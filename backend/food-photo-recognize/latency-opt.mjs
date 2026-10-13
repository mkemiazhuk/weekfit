#!/usr/bin/env node
/**
 * Latency stage breakdown — mock OpenAI only (0 real calls).
 * Idle: sequential accepts with free AI capacity (inline fast-path).
 * Peak: concurrent accepts that overflow slots (queue + workers).
 *
 *   node latency-opt.mjs
 */
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { makeJpegBytes } from './extended-load.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
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
    await new Promise((r) => setTimeout(r, 80));
  }
  throw new Error(`healthz timeout ${base}`);
}

const jpegB64 = () => makeJpegBytes(256).toString('base64');

async function submitAndResolve(base, { poll = true } = {}) {
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
  const acceptMs = performance.now() - t0;
  const body = await res.json();
  if (res.status === 200 && body.status === 'completed') {
    return {
      mode: 'inline',
      acceptMs,
      queueWaitMs: body.timings?.queueWaitMs ?? 0,
      aiMs: body.timings?.aiMs ?? (body.stageMs ? body.stageMs.inlineDone - (body.stageMs.inlineStart || 0) : null),
      e2eMs: performance.now() - t0,
      pollGapMs: 0,
      status: body.status,
    };
  }
  if (res.status !== 202) {
    throw new Error(`unexpected status ${res.status} ${JSON.stringify(body)}`);
  }
  if (!poll) {
    return { mode: 'queued', acceptMs, status: body.status };
  }
  let delay = 150;
  const pollStart = performance.now();
  let completedAtServer = null;
  while (performance.now() - t0 < 120_000) {
    const s = await fetch(`${base}/v1/food/photo-analyze/${body.analysisId}`, {
      headers: { Authorization: `Bearer ${DEV_TOKEN}` },
    });
    const st = await s.json();
    if (st.status === 'completed') {
      const clientE2e = performance.now() - t0;
      const serverE2e = st.timings?.e2eMs ?? null;
      completedAtServer = st.timings?.completedAt ?? null;
      return {
        mode: 'queued',
        acceptMs,
        queueWaitMs: st.timings?.queueWaitMs ?? null,
        aiMs: st.timings?.aiMs ?? null,
        e2eMs: clientE2e,
        serverE2eMs: serverE2e,
        // Approximate gap: client e2e − server e2e (poll discovery lag).
        pollGapMs: serverE2e != null ? Math.max(0, Math.round(clientE2e - serverE2e)) : null,
        pollClientMs: performance.now() - pollStart,
        status: st.status,
      };
    }
    if (st.status === 'failed') throw new Error(`failed ${st.error}`);
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(1200, Math.round(delay * 1.25));
  }
  throw new Error('poll timeout');
}

async function runSuite() {
  const dataDir = await mkdtemp(path.join(tmpdir(), 'wf-lat-'));
  const port = 21990 + Math.floor(Math.random() * 200);
  const common = {
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: DEV_TOKEN,
    OPENAI_MOCK: '1',
    ASYNC_ANALYSIS: '1',
    DATA_DIR: dataDir,
    STATE_BACKEND: 'file',
    OBJECT_STORE: 'local',
    FOOD_PHOTO_MOCK_DELAY_MS: '120',
    GLOBAL_AI_SLOTS: '4',
    WORKER_LOCAL_CONCURRENCY: '2',
    WORKER_IDLE_MS: '5',
    POLL_HINT_MS: '200',
    DAILY_SCAN_LIMIT: '100000',
    GLOBAL_DAILY_SCAN_LIMIT: '100000',
    MAX_ASYNC_QUEUE: '5000',
    MAX_CONCURRENT_UPLOADS: '64',
    MAX_UPLOAD_QUEUE: '200',
    INLINE_FAST_PATH: '1',
    PORT: String(port),
  };

  const api = spawnProc('server.mjs', common);
  const workers = [0, 1].map(() => spawnProc('worker.mjs', common));
  const base = `http://127.0.0.1:${port}`;
  const report = {
    generatedAt: new Date().toISOString(),
    openAIMock: true,
    realOpenAIFetchAttempts: 0,
    mockAiDelayMs: 120,
    note: 'Mock AI delay is synthetic. Do not claim real OpenAI latency from these numbers.',
    eliminatedDelays: [
      'Idle path: queue wait removed via inline fast-path when GLOBAL_AI_SLOTS free',
      'pollHintMs 250 (was 1000); iOS poll max 1.5s (was 8s); removed healthz warm-up',
      'Worker idle 10ms; soft-requeue sleep removed; lease sweep ≤1/s',
      'Shorter prompt + effort=medium + image detail=auto + keep-alive OpenAI HTTP',
      'iOS: parallel auth+JWS, JPEG target ≤450KB @1536px, connection reuse',
    ],
    providerBound: 'AI provider time (mock here; real OpenAI dominates e2e when not mocked)',
    idle: null,
    peak: null,
  };

  try {
    await waitHealth(base);

    // --- Idle: sequential, capacity free → inline ---
    const idleRows = [];
    for (let i = 0; i < 30; i += 1) {
      idleRows.push(await submitAndResolve(base));
    }
    report.idle = {
      label: 'idle_sequential_n30_slots4_mock120ms',
      modes: {
        inline: idleRows.filter((r) => r.mode === 'inline').length,
        queued: idleRows.filter((r) => r.mode === 'queued').length,
      },
      acceptMs: stats(idleRows.map((r) => r.acceptMs)),
      queueWaitMs: stats(idleRows.map((r) => r.queueWaitMs)),
      aiMs: stats(idleRows.map((r) => r.aiMs)),
      pollGapMs: stats(idleRows.map((r) => r.pollGapMs)),
      e2eMs: stats(idleRows.map((r) => r.e2eMs)),
    };

    // --- Peak: burst overflowing slots → queue ---
    const peakN = 40;
    const peakStarted = performance.now();
    const peakRows = await Promise.all(
      Array.from({ length: peakN }, () => submitAndResolve(base)),
    );
    report.peak = {
      label: 'peak_burst_n40_slots4_mock120ms',
      burstWallMs: Math.round(performance.now() - peakStarted),
      modes: {
        inline: peakRows.filter((r) => r.mode === 'inline').length,
        queued: peakRows.filter((r) => r.mode === 'queued').length,
      },
      acceptMs: stats(peakRows.map((r) => r.acceptMs)),
      queueWaitMs: stats(peakRows.map((r) => r.queueWaitMs)),
      aiMs: stats(peakRows.map((r) => r.aiMs)),
      pollGapMs: stats(peakRows.map((r) => r.pollGapMs)),
      e2eMs: stats(peakRows.map((r) => r.e2eMs)),
    };

    writeFileSync(
      path.join(__dirname, 'latency-opt-results.json'),
      `${JSON.stringify(report, null, 2)}\n`,
    );
    console.log(JSON.stringify({ phase: 'idle', ...report.idle }));
    console.log(JSON.stringify({ phase: 'peak', ...report.peak }));
    console.log('\n=== Latency opt complete (OPENAI_MOCK=1, real OpenAI=0) ===');
    console.log('Wrote latency-opt-results.json');
    return report;
  } finally {
    for (const w of workers) w.kill('SIGTERM');
    api.kill('SIGTERM');
    await new Promise((r) => setTimeout(r, 400));
    for (const x of [...workers, api]) {
      try { x.kill('SIGKILL'); } catch { /* ignore */ }
    }
    await rm(dataDir, { recursive: true, force: true }).catch(() => {});
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runSuite().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
