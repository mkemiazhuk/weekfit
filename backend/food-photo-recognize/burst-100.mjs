#!/usr/bin/env node
/**
 * Burst-100 + 1000-active-users mock capacity suite.
 * Real OpenAI = 0. No paid resources. Does not touch production.
 *
 *   node burst-100.mjs
 *   BURST100_QUICK=1 node burst-100.mjs
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
const QUICK = process.env.BURST100_QUICK === '1';
const PORT_OFFSET = Number(process.env.BURST100_PORT_OFFSET || 0);
const BURST_N = QUICK ? 20 : 100;
const DELAYS = QUICK ? [1000, 2000] : [5000, 10_000, 20_000];
const SLOTS = QUICK ? 20 : 100;
const WORKERS = QUICK ? 2 : 4;
const LOCAL_CONC = Math.ceil(SLOTS / WORKERS);
const DEV_TOKEN = 'weekfit-dev-local-token';
const DEV_SUB = 'weekfit-dev-local-subscription';

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

async function waitHealth(base, timeoutMs = 25_000) {
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
  const child = spawn(process.execPath, ['--import', './async/load-process-probe.mjs', script], {
    cwd: __dirname,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
  });
  child.samples = [];
  child.on('message', m => { if (m.probe) child.samples.push(m); });
  child.log = [];
  const onData = (b) => child.log.push(b.toString());
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);
  return child;
}

const jpegB64 = () => makeJpegBytes(450_000).toString('base64');

async function startFleet({ redisUrl, objectBaseUrl, objectToken, delayMs, basePort, workerLeaseMs = null }) {
  const leaseMs = workerLeaseMs ?? Math.max(60_000, delayMs * 2 + 30_000);
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
    GLOBAL_AI_SLOTS: String(SLOTS),
    TARGET_BURST_SLOTS: String(SLOTS),
    WORKER_LOCAL_CONCURRENCY: String(LOCAL_CONC),
    WORKER_CLAIM_WAIT_MS: '3000',
    INLINE_FAST_PATH: '0',
    LONG_POLL_MAX_MS: '25000',
    MAX_ASYNC_QUEUE: '5000',
    MAX_CONCURRENT_UPLOADS: '128',
    MAX_UPLOAD_QUEUE: '500',
    DAILY_SCAN_LIMIT: '100000',
    GLOBAL_DAILY_SCAN_LIMIT: '100000',
    OPENAI_TIMEOUT_MS: String(Math.max(90_000, delayMs + 30_000)),
    WORKER_LEASE_MS: String(leaseMs),
    DELETE_PHOTO_ON_COMPLETE: '1',
  };
  const apis = [];
  for (let i = 0; i < 2; i += 1) {
    const port = basePort + i;
    apis.push({
      child: spawnProc('server.mjs', { ...common, PORT: String(port) }),
      port,
      base: `http://127.0.0.1:${port}`,
    });
  }
  const workers = Array.from({ length: WORKERS }, () => ({
    child: spawnProc('worker.mjs', { ...common }),
  }));
  for (const api of apis) await waitHealth(api.base);
  const stop = async () => {
    for (const w of workers) w.child.kill('SIGTERM');
    for (const a of apis) a.child.kill('SIGTERM');
    await new Promise((r) => setTimeout(r, 400));
    for (const x of [...workers, ...apis]) {
      try { x.child.kill('SIGKILL'); } catch { /* ignore */ }
    }
  };
  return { apis, workers, stop, common };
}

async function submit(base) {
  const analysisId = randomUUID();
  const t0 = performance.now();
  const res = await fetch(`${base}/v1/food/photo-analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${DEV_TOKEN}`,
      'X-WeekFit-Subscription-JWS': DEV_SUB,
      'Idempotency-Key': analysisId,
    },
    body: JSON.stringify({ imageBase64: jpegB64(), mimeType: 'image/jpeg', locale: 'en_US' }),
  });
  const body = await res.json().catch(() => ({}));
  return {
    startedAt: t0,
    status: res.status,
    acceptMs: performance.now() - t0,
    analysisId: body.analysisId || analysisId,
    body,
  };
}

async function longPoll(base, analysisId, timeoutMs, startedAt = performance.now()) {
  const t0 = performance.now();
  while (performance.now() - t0 < timeoutMs) {
    const remaining = timeoutMs - (performance.now() - t0);
    const waitMs = Math.min(20_000, Math.max(500, Math.floor(remaining)));
    try {
      const res = await fetch(
        `${base}/v1/food/photo-analyze/${analysisId}?waitMs=${waitMs}`,
        { headers: { Authorization: `Bearer ${DEV_TOKEN}` } },
      );
      const body = await res.json();
      if (body.status === 'completed' || body.status === 'failed') {
        return {
          status: body.status,
          clientE2eMs: performance.now() - startedAt,
          timings: body.timings || null,
          error: body.error,
        };
      }
    } catch {
      await new Promise((r) => setTimeout(r, 200));
    }
  }
  return { status: 'poll_timeout', clientE2eMs: performance.now() - startedAt };
}

