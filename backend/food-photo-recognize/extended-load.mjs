#!/usr/bin/env node
/**
 * Extended Nutrition service audit load suite.
 * ALWAYS OPENAI_MOCK=1 — zero real OpenAI network calls.
 *
 *   node extended-load.mjs
 *   EXTENDED_LOAD_QUICK=1 node extended-load.mjs   # shorter sustained (60s)
 */
import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { createServer, configuration } from './server.mjs';
import { createMockOpenAIAdapter } from './openai-mock.mjs';

const DEV_TOKEN = 'weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';
const QUICK = process.env.EXTENDED_LOAD_QUICK === '1';
const SUSTAINED_SECONDS = QUICK ? 60 : 5 * 60;

/**
 * Valid JPEG of approximately `targetBytes` (EOI at end).
 * Uses multiple COM segments — a single JPEG segment length is uint16 (max ~64KiB).
 */
export function makeJpegBytes(targetBytes) {
  const sof = Buffer.from([
    0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x64, 0x00, 0x64,
    0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
  ]);
  const head = Buffer.from([0xFF, 0xD8]);
  const tail = Buffer.concat([sof, Buffer.from([0xFF, 0xD9])]);
  const maxPayload = 65533; // length field includes its own 2 bytes
  let remaining = Math.max(0, targetBytes - head.length - tail.length);
  const coms = [];
  while (remaining > 0) {
    if (remaining < 4) {
      // Fine-adjust with standalone RST markers (2 bytes, no length field).
      break;
    }
    let payload = Math.min(maxPayload, remaining - 4);
    const leftover = remaining - 4 - payload;
    if (leftover > 0 && leftover < 4 && payload + leftover <= maxPayload) {
      payload += leftover;
    }
    const seg = Buffer.alloc(4 + payload);
    seg[0] = 0xFF;
    seg[1] = 0xFE;
    seg.writeUInt16BE(payload + 2, 2);
    seg.fill(0x41, 4);
    coms.push(seg);
    remaining -= seg.length;
  }
  const rst = [];
  while (remaining >= 2) {
    rst.push(Buffer.from([0xFF, 0xD0]));
    remaining -= 2;
  }
  // If 1 byte left, shrink last COM payload by 1 and add nothing (or grow RST).
  let out = Buffer.concat([head, ...coms, ...rst, tail]);
  if (out.length === targetBytes + 1 && coms.length > 0) {
    const last = coms[coms.length - 1];
    if (last.length > 4) {
      const shrunk = last.subarray(0, last.length - 1);
      shrunk.writeUInt16BE(shrunk.length - 2, 2);
      coms[coms.length - 1] = shrunk;
      out = Buffer.concat([head, ...coms, ...rst, tail]);
    }
  }
  if (out.length !== targetBytes) {
    // Best-effort exact size: pad with extra COM of exact remainder when possible.
    const deficit = targetBytes - out.length;
    if (deficit >= 4 && deficit - 4 <= maxPayload) {
      const payload = deficit - 4;
      const seg = Buffer.alloc(deficit);
      seg[0] = 0xFF;
      seg[1] = 0xFE;
      seg.writeUInt16BE(payload + 2, 2);
      seg.fill(0x41, 4);
      out = Buffer.concat([head, ...coms, ...rst, seg, tail]);
    }
  }
  return out;
}

function percentile(sorted, p) {
  if (!sorted.length) return null;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return Math.round(sorted[idx]);
}

function latencyStats(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return {
    n: sorted.length,
    p50: percentile(sorted, 50),
    p95: percentile(sorted, 95),
    p99: percentile(sorted, 99),
    max: sorted.length ? Math.round(sorted[sorted.length - 1]) : null,
  };
}

function assertOk(cond, message = 'assertion failed') {
  if (!cond) throw new Error(message);
}

