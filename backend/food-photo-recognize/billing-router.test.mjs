import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createBillingRouter } from './billing-router.mjs';
import { BillingStore } from './billing-store.mjs';
import { ServiceError } from './recognition.mjs';
const productId = 'com.weekfit.topup.photos20';
const jpeg = Buffer.from([255,216,255,192,0,17,8,0,100,0,100,3,1,17,0,2,17,0,3,17,0,255,217]).toString('base64');
const signed = (environment, payload) => `${environment}|${JSON.stringify(payload)}`;
function verifier(environment) {
  const anchor = Date.now() - 86400000;
  const decode = jws => {
    if (typeof jws !== 'string' || !jws.startsWith(`${environment}|`)) throw new ServiceError('wrong_environment', 403);
    return JSON.parse(jws.slice(environment.length + 1));
  };
  return { environment,
    subscription: async jws => ({ environment, originalTransactionId: 'same-lineage', active: true,
      anchor, accessUntil: Date.now()+86400000, ...decode(jws) }),
    purchase: async jws => decode(jws), notification: async jws => decode(jws),
  };
}
async function fixture(t, overrides = {}) {
  const dir = mkdtempSync(path.join(tmpdir(), 'billing-router-'));
  const config = { billingEnabled: true, sandboxBillingEnabled: true, dataDirExplicit: true, dataDir: dir,
    stateBackend: 'file', allowSingleNode: true, plannerVoiceEnabled: true,
    plannerVoiceMaxCalls: 5, plannerVoiceModel: 'gpt-realtime-2.1-mini', plannerVoiceIdleSeconds: 75,
    apiKey: 'test-only', model: 'gpt-6.1-sol', ...overrides };
  const deps = { authenticate: async () => 'same-firebase-user',
    apples: { Production: verifier('Production'), Sandbox: verifier('Sandbox') }, log() {},
    analyze: async () => ({ result: { isFood: true, name: 'Rice' }, usage: {} }),
  };
  let router = createBillingRouter(config, deps);
  const server = http.createServer(async (req, res) => {
    if (!await router.handle(req, res)) { res.writeHead(404); res.end(JSON.stringify({ legacy: true })); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const send = async (environment, route = '/v2/ai/usage', body, headers = {}) => {
    const res = await fetch(`http://127.0.0.1:${server.address().port}${route}`, {
      method: body == null ? 'GET' : 'POST', headers: { Authorization: 'Bearer test',
        'Content-Type': 'application/json', 'X-WeekFit-Billing-Environment': environment,
        'X-WeekFit-Subscription-JWS': signed(environment, {}), ...headers },
      body: body == null ? undefined : JSON.stringify(body),
    });
    return { status: res.status, body: res.status === 204 ? null : await res.json() };
  };
  const buy = async (environment, token, transactionId = 'same-transaction') => send(environment, '/v2/ai/purchases', {
    signedTransaction: signed(environment, { environment, transactionId, appAccountToken: token, type: 'Consumable', productId }),
  });
  t.after(async () => { await router.close(); server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true, force: true }); });
  return { send, buy, config, get router() { return router; }, async restart() { await router.close(); router = createBillingRouter(config, deps); } };
}
test('one database has distinct prod/sandbox tables, independent purchases, quotas, idempotency and restart recovery', async t => {
  const f = await fixture(t);
  const prod = (await f.send('Production')).body, sandbox = (await f.send('Sandbox')).body;
  assert.notEqual(prod.appAccountToken, sandbox.appAccountToken);
  for (const environment of ['Production', 'Sandbox']) {
    const token = environment === 'Production' ? prod.appAccountToken : sandbox.appAccountToken;
    assert.equal((await f.buy(environment, token)).status, 200);
    assert.equal((await f.buy(environment, token)).body.photos.purchased, 20);
    assert.equal((await f.send(environment, '/v2/ai/photo', { imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en' },
      { 'Idempotency-Key': 'same_photo_key' })).status, 200);
    assert.equal((await f.send(environment)).body.photos.included, 29);
  }
  const db = f.router.stores.Production.db;
  for (const prefix of ['prod_', 'sandbox_']) {
    for (const table of ['wallets','subscriptions','checkout_identities','purchases','periods','balances','operations','audit','usage']) {
      assert.equal(db.prepare('SELECT count(*) AS n FROM sqlite_master WHERE type=? AND name=?').get('table', prefix+table).n, 1);
    }
    assert.equal(db.prepare(`SELECT count(*) AS n FROM ${prefix}purchases`).get().n, 1);
    assert.equal(db.prepare(`SELECT count(*) AS n FROM ${prefix}usage`).get().n, 1);
  }
  await f.restart();
  assert.equal((await f.send('Production')).body.appAccountToken, prod.appAccountToken);
  assert.equal((await f.send('Sandbox')).body.photos.purchased, 20);
  assert.equal((await f.send('Production')).body.photos.included, 29);
});
test('cross-environment proofs, purchases, tokens and signed refund notifications cannot change production', async t => {
  const f = await fixture(t);
  const prod = (await f.send('Production')).body, sandbox = (await f.send('Sandbox')).body;
  await f.buy('Production', prod.appAccountToken); await f.buy('Sandbox', sandbox.appAccountToken);
  assert.equal((await f.send('Production', '/v2/ai/usage', null,
    { 'X-WeekFit-Subscription-JWS': signed('Sandbox', {}) })).status, 403);
  assert.equal((await f.send('Production', '/v2/ai/usage', null,
    { 'X-WeekFit-Subscription-JWS': signed('Production', { environment: 'Sandbox' }) })).status, 403);
  assert.equal((await f.buy('Production', sandbox.appAccountToken, 'stolen-token')).status, 403);
  assert.equal((await f.send('Production', '/v2/ai/purchases', { signedTransaction: signed('Production', {
    environment: 'Sandbox', transactionId: 'foreign', appAccountToken: prod.appAccountToken, type: 'Consumable', productId }) })).status, 403);
  const refund = { type: 'REFUND', transaction: { environment: 'Sandbox', transactionId: 'same-transaction',
    appAccountToken: sandbox.appAccountToken, productId } };
  assert.equal((await f.send('Production', '/v2/billing/notifications', { signedPayload: signed('Sandbox', refund) })).status, 403);
  assert.equal((await f.send('Sandbox', '/v2/billing/notifications/sandbox', { signedPayload: signed('Sandbox', refund) })).status, 200);
  assert.equal((await f.send('Sandbox')).body.photos.purchased, 0);
  assert.equal((await f.send('Production')).body.photos.purchased, 20);
  assert.equal((await f.send('Sandbox', '/v2/billing/notifications', { signedPayload: signed('Sandbox', refund) })).status, 400);
});
test('Sandbox-only enable leaves production legacy routes untouched and rejects Sandbox legacy sessions', async t => {
  const f = await fixture(t, { billingEnabled: false });
  assert.equal((await f.send('Sandbox')).status, 200);
  assert.equal(f.router.stores.Production.db.prepare('SELECT count(*) AS n FROM prod_wallets').get().n, 0);
  assert.equal((await f.send('Production', '/v1/planner-voice/session', {})).body.legacy, true);
  assert.equal((await f.send('Sandbox', '/v1/planner-voice/session', {})).status, 426);
  assert.equal((await f.send('Sandbox', '/v1/food/photo-recognize', {})).status, 426);
  assert.equal((await f.send('sandbox')).status, 400);
});
test('voice tickets and reservations are isolated for the same Firebase user and subscription ID', async t => {
  const f = await fixture(t);
  const prod = (await f.send('Production', '/v1/planner-voice/line', {})).body;
  const sandbox = (await f.send('Sandbox', '/v1/planner-voice/line', {})).body;
  assert.notEqual(prod.ticket, sandbox.ticket);
  assert.equal((await f.send('Sandbox', '/v2/ai/voice/session', { ticket: prod.ticket, idempotencyKey: 'voice_same' })).status, 409);
  for (const [environment, ticket] of [['Production', prod.ticket], ['Sandbox', sandbox.ticket]]) {
    assert.equal((await f.send(environment, '/v2/ai/voice/session', { ticket, idempotencyKey: 'voice_same', language: 'en' })).status, 200);
    assert.equal((await f.send(environment)).body.voice.included, 0);
  }
  await f.send('Sandbox', '/v2/ai/voice/stop', { sessionId: 'voice_same' });
  assert.equal((await f.send('Sandbox')).body.voice.included, 300);
  assert.equal((await f.send('Production')).body.voice.included, 0);
});
test('namespace guards reject foreign signed data even if it reuses an existing appAccountToken', t => {
  const dir = mkdtempSync(path.join(tmpdir(), 'billing-scope-'));
  const store = new BillingStore(path.join(dir, 'db.sqlite'), { environment: 'Production' });
  t.after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });
  assert.throws(() => store.checkoutWallet('user', 'Sandbox'), { code: 'billing_environment_mismatch' });
  assert.throws(() => store.wallet({ environment: 'Sandbox', originalTransactionId: 'same' }), { code: 'billing_environment_mismatch' });
  assert.throws(() => store.refund({ environment: 'Sandbox', transactionId: 'same' }), { code: 'billing_environment_mismatch' });
});
test('older billing files stop startup instead of silently discarding balances', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'billing-old-'));
  try {
    writeFileSync(path.join(dir, 'billing-Sandbox.sqlite'), 'existing-ledger');
    assert.throws(() => createBillingRouter({ billingEnabled: true, dataDirExplicit: true, dataDir: dir,
      allowSingleNode: true, stateBackend: 'file' }), /Legacy billing database/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
