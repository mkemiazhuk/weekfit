import path from 'node:path';
import { mkdir } from 'node:fs/promises';
import { createExclusive } from './atomic-fs.mjs';
import { ServiceError } from '../recognition.mjs';

/**
 * One complimentary AI photo analysis per authenticated user (Firebase UID / local-developer).
 * File: exclusive create under DATA_DIR. Redis: SET NX.
 */
export async function createFileFreeTrialStore({ dataDir }) {
  const root = path.join(dataDir, 'photo-free-trial');
  await mkdir(root, { recursive: true });

  return {
    kind: 'file',
    async claim(userId) {
      if (!userId || typeof userId !== 'string') return false;
      const safe = encodeURIComponent(userId);
      const claimed = await createExclusive(
        path.join(root, `${safe}.json`),
        JSON.stringify({ userId, at: Date.now() }),
      );
      return claimed;
    },
  };
}

export function createRedisFreeTrialStore({ redis }) {
  return {
    kind: 'redis',
    async claim(userId) {
      if (!userId || typeof userId !== 'string') return false;
      const key = `weekfit:photo-free-trial:${userId}`;
      const result = await redis.set(key, String(Date.now()), { nx: true });
      return result === 'OK' || result === true;
    },
  };
}

export function createMemoryFreeTrialStore() {
  const claimed = new Set();
  return {
    kind: 'memory',
    async claim(userId) {
      if (!userId || typeof userId !== 'string') return false;
      if (claimed.has(userId)) return false;
      claimed.add(userId);
      return true;
    },
  };
}

/**
 * Paid JWS wins. Otherwise one free trial when client sends X-WeekFit-Photo-Free-Trial: 1.
 */
export async function requirePaidOrFreeTrial(headerValue, options = {}) {
  const {
    requirePaid,
    freeTrialStore,
    freeTrialRequested,
    userId,
    allowDevAuth = false,
  } = options;

  try {
    const paid = requirePaid(headerValue, { allowDevAuth });
    return { access: 'paid', ...paid };
  } catch (error) {
    if (!(error instanceof ServiceError) || error.status !== 402) throw error;
  }

  if (!freeTrialRequested || !freeTrialStore) {
    throw new ServiceError('subscription_required', 402);
  }

  const claimed = await freeTrialStore.claim(userId);
  if (!claimed) {
    throw new ServiceError('subscription_required', 402);
  }

  return { access: 'free_trial', productId: 'free_trial', environment: 'client' };
}

export function isFreeTrialHeader(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}