async function startServer({
  delayMs = 1000,
  maxConcurrency = 4,
  maxQueue = 16,
  queueWaitMs = 8000,
  maxUploads = 8,
  maxUploadQueue = 24,
  dailyLimit = 1000,
  globalDailyLimit = 100_000,
  bodyReadTimeoutMs = 30_000,
} = {}) {
  const adapter = createMockOpenAIAdapter({ delayMs, scenario: 'ok' });
  const config = configuration({
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: DEV_TOKEN,
    OPENAI_MOCK: '1',
    FOOD_PHOTO_MOCK_DELAY_MS: String(delayMs),
    MAX_CONCURRENT_SCANS: String(maxConcurrency),
    MAX_AI_QUEUE: String(maxQueue),
    AI_QUEUE_WAIT_MS: String(queueWaitMs),
    MAX_CONCURRENT_UPLOADS: String(maxUploads),
    MAX_UPLOAD_QUEUE: String(maxUploadQueue),
    BODY_READ_TIMEOUT_MS: String(bodyReadTimeoutMs),
    DAILY_SCAN_LIMIT: String(dailyLimit),
    GLOBAL_DAILY_SCAN_LIMIT: String(globalDailyLimit),
    BUSY_RETRY_AFTER_SECONDS: '5',
    OPENAI_TIMEOUT_MS: String(Math.max(90_000, delayMs + 30_000)),
  });
  const server = createServer(config, { mockAdapter: adapter, openaiFetcher: adapter.fetcher });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { server, base, adapter, config };
}

function tinyJpegB64() {
  return makeJpegBytes(64).toString('base64');
}

