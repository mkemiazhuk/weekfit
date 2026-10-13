import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createConcurrencyGate } from './concurrency.mjs';
import {
  createIdempotencyStore,
  normalizeIdempotencyKey,
  fingerprintPayload,
} from './idempotency.mjs';
import { createMockOpenAIAdapter } from './openai-mock.mjs';
import { recognize, validateInput } from './recognition.mjs';
import { configuration, createServer } from './server.mjs';

const jpeg = Buffer.from([255, 216, 255, 192, 0, 17, 8, 0, 100, 0, 100, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0, 255, 217]).toString('base64');
const jpegAlt = Buffer.from([255, 216, 255, 192, 0, 17, 8, 0, 101, 0, 101, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0, 255, 217]).toString('base64');
const input = () => ({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US' });
const inputAlt = () => ({ imageBase64: jpegAlt, mimeType: 'image/jpeg', locale: 'en_US' });
const DEV_SUB = 'weekfit-dev-local-subscription';
const AUTH = 'Bearer weekfit-dev-local-token';
const FP = fingerprintPayload(jpeg);
const FP_ALT = fingerprintPayload(jpegAlt);

function mockConfig(overrides = {}) {
  return {
    ...configuration({
      ALLOW_DEV_AUTH: '1',
      WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
      OPENAI_MOCK: '1',
      FOOD_PHOTO_MOCK_DELAY_MS: '30',
      DAILY_SCAN_LIMIT: '1000',
      GLOBAL_DAILY_SCAN_LIMIT: '10000',
      MAX_CONCURRENT_SCANS: '2',
      MAX_AI_QUEUE: '4',
      AI_QUEUE_WAIT_MS: '2000',
      BUSY_RETRY_AFTER_SECONDS: '3',
      MAX_CONCURRENT_UPLOADS: '4',
      MAX_UPLOAD_QUEUE: '8',
      ...overrides,
    }),
  };
}

async function listen(server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

test('concurrency gate queues then times out with Retry-After metadata', async () => {
  const gate = createConcurrencyGate({
    maxConcurrent: 1,
    maxQueue: 1,
    queueWaitMs: 40,
    retryAfterSeconds: 7,
  });
  const t1 = await gate.acquire();
  assert.equal(typeof t1.queueWaitMs, 'number');
  const waiting = gate.acquire();
  assert.throws(
    () => gate.acquire(),
    (e) => e.code === 'server_busy' && e.retryAfterSeconds === 7,
  );
  await assert.rejects(() => waiting, (e) => e.code === 'server_busy' && e.detail === 'ai_queue_timeout');
  t1.release();
});

test('idempotency coalesces concurrent work and caches success', async () => {
  const store = createIdempotencyStore({ ttlMs: 60_000 });
  let runs = 0;
  const work = async () => {
    runs += 1;
    await new Promise((r) => setTimeout(r, 30));
    return { ok: true, runs };
  };
  const [a, b] = await Promise.all([
    store.run('u1', 'key-a', FP, work),
    store.run('u1', 'key-a', FP, work),
  ]);
  assert.equal(runs, 1);
  assert.deepEqual(a.value, b.value);
  const c = await store.run('u1', 'key-a', FP, work);
  assert.equal(runs, 1);
  assert.equal(c.fromCache, true);
  assert.equal(c.value.ok, true);
  assert.equal(normalizeIdempotencyKey('  abc-1_2  '), 'abc-1_2');
  assert.equal(normalizeIdempotencyKey('bad key!'), null);
});

test('idempotency rejects same key with different fingerprint', async () => {
  const store = createIdempotencyStore({ ttlMs: 60_000 });
  await store.run('u1', 'key-b', FP, async () => ({ v: 1 }));
  await assert.rejects(
    () => store.run('u1', 'key-b', FP_ALT, async () => ({ v: 2 })),
    (e) => e.code === 'idempotency_key_reuse' && e.status === 409,
  );
});

test('failed idempotency attempt clears in-progress key', async () => {
  const store = createIdempotencyStore({ ttlMs: 60_000 });
  await assert.rejects(
    () => store.run('u1', 'fail-key', FP, async () => {
      throw new Error('boom');
    }),
  );
  assert.equal(store.get('u1', 'fail-key'), undefined);
  let runs = 0;
  const ok = await store.run('u1', 'fail-key', FP, async () => {
    runs += 1;
    return { ok: true };
  });
  assert.equal(runs, 1);
  assert.equal(ok.value.ok, true);
});

test('cancelling one waiter does not abort shared analysis for others', async () => {
  const store = createIdempotencyStore({ ttlMs: 60_000 });
  let started = 0;
  let finished = 0;
  const work = async ({ abortSignal }) => {
    started += 1;
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        finished += 1;
        resolve({ ok: true });
      }, 80);
      abortSignal.addEventListener('abort', () => {
        clearTimeout(timer);
        reject(Object.assign(new Error('aborted'), { name: 'AbortError' }));
      }, { once: true });
    });
    return { ok: true };
  };

  let releaseA;
  const pA = store.run('u1', 'shared-cancel', FP, work, {
    onAttached: (h) => { releaseA = h.releaseWaiter; },
  });
  await new Promise((r) => setTimeout(r, 10));
  const pB = store.run('u1', 'shared-cancel', FP, work);
  await new Promise((r) => setTimeout(r, 10));
  // First client disconnects while second still waits — must not abort shared AI.
  releaseA();
  const b = await pB;
  assert.equal(started, 1);
  assert.equal(finished, 1);
  assert.equal(b.value.ok, true);
  // Lead client still receives the shared result (disconnect only dropped its waiter count).
  const a = await pA;
  assert.equal(a.value.ok, true);
});

