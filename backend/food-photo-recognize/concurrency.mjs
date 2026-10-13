import { ServiceError } from './recognition.mjs';

/**
 * Process-local concurrency gate with a bounded wait queue.
 * Not shared across multiple service instances.
 */
export function createConcurrencyGate({
  maxConcurrent,
  maxQueue,
  queueWaitMs,
  retryAfterSeconds,
  fullCode = 'server_busy',
  timeoutDetail = 'ai_queue_timeout',
  fullDetail = 'ai_queue_full',
}) {
  let active = 0;
  let peakActive = 0;
  let peakQueued = 0;
  const waiters = [];

  const metrics = () => ({
    active,
    queued: waiters.length,
    peakActive,
    peakQueued,
    maxConcurrent,
    maxQueue,
  });

  const wakeNext = () => {
    while (active < maxConcurrent && waiters.length > 0) {
      const next = waiters.shift();
      clearTimeout(next.timer);
      active += 1;
      peakActive = Math.max(peakActive, active);
      next.resolve(createTicket(next.enqueuedAt));
    }
  };

  const createTicket = (enqueuedAt) => {
    const queueWaitMsActual = Math.max(0, Date.now() - enqueuedAt);
    return {
      queueWaitMs: queueWaitMsActual,
      release() {
        active = Math.max(0, active - 1);
        wakeNext();
      },
    };
  };

  /**
   * @returns {Promise<{ release: () => void, queueWaitMs: number }>}
   */
  const acquire = () => {
    const now = Date.now();
    if (active < maxConcurrent) {
      active += 1;
      peakActive = Math.max(peakActive, active);
      return Promise.resolve(createTicket(now));
    }
    if (waiters.length >= maxQueue) {
      throw new ServiceError(fullCode, 503, {
        retryAfterSeconds,
        detail: fullDetail,
      });
    }
    peakQueued = Math.max(peakQueued, waiters.length + 1);
    return new Promise((resolve, reject) => {
      const entry = {
        enqueuedAt: now,
        resolve,
        reject,
        timer: setTimeout(() => {
          const idx = waiters.indexOf(entry);
          if (idx >= 0) waiters.splice(idx, 1);
          reject(new ServiceError(fullCode, 503, {
            retryAfterSeconds,
            detail: timeoutDetail,
          }));
        }, queueWaitMs),
      };
      waiters.push(entry);
    });
  };

  return { acquire, metrics };
}
