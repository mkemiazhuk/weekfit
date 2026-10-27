import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { configuration, createServer } from './server.mjs';
import { createAsyncStack } from './async/bootstrap.mjs';
import { createQuotaStore, ownerKey } from './async/quota.mjs';
import { createPhotoCallLedger, readPhotoAttempt } from './photo-call-ledger.mjs';
import { mockFoodPayload } from './openai-mock.mjs';
import { makeJpegBytes } from './extended-load.mjs';

const ANALYSIS = 'abababab-abab-4aba-8aba-abababababab';
const jpeg = makeJpegBytes(96).toString('base64');

async function tempDir(t) {
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-owner-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

function paidServer(dir, extraConfig, dependencies) {
  const config = configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    FOOD_PHOTO_MOCK_DELAY_MS: '0',
    DATA_DIR: dir,
    ASYNC_ANALYSIS: '1',
    ALLOW_SINGLE_NODE_ASYNC: '1',
    STATE_BACKEND: 'file',
    OBJECT_STORE: 'local',
    DAILY_SCAN_LIMIT: '20',
    GLOBAL_DAILY_SCAN_LIMIT: '20',
    ...extraConfig,
  });
  return createServer(config, {
    authenticate: async (header) => header.replace(/^Bearer /, ''),
    requirePaidSubscriptionJWS: () => ({ productId: 'dev', environment: 'Sandbox' }),
    recognize: async () => ({ result: mockFoodPayload({ name: 'generated' }) }),
    ...dependencies,
  });
}

async function listen(server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

function post(base, route, user, bodyName = 'generated') {
  return fetch(`${base}${route}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${user}`,
      'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription',
      'Idempotency-Key': ANALYSIS,
    },
    body: JSON.stringify({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US', note: bodyName }),
  });
}

test('the same analysis UUID does not reveal another UID result on sync or async', async (t) => {
  const dir = await tempDir(t);
  const calls = [];
  const recognize = async () => {
    const name = `result-for-${calls.length}`;
    calls.push(name);
    return { result: mockFoodPayload({ name }) };
  };
  const stack = await createAsyncStack(configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    DATA_DIR: dir,
    ASYNC_ANALYSIS: '1',
    ALLOW_SINGLE_NODE_ASYNC: '1',
    STATE_BACKEND: 'file',
    OBJECT_STORE: 'local',
    FOOD_PHOTO_MOCK_DELAY_MS: '0',
    INLINE_FAST_PATH: '1',
    DAILY_SCAN_LIMIT: '20',
    GLOBAL_DAILY_SCAN_LIMIT: '20',
  }), {});
  const server = paidServer(dir, { INLINE_FAST_PATH: '1' }, { asyncStack: stack, recognize });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const first = await post(base, '/v1/food/photo-recognize', 'uid-a');
  const firstBody = await first.json();
  assert.equal(first.status, 200);
  assert.equal(firstBody.name, 'result-for-0');

  const secretPath = path.join(dir, 'photo-calls', 'owners', ownerKey('uid-a'), `${ANALYSIS}.json`);
  const stored = JSON.parse(await (await import('node:fs/promises')).readFile(secretPath, 'utf8'));
  stored.result = { ...stored.result, name: 'secret-for-a' };
  await writeFile(secretPath, `${JSON.stringify(stored)}\n`);

  const intruder = await post(base, '/v1/food/photo-recognize', 'uid-b');
  const intruderBody = await intruder.json();
  assert.equal(intruder.status, 200);
  assert.notEqual(intruderBody.name, 'secret-for-a');
  assert.equal(intruderBody.name, 'result-for-1');

  const replay = await post(base, '/v1/food/photo-recognize', 'uid-a');
  const replayBody = await replay.json();
  assert.equal(replay.status, 200);
  assert.equal(replayBody.name, 'secret-for-a');
  assert.equal(calls.length, 2);

  const asyncB = await post(base, '/v1/food/photo-analyze', 'uid-b');
  const asyncBBody = await asyncB.json();
  assert.ok(asyncB.status === 200 || asyncB.status === 202);
  const visible = JSON.stringify(asyncBBody);
  assert.equal(visible.includes('secret-for-a'), false);
  const owned = await readPhotoAttempt(dir, ANALYSIS, 'uid-a');
  const other = await readPhotoAttempt(dir, ANALYSIS, 'uid-b');
  assert.equal(owned.userId, 'uid-a');
  assert.equal(owned.result.name, 'secret-for-a');
  assert.equal(other.userId, 'uid-b');
  assert.notEqual(other.result?.name, 'secret-for-a');
});

