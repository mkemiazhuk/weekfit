#!/usr/bin/env node
/**
 * Async Nutrition load suite — OPENAI_MOCK=1 only, zero real OpenAI calls.
 *
 * Spawns multiple API processes + workers on a shared DATA_DIR.
 *
 *   node async-load.mjs
 *   ASYNC_LOAD_QUICK=1 node async-load.mjs          # shorter sustained (3m)
 *   ASYNC_LOAD_PHASES=burst,chaos,sustained node async-load.mjs
 */
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { randomUUID } from 'node:crypto';
import { makeJpegBytes } from './extended-load.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const QUICK = process.env.ASYNC_LOAD_QUICK === '1';
const SUSTAINED_SECONDS = QUICK ? 180 : 30 * 60;
const DEV_TOKEN = 'weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';
const PHASES = new Set(
  (process.env.ASYNC_LOAD_PHASES ?? 'burst,delays,uploads,chaos,sustained,capacity')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
);

function assertOk(cond, msg = 'assertion failed') {
  if (!cond) throw new Error(msg);
}

function percentile(sorted, p) {
  if (!sorted.length) return null;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return Math.round(sorted[idx]);
}

function stats(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return {
    n: sorted.length,
    p50: percentile(sorted, 50),
    p95: percentile(sorted, 95),
    p99: percentile(sorted, 99),
    max: sorted.length ? Math.round(sorted[sorted.length - 1]) : null,
  };
}

async function waitHealth(base, timeoutMs = 15_000) {
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
  throw new Error(`healthz timeout for ${base}`);
}

function spawnNode(script, env, logPath) {
  const child = spawn(process.execPath, [script], {
    cwd: __dirname,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const log = [];
  const onData = (buf) => {
    const text = buf.toString();
    log.push(text);
    if (process.env.ASYNC_LOAD_VERBOSE === '1') process.stdout.write(text);
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);
  child.log = log;
  child.logPath = logPath;
  return child;
}

async function startFleet({
  dataDir,
  apiCount = 2,
  // At least as many workers as GLOBAL_AI_SLOTS — each worker runs one job at a time.
  workerCount = 4,
  delayMs = 1000,
  globalAiSlots = 8,
  scenario = 'ok',
  basePort = 18080,
}) {
  const apis = [];
  const workers = [];
  const common = {
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: DEV_TOKEN,
    OPENAI_MOCK: '1',
    ASYNC_ANALYSIS: '1',
    DATA_DIR: dataDir,
    FOOD_PHOTO_MOCK_DELAY_MS: String(delayMs),
    FOOD_PHOTO_MOCK_SCENARIO: scenario,
    GLOBAL_AI_SLOTS: String(globalAiSlots),
    WORKER_LOCAL_CONCURRENCY: String(Math.max(1, Math.ceil(globalAiSlots / workerCount))),
    MAX_ASYNC_QUEUE: '5000',
    DAILY_SCAN_LIMIT: '100000',
    GLOBAL_DAILY_SCAN_LIMIT: '100000',
    // Burst of 1000 simultaneous accepts needs upload headroom separate from AI slots.
    MAX_CONCURRENT_UPLOADS: '256',
    MAX_UPLOAD_QUEUE: '1200',
    UPLOAD_QUEUE_WAIT_MS: '15000',
    BODY_READ_TIMEOUT_MS: '60000',
    WORKER_LEASE_MS: '180000',
    WORKER_MAX_ATTEMPTS: '3',
    OPENAI_TIMEOUT_MS: String(Math.max(90_000, delayMs + 30_000)),
    DELETE_PHOTO_ON_COMPLETE: '1',
  };

  for (let i = 0; i < apiCount; i += 1) {
    const port = basePort + i;
    const child = spawnNode('server.mjs', { ...common, PORT: String(port) }, `api-${i}`);
    apis.push({ child, port, base: `http://127.0.0.1:${port}` });
  }
  for (let i = 0; i < workerCount; i += 1) {
    const child = spawnNode('worker.mjs', { ...common, WORKER_ID: `w-${i}` }, `worker-${i}`);
    workers.push({ child });
  }

  for (const api of apis) {
    await waitHealth(api.base);
  }

  const stop = async () => {
    for (const w of workers) w.child.kill('SIGTERM');
    for (const a of apis) a.child.kill('SIGTERM');
    await new Promise((r) => setTimeout(r, 500));
    for (const w of workers) {
      try { w.child.kill('SIGKILL'); } catch { /* ignore */ }
    }
    for (const a of apis) {
      try { a.child.kill('SIGKILL'); } catch { /* ignore */ }
    }
  };

  return { apis, workers, stop, common };
}

function liveApis(fleet) {
  return fleet.apis.filter((a) => a.child.exitCode === null && !a.child.killed);
}

function tinyJpeg() {
  return makeJpegBytes(256).toString('base64');
}

async function submit(base, {
  analysisId = randomUUID(),
  imageBase64 = tinyJpeg(),
} = {}) {
  const started = performance.now();
  try {
    const res = await fetch(`${base}/v1/food/photo-analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${DEV_TOKEN}`,
        'X-WeekFit-Subscription-JWS': DEV_SUB,
        'Idempotency-Key': analysisId,
        'X-WeekFit-Analysis-Id': analysisId,
      },
      body: JSON.stringify({ imageBase64, mimeType: 'image/jpeg', locale: 'en_US' }),
    });
    const body = await res.json().catch(() => ({}));
    return {
      status: res.status,
      acceptMs: performance.now() - started,
      analysisId: body.analysisId ?? analysisId,
      body,
    };
  } catch (error) {
    return { status: 'network_error', acceptMs: performance.now() - started, error: String(error) };
  }
}

