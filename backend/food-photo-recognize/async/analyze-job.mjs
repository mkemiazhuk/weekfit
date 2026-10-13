import { recognize } from '../recognition.mjs';

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
  return recognize(
    { imageBase64: b64, locale: job.locale, note: job.note ?? '' },
    {
      ...config,
      openaiFetcher,
      abortSignal: AbortSignal.timeout(config.timeoutMs),
    },
    openaiFetcher,
  );
}
