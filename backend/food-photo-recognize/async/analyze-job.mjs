import { recognize, resolveOutputLanguage } from '../recognition.mjs';
import { providerAttemptKey } from '../observability.mjs';

/**
 * Single AI recognition for a durable job (worker or API inline fast-path).
 * One provider call per successful attempt — never fan-out duplicates.
 */
export async function analyzeQueuedPhoto({
  job,
  config,
  objectStore,
  openaiFetcher,
  imageBase64 = null,
}) {
  const b64 = imageBase64
    ?? (await objectStore.getJpeg(job.photoKey)).toString('base64');
  const language = resolveOutputLanguage(job.locale);
  return recognize(
    {
      imageBase64: b64,
      locale: language.code,
      language,
      note: job.note ?? '',
    },
    {
      ...config,
      observerAttemptKey: providerAttemptKey(job.userId, job.analysisId),
      openaiFetcher,
      abortSignal: AbortSignal.timeout(config.timeoutMs),
    },
    openaiFetcher,
  );
}