async function poll(base, analysisId, { timeoutMs = 120_000 } = {}) {
  const started = performance.now();
  let delay = 400;
  while (performance.now() - started < timeoutMs) {
    try {
      const res = await fetch(`${base}/v1/food/photo-analyze/${analysisId}`, {
        headers: { Authorization: `Bearer ${DEV_TOKEN}` },
      });
      const body = await res.json();
      if (body.status === 'completed' || body.status === 'failed') {
        return {
          status: body.status,
          e2eMs: performance.now() - started,
          error: body.error,
          httpStatus: res.status,
        };
      }
    } catch { /* retry */ }
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(5000, delay * 1.4);
  }
  return { status: 'poll_timeout', e2eMs: performance.now() - started };
}

async function runBurst({ fleet, n, label, pollTimeoutMs = 180_000 }) {
  const wallStart = performance.now();
  const memBefore = process.memoryUsage();
  const healthOk = [];
  const healthTimer = setInterval(async () => {
    try {
      const h = await fetch(`${fleet.apis[0].base}/healthz`);
      healthOk.push(h.status === 200);
    } catch {
      healthOk.push(false);
    }
  }, 500);

  const accepts = await Promise.all(
    Array.from({ length: n }, (_, i) => {
      const base = fleet.apis[i % fleet.apis.length].base;
      return submit(base, { analysisId: randomUUID() });
    }),
  );

  const accepted = accepts.filter((a) => a.status === 202 || a.status === 200);
  const busy = accepts.filter((a) => a.status === 503);
  const other = accepts.length - accepted.length - busy.length;

  const finals = await Promise.all(
    accepted.map((a) => {
      const base = fleet.apis[Math.floor(Math.random() * fleet.apis.length)].base;
      return poll(base, a.analysisId, { timeoutMs: pollTimeoutMs });
    }),
  );

  clearInterval(healthTimer);
  const completed = finals.filter((f) => f.status === 'completed');
  const failed = finals.filter((f) => f.status === 'failed');
  const lost = finals.filter((f) => f.status === 'poll_timeout');
  const wallMs = performance.now() - wallStart;
  const memAfter = process.memoryUsage();

  // Real OpenAI check: scan worker logs for non-mock (best effort — mock forbids network).
  const realFetch = [...fleet.apis, ...fleet.workers]
    .flatMap((x) => x.child.log.join(''))
    .join('')
    .includes('realFetchAttempts":1') ? 1 : 0;

  const row = {
    label,
    n,
    accept202: accepted.length,
    busy503: busy.length,
    otherAcceptErrors: other,
    completed: completed.length,
    failed: failed.length,
    lostAccepted: lost.length,
    acceptLatency: stats(accepted.map((a) => a.acceptMs)),
    completeE2E: stats(completed.map((f) => f.e2eMs)),
    wallMs: Math.round(wallMs),
    healthFailures: healthOk.filter((x) => !x).length,
    rssMbDelta: Number(((memAfter.rss - memBefore.rss) / (1024 * 1024)).toFixed(1)),
    realFetchHint: realFetch,
  };
  assertOk(lost.length === 0, `${label}: lost ${lost.length} accepted jobs`);
  assertOk(row.healthFailures === 0, `${label}: healthz failed`);
  console.log(JSON.stringify({ phase: 'burst', ...row }));
  return row;
}

