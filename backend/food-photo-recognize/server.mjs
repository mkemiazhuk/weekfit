import http from 'node:http';
import path from 'node:path';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { authenticate } from './auth.mjs';
import { recognize, validateInput, ServiceError, FOOD_PROMPT_VERSION } from './recognition.mjs';
import { createSummaryHandler, SUMMARY_PROMPT_VERSION } from './coach-summary.mjs';
import { requirePaidSubscriptionJWS } from './subscription-proof.mjs';
import { createConcurrencyGate } from './concurrency.mjs';
import {
  createIdempotencyStore,
  normalizeIdempotencyKey,
  fingerprintPayload,
} from './idempotency.mjs';
import { createMockOpenAIAdapter, forbidRealOpenAIFetch } from './openai-mock.mjs';
import { asyncConfiguration, createAsyncStack } from './async/bootstrap.mjs';
import {
  assertFileLedgerCanGenerate,
  assertPersistentDataDir,
  createPhotoCallLedger,
  fileLedgerGenerationRefusal,
} from './photo-call-ledger.mjs';
import { assertDurableGeneration, probeDirectoryDurable } from './async/atomic-fs.mjs';
import {
  createFileFreeTrialStore,
  createMemoryFreeTrialStore,
  isFreeTrialHeader,
  requirePaidOrFreeTrial,
} from './async/free-trial.mjs';

