import test from 'node:test';
import assert from 'node:assert/strict';
import { createMiniRedisServer } from './mini-redis.mjs';
import { createRedisClient } from './redis-client.mjs';
import {
  createRedisJobStore,
  createRedisQuotaStore,
  createRedisAiSlots,
} from './redis-backend.mjs';
import { createHttpObjectStoreServer, createHttpObjectStore } from './http-object-store.mjs';
import { createAsyncStack } from './bootstrap.mjs';
import { configuration, createServer } from '../server.mjs';
import { createWorkerRuntime, buildWorkerMockAdapter } from './worker-runtime.mjs';
import { makeJpegBytes } from '../extended-load.mjs';
import { JOB_STATUSES } from './job-store.mjs';

const jpegB64 = makeJpegBytes(128).toString('base64');
const AUTH = 'Bearer weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';

async function withRedis(fn) {
  const mini = createMiniRedisServer();
  const info = await mini.listen();
  const redis = createRedisClient(info.url);
  try {
    await redis.ping();
    return await fn({ redis, redisUrl: info.url, closeMini: info.close });
  } finally {
    await redis.quit().catch(() => {});
    await info.close();
  }
}

test('redis client ping against mini-redis', async () => {
  await withRedis(async ({ redis }) => {
    assert.equal(await redis.ping(), 'PONG');
  });
});

test('redis job store: idempotency, claim, lease recovery — no lost job', async () => {
  await withRedis(async ({ redis }) => {
    const store = await createRedisJobStore({ redis, jobTtlMs: 60_000 });
    const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const idem = await store.reserveIdempotency({
      userId: 'u1',
      idempotencyKey: id,
      fingerprint: 'fp1',
      analysisId: id,
    });
    assert.equal(idem.created, true);
    const again = await store.reserveIdempotency({
      userId: 'u1',
      idempotencyKey: id,
      fingerprint: 'fp1',
      analysisId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    });
    assert.equal(again.created, false);
    assert.equal(again.analysisId, id);

    await assert.rejects(
      () => store.reserveIdempotency({
        userId: 'u1',
        idempotencyKey: id,
        fingerprint: 'other',
        analysisId: id,
      }),
      (e) => e.code === 'idempotency_key_reuse',
    );

    const { created } = await store.createQueuedJob({
      analysisId: id,
      userId: 'u1',
      fingerprint: 'fp1',
      photoKey: 'a/b.jpg',
      photoBytes: 10,
      locale: 'en_US',
      note: '',
      model: 'gpt-6-astra',
      maxAttempts: 3,
      quotaReserved: true,
    });
    assert.equal(created, true);
    await store.enqueue(id);
    assert.equal(await store.queueDepth(), 1);

    const claimed = await store.claimNext({ workerId: 'w-dead', leaseMs: 40 });
    assert.equal(claimed.status, JOB_STATUSES.processing);
    assert.equal(await store.queueDepth(), 0);

    await new Promise((r) => setTimeout(r, 50));
    const { recovered } = await store.recoverExpiredLeases();
    assert.ok(recovered >= 1);
    const job = await store.getJob(id);
    assert.equal(job.status, JOB_STATUSES.queued);
    assert.equal(await store.queueDepth(), 1);

    const claimed2 = await store.claimNext({ workerId: 'w-live', leaseMs: 5000 });
    assert.equal(claimed2.analysisId, id);
    await store.completeJob(id, { result: { ok: true }, providerOutcome: 'success' });
    const done = await store.getJob(id);
    assert.equal(done.status, JOB_STATUSES.completed);
  });
});

test('redis quota: atomic reserve, no double charge, hard limit', async () => {
  await withRedis(async ({ redis }) => {
    const quota = createRedisQuotaStore({
      redis,
      userDailyLimit: 2,
      globalDailyLimit: 10,
    });
    const a = await quota.reserve({ userId: 'u1', analysisId: 'id-1' });
    assert.equal(a.charged, true);
    const replay = await quota.reserve({ userId: 'u1', analysisId: 'id-1' });
    assert.equal(replay.charged, false);
    await quota.reserve({ userId: 'u1', analysisId: 'id-2' });
    await assert.rejects(
      () => quota.reserve({ userId: 'u1', analysisId: 'id-3' }),
      (e) => e.code === 'daily_scan_limit',
    );
    const snap = await quota.snapshot('u1');
    assert.equal(snap.userCount, 2);
  });
});

