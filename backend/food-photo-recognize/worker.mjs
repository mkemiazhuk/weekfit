#!/usr/bin/env node
/**
 * Async photo-analysis worker.
 * Stateless wrt local disk when STATE_BACKEND=redis. OPENAI_MOCK=1 forbids real network.
 */
import { pathToFileURL } from 'node:url';
import { configuration } from './server.mjs';
import { asyncConfiguration, createAsyncStack } from './async/bootstrap.mjs';
import { createWorkerRuntime, buildWorkerMockAdapter } from './async/worker-runtime.mjs';

export async function startWorker(env = process.env) {
  const base = configuration(env);
  const asyncCfg = asyncConfiguration(env);
  const config = { ...base, ...asyncCfg, asyncEnabled: true };
  if (!config.openAIMock && !config.apiKey) {
    throw new Error('Worker requires OPENAI_API_KEY or OPENAI_MOCK=1');
  }

  const stack = await createAsyncStack(config);
  const mockAdapter = buildWorkerMockAdapter(config);
  const runtime = createWorkerRuntime({
    config: stack.asyncConfig,
    jobStore: stack.jobStore,
    objectStore: stack.objectStore,
    aiSlots: stack.aiSlots,
    circuit: stack.circuit,
    budget: stack.budget,
    providerLimits: stack.providerLimits,
    mockAdapter,
  });

  const shutdown = async (signal) => {
    console.log(JSON.stringify({ outcome: 'worker_shutdown', signal }));
    await runtime.stop({ drainMs: 25_000 });
    process.exit(0);
  };
  for (const signal of ['SIGTERM', 'SIGINT']) {
    process.on(signal, () => { shutdown(signal).catch(() => process.exit(1)); });
  }

  let maintaining = false;
  setInterval(async () => {
    if (maintaining) return;
    maintaining = true;
    console.log(JSON.stringify({ event: 'worker_metrics', readyWaiters: stack.jobStore.metrics?.().readyWaiters ?? null, inFlight: runtime.inFlight }));
    try {
      const protectedKeys = await stack.jobStore.protectedPhotoKeys?.();
      const photos = await stack.objectStore.cleanupExpired(Date.now(), protectedKeys);
      const jobs = await stack.jobStore.cleanupExpiredJobs();
      await stack.aiSlots.sweep();
      if (photos?.removed || jobs?.removed) {
        console.log(JSON.stringify({ event: 'storage_cleanup', photosRemoved: photos?.removed ?? null, jobsRemoved: jobs?.removed ?? null }));
      }
    } catch (error) {
      console.error(JSON.stringify({ event: 'storage_cleanup_failed', code: error.code ?? 'cleanup_failed' }));
    } finally { maintaining = false; }
  }, 60_000).unref();

  console.log(JSON.stringify({
    outcome: 'worker_listening',
    workerId: runtime.workerId,
    stateBackend: config.stateBackend,
    globalAiSlots: config.globalAiSlots,
    workerLocalConcurrency: config.workerLocalConcurrency,
    targetBurstSlots: config.targetBurstSlots,
    openAIMock: Boolean(config.openAIMock),
  }));

  await runtime.runLoop({
    claimWaitMs: config.workerClaimWaitMs,
    localConcurrency: config.workerLocalConcurrency,
  });
  return runtime;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  startWorker().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

