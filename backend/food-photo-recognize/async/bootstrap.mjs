import path from 'node:path';
import { createFileJobStore } from './job-store.mjs';
import { createLocalObjectStore } from './object-store.mjs';
import { createQuotaStore } from './quota.mjs';
import { createCircuitBreaker } from './circuit-breaker.mjs';
import { createProviderBudget } from './provider-budget.mjs';
import { createGlobalAiSlots } from './global-slots.mjs';
import { createConcurrencyGate } from '../concurrency.mjs';
import { createSubmitHandler, createStatusHandler } from './submit.mjs';
import { createRedisClient } from './redis-client.mjs';
import {
  createRedisJobStore,
  createRedisQuotaStore,
  createRedisAiSlots,
  createRedisCircuitBreaker,
  createRedisProviderBudget,
} from './redis-backend.mjs';
import { createHttpObjectStore, createS3ObjectStore } from './http-object-store.mjs';
import { createProviderLimits } from './provider-limits.mjs';

export function asyncConfiguration(env = process.env) {
  const integer = (key, fallback, min, max) => {
    const n = Number(env[key] ?? fallback);
    if (!Number.isInteger(n) || n < min || n > max) throw Error(`Invalid ${key}`);
    return n;
  };

  const isProduction = env.NODE_ENV === 'production';
  // Single Render instance + persistent disk only. Multi-instance still needs Redis + S3/http.
  const allowSingleNode = env.ALLOW_SINGLE_NODE_ASYNC === '1';
  const redisUrl = env.REDIS_URL || '';
  const stateBackend = (env.STATE_BACKEND || (redisUrl ? 'redis' : (env.DATA_DIR || env.WEEKFIT_DATA_DIR ? 'file' : ''))).toLowerCase();
  const objectStoreKind = (env.OBJECT_STORE || (
    allowSingleNode ? 'local' : (isProduction ? 's3' : 'local')
  )).toLowerCase();
  const dataDir = env.DATA_DIR || env.WEEKFIT_DATA_DIR || '';
  const asyncEnabled = env.ASYNC_ANALYSIS === '1' || Boolean(dataDir) || stateBackend === 'redis';

  if (isProduction && asyncEnabled && !allowSingleNode) {
    if (stateBackend === 'file' || (!redisUrl && stateBackend !== 'redis')) {
      throw new Error('Production async analysis requires STATE_BACKEND=redis and REDIS_URL (shared DATA_DIR is forbidden)');
    }
    if (objectStoreKind === 'local') {
      throw new Error('Production async analysis requires OBJECT_STORE=s3 or OBJECT_STORE=http (not local DATA_DIR photos)');
    }
  }
  if (isProduction && asyncEnabled && allowSingleNode) {
    if (stateBackend === 'redis' && !redisUrl) {
      throw new Error('REDIS_URL required when STATE_BACKEND=redis');
    }
    if (stateBackend === 'file' && !dataDir) {
      throw new Error('ALLOW_SINGLE_NODE_ASYNC=1 with file backend requires DATA_DIR on a persistent disk');
    }
  }

  return {
    asyncEnabled,
    isProduction,
    stateBackend: stateBackend || 'file',
    redisUrl,
    dataDir: dataDir || path.join(process.cwd(), '.data'),
    maxAsyncQueue: integer('MAX_ASYNC_QUEUE', 2000, 1, 100_000),
    pollHintMs: integer('POLL_HINT_MS', 250, 100, 30_000),
    longPollMaxMs: integer('LONG_POLL_MAX_MS', 25_000, 0, 55_000),
    inlineFastPath: env.INLINE_FAST_PATH !== '0',
    workerIdleMs: integer('WORKER_IDLE_MS', 0, 0, 5_000),
    workerClaimWaitMs: integer('WORKER_CLAIM_WAIT_MS', 5000, 100, 60_000),
    workerLeaseMs: integer('WORKER_LEASE_MS', 120_000, 5000, 600_000),
    workerMaxAttempts: integer('WORKER_MAX_ATTEMPTS', 3, 1, 10),
    workerRetryBaseMs: integer('WORKER_RETRY_BASE_MS', 500, 50, 60_000),
    workerRetryMaxMs: integer('WORKER_RETRY_MAX_MS', 20_000, 100, 120_000),
    // Parallel AI calls per worker process (memory-bound). Fleet capacity ≈ workers × this, capped by GLOBAL_AI_SLOTS.
    workerLocalConcurrency: integer('WORKER_LOCAL_CONCURRENCY', 8, 1, 128),
    // Atomic fleet-wide AI concurrency. Raise for burst tests (e.g. 100); production only after provider+host confirmation.
    globalAiSlots: integer('GLOBAL_AI_SLOTS', 16, 1, 2000),
    // Pre-provisioned burst target for capacity planning docs (does not auto-set slots).
    targetBurstSlots: integer('TARGET_BURST_SLOTS', 100, 1, 2000),
    maxQueueWaitMs: integer('MAX_QUEUE_WAIT_MS', 120_000, 0, 600_000),
    // 0 = disabled until account RPM/TPM are known from OpenAI dashboard / staging.
    providerMaxRpm: integer('PROVIDER_MAX_RPM', 0, 0, 100_000),
    providerMaxTpm: integer('PROVIDER_MAX_TPM', 0, 0, 50_000_000),
    providerTokensPerCallEstimate: integer('PROVIDER_TOKENS_PER_CALL', 4000, 100, 200_000),
    deletePhotoOnComplete: env.DELETE_PHOTO_ON_COMPLETE !== '0',
    photoTtlMs: integer('PHOTO_TTL_MS', 24 * 60 * 60_000, 60_000, 7 * 24 * 60 * 60_000),
    jobTtlMs: integer('JOB_TTL_MS', 24 * 60 * 60_000, 60_000, 7 * 24 * 60 * 60_000),
    maxEstimatedUsdPerDay: Number(env.MAX_ESTIMATED_USD_PER_DAY ?? 500),
    maxProviderCallsPerDay: integer('MAX_PROVIDER_CALLS_PER_DAY', 5000, 1, 1_000_000),
    objectStoreKind,
    objectStoreBaseUrl: env.OBJECT_STORE_BASE_URL || '',
    objectStoreToken: env.OBJECT_STORE_TOKEN || 'weekfit-object-dev',
  };
}

