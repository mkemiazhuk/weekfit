import test from 'node:test';
import assert from 'node:assert/strict';
import { createMiniRedisServer } from './mini-redis.mjs';
import { createRedisClient } from './redis-client.mjs';
import { createRedisProviderLimits } from './provider-limits.mjs';
import { createWorkerRuntime } from './worker-runtime.mjs';
import { createMockOpenAIAdapter } from '../openai-mock.mjs';
import { makeJpegBytes } from '../extended-load.mjs';

const sleep = ms => new Promise(r => setTimeout(r, ms));
async function until(fn, ms = 1000) {
  const end = Date.now() + ms;
  while (!fn() && Date.now() < end) await sleep(5);
  assert.ok(fn(), 'condition not met before deadline');
}

test('two processes share RPM/TPM reservations (Redis protocol double)', async () => {
  const broker = await createMiniRedisServer().listen();
  const a = createRedisClient(broker.url), b = createRedisClient(broker.url);
  try {
    const opts = { maxRpm: 7, maxTpm: 300, tokensPerCallEstimate: 100 };
    const x = createRedisProviderLimits({ redis: a, ...opts });
    const y = createRedisProviderLimits({ redis: b, ...opts });
    const outcomes = await Promise.all(Array.from({ length: 20 }, (_, i) => (i % 2 ? x : y).tryReserve()));
    assert.equal(outcomes.filter(r => r.ok).length, 3);
    assert.ok(outcomes.filter(r => !r.ok).every(r => r.code === 'provider_tpm_limited'));
  } finally { await Promise.all([a.close(), b.close()]); await broker.close(); }
});

test('blocked queue wait does not block heartbeat/state commands', async () => {
  const broker = await createMiniRedisServer().listen();
  const client = createRedisClient(broker.url);
  try {
    const blocked = client.brpop('empty', 1);
    await sleep(30);
    const started = Date.now();
    assert.equal(await client.ping(), 'PONG');
    assert.ok(Date.now() - started < 300);
    await blocked;
  } finally { await client.close(); await broker.close(); }
});

test('spare worker lane starts new arrival before slow analysis finishes', async () => {
  const jobs = [{ analysisId: 'a', createdAt: Date.now(), photoKey: 'photo', locale: 'en_US' }];
  const claimed = [], completed = [];
  const adapter = createMockOpenAIAdapter({ delayMs: 700 });
  const jobStore = {
    async recoverExpiredLeases() {},
    async claimNext({ waitMs }) {
      const end = Date.now() + waitMs;
      do {
        const job = jobs.shift();
        if (job) { claimed.push(job.analysisId); return job; }
        if (!waitMs) return null;
        await sleep(5);
      } while (Date.now() < end);
      return null;
    },
    async completeJob(id) { completed.push(id); },
    async failJob() {}, async renewLease() {},
  };
  const runtime = createWorkerRuntime({
    config: { openAIMock: true, model: 'gpt-6-astra', timeoutMs: 5000,
      workerLeaseMs: 6000, workerMaxAttempts: 1 },
    jobStore,
    objectStore: { async getJpeg() { return makeJpegBytes(256); } },
    aiSlots: { async tryAcquire() { return { async release() {}, async renew() {} }; } },
    circuit: { async beforeCall() {}, async recordSuccess() {}, async recordFailure() {} },
    budget: { async assertWithinBudget() {}, async recordAttempt() {} },
    mockAdapter: adapter, onLog() {},
  });
  const loop = runtime.runLoop({ localConcurrency: 2, claimWaitMs: 50 });
  try {
    await until(() => adapter.metrics().calls === 1);
    jobs.push({ analysisId: 'b', createdAt: Date.now(), photoKey: 'photo', locale: 'en_US' });
    await until(() => adapter.metrics().calls === 2, 300);
    assert.equal(completed.length, 0, 'second starts before first completes');
    assert.deepEqual(claimed, ['a', 'b']);
  } finally { await runtime.stop({ drainMs: 2000 }); await loop; }
  assert.equal(adapter.metrics().realFetchAttempts, 0);
});

test('production Redis mode fails closed when provider limits are unknown', async () => {
  const { asyncConfiguration } = await import('./bootstrap.mjs');
  const env = { NODE_ENV: 'production', STATE_BACKEND: 'redis',
    REDIS_URL: 'redis://localhost:6379', OBJECT_STORE: 's3' };
  assert.throws(() => asyncConfiguration(env), /confirmed positive PROVIDER_MAX/);
  assert.equal(asyncConfiguration({ ...env, PROVIDER_MAX_RPM: '120', PROVIDER_MAX_TPM: '480000' }).providerMaxRpm, 120);
});

test('crash between pop and job attachment leaves a recoverable lease', async () => {
  const { createRedisJobStore } = await import('./redis-backend.mjs');
  const broker = await createMiniRedisServer().listen();
  const client = createRedisClient(broker.url);
  try {
    const store = await createRedisJobStore({ redis: client });
    const id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    await store.createQueuedJob({ analysisId: id, userId: 'u', photoKey: 'photo' });
    await store.enqueue(id);
    const broken = await createRedisJobStore({ redis: { ...client,
      async get() { throw Error('simulated worker death after pop'); } } });
    await assert.rejects(() => broken.claimNext({ workerId: 'dead', leaseMs: 30 }), /simulated/);
    await sleep(50);
    assert.equal((await store.recoverExpiredLeases()).recovered, 1);
    assert.equal((await store.claimNext({ workerId: 'replacement', leaseMs: 1000 })).analysisId, id);
  } finally { await client.close(); await broker.close(); }
});
