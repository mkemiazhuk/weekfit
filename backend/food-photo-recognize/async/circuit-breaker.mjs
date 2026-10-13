import path from 'node:path';
import { writeJsonAtomic, readJson } from './atomic-fs.mjs';

/**
 * Shared circuit breaker for the OpenAI/provider path.
 * States: closed → open (after threshold failures) → half_open (probe) → closed.
 */
export function createCircuitBreaker({
  dataDir,
  failureThreshold = 8,
  openMs = 30_000,
  halfOpenMax = 1,
} = {}) {
  const file = path.join(dataDir, 'meta', 'circuit.json');

  const load = async () => (await readJson(file, null)) ?? {
    state: 'closed',
    failures: 0,
    openedAt: 0,
    halfOpenProbes: 0,
  };

  const save = (state) => writeJsonAtomic(file, state);

  const beforeCall = async () => {
    const now = Date.now();
    let s = await load();
    if (s.state === 'open') {
      if (now - s.openedAt < openMs) {
        const err = new Error('circuit_open');
        err.code = 'circuit_open';
        err.retryAfterSeconds = Math.ceil((openMs - (now - s.openedAt)) / 1000);
        throw err;
      }
      s = { ...s, state: 'half_open', halfOpenProbes: 0 };
      await save(s);
    }
    if (s.state === 'half_open' && s.halfOpenProbes >= halfOpenMax) {
      const err = new Error('circuit_open');
      err.code = 'circuit_open';
      err.retryAfterSeconds = Math.ceil(openMs / 1000);
      throw err;
    }
    if (s.state === 'half_open') {
      await save({ ...s, halfOpenProbes: s.halfOpenProbes + 1 });
    }
    return s.state;
  };

  const recordSuccess = async () => {
    await save({ state: 'closed', failures: 0, openedAt: 0, halfOpenProbes: 0 });
  };

  const recordFailure = async () => {
    const s = await load();
    const failures = (s.failures ?? 0) + 1;
    if (s.state === 'half_open' || failures >= failureThreshold) {
      await save({
        state: 'open',
        failures,
        openedAt: Date.now(),
        halfOpenProbes: 0,
      });
      return 'open';
    }
    await save({ ...s, failures });
    return 'closed';
  };

  const snapshot = async () => load();

  return { beforeCall, recordSuccess, recordFailure, snapshot };
}
