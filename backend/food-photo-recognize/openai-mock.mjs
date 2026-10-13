/**
 * Deterministic OpenAI Responses API stub for local load / concurrency tests.
 * NEVER opens a network connection. Forbidden to fall back to real fetch.
 */
import { ServiceError } from './recognition.mjs';

export const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses';

export function mockFoodPayload(overrides = {}) {
  return {
    isFood: true,
    name: 'Mock rice bowl',
    items: [{
      name: 'Cooked rice',
      preparation: 'cooked',
      grams: 180,
      minGrams: 140,
      maxGrams: 220,
      calories: 234,
      protein: 4.9,
      carbs: 50.4,
      fat: 0.5,
      assumptions: ['Mock estimate'],
    }],
    uncertainties: ['Portion weight cannot be measured from this photo'],
    clarificationQuestion: null,
    ...overrides,
  };
}

/**
 * @param {{
 *   delayMs?: number,
 *   scenario?: 'ok'|'rate_limit'|'server_error'|'timeout'|'slow',
 *   onCall?: (info: object) => void,
 * }} [options]
 */
export function createMockOpenAIAdapter(options = {}) {
  let calls = 0;
  let active = 0;
  let peakParallelism = 0;
  let realFetchAttempts = 0;

  const delayMs = Number(options.delayMs ?? 50);
  const scenario = options.scenario ?? 'ok';

  const metrics = () => ({
    calls,
    active,
    peakParallelism,
    realFetchAttempts,
  });

  const reset = () => {
    calls = 0;
    active = 0;
    peakParallelism = 0;
    realFetchAttempts = 0;
  };

  /** @type {typeof fetch} */
  const fetcher = async (url, init = {}) => {
    const href = typeof url === 'string' ? url : String(url);
    if (!href.startsWith('https://api.openai.com/')) {
      realFetchAttempts += 1;
      throw new ServiceError('mock_forbids_network', 500);
    }

    calls += 1;
    active += 1;
    peakParallelism = Math.max(peakParallelism, active);
    options.onCall?.({ calls, active, peakParallelism, url: href });

    const signal = init.signal;
    const wait = (ms) => new Promise((resolve, reject) => {
      const timer = setTimeout(resolve, ms);
      const onAbort = () => {
        clearTimeout(timer);
        const err = new Error('Aborted');
        err.name = 'AbortError';
        reject(err);
      };
      if (signal?.aborted) {
        onAbort();
        return;
      }
      signal?.addEventListener?.('abort', onAbort, { once: true });
    });

    try {
      const effectiveDelay = scenario === 'slow' ? Math.max(delayMs, 20_000)
        : scenario === 'timeout' ? Math.max(delayMs, 60_000)
          : delayMs;
      await wait(effectiveDelay);

      if (scenario === 'rate_limit') {
        return new Response(JSON.stringify({ error: { message: 'rate limited' } }), { status: 429 });
      }
      if (scenario === 'server_error') {
        return new Response(JSON.stringify({ error: { message: 'upstream' } }), { status: 503 });
      }
      if (scenario === 'timeout') {
        const err = new Error('Timeout');
        err.name = 'TimeoutError';
        throw err;
      }

      const payload = mockFoodPayload();
      return new Response(JSON.stringify({
        status: 'completed',
        output: [{ content: [{ type: 'output_text', text: JSON.stringify(payload) }] }],
        usage: { input_tokens: 100, output_tokens: 80 },
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    } finally {
      active -= 1;
    }
  };

  return { fetcher, metrics, reset };
}

/** Hard reject — used when mock mode is enabled but no adapter fetcher was injected. */
export function forbidRealOpenAIFetch() {
  return async () => {
    throw new ServiceError('openai_mock_required', 500);
  };
}
