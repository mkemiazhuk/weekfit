#!/usr/bin/env node
/**
 * Distributed-state load suite: mini-Redis + HTTP object store + mock OpenAI.
 * No paid cloud resources. Real OpenAI calls = 0.
 *
 *   node redis-load.mjs
 *   REDIS_LOAD_QUICK=1 node redis-load.mjs
 */
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { randomUUID } from 'node:crypto';
import { createMiniRedisServer } from './async/mini-redis.mjs';
import { createHttpObjectStoreServer } from './async/http-object-store.mjs';
import { makeJpegBytes } from './extended-load.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const QUICK = process.env.REDIS_LOAD_QUICK === '1';
const BURST_N = QUICK ? 100 : Number(process.env.REDIS_LOAD_N || 1000);
const DELAYS = (process.env.REDIS_LOAD_DELAYS || '1000,5000,20000')
  .split(',')
  .map((s) => Number(s.trim()))
  .filter((n) => Number.isFinite(n) && n > 0);
const DEV_TOKEN = 'weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';

function assertOk(cond, msg) {
  if (!cond) throw new Error(msg || 'assertion failed');
}

function percentile(sorted, p) {
  if (!sorted.length) return null;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return Math.round(sorted[idx]);
}

function stats(values) {
  const sorted = [...values].filter((v) => v != null).sort((a, b) => a - b);
  return {
    n: sorted.length,
    p50: percentile(sorted, 50),
    p95: percentile(sorted, 95),
    p99: percentile(sorted, 99),
    max: sorted.length ? Math.round(sorted[sorted.length - 1]) : null,
  };
}

async function waitHealth(base, timeoutMs = 20_000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    try {
      const res = await fetch(`${base}/healthz`);
      if (res.status === 200) {
        const body = await res.json();
        if (body.ok && body.asyncAnalysis) return body;
      }
    } catch { /* retry */ }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`healthz timeout ${base}`);
}

