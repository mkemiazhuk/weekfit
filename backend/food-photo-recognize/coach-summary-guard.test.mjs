import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtemp, rm, mkdir, writeFile, readFile, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createServer } from './server.mjs';
import { ServiceError } from './recognition.mjs';
import {
  generateSummary, validateDay, SUMMARY_PROMPT_VERSION,
} from './coach-summary.mjs';
import { coachUserHash, createCoachAttemptStore, legacyAttemptFileName } from './coach-attempt-store.mjs';

const input = (overrides = {}) => ({
  schemaVersion: 1,
  day: '2026-10-12',
  timezone: 'Europe/Warsaw',
  locale: 'ru',
  phase: 'evening',
  facts: {
    sleep: [{ id: 'sleep.duration', text: 'Last night: 6 hours sleep.' }],
    nutrition: [{ id: 'nutrition.completeness', text: 'Food log completeness unknown.' }],
    coachDecision: [{ id: 'coach.priority', text: 'One priority: wind down for sleep.' }],
  },
  ...overrides,
});

const answer = () => ({
  headline: 'Итог дня',
  today: { text: 'Сон был коротким.', evidenceIds: ['sleep.duration'] },
  now: { text: 'Пора готовиться ко сну.', evidenceIds: ['coach.priority'] },
  tomorrow: { text: 'План на завтра пока неизвестен.', evidenceIds: [] },
  limitations: ['Питание записано не полностью.'],
});

const envelope = (text) => ({
  ok: true,
  status: 200,
  headers: { get: (name) => (name === 'x-request-id' ? 'prov-1' : null) },
  json: async () => ({
    status: 'completed',
    output: [{ content: [{ type: 'output_text', text }] }],
    usage: { input_tokens: 20, output_tokens: 10 },
  }),
});

async function directory(t) {
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-guard-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

async function listen(t, dir, dependencies, config = {}) {
  const calls = { n: 0 };
  const generateSummaryImpl = dependencies.generateSummary ?? (async () => {
    calls.n += 1;
    return { result: answer() };
  });
  const s = createServer({
    apiKey: 'test',
    summaryModel: 'test-model',
    summaryStoreDir: dir,
    allowDevAuth: true,
    model: 'test-photo',
    dailyLimit: 20,
    maxConcurrency: 4,
    globalDailyLimit: 200,
    coachAiEnabled: true,
    ...config,
  }, {
    authenticate: async (header) => {
      if (!header) throw new ServiceError('unauthorized', 401);
      return header;
    },
    summaryNow: () => new Date('2026-10-12T18:00:00Z'),
    ...dependencies,
    generateSummary: dependencies.summaryFetcher ? undefined : generateSummaryImpl,
  });
  if (dependencies.summaryFetcher) {
    // createServer already captured dependencies. Rebuild is unnecessary:
    // passing generateSummary: undefined still overrides the default above.
  }
  s.listen(0, '127.0.0.1');
  await once(s, 'listening');
  t.after(() => s.close());
  const post = (body = input(), token = 'Bearer a', extraHeaders = {}) => fetch(
    `http://127.0.0.1:${s.address().port}/v1/coach/day-summary`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: token } : {}),
        ...extraHeaders,
      },
      body: JSON.stringify(body),
    },
  );
  return { s, post, calls, port: s.address().port };
}

function serverWithFetcher(t, dir, fetcher, config = {}, dependencies = {}) {
  const calls = { n: 0 };
  const wrapped = async (url, opts) => {
    calls.n += 1;
    return fetcher(url, opts);
  };
  return createServer({
    apiKey: 'test',
    summaryModel: 'gpt-4.1-mini',
    summaryStoreDir: dir,
    allowDevAuth: true,
    model: 'test-photo',
    dailyLimit: 20,
    maxConcurrency: 4,
    globalDailyLimit: 200,
    coachAiEnabled: true,
    summaryTimeoutMs: 15000,
    ...config,
  }, {
    authenticate: async (header) => {
      if (!header) throw new ServiceError('unauthorized', 401);
      return header;
    },
    summaryNow: () => new Date('2026-10-12T18:00:00Z'),
    summaryFetcher: wrapped,
    ...dependencies,
  });
}

