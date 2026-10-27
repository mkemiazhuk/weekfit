import { createHash, randomUUID } from 'node:crypto';
import { ownerKey } from './quota.mjs';
import { createRedisClient } from './redis-client.mjs';
import { JOB_STATUSES } from './job-store.mjs';
import { notifyJobUpdated } from './job-wait.mjs';

const CLAIM_SCRIPT = `
-- WEEKFIT_CLAIM
local id = redis.call('RPOP', KEYS[1])
if not id then return false end
redis.call('SET', KEYS[2] .. id, ARGV[3], 'PX', tonumber(ARGV[4]))
redis.call('ZADD', KEYS[3], tonumber(ARGV[2]), id)
return id
`;

const QUOTA_SCRIPT = `
-- WEEKFIT_QUOTA
if redis.call('EXISTS', KEYS[1]) == 1 then return 'EXISTING' end
local user = tonumber(redis.call('GET', KEYS[2]) or '0')
local global = tonumber(redis.call('GET', KEYS[3]) or '0')
local userLimit = tonumber(ARGV[1])
local globalLimit = tonumber(ARGV[2])
if user >= userLimit or global >= globalLimit then return 'LIMIT' end
redis.call('SET', KEYS[1], '1', 'EX', tonumber(ARGV[3]))
redis.call('INCR', KEYS[2])
redis.call('EXPIRE', KEYS[2], tonumber(ARGV[3]))
redis.call('INCR', KEYS[3])
redis.call('EXPIRE', KEYS[3], tonumber(ARGV[3]))
return 'OK'
`;

const SLOT_SCRIPT = `
-- WEEKFIT_SLOT
local zkey = KEYS[1]
local now = tonumber(ARGV[5])
local expired = redis.call('ZRANGEBYSCORE', zkey, '-inf', now)
for i, member in ipairs(expired) do
  redis.call('ZREM', zkey, member)
  redis.call('DEL', 'ai-slot:' .. member)
end
local n = redis.call('ZCARD', zkey)
if n >= tonumber(ARGV[4]) then return false end
redis.call('ZADD', zkey, tonumber(ARGV[3]), ARGV[1])
redis.call('SET', 'ai-slot:' .. ARGV[1], ARGV[2], 'PX', math.max(1000, tonumber(ARGV[3]) - now))
return ARGV[1]
`;

function userHash(userId) {
  return createHash('sha256').update(userId).digest('hex').slice(0, 24);
}
function keyHash(key) {
  return createHash('sha256').update(key).digest('hex').slice(0, 32);
}

/**
 * Redis-backed durable job + idempotency + queue + leases.
 * Same interface as createFileJobStore.
 */