export async function createAsyncStack(config, dependencies = {}) {
  const asyncConfig = {
    ...asyncConfiguration(),
    ...config,
    ...dependencies.asyncConfig,
  };
  const merged = { ...config, ...asyncConfig };

  let redis = dependencies.redis ?? null;
  if (!redis && asyncConfig.stateBackend === 'redis') {
    if (!asyncConfig.redisUrl) throw new Error('REDIS_URL required for STATE_BACKEND=redis');
    redis = createRedisClient(asyncConfig.redisUrl);
    await redis.ping();
  }

  let jobStore = dependencies.jobStore;
  let quota = dependencies.quota;
  let circuit = dependencies.circuit;
  let budget = dependencies.budget;
  let aiSlots = dependencies.aiSlots;
  let objectStore = dependencies.objectStore;

  if (asyncConfig.stateBackend === 'redis') {
    jobStore = jobStore ?? await createRedisJobStore({
      redis,
      jobTtlMs: asyncConfig.jobTtlMs,
    });
    quota = quota ?? createRedisQuotaStore({
      redis,
      userDailyLimit: config.dailyLimit,
      globalDailyLimit: config.globalDailyLimit,
    });
    circuit = circuit ?? createRedisCircuitBreaker({ redis });
    budget = budget ?? createRedisProviderBudget({
      redis,
      maxCallsPerDay: asyncConfig.maxProviderCallsPerDay,
      maxEstimatedUsdPerDay: asyncConfig.maxEstimatedUsdPerDay,
    });
    aiSlots = aiSlots ?? createRedisAiSlots({
      redis,
      maxConcurrent: asyncConfig.globalAiSlots,
      leaseMs: asyncConfig.workerLeaseMs,
    });
  } else {
    // Dev/single-node only — forbidden in production by asyncConfiguration().
    const dataDir = asyncConfig.dataDir;
    jobStore = jobStore ?? await createFileJobStore({ dataDir, jobTtlMs: asyncConfig.jobTtlMs });
    quota = quota ?? createQuotaStore({
      dataDir,
      userDailyLimit: config.dailyLimit,
      globalDailyLimit: config.globalDailyLimit,
    });
    circuit = circuit ?? createCircuitBreaker({ dataDir });
    budget = budget ?? createProviderBudget({
      dataDir,
      maxCallsPerDay: asyncConfig.maxProviderCallsPerDay,
      maxEstimatedUsdPerDay: asyncConfig.maxEstimatedUsdPerDay,
    });
    aiSlots = aiSlots ?? createGlobalAiSlots({
      dataDir,
      maxConcurrent: asyncConfig.globalAiSlots,
      leaseMs: asyncConfig.workerLeaseMs,
    });
  }

  if (!objectStore) {
    if (asyncConfig.objectStoreKind === 'http') {
      if (!asyncConfig.objectStoreBaseUrl) throw new Error('OBJECT_STORE_BASE_URL required');
      objectStore = createHttpObjectStore({
        baseUrl: asyncConfig.objectStoreBaseUrl,
        token: asyncConfig.objectStoreToken,
        ttlMs: asyncConfig.photoTtlMs,
      });
    } else if (asyncConfig.objectStoreKind === 's3') {
      objectStore = createS3ObjectStore(process.env);
    } else {
      objectStore = createLocalObjectStore({
        root: asyncConfig.dataDir,
        ttlMs: asyncConfig.photoTtlMs,
      });
    }
  }

  const uploadGate = dependencies.uploadGate ?? createConcurrencyGate({
    maxConcurrent: config.maxConcurrentUploads,
    maxQueue: config.maxUploadQueue,
    queueWaitMs: config.uploadQueueWaitMs,
    retryAfterSeconds: config.retryAfterSeconds,
    timeoutDetail: 'upload_queue_timeout',
    fullDetail: 'upload_queue_full',
  });

  // Wire mock fetcher for API inline fast-path (must never hit real OpenAI in mock mode).
  let openaiFetcher = dependencies.openaiFetcher ?? null;
  if (!openaiFetcher && merged.openAIMock) {
    const { createMockOpenAIAdapter } = await import('../openai-mock.mjs');
    openaiFetcher = createMockOpenAIAdapter({
      delayMs: merged.mockDelayMs,
      scenario: merged.mockScenario,
    }).fetcher;
  }

  const providerLimits = dependencies.providerLimits ?? createProviderLimits({
    maxRpm: asyncConfig.providerMaxRpm,
    maxTpm: asyncConfig.providerMaxTpm,
    tokensPerCallEstimate: asyncConfig.providerTokensPerCallEstimate,
  });

  const submit = createSubmitHandler({
    config: merged,
    jobStore,
    objectStore,
    quota,
    uploadGate,
    aiSlots,
    circuit,
    budget,
    providerLimits,
    openaiFetcher,
  });
  const status = createStatusHandler({
    jobStore,
    longPollMaxMs: asyncConfig.longPollMaxMs,
    pollHintMs: asyncConfig.pollHintMs,
  });

  return {
    asyncConfig: merged,
    redis,
    jobStore,
    objectStore,
    quota,
    circuit,
    budget,
    aiSlots,
    providerLimits,
    uploadGate,
    openaiFetcher,
    submit,
    status,
  };
}
