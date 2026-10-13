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

  setInterval(() => {
    stack.objectStore.cleanupExpired().catch(() => {});
    stack.jobStore.cleanupExpiredJobs().catch(() => {});
    stack.aiSlots.sweep().catch(() => {});
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