async function postRecognize(base, {
  imageBase64 = tinyJpegB64(),
  idempotencyKey,
  signal,
} = {}) {
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${DEV_TOKEN}`,
    'X-WeekFit-Subscription-JWS': DEV_SUB,
  };
  if (idempotencyKey) {
    headers['Idempotency-Key'] = idempotencyKey;
    headers['X-WeekFit-Analysis-Id'] = idempotencyKey;
  }
  const started = performance.now();
  try {
    const res = await fetch(`${base}/v1/food/photo-recognize`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ imageBase64, mimeType: 'image/jpeg', locale: 'en_US' }),
      signal,
    });
    const queueWaitMs = Number(res.headers.get('x-weekfit-queue-wait-ms') ?? NaN);
    const aiMs = Number(res.headers.get('x-weekfit-ai-ms') ?? NaN);
    const e2eHeader = Number(res.headers.get('x-weekfit-e2e-ms') ?? NaN);
    const idemHit = res.headers.get('x-weekfit-idempotent-hit') === '1';
    const retryAfter = res.headers.get('retry-after');
    // Drain body so sockets close promptly.
    await res.arrayBuffer().catch(() => null);
    return {
      status: res.status,
      e2eMs: performance.now() - started,
      serverE2eMs: Number.isFinite(e2eHeader) ? e2eHeader : null,
      queueWaitMs: Number.isFinite(queueWaitMs) ? queueWaitMs : null,
      aiMs: Number.isFinite(aiMs) ? aiMs : null,
      idemHit,
      retryAfter,
    };
  } catch (error) {
    return {
      status: error.name === 'AbortError' ? 'aborted' : 'network_error',
      e2eMs: performance.now() - started,
      queueWaitMs: null,
      aiMs: null,
      error,
    };
  }
}

function summarizeBurst(label, delayMs, concurrency, results, wallMs, adapter, memSamples = []) {
  const ok = results.filter((r) => r.status === 200);
  const busy = results.filter((r) => r.status === 503);
  const other = results.filter((r) => r.status !== 200 && r.status !== 503);
  return {
    label,
    delayMs,
    concurrency,
    wallMs: Math.round(wallMs),
    ok: ok.length,
    busy503: busy.length,
    otherErrors: other.length,
    // Successful path latency (exclude fast 503 sheds).
    successE2E: latencyStats(ok.map((r) => r.e2eMs)),
    successQueue: latencyStats(ok.map((r) => r.queueWaitMs).filter((v) => v != null)),
    successAI: latencyStats(ok.map((r) => r.aiMs).filter((v) => v != null)),
    // Fast rejects separately.
    rejectE2E: latencyStats(busy.map((r) => r.e2eMs)),
    // All statuses mixed (not for capacity claims).
    allE2E: latencyStats(results.map((r) => r.e2eMs)),
    aiCalls: adapter.metrics().calls,
    aiPeak: adapter.metrics().peakParallelism,
    realFetchAttempts: adapter.metrics().realFetchAttempts,
    rssMbMax: memSamples.length
      ? Number(Math.max(...memSamples.map((m) => m.rss / (1024 * 1024))).toFixed(1))
      : null,
    heapMbMax: memSamples.length
      ? Number(Math.max(...memSamples.map((m) => m.heapUsed / (1024 * 1024))).toFixed(1))
      : null,
  };
}

async function burstMatrix() {
  const delays = [1000, 5000, 20000];
  const concs = [4, 10, 25, 50, 100];
  const rows = [];
  for (const delayMs of delays) {
    for (const concurrency of concs) {
      const { server, base, adapter } = await startServer({
        delayMs,
        maxConcurrency: 4,
        maxQueue: 16,
        queueWaitMs: 8000,
      });
      try {
        const memSamples = [];
        const healthOk = [];
        const sampler = setInterval(() => {
          memSamples.push(process.memoryUsage());
        }, 200);
        const healthTimer = setInterval(async () => {
          try {
            const h = await fetch(`${base}/healthz`);
            healthOk.push(h.status === 200);
          } catch {
            healthOk.push(false);
          }
        }, 250);

        const wallStart = performance.now();
        const results = await Promise.all(
          Array.from({ length: concurrency }, (_, i) => postRecognize(base, {
            idempotencyKey: `burst-${delayMs}-${concurrency}-${i}`,
          })),
        );
        const wallMs = performance.now() - wallStart;
        clearInterval(sampler);
        clearInterval(healthTimer);

        assertOk(adapter.metrics().realFetchAttempts === 0);
        assertOk(adapter.metrics().peakParallelism <= 4, `AI peak ${adapter.metrics().peakParallelism} > 4`);
        assertOk(healthOk.every(Boolean), `healthz failed under delay=${delayMs} c=${concurrency}`);

        const row = summarizeBurst(
          `delay_${delayMs}_c_${concurrency}`,
          delayMs,
          concurrency,
          results,
          wallMs,
          adapter,
          memSamples,
        );
        rows.push(row);
        console.log(JSON.stringify({ phase: 'burst', ...row }));
      } finally {
        await new Promise((r) => server.close(r));
      }
    }
  }
  return rows;
}

async function sustainedLoad() {
  const delayMs = 1000;
  const { server, base, adapter } = await startServer({
    delayMs,
    maxConcurrency: 4,
    maxQueue: 16,
    queueWaitMs: 8000,
  });
  const results = [];
  const healthOk = [];
  const memSamples = [];
  const wallStart = performance.now();
  const end = wallStart + SUSTAINED_SECONDS * 1000;
  // Target ~2 RPS → below theoretical capacity ≈ 4 / 1s = 4 RPS at conc=4.
  const intervalMs = 500;
  let i = 0;
  const pending = [];

  const healthTimer = setInterval(async () => {
    try {
      const h = await fetch(`${base}/healthz`);
      healthOk.push(h.status === 200);
    } catch {
      healthOk.push(false);
    }
  }, 1000);
  const memTimer = setInterval(() => memSamples.push(process.memoryUsage()), 2000);

  try {
    while (performance.now() < end) {
      const idx = i++;
      pending.push(postRecognize(base, { idempotencyKey: `sust-${idx}` }).then((r) => {
        results.push(r);
      }));
      await new Promise((r) => setTimeout(r, intervalMs));
      // Bound in-flight client concurrency so the driver itself doesn't OOM.
      if (pending.length > 40) {
        await Promise.race(pending);
        for (let j = pending.length - 1; j >= 0; j -= 1) {
          // prune settled by re-wrapping — simpler: await all when over cap
        }
        if (pending.length > 40) {
          await Promise.all(pending.splice(0, 20));
        }
      }
    }
    await Promise.all(pending);
    const wallMs = performance.now() - wallStart;
    assertOk(adapter.metrics().realFetchAttempts === 0);
    assertOk(adapter.metrics().peakParallelism <= 4);
    assertOk(healthOk.every(Boolean), 'healthz failed during sustained load');

    const row = {
      ...summarizeBurst(
        `sustained_${SUSTAINED_SECONDS}s_2rps_delay_${delayMs}`,
        delayMs,
        results.length,
        results,
        wallMs,
        adapter,
        memSamples,
      ),
      healthProbes: healthOk.length,
      healthFailures: healthOk.filter((x) => !x).length,
    };
    console.log(JSON.stringify({ phase: 'sustained', ...row }));
    return row;
  } finally {
    clearInterval(healthTimer);
    clearInterval(memTimer);
    await new Promise((r) => server.close(r));
  }
}

function slowUpload(base, imageBytes, { chunkDelayMs = 30, chunkSize = 64 * 1024 } = {}) {
  const imageBase64 = imageBytes.toString('base64');
  const payload = JSON.stringify({ imageBase64, mimeType: 'image/jpeg', locale: 'en_US' });
  const body = Buffer.from(payload);
  return new Promise((resolve) => {
    const url = new URL(`${base}/v1/food/photo-recognize`);
    const started = performance.now();
    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${DEV_TOKEN}`,
        'X-WeekFit-Subscription-JWS': DEV_SUB,
        'Content-Length': body.length,
      },
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          e2eMs: performance.now() - started,
          bodyBytes: body.length,
          jpegBytes: imageBytes.length,
          response: Buffer.concat(chunks).toString('utf8').slice(0, 200),
        });
      });
    });
    req.on('error', (error) => {
      resolve({ status: 'network_error', e2eMs: performance.now() - started, error: String(error) });
    });

    let offset = 0;
    const writeNext = () => {
      if (offset >= body.length) {
        req.end();
        return;
      }
      const end = Math.min(offset + chunkSize, body.length);
      req.write(body.subarray(offset, end));
      offset = end;
      setTimeout(writeNext, chunkDelayMs);
    };
    writeNext();
  });
}