test('100 parallel requests for one UID call the provider once', async (t) => {
  const seen = { n: 0 };
  const live = await listen(t, await directory(t), {
    generateSummary: async () => {
      seen.n += 1;
      await new Promise((r) => setTimeout(r, 20));
      return { result: answer() };
    },
  });
  const responses = await Promise.all(Array.from({ length: 100 }, () => live.post()));
  assert.equal(seen.n, 1);
  assert.ok(responses.every((response) => [200, 202, 409].includes(response.status)));
  const bodies = await Promise.all(responses.map((response) => response.json()));
  assert.equal(bodies.filter((body) => body.reused === false).length, 1);
});

test('two processes on one directory call the provider once', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const generateSummary = async () => {
    seen.n += 1;
    await new Promise((r) => setTimeout(r, 40));
    return { result: answer() };
  };
  const a = await listen(t, dir, { generateSummary });
  const b = await listen(t, dir, { generateSummary });
  const responses = await Promise.all([a.post(), b.post(), a.post(), b.post()]);
  assert.equal(seen.n, 1);
  assert.ok(responses.every((response) => [200, 202, 409, 503].includes(response.status)));
});

test('locale, payload, prompt version and timezone do not buy another call', async (t) => {
  const seen = { n: 0 };
  let now = new Date('2026-10-12T18:00:00Z');
  const { post } = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
    summaryNow: () => now,
  });
  assert.equal((await post()).status, 200);
  const changed = input();
  changed.locale = 'pl';
  changed.facts.tomorrow = [{ id: 'tomorrow.run', text: 'A different plan.' }];
  changed.promptVersion = 99;
  now = new Date('2026-10-12T19:00:00Z');
  const again = await post({ ...changed, timezone: 'Europe/Warsaw', day: '2026-10-12' });
  assert.equal(again.status, 200);
  assert.equal((await again.json()).reused, true);
  assert.equal(seen.n, 1);
});

test('provider timeout, 429, 500, invalid JSON, language leak and bad evidence do not retry', async (t) => {
  const cases = [
    {
      name: 'timeout',
      fetcher: async () => { const error = new Error('slow'); error.name = 'TimeoutError'; throw error; },
    },
    {
      name: '429',
      fetcher: async () => ({ ok: false, status: 429, headers: { get: () => null }, json: async () => ({}) }),
    },
    {
      name: '500',
      fetcher: async () => ({ ok: false, status: 500, headers: { get: () => null }, json: async () => ({}) }),
    },
    {
      name: 'invalid json',
      fetcher: async () => envelope('not-json'),
    },
    {
      name: 'incomplete',
      fetcher: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        json: async () => ({ status: 'incomplete', incomplete_details: { reason: 'max_output_tokens' }, output: [] }),
      }),
    },
    {
      name: 'language leak',
      fetcher: async () => envelope(JSON.stringify({
        ...answer(),
        headline: 'Day wrap',
        today: { text: 'You have logged only one meal so far today.', evidenceIds: ['sleep.duration'] },
      })),
    },
    {
      name: 'invalid evidence',
      fetcher: async () => envelope(JSON.stringify({
        ...answer(),
        today: { text: 'Сон был коротким.', evidenceIds: ['invented'] },
      })),
    },
  ];
  for (const item of cases) {
    const dir = await directory(t);
    const seen = { n: 0 };
    const s = serverWithFetcher(t, dir, async (...args) => {
      seen.n += 1;
      return item.fetcher(...args);
    });
    s.listen(0, '127.0.0.1');
    await once(s, 'listening');
    t.after(() => s.close());
    const post = () => fetch(`http://127.0.0.1:${s.address().port}/v1/coach/day-summary`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
      body: JSON.stringify(input()),
    });
    const first = await post();
    const second = await post();
    assert.equal(seen.n, 1, item.name);
    assert.notEqual(first.status, 200, item.name);
    assert.equal(second.status, 409, item.name);
    assert.ok(['attempt_failed', 'attempt_unknown'].includes((await second.json()).error), item.name);
  }
});

