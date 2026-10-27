import path from 'node:path';
import { mkdirSync } from 'node:fs';
import { mkdir, readdir } from 'node:fs/promises';
import { DatabaseSync } from 'node:sqlite';
import { createExclusive, readJson } from './atomic-fs.mjs';

/**
 * Atomic daily quota reservation shared across API instances (same DATA_DIR).
 * Each analysisId gets an exclusive reservation file. User/global counts are the
 * number of reservation markers (not a racy read-modify-write counter).
 */
export function createQuotaStore({ dataDir, userDailyLimit, globalDailyLimit }) {
  const usersDir = path.join(dataDir, 'quota', 'users');
  const globalDir = path.join(dataDir, 'quota', 'global');
  const reservationsDir = path.join(dataDir, 'quota', 'reservations');
  const dayKey = () => new Date().toISOString().slice(0, 10);

  const countRes = async (dir) => {
    try {
      return (await readdir(dir)).filter((n) => n.endsWith('.res')).length;
    } catch (error) {
      if (error.code === 'ENOENT') return 0;
      throw error;
    }
  };

  const reserve = async ({ userId, analysisId }) => withQuotaLock(dataDir, async () => {
    const day = dayKey();
    const reservationPath = path.join(reservationsDir, `${analysisId}.json`);
    const existing = await readJson(reservationPath, null);
    if (existing) return { charged: false, reason: 'already_reserved' };

    const userDir = path.join(usersDir, day, encodeURIComponent(userId));
    const globalDayDir = path.join(globalDir, day);
    const userCount = await countRes(userDir);
    const globalCount = await countRes(globalDayDir);
    if (userCount >= userDailyLimit || globalCount >= globalDailyLimit) {
      const err = new Error('daily_scan_limit');
      err.code = 'daily_scan_limit';
      throw err;
    }

    await mkdir(userDir, { recursive: true });
    await mkdir(globalDayDir, { recursive: true });
    const reserved = await createExclusive(
      reservationPath,
      JSON.stringify({ userId, analysisId, day, at: Date.now() }),
    );
    if (!reserved) return { charged: false, reason: 'already_reserved' };

    const userMarker = path.join(userDir, `${analysisId}.res`);
    const globalMarker = path.join(globalDayDir, `${analysisId}.res`);
    await createExclusive(userMarker, '1');
    await createExclusive(globalMarker, '1');
    return {
      charged: true,
      userCount: userCount + 1,
      globalCount: globalCount + 1,
      day,
    };
  });

  const snapshot = async (userId) => {
    const day = dayKey();
    const userCount = await countRes(path.join(usersDir, day, encodeURIComponent(userId)));
    const globalCount = await countRes(path.join(globalDir, day));
    return {
      day,
      userCount,
      globalCount,
      userDailyLimit,
      globalDailyLimit,
    };
  };

  return { reserve, snapshot };
}

async function withQuotaLock(dataDir, fn) {
  const lockFile = path.join(dataDir, 'quota', 'lock.sqlite');
  mkdirSync(path.dirname(lockFile), { recursive: true });
  const deadline = Date.now() + 2000;
  while (true) {
    const db = new DatabaseSync(lockFile);
    // busy_timeout 0 returns immediately. A blocking wait would freeze this thread
    // and deadlock the holder, which is awaiting work on the same thread.
    db.exec('PRAGMA busy_timeout = 0');
    try {
      db.exec('BEGIN IMMEDIATE');
    } catch (error) {
      db.close();
      if (Date.now() >= deadline) {
        const err = new Error('quota_store_busy');
        err.code = 'quota_store_busy';
        err.cause = error;
        throw err;
      }
      await new Promise((resolve) => setTimeout(resolve, 5));
      continue;
    }
    try {
      return await fn();
    } finally {
      try { db.exec('COMMIT'); } catch { /* rolled back on process death */ }
      db.close();
    }
  }
}
