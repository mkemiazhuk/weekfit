import path from 'node:path';
import { mkdir, readdir } from 'node:fs/promises';
import { createExclusive, removeQuiet, readJson } from './atomic-fs.mjs';

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

  const reserve = async ({ userId, analysisId }) => {
    const day = dayKey();
    const reservationPath = path.join(reservationsDir, `${analysisId}.json`);
    const reserved = await createExclusive(
      reservationPath,
      JSON.stringify({ userId, analysisId, day, at: Date.now() }),
    );
    if (!reserved) {
      return { charged: false, reason: 'already_reserved' };
    }

    const userDir = path.join(usersDir, day, encodeURIComponent(userId));
    const globalDayDir = path.join(globalDir, day);
    await mkdir(userDir, { recursive: true });
    await mkdir(globalDayDir, { recursive: true });

    const userMarker = path.join(userDir, `${analysisId}.res`);
    const globalMarker = path.join(globalDayDir, `${analysisId}.res`);
    await createExclusive(userMarker, '1');
    await createExclusive(globalMarker, '1');

    const userCount = await countRes(userDir);
    const globalCount = await countRes(globalDayDir);

    if (userCount > userDailyLimit || globalCount > globalDailyLimit) {
      await removeQuiet(userMarker);
      await removeQuiet(globalMarker);
      await removeQuiet(reservationPath);
      const err = new Error('daily_scan_limit');
      err.code = 'daily_scan_limit';
      throw err;
    }

    return {
      charged: true,
      userCount,
      globalCount,
      day,
    };
  };

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