export function configuration(env = process.env) {
  const integer = (key, fallback, min, max) => {
    const n = Number(env[key] ?? fallback);
    if (!Number.isInteger(n) || n < min || n > max) throw Error(`Invalid ${key}`);
    return n;
  };
  const allowDevAuth = env.ALLOW_DEV_AUTH === '1';
  if (allowDevAuth && (env.NODE_ENV === 'production' || !env.WEEKFIT_DEV_TOKEN || env.WEEKFIT_DEV_TOKEN.length < 16)) {
    throw Error('Development auth requires a non-production environment and a token of at least 16 characters');
  }
  const openAIMock = env.OPENAI_MOCK === '1';
  if (openAIMock && env.NODE_ENV === 'production') {
    throw Error('OPENAI_MOCK is forbidden in production');
  }
  // medium is the latency default; set FOOD_PHOTO_REASONING_EFFORT=high only after measuring quality.
  const effort = env.FOOD_PHOTO_REASONING_EFFORT ?? 'medium';
  if (!['low', 'medium', 'high', 'xhigh', 'max'].includes(effort)) throw Error('Invalid reasoning effort');
  const model = env.FOOD_PHOTO_MODEL ?? 'gpt-6-astra';
  if (!['gpt-6-astra', 'gpt-6.1-sol'].includes(model)) {
    throw Error('Unsupported model; explicitly update the server allowlist after evaluation');
  }
  const mockScenario = env.FOOD_PHOTO_MOCK_SCENARIO ?? 'ok';
  if (!['ok', 'rate_limit', 'server_error', 'timeout', 'slow', 'coach_invalid'].includes(mockScenario)) {
    throw Error('Invalid FOOD_PHOTO_MOCK_SCENARIO');
  }
  let summaryNow = null;
  if (env.COACH_SUMMARY_NOW) {
    if (env.NODE_ENV === 'production') throw Error('COACH_SUMMARY_NOW is forbidden in production');
    const parsed = new Date(env.COACH_SUMMARY_NOW);
    if (Number.isNaN(parsed.getTime())) throw Error('Invalid COACH_SUMMARY_NOW');
    const instant = parsed.getTime();
    summaryNow = () => new Date(instant);
  }
  const imageDetail = env.FOOD_PHOTO_IMAGE_DETAIL ?? 'auto';
  if (!['auto', 'low', 'high'].includes(imageDetail)) throw Error('Invalid FOOD_PHOTO_IMAGE_DETAIL');
  if (env.NODE_ENV === 'production' && env.COACH_SUMMARY_ONCE_PER_DAY === '0') {
    throw Error('COACH_SUMMARY_ONCE_PER_DAY=0 is forbidden in production');
  }
  if (env.NODE_ENV === 'production' && env.COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER === '1') {
    throw Error('COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER is forbidden in production');
  }
  return {
    apiKey: env.OPENAI_API_KEY ?? '',
    openAIMock,
    mockDelayMs: integer('FOOD_PHOTO_MOCK_DELAY_MS', 50, 0, 120000),
    mockScenario,
    model,
    effort,
    imageDetail,
    allowDevAuth,
    devToken: env.WEEKFIT_DEV_TOKEN ?? '',
    firebaseProject: env.FIREBASE_PROJECT_ID ?? '',
    port: integer('PORT', 8080, 1, 65535),
    timeoutMs: integer('OPENAI_TIMEOUT_MS', 90000, 1000, 180000),
    maxOutputTokens: integer('OPENAI_MAX_OUTPUT_TOKENS', 2500, 500, 32000),
    inlineFastPath: env.INLINE_FAST_PATH !== '0',
    dailyLimit: integer('DAILY_SCAN_LIMIT', 20, 1, 100000),
    maxConcurrency: integer('MAX_CONCURRENT_SCANS', 4, 1, 100),
    maxQueue: integer('MAX_AI_QUEUE', 16, 0, 1000),
    queueWaitMs: integer('AI_QUEUE_WAIT_MS', 8000, 0, 120000),
    retryAfterSeconds: integer('BUSY_RETRY_AFTER_SECONDS', 5, 1, 120),
    maxConcurrentUploads: integer('MAX_CONCURRENT_UPLOADS', 8, 1, 1000),
    maxUploadQueue: integer('MAX_UPLOAD_QUEUE', 24, 0, 10000),
    uploadQueueWaitMs: integer('UPLOAD_QUEUE_WAIT_MS', 2000, 0, 60000),
    bodyReadTimeoutMs: integer('BODY_READ_TIMEOUT_MS', 30000, 1000, 120000),
    globalDailyLimit: integer('GLOBAL_DAILY_SCAN_LIMIT', 200, 1, 100000),
    summaryModel: env.COACH_SUMMARY_MODEL ?? 'gpt-4.1-mini',
    summaryStoreDir: env.COACH_SUMMARY_STORE_DIR ?? '',
    summaryTimeoutMs: integer('COACH_SUMMARY_TIMEOUT_MS', 15000, 1000, 60000),
    summaryConcurrency: integer('COACH_SUMMARY_MAX_CONCURRENT', 2, 1, 8),
    summaryMaxBodyBytes: integer('COACH_SUMMARY_MAX_BODY_BYTES', 131072, 1024, 131072),
    // UTF-8 size of the instruction text plus the day snapshot. Not a token budget and not
    // the whole model request: the response schema and API framing are extra.
    // COACH_SUMMARY_MAX_INPUT_TOKENS is accepted as the same byte ceiling.
    summaryMaxInputTextBytes: integer(
      env.COACH_SUMMARY_MAX_INPUT_TEXT_BYTES != null
        ? 'COACH_SUMMARY_MAX_INPUT_TEXT_BYTES'
        : 'COACH_SUMMARY_MAX_INPUT_TOKENS',
      80000,
      1000,
      200000,
    ),
    // Output budget only. max_output_tokens does not promise a finished JSON object.
    // An incomplete or truncated response ends the attempt; it is not retried.
    summaryMaxOutputTokens: integer('COACH_SUMMARY_MAX_OUTPUT_TOKENS', 8192, 256, 16384),
    summaryMaxStartsPerUtcDay: integer('COACH_SUMMARY_MAX_STARTS_PER_UTC_DAY', 100, 1, 100000),
    summaryMaxStartsPerMinute: integer('COACH_SUMMARY_MAX_STARTS_PER_MINUTE', 10, 1, 1000),
    summaryMinIntervalMs: integer('COACH_SUMMARY_MIN_INTERVAL_HOURS', 20, 1, 48) * 60 * 60 * 1000,
    summaryCircuitFailures: integer('COACH_SUMMARY_CIRCUIT_FAILURES', 3, 1, 20),
    summaryCircuitOpenMs: integer('COACH_SUMMARY_CIRCUIT_OPEN_MINUTES', 30, 1, 240) * 60 * 1000,
    // Always on. Production refuses to boot if an operator tries to turn it off.
    summaryOncePerDay: true,
    summaryAllowUnrestrictedHeader: false,
    // Production stays dark until COACH_AI_ENABLED=1. Food recognition is unaffected.
    coachAiEnabled: env.COACH_AI_ENABLED != null
      ? env.COACH_AI_ENABLED === '1'
      : env.NODE_ENV !== 'production',
    // File ledger is one process on one disk. Production must say so explicitly.
    // Unset in production disables new Coach generations; reads of a saved result still work.
    coachSingleInstanceDeclared: env.NODE_ENV === 'production'
      ? env.COACH_SUMMARY_SINGLE_INSTANCE === '1'
      : env.COACH_SUMMARY_SINGLE_INSTANCE !== '0',
    summaryNow,
    ...asyncConfiguration(env),
  };
}

