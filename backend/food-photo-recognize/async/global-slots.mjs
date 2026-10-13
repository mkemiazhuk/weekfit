import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { writeJsonAtomic, readJson, removeQuiet } from './atomic-fs.mjs';
import { readdir } from 'node:fs/promises';

/**
 * Cross-process AI concurrency limit: each active provider call holds a lease file
 * under meta/ai-slots/. Expired leases are swept so crashed workers do not wedge the fleet.
 */
export function createGlobalAiSlots({ dataDir, maxConcurrent, leaseMs = 120_000 }) {
  const dir = path.join(dataDir, 'meta', 'ai-slots');

  const sweep = async (now = Date.now()) => {
    let entries = [];
    try {
      entries = await readdir(dir);
    } catch (error) {
      if (error.code === 'ENOENT') return 0;
      throw error;
    }
    let removed = 0;
    for (const name of entries) {
      if (!name.endsWith('.json')) continue;
      const slot = await readJson(path.join(dir, name), null);
      if (!slot || slot.expiresAt <= now) {
        await removeQuiet(path.join(dir, name));
        removed += 1;
      }
    }
    return removed;
  };

  const activeCount = async () => {
    await sweep();
    try {
      return (await readdir(dir)).filter((n) => n.endsWith('.json')).length;
    } catch (error) {
      if (error.code === 'ENOENT') return 0;
      throw error;
    }
  };

  const tryAcquire = async (ownerId) => {
    await sweep();
    const active = await activeCount();
    if (active >= maxConcurrent) return null;
    const id = randomUUID();
    const file = path.join(dir, `${id}.json`);
    // Best-effort: two processes may both pass the count check; accept small overshoot
    // under file store. Redis SET NX + INCR is the staging hardening path.
    await writeJsonAtomic(file, {
      id,
      ownerId,
      acquiredAt: Date.now(),
      expiresAt: Date.now() + leaseMs,
    });
    const after = await activeCount();
    if (after > maxConcurrent) {
      await removeQuiet(file);
      return null;
    }
    return {
      id,
      release: async () => removeQuiet(file),
      renew: async () => writeJsonAtomic(file, {
        id,
        ownerId,
        acquiredAt: Date.now(),
        expiresAt: Date.now() + leaseMs,
      }),
    };
  };

  return { tryAcquire, activeCount, sweep, maxConcurrent };
}
