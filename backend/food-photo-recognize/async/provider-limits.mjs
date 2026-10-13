/**
 * Separate provider capacity controls (concurrency is GLOBAL_AI_SLOTS).
 * RPM / TPM are soft local admissions — values must match the OpenAI account tier
 * after staging measurement. Unknown limits → leave 0 (disabled) until confirmed.
 *
 * Does NOT bypass provider caps via multiple keys/accounts.
 */
export function createProviderLimits({
  maxRpm = 0,
  maxTpm = 0,
  tokensPerCallEstimate = 4000,
} = {}) {
  /** @type {number[]} */
  const callTimestamps = [];
  let reservedTokensWindow = 0;
  /** @type {{ at: number, tokens: number }[]} */
  const tokenEvents = [];

  const prune = (now = Date.now()) => {
    const cutoff = now - 60_000;
    while (callTimestamps.length && callTimestamps[0] < cutoff) callTimestamps.shift();
    while (tokenEvents.length && tokenEvents[0].at < cutoff) {
      reservedTokensWindow -= tokenEvents[0].tokens;
      tokenEvents.shift();
    }
    if (reservedTokensWindow < 0) reservedTokensWindow = 0;
  };

  const snapshot = () => {
    prune();
    return {
      rpmInWindow: callTimestamps.length,
      maxRpm: maxRpm || null,
      tpmInWindow: reservedTokensWindow,
      maxTpm: maxTpm || null,
      tokensPerCallEstimate,
      rpmEnabled: maxRpm > 0,
      tpmEnabled: maxTpm > 0,
    };
  };

  /**
   * Reserve admission for one provider call.
   * @returns {{ ok: true, release: () => void } | { ok: false, code: string, retryAfterSeconds: number }}
   */
  const tryReserve = () => {
    const now = Date.now();
    prune(now);
    if (maxRpm > 0 && callTimestamps.length >= maxRpm) {
      const retryAfterSeconds = Math.max(1, Math.ceil((callTimestamps[0] + 60_000 - now) / 1000));
      return { ok: false, code: 'provider_rpm_limited', retryAfterSeconds };
    }
    if (maxTpm > 0 && reservedTokensWindow + tokensPerCallEstimate > maxTpm) {
      const retryAfterSeconds = Math.max(1, Math.ceil((tokenEvents[0]?.at ?? now) + 60_000 - now) / 1000);
      return { ok: false, code: 'provider_tpm_limited', retryAfterSeconds };
    }
    callTimestamps.push(now);
    if (maxTpm > 0) {
      tokenEvents.push({ at: now, tokens: tokensPerCallEstimate });
      reservedTokensWindow += tokensPerCallEstimate;
    }
    return {
      ok: true,
      release: () => {
        // Window entries age out via prune; no immediate undo needed for completed calls.
      },
    };
  };

  return { tryReserve, snapshot, kind: 'local' };
}

// One rolling window for the entire API/worker fleet. Redis time avoids clock
// skew across hosts; rejection does not consume a reservation.
const RATE_SCRIPT = `-- WEEKFIT_PROVIDER_RATE
local t = redis.call('TIME')
local now = tonumber(t[1]) * 1000 + math.floor(tonumber(t[2]) / 1000)
redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now - 60000)
local count = redis.call('ZCARD', KEYS[1])
local rpm = tonumber(ARGV[2])
local tpm = tonumber(ARGV[3])
local tokens = tonumber(ARGV[4])
if rpm > 0 and count >= rpm then return 'provider_rpm_limited' end
if tpm > 0 and (count + 1) * tokens > tpm then return 'provider_tpm_limited' end
redis.call('ZADD', KEYS[1], now, ARGV[1])
redis.call('PEXPIRE', KEYS[1], 61000)
return 'OK'
`;

export function createRedisProviderLimits({ redis, maxRpm = 0, maxTpm = 0,
  tokensPerCallEstimate = 4000, prefix = 'wf:' }) {
  const key = `${prefix}provider:minute`;
  return {
    kind: 'redis',
    async tryReserve() {
      if (!maxRpm && !maxTpm) return { ok: true, release() {} };
      const { randomUUID } = await import('node:crypto');
      const result = await redis.eval(RATE_SCRIPT, [key],
        [randomUUID(), String(maxRpm), String(maxTpm), String(tokensPerCallEstimate)]);
      return result === 'OK' ? { ok: true, release() {} }
        : { ok: false, code: result, retryAfterSeconds: 1 };
    },
    async snapshot() {
      return { kind: 'redis', reservations: await redis.zcard(key), maxRpm, maxTpm,
        tokensPerCallEstimate, note: 'Conservative estimated tokens; provider remains authoritative.' };
    },
  };
}
