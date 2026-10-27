import { createHash, randomUUID } from 'node:crypto';
import path from 'node:path';
import { ServiceError } from './recognition.mjs';
import { createExclusive, readJson, writeJsonAtomic } from './async/atomic-fs.mjs';
import { createQuotaStore } from './async/quota.mjs';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Durable photo-call identity shared by the synchronous route and the async job path.
 * The provider marker is an exclusive file synced before the caller may open a socket.
 */
export function analysisIdFor(userId, idempotencyKey) {
  if (UUID_RE.test(idempotencyKey ?? '')) return idempotencyKey.toLowerCase();
  const hex = createHash('sha256').update(`${userId}\0${idempotencyKey}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(12, 15)}-a${hex.slice(15, 18)}-${hex.slice(18, 30)}`;
}

function callsDir(dataDir) {
  return path.join(dataDir, 'photo-calls');
}

function recordPath(dataDir, analysisId) {
  return path.join(callsDir(dataDir), `${analysisId}.json`);
}

function markerPath(dataDir, analysisId) {
  return path.join(callsDir(dataDir), `${analysisId}.provider-started`);
}

export async function readPhotoAttempt(dataDir, analysisId) {
  const record = await readJson(recordPath(dataDir, analysisId), null);
  const marker = await readJson(markerPath(dataDir, analysisId), null);
  if (!record && !marker) return null;
  return {
    ...(record ?? { analysisId }),
    providerStarted: Boolean(record?.providerStarted || marker),
  };
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

export async function claimProviderCall(dataDir, analysisId) {
  if (!dataDir) {
    const error = new ServiceError('photo_ledger_unconfigured', 503);
    throw error;
  }
  return createExclusive(
    markerPath(dataDir, analysisId),
    `${JSON.stringify({ analysisId, at: new Date().toISOString() })}\n`,
  );
}

export async function savePhotoAttemptResult(dataDir, analysisId, result) {
  const current = await readPhotoAttempt(dataDir, analysisId);
  await writeJsonAtomic(recordPath(dataDir, analysisId), {
    ...(current ?? { analysisId }),
    analysisId,
    providerStarted: true,
    status: 'completed',
    result,
  });
}

export function createPhotoCallLedger({ dataDir, userDailyLimit, globalDailyLimit }) {
  const quota = createQuotaStore({ dataDir, userDailyLimit, globalDailyLimit });

  const read = async (userId, idempotencyKey, fingerprint) => {
    if (!idempotencyKey) return null;
    const analysisId = analysisIdFor(userId, idempotencyKey);
    const record = await readPhotoAttempt(dataDir, analysisId);
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
    const existing = await readPhotoAttempt(dataDir, analysisId);
    if (existing) {
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
    const created = await createExclusive(recordPath(dataDir, analysisId), `${JSON.stringify(record)}\n`);
    if (!created) {
      const again = await readPhotoAttempt(dataDir, analysisId);
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

  const markProviderStarted = async (analysisId) => {
    const created = await claimProviderCall(dataDir, analysisId);
    if (!created) return { startedByUs: false, record: await readPhotoAttempt(dataDir, analysisId) };
    const current = await readPhotoAttempt(dataDir, analysisId);
    const next = {
      ...(current ?? { analysisId }),
      analysisId,
      providerStarted: true,
      providerStartedAt: new Date().toISOString(),
      status: 'provider_started',
    };
    await writeJsonAtomic(recordPath(dataDir, analysisId), next);
    return { startedByUs: true, record: next };
  };

  const complete = async (analysisId, result) => {
    const current = await readPhotoAttempt(dataDir, analysisId);
    if (!current?.providerStarted) throw new ServiceError('provider_not_started', 503);
    await savePhotoAttemptResult(dataDir, analysisId, result);
  };

  const fail = async (analysisId) => {
    const current = await readPhotoAttempt(dataDir, analysisId);
    if (!current?.providerStarted) return;
    await writeJsonAtomic(recordPath(dataDir, analysisId), {
      ...current,
      status: 'failed',
      providerStarted: true,
    });
  };

  const snapshot = (userId) => quota.snapshot(userId);

  return { read, prepare, markProviderStarted, complete, fail, snapshot, quota };
}
