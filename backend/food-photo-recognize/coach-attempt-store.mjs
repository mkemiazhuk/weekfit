import { createHash, randomUUID } from 'node:crypto';
import { mkdir, open, readdir, unlink } from 'node:fs/promises';
import path from 'node:path';
import { ServiceError } from './recognition.mjs';
import { createExclusive, readJson, removeQuiet, writeJsonAtomic } from './async/atomic-fs.mjs';

/**
 * Durable Coach attempt ledger.
 *
 * The live service already stores coach state on a Render persistent disk
 * (COACH_SUMMARY_STORE_DIR). Exclusive create is atomic for every process that
 * mounts that same volume, so a restart, redeploy, or second instance on the
 * volume cannot mint a second provider call. The in-memory map only lets the
 * same process wait for a call it already started.
 *
 * The lock file is not deleted because of age. If its holder dies, later
 * requests fail closed and do not call OpenAI. Two instances on two different
 * disks, or an ephemeral Redis, are not this guarantee.
 */

const LEGACY_PROMPT_VERSIONS = [6, 7, 8, 9, 10, 11, 12, 13];

export function coachUserHash(uid) {
  return createHash('sha256').update(String(uid)).digest('hex');
}

export function legacyAttemptFileName(uid, day, locale = null, promptVersion = null) {
  const key = locale == null
    ? JSON.stringify([uid, day])
    : JSON.stringify([uid, day, locale, promptVersion]);
  return `${createHash('sha256').update(key).digest('hex')}.json`;
}

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
}) {
  const root = path.join(dir, 'coach-guard');
  const bootId = randomUUID();
  const waiters = new Map();
  const nowMs = () => clock().getTime();
  const dayPath = (userKey, localDay) => path.join(root, 'users', userKey, 'days', `${localDay}.json`);
  const metaPath = (userKey) => path.join(root, 'users', userKey, 'meta.json');
  const inflightPath = (attemptId) => path.join(root, 'inflight', `${attemptId}.json`);
  const minutePath = (attemptId) => path.join(root, 'budget', 'minute', `${attemptId}.json`);
  const dayBudgetDir = (utcDay) => path.join(root, 'budget', 'utc-day', utcDay);
  const circuitPath = path.join(root, 'circuit.json');

  async function withLock(fn) {
    const lockPath = path.join(root, 'lock');
    const deadline = Date.now() + 2000;
    while (true) {
      let handle;
      try {
        await mkdir(root, { recursive: true, mode: 0o700 });
        handle = await open(lockPath, 'wx');
      } catch (error) {
        if (error instanceof ServiceError) throw error;
        if (error.code === 'EEXIST' && Date.now() < deadline) {
          await delay(5);
          continue;
        }
        if (error.code === 'EEXIST') throw new ServiceError('coach_store_busy', 503);
        throw new ServiceError('coach_store_unavailable', 503);
      }
      try {
        await handle.writeFile(JSON.stringify({ pid: process.pid, bootId, at: new Date(nowMs()).toISOString() }));
        return await fn();
      } finally {
        await handle.close();
        await unlink(lockPath).catch(() => {});
      }
    }
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

  async function writeUnknown(record, reason) {
    const next = { ...record, state: 'unknown', reason, unknownAt: new Date(nowMs()).toISOString() };
    await writeJsonAtomic(dayPath(record.userKey, record.localDay), next);
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
    return withLock(async () => {
      const now = nowMs();
      let record = await readJson(dayPath(userKey, localDay), null);
      if (!record) {
        const legacy = await readLegacy(uid, localDay, locale);
        if (legacy) {
          record = fromLegacy(legacy, userKey, localDay, timezone, locale);
          await writeJsonAtomic(dayPath(userKey, localDay), record);
          const meta = await readJson(metaPath(userKey), null);
          if (!meta?.lastAttemptAt) {
            const at = Date.parse(record.reservedAt);
            await writeJsonAtomic(metaPath(userKey), {
              lastAttemptAt: Number.isFinite(at) ? at : now,
              lastTimezone: timezone,
              lastLocalDay: localDay,
            });
          }
        }
      }
      const existing = await interpret(record);
      if (existing) return existing;

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
          await writeJsonAtomic(circuitPath, {
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
        probe,
      };
      const created = await createExclusive(dayPath(userKey, localDay), JSON.stringify(fresh));
      if (!created) return interpret(await readJson(dayPath(userKey, localDay), null));

      await mkdir(dayBudgetDir(utcDay), { recursive: true });
      await createExclusive(path.join(dayBudgetDir(utcDay), `${attemptId}.json`), JSON.stringify({ at: now }));
      await mkdir(path.dirname(minutePath(attemptId)), { recursive: true });
      await writeJsonAtomic(minutePath(attemptId), { at: now, attemptId });
      await mkdir(path.dirname(inflightPath(attemptId)), { recursive: true });
      await createExclusive(inflightPath(attemptId), JSON.stringify({ attemptId, at: now, bootId }));
      await writeJsonAtomic(metaPath(userKey), { lastAttemptAt: now, lastTimezone: timezone, lastLocalDay: localDay });
      if (probe) {
        await writeJsonAtomic(circuitPath, {
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
    const current = await readJson(dayPath(record.userKey, record.localDay), null);
    if (!current || current.attemptId !== record.attemptId || current.ownerBootId !== bootId || current.state !== 'reserved') {
      throw new ServiceError('attempt_not_owner', 409);
    }
    const next = { ...current, state: 'provider_started', providerStartedAt: new Date(nowMs()).toISOString() };
    await writeJsonAtomic(dayPath(record.userKey, record.localDay), next);
    return next;
  }

  async function markFinished(record, state, extra = {}) {
    return withLock(async () => {
      const current = await readJson(dayPath(record.userKey, record.localDay), null);
      const next = {
        ...(current ?? record),
        state,
        reason: extra.reason,
        result: extra.result,
        finishedAt: new Date(nowMs()).toISOString(),
      };
      await writeJsonAtomic(dayPath(record.userKey, record.localDay), next);
      await removeQuiet(inflightPath(record.attemptId));
      const circuit = await loadCircuit();
      if (state === 'completed') {
        await writeJsonAtomic(circuitPath, { state: 'closed', consecutiveFailures: 0, openedAt: 0, probeClaimed: false });
      } else {
        const failures = (circuit.consecutiveFailures ?? 0) + 1;
        const open = circuit.state === 'half_open' || failures >= limits.circuitFailures;
        await writeJsonAtomic(circuitPath, {
          state: open ? 'open' : 'closed',
          consecutiveFailures: failures,
          openedAt: open ? nowMs() : 0,
          probeClaimed: false,
        });
      }
      return next;
    });
  }

  function settle(attemptId, error, value) {
    const waiter = waiters.get(attemptId);
    waiters.delete(attemptId);
    if (!waiter) return;
    if (error) waiter.reject(error);
    else waiter.resolve(value);
  }

  return { bootId, decide, markProviderStarted, markFinished, settle };
}