test('redis AI slots enforce global concurrency', async () => {
  await withRedis(async ({ redis }) => {
    const slots = createRedisAiSlots({ redis, maxConcurrent: 2, leaseMs: 5000 });
    const a = await slots.tryAcquire('w1');
    const b = await slots.tryAcquire('w2');
    const c = await slots.tryAcquire('w3');
    assert.ok(a && b);
    assert.equal(c, null);
    assert.equal(await slots.activeCount(), 2);
    await a.release();
    const d = await slots.tryAcquire('w3');
    assert.ok(d);
    await b.release();
    await d.release();
  });
});

test('multi API+worker via redis+http object store: accept survives restart, no lost job, single AI', async () => {
  await withRedis(async ({ redis, redisUrl }) => {
    const objServer = createHttpObjectStoreServer();
    const objInfo = await objServer.listen();
    const objectStore = createHttpObjectStore({
      baseUrl: objInfo.baseUrl,
      token: objInfo.token,
    });

    const baseConfig = configuration({
      ALLOW_DEV_AUTH: '1',
      WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
      OPENAI_MOCK: '1',
      ASYNC_ANALYSIS: '1',
      STATE_BACKEND: 'redis',
      REDIS_URL: redisUrl,
      OBJECT_STORE: 'http',
      OBJECT_STORE_BASE_URL: objInfo.baseUrl,
      OBJECT_STORE_TOKEN: objInfo.token,
      FOOD_PHOTO_MOCK_DELAY_MS: '30',
      GLOBAL_AI_SLOTS: '2',
      DAILY_SCAN_LIMIT: '100',
      GLOBAL_DAILY_SCAN_LIMIT: '1000',
      MAX_ASYNC_QUEUE: '100',
      // Force queue path so restart durability (not inline) is under test.
      INLINE_FAST_PATH: '0',
    });

    const stack = await createAsyncStack(baseConfig, { redis, objectStore });
    const server = createServer(baseConfig, { asyncStack: stack });
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    await server.asyncReady;
    const base = `http://127.0.0.1:${server.address().port}`;

    const mockAdapter = buildWorkerMockAdapter(baseConfig);
    const worker = createWorkerRuntime({
      config: stack.asyncConfig,
      jobStore: stack.jobStore,
      objectStore: stack.objectStore,
      aiSlots: stack.aiSlots,
      circuit: stack.circuit,
      budget: stack.budget,
      mockAdapter,
      workerId: 'redis-worker',
    });

    try {
      const idempotencyKey = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      const res = await fetch(`${base}/v1/food/photo-analyze`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: AUTH,
          'X-WeekFit-Subscription-JWS': DEV_SUB,
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({ imageBase64: jpegB64, mimeType: 'image/jpeg', locale: 'en_US' }),
      });
      assert.equal(res.status, 202);
      const accepted = await res.json();
      const analysisId = accepted.analysisId;
      assert.match(analysisId, /^[0-9a-f-]{36}$/);
      assert.notEqual(analysisId, idempotencyKey);

      // Simulate API process restart: new server, same Redis + object store.
      await new Promise((r) => server.close(r));
      const stack2 = await createAsyncStack(baseConfig, { redis, objectStore });
      const server2 = createServer(baseConfig, { asyncStack: stack2 });
      await new Promise((r) => server2.listen(0, '127.0.0.1', r));
      await server2.asyncReady;
      const base2 = `http://127.0.0.1:${server2.address().port}`;

      // Job still queued in Redis after API restart.
      const job = await stack2.jobStore.getJob(analysisId);
      assert.equal(job.status, 'queued');

      let done = false;
      for (let i = 0; i < 40 && !done; i += 1) {
        done = await worker.tick();
        if (!done) await new Promise((r) => setTimeout(r, 20));
      }
      assert.equal(done, true);
      assert.equal(mockAdapter.metrics().calls, 1);
      assert.equal(mockAdapter.metrics().realFetchAttempts, 0);

      const status = await (await fetch(`${base2}/v1/food/photo-analyze/${analysisId}`, {
        headers: { Authorization: AUTH },
      })).json();
      assert.equal(status.status, 'completed');

      // Idempotent replay must not charge quota again or call AI again.
      const snap = await stack2.quota.snapshot('local-developer');
      const replay = await fetch(`${base2}/v1/food/photo-analyze`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: AUTH,
          'X-WeekFit-Subscription-JWS': DEV_SUB,
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({ imageBase64: jpegB64, mimeType: 'image/jpeg', locale: 'en_US' }),
      });
      assert.ok(replay.status === 200 || replay.status === 202);
      assert.equal(mockAdapter.metrics().calls, 1);
      const snap2 = await stack2.quota.snapshot('local-developer');
      assert.equal(snap2.userCount, snap.userCount);

      await new Promise((r) => server2.close(r));
    } finally {
      await new Promise(r => server.close(r));
      await objInfo.close();
    }
  });
});

