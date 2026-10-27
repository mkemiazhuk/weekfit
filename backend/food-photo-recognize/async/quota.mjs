import path from 'node:path';
import { createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { mkdir, readdir, rename } from 'node:fs/promises';
import { DatabaseSync } from 'node:sqlite';
import { createExclusive, readJson, removeQuiet } from './atomic-fs.mjs';

/** Stable owner folder. The same UID always maps to the same key. */
export function ownerKey(userId) {
  return createHash('sha256').update(String(userId)).digest('hex').slice(0, 24);
}

/**
 * Atomic daily quota reservation shared across API instances (same DATA_DIR).
 * A charge is the reservation file plus the user and global markers.
 * A crash between those writes is repaired under the lock before a new charge
 * or a provider call is allowed. Counts are the marker files after repair.
 */
export function createQuotaStore({
  dataDir,
  userDailyLimit,
  globalDailyLimit,
  failAfter = null,
}) {
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

  const reservationFile = (userId, analysisId) => path.join(
    reservationsDir,
    `${ownerKey(userId)}--${analysisId}.json`,
  );
  const legacyReservationFile = (analysisId) => path.join(reservationsDir, `${analysisId}.json`);
  const userMarker = (day, userId, analysisId) => path.join(
    usersDir,
    day,
    encodeURIComponent(userId),
    `${analysisId}.res`,
  );
  const globalMarker = (day, userId, analysisId) => path.join(
    globalDir,
    day,
    `${ownerKey(userId)}--${analysisId}.res`,
  );
  const legacyGlobalMarker = (day, analysisId) => path.join(globalDir, day, `${analysisId}.res`);

  const crashAfter = async (step) => {
    if (failAfter !== step) return;
    const error = new Error('quota_write_interrupted');
    error.code = 'quota_write_interrupted';
    error.step = step;
    throw error;
  };

  const ensureMarkers = async (record) => {
    const { userId, analysisId, day } = record;
    const userDir = path.join(usersDir, day, encodeURIComponent(userId));
    const globalDayDir = path.join(globalDir, day);
    await mkdir(userDir, { recursive: true });
    await mkdir(globalDayDir, { recursive: true });
    await createExclusive(userMarker(day, userId, analysisId), '1');
    const next = globalMarker(day, userId, analysisId);
    const legacy = legacyGlobalMarker(day, analysisId);
    try {
      await rename(legacy, next);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    await createExclusive(next, '1');
    if (legacy !== next) await removeQuiet(legacy);
  };

  const readOwnedReservation = async (userId, analysisId) => {
    const current = await readJson(reservationFile(userId, analysisId), null);
    if (current?.userId === userId && current.analysisId === analysisId) return current;
    const legacy = await readJson(legacyReservationFile(analysisId), null);
    if (legacy?.userId !== userId || legacy.analysisId !== analysisId) return null;
    return legacy;
  };

  const repairCharges = async () => {
    let names = [];
    try {
      names = await readdir(reservationsDir);
    } catch (error) {
      if (error.code === 'ENOENT') return;
      throw error;
    }
    for (const name of names) {
      if (!name.endsWith('.json')) continue;
      const record = await readJson(path.join(reservationsDir, name), null);
      if (!record?.userId || !record.analysisId || !record.day) continue;
      await ensureMarkers(record);
    }
  };

  const countsFor = async (userId, day) => ({
    userCount: await countRes(path.join(usersDir, day, encodeURIComponent(userId))),
    globalCount: await countRes(path.join(globalDir, day)),
  });

  const reserve = async ({ userId, analysisId }) => withQuotaLock(dataDir, async () => {
    await repairCharges();
    const day = dayKey();
    const existing = await readOwnedReservation(userId, analysisId);
    if (existing) {
      if (existing.userId !== userId) {
        const error = new Error('quota_owner_mismatch');
        error.code = 'quota_owner_mismatch';
        throw error;
      }
      await ensureMarkers({ ...existing, day: existing.day || day });
      const counts = await countsFor(userId, existing.day || day);
      return { charged: false, recovered: true, reason: 'already_reserved', ...counts, day: existing.day || day };
    }

    const userDir = path.join(usersDir, day, encodeURIComponent(userId));
    const globalDayDir = path.join(globalDir, day);
    const before = await countsFor(userId, day);
    if (before.userCount >= userDailyLimit || before.globalCount >= globalDailyLimit) {
      const err = new Error('daily_scan_limit');
      err.code = 'daily_scan_limit';
      throw err;
    }

    await mkdir(userDir, { recursive: true });
    await mkdir(globalDayDir, { recursive: true });
    const record = { userId, analysisId, day, at: Date.now() };
    const reserved = await createExclusive(reservationFile(userId, analysisId), JSON.stringify(record));
    if (!reserved) {
      await ensureMarkers(record);
      const counts = await countsFor(userId, day);
      return { charged: false, recovered: true, reason: 'already_reserved', ...counts, day };
    }
    await crashAfter('reservation');
    await createExclusive(userMarker(day, userId, analysisId), '1');
    await crashAfter('userMarker');
    await createExclusive(globalMarker(day, userId, analysisId), '1');
    await crashAfter('globalMarker');
    return {
      charged: true,
      recovered: false,
      userCount: before.userCount + 1,
      globalCount: before.globalCount + 1,
      day,
    };
  });

  const snapshot = async (userId) => {
    const day = dayKey();
    const counts = await withQuotaLock(dataDir, async () => {
      await repairCharges();
      return countsFor(userId, day);
    });
    return {
      day,
      ...counts,
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