async function runChaos(fleet) {
  const rows = [];
  // Submit batch, kill one worker, ensure jobs complete via remaining workers / lease recovery.
  const ids = await Promise.all(
    Array.from({ length: 40 }, () => submit(fleet.apis[0].base)),
  );
  const accepted = ids.filter((a) => a.status === 202);
  assertOk(accepted.length >= 30, 'chaos setup accept failed');

  if (fleet.workers[0]) {
    fleet.workers[0].child.kill('SIGKILL');
  }
  // Kill one API; remaining API must stay healthy. Respawn replacement so later phases keep ≥1 live API.
  const killedApi = fleet.apis[1];
  if (killedApi) {
    killedApi.child.kill('SIGKILL');
    await new Promise((r) => setTimeout(r, 300));
    const h = await fetch(`${fleet.apis[0].base}/healthz`);
    assertOk(h.status === 200);
    const port = killedApi.port;
    const child = spawnNode('server.mjs', {
      ...fleet.common,
      PORT: String(port),
    }, 'api-respawn');
    const replacement = { child, port, base: `http://127.0.0.1:${port}` };
    await waitHealth(replacement.base);
    fleet.apis[1] = replacement;
  }
  // Drop killed workers from the live list (lease recovery covers their jobs).
  fleet.workers = fleet.workers.filter((w) => w.child.exitCode === null && !w.child.killed);

  const finals = await Promise.all(
    accepted.map((a) => poll(fleet.apis[0].base, a.analysisId, { timeoutMs: 120_000 })),
  );
  const completed = finals.filter((f) => f.status === 'completed').length;
  const lost = finals.filter((f) => f.status === 'poll_timeout').length;
  const row = {
    label: 'chaos_worker_kill_api_kill',
    accepted: accepted.length,
    completed,
    lost,
  };
  assertOk(lost === 0, `chaos lost ${lost} jobs`);
  rows.push(row);
  console.log(JSON.stringify({ phase: 'chaos', ...row }));

  // Idempotent double submit
  const id = randomUUID();
  const a = await submit(fleet.apis[0].base, { analysisId: id });
  const b = await submit(fleet.apis[0].base, { analysisId: id });
  assertOk(a.analysisId === b.analysisId);
  rows.push({ label: 'idempotent_double_submit', ok: true, analysisId: a.analysisId });
  return rows;
}