test('mock adapter never opens network and tracks peak parallelism', async () => {
  const adapter = createMockOpenAIAdapter({ delayMs: 40, scenario: 'ok' });
  const config = { ...mockConfig(), apiKey: 'unused', openaiFetcher: adapter.fetcher, openAIMock: true, timeoutMs: 5000 };
  const parsed = validateInput(input());
  await Promise.all([
    recognize(parsed, config, adapter.fetcher),
    recognize(parsed, config, adapter.fetcher),
    recognize(parsed, config, adapter.fetcher),
  ]);
  const m = adapter.metrics();
  assert.equal(m.calls, 3);
  assert.equal(m.realFetchAttempts, 0);
  assert.ok(m.peakParallelism >= 2);
});

test('mock mode forbids falling back to real fetch', async () => {
  const config = { ...mockConfig(), openAIMock: true, openaiFetcher: undefined, apiKey: '' };
  delete config.openaiFetcher;
  await assert.rejects(
    () => recognize(validateInput(input()), { ...config, openaiFetcher: undefined }, undefined),
    (e) => e.code === 'openai_mock_required' || e.code === 'openai_mock_forbids_real_fetch',
  );
});

test('HTTP overload returns 503 with Retry-After; healthz stays up', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 120, scenario: 'ok' });
  const config = mockConfig({
    MAX_CONCURRENT_SCANS: '1',
    MAX_AI_QUEUE: '1',
    AI_QUEUE_WAIT_MS: '30',
    FOOD_PHOTO_MOCK_DELAY_MS: '120',
  });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const post = () => fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
    },
    body: JSON.stringify(input()),
  });

  const launched = Array.from({ length: 8 }, () => post());
  const healthDuring = await fetch(`${base}/healthz`);
  assert.equal(healthDuring.status, 200);
  const healthBody = await healthDuring.json();
  assert.equal(healthBody.ok, true);
  assert.equal(healthBody.openAIMock, true);
  assert.ok(healthBody.uploads);
  assert.ok(healthBody.timeouts?.requestTimeoutMs >= 120_000);

  const results = await Promise.all(launched);
  const statuses = results.map((r) => r.status);
  assert.ok(statuses.includes(200));
  assert.ok(statuses.includes(503));
  const busy = results.find((r) => r.status === 503);
  assert.equal(busy.headers.get('retry-after'), '3');
  assert.equal(adapter.metrics().realFetchAttempts, 0);
  assert.ok(adapter.metrics().peakParallelism <= 1);
});

test('idempotent retry does not double AI call or daily charge', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 20, scenario: 'ok' });
  const config = mockConfig({ DAILY_SCAN_LIMIT: '2', FOOD_PHOTO_MOCK_DELAY_MS: '20' });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const post = () => fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': 'analysis-same-1',
    },
    body: JSON.stringify(input()),
  });

  const [a, b] = await Promise.all([post(), post()]);
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.equal(adapter.metrics().calls, 1);
  assert.equal(server.weekfitInternals.getDailyCount(), 1);
  assert.equal(a.headers.get('x-weekfit-idempotent-hit') === '1'
    || b.headers.get('x-weekfit-idempotent-hit') === '1'
    || a.headers.get('x-weekfit-ai-ms') != null, true);

  const c = await post();
  assert.equal(c.status, 200);
  assert.equal(c.headers.get('x-weekfit-idempotent-hit'), '1');
  assert.equal(adapter.metrics().calls, 1);
  assert.equal(server.weekfitInternals.getDailyCount(), 1);
});

