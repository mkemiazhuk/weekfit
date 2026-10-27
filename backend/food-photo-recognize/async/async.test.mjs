import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { configuration, createServer } from '../server.mjs';
import { createAsyncStack } from './bootstrap.mjs';
import { createQuotaStore } from './quota.mjs';
import { createWorkerRuntime, buildWorkerMockAdapter } from './worker-runtime.mjs';
import { makeJpegBytes } from '../extended-load.mjs';
import { createMockOpenAIAdapter } from '../openai-mock.mjs';

const DEV_SUB = 'weekfit-dev-local-subscription';
const AUTH = 'Bearer weekfit-dev-local-token';
const jpegB64 = makeJpegBytes(128).toString('base64');
const input = () => ({ imageBase64: jpegB64, mimeType: 'image/jpeg', locale: 'en_US' });

async function tempData() {
  return mkdtemp(path.join(tmpdir(), 'weekfit-async-'));
}

function mockConfig(dataDir, overrides = {}) {
  return configuration({
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    OPENAI_MOCK: '1',
    ASYNC_ANALYSIS: '1',
    DATA_DIR: dataDir,
    FOOD_PHOTO_MOCK_DELAY_MS: '40',
    DAILY_SCAN_LIMIT: '100',
    GLOBAL_DAILY_SCAN_LIMIT: '1000',
    GLOBAL_AI_SLOTS: '2',
    MAX_ASYNC_QUEUE: '100',
    MAX_CONCURRENT_UPLOADS: '4',
    ...overrides,
  });
}

async function listen(server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  await server.asyncReady;
  return `http://127.0.0.1:${server.address().port}`;
}

test('idle capacity uses inline fast-path (200 + result, no queue)', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));

  const config = mockConfig(dataDir);
  const stack = await createAsyncStack(config);
  const server = createServer(config, { asyncStack: stack });
  const base = await listen(server);
  t.after(() => new Promise((r) => server.close(r)));

  const res = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': 'async-key-inline',
    },
    body: JSON.stringify(input()),
  });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, 'completed');
  assert.equal(body.inline, true);
  assert.equal(body.result.isFood, true);
  assert.ok(body.analysisId);

  // Replay same analysis id → completed result, no new AI.
  const replay = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': 'async-key-inline',
    },
    body: JSON.stringify(input()),
  });
  assert.equal(replay.status, 200);
  const replayed = await replay.json();
  assert.equal(replayed.idempotentReplay, true);
  assert.equal(replayed.status, 'completed');
  assert.equal(replayed.analysisId, body.analysisId);
});

test('busy path enqueues 202 and worker completes job', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));

  const config = mockConfig(dataDir, {
    INLINE_FAST_PATH: '0',
    FOOD_PHOTO_MOCK_DELAY_MS: '40',
  });
  const stack = await createAsyncStack(config);
  const server = createServer(config, { asyncStack: stack });
  const base = await listen(server);
  t.after(() => new Promise((r) => server.close(r)));

  const mockAdapter = buildWorkerMockAdapter(config);
  const worker = createWorkerRuntime({
    config: stack.asyncConfig,
    jobStore: stack.jobStore,
    objectStore: stack.objectStore,
    aiSlots: stack.aiSlots,
    circuit: stack.circuit,
    budget: stack.budget,
    mockAdapter,
    workerId: 'test-worker-1',
  });

  const res = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': 'async-key-1',
    },
    body: JSON.stringify(input()),
  });
  assert.equal(res.status, 202);
  const accepted = await res.json();
  assert.equal(accepted.status, 'queued');
  assert.ok(accepted.analysisId);

  let done = false;
  for (let i = 0; i < 50 && !done; i += 1) {
    done = await worker.tick();
    if (!done) await new Promise((r) => setTimeout(r, 20));
  }
  assert.equal(done, true);

  const statusRes = await fetch(`${base}/v1/food/photo-analyze/${accepted.analysisId}`, {
    headers: { Authorization: AUTH },
  });
  assert.equal(statusRes.status, 200);
  const status = await statusRes.json();
  assert.equal(status.status, 'completed');
  assert.equal(status.result.isFood, true);
  assert.equal(mockAdapter.metrics().realFetchAttempts, 0);
  assert.ok(mockAdapter.metrics().calls >= 1);
});

test('async idempotent replay does not double quota or enqueue duplicate AI', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const config = mockConfig(dataDir, { DAILY_SCAN_LIMIT: '3' });
  const stack = await createAsyncStack(config);
  const server = createServer(config, { asyncStack: stack });
  const base = await listen(server);
  t.after(() => new Promise((r) => server.close(r)));

  const post = () => fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': 'same-async',
    },
    body: JSON.stringify(input()),
  });

  const a = await (await post()).json();
  const b = await (await post()).json();
  assert.equal(a.analysisId, b.analysisId);
  assert.equal(b.idempotentReplay, true);
  const snap = await stack.quota.snapshot('local-developer');
  assert.equal(snap.userCount, 1);
  // Inline fast-path completes without leaving a queue item; replay must not enqueue again.
  assert.equal(await stack.jobStore.queueDepth(), 0);
});

test('async status forbids other users', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const config = mockConfig(dataDir);
  const stack = await createAsyncStack(config);
  const server = createServer(config, { asyncStack: stack });
  const base = await listen(server);
  t.after(() => new Promise((r) => server.close(r)));

  const accepted = await (await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
    },
    body: JSON.stringify(input()),
  })).json();

  // Forge a different user by temporarily swapping job owner.
  const job = await stack.jobStore.getJob(accepted.analysisId, 'local-developer');
  await stack.jobStore.saveJob({ ...job, userId: 'someone-else' });

  const statusRes = await fetch(`${base}/v1/food/photo-analyze/${accepted.analysisId}`, {
    headers: { Authorization: AUTH },
  });
  assert.equal(statusRes.status, 403);
});