async function runBurst(fleet, { n, delayMs, label }) {
  const wallStart = performance.now();
  const accepts = await Promise.all(
    Array.from({ length: n }, (_, i) => submit(fleet.apis[i % fleet.apis.length].base)),
  );
  const accepted = accepts.filter((a) => a.status === 202 || a.status === 200);
  const rejected = accepts.filter((a) => a.status === 503 || a.status >= 400);
  const pollTimeout = Math.max(90_000, delayMs * 3 + 60_000);
  const finals = await Promise.all(
    accepted.map((a, i) => longPoll(fleet.apis[i % fleet.apis.length].base, a.analysisId, pollTimeout, a.startedAt)),
  );
  const completed = finals.filter((f) => f.status === 'completed');
  const failed = finals.filter((f) => f.status === 'failed');
  const lost = finals.filter((f) => f.status === 'poll_timeout');
  const queueWaits = completed.map((f) => f.timings?.queueWaitMs).filter((v) => v != null);
  const aiMs = completed.map((f) => f.timings?.aiMs).filter((v) => v != null);
  const e2e = completed.map((f) => f.clientE2eMs);
  const row = {
    label,
    delayMs,
    n,
    slots: SLOTS,
    workers: WORKERS,
    localConcurrency: LOCAL_CONC,
    acceptOk: accepted.length,
    rejected: rejected.length,
    completed: completed.length,
    failed: failed.length,
    lost: lost.length,
    acceptLatency: stats(accepted.map((a) => a.acceptMs)),
    queueLatency: stats(queueWaits),
    aiLatency: stats(aiMs),
    e2eLatency: stats(e2e),
    deliveryClientMs: stats(completed.map((f) => f.clientE2eMs)),
    burstWallMs: Math.round(performance.now() - wallStart),
    fixtureBytes: 450_000,
    resources: [...fleet.apis, ...fleet.workers].map((x, index) => ({
      role: index < fleet.apis.length ? 'api' : 'worker',
      peakRssMB: Math.round(Math.max(0, ...x.child.samples.map(s => s.rssBytes)) / 1024 / 1024),
      cpuPercentOneCore: stats(x.child.samples.map(s => s.cpuPercentOneCore)),
    })),
    targets: {
      queueP95_le_1000ms: (percentile([...queueWaits].sort((a, b) => a - b), 95) ?? Infinity) <= 1000,
      e2eP95_le_30000ms: (percentile([...e2e].sort((a, b) => a - b), 95) ?? Infinity) <= 30_000,
    },
  };
  if (lost.length) throw new Error(`${label}: lost ${lost.length}`);
  console.log(JSON.stringify({ phase: 'burst', ...row }));
  return row;
}

async function runActiveUsers(fleet) {
  // Proxy for 1000 active users at 0.12 analyses/user/min = 2 RPS (quick: 1 RPS).
  const durationMs = QUICK ? 20_000 : 60_000;
  const rps = QUICK ? 1 : 2;
  const interval = 1000 / rps;
  const started = performance.now();
  const ids = [];
  while (performance.now() - started < durationMs) {
    const tick = performance.now();
    const a = await submit(fleet.apis[ids.length % fleet.apis.length].base);
    a.final = (a.status === 202 || a.status === 200)
      ? longPoll(fleet.apis[0].base, a.analysisId, 120_000, a.startedAt) : null;
    ids.push(a);
    const sleep = interval - (performance.now() - tick);
    if (sleep > 0) await new Promise((r) => setTimeout(r, sleep));
  }
  const accepted = ids.filter((a) => a.status === 202 || a.status === 200);
  const finals = await Promise.all(
    accepted.map((a) => a.final),
  );
  const row = {
    label: 'active_users_1000_proxy',
    note: 'Proxy: 1000 active users × 0.12 analyses/min = 2 RPS, not 1000 simultaneous users',
    durationMs,
    rps,
    submitted: ids.length,
    acceptOk: accepted.length,
    rejected: ids.length - accepted.length,
    failed: finals.filter((f) => f.status === 'failed').length,
    completed: finals.filter((f) => f.status === 'completed').length,
    lost: finals.filter((f) => f.status === 'poll_timeout').length,
    e2eLatency: stats(finals.filter((f) => f.status === 'completed').map((f) => f.clientE2eMs)),
  };
  if (row.lost) throw new Error(`active users lost ${row.lost}`);
  console.log(JSON.stringify({ phase: 'active_users', ...row }));
  return row;
}