async function uploadSuite() {
  // Decoded JPEG sizes; base64+JSON body ≈ 4/3 × jpeg (+wrapper). ~8MiB jpeg → ~11–12MB JSON.
  const sizes = [
    { label: 'jpeg_1mb', jpegBytes: 1 * 1024 * 1024 },
    { label: 'jpeg_5mb', jpegBytes: 5 * 1024 * 1024 },
    { label: 'jpeg_~8mb_body_~12mb', jpegBytes: 8 * 1024 * 1024 - 1024 },
  ];
  const rows = [];

  for (const size of sizes) {
    const { server, base, adapter } = await startServer({
      delayMs: 200,
      maxConcurrency: 4,
      maxUploads: 4,
      maxUploadQueue: 8,
    });
    try {
      const jpeg = makeJpegBytes(size.jpegBytes);
      const memBefore = process.memoryUsage();
      const memSamples = [memBefore];
      const healthOk = [];
      const sampler = setInterval(() => memSamples.push(process.memoryUsage()), 100);
      const healthTimer = setInterval(async () => {
        try {
          healthOk.push((await fetch(`${base}/healthz`)).status === 200);
        } catch {
          healthOk.push(false);
        }
      }, 200);

      const wallStart = performance.now();
      // Slow parallel uploads (6) — upload gate=4 should bound memory growth.
      const results = await Promise.all(
        Array.from({ length: 6 }, () => slowUpload(base, jpeg, { chunkDelayMs: 20, chunkSize: 48 * 1024 })),
      );
      const wallMs = performance.now() - wallStart;
      clearInterval(sampler);
      clearInterval(healthTimer);

      const rss = memSamples.map((m) => m.rss / (1024 * 1024));
      const heap = memSamples.map((m) => m.heapUsed / (1024 * 1024));
      const row = {
        label: `upload_${size.label}`,
        jpegBytes: size.jpegBytes,
        approxBodyBytes: Math.round(size.jpegBytes * 4 / 3) + 64,
        parallel: 6,
        maxUploads: 4,
        ok: results.filter((r) => r.status === 200).length,
        busy503: results.filter((r) => r.status === 503).length,
        other: results.filter((r) => r.status !== 200 && r.status !== 503).length,
        wallMs: Math.round(wallMs),
        e2e: latencyStats(results.map((r) => r.e2eMs)),
        rssMbBefore: Number(rss[0].toFixed(1)),
        rssMbMax: Number(Math.max(...rss).toFixed(1)),
        rssMbAfter: Number(rss[rss.length - 1].toFixed(1)),
        heapMbMax: Number(Math.max(...heap).toFixed(1)),
        healthFailures: healthOk.filter((x) => !x).length,
        aiPeak: adapter.metrics().peakParallelism,
        realFetchAttempts: adapter.metrics().realFetchAttempts,
      };
      assertOk(adapter.metrics().realFetchAttempts === 0);
      assertOk(adapter.metrics().peakParallelism <= 4);
      assertOk(row.healthFailures === 0, `healthz failed during ${size.label}`);
      // RSS must not explode unboundedly: allow headroom for 4 concurrent ~12MB bodies + overhead.
      const rssGrowth = row.rssMbMax - row.rssMbBefore;
      assertOk(rssGrowth < 400, `uncontrolled RSS growth ${rssGrowth}MB for ${size.label}`);
      rows.push(row);
      console.log(JSON.stringify({ phase: 'upload', ...row }));
    } finally {
      await new Promise((r) => server.close(r));
    }
  }
  return rows;
}