test('file quota admits at most the global limit under parallel reserves', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const quota = createQuotaStore({ dataDir, userDailyLimit: 20, globalDailyLimit: 2 });
  const results = await Promise.all(Array.from({ length: 12 }, (_, index) => quota.reserve({
    userId: `user-${index}`,
    analysisId: `aaaaaaaa-aaaa-4aaa-8aaa-${String(index).padStart(12, '0')}`,
  }).then(() => 'charged').catch((error) => error.code)));
  assert.equal(results.filter((item) => item === 'charged').length, 2);
  const again = await quota.reserve({
    userId: 'user-0',
    analysisId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000000',
  });
  assert.equal(again.charged, false);
});

test('lease recovery requeues abandoned processing jobs', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const config = mockConfig(dataDir);
  const stack = await createAsyncStack(config);

  const { job } = await stack.jobStore.createQueuedJob({
    analysisId: '11111111-1111-4111-8111-111111111111',
    userId: 'local-developer',
    idempotencyKey: 'lease-test',
    fingerprint: 'abc',
    photoKey: 'x/y.jpg',
    photoBytes: 10,
    locale: 'en_US',
    note: '',
    model: config.model,
    maxAttempts: 3,
    quotaReserved: true,
  });
  await stack.jobStore.enqueue(job.analysisId, job.userId);
  const claimed = await stack.jobStore.claimNext({ workerId: 'dead-worker', leaseMs: 30 });
  assert.equal(claimed.status, 'processing');
  await new Promise((r) => setTimeout(r, 40));
  const { recovered } = await stack.jobStore.recoverExpiredLeases();
  assert.ok(recovered >= 1);
  const again = await stack.jobStore.getJob(job.analysisId, job.userId);
  assert.equal(again.status, 'queued');
  assert.equal(again.providerStarted, undefined);
});

test('lease recovery does not requeue an analysis whose provider call started', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const stack = await createAsyncStack(mockConfig(dataDir));
  const { job } = await stack.jobStore.createQueuedJob({
    analysisId: '22222222-2222-4222-8222-222222222222',
    userId: 'local-developer',
    idempotencyKey: 'lease-started',
    fingerprint: 'abc',
    photoKey: 'x/y.jpg',
    photoBytes: 10,
    locale: 'en_US',
    note: '',
    model: 'gpt-6-astra',
    maxAttempts: 3,
    quotaReserved: true,
  });
  await stack.jobStore.enqueue(job.analysisId, job.userId);
  const claimed = await stack.jobStore.claimNext({ workerId: 'dead-worker', leaseMs: 30 });
  const marked = await stack.jobStore.markProviderStarted(claimed.analysisId, claimed.leaseToken, claimed.userId);
  assert.equal(marked.providerStarted, true);
  await new Promise((r) => setTimeout(r, 40));
  await stack.jobStore.recoverExpiredLeases();
  const again = await stack.jobStore.getJob(job.analysisId, job.userId);
  assert.equal(again.status, 'failed');
  assert.equal(again.providerOutcome, 'uncertain');
  const queued = await stack.jobStore.claimNext({ workerId: 'other', leaseMs: 1000 });
  assert.equal(queued, null);
});

test('one analysis id calls the provider once across sync, async, and restart', async (t) => {
  const dataDir = await tempData();
  t.after(async () => rm(dataDir, { recursive: true, force: true }));
  const analysisId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const headers = {
    'Content-Type': 'application/json',
    Authorization: AUTH,
    'X-WeekFit-Subscription-JWS': DEV_SUB,
    'Idempotency-Key': analysisId,
    'X-WeekFit-Analysis-Id': analysisId,
  };
  const adapter = createMockOpenAIAdapter({ delayMs: 5, scenario: 'ok' });
  const config = mockConfig(dataDir);
  const stack = await createAsyncStack(config, { openaiFetcher: adapter.fetcher });
  const server = createServer(config, {
    asyncStack: stack,
    mockAdapter: adapter,
    openaiFetcher: adapter.fetcher,
  });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const sync = await fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST', headers, body: JSON.stringify(input()),
  });
  assert.equal(sync.status, 200);
  assert.equal(adapter.metrics().calls, 1);

  const asyncReplay = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST', headers, body: JSON.stringify(input()),
  });
  assert.equal(asyncReplay.status, 200);
  assert.equal((await asyncReplay.json()).idempotentReplay, true);
  assert.equal(adapter.metrics().calls, 1);
  const quota = createQuotaStore({ dataDir, userDailyLimit: 100, globalDailyLimit: 1000 });
  assert.equal((await quota.snapshot('local-developer')).globalCount, 1);

  await new Promise((resolve) => server.close(resolve));
  const adapter2 = createMockOpenAIAdapter({ delayMs: 5, scenario: 'ok' });
  const stack2 = await createAsyncStack(config, { openaiFetcher: adapter2.fetcher });
  const restarted = createServer(config, {
    asyncStack: stack2,
    mockAdapter: adapter2,
    openaiFetcher: adapter2.fetcher,
  });
  const base2 = await listen(restarted);
  t.after(() => new Promise((resolve) => restarted.close(resolve)));
  const again = await fetch(`${base2}/v1/food/photo-recognize`, {
    method: 'POST', headers, body: JSON.stringify(input()),
  });
  assert.equal(again.status, 200);
  assert.equal(again.headers.get('x-weekfit-idempotent-hit'), '1');
  assert.equal(adapter2.metrics().calls, 0);
  assert.equal((await quota.snapshot('local-developer')).globalCount, 1);
});
