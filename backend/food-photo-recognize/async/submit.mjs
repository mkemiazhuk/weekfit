import { randomUUID, createHash } from 'node:crypto';
import { validateInput, ServiceError } from '../recognition.mjs';
import { normalizeIdempotencyKey } from '../idempotency.mjs';
import { JOB_STATUSES } from './job-store.mjs';
import { analyzeQueuedPhoto } from './analyze-job.mjs';
import { waitForJobUpdate, notifyJobUpdated } from './job-wait.mjs';

function fingerprintBytes(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

/**
 * Accept a photo analysis request.
 * Idle / capacity available → inline AI (200 + result) after durable job write.
 * Busy → durable enqueue + 202; workers drain the queue.
 */
export function createSubmitHandler({
  config,
  jobStore,
  objectStore,
  quota,
  uploadGate,
  aiSlots = null,
  circuit = null,
  budget = null,
  providerLimits = null,
  openaiFetcher = null,
}) {
  const inlineEnabled = config.inlineFastPath !== false;

  return async function submitAnalysis({
    userId,
    headers,
    body,
  }) {
    const stage = { t0: Date.now() };
    const mark = (name) => { stage[name] = Date.now() - stage.t0; };

    const rawIdem = normalizeIdempotencyKey(
      headers['idempotency-key'] ?? headers['x-weekfit-analysis-id'],
    );
    const idemKey = rawIdem ?? randomUUID();
    const preferredId = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idemKey)
      ? idemKey.toLowerCase()
      : randomUUID();

    const input = validateInput(body);
    const jpegBytes = Buffer.from(input.imageBase64, 'base64');
    const fingerprint = fingerprintBytes(jpegBytes);
    mark('validated');

    const depth = await jobStore.queueDepth();
    if (depth >= config.maxAsyncQueue) {
      throw new ServiceError('server_busy', 503, {
        retryAfterSeconds: config.retryAfterSeconds,
        detail: 'async_queue_full',
      });
    }

    let uploadTicket;
    try {
      uploadTicket = await uploadGate.acquire();
    } catch (error) {
      if (error instanceof ServiceError) throw error;
      throw new ServiceError('server_busy', 503, {
        retryAfterSeconds: config.retryAfterSeconds,
        detail: 'upload_queue_full',
      });
    }

    let analysisId = preferredId;
    try {
      let idem;
      try {
        idem = await jobStore.reserveIdempotency({
          userId,
          idempotencyKey: idemKey,
          fingerprint,
          analysisId,
        });
      } catch (error) {
        if (error.code === 'idempotency_key_reuse') {
          throw new ServiceError('idempotency_key_reuse', 409, {
            detail: 'same_key_different_payload',
          });
        }
        throw error;
      }

      analysisId = idem.analysisId;
      mark('idempotency');

      if (!idem.created) {
        const existing = await jobStore.getJob(analysisId);
        if (existing) {
          // Replay completed/failed/in-flight without a new AI call.
          return {
            statusCode: existing.status === JOB_STATUSES.completed
              || existing.status === JOB_STATUSES.failed
              ? 200
              : 202,
            body: {
              analysisId,
              status: existing.status,
              requestId: analysisId,
              idempotentReplay: true,
              pollAfterMs: config.pollHintMs,
              stageMs: stage,
              ...(existing.status === JOB_STATUSES.completed ? { result: existing.result } : {}),
              ...(existing.status === JOB_STATUSES.failed ? { error: existing.error } : {}),
            },
          };
        }
      }

      try {
        await quota.reserve({ userId, analysisId });
      } catch (error) {
        if (error.code === 'daily_scan_limit') {
          throw new ServiceError('daily_scan_limit', 429, { retryAfterSeconds: 3600 });
        }
        throw error;
      }
      mark('quota');

      const photo = await objectStore.putJpeg(userId, analysisId, jpegBytes);
      mark('objectPut');

      const { job, created } = await jobStore.createQueuedJob({
        analysisId,
        userId,
        idempotencyKey: idemKey,
        fingerprint,
        photoKey: photo.key,
        photoBytes: photo.bytes,
        locale: input.locale,
        note: input.note ?? '',
        model: config.model,
        maxAttempts: config.workerMaxAttempts,
        quotaReserved: true,
      });

      if (!created) {
        const existing = await jobStore.getJob(analysisId);
        uploadTicket?.release();
        uploadTicket = null;
        return {
          statusCode: existing?.status === JOB_STATUSES.completed ? 200 : 202,
          body: {
            analysisId,
            status: existing?.status ?? JOB_STATUSES.queued,
            requestId: analysisId,
            idempotentReplay: true,
            pollAfterMs: config.pollHintMs,
            ...(existing?.status === JOB_STATUSES.completed ? { result: existing.result } : {}),
          },
        };
      }

      // Release upload gate before AI — it only protects concurrent body/object puts.
      uploadTicket?.release();
      uploadTicket = null;

      // --- Inline fast-path: free AI capacity → analyze now (no queue wait) ---
      let slot = null;
      const canInline = inlineEnabled
        && aiSlots
        && circuit
        && budget
        && depth === 0;

      if (canInline) {
        try {
          await Promise.all([
            circuit.beforeCall(),
            budget.assertWithinBudget(),
          ]);
          slot = await aiSlots.tryAcquire(`api-inline-${process.pid}`);
          if (slot && providerLimits) {
            const rate = await providerLimits.tryReserve();
            if (!rate.ok) throw new Error(rate.code);
          }
        } catch {
          await slot?.release?.().catch(() => {});
          slot = null;
        }
      }

      if (slot) {
        const owner = `api-inline-${process.pid}`;
        const leaseMs = config.workerLeaseMs ?? 120_000;
        const leaseToken = randomUUID();
        await jobStore.saveJob({
          ...job,
          status: JOB_STATUSES.processing,
          leaseOwner: owner,
          leaseToken,
          leaseUntil: Date.now() + leaseMs,
          processingStartedAt: Date.now(),
          attempts: 1,
        });
        notifyJobUpdated(analysisId);
        mark('inlineStart');

        try {
          await budget.recordAttempt({ uncertain: false });
          const analyzed = await analyzeQueuedPhoto({
            job,
            config,
            objectStore,
            openaiFetcher,
          });
          await circuit.recordSuccess();
          await jobStore.completeJob(analysisId, {
            result: analyzed.result,
            providerOutcome: 'success',
            leaseToken,
          });
          if (config.deletePhotoOnComplete !== false) {
            objectStore.delete(photo.key).catch(() => {});
          }
          mark('inlineDone');
          return {
            statusCode: 200,
            body: {
              analysisId,
              status: JOB_STATUSES.completed,
              requestId: analysisId,
              result: analyzed.result,
              inline: true,
              pollAfterMs: config.pollHintMs,
              stageMs: stage,
              timings: {
                e2eMs: stage.inlineDone,
                acceptMs: stage.inlineDone,
                queueWaitMs: 0,
                aiMs: stage.inlineDone - (stage.inlineStart ?? stage.objectPut),
              },
            },
          };
        } catch (error) {
          await circuit.recordFailure().catch(() => {});
          const code = error?.code ?? error?.name ?? 'internal_error';
          await jobStore.failJob(analysisId, {
            error: code,
            providerOutcome: 'failed',
            requeue: false,
            leaseToken,
          }).catch(() => {});
          if (error instanceof ServiceError) throw error;
          throw new ServiceError(code, 502);
        } finally {
          await slot.release?.().catch(() => {});
        }
      }

      // Busy / no slot / inline disabled → queue only (workers pick up).
      await jobStore.enqueue(analysisId);
      mark('enqueued');

      return {
        statusCode: 202,
        body: {
          analysisId: job.analysisId,
          status: JOB_STATUSES.queued,
          requestId: job.analysisId,
          pollAfterMs: config.pollHintMs,
          inline: false,
          stageMs: stage,
        },
      };
    } finally {
      uploadTicket?.release();
    }
  };
}

