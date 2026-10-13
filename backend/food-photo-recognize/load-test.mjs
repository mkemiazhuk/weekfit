#!/usr/bin/env node
/**
 * Local load tests for food-photo-recognize.
 * ALWAYS runs with OPENAI_MOCK=1 — zero real OpenAI network calls.
 *
 *   node load-test.mjs
 */
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { createServer, configuration } from './server.mjs';
import { createMockOpenAIAdapter } from './openai-mock.mjs';

const jpeg = Buffer.from([
  255, 216, 255, 192, 0, 17, 8, 0, 100, 0, 100, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0, 255, 217,
]).toString('base64');

const DEV_TOKEN = 'weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

function summarize(latenciesMs, statuses, wallMs, adapterMetrics, label, mem = null) {
  const sorted = [...latenciesMs].sort((a, b) => a - b);
  const ok = statuses.filter((s) => s === 200).length;
  const busy = statuses.filter((s) => s === 503).length;
  const limited = statuses.filter((s) => s === 429).length;
  const subRequired = statuses.filter((s) => s === 402).length;
  const other = statuses.length - ok - busy - limited - subRequired;
  const throughput = wallMs > 0 ? (statuses.length / (wallMs / 1000)) : 0;
  return {
    label,
    concurrency: statuses.length,
    wallMs: Math.round(wallMs),
    throughputRps: Number(throughput.toFixed(2)),
    ok,
    busy503: busy,
    limited429: limited,
    subscription402: subRequired,
    otherErrors: other,
    p50: Math.round(percentile(sorted, 50)),
    p95: Math.round(percentile(sorted, 95)),
    p99: Math.round(percentile(sorted, 99)),
    aiCalls: adapterMetrics.calls,
    aiPeakParallel: adapterMetrics.peakParallelism,
    realFetchAttempts: adapterMetrics.realFetchAttempts,
    rssMb: mem ? Number((mem.rss / (1024 * 1024)).toFixed(1)) : null,
    heapMb: mem ? Number((mem.heapUsed / (1024 * 1024)).toFixed(1)) : null,
  };
}

function assertOk(cond, message = 'assertion failed') {
  if (!cond) throw new Error(message);
}

async function startServer({
  delayMs = 40,
  maxConcurrency = 4,
  maxQueue = 16,
  queueWaitMs = 2000,
  dailyLimit = 1000,
  globalDailyLimit = 100_000,
  scenario = 'ok',
} = {}) {
  const adapter = createMockOpenAIAdapter({ delayMs, scenario });
  const config = configuration({
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: DEV_TOKEN,
    OPENAI_MOCK: '1',
    FOOD_PHOTO_MOCK_DELAY_MS: String(delayMs),
    FOOD_PHOTO_MOCK_SCENARIO: scenario,
    MAX_CONCURRENT_SCANS: String(maxConcurrency),
    MAX_AI_QUEUE: String(maxQueue),
    AI_QUEUE_WAIT_MS: String(queueWaitMs),
    DAILY_SCAN_LIMIT: String(dailyLimit),
    GLOBAL_DAILY_SCAN_LIMIT: String(globalDailyLimit),
    BUSY_RETRY_AFTER_SECONDS: '2',
  });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { server, base, adapter, config };
}