test('generateSummary itself performs one provider call when validation fails', async () => {
  let calls = 0;
  const day = validateDay(input({ locale: 'pl' }));
  await assert.rejects(() => generateSummary(day, { apiKey: 'test', summaryModel: 'gpt-4.1-mini' }, async () => {
    calls += 1;
    return envelope(JSON.stringify({
      ...answer(),
      headline: 'Day wrap',
      today: { text: 'You have logged only one meal so far today.', evidenceIds: ['sleep.duration'] },
    }));
  }), (error) => {
    assert.equal(error.code, 'invalid_summary_result');
    assert.equal(error.validationReason, 'language_mismatch');
    assert.equal(error.fieldPath, 'today.text');
    assert.equal(error.providerRequestId, 'prov-1');
    assert.deepEqual(error.usage, { input_tokens: 20, output_tokens: 10 });
    return true;
  });
  assert.equal(calls, 1);
  assert.equal(SUMMARY_PROMPT_VERSION, 15);
});

test('unparseable output keeps usage and a null provider id when the header is absent', async () => {
  let calls = 0;
  await assert.rejects(() => generateSummary(validateDay(input()), { apiKey: 'test', summaryModel: 'gpt-4.1-mini' }, async () => {
    calls += 1;
    return {
      ok: true,
      status: 200,
      headers: { get: () => null },
      json: async () => ({
        status: 'completed',
        usage: { input_tokens: 4, output_tokens: 1 },
        output: [{ content: [{ type: 'output_text', text: '{oops' }] }],
      }),
    };
  }), (error) => {
    assert.equal(error.validationReason, 'json_parse_failed');
    assert.equal(error.fieldPath, null);
    assert.equal(error.providerRequestId, null);
    assert.deepEqual(error.usage, { input_tokens: 4, output_tokens: 1 });
    assert.equal(error.message.includes('{oops'), false);
    return true;
  });
  assert.equal(calls, 1);
});

test('invalid summary stays one provider call across POST, GET, locale change and restart', async (t) => {
  const dir = await directory(t);
  const lines = [];
  const original = console.log;
  console.log = (line) => { lines.push(String(line)); };
  t.after(() => { console.log = original; });
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return {
      ok: true,
      status: 200,
      headers: { get: (name) => (name === 'x-request-id' ? 'prov-kept' : null) },
      json: async () => ({
        status: 'completed',
        usage: { input_tokens: 93, output_tokens: 40 },
        output: [{ content: [{ type: 'output_text', text: JSON.stringify({
          ...answer(),
          today: { text: 'Сон был коротким.', evidenceIds: ['not-a-fact'] },
        }) }] }],
      }),
    };
  };
  const open = () => new Promise((resolve) => {
    const server = serverWithFetcher(t, dir, fetcher, { summaryModel: 'gpt-4.1-mini' });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
  const post = (server, body = input()) => fetch(`http://127.0.0.1:${server.address().port}/v1/coach/day-summary`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
    body: JSON.stringify(body),
  });
  const read = (server) => fetch(`http://127.0.0.1:${server.address().port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe%2FWarsaw`, {
    headers: { Authorization: 'Bearer a' },
  });
  const first = await open();
  t.after(() => first.close());
  const bad = await post(first);
  const badBody = await bad.json();
  assert.equal(bad.status, 502);
  assert.equal(badBody.error, 'invalid_summary_result');
  assert.equal(badBody.validationReason, undefined);
  assert.equal(calls, 1);
  const changed = await post(first, { ...input(), locale: 'en' });
  assert.equal(changed.status, 409);
  assert.equal((await changed.json()).error, 'attempt_failed');
  const status = await read(first);
  assert.equal(status.status, 409);
  assert.equal((await status.json()).error, 'attempt_failed');
  assert.equal(calls, 1);
  await new Promise((resolve) => first.close(resolve));

  const restarted = await open();
  t.after(() => restarted.close());
  assert.equal((await post(restarted)).status, 409);
  assert.equal((await read(restarted)).status, 409);
  assert.equal(calls, 1);

  const events = lines.flatMap((line) => {
    try { return [JSON.parse(line)]; } catch { return []; }
  }).filter((row) => row.endpoint === 'coach_summary');
  const finished = events.find((row) => row.event === 'provider_call_finished' && row.outcome === 'failed');
  assert.equal(finished.validationReason, 'unknown_evidence_id');
  assert.equal(finished.fieldPath, 'today.evidenceIds[0]');
  assert.equal(finished.providerRequestId, 'prov-kept');
  assert.deepEqual(finished.usage, { input_tokens: 93, output_tokens: 40 });
  assert.equal(finished.model, 'gpt-4.1-mini');
  assert.equal(finished.promptVersion, SUMMARY_PROMPT_VERSION);
  assert.equal(finished.localDay, '2026-10-12');
  assert.equal(typeof finished.requestId, 'string');
  assert.equal(finished.requestId.length > 0, true);
  assert.equal(typeof finished.attemptId, 'string');
  assert.equal(finished.userHash.length, 16);
  const blob = JSON.stringify(events);
  assert.equal(blob.includes('not-a-fact'), false);
  assert.equal(blob.includes('Last night'), false);
  assert.equal(blob.includes('Сон был коротким'), false);
  assert.equal(blob.includes('Bearer'), false);
  assert.equal(blob.includes('Bearer a'), false);

  const userKey = coachUserHash('Bearer a');
  const saved = JSON.parse(await readFile(path.join(dir, 'coach-guard', 'users', userKey, 'days', '2026-10-12.json'), 'utf8'));
  assert.equal(saved.state, 'failed');
  assert.equal(saved.reason, 'invalid_summary_result');
  const budget = await readdir(path.join(dir, 'coach-guard', 'budget', 'utc-day', '2026-10-12'));
  assert.equal(budget.length, 1);
});