function buildStatusPayload(job, queueDepth, pollHintMs) {
  const payload = {
    analysisId: job.analysisId,
    status: job.status,
    requestId: job.analysisId,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    attempts: job.attempts ?? 0,
    pollAfterMs: job.status === JOB_STATUSES.processing
      ? 200
      : job.status === JOB_STATUSES.queued
        ? (pollHintMs ?? 300)
        : null,
    delivery: 'long_poll_or_get',
  };
  if (job.status === JOB_STATUSES.queued && queueDepth != null) {
    payload.queueDepth = queueDepth;
  }
  if (job.status === JOB_STATUSES.completed) {
    payload.result = job.result;
    payload.model = job.model;
    payload.timings = {
      createdAt: job.createdAt,
      processingStartedAt: job.processingStartedAt ?? null,
      completedAt: job.updatedAt,
      queueWaitMs: job.processingStartedAt && job.createdAt
        ? Math.max(0, job.processingStartedAt - job.createdAt)
        : null,
      aiMs: job.processingStartedAt
        ? Math.max(0, job.updatedAt - job.processingStartedAt)
        : null,
      e2eMs: job.createdAt ? Math.max(0, job.updatedAt - job.createdAt) : null,
    };
  }
  if (job.status === JOB_STATUSES.failed) {
    payload.error = job.error;
    payload.providerOutcome = job.providerOutcome;
  }
  return payload;
}

/**
 * GET status with optional authenticated long-poll:
 *   ?waitMs=25000 — hold until terminal status or timeout (fallback: short GET).
 * Prefer long-poll over SSE for simpler auth/proxy and automatic fallback.
 */
export function createStatusHandler({ jobStore, longPollMaxMs = 25_000, pollHintMs = 250 }) {
  return async function getAnalysisStatus({ userId, analysisId, waitMs = 0, abortSignal = null }) {
    if (!/^[0-9a-f-]{36}$/i.test(analysisId)) {
      throw new ServiceError('not_found', 404);
    }
    let job = await jobStore.getJob(analysisId);
    if (!job) throw new ServiceError('not_found', 404);
    if (job.userId !== userId) throw new ServiceError('forbidden', 403);

    const cap = Math.min(Math.max(0, waitMs), longPollMaxMs);
    const deadline = Date.now() + cap;
    while (
      cap > 0
      && job.status !== JOB_STATUSES.completed
      && job.status !== JOB_STATUSES.failed
      && Date.now() < deadline
      && !abortSignal?.aborted
    ) {
      const slice = Math.min(250, deadline - Date.now());
      if (slice <= 0) break;
      // In-process wake + short Redis/file re-read for multi-instance workers.
      await waitForJobUpdate(analysisId, slice, abortSignal);
      job = await jobStore.getJob(analysisId);
      if (!job) throw new ServiceError('not_found', 404);
    }

    const depth = job.status === JOB_STATUSES.queued ? await jobStore.queueDepth() : null;
    return buildStatusPayload(job, depth, pollHintMs);
  };
}