export async function createRedisJobStore({ redis, redisUrl, jobTtlMs = 24 * 60 * 60_000, prefix = 'wf:' }) {
  const r = redis ?? createRedisClient(redisUrl);
  await r.ping();

  const k = {
    job: (id, userId = null) => (userId
      ? `${prefix}job:${ownerKey(userId)}:${id}`
      : `${prefix}job:${id}`),
    legacyJob: (id) => `${prefix}job:${id}`,
    idem: (userId, idemKey) => `${prefix}idem:${userHash(userId)}:${keyHash(idemKey)}`,
    queue: `${prefix}queue:ready`,
    lease: (id) => `${prefix}lease:`,
    leaseZ: `${prefix}lease:z`,
  };

  const getJob = async (analysisId, userId = null) => {
    if (userId) {
      const scoped = await r.get(k.job(analysisId, userId));
      if (scoped) return JSON.parse(scoped);
      const legacy = await r.get(k.legacyJob(analysisId));
      if (!legacy) return null;
      const job = JSON.parse(legacy);
      if (job.userId !== userId) return null;
      const migrated = { ...job, ownerUserId: userId };
      const ttlSec = Math.max(60, Math.ceil(((migrated.expiresAt ?? (Date.now() + jobTtlMs)) - Date.now()) / 1000));
      await r.set(k.job(analysisId, userId), JSON.stringify(migrated), { ex: ttlSec });
      return migrated;
    }
    const raw = await r.get(k.legacyJob(analysisId));
    return raw ? JSON.parse(raw) : null;
  };

  const saveJob = async (job) => {
    const owner = job.ownerUserId || job.userId;
    const next = { ...job, ownerUserId: owner, updatedAt: Date.now() };
    const ttlSec = Math.max(60, Math.ceil(((next.expiresAt ?? (Date.now() + jobTtlMs)) - Date.now()) / 1000));
    await r.set(k.job(job.analysisId, owner), JSON.stringify(next), { ex: ttlSec });
    return next;
  };

  const leaseTokenFor = (analysisId, userId) => (userId ? `${ownerKey(userId)}:${analysisId}` : analysisId);

  const reserveIdempotency = async ({ userId, idempotencyKey, fingerprint, analysisId }) => {
    const key = k.idem(userId, idempotencyKey);
    const payload = JSON.stringify({
      analysisId,
      fingerprint,
      userId,
      createdAt: Date.now(),
      expiresAt: Date.now() + jobTtlMs,
    });
    const created = await r.set(key, payload, { nx: true, ex: Math.ceil(jobTtlMs / 1000) });
    if (created === 'OK') return { analysisId, created: true, fingerprint };
    const existing = JSON.parse(await r.get(key));
    if (existing.fingerprint !== fingerprint) {
      const err = new Error('idempotency_key_reuse');
      err.code = 'idempotency_key_reuse';
      err.existingAnalysisId = existing.analysisId;
      throw err;
    }
    return { analysisId: existing.analysisId, created: false, fingerprint: existing.fingerprint };
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
    const stored = { ...record, ownerUserId: record.userId };
    const ok = await r.set(k.job(record.analysisId, record.userId), JSON.stringify(stored), {
      nx: true,
      ex: Math.ceil(jobTtlMs / 1000),
    });
    if (ok !== 'OK') {
      const existing = await getJob(record.analysisId, record.userId);
      if (existing && existing.userId !== record.userId) {
        const error = new Error('analysis_owner_mismatch');
        error.code = 'analysis_owner_mismatch';
        throw error;
      }
      return { job: existing, created: false };
    }
    return { job: stored, created: true };
  };

  const enqueue = async (analysisId, userId = null) => {
    const payload = userId ? JSON.stringify({ analysisId, userId }) : analysisId;
    await r.lpush(k.queue, payload);
    return analysisId;
  };

  const parseQueued = (raw) => {
    if (!raw) return null;
    if (raw.startsWith('{')) {
      try {
        const parsed = JSON.parse(raw);
        if (parsed?.analysisId) return parsed;
      } catch {
        // Legacy queue values are the analysis id.
      }
    }
    return { analysisId: raw, userId: null };
  };

  const attachClaim = async (queued, workerId, leaseMs) => {
    const parsed = typeof queued === 'string' ? parseQueued(queued) : queued;
    if (!parsed?.analysisId) return null;
    const { analysisId: id, userId } = parsed;
    const job = await getJob(id, userId);
    if (!job || job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) {
      await r.del(`${k.lease('')}${id}`);
      await r.zrem(k.leaseZ, id);
      return null;
    }
    const leaseToken = randomUUID();
    const leaseUntil = Date.now() + leaseMs;
    const leaseJson = JSON.stringify({
      analysisId: id, userId: job.userId, workerId, leaseUntil, leaseToken, claimedAt: Date.now(),
    });
    const token = leaseTokenFor(id, job.userId);
    await r.set(`${k.lease('')}${token}`, leaseJson, { px: leaseMs });
    await r.zadd(k.leaseZ, leaseUntil, token);
    const next = await saveJob({
      ...job,
      status: JOB_STATUSES.processing,
      leaseOwner: workerId,
      leaseToken,
      leaseUntil,
      processingStartedAt: job.processingStartedAt ?? Date.now(),
      attempts: (job.attempts ?? 0) + 1,
    });
    notifyJobUpdated(id);
    return next;
  };

  const claimNext = async ({ workerId, leaseMs, waitMs = 0 }) => {
    // Pop then attach lease+fencing token. BRPOP wakes immediately on enqueue (no sleep poll).
    let id = await r.rpop(k.queue);
    if (!id && waitMs > 0) {
      const popped = await r.brpop(k.queue, Math.max(1, Math.ceil(waitMs / 1000)));
      id = Array.isArray(popped) ? popped[1] : null;
    }
    return attachClaim(id, workerId, leaseMs);
  };

  const recoverExpiredLeases = async (nowMs = Date.now()) => {
    const expired = await r.zrangebyscore(k.leaseZ, '-inf', nowMs);
    let recovered = 0;
    for (const token of expired || []) {
      const raw = await r.get(`${k.lease('')}${token}`);
      const lease = raw ? JSON.parse(raw) : null;
      const analysisId = lease?.analysisId ?? token;
      const userId = lease?.userId ?? null;
      const job = await getJob(analysisId, userId);
      await r.del(`${k.lease('')}${token}`);
      await r.zrem(k.leaseZ, token);
      if (!job) continue;
      if (job.status === JOB_STATUSES.completed || job.status === JOB_STATUSES.failed) continue;
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
    const token = leaseTokenFor(analysisId, job.userId);
    await r.del(`${k.lease('')}${token}`);
    await r.zrem(k.leaseZ, token);
    notifyJobUpdated(analysisId);
    return next;
  };

  const failJob = async (analysisId, {
    error, providerOutcome, requeue, softRequeue = false, leaseToken = null, userId = null,
  } = {}) => {
    const job = await getJob(analysisId, userId);
    if (!job) return null;
    if (leaseToken && job.leaseToken && job.leaseToken !== leaseToken && !requeue) return null;
    const token = leaseTokenFor(analysisId, job.userId);
    await r.del(`${k.lease('')}${token}`);
    await r.zrem(k.leaseZ, token);
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
    const token = leaseTokenFor(analysisId, job.userId);
    await r.set(
      `${k.lease('')}${token}`,
      JSON.stringify({
        analysisId, userId: job.userId, workerId, leaseUntil, leaseToken: job.leaseToken, renewedAt: Date.now(),
      }),
      { px: leaseMs },
    );
    await r.zadd(k.leaseZ, leaseUntil, token);
    return true;
  };

  const queueDepth = async () => Number(await r.llen(k.queue)) || 0;

  const cleanupExpiredJobs = async () => ({ removed: 0 }); // TTL on keys handles expiry

  return {
    kind: 'redis',
    redis: r,
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

export function createRedisQuotaStore({ redis, redisUrl, userDailyLimit, globalDailyLimit, prefix = 'wf:' }) {
  const r = redis ?? createRedisClient(redisUrl);
  const dayKey = () => new Date().toISOString().slice(0, 10);

  const reserve = async ({ userId, analysisId }) => {
    const day = dayKey();
    const resKey = `${prefix}quota:res:${analysisId}`;
    const userKey = `${prefix}quota:user:${day}:${userHash(userId)}`;
    const globalKey = `${prefix}quota:global:${day}`;
    const result = await r.eval(
      QUOTA_SCRIPT,
      [resKey, userKey, globalKey],
      [String(userDailyLimit), String(globalDailyLimit), '172800'],
    );
    if (result === 'EXISTING') return { charged: false, reason: 'already_reserved' };
    if (result === 'LIMIT') {
      const err = new Error('daily_scan_limit');
      err.code = 'daily_scan_limit';
      throw err;
    }
    const userCount = Number(await r.get(userKey) || 0);
    const globalCount = Number(await r.get(globalKey) || 0);
    return { charged: true, userCount, globalCount, day };
  };

  const snapshot = async (userId) => {
    const day = dayKey();
    return {
      day,
      userCount: Number(await r.get(`${prefix}quota:user:${day}:${userHash(userId)}`) || 0),
      globalCount: Number(await r.get(`${prefix}quota:global:${day}`) || 0),
      userDailyLimit,
      globalDailyLimit,
    };
  };

  return { reserve, snapshot, kind: 'redis' };
}

export function createRedisAiSlots({ redis, redisUrl, maxConcurrent, leaseMs = 120_000, prefix = 'wf:' }) {
  const r = redis ?? createRedisClient(redisUrl);
  const zkey = `${prefix}ai-slots:z`;

  const tryAcquire = async (ownerId) => {
    const id = randomUUID();
    const expiresAt = Date.now() + leaseMs;
    const payload = JSON.stringify({ id, ownerId, expiresAt });
    const got = await r.eval(
      SLOT_SCRIPT,
      [zkey],
      [id, payload, String(expiresAt), String(maxConcurrent), String(Date.now())],
    );
    if (!got) return null;
    return {
      id,
      release: async () => {
        await r.zrem(zkey, id);
        await r.del(`ai-slot:${id}`);
      },
      renew: async () => {
        const next = Date.now() + leaseMs;
        await r.zadd(zkey, next, id);
        await r.set(`ai-slot:${id}`, JSON.stringify({ id, ownerId, expiresAt: next }), { px: leaseMs });
      },
    };
  };

  const activeCount = async () => {
    const expired = await r.zrangebyscore(zkey, '-inf', Date.now());
    for (const m of expired || []) {
      await r.zrem(zkey, m);
      await r.del(`ai-slot:${m}`);
    }
    return Number(await r.zcard(zkey)) || 0;
  };

  return {
    kind: 'redis',
    tryAcquire,
    activeCount,
    sweep: activeCount,
    maxConcurrent,
  };
}

export function createRedisCircuitBreaker({
  redis,
  redisUrl,
  failureThreshold = 8,
  openMs = 30_000,
  halfOpenMax = 1,
  prefix = 'wf:',
}) {
  const r = redis ?? createRedisClient(redisUrl);
  const key = `${prefix}circuit`;

  const load = async () => {
    const raw = await r.get(key);
    return raw ? JSON.parse(raw) : { state: 'closed', failures: 0, openedAt: 0, halfOpenProbes: 0 };
  };
  const save = async (s) => r.set(key, JSON.stringify(s), { ex: 86400 });

  const beforeCall = async () => {
    const nowMs = Date.now();
    let s = await load();
    if (s.state === 'open') {
      if (nowMs - s.openedAt < openMs) {
        const err = new Error('circuit_open');
        err.code = 'circuit_open';
        err.retryAfterSeconds = Math.ceil((openMs - (nowMs - s.openedAt)) / 1000);
        throw err;
      }
      s = { ...s, state: 'half_open', halfOpenProbes: 0 };
      await save(s);
    }
    if (s.state === 'half_open' && s.halfOpenProbes >= halfOpenMax) {
      const err = new Error('circuit_open');
      err.code = 'circuit_open';
      throw err;
    }
    if (s.state === 'half_open') await save({ ...s, halfOpenProbes: s.halfOpenProbes + 1 });
    return s.state;
  };

  const recordSuccess = async () => save({ state: 'closed', failures: 0, openedAt: 0, halfOpenProbes: 0 });
  const recordFailure = async () => {
    const s = await load();
    const failures = (s.failures ?? 0) + 1;
    if (s.state === 'half_open' || failures >= failureThreshold) {
      await save({ state: 'open', failures, openedAt: Date.now(), halfOpenProbes: 0 });
      return 'open';
    }
    await save({ ...s, failures });
    return 'closed';
  };

  return { beforeCall, recordSuccess, recordFailure, snapshot: load, kind: 'redis' };
}

export function createRedisProviderBudget({
  redis,
  redisUrl,
  maxCallsPerDay = 5000,
  maxEstimatedUsdPerDay = 500,
  usdPerCallEstimate = 0.08,
  prefix = 'wf:',
}) {
  const r = redis ?? createRedisClient(redisUrl);
  const dayKey = () => new Date().toISOString().slice(0, 10);
  const fileFor = (day) => `${prefix}spend:${day}`;

  const load = async () => {
    const day = dayKey();
    const raw = await r.get(fileFor(day));
    return raw ? JSON.parse(raw) : { day, calls: 0, estimatedUsd: 0, uncertainOutcomes: 0 };
  };

  const assertWithinBudget = async () => {
    const s = await load();
    if (s.calls >= maxCallsPerDay || s.estimatedUsd >= maxEstimatedUsdPerDay) {
      const err = new Error('provider_budget_exhausted');
      err.code = 'provider_budget_exhausted';
      throw err;
    }
    return s;
  };

  const recordAttempt = async ({ uncertain = false } = {}) => {
    const s = await load();
    const next = {
      ...s,
      calls: s.calls + 1,
      estimatedUsd: Number((s.estimatedUsd + usdPerCallEstimate).toFixed(4)),
      uncertainOutcomes: s.uncertainOutcomes + (uncertain ? 1 : 0),
    };
    await r.set(fileFor(s.day), JSON.stringify(next), { ex: 172800 });
    return next;
  };

  return { assertWithinBudget, recordAttempt, snapshot: load, kind: 'redis' };
}
