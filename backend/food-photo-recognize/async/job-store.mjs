import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { EventEmitter } from 'node:events';
import { readdir, rename } from 'node:fs/promises';
import { writeJsonAtomic, readJson, createExclusive, removeQuiet } from './atomic-fs.mjs';
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

  const jobPath = (analysisId) => path.join(paths.jobs, `${analysisId}.json`);
  const resultPath = (analysisId) => path.join(paths.results, `${analysisId}.json`);

  const getJob = async (analysisId) => readJson(jobPath(analysisId), null);

  const saveJob = async (job) => {
    const next = { ...job, updatedAt: Date.now() };
    await writeJsonAtomic(jobPath(job.analysisId), next);
    if (next.status === JOB_STATUSES.completed || next.status === JOB_STATUSES.failed) {
      await writeJsonAtomic(resultPath(job.analysisId), {
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
    const created = await createExclusive(jobPath(record.analysisId), `${JSON.stringify(record)}\n`);
    if (!created) {
      return { job: await getJob(record.analysisId), created: false };
    }
    return { job: record, created: true };
  };

  const listReadyNames = async () => {
    try {
      return (await readdir(paths.queueReady)).filter((n) => !n.endsWith('.claiming'));
    } catch (error) {
      if (error.code === 'ENOENT') return [];
      throw error;
    }
  };

  /** Ready marker name: `{timestampMs}.{analysisId}` */
  const enqueue = async (analysisId) => {
    const name = `${Date.now()}.${analysisId}`;
    const marker = path.join(paths.queueReady, name);
    const ok = await createExclusive(marker, analysisId);
    let out = name;
    if (!ok) {
      // Same ms collision — retry with jitter suffix.
      const alt = `${Date.now()}.${analysisId}.${Math.random().toString(16).slice(2, 8)}`;
      await createExclusive(path.join(paths.queueReady, alt), analysisId);
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
        const job = await getJob(claimedId);
        if (!job || job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) {
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
        await writeJsonAtomic(path.join(paths.queueLeased, `${claimedId}.json`), {
          analysisId: claimedId,
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
        const done = () => { clearTimeout(timer); wake.off('ready', done); resolve(); };
        const timer = setTimeout(done, Math.min(remaining, 5000));
        wake.once('ready', done);
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
      const job = await getJob(lease.analysisId);
      if (!job) {
        await removeQuiet(path.join(paths.queueLeased, name));
        continue;
      }
      if (job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) {
        await removeQuiet(path.join(paths.queueLeased, name));
        continue;
      }
      await saveJob({
        ...job,
        status: JOB_STATUSES.queued,
        leaseOwner: null,
        leaseUntil: null,
      });
      await enqueue(job.analysisId);
      await removeQuiet(path.join(paths.queueLeased, name));
      recovered += 1;
    }
    return { recovered };
  };

  const completeJob = async (analysisId, { result, providerOutcome, leaseToken = null }) => {
    const job = await getJob(analysisId);
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
    await removeQuiet(path.join(paths.queueLeased, `${analysisId}.json`));
    notifyJobUpdated(analysisId);
    return next;
  };

  const failJob = async (analysisId, { error, providerOutcome, requeue, softRequeue = false, leaseToken = null }) => {
    const job = await getJob(analysisId);
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
      await enqueue(analysisId);
      await removeQuiet(path.join(paths.queueLeased, `${analysisId}.json`));
      notifyJobUpdated(analysisId);
      return getJob(analysisId);
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
    await removeQuiet(path.join(paths.queueLeased, `${analysisId}.json`));
    notifyJobUpdated(analysisId);
    return next;
  };

  const renewLease = async (analysisId, workerId, leaseMs, leaseToken = null) => {
    const job = await getJob(analysisId);
    if (!job || job.leaseOwner !== workerId) return false;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken) return false;
    const leaseUntil = Date.now() + leaseMs;
    await saveJob({ ...job, leaseUntil });
    await writeJsonAtomic(path.join(paths.queueLeased, `${analysisId}.json`), {
      analysisId,
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
    completeJob,
    failJob,
    renewLease,
    queueDepth,
    cleanupExpiredJobs,
    jobTtlMs,
  };
}
