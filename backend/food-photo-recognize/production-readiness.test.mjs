import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { configuration, createServer } from './server.mjs';
import { supervise } from './container.mjs';
import { createAsyncStack } from './async/bootstrap.mjs';
import { makeJpegBytes } from './extended-load.mjs';
import { createWorkerRuntime, buildWorkerMockAdapter } from './async/worker-runtime.mjs';

const mockEnv = { OPENAI_MOCK: '1', ALLOW_DEV_AUTH: '1', WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token' };
const input = { imageBase64: makeJpegBytes(128).toString('base64'), mimeType: 'image/jpeg', locale: 'en_US' };
async function serve(t, config, deps = {}) {
  const server = createServer(config, deps);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  return { server, base: `http://127.0.0.1:${server.address().port}` };
}
async function stackFor(t, env = {}) {
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-production-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const config = configuration({ ...mockEnv, DATA_DIR: dir, ...env });
  return { config, stack: await createAsyncStack(config) };
}

test('explicit ASYNC_ANALYSIS=0 preserves persistent trial storage without launching worker', () => {
  assert.equal(configuration({ DATA_DIR: '/var/data', ASYNC_ANALYSIS: '0' }).asyncEnabled, false);
});
test('readiness fails when async initialization failed, while liveness stays available', async t => {
  const config = configuration({ ...mockEnv, ASYNC_ANALYSIS: '1', STATE_BACKEND: 'redis' });
  const { base } = await serve(t, config);
  const ready = await fetch(`${base}/readyz`);
  assert.equal(ready.status, 503);
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.photoAnalyzeMode, 'unavailable');
  assert.equal(health.asyncInitFailed, true);
});
test('readiness rechecks Redis after initialization', async t => {
  const config = configuration(mockEnv);
  const { base } = await serve(t, config, { asyncStack: { redis: { ping: async () => { throw Error('offline'); } } } });
  assert.equal((await fetch(`${base}/readyz`)).status, 503);
});
test('same client UUID across users cannot disclose another user result', async t => {
  const { config, stack } = await stackFor(t);
  const key = randomUUID();
  const submit = userId => stack.submit({ userId, headers: { 'idempotency-key': key }, body: input });
  const a = await submit('alice');
  const b = await submit('bob');
  assert.notEqual(a.body.analysisId, b.body.analysisId);
  assert.equal((await stack.jobStore.getJob(a.body.analysisId)).userId, 'alice');
  assert.equal((await stack.jobStore.getJob(b.body.analysisId)).userId, 'bob');
  await assert.rejects(() => stack.status({ userId: 'bob', analysisId: a.body.analysisId }), e => e.status === 403);
});
test('long poll waits for worker completion instead of aborting on normal request close', async t => {
  const { config, stack } = await stackFor(t, { INLINE_FAST_PATH: '0' });
  const { base } = await serve(t, config, { asyncStack: stack });
  const accepted = await stack.submit({ userId: 'local-developer', headers: {}, body: input });
  const task = fetch(`${base}/v1/food/photo-analyze/${accepted.body.analysisId}?waitMs=2000`, { headers: { Authorization: `Bearer ${mockEnv.WEEKFIT_DEV_TOKEN}` } });
  const timer = setTimeout(() => stack.jobStore.completeJob(accepted.body.analysisId, { result: { isFood: true } }), 100);
  t.after(() => clearTimeout(timer));
  const res = await task;
  assert.equal((await res.json()).status, 'completed');
});
test('production free trial fails closed without durable storage', async t => {
  const config = configuration({ NODE_ENV: 'production', OPENAI_API_KEY: 'test', FIREBASE_PROJECT_ID: 'test' });
  const { base } = await serve(t, config, { authenticate: async () => 'user' });
  const res = await fetch(`${base}/v1/food/photo-recognize`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-WeekFit-Photo-Free-Trial': '1' }, body: JSON.stringify(input) });
  assert.equal(res.status, 503);
  assert.equal((await res.json()).error, 'trial_store_unavailable');
});
test('uncertain provider failure is terminal instead of automatic double billing', async t => {
  const { config, stack } = await stackFor(t, { INLINE_FAST_PATH: '0', FOOD_PHOTO_MOCK_SCENARIO: 'server_error' });
  const accepted = await stack.submit({ userId: 'alice', headers: {}, body: input });
  const runtime = createWorkerRuntime({ config, ...stack, mockAdapter: buildWorkerMockAdapter(config), onLog: () => {} });
  await runtime.tick();
  const job = await stack.jobStore.getJob(accepted.body.analysisId);
  assert.equal(job.status, 'failed');
  assert.equal(job.attempts, 1);
  assert.equal(await stack.jobStore.queueDepth(), 0);
});
function fakeSupervisor(env) {
  const children = [];
  const signals = new EventEmitter();
  const runtime = supervise({ env, signals, spawnProcess: (_exec, args) => {
    const child = new EventEmitter();
    child.script = args[0]; child.sent = [];
    child.kill = signal => { child.sent.push(signal); return true; };
    children.push(child); return child;
  } });
  return { ...runtime, children, signals };
}
test('supervisor terminates API when worker exits unexpectedly', async () => {
  const r = fakeSupervisor({ ...mockEnv, ASYNC_ANALYSIS: '1' });
  assert.deepEqual(r.children.map(c => c.script), ['server.mjs', 'worker.mjs']);
  r.children[1].emit('exit', 1);
  assert.deepEqual(r.children[0].sent, ['SIGTERM']);
  r.children[0].emit('exit', 0);
  assert.equal(await r.completion, 1);
});
test('SIGTERM drains API and worker together', async () => {
  const r = fakeSupervisor({ ...mockEnv, ASYNC_ANALYSIS: '1' });
  r.signals.emit('SIGTERM');
  for (const child of r.children) { assert.deepEqual(child.sent, ['SIGTERM']); child.emit('exit', 0); }
  assert.equal(await r.completion, 0);
  assert.equal(r.signals.listenerCount('SIGTERM'), 0);
});

test('legacy sync route uses the same durable job and quota as async submissions', async t => {
  const { config, stack } = await stackFor(t);
  const { base } = await serve(t, config, { asyncStack: stack });
  const key = randomUUID();
  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${mockEnv.WEEKFIT_DEV_TOKEN}`, 'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription', 'Idempotency-Key': key };
  const first = await fetch(`${base}/v1/food/photo-recognize`, { method: 'POST', headers, body: JSON.stringify(input) });
  assert.equal(first.status, 200);
  assert.equal((await first.json()).isFood, true);
  const second = await fetch(`${base}/v1/food/photo-analyze`, { method: 'POST', headers, body: JSON.stringify(input) });
  assert.equal((await second.json()).idempotentReplay, true);
  assert.equal((await stack.quota.snapshot('local-developer')).userCount, 1);
});

test('rediss sends a TLS handshake, never plaintext Redis AUTH', async () => {
  const { createServer } = await import('node:net');
  const { createRedisClient } = await import('./async/redis-client.mjs');
  let firstByte;
  const server = createServer(socket => socket.once('data', bytes => { firstByte = bytes[0]; socket.destroy(); }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const client = createRedisClient(`rediss://secret@127.0.0.1:${server.address().port}`);
  try { await assert.rejects(() => client.ping()); assert.equal(firstByte, 0x16); }
  finally { await client.quit(); await new Promise(resolve => server.close(resolve)); }
});

test('worker fills spare slots while its first AI analysis is still running', async t => {
  const { config, stack } = await stackFor(t, { INLINE_FAST_PATH: '0', FOOD_PHOTO_MOCK_DELAY_MS: '500', GLOBAL_AI_SLOTS: '4' });
  const runtime = createWorkerRuntime({ config, ...stack, mockAdapter: buildWorkerMockAdapter(config), onLog: () => {} });
  const first = await stack.submit({ userId: 'alice', headers: {}, body: input });
  const loop = runtime.runLoop({ claimWaitMs: 100, localConcurrency: 4 });
  t.after(async () => { await runtime.stop(); await loop; });
  const waitProcessing = async id => {
    const deadline = Date.now() + 2000;
    while (Date.now() < deadline) {
      const job = await stack.jobStore.getJob(id);
      if (job.status === 'processing') return;
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    assert.fail('worker did not start queued job');
  };
  await waitProcessing(first.body.analysisId);
  const second = await stack.submit({ userId: 'bob', headers: {}, body: input });
  await waitProcessing(second.body.analysisId);
  try { assert.equal((await stack.jobStore.getJob(first.body.analysisId)).status, 'processing'); }
  finally { await runtime.stop(); await loop; }
});
