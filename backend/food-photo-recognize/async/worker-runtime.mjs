import { ServiceError } from '../recognition.mjs';
import { createMockOpenAIAdapter, forbidRealOpenAIFetch } from '../openai-mock.mjs';
import {
  computeRetryDelayMs,
  isRetryableProviderError,
  isSoftRequeueError,
} from './provider-budget.mjs';
import { analyzeQueuedPhoto } from './analyze-job.mjs';
import {
  assertPersistentDataDir,
  claimProviderCall,
  fileLedgerGenerationRefusal,
  savePhotoAttemptResult,
} from '../photo-call-ledger.mjs';
import { assertDurableGeneration, probeDirectoryDurable } from './atomic-fs.mjs';

/**
 * Worker loop: blocking claim → global AI slot → provider limits → AI → complete.
 * No periodic idle sleep when waitMs>0 (BRPOP / file wake).
 */
export function createWorkerRuntime({
  config,
  jobStore,
  objectStore,
  aiSlots,
  circuit,
  budget,
  providerLimits = null,
  mockAdapter = null,
  workerId = `worker-${process.pid}`,
  onLog = (obj) => console.log(JSON.stringify(obj)),
}) {
  const openaiFetcher = mockAdapter?.fetcher
    ?? (config.openAIMock ? forbidRealOpenAIFetch() : undefined);
  const durableConfig = {
    ...config,
    directoryDurability: config.directoryDurability
      ?? (config.dataDir ? probeDirectoryDurable(config.dataDir) : null),
  };

  let stopping = false;
  let inFlight = 0;
  let lastLeaseSweepAt = 0;

  const stop = async ({ drainMs = 25_000 } = {}) => {
    stopping = true;
    const deadline = Date.now() + drainMs;
    while (inFlight > 0 && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 50));
    }
  };

  const maybeRecoverLeases = async () => {
    const now = Date.now();
    if (now - lastLeaseSweepAt < 1000) return;
    lastLeaseSweepAt = now;
    await jobStore.recoverExpiredLeases();
  };

  const processOne = async (job) => {
    inFlight += 1;
    const started = Date.now();
    let slot = null;
    let rateTicket = null;
    let enteredProvider = false;
    const leaseToken = job.leaseToken ?? null;
    const maxQueueWaitMs = Number(config.maxQueueWaitMs ?? 0);

    try {
      try {
        assertPersistentDataDir(durableConfig);
      } catch (error) {
        console.error(JSON.stringify({
          event: 'ai_call_blocked',
          reason: error.detail ?? error.code,
          analysisId: job.analysisId,
          workerId,
        }));
        await jobStore.failJob(job.analysisId, {
          userId: job.userId,
          error: error.code ?? 'persistent_data_dir_required',
          providerOutcome: 'failed',
          requeue: false,
          leaseToken,
        });
        return { outcome: 'persistent_data_dir_required' };
      }
      const ledgerRefusal = fileLedgerGenerationRefusal(durableConfig);
      if (ledgerRefusal) {
        console.error(JSON.stringify({
          event: 'ai_call_blocked',
          reason: ledgerRefusal.detail,
          analysisId: job.analysisId,
          workerId,
        }));
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: ledgerRefusal.code,
          providerOutcome: 'failed',
          requeue: false,
          leaseToken,
        });
        return { outcome: ledgerRefusal.code };
      }
      try {
        assertDurableGeneration(durableConfig);
      } catch (error) {
        console.error(JSON.stringify({
          event: 'ai_call_blocked',
          reason: error.detail ?? error.code,
          analysisId: job.analysisId,
          workerId,
        }));
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: error.code ?? 'durability_unconfirmed',
          providerOutcome: 'failed',
          requeue: false,
          leaseToken,
        });
        return { outcome: 'durability_unconfirmed' };
      }
      if (maxQueueWaitMs > 0 && job.createdAt && (Date.now() - job.createdAt) > maxQueueWaitMs) {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: 'queue_wait_exceeded',
          providerOutcome: 'shed',
          requeue: false,
          leaseToken,
        });
        return { outcome: 'queue_timeout' };
      }

      await Promise.all([
        circuit.beforeCall(),
        budget.assertWithinBudget(),
      ]);

      if (providerLimits) {
        rateTicket = providerLimits.tryReserve();
        if (!rateTicket.ok) {
          await jobStore.failJob(job.analysisId, { userId: job.userId,
            error: rateTicket.code,
            providerOutcome: 'shed',
            requeue: true,
            softRequeue: true,
            leaseToken,
          });
          return { outcome: 'rate_limited' };
        }
      }

      slot = await aiSlots.tryAcquire(workerId);
      if (!slot) {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: 'ai_slots_full',
          providerOutcome: 'retryable',
          requeue: true,
          softRequeue: true,
          leaseToken,
        });
        return { outcome: 'requeued_no_slot' };
      }

      let jpeg;
      try {
        jpeg = await objectStore.getJpeg(job.photoKey);
      } catch (storeError) {
        storeError.code = storeError.code || 'object_store_unavailable';
        throw storeError;
      }

      const marked = await jobStore.markProviderStarted(job.analysisId, leaseToken, job.userId);
      if (!marked?.providerStarted) {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: 'provider_not_started',
          providerOutcome: 'uncertain',
          requeue: false,
          leaseToken,
        }).catch(() => {});
        return { outcome: 'uncertain' };
      }
      const claimed = await claimProviderCall(config.dataDir, job.analysisId, job.userId);
      if (!claimed) {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: 'provider_already_started',
          providerOutcome: 'uncertain',
          requeue: false,
          leaseToken,
        }).catch(() => {});
        return { outcome: 'uncertain' };
      }
      enteredProvider = true;
      await budget.recordAttempt({ uncertain: false });

      const leaseHeartbeat = setInterval(() => {
        jobStore.renewLease(job.analysisId, workerId, config.workerLeaseMs, leaseToken, job.userId).catch(() => {});
        slot.renew().catch(() => {});
      }, Math.max(5_000, Math.floor(config.workerLeaseMs / 3)));

      let analyzed;
      try {
        analyzed = await analyzeQueuedPhoto({
          job,
          config,
          objectStore,
          openaiFetcher,
          imageBase64: jpeg.toString('base64'),
        });
      } finally {
        clearInterval(leaseHeartbeat);
      }

      await circuit.recordSuccess();
      await savePhotoAttemptResult(config.dataDir, job.analysisId, analyzed.result, job.userId).catch(() => {});
      await jobStore.completeJob(job.analysisId, {
        userId: job.userId,
        result: analyzed.result,
        providerOutcome: 'success',
        leaseToken,
      });
      if (config.deletePhotoOnComplete) {
        objectStore.delete(job.photoKey).catch(() => {});
      }
      onLog({
        workerId,
        analysisId: job.analysisId,
        outcome: 'completed',
        latencyMs: Date.now() - started,
        openAIMock: Boolean(config.openAIMock),
      });
      return { outcome: 'completed' };
    } catch (error) {
      const code = error instanceof ServiceError
        ? error.code
        : (error.code ?? error.name ?? 'internal_error');

      // The provider call already started. A retry, including uncertain_retry, would be a second call
      // for the same analysisId. The job stays terminal.
      if (enteredProvider) {
        await circuit.recordFailure().catch(() => {});
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: code,
          providerOutcome: 'uncertain',
          requeue: false,
          leaseToken,
        });
        onLog({
          workerId,
          analysisId: job.analysisId,
          outcome: 'uncertain',
          error: code,
          openAIMock: Boolean(config.openAIMock),
        });
        return { outcome: 'uncertain' };
      }

      // Provider 429 / rate — soft requeue, never blind duplicate while uncertain.
      if (code === 'provider_rate_limited' || code === 'provider_rpm_limited' || code === 'provider_tpm_limited') {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: code,
          providerOutcome: enteredProvider ? 'uncertain' : 'shed',
          requeue: !enteredProvider,
          softRequeue: !enteredProvider,
          leaseToken,
        });
        return { outcome: 'rate_limited' };
      }

      if (code === 'circuit_open' || code === 'provider_budget_exhausted') {
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: code,
          providerOutcome: 'shed',
          requeue: true,
          softRequeue: true,
          leaseToken,
        });
        return { outcome: 'shed' };
      }

      await circuit.recordFailure().catch(() => {});

      const attempts = job.attempts ?? 1;
      const soft = !enteredProvider && isSoftRequeueError(error);
      const retryable = soft
        || (isRetryableProviderError(error) && attempts < (job.maxAttempts ?? config.workerMaxAttempts));

      if (retryable) {
        if (!soft) {
          const delay = computeRetryDelayMs(attempts, {
            baseMs: config.workerRetryBaseMs,
            maxMs: config.workerRetryMaxMs,
          });
          await new Promise((r) => setTimeout(r, delay));
        }
        await jobStore.failJob(job.analysisId, { userId: job.userId,
          error: code,
          providerOutcome: 'retryable',
          requeue: true,
          softRequeue: soft,
          leaseToken,
        });
        onLog({
          workerId,
          analysisId: job.analysisId,
          outcome: soft ? 'requeued_soft' : 'requeued',
          error: code,
          attempts,
          openAIMock: Boolean(config.openAIMock),
        });
        return { outcome: 'requeued' };
      }

      await jobStore.failJob(job.analysisId, {
        userId: job.userId,
        error: code,
        providerOutcome: enteredProvider ? 'uncertain' : 'failed',
        requeue: false,
        leaseToken,
      });
      onLog({
        workerId,
        analysisId: job.analysisId,
        outcome: 'failed',
        error: code,
        providerOutcome: enteredProvider ? 'uncertain' : 'failed',
        openAIMock: Boolean(config.openAIMock),
      });
      return { outcome: 'failed' };
    } finally {
      rateTicket?.release?.();
      await slot?.release?.();
      inFlight = Math.max(0, inFlight - 1);
    }
  };

  const tick = async () => {
    if (stopping) return false;
    await maybeRecoverLeases();
    const job = await jobStore.claimNext({
      workerId,
      leaseMs: config.workerLeaseMs,
      waitMs: 0,
    });
    if (!job) return false;
    await processOne(job);
    return true;
  };

  const runLoop = async ({
    // Blocking wait replaces idle sleep — workers wake on enqueue.
    claimWaitMs = Math.max(1000, Number(config.workerClaimWaitMs ?? 5000)),
    localConcurrency = Math.max(1, Number(config.workerLocalConcurrency ?? 2)),
  } = {}) => {
    onLog({
      workerId,
      outcome: 'worker_start',
      localConcurrency,
      claimWaitMs,
      globalAiSlots: config.globalAiSlots,
      openAIMock: Boolean(config.openAIMock),
    });
    /** @type {Set<Promise<unknown>>} */
    const running = new Set();
    while (!stopping) {
      try {
        await maybeRecoverLeases();
        while (!stopping && running.size < localConcurrency) {
          const waitMs = running.size === 0 ? claimWaitMs : 0;
          const job = await jobStore.claimNext({
            workerId,
            leaseMs: config.workerLeaseMs,
            waitMs,
          });
          if (!job) break;
          const task = processOne(job).finally(() => running.delete(task));
          running.add(task);
        }
        if (running.size === 0) {
          // claimNext already blocked; brief yield only if wait returned empty.
          continue;
        }
        await Promise.race(running);
      } catch (error) {
        onLog({
          workerId,
          outcome: 'worker_tick_error',
          error: error.code ?? error.message,
        });
        await new Promise((r) => setTimeout(r, 50));
      }
    }
    await Promise.allSettled([...running]);
    onLog({ workerId, outcome: 'worker_stop' });
  };

  return {
    workerId,
    tick,
    runLoop,
    stop,
    get inFlight() { return inFlight; },
  };
}

export function buildWorkerMockAdapter(config) {
  if (!config.openAIMock) return null;
  return createMockOpenAIAdapter({
    delayMs: config.mockDelayMs,
    scenario: config.mockScenario,
  });
}
