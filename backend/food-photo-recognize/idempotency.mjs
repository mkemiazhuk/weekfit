import { createHash } from 'node:crypto';
import { ServiceError } from './recognition.mjs';

/**
 * Process-local idempotency for photo recognition.
 * Keyed by `${userId}:${idempotencyKey}` — not shared across instances / restarts.
 *
 * Abort semantics: a shared in-flight analysis is aborted only when the last waiter
 * disconnects. One client's cancel must not kill work still awaited by others.
 */
export function createIdempotencyStore({ ttlMs = 5 * 60_000, maxEntries = 2000 } = {}) {
  /** @type {Map<string, {
   *   status: 'inflight'|'done',
   *   fingerprint: string,
   *   promise?: Promise<any>,
   *   value?: any,
   *   waiters: number,
   *   abortController: AbortController,
   *   expiresAt: number,
   * }>} */
  const entries = new Map();

  const purgeExpired = (now = Date.now()) => {
    for (const [key, entry] of entries) {
      if (entry.expiresAt <= now && entry.status !== 'inflight') entries.delete(key);
    }
    while (entries.size > maxEntries) {
      const oldest = entries.keys().next().value;
      if (oldest === undefined) break;
      const entry = entries.get(oldest);
      if (entry?.status === 'inflight') break;
      entries.delete(oldest);
    }
  };

  const keyFor = (userId, idempotencyKey) => `${userId}:${idempotencyKey}`;

  const makeReleaser = (key) => {
    let released = false;
    return () => {
      if (released) return;
      released = true;
      const entry = entries.get(key);
      if (!entry) return;
      entry.waiters = Math.max(0, entry.waiters - 1);
      if (entry.waiters === 0 && entry.status === 'inflight') {
        entry.abortController.abort();
      }
    };
  };

  /**
   * @param {string} userId
   * @param {string|null} idempotencyKey
   * @param {string} fingerprint
   * @param {(ctx: { abortSignal: AbortSignal }) => Promise<any>} work
   * @param {{ onAttached?: (h: { shared: boolean, abortController: AbortController, releaseWaiter: () => void }) => void }} [options]
   */
  const run = async (userId, idempotencyKey, fingerprint, work, options = {}) => {
    const onAttached = options.onAttached;

    if (!idempotencyKey) {
      const local = new AbortController();
      const releaseWaiter = () => {
        if (!local.signal.aborted) local.abort();
      };
      onAttached?.({ shared: false, abortController: local, releaseWaiter });
      return {
        value: await work({ abortSignal: local.signal }),
        shared: false,
        fromCache: false,
        abortController: local,
        releaseWaiter,
      };
    }

    purgeExpired();
    const key = keyFor(userId, idempotencyKey);
    const existing = entries.get(key);

    if (existing?.status === 'done') {
      if (existing.fingerprint !== fingerprint) {
        throw new ServiceError('idempotency_key_reuse', 409, {
          detail: 'same_key_different_payload',
        });
      }
      const releaseWaiter = () => {};
      onAttached?.({ shared: true, abortController: existing.abortController, releaseWaiter });
      return {
        value: existing.value,
        shared: true,
        fromCache: true,
        abortController: existing.abortController,
        releaseWaiter,
      };
    }

    if (existing?.status === 'inflight' && existing.promise) {
      if (existing.fingerprint !== fingerprint) {
        throw new ServiceError('idempotency_key_reuse', 409, {
          detail: 'same_key_different_payload',
        });
      }
      existing.waiters += 1;
      const releaseWaiter = makeReleaser(key);
      onAttached?.({ shared: true, abortController: existing.abortController, releaseWaiter });
      try {
        const value = await existing.promise;
        return {
          value,
          shared: true,
          fromCache: false,
          abortController: existing.abortController,
          releaseWaiter,
        };
      } catch (error) {
        releaseWaiter();
        throw error;
      }
    }

    const abortController = new AbortController();
    const promise = (async () => {
      try {
        const value = await work({ abortSignal: abortController.signal });
        entries.set(key, {
          status: 'done',
          fingerprint,
          value,
          waiters: 0,
          abortController,
          expiresAt: Date.now() + ttlMs,
        });
        return value;
      } catch (error) {
        // Clear failed / aborted keys so they never stick as in-progress forever.
        entries.delete(key);
        throw error;
      }
    })();

    entries.set(key, {
      status: 'inflight',
      fingerprint,
      promise,
      waiters: 1,
      abortController,
      expiresAt: Date.now() + ttlMs,
    });

    const releaseWaiter = makeReleaser(key);
    onAttached?.({ shared: true, abortController, releaseWaiter });

    try {
      const value = await promise;
      return {
        value,
        shared: true,
        fromCache: false,
        abortController,
        releaseWaiter,
      };
    } catch (error) {
      releaseWaiter();
      throw error;
    }
  };

  const get = (userId, idempotencyKey) => entries.get(keyFor(userId, idempotencyKey));
  const size = () => entries.size;
  const clear = () => entries.clear();
  return { run, size, purgeExpired, get, clear };
}

export function normalizeIdempotencyKey(headerValue) {
  if (typeof headerValue !== 'string') return null;
  const trimmed = headerValue.trim();
  if (!trimmed || trimmed.length > 128) return null;
  if (!/^[A-Za-z0-9._:-]+$/.test(trimmed)) return null;
  return trimmed;
}

export function fingerprintPayload(imageBase64) {
  return createHash('sha256').update(imageBase64).digest('hex');
}