test('same idempotency key with different photo returns 409', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 10 });
  const config = mockConfig();
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const headers = {
    'Content-Type': 'application/json',
    Authorization: AUTH,
    'X-WeekFit-Subscription-JWS': DEV_SUB,
    'Idempotency-Key': 'reuse-conflict',
  };
  const a = await fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST', headers, body: JSON.stringify(input()),
  });
  assert.equal(a.status, 200);
  const b = await fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST', headers, body: JSON.stringify(inputAlt()),
  });
  assert.equal(b.status, 409);
  const body = await b.json();
  assert.equal(body.error, 'idempotency_key_reuse');
  assert.equal(adapter.metrics().calls, 1);
});

test('HTTP cancel of one shared client does not abort sibling waiters', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 400 });
  const config = mockConfig({ FOOD_PHOTO_MOCK_DELAY_MS: '400', MAX_CONCURRENT_SCANS: '2' });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const headers = {
    'Content-Type': 'application/json',
    Authorization: AUTH,
    'X-WeekFit-Subscription-JWS': DEV_SUB,
    'Idempotency-Key': 'shared-http-cancel',
  };
  const body = JSON.stringify(input());
  const ac = new AbortController();
  const first = fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST', headers, body, signal: ac.signal,
  });
  // Wait until first request is in-flight in the idempotency store.
  const deadline = Date.now() + 1000;
  while (Date.now() < deadline) {
    if (server.weekfitInternals.idempotency.get('local-developer', 'shared-http-cancel')?.status === 'inflight') {
      break;
    }
    await new Promise((r) => setTimeout(r, 10));
  }
  const second = fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST', headers, body,
  });
  // Ensure second waiter is registered before the first client disconnects.
  await new Promise((r) => setTimeout(r, 50));
  const entry = server.weekfitInternals.idempotency.get('local-developer', 'shared-http-cancel');
  assert.ok(entry?.waiters >= 2, `expected ≥2 waiters, got ${entry?.waiters}`);
  ac.abort();
  await assert.rejects(() => first);
  const res = await second;
  assert.equal(res.status, 200);
  assert.equal(adapter.metrics().calls, 1);
});

test('paid access still required before mock AI', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 5 });
  const config = mockConfig();
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const res = await fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
    },
    body: JSON.stringify(input()),
  });
  assert.equal(res.status, 402);
  assert.equal(adapter.metrics().calls, 0);
});

test('upload gate rejects when too many bodies are reading', async (t) => {
  const adapter = createMockOpenAIAdapter({ delayMs: 5 });
  const config = mockConfig({
    MAX_CONCURRENT_UPLOADS: '1',
    MAX_UPLOAD_QUEUE: '0',
    UPLOAD_QUEUE_WAIT_MS: '10',
  });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  const base = await listen(server);
  t.after(() => new Promise((resolve) => server.close(resolve)));

  // Slow chunked uploads hold the upload slot.
  const slowPost = () => new Promise((resolve) => {
    const url = new URL(`${base}/v1/food/photo-recognize`);
    const payload = JSON.stringify(input());
    const req = httpRequest(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: AUTH,
        'X-WeekFit-Subscription-JWS': DEV_SUB,
        'Content-Length': Buffer.byteLength(payload),
      },
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    // Send half, pause, then rest — keeps upload slot occupied.
    req.write(payload.slice(0, Math.floor(payload.length / 2)));
    setTimeout(() => {
      req.write(payload.slice(Math.floor(payload.length / 2)));
      req.end();
    }, 80);
  });

  const fast = () => fetch(`${base}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
    },
    body: JSON.stringify(input()),
  });

  const a = slowPost();
  await new Promise((r) => setTimeout(r, 15));
  const b = await fast();
  assert.equal(b.status, 503);
  assert.equal(b.headers.get('retry-after'), '3');
  const aRes = await a;
  assert.ok([200, 503].includes(aRes.status));
});

function httpRequest(url, options, callback) {
  return http.request(url, options, callback);
}
