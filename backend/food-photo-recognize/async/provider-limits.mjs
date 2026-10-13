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