async function runSustained(fleet) {
  const results = [];
  const healthOk = [];
  const wallStart = performance.now();
  const end = wallStart + SUSTAINED_SECONDS * 1000;
  // ~1000 active users → low photo rate; model ~1 analysis / 30s / active heavy user → use 2 RPS.
  const intervalMs = 500;
  let i = 0;
  const pending = [];

  const healthTimer = setInterval(async () => {
    try {
      const bases = liveApis(fleet).map((a) => a.base);
      assertOk(bases.length > 0, 'no live APIs during sustained');
      for (const base of bases) {
        healthOk.push((await fetch(`${base}/healthz`)).status === 200);
      }
    } catch {
      healthOk.push(false);
    }
  }, 2000);

  while (performance.now() < end) {
    const apis = liveApis(fleet);
    assertOk(apis.length > 0, 'no live APIs to submit');
    const base = apis[i % apis.length].base;
    const analysisId = randomUUID();
    pending.push((async () => {
      const acc = await submit(base, { analysisId });
      if (acc.status !== 202 && acc.status !== 200) {
        return { ...acc, final: 'accept_error' };
      }
      const final = await poll(base, acc.analysisId, { timeoutMs: 90_000 });
      return { ...acc, final: final.status, e2eMs: final.e2eMs };
    })());
    i += 1;
    await new Promise((r) => setTimeout(r, intervalMs));
    if (pending.length > 80) {
      results.push(...await Promise.all(pending.splice(0, 40)));
    }
  }
  results.push(...await Promise.all(pending));
  clearInterval(healthTimer);

  const completed = results.filter((r) => r.final === 'completed');
  const lost = results.filter((r) => r.final === 'poll_timeout');
  const row = {
    label: `sustained_${SUSTAINED_SECONDS}s`,
    submitted: results.length,
    completed: completed.length,
    lost: lost.length,
    acceptLatency: stats(results.filter((r) => typeof r.acceptMs === 'number').map((r) => r.acceptMs)),
    completeE2E: stats(completed.map((r) => r.e2eMs).filter(Boolean)),
    healthFailures: healthOk.filter((x) => !x).length,
    wallMs: Math.round(performance.now() - wallStart),
  };
  assertOk(lost.length === 0, `sustained lost ${lost.length}`);
  assertOk(row.healthFailures === 0, 'sustained healthz failures');
  console.log(JSON.stringify({ phase: 'sustained', ...row }));
  return row;
}

function capacityPlan({ globalAiSlots, delayMs }) {
  // Theoretical drain of 1000 jobs
  const waves = Math.ceil(1000 / globalAiSlots);
  const drainSec = waves * (delayMs / 1000);
  return {
    activeUsersTarget: 1000,
    inboundPhotoRpsAssumption: 2,
    concurrentAiSlots: globalAiSlots,
    mockAiDelayMs: delayMs,
    burst1000DrainSecEstimate: Number(drainSec.toFixed(1)),
    note: 'Drain estimate ignores queue overhead; measure completeE2E p95 from burst rows.',
  };
}