test('a legacy photo record migrates only for its stored UID', async (t) => {
  const dir = await tempDir(t);
  const legacyDir = path.join(dir, 'photo-calls');
  await mkdir(legacyDir, { recursive: true });
  await writeFile(path.join(legacyDir, `${ANALYSIS}.json`), `${JSON.stringify({
    analysisId: ANALYSIS,
    userId: 'uid-a',
    status: 'completed',
    providerStarted: true,
    result: { name: 'legacy-a' },
  })}\n`);
  const owner = await readPhotoAttempt(dir, ANALYSIS, 'uid-a');
  const stranger = await readPhotoAttempt(dir, ANALYSIS, 'uid-b');
  assert.equal(owner.result.name, 'legacy-a');
  assert.equal(owner.userId, 'uid-a');
  assert.equal(stranger, null);
  const migrated = await readPhotoAttempt(dir, ANALYSIS, 'uid-a');
  assert.equal(migrated.result.name, 'legacy-a');
});

test('quota crashes between reservation and markers are repaired before another generation', async (t) => {
  for (const step of ['reservation', 'userMarker', 'globalMarker']) {
    const dir = await tempDir(t);
    const broken = createQuotaStore({
      dataDir: dir,
      userDailyLimit: 1,
      globalDailyLimit: 1,
      failAfter: step,
    });
    await assert.rejects(
      () => broken.reserve({ userId: 'uid-a', analysisId: ANALYSIS }),
      (error) => error.code === 'quota_write_interrupted' && error.step === step,
    );

    const restarted = createQuotaStore({
      dataDir: dir,
      userDailyLimit: 1,
      globalDailyLimit: 1,
    });
    await assert.rejects(
      () => restarted.reserve({ userId: 'uid-b', analysisId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' }),
      (error) => error.code === 'daily_scan_limit',
    );
    const recovered = await restarted.reserve({ userId: 'uid-a', analysisId: ANALYSIS });
    assert.equal(recovered.charged, false);
    const snap = await restarted.snapshot('uid-a');
    assert.equal(snap.userCount, 1);
    assert.equal(snap.globalCount, 1);

    let providerCalls = 0;
    const ledger = createPhotoCallLedger({
      dataDir: dir,
      userDailyLimit: 1,
      globalDailyLimit: 1,
    });
    const prepared = await ledger.prepare({
      userId: 'uid-a',
      idempotencyKey: ANALYSIS,
      fingerprint: 'fp',
    });
    assert.equal(prepared.analysisId, ANALYSIS);
    const ready = await ledger.snapshot('uid-a');
    if (ready.userCount >= 1 && ready.globalCount >= 1) providerCalls += 1;
    assert.equal(providerCalls, 1);
    await assert.rejects(
      () => ledger.prepare({
        userId: 'uid-a',
        idempotencyKey: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        fingerprint: 'other',
      }),
      (error) => error.code === 'daily_scan_limit',
    );
  }
});

test('production without an explicit DATA_DIR does not call the provider', async (t) => {
  let calls = 0;
  const config = configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    FOOD_PHOTO_MOCK_DELAY_MS: '0',
  });
  config.isProduction = true;
  const server = createServer(config, {
    asyncStack: null,
    recognize: async () => {
      calls += 1;
      return { result: mockFoodPayload() };
    },
  });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer weekfit-dev-local-token',
      'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription',
      'Idempotency-Key': ANALYSIS,
    },
    body: JSON.stringify({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US' }),
  });
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, 'persistent_data_dir_required');
  assert.equal(body.detail, 'persistent_mount_unconfirmed');
  assert.equal(calls, 0);
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.persistentDataDir, false);
  assert.equal(health.persistentDataDirReason, 'persistent_mount_unconfirmed');
  assert.equal(health.directoryDurable, null);
});

test('dev token suffixes do not share one analysis result', async (t) => {
  const dir = await tempDir(t);
  const token = 'weekfit-dev-local-token';
  const server = createServer(configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: token,
    FOOD_PHOTO_MOCK_DELAY_MS: '0',
    DATA_DIR: dir,
    ALLOW_SINGLE_NODE_ASYNC: '1',
    STATE_BACKEND: 'file',
    OBJECT_STORE: 'local',
    DAILY_SCAN_LIMIT: '20',
    GLOBAL_DAILY_SCAN_LIMIT: '20',
  }));
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const send = (suffix) => fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}.${suffix}`,
      'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription',
      'Idempotency-Key': ANALYSIS,
    },
    body: JSON.stringify({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US' }),
  });
  const first = await send('uid-a');
  const firstBody = await first.json();
  assert.equal(first.status, 200, JSON.stringify(firstBody));
  const secretPath = path.join(dir, 'photo-calls', 'owners', ownerKey('devuid:uid-a'), `${ANALYSIS}.json`);
  const stored = JSON.parse(await (await import('node:fs/promises')).readFile(secretPath, 'utf8'));
  stored.result = { ...stored.result, name: 'secret-for-a' };
  await writeFile(secretPath, `${JSON.stringify(stored)}\n`);
  const other = await send('uid-b');
  const otherBody = await other.json();
  assert.equal(other.status, 200, JSON.stringify(otherBody));
  assert.notEqual(otherBody.name, 'secret-for-a');
  const replay = await send('uid-a');
  const replayBody = await replay.json();
  assert.equal(replay.status, 200);
  assert.equal(replayBody.name, 'secret-for-a');
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.mockMetrics.calls, 2);
  assert.equal(health.mockMetrics.realFetchAttempts, 0);
});