test('a lost owner before or after provider start cannot be regenerated', async (t) => {
  for (const state of ['reserved', 'provider_started']) {
    const dir = await directory(t);
    const uid = 'Bearer a';
    const userKey = coachUserHash(uid);
    const dayDir = path.join(dir, 'coach-guard', 'users', userKey, 'days');
    await mkdir(dayDir, { recursive: true });
    await writeFile(path.join(dayDir, '2026-10-12.json'), JSON.stringify({
      state,
      attemptId: 'lost',
      userKey,
      uidHash: userKey.slice(0, 16),
      localDay: '2026-10-12',
      timezone: 'Europe/Warsaw',
      locale: 'ru',
      reservedAt: '2026-10-12T00:00:00.000Z',
      ownerBootId: 'dead-process',
    }));
    const seen = { n: 0 };
    const { post } = await listen(t, dir, {
      generateSummary: async () => { seen.n += 1; return { result: answer() }; },
    });
    const response = await post();
    assert.equal(response.status, 409, state);
    assert.equal((await response.json()).error, 'attempt_unknown');
    assert.equal(seen.n, 0, state);
  }
});

test('completed is cached and failed or unknown stays terminal without OpenAI', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const first = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  assert.equal((await first.post()).status, 200);
  await new Promise((resolve) => first.s.close(resolve));
  const restarted = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  const cached = await restarted.post();
  assert.equal(cached.status, 200);
  assert.equal((await cached.json()).reused, true);
  assert.equal(seen.n, 1);

  const failedDir = await directory(t);
  const failing = await listen(t, failedDir, {
    generateSummary: async () => { seen.n += 1; throw new ServiceError('provider_error', 502); },
  });
  assert.equal((await failing.post()).status, 502);
  const again = await failing.post();
  assert.equal(again.status, 409);
  assert.equal((await again.json()).error, 'attempt_failed');
  assert.equal(seen.n, 2);
});

