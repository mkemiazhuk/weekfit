import { randomUUID } from 'node:crypto';
import { readFile, readdir, statfs } from 'node:fs/promises';
import path from 'node:path';
import { monitorEventLoopDelay } from 'node:perf_hooks';

const log = (row) => console.log(JSON.stringify({ ...row, at: new Date().toISOString() }));
const numeric = (value) => Number.isFinite(value) && value >= 0 ? value : null;
export function safeUsage(usage) {
  return {
    inputTokens: numeric(usage?.input_tokens),
    cachedInputTokens: numeric(usage?.input_tokens_details?.cached_tokens),
    outputTokens: numeric(usage?.output_tokens),
  };
}

/** Exactly one fetch, no retries. Never log request bodies, images, facts or credentials.
 * finished means HTTP/JSON transport finished, NOT validated application success.
 * Count starts for attempts, and join by callId; never sum starts and finishes.
 */
export async function observedProviderFetch(fetcher, url, options, { endpoint, model, mock }) {
  const callId = randomUUID();
  const started = performance.now();
  const base = { event: 'ai_transport', callId, endpoint, model, mock: Boolean(mock) };
  log({ ...base, phase: 'started' });
  try {
    const response = await fetcher(url, options);
    const providerRequestId = response.headers?.get?.('x-request-id') ?? response.headers?.get?.('openai-request-id') ?? null;
    if (!response.ok) {
      log({ ...base, phase: 'http_error', status: response.status, providerRequestId, latencyMs: Math.round(performance.now() - started) });
      return response;
    }
    return {
      ok: response.ok, status: response.status, headers: response.headers,
      async json() {
        try {
          const data = await response.json();
          log({ ...base, phase: 'finished', providerRequestId, ...safeUsage(data.usage), latencyMs: Math.round(performance.now() - started) });
          return data;
        } catch (error) {
          log({ ...base, phase: 'json_error', providerRequestId, latencyMs: Math.round(performance.now() - started) });
          throw error;
        }
      },
    };
  } catch (error) {
    log({ ...base, phase: 'network_error', latencyMs: Math.round(performance.now() - started) });
    throw error;
  }
}

async function readNumber(file) {
  try {
    const n = Number((await readFile(file, 'utf8')).trim());
    return Number.isFinite(n) && n > 0 ? n : null;
  } catch { return null; }
}

async function memory() {
  const limit = await readNumber('/sys/fs/cgroup/memory.max')
    ?? await readNumber('/sys/fs/cgroup/memory/memory.limit_in_bytes');
  const used = await readNumber('/sys/fs/cgroup/memory.current')
    ?? await readNumber('/sys/fs/cgroup/memory/memory.usage_in_bytes');
  return { containerMemoryBytes: used, containerMemoryLimitBytes: limit,
    memoryUsedRatio: limit && used ? used / limit : null, processRssBytes: process.memoryUsage().rss };
}

async function count(dir, suffix) {
  try { return (await readdir(dir)).filter((name) => name.endsWith(suffix)).length; }
  catch (error) { if (error.code === 'ENOENT') return 0; throw error; }
}

/** Pure thresholds; CPU sustain is evaluated from Render metrics, not process CPU. */
export function resourceAlerts(sample) {
  const alerts = [];
  if (sample.diskUsedRatio >= 0.85) alerts.push('disk_critical');
  else if (sample.diskUsedRatio >= 0.70) alerts.push('disk_warning');
  if (sample.memoryUsedRatio >= 0.80) alerts.push('memory_high');
  if (sample.readyWaiters > 16) alerts.push('queue_waiters_high');
  if (sample.coachQuotaUsedRatio >= 0.80) alerts.push('coach_quota_near_limit');
  if (sample.photoQuotaUsedRatio >= 0.80) alerts.push('photo_quota_near_limit');
  if (sample.eventLoopP95Ms > 200) alerts.push('event_loop_delayed');
  return alerts;
}

/** One non-overlapping sample/minute. Health reads the cache, never walks the disk.
 * No deletion here. Reservation counts are NOT billable-call or cost counts.
 */
export function createRuntimeMonitor({ dataDir, summaryStoreDir, photoLimit, coachLimit,
  intervalMs = 60_000, queueSnapshot = async () => ({}), emit = log }) {
  let latest = null, timer = null, running = null, stopped = false;
  const delay = monitorEventLoopDelay({ resolution: 20 });
  const sample = async () => {
    if (running) return running;
    running = (async () => {
      const now = new Date();
      const row = { sampledAt: now.toISOString(), uptimeSeconds: Math.round(process.uptime()),
        ...await memory(), ...await queueSnapshot(), eventLoopP95Ms: Number((delay.percentile(95) / 1e6).toFixed(2)) };
      if (dataDir) {
        try {
          const fs = await statfs(dataDir);
          row.diskTotalBytes = fs.blocks * fs.bsize;
          row.diskAvailableBytes = fs.bavail * fs.bsize;
          row.diskUsedRatio = fs.blocks ? 1 - fs.bavail / fs.blocks : null;
          row.photoReservationsUtcDay = await count(path.join(dataDir, 'quota', 'global', now.toISOString().slice(0, 10)), '.res');
          row.photoQuotaUsedRatio = photoLimit ? row.photoReservationsUtcDay / photoLimit : null;
        } catch { row.storageSampleUnavailable = true; }
      }
      if (summaryStoreDir) {
        try {
          row.coachReservationsUtcDay = await count(path.join(summaryStoreDir, 'coach-guard', 'budget', 'utc-day', now.toISOString().slice(0, 10)), '.json');
          row.coachQuotaUsedRatio = coachLimit ? row.coachReservationsUtcDay / coachLimit : null;
        } catch { row.coachQuotaSampleUnavailable = true; }
      }
      row.alerts = resourceAlerts(row);
      if (!stopped) {
        latest = row;
        emit({ event: 'runtime_metrics', ...row });
        if (row.alerts.length) emit({ event: 'runtime_alert', alerts: row.alerts });
      }
      delay.reset();
      return row;
    })().catch(() => {
      if (!stopped) emit({ event: 'runtime_monitor_failed' });
      return null;
    }).finally(() => { running = null; });
    return running;
  };
  return {
    sample,
    snapshot: () => latest,
    start() {
      if (timer || stopped) return;
      delay.enable();
      void sample();
      timer = setInterval(() => { void sample(); }, intervalMs);
      timer.unref();
    },
    stop() { stopped = true; clearInterval(timer); delay.disable(); },
  };
}