export function createServer(config, dependencies = {}) {
  const auth = dependencies.authenticate ?? authenticate;
  const analyze = dependencies.recognize ?? recognize;
  const requirePaid = dependencies.requirePaidSubscriptionJWS ?? requirePaidSubscriptionJWS;
  const explicitLedger = config.photoLedgerDir
    || (config.dataDirExplicit && config.dataDir ? config.dataDir : '');
  // Production must not invent a temp directory. fsync of that directory would not be a persistent mount.
  const ledgerDir = explicitLedger
    || (config.isProduction ? null : mkdtempSync(path.join(tmpdir(), 'weekfit-photo-')));
  const persistentDataDir = Boolean(explicitLedger);
  const directoryDurability = dependencies.directoryDurability
    ?? config.directoryDurability
    ?? (ledgerDir
      ? probeDirectoryDurable(ledgerDir)
      : { confirmed: null, reason: null, errno: null });
  const runtimeConfig = {
    ...config,
    directoryDurability,
    persistentDataDir,
    photoLedgerDir: config.photoLedgerDir || (persistentDataDir ? explicitLedger : ''),
  };
  const mockAdapter = dependencies.mockAdapter
    ?? (config.openAIMock
      ? createMockOpenAIAdapter({
        delayMs: config.mockDelayMs,
        scenario: config.mockScenario,
      })
      : null);

  // When mock mode is on, recognition must never see global fetch.
  const openaiFetcher = dependencies.openaiFetcher
    ?? mockAdapter?.fetcher
    ?? (config.openAIMock ? forbidRealOpenAIFetch() : undefined);
  const summary = createSummaryHandler(runtimeConfig, {
    ...dependencies,
    authenticate: auth,
    summaryNow: dependencies.summaryNow ?? config.summaryNow ?? undefined,
    summaryFetcher: dependencies.summaryFetcher ?? openaiFetcher,
  });

  const gate = dependencies.concurrencyGate ?? createConcurrencyGate({
    maxConcurrent: config.maxConcurrency,
    maxQueue: config.maxQueue,
    queueWaitMs: config.queueWaitMs,
    retryAfterSeconds: config.retryAfterSeconds,
  });
  const uploadGate = dependencies.uploadGate ?? createConcurrencyGate({
    maxConcurrent: config.maxConcurrentUploads,
    maxQueue: config.maxUploadQueue,
    queueWaitMs: config.uploadQueueWaitMs,
    retryAfterSeconds: config.retryAfterSeconds,
    timeoutDetail: 'upload_queue_timeout',
    fullDetail: 'upload_queue_full',
  });
  const idempotency = dependencies.idempotencyStore ?? createIdempotencyStore();
  const photoLedger = ledgerDir
    ? createPhotoCallLedger({
      dataDir: ledgerDir,
      userDailyLimit: config.dailyLimit,
      globalDailyLimit: config.globalDailyLimit,
    })
    : null;

  /** Async stack (202 accept + workers). Null when explicitly disabled. */
  let asyncStack = dependencies.asyncStack ?? null;
  const asyncReady = (async () => {
    if (dependencies.asyncStack === null) return null;
    if (asyncStack) return asyncStack;
    if (!config.asyncEnabled) return null;
    asyncStack = await createAsyncStack(config, dependencies);
    return asyncStack;
  })();

  const freeTrialReady = (async () => {
    if (dependencies.freeTrialStore) return dependencies.freeTrialStore;
    const stack = await asyncReady.catch(() => null);
    if (stack?.freeTrialStore) return stack.freeTrialStore;
    // Durable when DATA_DIR is mounted (Render disk); otherwise process-local.
    const dataDir = process.env.DATA_DIR?.trim();
    if (dataDir) {
      try {
        return await createFileFreeTrialStore({ dataDir });
      } catch {
        // Fall through to memory.
      }
    }
    return createMemoryFreeTrialStore();
  })();

  const enforceSubscriptionAccess = async (userId, headers) => {
    const freeTrialStore = await freeTrialReady;
    return requirePaidOrFreeTrial(headers['x-weekfit-subscription-jws'], {
      requirePaid: (headerValue, opts) => requirePaid(headerValue, opts),
      freeTrialStore,
      freeTrialRequested: isFreeTrialHeader(headers['x-weekfit-photo-free-trial']),
      userId,
      allowDevAuth: config.allowDevAuth && (
        userId === 'local-developer' || (typeof userId === 'string' && userId.startsWith('devuid:'))
      ),
    });
  };

  let dailyCount = 0;
  const userCounts = new Map();
  let inFlightHttp = 0;
  let peakInFlightHttp = 0;

  const send = (res, status, body, extraHeaders = {}) => {
    if (res.writableEnded || res.destroyed) return;
    const headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...extraHeaders,
    };
    res.writeHead(status, headers);
    res.end(JSON.stringify(body));
  };

  const configured = () => Boolean(
    (config.openAIMock || config.apiKey) && (config.firebaseProject || config.allowDevAuth),
  );
  const summaryConfigured = () => Boolean(
    (config.apiKey || config.openAIMock) && config.summaryStoreDir && config.summaryModel,
  );

  /**
   * Read JSON body with size + wall-clock limits.
   * Does NOT hold an AI concurrency slot (upload gate is separate).
   */
  const readJsonBody = async (req, { timeoutMs, abortSignal } = {}) => {
    const chunks = [];
    let size = 0;
    const signals = [];
    if (timeoutMs > 0) signals.push(AbortSignal.timeout(timeoutMs));
    if (abortSignal) signals.push(abortSignal);
    const combined = signals.length > 0 ? AbortSignal.any(signals) : null;

    await new Promise((resolve, reject) => {
      let settled = false;
      const fail = (error) => {
        if (settled) return;
        settled = true;
        req.removeListener('data', onData);
        req.removeListener('end', onEnd);
        req.removeListener('error', onError);
        try { req.destroy(); } catch { /* ignore */ }
        reject(error);
      };
      const onAbort = () => {
        const timedOut = combined?.reason?.name === 'TimeoutError'
          || (combined?.reason && String(combined.reason).includes('Timeout'));
        fail(timedOut
          ? new ServiceError('body_read_timeout', 408)
          : new ServiceError('client_aborted', 499));
      };
      const onData = (chunk) => {
        size += chunk.length;
        if (size > 12 * 1024 * 1024) {
          fail(new ServiceError('request_too_large', 413));
          return;
        }
        chunks.push(chunk);
      };
      const onEnd = () => {
        if (settled) return;
        settled = true;
        combined?.removeEventListener('abort', onAbort);
        resolve();
      };
      const onError = (error) => fail(error);

      if (combined?.aborted) {
        onAbort();
        return;
      }
      combined?.addEventListener('abort', onAbort, { once: true });
      req.on('data', onData);
      req.on('end', onEnd);
      req.on('error', onError);
    });

    try {
      return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch {
      throw new ServiceError('invalid_json');
    }
  };

  const server = http.createServer(async (req, res) => {
    const coachPath = (req.url ?? '').split('?')[0];
    if (coachPath === '/v1/coach/day-summary' && (req.method === 'POST' || req.method === 'GET')) {
      return summary(req, res);
    }

    const requestId = randomUUID();
    const started = Date.now();
    let aiTicket;
    let uploadTicket;
    let releaseWaiter = () => {};

    if (req.method === 'GET' && req.url === '/healthz') {
      const stack = await asyncReady.catch(() => null);
      let queueDepth = null;
      let circuit = null;
      if (stack) {
        queueDepth = await stack.jobStore.queueDepth().catch(() => null);
        circuit = await stack.circuit.snapshot().catch(() => null);
      }
      return send(res, 200, {
        ok: true,
        configured: configured(),
        model: config.model,
        photoPromptVersion: FOOD_PROMPT_VERSION,
        allowDevAuth: config.allowDevAuth,
        openAIMock: Boolean(config.openAIMock),
        asyncAnalysis: Boolean(stack),
        photoAnalyzeMode: stack ? 'async' : 'sync_compat',
        stateBackend: stack?.asyncConfig?.stateBackend ?? config.stateBackend ?? null,
        objectStore: stack?.objectStore?.kind ?? config.objectStoreKind ?? null,
        globalAiSlots: stack?.asyncConfig?.globalAiSlots ?? null,
        targetBurstSlots: stack?.asyncConfig?.targetBurstSlots ?? null,
        coachSummaryConfigured: summaryConfigured(),
        coachSummaryOncePerDay: true,
        coachSummaryPromptVersion: SUMMARY_PROMPT_VERSION,
        coachAiEnabled: Boolean(config.coachAiEnabled),
        directoryDurable: directoryDurability.confirmed,
        durabilityReason: directoryDurability.reason,
        durabilityErrno: directoryDurability.errno,
        persistentDataDir,
        persistentDataDirReason: persistentDataDir ? null : 'persistent_mount_unconfirmed',
        fileLedgerGeneration: fileLedgerGenerationRefusal(runtimeConfig) ? 'refused' : 'allowed',
        coachSingleInstanceDeclared: config.coachSingleInstanceDeclared !== false,
        coachSummaryMaxConcurrent: config.summaryConcurrency,
        coachSummaryMaxStartsPerUtcDay: config.summaryMaxStartsPerUtcDay,
        coachSummaryMaxStartsPerMinute: config.summaryMaxStartsPerMinute,
        concurrency: gate.metrics(),
        uploads: uploadGate.metrics(),
        asyncQueueDepth: queueDepth,
        circuit,
        timeouts: {
          bodyReadTimeoutMs: config.bodyReadTimeoutMs,
          queueWaitMs: config.queueWaitMs,
          openaiTimeoutMs: config.timeoutMs,
          // Node http.Server.requestTimeout: idle socket / incomplete request budget.
          // It is NOT the same as “full AI processing finished within N ms”.
          requestTimeoutMs: Math.max(120_000, config.timeoutMs + 30_000),
          headersTimeoutMs: 15_000,
        },
        inFlightHttp,
        peakInFlightHttp,
        idempotencyEntries: idempotency.size(),
        mockMetrics: mockAdapter?.metrics?.() ?? null,
      });
    }
    if (req.method === 'GET' && req.url === '/readyz') {
      return send(res, configured() ? 200 : 503, { ready: configured() });
    }

    // --- Async analysis API (preferred): accept fast, workers process ---
    const asyncStatusMatch = req.method === 'GET'
      && req.url
      && /^\/v1\/food\/photo-analyze\/([0-9a-f-]{36})/i.exec(req.url.split('?')[0] ?? '');
    if (asyncStatusMatch) {
      inFlightHttp += 1;
      const clientAbort = new AbortController();
      const onClose = () => clientAbort.abort();
      req.on('aborted', onClose);
      req.on('close', onClose);
      try {
        // Stack init failure (Redis down, bad DATA_DIR, etc.) → same as disabled async.
        // iOS falls back to sync on async_not_configured; do not surface a bare 500.
        const stack = await asyncReady.catch(() => null);
        if (!stack) throw new ServiceError('async_not_configured', 503);
        if (!configured()) throw new ServiceError('service_not_configured', 503);
        const user = await auth(req.headers.authorization, config);
        const url = new URL(req.url, 'http://127.0.0.1');
        const waitMs = Math.max(0, Number(url.searchParams.get('waitMs') || 0) || 0);
        const payload = await stack.status({
          userId: user,
          analysisId: asyncStatusMatch[1],
          waitMs,
          abortSignal: clientAbort.signal,
        });
        return send(res, 200, payload);
      } catch (error) {
        const code = error instanceof ServiceError ? error.code : 'internal_error';
        const status = error instanceof ServiceError ? error.status : 500;
        const headers = {};
        if (error instanceof ServiceError && error.retryAfterSeconds) {
          headers['Retry-After'] = String(error.retryAfterSeconds);
        }
        return send(res, status, { error: code, requestId }, headers);
      } finally {
        inFlightHttp = Math.max(0, inFlightHttp - 1);
        req.off('aborted', onClose);
        req.off('close', onClose);
      }
    }

    // Compatibility for apps already using the new endpoint on sync-only hosts.
    // Use the existing bounded, paid, idempotent recognition path, not an
    // ephemeral async queue or a second provider request.
    const syncAnalyze = req.method === 'POST'
      && req.url === '/v1/food/photo-analyze'
      && !config.asyncEnabled && !asyncStack;

    if (req.method === 'POST' && req.url === '/v1/food/photo-analyze' && !syncAnalyze) {
      inFlightHttp += 1;
      peakInFlightHttp = Math.max(peakInFlightHttp, inFlightHttp);
      const clientAbort = new AbortController();
      const onClientClose = () => clientAbort.abort();
      req.on('aborted', onClientClose);
      try {
        const stack = await asyncReady.catch(() => null);
        if (!stack) throw new ServiceError('async_not_configured', 503);
        if (!configured()) throw new ServiceError('service_not_configured', 503);
        const user = await auth(req.headers.authorization, config);
        const access = await enforceSubscriptionAccess(user, req.headers);
        if (!req.headers['content-type']?.startsWith('application/json')) {
          throw new ServiceError('json_required', 415);
        }
        const body = await readJsonBody(req, {
          timeoutMs: config.bodyReadTimeoutMs,
          abortSignal: clientAbort.signal,
        });
        const outcome = await stack.submit({
          userId: user,
          headers: req.headers,
          body,
        });
        console.log(JSON.stringify({
          requestId,
          outcome: 'async_accepted',
          status: outcome.body.status,
          analysisId: outcome.body.analysisId,
          access: access.access,
          latencyMs: Date.now() - started,
          openAIMock: Boolean(config.openAIMock),
        }));
        return send(res, outcome.statusCode, outcome.body);
      } catch (error) {
        const timeout = ['TimeoutError', 'AbortError'].includes(error.name);
        const code = timeout
          ? (clientAbort.signal.aborted ? 'client_aborted' : 'recognition_timeout')
          : error instanceof ServiceError ? error.code : 'internal_error';
        const status = timeout
          ? (code === 'client_aborted' ? 499 : 504)
          : error instanceof ServiceError ? error.status : 500;
        const headers = {};
        if (error instanceof ServiceError && error.retryAfterSeconds) {
          headers['Retry-After'] = String(error.retryAfterSeconds);
        } else if (status === 503) {
          headers['Retry-After'] = String(config.retryAfterSeconds);
        }
        console.log(JSON.stringify({
          requestId,
          outcome: code,
          latencyMs: Date.now() - started,
          openAIMock: Boolean(config.openAIMock),
        }));
        return send(res, status, {
          error: code,
          requestId,
          ...(error instanceof ServiceError && error.detail ? { detail: error.detail } : {}),
        }, headers);
      } finally {
        inFlightHttp = Math.max(0, inFlightHttp - 1);
        req.off('aborted', onClientClose);
      }
    }

    if (req.method !== 'POST' || (req.url !== '/v1/food/photo-recognize' && !syncAnalyze)) {
      return send(res, 404, { error: 'not_found', requestId });
    }

    inFlightHttp += 1;
    peakInFlightHttp = Math.max(peakInFlightHttp, inFlightHttp);

    // Client disconnect releases an idempotency waiter; shared AI aborts only if last waiter.
    const clientAbort = new AbortController();
    const onClientClose = () => {
      clientAbort.abort();
      releaseWaiter();
    };
    req.on('aborted', onClientClose);
    res.on('close', () => {
      if (!res.writableEnded) onClientClose();
    });

    try {
      if (!configured()) throw new ServiceError('service_not_configured', 503);

      // 1) Auth + paid proof (or one complimentary free trial) before AI.
      const user = await auth(req.headers.authorization, config);
      await enforceSubscriptionAccess(user, req.headers);

      if (!req.headers['content-type']?.startsWith('application/json')) {
        throw new ServiceError('json_required', 415);
      }

      // 2) Bounded upload concurrency (separate from AI slots) → read/validate body.
      uploadTicket = await uploadGate.acquire();
      let input;
      try {
        const body = await readJsonBody(req, {
          timeoutMs: config.bodyReadTimeoutMs,
          abortSignal: clientAbort.signal,
        });
        input = validateInput(body);
      } finally {
        uploadTicket.release();
        uploadTicket = undefined;
      }

      const idemKey = normalizeIdempotencyKey(
        req.headers['idempotency-key'] ?? req.headers['x-weekfit-analysis-id'],
      );
      const fingerprint = fingerprintPayload(input.imageBase64);

      const live = idemKey ? idempotency.get(user, idemKey) : null;
      // A sibling of an in-flight request must join that waiter. The durable
      // marker is already written by then; treating it as a finished unknown
      // attempt would reject the sibling instead of sharing the one call.
      const prior = idemKey && photoLedger && live?.status !== 'inflight'
        ? await photoLedger.read(user, idemKey, fingerprint)
        : null;
      if (live?.status !== 'inflight' && prior?.providerStarted && prior.status !== 'completed') {
        throw new ServiceError('attempt_unknown', 409);
      }
      if (live?.status !== 'inflight' && !(prior?.status === 'completed' && prior.result)) {
        if (!photoLedger) throw new ServiceError('persistent_data_dir_required', 503, { detail: 'persistent_mount_unconfirmed' });
        const snap = await photoLedger.snapshot(user);
        if (snap.userCount >= config.dailyLimit || snap.globalCount >= config.globalDailyLimit) {
          throw new ServiceError('daily_scan_limit', 429, { retryAfterSeconds: 3600 });
        }
      }

      const { value, fromCache } = prior?.status === 'completed' && prior.result
        ? {
          value: { result: prior.result, usage: null, queueWaitMs: 0, aiMs: 0 },
          fromCache: true,
        }
        : await idempotency.run(
        user,
        idemKey,
        fingerprint,
        async ({ abortSignal }) => {
          // 3) Bounded AI concurrency (+ optional short queue) AFTER body is fully read.
          aiTicket = await gate.acquire();
          const queueWaitMs = aiTicket.queueWaitMs;
          const aiStarted = Date.now();
          let ownedCall = false;
          let prepared = null;
          try {
            assertPersistentDataDir(runtimeConfig);
            assertDurableGeneration(runtimeConfig);
            assertFileLedgerCanGenerate(runtimeConfig);
            if (!photoLedger) {
              throw new ServiceError('persistent_data_dir_required', 503, { detail: 'persistent_mount_unconfirmed' });
            }
            prepared = await photoLedger.prepare({ userId: user, idempotencyKey: idemKey, fingerprint });
            if (prepared.globalCount != null) dailyCount = prepared.globalCount;
            if (prepared.userCount != null) userCounts.set(user, prepared.userCount);
            if (prepared.record?.status === 'completed' && prepared.record.result) {
              return {
                result: prepared.record.result,
                usage: null,
                queueWaitMs,
                aiMs: 0,
              };
            }
            if (prepared.record?.providerStarted) throw new ServiceError('attempt_unknown', 409);
            const marked = await photoLedger.markProviderStarted(prepared.analysisId, user);
            if (!marked.startedByUs) throw new ServiceError('attempt_unknown', 409);
            ownedCall = true;
            const analyzed = await analyze(input, {
              ...config,
              openaiFetcher,
              abortSignal,
            }, openaiFetcher);
            await photoLedger.complete(prepared.analysisId, analyzed.result, user);
            return {
              result: analyzed.result,
              usage: analyzed.usage,
              queueWaitMs,
              aiMs: Date.now() - aiStarted,
            };
          } catch (error) {
            if (ownedCall) await photoLedger.fail(prepared?.analysisId, user).catch(() => {});
            throw error;
          } finally {
            aiTicket?.release();
            aiTicket = undefined;
          }
        },
        {
          onAttached: (handle) => {
            releaseWaiter = handle.releaseWaiter;
          },
        },
      );

      const e2eMs = Date.now() - started;
      const queueWaitMs = fromCache ? 0 : (value.queueWaitMs ?? 0);
      const aiMs = fromCache ? 0 : (value.aiMs ?? 0);
      console.log(JSON.stringify({
        requestId,
        model: config.model,
        latencyMs: e2eMs,
        queueWaitMs,
        aiMs,
        fromCache: Boolean(fromCache),
        outcome: 'success',
        inputTokens: value.usage?.input_tokens,
        outputTokens: value.usage?.output_tokens,
        openAIMock: Boolean(config.openAIMock),
      }));
      const result = { ...value.result, model: config.model, requestId };
      const key = normalizeIdempotencyKey(req.headers['idempotency-key'] ?? req.headers['x-weekfit-analysis-id']);
      const analysisId = key && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(key)
        ? key.toLowerCase() : requestId;
      send(res, 200, syncAnalyze ? {
        ...result,
        analysisId,
        status: 'completed',
        result,
        inline: true,
        delivery: 'sync_compat',
        timings: { e2eMs, queueWaitMs, aiMs },
      } : result, {
        'X-WeekFit-Queue-Wait-Ms': String(queueWaitMs),
        'X-WeekFit-AI-Ms': String(aiMs),
        'X-WeekFit-E2E-Ms': String(e2eMs),
        'X-WeekFit-Idempotent-Hit': fromCache ? '1' : '0',
      });
    } catch (error) {
      const timeout = ['TimeoutError', 'AbortError'].includes(error.name);
      const code = timeout
        ? (clientAbort.signal.aborted && error.name === 'AbortError' ? 'client_aborted' : 'recognition_timeout')
        : error instanceof ServiceError
          ? error.code
          : 'internal_error';
      const status = timeout
        ? (code === 'client_aborted' ? 499 : 504)
        : error instanceof ServiceError ? error.status : 500;
      console.log(JSON.stringify({
        requestId,
        model: config.model,
        latencyMs: Date.now() - started,
        outcome: code,
        openAIMock: Boolean(config.openAIMock),
      }));
      const headers = {};
      if (error instanceof ServiceError && error.retryAfterSeconds) {
        headers['Retry-After'] = String(error.retryAfterSeconds);
      } else if (status === 503) {
        headers['Retry-After'] = String(config.retryAfterSeconds);
      }
      send(res, status, {
        error: code,
        requestId,
        ...(error instanceof ServiceError && error.detail ? { detail: error.detail } : {}),
      }, headers);
    } finally {
      inFlightHttp = Math.max(0, inFlightHttp - 1);
      uploadTicket?.release();
      aiTicket?.release();
      releaseWaiter();
      req.off('aborted', onClientClose);
    }
  });

  // requestTimeout: Node closes the socket if the *request* stays incomplete / idle too long.
  // It is NOT a guarantee that AI work finishes within this window, and it is not the iOS
  // overall deadline. Raise it above OPENAI_TIMEOUT_MS so a slow provider call is not
  // killed by the HTTP server while still within the AI budget.
  server.requestTimeout = Math.max(120_000, config.timeoutMs + 30_000);
  server.headersTimeout = 15_000;
  server.keepAliveTimeout = 10_000;

  server.weekfitInternals = {
    gate,
    uploadGate,
    idempotency,
    mockAdapter,
    asyncReady,
    getAsyncStack: () => asyncStack,
    getDailyCount: () => dailyCount,
    getUserLimit: (user) => userCounts.get(user) ?? 0,
    photoLedgerDir: ledgerDir,
  };
  server.asyncReady = asyncReady;
  server.on('close', () => summary.stop?.());
  const originalClose = server.close.bind(server);
  let closeStarted = false;
  server.close = function closeServer(callback) {
    if (!closeStarted) {
      closeStarted = true;
      // Drop the Coach SQLite lock before sockets drain. A keep-alive fetch
      // socket would otherwise hold close() open and leave the database handle
      // referenced for the rest of the process.
      try { summary.stop?.(); } catch { /* already stopped */ }
      server.closeIdleConnections?.();
      server.closeAllConnections?.();
      return originalClose(callback);
    }
    if (typeof callback === 'function') queueMicrotask(callback);
    return server;
  };

  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = configuration();
  const server = createServer(config);
  server.listen(config.port, '0.0.0.0', () => console.log(JSON.stringify({
    outcome: 'listening',
    port: config.port,
    model: config.model,
    configured: Boolean(config.openAIMock || config.apiKey),
    openAIMock: Boolean(config.openAIMock),
    coachSummaryConfigured: Boolean((config.apiKey || config.openAIMock) && config.summaryStoreDir),
    maxConcurrency: config.maxConcurrency,
    maxQueue: config.maxQueue,
    maxConcurrentUploads: config.maxConcurrentUploads,
  })));
  for (const signal of ['SIGTERM', 'SIGINT']) {
    process.on(signal, () => {
      server.close(() => process.exit(0));
      setTimeout(() => process.exit(1), 10000).unref();
    });
  }
}