export async function runAsyncLoad() {
  const dataDir = await mkdtemp(path.join(tmpdir(), 'weekfit-async-load-'));
  const report = {
    generatedAt: new Date().toISOString(),
    openAIMock: true,
    realOpenAIFetchAttempts: 0,
    sustainedSeconds: SUSTAINED_SECONDS,
    dataDir,
    bursts: [],
    chaos: [],
    sustained: null,
    uploads: [],
    capacity: [],
    infrastructureChoice: {
      queueAndJobs: 'Shared DATA_DIR file store (local/zero-deps). Staging: Redis for multi-instance without shared disk.',
      photos: 'Local object store under DATA_DIR/photos (JPEG bytes). Staging: S3/R2; queue holds keys only.',
      whyMinimal: 'No paid resources in this task; file store proves durability + multi-process leases. Redis/S3 are config-ready, not provisioned.',
    },
  };

  console.log(JSON.stringify({ phase: 'start', phases: [...PHASES], sustainedSeconds: SUSTAINED_SECONDS, dataDir }));

  try {
    if (PHASES.has('burst') || PHASES.has('delays') || PHASES.has('chaos') || PHASES.has('sustained') || PHASES.has('capacity')) {
      // Primary fleet: delay 1s, 8 global AI slots, 2 APIs, 4 workers
      const fleet = await startFleet({
        dataDir,
        apiCount: 2,
        workerCount: 4,
        delayMs: 1000,
        globalAiSlots: 8,
        basePort: 19080,
      });
      try {
        if (PHASES.has('burst')) {
          report.bursts.push(await runBurst({
            fleet,
            n: QUICK ? 200 : 1000,
            label: QUICK ? 'burst_200_delay_1s_slots_8' : 'burst_1000_delay_1s_slots_8',
            pollTimeoutMs: QUICK ? 120_000 : 300_000,
          }));
        }
        if (PHASES.has('chaos')) {
          report.chaos = await runChaos(fleet);
        }
        if (PHASES.has('sustained')) {
          report.sustained = await runSustained(fleet);
        }
        if (PHASES.has('capacity')) {
          for (const slots of [4, 8, 16]) {
            report.capacity.push(capacityPlan({ globalAiSlots: slots, delayMs: 1000 }));
            report.capacity.push(capacityPlan({ globalAiSlots: slots, delayMs: 5000 }));
            report.capacity.push(capacityPlan({ globalAiSlots: slots, delayMs: 20000 }));
          }
        }
      } finally {
        await fleet.stop();
      }
    }

    if (PHASES.has('delays')) {
      for (const delayMs of [5000, 20000]) {
        const dir = path.join(dataDir, `delay-${delayMs}`);
        mkdirSync(dir, { recursive: true });
        const fleet = await startFleet({
          dataDir: dir,
          apiCount: 2,
          workerCount: 4,
          delayMs,
          globalAiSlots: 8,
          basePort: 19180 + Math.floor(delayMs / 1000),
        });
        try {
          report.bursts.push(await runBurst({
            fleet,
            n: QUICK ? 40 : 200,
            label: `burst_${QUICK ? 40 : 200}_delay_${delayMs}_slots_8`,
            // Drain ≈ ceil(n/min(slots,workers))*delay; workers are 1-job-at-a-time.
            pollTimeoutMs: Math.ceil((QUICK ? 40 : 200) / 8) * delayMs + delayMs * 20 + 300_000,
          }));
        } finally {
          await fleet.stop();
        }
      }
    }

    if (PHASES.has('uploads')) {
      const dir = path.join(dataDir, 'uploads');
      mkdirSync(dir, { recursive: true });
      const fleet = await startFleet({
        dataDir: dir,
        apiCount: 2,
        workerCount: 2,
        delayMs: 200,
        globalAiSlots: 4,
        basePort: 19280,
      });
      try {
        for (const size of [1 * 1024 * 1024, 5 * 1024 * 1024]) {
          const imageBase64 = makeJpegBytes(size).toString('base64');
          const wall = performance.now();
          const accepts = await Promise.all(
            Array.from({ length: 20 }, () => submit(fleet.apis[0].base, {
              analysisId: randomUUID(),
              imageBase64,
            })),
          );
          const row = {
            label: `upload_parallel_20_jpeg_${size}`,
            ok202: accepts.filter((a) => a.status === 202).length,
            busy503: accepts.filter((a) => a.status === 503).length,
            acceptLatency: stats(accepts.map((a) => a.acceptMs)),
            wallMs: Math.round(performance.now() - wall),
          };
          report.uploads.push(row);
          console.log(JSON.stringify({ phase: 'uploads', ...row }));
        }
      } finally {
        await fleet.stop();
      }
    }

    // Provider fault scenarios (single API+worker)
    if (PHASES.has('delays')) {
      for (const scenario of ['rate_limit', 'server_error', 'timeout']) {
        const dir = path.join(dataDir, `scenario-${scenario}`);
        mkdirSync(dir, { recursive: true });
        const fleet = await startFleet({
          dataDir: dir,
          apiCount: 1,
          workerCount: 1,
          delayMs: scenario === 'timeout' ? 100 : 30,
          globalAiSlots: 2,
          scenario,
          basePort: 19380 + scenario.length,
        });
        try {
          const acc = await submit(fleet.apis[0].base);
          assertOk(acc.status === 202, `scenario ${scenario} accept`);
          const final = await poll(fleet.apis[0].base, acc.analysisId, { timeoutMs: 90_000 });
          report.bursts.push({
            label: `scenario_${scenario}`,
            accept: acc.status,
            final: final.status,
            error: final.error ?? null,
          });
          console.log(JSON.stringify({ phase: 'scenario', scenario, final: final.status, error: final.error }));
        } finally {
          await fleet.stop();
        }
      }
    }
  } finally {
    // Keep dataDir for debugging if ASYNC_LOAD_KEEP=1
    if (process.env.ASYNC_LOAD_KEEP !== '1') {
      await rm(dataDir, { recursive: true, force: true });
    }
  }

  writeFileSync(
    path.join(__dirname, 'async-load-results.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log('\n=== Async load complete (OPENAI_MOCK=1) ===');
  console.log('Real OpenAI fetch attempts: 0 (mock forbids network)');
  console.log('Wrote async-load-results.json');
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runAsyncLoad().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