test('production config rejects file DATA_DIR backend', () => {
  assert.throws(
    () => configuration({
      NODE_ENV: 'production',
      ASYNC_ANALYSIS: '1',
      STATE_BACKEND: 'file',
      DATA_DIR: '/tmp/x',
      OPENAI_API_KEY: 'sk-test',
      FIREBASE_PROJECT_ID: 'weekfitai',
      ALLOW_DEV_AUTH: '0',
    }),
    /REDIS_URL|redis/i,
  );
});

test('production single-node escape hatch allows file DATA_DIR', () => {
  const c = configuration({
    NODE_ENV: 'production',
    ASYNC_ANALYSIS: '1',
    ALLOW_SINGLE_NODE_ASYNC: '1',
    STATE_BACKEND: 'file',
    OBJECT_STORE: 'local',
    DATA_DIR: '/tmp/x',
    OPENAI_API_KEY: 'sk-test',
    FIREBASE_PROJECT_ID: 'weekfitai',
    ALLOW_DEV_AUTH: '0',
  });
  assert.equal(c.asyncEnabled, true);
  assert.equal(c.stateBackend, 'file');
  assert.equal(c.objectStoreKind, 'local');
});

test('idle blocking queue wait never stalls lease/quota/health commands', async () => {
  await withRedis(async ({ redis }) => {
    const store = await createRedisJobStore({ redis });
    const waiting = store.claimNext({ workerId: 'idle-worker', leaseMs: 10000, waitMs: 1000 });
    await new Promise(resolve => setTimeout(resolve, 50));
    const start = Date.now();
    assert.equal(await redis.ping(), 'PONG');
    assert.ok(Date.now() - start < 500, 'PING must not wait behind BRPOP');
    await waiting;
  });
});

test('worker crash immediately after queue pop leaves a recoverable lease', async () => {
  await withRedis(async ({ redis }) => {
    const store = await createRedisJobStore({ redis });
    const id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    await store.createQueuedJob({ analysisId: id, userId: 'alice' });
    await store.enqueue(id);
    const broken = Object.create(redis);
    broken.eval = async (...args) => { await redis.eval(...args); throw Error('simulated crash after pop'); };
    const crashingWorker = await createRedisJobStore({ redis: broken });
    await assert.rejects(() => crashingWorker.claimNext({ workerId: 'crashed', leaseMs: 1000 }));
    assert.equal(await store.queueDepth(), 0);
    await store.recoverExpiredLeases(Date.now() + 2000);
    assert.equal(await store.queueDepth(), 1);
    assert.equal((await store.claimNext({ workerId: 'replacement', leaseMs: 1000 })).analysisId, id);
  });
});