async function idempotencyAndCancel() {
  const rows = [];
  {
    const { server, base, adapter } = await startServer({ delayMs: 300 });
    try {
      const key = 'idemp-complete-1';
      const a = await postRecognize(base, { idempotencyKey: key });
      const callsAfterFirst = adapter.metrics().calls;
      const b = await postRecognize(base, { idempotencyKey: key });
      assertOk(a.status === 200 && b.status === 200);
      assertOk(b.idemHit === true, 'expected idempotent cache hit');
      assertOk(adapter.metrics().calls === callsAfterFirst, 'retry after complete must not call AI again');
      rows.push({
        label: 'idempotent_replay_after_complete',
        ok: true,
        aiCalls: adapter.metrics().calls,
        realFetchAttempts: adapter.metrics().realFetchAttempts,
      });
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 50 });
    try {
      const key = 'idemp-conflict';
      const a = await postRecognize(base, {
        idempotencyKey: key,
        imageBase64: makeJpegBytes(128).toString('base64'),
      });
      const b = await postRecognize(base, {
        idempotencyKey: key,
        imageBase64: makeJpegBytes(256).toString('base64'),
      });
      assertOk(a.status === 200);
      assertOk(b.status === 409, `expected 409, got ${b.status}`);
      assertOk(adapter.metrics().calls === 1);
      rows.push({
        label: 'idempotent_key_different_photo_409',
        ok: true,
        aiCalls: adapter.metrics().calls,
      });
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    const { server, base, adapter } = await startServer({ delayMs: 500 });
    try {
      const key = 'shared-cancel-http';
      const ac = new AbortController();
      const first = postRecognize(base, { idempotencyKey: key, signal: ac.signal });
      const deadline = Date.now() + 2000;
      while (Date.now() < deadline) {
        if (server.weekfitInternals.idempotency.get('local-developer', key)?.status === 'inflight') break;
        await new Promise((r) => setTimeout(r, 10));
      }
      const second = postRecognize(base, { idempotencyKey: key });
      await new Promise((r) => setTimeout(r, 80));
      const entry = server.weekfitInternals.idempotency.get('local-developer', key);
      assertOk((entry?.waiters ?? 0) >= 2, `expected ≥2 waiters before cancel, got ${entry?.waiters}`);
      ac.abort();
      const a = await first;
      const b = await second;
      assertOk(a.status === 'aborted');
      assertOk(b.status === 200, `sibling should complete, got ${b.status}`);
      assertOk(adapter.metrics().calls === 1);
      rows.push({
        label: 'cancel_one_keeps_shared_analysis',
        ok: true,
        aiCalls: adapter.metrics().calls,
      });
    } finally {
      await new Promise((r) => server.close(r));
    }
  }

  {
    // Error clears in-progress; restart loses process-local cache.
    const { server, base, adapter } = await startServer({
      delayMs: 10,
    });
    // Force mock timeout scenario via adapter swap is heavy; use a throwing recognize dep instead.
    await new Promise((r) => server.close(r));

    const failAdapter = createMockOpenAIAdapter({ delayMs: 20, scenario: 'server_error' });
    const config = configuration({
      ALLOW_DEV_AUTH: '1',
      WEEKFIT_DEV_TOKEN: DEV_TOKEN,
      OPENAI_MOCK: '1',
      FOOD_PHOTO_MOCK_DELAY_MS: '20',
      FOOD_PHOTO_MOCK_SCENARIO: 'server_error',
      DAILY_SCAN_LIMIT: '100',
      GLOBAL_DAILY_SCAN_LIMIT: '1000',
    });
    const failServer = createServer(config, { mockAdapter: failAdapter, openaiFetcher: failAdapter.fetcher });
    await new Promise((resolve) => failServer.listen(0, '127.0.0.1', resolve));
    const failBase = `http://127.0.0.1:${failServer.address().port}`;
    try {
      const key = 'fail-clear';
      const a = await postRecognize(failBase, { idempotencyKey: key });
      assertOk(a.status >= 500 || a.status === 502, `expected provider error, got ${a.status}`);
      assertOk(failServer.weekfitInternals.idempotency.get('local-developer', key) === undefined);

      // Process restart simulation: new server, same key → new AI attempt (process-local limit).
      await new Promise((r) => failServer.close(r));
      const okAdapter = createMockOpenAIAdapter({ delayMs: 20, scenario: 'ok' });
      const okConfig = configuration({
        ALLOW_DEV_AUTH: '1',
        WEEKFIT_DEV_TOKEN: DEV_TOKEN,
        OPENAI_MOCK: '1',
        FOOD_PHOTO_MOCK_DELAY_MS: '20',
        DAILY_SCAN_LIMIT: '100',
        GLOBAL_DAILY_SCAN_LIMIT: '1000',
      });
      const okServer = createServer(okConfig, { mockAdapter: okAdapter, openaiFetcher: okAdapter.fetcher });
      await new Promise((resolve) => okServer.listen(0, '127.0.0.1', resolve));
      const okBase = `http://127.0.0.1:${okServer.address().port}`;
      try {
        const b = await postRecognize(okBase, { idempotencyKey: key });
        assertOk(b.status === 200);
        assertOk(okAdapter.metrics().calls === 1, 'after restart cache is empty — new AI call expected');
        rows.push({
          label: 'error_clears_inflight_restart_loses_cache',
          ok: true,
          note: 'idempotency is process-local; restart drops cache and in-flight state',
          aiCallsAfterRestart: okAdapter.metrics().calls,
        });
      } finally {
        await new Promise((r) => okServer.close(r));
      }
    } catch (error) {
      try { await new Promise((r) => failServer.close(r)); } catch { /* ignore */ }
      throw error;
    }
  }

  console.log(JSON.stringify({ phase: 'idempotency', rows }));
  return rows;
}