test('a leftover lock file is not ownership, and a missing store blocks generation', async (t) => {
  const dir = await directory(t);
  await mkdir(path.join(dir, 'coach-guard'), { recursive: true });
  await writeFile(path.join(dir, 'coach-guard', 'lock'), 'stuck');
  const seen = { n: 0 };
  const locked = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  assert.equal((await locked.post()).status, 200);
  assert.equal(seen.n, 1);

  const fileAsDir = path.join(dir, 'not-a-directory');
  await writeFile(fileAsDir, 'x');
  const broken = await listen(t, fileAsDir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  assert.equal((await broken.post()).status, 503);
  assert.equal(seen.n, 1);

  const missing = await listen(t, '', {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  assert.equal((await missing.post()).status, 503);
  assert.equal(seen.n, 1);
});

test('legacy day file is reused and does not call the provider', async (t) => {
  const dir = await directory(t);
  const saved = {
    ...answer(),
    day: '2026-10-12',
    locale: 'ru',
    generatedAt: '2026-10-12T18:05:00.000Z',
    source: 'ai',
  };
  await writeFile(path.join(dir, legacyAttemptFileName('Bearer a', '2026-10-12')), JSON.stringify({
    status: 'completed',
    result: saved,
  }));
  const seen = { n: 0 };
  const { post } = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  const response = await post();
  assert.equal(response.status, 200);
  assert.equal((await response.json()).reused, true);
  assert.equal(seen.n, 0);
});

test('timezone hop inside 20 hours is blocked and the next eligible day is allowed', async (t) => {
  const dir = await directory(t);
  let now = new Date('2026-10-12T18:00:00Z');
  const seen = { n: 0 };
  const { post } = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
    summaryNow: () => now,
  });
  assert.equal((await post()).status, 200);
  now = new Date('2026-10-13T07:00:00Z');
  const hopped = await post(input({ timezone: 'Pacific/Kiritimati', day: '2026-10-13' }));
  assert.equal(hopped.status, 429);
  assert.equal((await hopped.json()).error, 'uid_interval_blocked');
  assert.equal(seen.n, 1);
  now = new Date('2026-10-13T18:00:00Z');
  assert.equal((await post(input({ day: '2026-10-13' }))).status, 200);
  assert.equal(seen.n, 2);
});

test('global day, minute and concurrency budgets are shared and stop before OpenAI', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const { post } = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { summaryMaxStartsPerUtcDay: 1, summaryMaxStartsPerMinute: 10, summaryConcurrency: 2 });
  assert.equal((await post(input(), 'Bearer a')).status, 200);
  const blocked = await post(input(), 'Bearer b');
  const body = await blocked.json();
  assert.equal(blocked.status, 429);
  assert.equal(body.error, 'global_daily_limit');
  assert.equal(typeof body.nextEligibleAt, 'string');
  assert.equal(seen.n, 1);

  const minuteDir = await directory(t);
  const minuteSeen = { n: 0 };
  const minute = await listen(t, minuteDir, {
    generateSummary: async () => { minuteSeen.n += 1; return { result: answer() }; },
  }, { summaryMaxStartsPerMinute: 1, summaryMaxStartsPerUtcDay: 100 });
  assert.equal((await minute.post(input(), 'Bearer a')).status, 200);
  const limited = await minute.post(input(), 'Bearer b');
  assert.equal(limited.status, 429);
  assert.equal((await limited.json()).error, 'global_minute_limit');
  assert.equal(minuteSeen.n, 1);
});

test('circuit breaker is shared by the directory and the probe spends one real attempt', async (t) => {
  const dir = await directory(t);
  let now = new Date('2026-10-12T18:00:00Z');
  let release = () => {};
  const gate = new Promise((resolve) => { release = resolve; });
  const seen = { n: 0 };
  const { post } = await listen(t, dir, {
    summaryNow: () => now,
    generateSummary: async () => {
      seen.n += 1;
      if (seen.n <= 3) throw new ServiceError('provider_error', 502);
      if (seen.n === 4) await gate;
      return { result: answer() };
    },
  }, { summaryCircuitFailures: 3, summaryCircuitOpenMs: 30 * 60 * 1000 });
  for (const token of ['Bearer a', 'Bearer b', 'Bearer c']) {
    assert.equal((await post(input(), token)).status, 502);
  }
  const closed = await post(input(), 'Bearer d');
  assert.equal(closed.status, 503);
  assert.equal((await closed.json()).error, 'circuit_open');
  assert.equal(seen.n, 3);
  now = new Date(now.getTime() + 31 * 60 * 1000);
  const probe = post(input(), 'Bearer e');
  while (seen.n < 4) await new Promise((resolve) => setTimeout(resolve, 5));
  const during = await post(input(), 'Bearer f');
  assert.equal(during.status, 503);
  assert.equal((await during.json()).error, 'circuit_open');
  assert.equal(seen.n, 4);
  release();
  assert.equal((await probe).status, 200);
  assert.equal(seen.n, 4);
});

