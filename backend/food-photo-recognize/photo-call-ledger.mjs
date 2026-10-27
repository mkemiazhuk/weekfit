import { createHash, randomUUID } from 'node:crypto';
import path from 'node:path';
import { ServiceError } from './recognition.mjs';
import { createExclusive, readJson, writeJsonAtomic } from './async/atomic-fs.mjs';
import { createQuotaStore, ownerKey } from './async/quota.mjs';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export { ownerKey };

/**
 * Public analysis id. A client UUID stays that UUID.
 * Storage is never the UUID alone: sync and async both use ownerKey(userId) + analysisId.
 */
export function analysisIdFor(userId, idempotencyKey) {
  if (UUID_RE.test(idempotencyKey ?? '')) return idempotencyKey.toLowerCase();
  const hex = createHash('sha256').update(`${userId}\0${idempotencyKey}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(12, 15)}-a${hex.slice(15, 18)}-${hex.slice(18, 30)}`;
}

function callsDir(dataDir) {
  return path.join(dataDir, 'photo-calls');
}

function scopedDir(dataDir, userId) {
  return path.join(callsDir(dataDir), 'owners', ownerKey(userId));
}

function recordPath(dataDir, userId, analysisId) {
  return path.join(scopedDir(dataDir, userId), `${analysisId}.json`);
}

function markerPath(dataDir, userId, analysisId) {
  return path.join(scopedDir(dataDir, userId), `${analysisId}.provider-started`);
}

function legacyRecordPath(dataDir, analysisId) {
  return path.join(callsDir(dataDir), `${analysisId}.json`);
}

function legacyMarkerPath(dataDir, analysisId) {
  return path.join(callsDir(dataDir), `${analysisId}.provider-started`);
}

function requireUser(userId) {
  if (!userId) throw new ServiceError('photo_owner_required', 503, { detail: 'uid_required' });
}

function ownedRecord(record, userId, analysisId) {
  if (!record) return null;
  if (record.userId !== userId) return null;
  return {
    ...record,
    analysisId: record.analysisId ?? analysisId,
    userId,
  };
}

/**
 * Read one user's attempt. A legacy file is migrated only when its stored userId
 * (or the quota reservation) is this UID. Another UID gets null, not the result.
 */
export async function readPhotoAttempt(dataDir, analysisId, userId) {
  requireUser(userId);
  const scoped = ownedRecord(await readJson(recordPath(dataDir, userId, analysisId), null), userId, analysisId);
  const scopedMarker = await readJson(markerPath(dataDir, userId, analysisId), null);
  if (scoped || scopedMarker) {
    return {
      ...(scoped ?? { analysisId, userId }),
      providerStarted: Boolean(scoped?.providerStarted || scopedMarker),
    };
  }

  const legacy = await readJson(legacyRecordPath(dataDir, analysisId), null);
  const legacyMarker = await readJson(legacyMarkerPath(dataDir, analysisId), null);
  if (!legacy && !legacyMarker) return null;
  const reservation = await readJson(
    path.join(dataDir, 'quota', 'reservations', `${ownerKey(userId)}--${analysisId}.json`),
    null,
  ) ?? await readJson(path.join(dataDir, 'quota', 'reservations', `${analysisId}.json`), null);
  const owner = legacy?.userId ?? (reservation?.userId === userId ? userId : null);
  if (owner !== userId) return null;

  const migrated = {
    ...(legacy ?? { analysisId }),
    analysisId,
    userId,
    providerStarted: Boolean(legacy?.providerStarted || legacyMarker),
  };
  await writeJsonAtomic(recordPath(dataDir, userId, analysisId), migrated);
  if (legacyMarker || migrated.providerStarted) {
    await createExclusive(
      markerPath(dataDir, userId, analysisId),
      `${JSON.stringify({ analysisId, userId, at: new Date().toISOString(), migrated: true })}\n`,
    );
  }
  return migrated;
}

/**
 * The file ledger coordinates one DATA_DIR. STATE_BACKEND=redis with a separate
 * DATA_DIR per instance is not that store, so it must not authorize a provider call.
 * One shared disk is the single-node file declaration: ALLOW_SINGLE_NODE_ASYNC=1,
 * an explicit DATA_DIR, and OBJECT_STORE=local.
 */
export function fileLedgerGenerationRefusal(config) {
  if ((config?.stateBackend || 'file') !== 'redis') return null;
  const oneSharedDisk = config.allowSingleNode === true
    && config.dataDirExplicit === true
    && config.objectStoreKind === 'local';
  if (oneSharedDisk) return null;
  return {
    code: 'file_ledger_unsupported',
    status: 503,
    detail: 'redis_separate_data_dir',
  };
}

/**
 * An explicit DATA_DIR / photo ledger path is the persistent directory.
 * Directory fsync does not prove that path is a persistent mount.
 * Production without that path must not fall back to a temp directory or call a provider.
 */
export function assertPersistentDataDir(config) {
  if (!config?.isProduction) return;
  const explicit = Boolean(config.photoLedgerDir || (config.dataDirExplicit && config.dataDir));
  if (explicit) return;
  console.error(JSON.stringify({
    event: 'ai_call_blocked',
    reason: 'persistent_mount_unconfirmed',
    detail: 'DATA_DIR is not an explicit persistent directory. Directory fsync does not prove a persistent mount.',
  }));
  throw new ServiceError('persistent_data_dir_required', 503, {
    detail: 'persistent_mount_unconfirmed',
  });
}

export function assertFileLedgerCanGenerate(config) {
  const refusal = fileLedgerGenerationRefusal(config);
  if (!refusal) return;
  console.error(JSON.stringify({
    event: 'ai_call_blocked',
    reason: refusal.detail,
    stateBackend: config.stateBackend,
    dataDirExplicit: Boolean(config.dataDirExplicit),
    allowSingleNode: Boolean(config.allowSingleNode),
    objectStore: config.objectStoreKind ?? null,
  }));
  throw new ServiceError(refusal.code, refusal.status, { detail: refusal.detail });
}

export async function claimProviderCall(dataDir, analysisId, userId) {
  requireUser(userId);
  if (!dataDir) {
    const error = new ServiceError('photo_ledger_unconfigured', 503);
    throw error;
  }
  const existing = await readPhotoAttempt(dataDir, analysisId, userId);
  if (existing && existing.userId !== userId) {
    throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
  }
  return createExclusive(
    markerPath(dataDir, userId, analysisId),
    `${JSON.stringify({ analysisId, userId, at: new Date().toISOString() })}\n`,
  );
}

export async function savePhotoAttemptResult(dataDir, analysisId, result, userId) {
  requireUser(userId);
  const current = await readPhotoAttempt(dataDir, analysisId, userId);
  if (current && current.userId !== userId) {
    throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
  }
  await writeJsonAtomic(recordPath(dataDir, userId, analysisId), {
    ...(current ?? { analysisId, userId }),
    analysisId,
    userId,
    providerStarted: true,
    status: 'completed',
    result,
  });
}

export function createPhotoCallLedger({ dataDir, userDailyLimit, globalDailyLimit, failAfter = null }) {
  const quota = createQuotaStore({ dataDir, userDailyLimit, globalDailyLimit, failAfter });

  const read = async (userId, idempotencyKey, fingerprint) => {
    if (!idempotencyKey) return null;
    const analysisId = analysisIdFor(userId, idempotencyKey);
    const record = await readPhotoAttempt(dataDir, analysisId, userId);
    if (!record) return null;
    if (record.fingerprint && fingerprint && record.fingerprint !== fingerprint) {
      throw new ServiceError('idempotency_key_reuse', 409, { detail: 'same_key_different_payload' });
    }
    return record;
  };

  const prepare = async ({ userId, idempotencyKey, fingerprint }) => {
    const analysisId = idempotencyKey
      ? analysisIdFor(userId, idempotencyKey)
      : randomUUID();
    const existing = await readPhotoAttempt(dataDir, analysisId, userId);
    if (existing) {
      if (existing.userId !== userId) throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
      if (existing.fingerprint && fingerprint && existing.fingerprint !== fingerprint) {
        throw new ServiceError('idempotency_key_reuse', 409, { detail: 'same_key_different_payload' });
      }
      return { analysisId, record: existing, charged: false };
    }
    let reservation;
    try {
      reservation = await quota.reserve({ userId, analysisId });
    } catch (error) {
      if (error.code === 'daily_scan_limit') {
        throw new ServiceError('daily_scan_limit', 429, { retryAfterSeconds: 3600 });
      }
      if (error.code === 'quota_store_busy') throw new ServiceError('quota_store_busy', 503);
      throw error;
    }
    const record = {
      analysisId,
      userId,
      fingerprint: fingerprint ?? null,
      providerStarted: false,
      status: 'reserved',
      result: null,
    };
    const created = await createExclusive(recordPath(dataDir, userId, analysisId), `${JSON.stringify(record)}\n`);
    if (!created) {
      const again = await readPhotoAttempt(dataDir, analysisId, userId);
      if (again && again.userId !== userId) {
        throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
      }
      return { analysisId, record: again, charged: false };
    }
    return {
      analysisId,
      record,
      charged: reservation.charged !== false,
      globalCount: reservation.globalCount,
      userCount: reservation.userCount,
    };
  };

  const markProviderStarted = async (analysisId, userId) => {
    requireUser(userId);
    const created = await claimProviderCall(dataDir, analysisId, userId);
    if (!created) return { startedByUs: false, record: await readPhotoAttempt(dataDir, analysisId, userId) };
    const current = await readPhotoAttempt(dataDir, analysisId, userId);
    if (current && current.userId !== userId) {
      throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
    }
    const next = {
      ...(current ?? { analysisId, userId }),
      analysisId,
      userId,
      providerStarted: true,
      providerStartedAt: new Date().toISOString(),
      status: 'provider_started',
    };
    await writeJsonAtomic(recordPath(dataDir, userId, analysisId), next);
    return { startedByUs: true, record: next };
  };

  const complete = async (analysisId, result, userId) => {
    const current = await readPhotoAttempt(dataDir, analysisId, userId);
    if (current && current.userId !== userId) {
      throw new ServiceError('forbidden', 403, { detail: 'analysis_owner_mismatch' });
    }
    if (!current?.providerStarted) throw new ServiceError('provider_not_started', 503);
    await savePhotoAttemptResult(dataDir, analysisId, result, userId);
  };

  const fail = async (analysisId, userId) => {
    const current = await readPhotoAttempt(dataDir, analysisId, userId);
    if (!current?.providerStarted || current.userId !== userId) return;
    await writeJsonAtomic(recordPath(dataDir, userId, analysisId), {
      ...current,
      userId,
      status: 'failed',
      providerStarted: true,
    });
  };

  const snapshot = (userId) => quota.snapshot(userId);

  return { read, prepare, markProviderStarted, complete, fail, snapshot, quota };
}
