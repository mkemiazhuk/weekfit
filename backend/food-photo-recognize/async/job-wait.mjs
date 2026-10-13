import { EventEmitter } from 'node:events';

/**
 * In-process job status wake channel for long-poll.
 * Multi-instance: each API polls Redis/file state; this only accelerates same-process waiters.
 */
const bus = new EventEmitter();
bus.setMaxListeners(500);

export function notifyJobUpdated(analysisId) {
  if (!analysisId) return;
  bus.emit(`job:${analysisId}`);
  bus.emit('job:*', analysisId);
}

export function waitForJobUpdate(analysisId, timeoutMs, abortSignal) {
  return new Promise((resolve) => {
    const key = `job:${analysisId}`;
    let settled = false;
    const done = (reason) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      bus.off(key, onUpdate);
      abortSignal?.removeEventListener?.('abort', onAbort);
      resolve(reason);
    };
    const onUpdate = () => done('updated');
    const onAbort = () => done('aborted');
    const timer = setTimeout(() => done('timeout'), Math.max(0, timeoutMs));
    bus.on(key, onUpdate);
    if (abortSignal?.aborted) {
      done('aborted');
      return;
    }
    abortSignal?.addEventListener?.('abort', onAbort, { once: true });
  });
}
