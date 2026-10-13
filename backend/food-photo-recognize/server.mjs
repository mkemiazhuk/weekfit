import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { authenticate } from './auth.mjs';
import { recognize, validateInput, ServiceError } from './recognition.mjs';
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
  if (!['ok', 'rate_limit', 'server_error', 'timeout', 'slow'].includes(mockScenario)) {
    throw Error('Invalid FOOD_PHOTO_MOCK_SCENARIO');
  }
  const imageDetail = env.FOOD_PHOTO_IMAGE_DETAIL ?? 'auto';
  if (!['auto', 'low', 'high'].includes(imageDetail)) throw Error('Invalid FOOD_PHOTO_IMAGE_DETAIL');
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
    summaryConcurrency: integer('COACH_SUMMARY_MAX_CONCURRENT', 4, 1, 100),
    // Production: COACH_SUMMARY_ONCE_PER_DAY=1 → after 20:00, one AI attempt per UID+local day.
    // Unset/0 for unrestricted testing (manual Coach refresh always calls AI).
    summaryOncePerDay: env.COACH_SUMMARY_ONCE_PER_DAY === '1',
    ...asyncConfiguration(env),
  };
}

export function createServer(config, dependencies = {}) {
  const auth = dependencies.authenticate ?? authenticate;
  const analyze = dependencies.recognize ?? recognize;
  const requirePaid = dependencies.requirePaidSubscriptionJWS ?? requirePaidSubscriptionJWS;
  const summary = createSummaryHandler(config, { ...dependencies, authenticate: auth });

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

  /** Async stack (202 accept + workers). Null when explicitly disabled. */
  let asyncStack = dependencies.asyncStack ?? null;
  const asyncReady = (async () => {
    if (dependencies.asyncStack === null) return null;
    if (asyncStack) return asyncStack;
    if (!config.asyncEnabled) return null;
    asyncStack = await createAsyncStack(config, dependencies);
    return asyncStack;
  })();

  const limits = new Map();
  /** Keys already charged against daily quota (user or user:idempotency). */
  const chargedKeys = new Set();
  let day = '';
  let dailyCount = 0;
  let inFlightHttp = 0;
  let peakInFlightHttp = 0;

  const resetDayIfNeeded = () => {
    const today = new Date().toISOString().slice(0, 10);
    if (day !== today) {
      limits.clear();
      chargedKeys.clear();
      dailyCount = 0;
      day = today;
    }
  };

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
  const summaryConfigured = () => Boolean(config.apiKey && config.summaryStoreDir && config.summaryModel);

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

  const chargeDailyQuota = (user, idemKey) => {
    resetDayIfNeeded();
    const chargeKey = idemKey ? `${user}:${idemKey}` : `${user}:${randomUUID()}`;
    if (chargedKeys.has(chargeKey)) return { charged: false, chargeKey };
    if ((limits.get(user) ?? 0) >= config.dailyLimit || dailyCount >= config.globalDailyLimit) {
      throw new ServiceError('daily_scan_limit', 429, { retryAfterSeconds: 3600 });
    }
    chargedKeys.add(chargeKey);
    limits.set(user, (limits.get(user) ?? 0) + 1);
    dailyCount += 1;
    return { charged: true, chargeKey };
  };

  const server = http.createServer(async (req, res) => {
    if (req.method === 'POST' && req.url === '/v1/coach/day-summary') {
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
        allowDevAuth: config.allowDevAuth,
        openAIMock: Boolean(config.openAIMock),
        asyncAnalysis: Boolean(stack),
        photoAnalyzeMode: stack ? 'async' : 'sync_compat',
        stateBackend: stack?.asyncConfig?.stateBackend ?? config.stateBackend ?? null,
        objectStore: stack?.objectStore?.kind ?? config.objectStoreKind ?? null,
        globalAiSlots: stack?.asyncConfig?.globalAiSlots ?? null,
        targetBurstSlots: stack?.asyncConfig?.targetBurstSlots ?? null,
        coachSummaryConfigured: summaryConfigured(),
        coachSummaryOncePerDay: Boolean(config.summaryOncePerDay),
        coachSummaryPromptVersion: SUMMARY_PROMPT_VERSION,
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
        const stack = await asyncReady;
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
        const stack = await asyncReady;
        if (!stack) throw new ServiceError('async_not_configured', 503);
        if (!configured()) throw new ServiceError('service_not_configured', 503);
        const user = await auth(req.headers.authorization, config);
        requirePaid(req.headers['x-weekfit-subscription-jws'], {
          allowDevAuth: config.allowDevAuth && user === 'local-developer',
        });
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

      // 1) Auth + paid proof before any expensive work / AI.
      const user = await auth(req.headers.authorization, config);
      requirePaid(req.headers['x-weekfit-subscription-jws'], {
        allowDevAuth: config.allowDevAuth && user === 'local-developer',
      });

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

      resetDayIfNeeded();
      if ((limits.get(user) ?? 0) >= config.dailyLimit || dailyCount >= config.globalDailyLimit) {
        throw new ServiceError('daily_scan_limit', 429, { retryAfterSeconds: 3600 });
      }

      const { value, fromCache } = await idempotency.run(
        user,
        idemKey,
        fingerprint,
        async ({ abortSignal }) => {
          // 3) Bounded AI concurrency (+ optional short queue) AFTER body is fully read.
          aiTicket = await gate.acquire();
          const queueWaitMs = aiTicket.queueWaitMs;
          const aiStarted = Date.now();
          try {
            chargeDailyQuota(user, idemKey);
            const analyzed = await analyze(input, {
              ...config,
              openaiFetcher,
              abortSignal,
            }, openaiFetcher);
            return {
              result: analyzed.result,
              usage: analyzed.usage,
              queueWaitMs,
              aiMs: Date.now() - aiStarted,
            };
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
    getUserLimit: (user) => limits.get(user) ?? 0,
  };
  server.asyncReady = asyncReady;

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
    coachSummaryConfigured: Boolean(config.apiKey && config.summaryStoreDir),
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
