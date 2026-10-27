import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { EventEmitter } from 'node:events';
import { readFile, readdir, rename } from 'node:fs/promises';
import { writeJsonAtomic, readJson, createExclusive, removeQuiet } from './atomic-fs.mjs';
import { ownerKey } from './quota.mjs';
import { dataPaths, ensureDataDirs } from './paths.mjs';
import { notifyJobUpdated } from './job-wait.mjs';

export const JOB_STATUSES = Object.freeze({
  queued: 'queued',
  processing: 'processing',
  completed: 'completed',
  failed: 'failed',
});

function idempotencyPath(paths, userId, idempotencyKey) {
  const userHash = createHash('sha256').update(userId).digest('hex').slice(0, 24);
  const keyHash = createHash('sha256').update(idempotencyKey).digest('hex').slice(0, 32);
  return path.join(paths.idempotency, userHash, `${keyHash}.json`);
}

/**
 * Durable file-backed job + idempotency store.
 * Survives process restart. Shared across API instances and workers on the same DATA_DIR.
 * For multi-disk multi-region, use Redis (see redis-store.mjs + render blueprint).
 */
export async function createFileJobStore({ dataDir, jobTtlMs = 24 * 60 * 60_000 }) {
  const paths = dataPaths(dataDir);
  await ensureDataDirs(paths);
  const wake = new EventEmitter();
  wake.setMaxListeners(200);

  const jobPath = (analysisId, userId) => (userId
    ? path.join(paths.jobs, ownerKey(userId), `${analysisId}.json`)
    : path.join(paths.jobs, `${analysisId}.json`));
  const resultPath = (analysisId, userId) => (userId
    ? path.join(paths.results, ownerKey(userId), `${analysisId}.json`)
    : path.join(paths.results, `${analysisId}.json`));

  const getJob = async (analysisId, userId = null) => {
    if (userId) {
      const scoped = await readJson(jobPath(analysisId, userId), null);
      if (scoped) return scoped;
      const legacy = await readJson(jobPath(analysisId), null);
      if (legacy?.userId === userId) {
        const migrated = { ...legacy, ownerUserId: userId };
        await writeJsonAtomic(jobPath(analysisId, userId), migrated);
        return migrated;
      }
      return null;
    }
    return readJson(jobPath(analysisId), null);
  };

  const saveJob = async (job) => {
    const owner = job.ownerUserId || job.userId;
    const next = { ...job, ownerUserId: owner, updatedAt: Date.now() };
    await writeJsonAtomic(jobPath(job.analysisId, owner), next);
    if (next.status === JOB_STATUSES.completed || next.status === JOB_STATUSES.failed) {
      await writeJsonAtomic(resultPath(job.analysisId, owner), {
        analysisId: next.analysisId,
        status: next.status,
        result: next.result ?? null,
        error: next.error ?? null,
        providerOutcome: next.providerOutcome ?? null,
        completedAt: next.updatedAt,
        expiresAt: next.expiresAt,
      });
    }
    return next;
  };

  const reserveIdempotency = async ({ userId, idempotencyKey, fingerprint, analysisId }) => {
    const file = idempotencyPath(paths, userId, idempotencyKey);
    const payload = {
      analysisId,
      fingerprint,
      userId,
      createdAt: Date.now(),
      expiresAt: Date.now() + jobTtlMs,
    };
    const created = await createExclusive(file, `${JSON.stringify(payload)}\n`);
    if (created) return { analysisId, created: true, fingerprint };

    const existing = await readJson(file, null);
    if (!existing) {
      const again = await createExclusive(file, `${JSON.stringify(payload)}\n`);
      if (again) return { analysisId, created: true, fingerprint };
      const err = new Error('idempotency_race');
      err.code = 'idempotency_race';
      throw err;
    }
    if (existing.fingerprint !== fingerprint) {
      const err = new Error('idempotency_key_reuse');
      err.code = 'idempotency_key_reuse';
      err.existingAnalysisId = existing.analysisId;
      throw err;
    }
    return {
      analysisId: existing.analysisId,
      created: false,
      fingerprint: existing.fingerprint,
    };
  };

  const createQueuedJob = async (job) => {
    const record = {
      ...job,
      status: JOB_STATUSES.queued,
      attempts: 0,
      leaseOwner: null,
      leaseUntil: null,
      result: null,
      error: null,
      providerOutcome: null,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      expiresAt: Date.now() + jobTtlMs,
    };
    const owner = record.userId;
    const stored = { ...record, ownerUserId: owner };
    const created = await createExclusive(jobPath(record.analysisId, owner), `${JSON.stringify(stored)}\n`);
    if (!created) {
      const existing = await getJob(record.analysisId, owner);
      if (existing && existing.userId !== record.userId) {
        const error = new Error('analysis_owner_mismatch');
        error.code = 'analysis_owner_mismatch';
        throw error;
      }
      return { job: existing, created: false };
    }
    return { job: stored, created: true };
  };

  const leaseFile = (job) => {
    const owner = job?.ownerUserId || job?.userId;
    const name = owner ? `${ownerKey(owner)}--${job.analysisId}.json` : `${job.analysisId}.json`;
    return path.join(paths.queueLeased, name);
  };

  const readMarker = async (file) => {
    const raw = await readFile(file, 'utf8');
    try {
      const parsed = JSON.parse(raw);
      if (parsed?.analysisId) return parsed;
    } catch {
      // Legacy markers store the analysis id as plain text.
    }
    return { analysisId: raw.trim(), userId: null };
  };

  const listReadyNames = async () => {
    try {
      return (await readdir(paths.queueReady)).filter((n) => !n.endsWith('.claiming'));
    } catch (error) {
      if (error.code === 'ENOENT') return [];
      throw error;
    }
  };

  /** Ready marker name includes the owner key when the job is bound to a UID. */
  const enqueue = async (analysisId, userId = null) => {
    const token = userId ? `${ownerKey(userId)}--${analysisId}` : analysisId;
    const body = JSON.stringify({ analysisId, userId });
    const name = `${Date.now()}.${token}`;
    const marker = path.join(paths.queueReady, name);
    const ok = await createExclusive(marker, body);
    let out = name;
    if (!ok) {
      const alt = `${Date.now()}.${token}.${Math.random().toString(16).slice(2, 8)}`;
      await createExclusive(path.join(paths.queueReady, alt), body);
      out = alt;
    }
    wake.emit('ready');
    return out;
  };

  const parseReadyName = (name) => {
    const dot = name.indexOf('.');
    if (dot < 0) return null;
    // analysisId may itself contain nothing after first uuid — format timestamp.uuid
    // or timestamp.uuid.suffix
    const rest = name.slice(dot + 1);
    const uuidMatch = rest.match(
      /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i,
    );
    return uuidMatch ? uuidMatch[1] : rest.split('.')[0];
  };

  const tryClaimOnce = async ({ workerId, leaseMs }) => {
    const names = (await listReadyNames()).sort();
    for (const name of names) {
      const claimedId = parseReadyName(name);
      if (!claimedId) continue;
      const readyPath = path.join(paths.queueReady, name);
      const claimingPath = `${readyPath}.claiming`;
      try {
        await rename(readyPath, claimingPath);
      } catch (error) {
        if (error.code === 'ENOENT') continue;
        throw error;
      }

      try {
        const marker = await readMarker(claimingPath);
        const job = await getJob(marker.analysisId, marker.userId);
        if (!job || job.userId !== (marker.userId ?? job.userId)
          || job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) {
          await removeQuiet(claimingPath);
          continue;
        }
        const leaseToken = randomUUID();
        const leaseUntil = Date.now() + leaseMs;
        const leased = await saveJob({
          ...job,
          status: JOB_STATUSES.processing,
          leaseOwner: workerId,
          leaseToken,
          leaseUntil,
          processingStartedAt: Date.now(),
          attempts: (job.attempts ?? 0) + 1,
        });
        await writeJsonAtomic(leaseFile(leased), {
          analysisId: leased.analysisId,
          userId: leased.userId,
          workerId,
          leaseToken,
          leaseUntil,
          claimedAt: Date.now(),
        });
        await removeQuiet(claimingPath);
        notifyJobUpdated(claimedId);
        return leased;
      } catch (error) {
        try {
          await rename(claimingPath, readyPath);
        } catch {
          await removeQuiet(claimingPath);
        }
        throw error;
      }
    }
    return null;
  };

  const claimNext = async ({ workerId, leaseMs, waitMs = 0 }) => {
    const first = await tryClaimOnce({ workerId, leaseMs });
    if (first || waitMs <= 0) return first;
    const deadline = Date.now() + waitMs;
    while (Date.now() < deadline) {
      const remaining = deadline - Date.now();
      await new Promise((resolve) => {
        const timer = setTimeout(resolve, Math.min(remaining, 5000));
        wake.once('ready', () => {
          clearTimeout(timer);
          resolve();
        });
      });
      const job = await tryClaimOnce({ workerId, leaseMs });
      if (job) return job;
    }
    return null;
  };

  const recoverExpiredLeases = async (now = Date.now()) => {
    let recovered = 0;
    let entries = [];
    try {
      entries = await readdir(paths.queueLeased);
    } catch (error) {
      if (error.code === 'ENOENT') return { recovered: 0 };
      throw error;
    }
    for (const name of entries) {
      if (!name.endsWith('.json')) continue;
      const lease = await readJson(path.join(paths.queueLeased, name), null);
      if (!lease || lease.leaseUntil > now) continue;
      const job = await getJob(lease.analysisId, lease.userId);
      if (!job) {
        await removeQuiet(path.join(paths.queueLeased, name));
        continue;
      }
      if (job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) {
        await removeQuiet(path.join(paths.queueLeased, name));
        continue;
      }
      if (job.providerStarted) {
        await saveJob({
          ...job,
          status: JOB_STATUSES.failed,
          error: 'lease_expired_after_provider',
          providerOutcome: 'uncertain',
          leaseOwner: null,
          leaseUntil: null,
          leaseToken: null,
        });
        await removeQuiet(path.join(paths.queueLeased, name));
        recovered += 1;
        continue;
      }
      await saveJob({
        ...job,
        status: JOB_STATUSES.queued,
        leaseOwner: null,
        leaseUntil: null,
      });
      await enqueue(job.analysisId, job.userId);
      await removeQuiet(path.join(paths.queueLeased, name));
      recovered += 1;
    }
    return { recovered };
  };

  const completeJob = async (analysisId, { result, providerOutcome, leaseToken = null, userId = null } = {}) => {
    const job = await getJob(analysisId, userId);
    if (!job) return null;
    if (job.status === JOB_STATUSES.completed) return job;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken) return null;
    const next = await saveJob({
      ...job,
      status: JOB_STATUSES.completed,
      result,
      error: null,
      providerOutcome: providerOutcome ?? 'success',
      leaseOwner: null,
      leaseToken: null,
      leaseUntil: null,
    });
    await removeQuiet(leaseFile(job));
    notifyJobUpdated(analysisId);
    return next;
  };

  const failJob = async (analysisId, { error, providerOutcome, requeue, softRequeue = false, leaseToken = null, userId = null } = {}) => {
    const job = await getJob(analysisId, userId);
    if (!job) return null;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken && !requeue) return null;
    if (requeue) {
      const attempts = softRequeue
        ? Math.max(0, (job.attempts ?? 1) - 1)
        : (job.attempts ?? 0);
      await saveJob({
        ...job,
        status: JOB_STATUSES.queued,
        attempts,
        error,
        providerOutcome: providerOutcome ?? 'retryable',
        leaseOwner: null,
        leaseToken: null,
        leaseUntil: null,
      });
      await enqueue(analysisId, job.userId);
      await removeQuiet(leaseFile(job));
      notifyJobUpdated(analysisId);
      return getJob(analysisId, job.userId);
    }
    const next = await saveJob({
      ...job,
      status: JOB_STATUSES.failed,
      error,
      providerOutcome: providerOutcome ?? 'failed',
      leaseOwner: null,
      leaseToken: null,
      leaseUntil: null,
    });
    await removeQuiet(leaseFile(job));
    notifyJobUpdated(analysisId);
    return next;
  };

  const markProviderStarted = async (analysisId, leaseToken = null, userId = null) => {
    const job = await getJob(analysisId, userId);
    if (!job || job.status !== JOB_STATUSES.processing) return null;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken) return null;
    if (job.providerStarted) return job;
    return saveJob({
      ...job,
      providerStarted: true,
      providerStartedAt: new Date().toISOString(),
    });
  };

  const renewLease = async (analysisId, workerId, leaseMs, leaseToken = null, userId = null) => {
    const job = await getJob(analysisId, userId);
    if (!job || job.leaseOwner !== workerId) return false;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken) return false;
    const leaseUntil = Date.now() + leaseMs;
    await saveJob({ ...job, leaseUntil });
    await writeJsonAtomic(leaseFile(job), {
      analysisId,
      userId: job.userId,
      workerId,
      leaseToken: job.leaseToken,
      leaseUntil,
      renewedAt: Date.now(),
    });
    return true;
  };

  const queueDepth = async () => (await listReadyNames()).length;

  const cleanupExpiredJobs = async (now = Date.now()) => {
    let removed = 0;
    const names = await readdir(paths.jobs).catch((e) => (e.code === 'ENOENT' ? [] : Promise.reject(e)));
    for (const name of names) {
      if (!name.endsWith('.json')) continue;
      const job = await readJson(path.join(paths.jobs, name), null);
      if (!job || (job.expiresAt ?? 0) > now) continue;
      if (job.status === JOB_STATUSES.queued || job.status === JOB_STATUSES.processing) continue;
      await removeQuiet(path.join(paths.jobs, name));
      await removeQuiet(path.join(paths.results, name));
      removed += 1;
    }
    return { removed };
  };

  return {
    kind: 'file',
    paths,
    getJob,
    saveJob,
    reserveIdempotency,
    createQueuedJob,
    enqueue,
    claimNext,
    recoverExpiredLeases,
    markProviderStarted,
    completeJob,
    failJob,
    renewLease,
    queueDepth,
    cleanupExpiredJobs,
    jobTtlMs,
  };
}