function spawnProc(script, env) {
  const child = spawn(process.execPath, [script], {
    cwd: __dirname,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.log = [];
  const onData = (b) => child.log.push(b.toString());
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);
  return child;
}

async function startFleet({
  redisUrl,
  objectBaseUrl,
  objectToken,
  delayMs,
  globalAiSlots = 8,
  apiCount = 2,
  workerCount = 4,
  basePort = 21080,
  workerLeaseMs = 180_000,
}) {
  // Long AI delays: keep lease > AI time but short enough that a dead worker recovers in one wave.
  const leaseMs = workerLeaseMs >= 180_000 && delayMs >= 10_000
    ? Math.max(45_000, delayMs * 2 + 15_000)
    : workerLeaseMs;
  const common = {
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: DEV_TOKEN,
    OPENAI_MOCK: '1',
    ASYNC_ANALYSIS: '1',
    STATE_BACKEND: 'redis',
    REDIS_URL: redisUrl,
    OBJECT_STORE: 'http',
    OBJECT_STORE_BASE_URL: objectBaseUrl,
    OBJECT_STORE_TOKEN: objectToken,
    FOOD_PHOTO_MOCK_DELAY_MS: String(delayMs),
    GLOBAL_AI_SLOTS: String(globalAiSlots),
    WORKER_LOCAL_CONCURRENCY: String(Math.max(1, Math.ceil(globalAiSlots / workerCount))),
    MAX_ASYNC_QUEUE: '5000',
    DAILY_SCAN_LIMIT: '100000',
    GLOBAL_DAILY_SCAN_LIMIT: '100000',
    MAX_CONCURRENT_UPLOADS: '256',
    MAX_UPLOAD_QUEUE: '1200',
    UPLOAD_QUEUE_WAIT_MS: '15000',
    WORKER_LEASE_MS: String(leaseMs),
    OPENAI_TIMEOUT_MS: String(Math.max(90_000, delayMs + 30_000)),
    DELETE_PHOTO_ON_COMPLETE: '1',
  };

  const apis = [];
  const workers = [];
  for (let i = 0; i < apiCount; i += 1) {
    const port = basePort + i;
    const child = spawnProc('server.mjs', { ...common, PORT: String(port) });
    apis.push({ child, port, base: `http://127.0.0.1:${port}` });
  }
  for (let i = 0; i < workerCount; i += 1) {
    workers.push({ child: spawnProc('worker.mjs', { ...common }) });
  }

  const stop = async () => {
    for (const w of workers) w.child.kill('SIGTERM');
    for (const a of apis) a.child.kill('SIGTERM');
    await new Promise((r) => setTimeout(r, 400));
    for (const x of [...workers, ...apis]) {
      try { x.child.kill('SIGKILL'); } catch { /* ignore */ }
    }
  };

  for (const api of apis) {
    try {
      await waitHealth(api.base);
    } catch (error) {
      const tail = (api.child.log || []).join('').slice(-1200);
      console.error(JSON.stringify({ phase: 'api_start_failed', port: api.port, tail }));
      await stop().catch(() => {});
      throw error;
    }
  }

  return { apis, workers, stop, common };
}

const tinyJpeg = () => makeJpegBytes(256).toString('base64');

async function submit(base, analysisId = randomUUID()) {
  const started = performance.now();
  const res = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${DEV_TOKEN}`,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': analysisId,
    },
    body: JSON.stringify({ imageBase64: tinyJpeg(), mimeType: 'image/jpeg', locale: 'en_US' }),
  });
  const body = await res.json().catch(() => ({}));
  return {
    status: res.status,
    acceptMs: performance.now() - started,
    analysisId: body.analysisId || analysisId,
  };
}

async function poll(base, analysisId, timeoutMs, { minDelayMs = 800, maxDelayMs = 8000 } = {}) {
  const started = performance.now();
  let delay = minDelayMs;
  while (performance.now() - started < timeoutMs) {
    try {
      const res = await fetch(`${base}/v1/food/photo-analyze/${analysisId}`, {
        headers: { Authorization: `Bearer ${DEV_TOKEN}` },
      });
      const body = await res.json();
      if (body.status === 'completed' || body.status === 'failed') {
        return {
          status: body.status,
          clientE2eMs: performance.now() - started,
          timings: body.timings || null,
          error: body.error,
        };
      }
    } catch { /* retry — storage blips */ }
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(maxDelayMs, Math.round(delay * 1.35));
  }
  return { status: 'poll_timeout', clientE2eMs: performance.now() - started };
}

async function runBurst(fleet, { n, delayMs, label }) {
  const wallStart = performance.now();
  const healthOk = [];
  const healthTimer = setInterval(async () => {
    try {
      healthOk.push((await fetch(`${fleet.apis[0].base}/healthz`)).status === 200);
    } catch { healthOk.push(false); }
  }, 500);

  const accepts = await Promise.all(
    Array.from({ length: n }, (_, i) => submit(fleet.apis[i % fleet.apis.length].base)),
  );
  const accepted = accepts.filter((a) => a.status === 202 || a.status === 200);
  const busy = accepts.filter((a) => a.status === 503);

  // Poll gently: 1000 aggressive pollers starve Redis claim/status and under-utilize AI slots.
  const theoreticalDrainMs = Math.ceil(n / 8) * delayMs;
  const pollTimeout = theoreticalDrainMs * 2 + delayMs * 10 + 600_000;
  const pollOpts = {
    minDelayMs: n >= 500 ? 2000 : 800,
    maxDelayMs: n >= 500 ? 12_000 : 8000,
  };
  // Stagger poll starts so status traffic does not spike as one thundering herd.
  const finals = await Promise.all(
    accepted.map(async (a, i) => {
      await new Promise((r) => setTimeout(r, (i % 50) * 40));
      return poll(fleet.apis[i % fleet.apis.length].base, a.analysisId, pollTimeout, pollOpts);
    }),
  );
  clearInterval(healthTimer);

  const completed = finals.filter((f) => f.status === 'completed');
  const failed = finals.filter((f) => f.status === 'failed');
  const lost = finals.filter((f) => f.status === 'poll_timeout');
  const queueWaits = completed.map((f) => f.timings?.queueWaitMs).filter((v) => v != null);
  const aiMs = completed.map((f) => f.timings?.aiMs).filter((v) => v != null);
  const e2e = completed.map((f) => f.timings?.e2eMs ?? f.clientE2eMs);

  const workerAlive = fleet.workers.filter((w) => w.child.exitCode == null && !w.child.killed).length;
  const row = {
    label,
    delayMs,
    n,
    acceptOk: accepted.length,
    busy503: busy.length,
    completed: completed.length,
    failed: failed.length,
    lost: lost.length,
    acceptLatency: stats(accepted.map((a) => a.acceptMs)),
    queueLatency: stats(queueWaits),
    aiLatency: stats(aiMs),
    e2eLatency: stats(e2e),
    burstWallMs: Math.round(performance.now() - wallStart),
    healthFailures: healthOk.filter((x) => !x).length,
    theoreticalDrainMs,
    workersAliveAtEnd: workerAlive,
    workersNeededForTargetWait: {
      finishIn60s: Math.ceil((n * (delayMs / 1000)) / 60),
      finishIn120s: Math.ceil((n * (delayMs / 1000)) / 120),
      finishIn300s: Math.ceil((n * (delayMs / 1000)) / 300),
    },
  };
  if (lost.length || workerAlive < fleet.workers.length) {
    for (const [i, w] of fleet.workers.entries()) {
      const tail = (w.child.log || []).join('').slice(-800);
      if (tail) console.error(JSON.stringify({ phase: 'worker_log_tail', i, exitCode: w.child.exitCode, tail }));
    }
  }
  assertOk(lost.length === 0, `${label}: lost ${lost.length} (failed=${failed.length}, workersAlive=${workerAlive})`);
  assertOk(row.healthFailures === 0, `${label}: healthz failed`);
  assertOk(accepted.length === n, `${label}: expected ${n} accepts, got ${accepted.length}`);
  console.log(JSON.stringify({ phase: 'burst', ...row }));
  return row;
}

async function runChaos(redisUrl, objectBaseUrl, objectToken, { setObjectPaused } = {}) {
  const rows = [];

  // --- A: worker kill + API kill; remaining API + lease recovery ---
  {
    const fleet = await startFleet({
      redisUrl,
      objectBaseUrl,
      objectToken,
      delayMs: 500,
      globalAiSlots: 4,
      workerCount: 2,
      apiCount: 2,
      basePort: 23000 + Math.floor(Math.random() * 400),
      workerLeaseMs: 5000,
    });
    try {
      const ids = await Promise.all(Array.from({ length: 30 }, () => submit(fleet.apis[0].base)));
      const accepted = ids.filter((a) => a.status === 202);
      assertOk(accepted.length >= 25);

      fleet.workers[0].child.kill('SIGKILL');
      fleet.apis[1].child.kill('SIGKILL');
      await new Promise((r) => setTimeout(r, 200));
      assertOk((await fetch(`${fleet.apis[0].base}/healthz`)).status === 200);

      const finals = await Promise.all(
        accepted.map((a) => poll(fleet.apis[0].base, a.analysisId, 180_000)),
      );
      const lost = finals.filter((f) => f.status === 'poll_timeout').length;
      assertOk(lost === 0, `chaos lost ${lost}`);
      const row = {
        label: 'chaos_worker_kill_api_kill_redis',
        accepted: accepted.length,
        completed: finals.filter((f) => f.status === 'completed').length,
        lost,
      };
      rows.push(row);
      console.log(JSON.stringify({ phase: 'chaos', ...row }));
    } finally {
      await fleet.stop();
    }
  }

  // --- B: brief object-store outage mid-drain; poll retries; jobs still complete ---
  if (typeof setObjectPaused === 'function') {
    const fleet = await startFleet({
      redisUrl,
      objectBaseUrl,
      objectToken,
      delayMs: 400,
      globalAiSlots: 4,
      workerCount: 2,
      apiCount: 1,
      basePort: 23500 + Math.floor(Math.random() * 400),
    });
    try {
      const ids = await Promise.all(Array.from({ length: 20 }, () => submit(fleet.apis[0].base)));
      const accepted = ids.filter((a) => a.status === 202);
      assertOk(accepted.length >= 15);
      setObjectPaused(true);
      await new Promise((r) => setTimeout(r, 1500));
      setObjectPaused(false);
      const finals = await Promise.all(
        accepted.map((a) => poll(fleet.apis[0].base, a.analysisId, 180_000)),
      );
      const lost = finals.filter((f) => f.status === 'poll_timeout').length;
      const completed = finals.filter((f) => f.status === 'completed').length;
      assertOk(lost === 0, `object-store chaos lost ${lost}`);
      assertOk(completed === accepted.length, `object-store chaos completed ${completed}/${accepted.length}`);
      const row = {
        label: 'chaos_object_store_blip',
        accepted: accepted.length,
        completed,
        lost,
      };
      rows.push(row);
      console.log(JSON.stringify({ phase: 'chaos', ...row }));
    } finally {
      setObjectPaused(false);
      await fleet.stop();
    }
  }

  // --- C: short lease expires after worker death → reclaim → complete ---
  {
    const leaseMs = 5000;
    const fleet = await startFleet({
      redisUrl,
      objectBaseUrl,
      objectToken,
      delayMs: 8000,
      globalAiSlots: 2,
      workerCount: 1,
      apiCount: 1,
      basePort: 24000 + Math.floor(Math.random() * 400),
      workerLeaseMs: leaseMs,
    });
    let accepted = [];
    try {
      const ids = await Promise.all(Array.from({ length: 8 }, () => submit(fleet.apis[0].base)));
      accepted = ids.filter((a) => a.status === 202);
      assertOk(accepted.length === 8);
      await new Promise((r) => setTimeout(r, 600));
      fleet.workers[0].child.kill('SIGKILL');
      await new Promise((r) => setTimeout(r, leaseMs + 1500));
    } finally {
      for (const w of fleet.workers) {
        try { w.child.kill('SIGKILL'); } catch { /* ignore */ }
      }
    }

    const replacement = spawnProc('worker.mjs', {
      ...fleet.common,
      FOOD_PHOTO_MOCK_DELAY_MS: '300',
      WORKER_LEASE_MS: '60000',
    });
    try {
      const finals = await Promise.all(
        accepted.map((a) => poll(fleet.apis[0].base, a.analysisId, 180_000)),
      );
      const lost = finals.filter((f) => f.status === 'poll_timeout').length;
      assertOk(lost === 0, `lease reclaim lost ${lost}`);
      const row = {
        label: 'chaos_lease_expire_reclaim',
        accepted: accepted.length,
        completed: finals.filter((f) => f.status === 'completed').length,
        lost,
      };
      rows.push(row);
      console.log(JSON.stringify({ phase: 'chaos', ...row }));
    } finally {
      try { replacement.kill('SIGTERM'); } catch { /* ignore */ }
      await fleet.stop();
    }
  }

  return rows;
}

export async function runRedisLoad() {
  const mini = createMiniRedisServer();
  const redisInfo = await mini.listen();
  const obj = createHttpObjectStoreServer();
  const objInfo = await obj.listen();

  const report = {
    generatedAt: new Date().toISOString(),
    backend: 'redis+http-object-store',
    openAIMock: true,
    realOpenAIFetchAttempts: 0,
    bursts: [],
    chaos: [],
    capacityGuidance: [],
    notes: [
      'Production forbids STATE_BACKEND=file / OBJECT_STORE=local.',
      'mini-Redis is protocol-compatible local stand-in; staging uses managed Redis.',
      'HTTP object store stands in for S3/R2 without paid buckets.',
    ],
  };

  console.log(JSON.stringify({
    phase: 'start',
    redisUrl: redisInfo.url,
    objectBaseUrl: objInfo.baseUrl,
    burstN: BURST_N,
  }));

  const writePartial = () => {
    writeFileSync(
      path.join(__dirname, 'redis-load-results.json'),
      `${JSON.stringify(report, null, 2)}\n`,
    );
  };

  try {
    for (const delayMs of DELAYS) {
      const fleet = await startFleet({
        redisUrl: redisInfo.url,
        objectBaseUrl: objInfo.baseUrl,
        objectToken: objInfo.token,
        delayMs,
        globalAiSlots: 8,
        workerCount: 4,
        apiCount: 2,
        basePort: 21100 + Math.floor(delayMs / 1000),
      });
      try {
        const row = await runBurst(fleet, {
          n: BURST_N,
          delayMs,
          label: `redis_burst_${BURST_N}_delay_${delayMs}_slots_8`,
        });
        report.bursts.push(row);
        report.capacityGuidance.push({
          delayMs,
          n: BURST_N,
          measuredBurstWallMs: row.burstWallMs,
          measuredQueueP95: row.queueLatency.p95,
          measuredE2eP95: row.e2eLatency.p95,
          slotsFor60s: row.workersNeededForTargetWait.finishIn60s,
          slotsFor120s: row.workersNeededForTargetWait.finishIn120s,
          slotsFor300s: row.workersNeededForTargetWait.finishIn300s,
          note: 'slots ≈ concurrent AI calls; pair with provider TPM/RPM caps and GLOBAL_AI_SLOTS',
        });
        writePartial();
      } finally {
        await fleet.stop();
        await new Promise((r) => setTimeout(r, 500));
      }
    }

    report.chaos = await runChaos(redisInfo.url, objInfo.baseUrl, objInfo.token, {
      setObjectPaused: objInfo.setPaused,
    });
    writePartial();
  } finally {
    await objInfo.close();
    await redisInfo.close();
  }

  writeFileSync(
    path.join(__dirname, 'redis-load-results.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log('\n=== Redis distributed load complete (OPENAI_MOCK=1) ===');
  console.log('Real OpenAI fetch attempts: 0');
  console.log('Wrote redis-load-results.json');
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runRedisLoad().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
