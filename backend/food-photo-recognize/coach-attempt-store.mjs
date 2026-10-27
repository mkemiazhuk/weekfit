import { createHash, randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { mkdir, readdir } from 'node:fs/promises';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { ServiceError } from './recognition.mjs';
import { createExclusive, readJson, removeQuiet, writeJsonAtomic as durableWrite } from './async/atomic-fs.mjs';

/**
 * Durable Coach attempt ledger on one directory.
 *
 * Process ownership is a SQLite RESERVED lock held until this process releases
 * it or dies. A paused owner still holds that lock. File age and a heartbeat
 * timestamp are not proof that the owner died, so they never transfer the lock.
 * The committed fence increases only after the OS lock is acquired. A writer
 * whose fence is no longer current does not publish records and does not remove
 * another owner's files.
 *
 * An inflight file older than the provider grace is closed to terminal unknown
 * only by the current owner. That does not clear meta.lastAttemptAt and does
 * not allow another provider call for that attempt.
 *
 * Two processes on this directory share the files. That is not a multi-instance
 * deployment guarantee: a second disk does not.
 */

const LEGACY_PROMPT_VERSIONS = [6, 7, 8, 9, 10, 11, 12, 13];

function openProcessLock(file) {
  mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec('PRAGMA busy_timeout = 0');
  try {
    db.exec('BEGIN IMMEDIATE');
  } catch {
    db.close();
    return { held: false, release() {} };
  }
  let released = false;
  return {
    held: true,
    release() {
      if (released) return;
      released = true;
      try { db.exec('ROLLBACK'); } catch { /* already closed */ }
      try { db.close(); } catch { /* already closed */ }
    },
  };
}

function bumpFence(file) {
  mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec('PRAGMA synchronous = FULL');
  db.exec('PRAGMA journal_mode = DELETE');
  db.exec('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
  db.exec(`INSERT OR IGNORE INTO meta(key, value) VALUES ('fence', 0)`);
  db.exec('BEGIN IMMEDIATE');
  const row = db.prepare(`UPDATE meta SET value = value + 1 WHERE key = 'fence' RETURNING value`).get();
  db.exec('COMMIT');
  db.close();
  return Number(row.value);
}

function readFence(file) {
  try {
    const db = new DatabaseSync(file);
    const row = db.prepare(`SELECT value FROM meta WHERE key = 'fence'`).get();
    db.close();
    return Number(row?.value ?? 0);
  } catch {
    return 0;
  }
}

export function coachUserHash(uid) {
  return createHash('sha256').update(String(uid)).digest('hex');
}

export function legacyAttemptFileName(uid, day, locale = null, promptVersion = null) {
  const key = locale == null
    ? JSON.stringify([uid, day])
    : JSON.stringify([uid, day, locale, promptVersion]);
  return `${createHash('sha256').update(key).digest('hex')}.json`;
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

export function createCoachAttemptStore({
  dir,
  clock = () => new Date(),
  promptVersion,
  limits,
  failDurableWrite = null,
}) {
  const root = path.join(dir, 'coach-guard');
  const fencePath = path.join(root, 'fence.sqlite');
  const bootId = randomUUID();
  const waiters = new Map();
  const nowMs = () => clock().getTime();
  let processLock = { held: false, release() {} };
  let storeBroken = false;
  try {
    processLock = openProcessLock(path.join(root, 'owner.sqlite'));
  } catch {
    storeBroken = true;
  }
  let lockHeld = processLock.held;
  const myFence = lockHeld ? bumpFence(fencePath) : 0;
  let tail = Promise.resolve();
  let stopped = false;

  function withMutex(fn) {
    const run = tail.then(() => fn(), () => fn());
    tail = run.then(() => {}, () => {});
    return run;
  }

  function stillOwner() {
    return !stopped && lockHeld && readFence(fencePath) === myFence;
  }

  function dropProcessLock() {
    processLock.release();
    lockHeld = false;
  }

  function stop() {
    if (stopped) return;
    stopped = true;
    dropProcessLock();
  }
  const dayPath = (userKey, localDay) => path.join(root, 'users', userKey, 'days', `${localDay}.json`);
  const metaPath = (userKey) => path.join(root, 'users', userKey, 'meta.json');
  const inflightPath = (attemptId) => path.join(root, 'inflight', `${attemptId}.json`);
  const minutePath = (attemptId) => path.join(root, 'budget', 'minute', `${attemptId}.json`);
  const dayBudgetDir = (utcDay) => path.join(root, 'budget', 'utc-day', utcDay);
  const circuitPath = path.join(root, 'circuit.json');

  async function persist(file, value) {
    if (!stillOwner()) throw new ServiceError('coach_lock_lost', 503);
    if (failDurableWrite && value?.state === failDurableWrite) {
      throw new ServiceError('coach_store_unavailable', 503);
    }
    await durableWrite(file, value);
  }

  async function listJson(directory) {
    try {
      return (await readdir(directory)).filter((name) => name.endsWith('.json'));
    } catch (error) {
      if (error.code === 'ENOENT') return [];
      throw new ServiceError('coach_store_unavailable', 503);
    }
  }

  function block(code, status, nextEligibleAt, event) {
    const error = new ServiceError(code, status, {
      nextEligibleAt,
      retryAfterSeconds: nextEligibleAt
        ? Math.max(1, Math.ceil((Date.parse(nextEligibleAt) - nowMs()) / 1000))
        : undefined,
    });
    error.coachEvent = event;
    throw error;
  }

  async function readLegacy(uid, localDay, locale) {
    const names = new Set([
      legacyAttemptFileName(uid, localDay),
      ...LEGACY_PROMPT_VERSIONS.filter((version) => version <= promptVersion)
        .map((version) => legacyAttemptFileName(uid, localDay, locale, version)),
    ]);
    let chosen = null;
    for (const name of names) {
      const row = await readJson(path.join(dir, name), null);
      if (!row || typeof row !== 'object') continue;
      const rank = row.status === 'completed' ? 3 : row.status === 'failed' ? 2 : 1;
      if (!chosen || rank > chosen.rank) chosen = { rank, row };
    }
    return chosen?.row ?? null;
  }

  function fromLegacy(legacy, userKey, localDay, timezone, locale) {
    const stamp = Date.parse(legacy.result?.generatedAt ?? '');
    return {
      state: legacy.status === 'completed' && legacy.result
        ? 'completed'
        : legacy.status === 'failed' ? 'failed' : 'unknown',
      attemptId: randomUUID(),
      userKey,
      uidHash: userKey.slice(0, 16),
      localDay,
      timezone,
      locale,
      promptVersion,
      reservedAt: Number.isFinite(stamp) ? new Date(stamp).toISOString() : new Date(nowMs()).toISOString(),
      result: legacy.status === 'completed' ? legacy.result : undefined,
      reason: legacy.status === 'failed' ? (legacy.error ?? 'summary_already_attempted') : 'legacy_attempt',
      migratedFrom: 'legacy-day-file',
      ownerBootId: 'legacy',
    };
  }

  function ageMs(record, now) {
    const started = Date.parse(record.providerStartedAt ?? record.reservedAt ?? '');
    return Number.isFinite(started) ? now - started : limits.attemptGraceMs;
  }

  async function reconcileStaleInflight(now) {
    if (!stillOwner()) return;
    const directory = path.join(root, 'inflight');
    for (const name of await listJson(directory)) {
      const file = path.join(directory, name);
      const row = await readJson(file, null);
      const at = Number(row?.at);
      const age = Number.isFinite(at) ? now - at : limits.attemptGraceMs;
      if (age < limits.attemptGraceMs) continue;
      if (row?.userKey && row?.localDay && row?.attemptId) {
        const record = await readJson(dayPath(row.userKey, row.localDay), null);
        if (record
          && record.attemptId === row.attemptId
          && (record.state === 'reserved' || record.state === 'provider_started')) {
          await writeUnknown(record, 'owner_lost');
        }
      }
      await removeQuiet(file);
    }
  }

  async function loadRecord(uid, localDay, timezone, locale) {
    const userKey = coachUserHash(uid);
    let record = await readJson(dayPath(userKey, localDay), null);
    if (!record) {
      const legacy = await readLegacy(uid, localDay, locale);
      if (legacy && stillOwner()) {
        record = fromLegacy(legacy, userKey, localDay, timezone, locale);
        record.fence = myFence;
        await persist(dayPath(userKey, localDay), record);
        const meta = await readJson(metaPath(userKey), null);
        if (!meta?.lastAttemptAt) {
          const at = Date.parse(record.reservedAt);
          await persist(metaPath(userKey), {
            lastAttemptAt: Number.isFinite(at) ? at : nowMs(),
            lastTimezone: timezone,
            lastLocalDay: localDay,
          });
        }
      } else if (legacy) {
        record = fromLegacy(legacy, userKey, localDay, timezone, locale);
      }
    }
    return record;
  }

  async function writeUnknown(record, reason) {
    const next = { ...record, state: 'unknown', reason, unknownAt: new Date(nowMs()).toISOString() };
    if (!stillOwner()) return next;
    if (record.fence != null && record.fence !== myFence) return next;
    await persist(dayPath(record.userKey, record.localDay), next);
    await removeQuiet(inflightPath(record.attemptId));
    return next;
  }

  async function interpret(record) {
    if (!record) return null;
    if (record.state === 'completed' && record.result) return { kind: 'completed', record };
    if (record.state === 'failed') return { kind: 'terminal', code: 'attempt_failed', status: 409, record };
    if (record.state === 'unknown') return { kind: 'terminal', code: 'attempt_unknown', status: 409, record };
    if (record.state === 'reserved' || record.state === 'provider_started') {
      const waiter = waiters.get(record.attemptId);
      if (record.ownerBootId === bootId && waiter) {
        return { kind: 'join', record, promise: waiter.promise };
      }
      if (ageMs(record, nowMs()) < limits.attemptGraceMs) {
        return { kind: 'pending', code: 'attempt_pending', status: 202, record };
      }
      const unknown = await writeUnknown(record, 'owner_lost');
      return { kind: 'terminal', code: 'attempt_unknown', status: 409, record: unknown };
    }
    const unknown = await writeUnknown(record, 'unrecognized_state');
    return { kind: 'terminal', code: 'attempt_unknown', status: 409, record: unknown };
  }

  async function loadCircuit() {
    return await readJson(circuitPath, null) ?? {
      state: 'closed', consecutiveFailures: 0, openedAt: 0, probeClaimed: false,
    };
  }

  async function decide({ uid, localDay, timezone, locale, aiEnabled }) {
    const userKey = coachUserHash(uid);
    return withMutex(async () => {
      if (storeBroken) throw new ServiceError('coach_store_unavailable', 503);
      const now = nowMs();
      await reconcileStaleInflight(now);
      const record = await loadRecord(uid, localDay, timezone, locale);
      const existing = await interpret(record);
      if (existing) return existing;
      if (!stillOwner()) block('coach_instance_busy', 503, null, 'global_limit_blocked');

      const meta = await readJson(metaPath(userKey), null);
      if (meta?.lastAttemptAt && now - meta.lastAttemptAt < limits.minIntervalMs) {
        block('uid_interval_blocked', 429, new Date(meta.lastAttemptAt + limits.minIntervalMs).toISOString(), 'daily_attempt_blocked');
      }
      if (!aiEnabled) block('coach_ai_disabled', 403, null, 'daily_attempt_blocked');

      let circuit = await loadCircuit();
      if (circuit.state === 'open' && now - circuit.openedAt < limits.circuitOpenMs) {
        block('circuit_open', 503, new Date(circuit.openedAt + limits.circuitOpenMs).toISOString(), 'circuit_open');
      }
      if (circuit.state === 'open') circuit = { ...circuit, state: 'half_open', probeClaimed: false };
      if (circuit.state === 'half_open' && circuit.probeClaimed) {
        const probeRecord = circuit.probeUserKey
          ? await readJson(dayPath(circuit.probeUserKey, circuit.probeLocalDay), null)
          : null;
        const probeLive = probeRecord
          && (probeRecord.state === 'reserved' || probeRecord.state === 'provider_started')
          && ageMs(probeRecord, now) < limits.attemptGraceMs;
        if (!probeLive) {
          await persist(circuitPath, {
            state: 'open',
            consecutiveFailures: circuit.consecutiveFailures ?? limits.circuitFailures,
            openedAt: now,
            probeClaimed: false,
          });
        }
        block('circuit_open', 503, new Date(now + limits.circuitOpenMs).toISOString(), 'circuit_open');
      }
      const probe = circuit.state === 'half_open';

      const utcDay = new Date(now).toISOString().slice(0, 10);
      if (await countDir(dayBudgetDir(utcDay)) >= limits.maxStartsPerUtcDay) {
        block('global_daily_limit', 429, nextUtcMidnight(now), 'global_limit_blocked');
      }
      if (await countMinute(now) >= limits.maxStartsPerMinute) {
        block('global_minute_limit', 429, new Date(now + 60_000).toISOString(), 'global_limit_blocked');
      }
      if (await countDir(path.join(root, 'inflight')) >= limits.maxConcurrent) {
        block('coach_concurrency_limited', 503, null, 'global_limit_blocked');
      }
      if (limits.singleInstanceDeclared === false) {
        block('coach_single_instance_required', 503, null, 'global_limit_blocked');
      }
      if (!stillOwner()) block('coach_instance_busy', 503, null, 'global_limit_blocked');
      if (failDurableWrite === 'reserved') throw new ServiceError('coach_store_unavailable', 503);

      const attemptId = randomUUID();
      const fresh = {
        state: 'reserved',
        attemptId,
        userKey,
        uidHash: userKey.slice(0, 16),
        localDay,
        timezone,
        locale,
        promptVersion,
        reservedAt: new Date(now).toISOString(),
        ownerBootId: bootId,
        fence: myFence,
        probe,
      };
      const created = await createExclusive(dayPath(userKey, localDay), JSON.stringify(fresh));
      if (!created) return interpret(await readJson(dayPath(userKey, localDay), null));

      await mkdir(dayBudgetDir(utcDay), { recursive: true });
      await createExclusive(path.join(dayBudgetDir(utcDay), `${attemptId}.json`), JSON.stringify({ at: now }));
      await mkdir(path.dirname(minutePath(attemptId)), { recursive: true });
      await persist(minutePath(attemptId), { at: now, attemptId });
      await mkdir(path.dirname(inflightPath(attemptId)), { recursive: true });
      await createExclusive(inflightPath(attemptId), JSON.stringify({
        attemptId, at: now, bootId, userKey, localDay,
      }));
      await persist(metaPath(userKey), { lastAttemptAt: now, lastTimezone: timezone, lastLocalDay: localDay });
      if (probe) {
        await persist(circuitPath, {
          ...circuit,
          state: 'half_open',
          probeClaimed: true,
          probeAttemptId: attemptId,
          probeUserKey: userKey,
          probeLocalDay: localDay,
        });
      }
      const slot = deferred();
      // The owner does not await this promise. A rejection still has a handler,
      // so a failed attempt cannot surface as an unhandled rejection and a retry.
      slot.promise.catch(() => {});
      waiters.set(attemptId, slot);
      return { kind: 'owner', record: fresh, deferred: slot };
    });
  }

  async function countDir(directory) {
    return (await listJson(directory)).length;
  }

  async function countMinute(now) {
    const directory = path.join(root, 'budget', 'minute');
    let count = 0;
    for (const name of await listJson(directory)) {
      const row = await readJson(path.join(directory, name), null);
      if (!row || typeof row.at !== 'number') continue;
      if (now - row.at < 60_000) count += 1;
      else if (now - row.at > 120_000) await removeQuiet(path.join(directory, name));
    }
    return count;
  }

  function nextUtcMidnight(now) {
    const d = new Date(now);
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)).toISOString();
  }

  async function markProviderStarted(record) {
    if (!stillOwner()) throw new ServiceError('coach_lock_lost', 503);
    const current = await readJson(dayPath(record.userKey, record.localDay), null);
    if (!current
      || current.attemptId !== record.attemptId
      || current.ownerBootId !== bootId
      || current.fence !== myFence
      || current.state !== 'reserved') {
      throw new ServiceError('coach_lock_lost', 409);
    }
    const next = { ...current, state: 'provider_started', providerStartedAt: new Date(nowMs()).toISOString() };
    await persist(dayPath(record.userKey, record.localDay), next);
    return next;
  }

  async function markFinished(record, state, extra = {}) {
    return withMutex(async () => {
      if (!stillOwner()) throw new ServiceError('coach_lock_lost', 503);
      const current = await readJson(dayPath(record.userKey, record.localDay), null);
      if (!current
        || current.attemptId !== record.attemptId
        || current.ownerBootId !== bootId
        || (current.fence != null && current.fence !== myFence)) {
        throw new ServiceError('coach_lock_lost', 409);
      }
      const next = {
        ...current,
        state,
        reason: extra.reason,
        result: extra.result,
        finishedAt: new Date(nowMs()).toISOString(),
      };
      await persist(dayPath(record.userKey, record.localDay), next);
      await removeQuiet(inflightPath(record.attemptId));
      const circuit = await loadCircuit();
      if (state === 'completed') {
        await persist(circuitPath, { state: 'closed', consecutiveFailures: 0, openedAt: 0, probeClaimed: false });
      } else {
        const failures = (circuit.consecutiveFailures ?? 0) + 1;
        const open = circuit.state === 'half_open' || failures >= limits.circuitFailures;
        await persist(circuitPath, {
          state: open ? 'open' : 'closed',
          consecutiveFailures: failures,
          openedAt: open ? nowMs() : 0,
          probeClaimed: false,
        });
      }
      return next;
    });
  }

  async function read({ uid, localDay, timezone, locale }) {
    return withMutex(async () => {
      if (storeBroken) throw new ServiceError('coach_store_unavailable', 503);
      if (stillOwner()) await reconcileStaleInflight(nowMs());
      const record = await loadRecord(uid, localDay, timezone ?? 'UTC', locale);
      if (!record) return { kind: 'absent' };
      return await interpret(record) ?? { kind: 'absent' };
    });
  }

  function settle(attemptId, error, value) {
    const waiter = waiters.get(attemptId);
    waiters.delete(attemptId);
    if (!waiter) return;
    if (error) waiter.reject(error);
    else waiter.resolve(value);
  }

  return {
    bootId,
    decide,
    read,
    markProviderStarted,
    markFinished,
    settle,
    stop,
    dropProcessLock,
    ownsProcessLock: () => lockHeld && !stopped,
  };
}