async function postRecognize(base, {
  idempotencyKey,
  omitSubscription = false,
  signal,
} = {}) {
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${DEV_TOKEN}`,
  };
  if (!omitSubscription) headers['X-WeekFit-Subscription-JWS'] = DEV_SUB;
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
  const started = performance.now();
  try {
    const res = await fetch(`${base}/v1/food/photo-recognize`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US' }),
      signal,
    });
    return { status: res.status, latencyMs: performance.now() - started, headers: res.headers };
  } catch (error) {
    return {
      status: error.name === 'AbortError' ? 'aborted' : 'network_error',
      latencyMs: performance.now() - started,
      error,
    };
  }
}

async function burst(base, n, options = {}) {
  const wallStart = performance.now();
  const results = await Promise.all(
    Array.from({ length: n }, (_, i) => postRecognize(base, {
      idempotencyKey: options.sharedIdempotency ? 'shared-load-key' : options.uniqueIdempotency ? `k-${i}` : undefined,
      omitSubscription: options.omitSubscription,
    })),
  );
  const wallMs = performance.now() - wallStart;
  return { results, wallMs };
}

async function ramp(base, steps) {
  const all = [];
  const wallStart = performance.now();
  for (const n of steps) {
    const batch = await Promise.all(Array.from({ length: n }, () => postRecognize(base)));
    all.push(...batch);
  }
  return { results: all, wallMs: performance.now() - wallStart };
}

async function sustained(base, { rps, seconds }) {
  const results = [];
  const wallStart = performance.now();
  const end = wallStart + seconds * 1000;
  const interval = 1000 / rps;
  const pending = [];
  while (performance.now() < end) {
    pending.push(postRecognize(base));
    await new Promise((r) => setTimeout(r, interval));
  }
  results.push(...await Promise.all(pending));
  return { results, wallMs: performance.now() - wallStart };
}

function printTable(rows) {
  const cols = [
    'label', 'concurrency', 'ok', 'busy503', 'limited429', 'p50', 'p95', 'p99',
    'throughputRps', 'aiCalls', 'aiPeakParallel', 'realFetchAttempts', 'rssMb', 'heapMb', 'wallMs',
  ];
  console.log(cols.join('\t'));
  for (const row of rows) {
    console.log(cols.map((c) => row[c]).join('\t'));
  }
}

export async function runLoadSuite() {
  const rows = [];
  let totalRealFetches = 0;

  for (const n of [1, 10, 25, 50, 100]) {
    const { server, base, adapter } = await startServer({
      delayMs: 40,
      maxConcurrency: 4,
      maxQueue: 20,
      queueWaitMs: 3000,
    });
    try {
      assertOk((await fetch(`${base}/healthz`)).status === 200);
      const healthProbe = [];
      const healthTimer = setInterval(async () => {
        try {
          const h = await fetch(`${base}/healthz`);
          healthProbe.push(h.status);
        } catch {
          healthProbe.push(0);
        }
      }, 50);

      const { results, wallMs } = await burst(base, n);
      clearInterval(healthTimer);
      assertOk(healthProbe.length === 0 || healthProbe.every((s) => s === 200), `healthz failed under concurrency=${n}`);

      const summary = summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        `burst_${n}`,
        process.memoryUsage(),
      );
      rows.push(summary);
      totalRealFetches += adapter.metrics().realFetchAttempts;
      assertOk(adapter.metrics().realFetchAttempts === 0);
      assertOk(adapter.metrics().peakParallelism <= 4, `peak AI ${adapter.metrics().peakParallelism} > 4`);
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 30, maxConcurrency: 4, maxQueue: 24 });
    try {
      const { results, wallMs } = await ramp(base, [1, 5, 10, 20, 40]);
      rows.push(summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'ramp_1_5_10_20_40',
      ));
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 40, maxConcurrency: 4, maxQueue: 24 });
    try {
      const { results, wallMs } = await sustained(base, { rps: 8, seconds: 3 });
      rows.push(summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'sustained_8rps_3s',
      ));
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({
      delayMs: 200,
      maxConcurrency: 2,
      maxQueue: 2,
      queueWaitMs: 50,
    });
    try {
      const { results, wallMs } = await burst(base, 40);
      const summary = summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'spike_overload_40',
      );
      rows.push(summary);
      assertOk(summary.busy503 > 0, 'expected overload 503s');
      const sampleBusy = results.find((r) => r.status === 503);
      assertOk(sampleBusy?.headers?.get('retry-after'), 'missing Retry-After');
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 10 });
    try {
      const { results, wallMs } = await burst(base, 10, { omitSubscription: true });
      const summary = summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'no_subscription_10',
      );
      rows.push(summary);
      assertOk(summary.subscription402 === 10);
      assertOk(adapter.metrics().calls === 0);
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 80, maxConcurrency: 4 });
    try {
      const { results, wallMs } = await burst(base, 25, { sharedIdempotency: true });
      const summary = summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'idempotent_25_same_key',
      );
      rows.push(summary);
      assertOk(adapter.metrics().calls === 1, `expected 1 AI call, got ${adapter.metrics().calls}`);
      assertOk(summary.ok === 25);
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 500, maxConcurrency: 2 });
    try {
      const controller = new AbortController();
      const pending = postRecognize(base, { signal: controller.signal });
      await new Promise((r) => setTimeout(r, 30));
      controller.abort();
      const aborted = await pending;
      assertOk(aborted.status === 'aborted' || aborted.status === 499 || aborted.status === 504);
      assertOk((await fetch(`${base}/healthz`)).status === 200);
      totalRealFetches += adapter.metrics().realFetchAttempts;
      rows.push({
        label: 'client_cancel',
        concurrency: 1,
        ok: 0,
        busy503: 0,
        limited429: 0,
        p50: Math.round(aborted.latencyMs),
        p95: Math.round(aborted.latencyMs),
        p99: Math.round(aborted.latencyMs),
        throughputRps: 0,
        aiCalls: adapter.metrics().calls,
        aiPeakParallel: adapter.metrics().peakParallelism,
        realFetchAttempts: adapter.metrics().realFetchAttempts,
        wallMs: Math.round(aborted.latencyMs),
        subscription402: 0,
        otherErrors: 1,
      });
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({
      delayMs: 5,
      maxConcurrency: 4,
      dailyLimit: 3,
      globalDailyLimit: 3,
    });
    try {
      const { results, wallMs } = await burst(base, 8, { uniqueIdempotency: true });
      const summary = summarize(
        results.map((r) => r.latencyMs),
        results.map((r) => r.status),
        wallMs,
        adapter.metrics(),
        'daily_limit_overflow',
      );
      rows.push(summary);
      assertOk(summary.ok === 3);
      assertOk(summary.limited429 === 5);
      assertOk(adapter.metrics().calls === 3);
      totalRealFetches += adapter.metrics().realFetchAttempts;
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  console.log('\n=== WeekFit food-photo load results (OPENAI_MOCK=1) ===\n');
  printTable(rows);
  console.log(`\nTotal real OpenAI fetch attempts across suite: ${totalRealFetches}`);
  assertOk(totalRealFetches === 0, 'REAL OPENAI CALLS DETECTED');

  return { rows, totalRealFetches };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runLoadSuite().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