test('COACH_AI_ENABLED false serves a saved result and starts nothing', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const open = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { coachAiEnabled: true });
  assert.equal((await open.post()).status, 200);
  await new Promise((resolve) => open.s.close(resolve));
  const disabled = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { coachAiEnabled: false });
  const cached = await disabled.post();
  assert.equal(cached.status, 200);
  assert.equal((await cached.json()).reused, true);
  const fresh = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { coachAiEnabled: false });
  const blocked = await fresh.post();
  assert.equal(blocked.status, 403);
  assert.equal((await blocked.json()).error, 'coach_ai_disabled');
  assert.equal(seen.n, 1);
});

test('invalid payload and empty facts do not call the provider', async (t) => {
  const seen = { n: 0 };
  const { post } = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  assert.equal((await post({ ...input(), day: 'not-a-date' })).status, 400);
  const empty = await post({ ...input(), facts: {} });
  assert.equal(empty.status, 200);
  assert.equal((await empty.json()).source, 'fallback');
  assert.equal(seen.n, 0);
});

test('client disconnect does not start a second provider call', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  let release = () => {};
  let entered = () => {};
  const gate = new Promise((resolve) => { release = resolve; });
  const startedGate = new Promise((resolve) => { entered = resolve; });
  const { post, port } = await listen(t, dir, {
    generateSummary: async () => {
      seen.n += 1;
      entered();
      await gate;
      return { result: answer() };
    },
  });
  const controller = new AbortController();
  const hanging = fetch(`http://127.0.0.1:${port}/v1/coach/day-summary`, {
    method: 'POST',
    signal: controller.signal,
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
    body: JSON.stringify(input()),
  }).catch(() => {});
  await startedGate;
  controller.abort();
  release();
  await hanging;
  await new Promise((resolve) => setTimeout(resolve, 30));
  const second = await post();
  assert.equal(seen.n, 1);
  assert.equal(second.status, 200);
  assert.equal((await second.json()).reused, true);
});

test('logs name the provider attempt and omit the health payload', async (t) => {
  const lines = [];
  const original = console.log;
  console.log = (line) => { lines.push(String(line)); original(line); };
  t.after(() => { console.log = original; });
  const seen = { n: 0 };
  const { post } = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer(), usage: { input_tokens: 3, output_tokens: 4 }, providerRequestId: 'prov-9' }; },
  }, { summaryModel: 'log-probe-model' });
  assert.equal((await post()).status, 200);
  assert.equal((await post()).status, 200);
  const events = lines.flatMap((line) => {
    try { return [JSON.parse(line)]; } catch { return []; }
  }).filter((row) => row.endpoint === 'coach_summary' && row.model === 'log-probe-model');
  const names = events.map((row) => row.event);
  for (const required of ['request_received', 'attempt_reserved', 'provider_call_started', 'provider_call_finished', 'result_saved', 'cache_hit']) {
    assert.ok(names.includes(required), required);
  }
  assert.equal(events.filter((row) => row.event === 'provider_call_started').length, 1);
  const started = events.find((row) => row.event === 'provider_call_started');
  assert.equal(typeof started.userHash, 'string');
  assert.equal(started.userHash.length, 16);
  assert.equal(events.some((row) => JSON.stringify(row).includes('Last night')), false);
  assert.equal(events.some((row) => JSON.stringify(row).includes('Bearer')), false);
  assert.equal(seen.n, 1);
});