async function timeoutProbe() {
  const { server, base } = await startServer({ delayMs: 50 });
  try {
    const health = await (await fetch(`${base}/healthz`)).json();
    const row = {
      label: 'timeout_config',
      bodyReadTimeoutMs: health.timeouts.bodyReadTimeoutMs,
      queueWaitMs: health.timeouts.queueWaitMs,
      openaiTimeoutMs: health.timeouts.openaiTimeoutMs,
      requestTimeoutMs: health.timeouts.requestTimeoutMs,
      headersTimeoutMs: health.timeouts.headersTimeoutMs,
      iosOverallDeadlineSeconds: 105,
      note: 'requestTimeout is Node incomplete-request / idle budget, not full AI e2e; iOS caps at 105s task-group deadline above server OPENAI_TIMEOUT_MS (90s)',
    };
    assertOk(health.timeouts.requestTimeoutMs >= health.timeouts.openaiTimeoutMs);
    assertOk(105_000 > health.timeouts.openaiTimeoutMs);
    console.log(JSON.stringify({ phase: 'timeouts', ...row }));
    return row;
  } finally {
    await new Promise((r) => server.close(r));
  }
}

export async function runExtendedLoad() {
  const phases = new Set(
    (process.env.EXTENDED_LOAD_PHASES ?? 'burst,sustained,upload,idempotency,timeouts')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
  console.log(JSON.stringify({
    phase: 'start',
    openAIMock: true,
    sustainedSeconds: SUSTAINED_SECONDS,
    quick: QUICK,
    phases: [...phases],
  }));

  const burst = phases.has('burst') ? await burstMatrix() : [];
  const sustained = phases.has('sustained') ? await sustainedLoad() : null;
  const uploads = phases.has('upload') ? await uploadSuite() : [];
  const idempotency = phases.has('idempotency') ? await idempotencyAndCancel() : [];
  const timeouts = phases.has('timeouts') ? await timeoutProbe() : null;

  const totalReal = [...burst, ...(sustained ? [sustained] : []), ...uploads]
    .reduce((n, r) => n + (r.realFetchAttempts ?? 0), 0);
  assertOk(totalReal === 0, 'REAL OPENAI CALLS DETECTED');

  // Merge prior full-run burst/sustained if this is a partial re-run.
  let prior = null;
  const priorPath = new URL('./extended-load-results.json', import.meta.url);
  if (existsSync(priorPath)) {
    try { prior = JSON.parse(readFileSync(priorPath, 'utf8')); } catch { /* ignore */ }
  }

  const report = {
    generatedAt: new Date().toISOString(),
    openAIMock: true,
    realOpenAIFetchAttempts: totalReal,
    sustainedSeconds: SUSTAINED_SECONDS,
    burst: burst.length ? burst : (prior?.burst ?? []),
    sustained: sustained ?? prior?.sustained ?? null,
    uploads,
    idempotency,
    timeouts: timeouts ?? prior?.timeouts ?? null,
    capacityRationale: {
      maxConcurrentScans: 4,
      maxAiQueue: 16,
      queueWaitMs: 8000,
      reasoning: [
        'At mock AI=1s, theoretical completion ≈ 4 RPS; sustained ~2 RPS stayed healthy with queue room.',
        'At AI=5s/20s, bursts of 25–100 mostly shed via 503 once active+queue (4+16) are full — queue size bounds waiters, not throughput.',
        'Upload gate (default 8) is separate so multi-MB bodies cannot pin all AI slots or grow RSS without bound.',
        'Not production-ready proof: Render multi-instance + real OpenAI latency/TPM/$ remain unverified.',
      ],
    },
  };

  writeFileSync(
    new URL('./extended-load-results.json', import.meta.url),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log('\n=== Extended load complete (OPENAI_MOCK=1) ===');
  console.log(`Real OpenAI fetch attempts: ${totalReal}`);
  console.log('Wrote extended-load-results.json');
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runExtendedLoad().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