async function runChaos(fleet) {
  const ids = await Promise.all(Array.from({ length: 20 }, () => submit(fleet.apis[0].base)));
  const accepted = ids.filter((a) => a.status === 202 || a.status === 200);
  fleet.workers[0].child.kill('SIGKILL');
  fleet.apis[1].child.kill('SIGKILL');
  // Replacement worker picks up after lease expiry / remaining workers drain queue.
  const replacement = spawnProc('worker.mjs', {
    ...fleet.common,
    WORKER_LEASE_MS: '8000',
    FOOD_PHOTO_MOCK_DELAY_MS: '200',
  });
  try {
    const finals = await Promise.all(
      accepted.map((a) => longPoll(fleet.apis[0].base, a.analysisId, 180_000, a.startedAt)),
    );
    const row = {
      label: 'chaos_worker_api_kill',
      accepted: accepted.length,
      completed: finals.filter((f) => f.status === 'completed').length,
      lost: finals.filter((f) => f.status === 'poll_timeout').length,
    };
    if (row.lost) throw new Error(`chaos lost ${row.lost}`);
    console.log(JSON.stringify({ phase: 'chaos', ...row }));
    return row;
  } finally {
    try { replacement.kill('SIGTERM'); } catch { /* ignore */ }
  }
}

export async function runBurst100() {
  const mini = createMiniRedisServer();
  const redisInfo = await mini.listen();
  const obj = createHttpObjectStoreServer();
  const objInfo = await obj.listen();
  const report = {
    generatedAt: new Date().toISOString(),
    openAIMock: true,
    realOpenAIFetchAttempts: 0,
    slots: SLOTS,
    workers: WORKERS,
    localConcurrency: LOCAL_CONC,
    burstN: BURST_N,
    bursts: [],
    activeUsers: null,
    chaos: null,
    capacityPlan: {
      burst100: {
        globalAiSlots: 100,
        workers: 4,
        workerLocalConcurrency: 25,
        apiInstances: 2,
        note: 'Pre-warm this capacity; do not rely on cold autoscale for the instant burst.',
      },
      providerLimitsRequired: {
        concurrent: '≥ GLOBAL_AI_SLOTS (e.g. 100 for mock burst target)',
        rpm: 'Set PROVIDER_MAX_RPM from OpenAI dashboard after staging canary',
        tpm: 'Set PROVIDER_MAX_TPM from OpenAI dashboard after staging canary',
        unsetMeans: '0 disables shared RPM/TPM admission (concurrency still capped by slots)',
      },
    },
    notes: [
      '202 accept ≠ result. Only completed status with result is success.',
      'Mock AI delay is synthetic — do not claim real OpenAI speed.',
      'Production GLOBAL_AI_SLOTS must not be set to 100 without confirmed provider+host limits.',
    ],
  };

  console.log(JSON.stringify({
    phase: 'start',
    burstN: BURST_N,
    slots: SLOTS,
    workers: WORKERS,
    localConcurrency: LOCAL_CONC,
  }));

  try {
    for (const delayMs of DELAYS) {
      const fleet = await startFleet({
        redisUrl: redisInfo.url,
        objectBaseUrl: objInfo.baseUrl,
        objectToken: objInfo.token,
        delayMs,
        basePort: PORT_OFFSET + 25000 + Math.floor(delayMs / 1000),
      });
      try {
        report.bursts.push(await runBurst(fleet, {
          n: BURST_N,
          delayMs,
          label: `burst_${BURST_N}_delay_${delayMs}_slots_${SLOTS}`,
        }));
        if (delayMs === DELAYS[0]) {
          report.overCapacity = await runBurst(fleet, {
            n: BURST_N * 2, delayMs, label: 'over_capacity_double_burst',
          });
        }
      } finally {
        await fleet.stop();
        await new Promise((r) => setTimeout(r, 500));
      }
    }

    const fleet = await startFleet({
      redisUrl: redisInfo.url,
      objectBaseUrl: objInfo.baseUrl,
      objectToken: objInfo.token,
      delayMs: QUICK ? 200 : 500,
      basePort: PORT_OFFSET + 26000,
      workerLeaseMs: 8000,
    });
    try {
      if (process.env.BURST100_SKIP_ACTIVE !== '1') report.activeUsers = await runActiveUsers(fleet);
      report.chaos = await runChaos(fleet);
    } finally {
      await fleet.stop();
    }
  } finally {
    await objInfo.close();
    await redisInfo.close();
  }

  writeFileSync(
    path.join(__dirname, process.env.BURST100_RESULTS_FILE || 'burst-100-results.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log('\n=== Burst-100 complete (OPENAI_MOCK=1, real OpenAI=0) ===');
  console.log('Wrote burst-100-results.json');
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runBurst100().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
