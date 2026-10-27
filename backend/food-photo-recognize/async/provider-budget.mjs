import path from 'node:path';
import { writeJsonAtomic, readJson } from './atomic-fs.mjs';

/**
 * Soft daily spend / call budget for the photo model (USD estimate + call count).
 * Does not promise exactly-once billing with the provider — only stops new attempts
 * when local counters exceed the budget. Uncertain outcomes after network cut still
 * count as an attempt when the worker already entered the provider call.
 */
export function createProviderBudget({
  dataDir,
  maxCallsPerDay = 5000,
  maxEstimatedUsdPerDay = 500,
  usdPerCallEstimate = 0.08,
} = {}) {
  const fileFor = (day) => path.join(dataDir, 'meta', `spend-${day}.json`);
  const dayKey = () => new Date().toISOString().slice(0, 10);

  const load = async () => {
    const day = dayKey();
    return (await readJson(fileFor(day), null)) ?? {
      day,
      calls: 0,
      estimatedUsd: 0,
      uncertainOutcomes: 0,
    };
  };

  const assertWithinBudget = async () => {
    const s = await load();
    if (s.calls >= maxCallsPerDay || s.estimatedUsd >= maxEstimatedUsdPerDay) {
      const err = new Error('provider_budget_exhausted');
      err.code = 'provider_budget_exhausted';
      throw err;
    }
    return s;
  };

  const recordAttempt = async ({ uncertain = false } = {}) => {
    const s = await load();
    const next = {
      ...s,
      calls: s.calls + 1,
      estimatedUsd: Number((s.estimatedUsd + usdPerCallEstimate).toFixed(4)),
      uncertainOutcomes: s.uncertainOutcomes + (uncertain ? 1 : 0),
    };
    await writeJsonAtomic(fileFor(s.day), next);
    return next;
  };

  return { assertWithinBudget, recordAttempt, snapshot: load };
}

/** Bounded retry with full jitter. Never infinite. */
export function computeRetryDelayMs(attempt, { baseMs = 500, maxMs = 20_000 } = {}) {
  const exp = Math.min(maxMs, baseMs * (2 ** Math.max(0, attempt - 1)));
  return Math.floor(Math.random() * (exp + 1));
}

export function isRetryableProviderError(error) {
  const code = error?.code ?? error?.name ?? '';
  const status = error?.status;
  const message = String(error?.message ?? '');
  // These mean the call must not be attempted again. A 503 here is a refusal, not a transient provider error.
  if (code === 'durability_unconfirmed' || code === 'file_ledger_unsupported') return false;
  if (status === 429 || status === 500 || status === 502 || status === 503) return true;
  if ([
    'TimeoutError',
    'AbortError',
    'provider_rate_limited',
    'provider_error',
    'object_store_unavailable',
    'object_get_failed',
    'ECONNRESET',
    'ECONNREFUSED',
    'ETIMEDOUT',
    'fetch failed',
  ].includes(code)) {
    return true;
  }
  if (/object_store|object_get_failed|fetch failed|ECONNRESET|ECONNREFUSED/i.test(message)) {
    return true;
  }
  if (error?.message === 'circuit_open') return false;
  return false;
}

/** Storage / slot pressure should not burn provider attempts toward terminal failure. */
export function isSoftRequeueError(error) {
  const code = error?.code ?? error?.name ?? '';
  const message = String(error?.message ?? '');
  return code === 'object_store_unavailable'
    || code === 'ai_slots_full'
    || /object_store_unavailable|object_get_failed/i.test(message);
}