test('GET reads a saved result and does not generate', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  let release = () => {};
  const gate = new Promise((resolve) => { release = resolve; });
  const { post, port } = await listen(t, dir, {
    generateSummary: async () => {
      seen.n += 1;
      await gate;
      return { result: answer() };
    },
  });
  const hanging = fetch(`http://127.0.0.1:${port}/v1/coach/day-summary`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
    body: JSON.stringify(input()),
  });
  const deadline = Date.now() + 2000;
  while (seen.n < 1 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  const pending = await fetch(`http://127.0.0.1:${port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe/Warsaw`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(pending.status, 202);
  assert.equal(seen.n, 1);
  release();
  assert.equal((await hanging).status, 200);
  const saved = await fetch(`http://127.0.0.1:${port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe/Warsaw`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(saved.status, 200);
  assert.equal((await saved.json()).reused, true);
  assert.equal(seen.n, 1);

  const absent = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  });
  const missing = await fetch(`http://127.0.0.1:${absent.port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe/Warsaw`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(missing.status, 404);
  assert.equal(seen.n, 1);
});

test('a stale lock and inflight free technical slots without a new call for that UID', async (t) => {
  const dir = await directory(t);
  await mkdir(path.join(dir, 'coach-guard'), { recursive: true });
  await writeFile(path.join(dir, 'coach-guard', 'lock'), JSON.stringify({
    pid: 1,
    bootId: 'dead',
    at: new Date(Date.now() - 60_000).toISOString(),
  }));
  const userKey = coachUserHash('Bearer a');
  const dayDir = path.join(dir, 'coach-guard', 'users', userKey, 'days');
  await mkdir(dayDir, { recursive: true });
  await writeFile(path.join(dayDir, '2026-10-12.json'), JSON.stringify({
    state: 'provider_started',
    attemptId: 'stuck-attempt',
    userKey,
    uidHash: userKey.slice(0, 16),
    localDay: '2026-10-12',
    timezone: 'Europe/Warsaw',
    locale: 'ru',
    reservedAt: '2026-10-12T17:00:00.000Z',
    providerStartedAt: '2026-10-12T17:00:00.000Z',
    ownerBootId: 'dead-process',
  }));
  await writeFile(path.join(dir, 'coach-guard', 'users', userKey, 'meta.json'), JSON.stringify({
    lastAttemptAt: Date.parse('2026-10-12T17:00:00.000Z'),
    lastTimezone: 'Europe/Warsaw',
    lastLocalDay: '2026-10-12',
  }));
  await mkdir(path.join(dir, 'coach-guard', 'inflight'), { recursive: true });
  await writeFile(path.join(dir, 'coach-guard', 'inflight', 'stuck-attempt.json'), JSON.stringify({
    attemptId: 'stuck-attempt',
    at: Date.parse('2026-10-12T17:00:00.000Z'),
    bootId: 'dead-process',
    userKey,
    localDay: '2026-10-12',
  }));
  const seen = { n: 0 };
  const { post } = await listen(t, dir, {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { summaryConcurrency: 1 });
  const blocked = await post(input(), 'Bearer a');
  assert.equal(blocked.status, 409);
  assert.equal((await blocked.json()).error, 'attempt_unknown');
  const other = await post(input(), 'Bearer b');
  assert.equal(other.status, 200);
  assert.equal(seen.n, 1);
  const { readFile } = await import('node:fs/promises');
  const meta = JSON.parse(await readFile(path.join(dir, 'coach-guard', 'users', userKey, 'meta.json'), 'utf8'));
  assert.equal(meta.lastAttemptAt, Date.parse('2026-10-12T17:00:00.000Z'));
});

test('a live second process does not generate for another UID', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const generateSummary = async () => { seen.n += 1; return { result: answer() }; };
  const first = await listen(t, dir, { generateSummary });
  const second = await listen(t, dir, { generateSummary });
  assert.equal((await first.post(input(), 'Bearer a')).status, 200);
  const blocked = await second.post(input(), 'Bearer b');
  assert.equal(blocked.status, 503);
  assert.equal((await blocked.json()).error, 'coach_instance_busy');
  assert.equal(seen.n, 1);
  const saved = await fetch(`http://127.0.0.1:${second.port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe/Warsaw`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(saved.status, 200);
  assert.equal(seen.n, 1);
});

test('a stale heartbeat does not transfer ownership while the owner is alive', async (t) => {
  const dir = await directory(t);
  const seen = { n: 0 };
  const generateSummary = async () => { seen.n += 1; return { result: answer() }; };
  const first = await listen(t, dir, { generateSummary });
  await mkdir(path.join(dir, 'coach-guard', 'instances'), { recursive: true });
  await writeFile(path.join(dir, 'coach-guard', 'instances', 'old.json'), JSON.stringify({
    bootId: 'old',
    at: new Date(Date.now() - 120_000).toISOString(),
  }));
  const second = await listen(t, dir, { generateSummary });
  const blocked = await second.post(input(), 'Bearer b');
  assert.equal(blocked.status, 503);
  assert.equal((await blocked.json()).error, 'coach_instance_busy');
  assert.equal((await first.post(input(), 'Bearer a')).status, 200);
  assert.equal(seen.n, 1);
});

test('a continued writer cannot overwrite the process that acquired the lock', async (t) => {
  const dir = await directory(t);
  const limits = {
    minIntervalMs: 20 * 60 * 60 * 1000,
    maxStartsPerUtcDay: 100,
    maxStartsPerMinute: 10,
    maxConcurrent: 2,
    circuitFailures: 3,
    circuitOpenMs: 30 * 60 * 1000,
    attemptGraceMs: 20_000,
    singleInstanceDeclared: true,
  };
  const clock = () => new Date('2026-10-12T18:00:00Z');
  const a = createCoachAttemptStore({ dir, clock, promptVersion: SUMMARY_PROMPT_VERSION, limits });
  t.after(() => a.stop());
  const reserved = await a.decide({
    uid: 'Bearer a', localDay: '2026-10-12', timezone: 'Europe/Warsaw', locale: 'ru', aiEnabled: true,
  });
  assert.equal(reserved.kind, 'owner');
  a.dropProcessLock();
  const b = createCoachAttemptStore({ dir, clock, promptVersion: SUMMARY_PROMPT_VERSION, limits });
  t.after(() => b.stop());
  assert.equal(b.ownsProcessLock(), true);
  const other = await b.decide({
    uid: 'Bearer b', localDay: '2026-10-12', timezone: 'Europe/Warsaw', locale: 'ru', aiEnabled: true,
  });
  assert.equal(other.kind, 'owner');
  const dayFile = path.join(dir, 'coach-guard', 'users', coachUserHash('Bearer b'), 'days', '2026-10-12.json');
  const before = await readFile(dayFile, 'utf8');
  const marker = path.join(dir, 'coach-guard', 'lock');
  await writeFile(marker, 'owner-b');
  const budgetDir = path.join(dir, 'coach-guard', 'budget', 'utc-day', '2026-10-12');
  const budgetBefore = (await readdir(budgetDir)).length;
  await assert.rejects(
    () => a.markProviderStarted(reserved.record),
    (error) => error.code === 'coach_lock_lost',
  );
  await assert.rejects(
    () => a.markFinished(reserved.record, 'completed', { result: answer() }),
    (error) => error.code === 'coach_lock_lost',
  );
  assert.equal(await readFile(dayFile, 'utf8'), before);
  assert.equal(await readFile(marker, 'utf8'), 'owner-b');
  assert.equal((await readdir(budgetDir)).length, budgetBefore);
  const aRecord = JSON.parse(await readFile(
    path.join(dir, 'coach-guard', 'users', coachUserHash('Bearer a'), 'days', '2026-10-12.json'),
    'utf8',
  ));
  assert.equal(aRecord.state, 'reserved');
});

test('providerStarted is durable before the provider call', async (t) => {
  const seen = { n: 0 };
  const { post } = await listen(t, await directory(t), {
    generateSummary: async () => { seen.n += 1; return { result: answer() }; },
  }, { summaryFailDurableWrite: 'provider_started' });
  const res = await post();
  assert.equal(res.status, 503);
  assert.equal((await res.json()).error, 'coach_store_unavailable');
  assert.equal(seen.n, 0);
  const reserved = await post();
  assert.equal(reserved.status, 409);
  assert.equal(seen.n, 0);
});
