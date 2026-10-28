import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import { authenticate } from './auth.mjs';
import {
  calendarContext,
  commitPlannerActivity,
  consoleDocument,
  createPlannerVoiceHandler,
  createPlannerVoiceStore,
  plannerVoiceSettings,
} from './planner-voice.mjs';

const token = 'weekfit-dev-local-token';

function config(overrides = {}) {
  return {
    allowDevAuth: true,
    devToken: token,
    openAIMock: true,
    apiKey: 'sk-server-secret',
    plannerVoiceEnabled: true,
    plannerVoiceAllowedUids: ['local-developer'],
    plannerVoiceModel: 'gpt-realtime-2.1-mini',
    plannerVoiceVoice: 'marin',
    plannerVoiceIdleSeconds: 75,
    plannerVoiceSecretSeconds: 60,
    ...overrides,
  };
}

function tennis(overrides = {}) {
  return {
    idempotencyKey: 'call_tennis_1',
    catalogTitle: 'Tennis',
    date: '2026-10-29',
    startTime: '13:00',
    durationMinutes: 60,
    timeZone: 'Europe/Moscow',
    now: '2026-10-28T09:00:00+03:00',
    planningDay: '2026-10-28',
    existing: [],
    ...overrides,
  };
}

async function start(handler) {
  const server = http.createServer((req, res) => {
    handler(req, res).catch((error) => {
      res.writeHead(500);
      res.end(error.message);
    });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();
  return {
    server,
    url: `http://127.0.0.1:${port}`,
    close: () => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve())),
  };
}

async function request(base, method, path, { body, authorization = `Bearer ${token}` } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(authorization ? { Authorization: authorization } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const json = (response.headers.get('content-type') ?? '').includes('json');
  return { status: response.status, body: json && text ? JSON.parse(text) : text };
}

test('calendar date follows the user zone across midnight', () => {
  const now = new Date('2026-10-28T16:30:00Z');
  const tokyo = calendarContext(now, 'Asia/Tokyo');
  assert.equal(tokyo.today, '2026-10-29');
  assert.equal(tokyo.tomorrow, '2026-10-30');
  assert.equal(tokyo.dayAfterTomorrow, '2026-10-31');
  assert.equal(calendarContext(now, 'Europe/London').today, '2026-10-28');
});

test('model defaults to gpt-realtime-2.1-mini and stays configurable', () => {
  assert.equal(plannerVoiceSettings({}).plannerVoiceModel, 'gpt-realtime-2.1-mini');
  assert.equal(plannerVoiceSettings({}).plannerVoiceEnabled, false);
  assert.equal(
    plannerVoiceSettings({ PLANNER_VOICE_REALTIME_MODEL: 'gpt-realtime-2.1' }).plannerVoiceModel,
    'gpt-realtime-2.1',
  );
  assert.throws(() => plannerVoiceSettings({ PLANNER_VOICE_REALTIME_MODEL: 'gpt-4o' }));
});

test('full command commits tennis and a missing time does not', () => {
  const store = createPlannerVoiceStore();
  const saved = commitPlannerActivity(store, 'local-developer', tennis());
  assert.equal(saved.status, 200);
  assert.equal(saved.body.saved, true);
  assert.equal(saved.body.activity.start, '2026-10-29T10:00:00.000Z');
  assert.equal(saved.body.activity.localEnd, '2026-10-29T14:00');
  assert.equal(saved.body.speak, 'Добавил теннис на завтра, с 13 до 14.');

  const missing = commitPlannerActivity(store, 'local-developer', tennis({
    idempotencyKey: 'call_tennis_2',
    startTime: '',
    durationMinutes: 0,
  }));
  assert.equal(missing.status, 422);
  assert.equal(missing.body.error, 'start_time_required');
  assert.equal(missing.body.saved, false);
  assert.equal(store.size(), 1);
});

test('omitted duration uses the planner default', () => {
  const store = createPlannerVoiceStore();
  const saved = commitPlannerActivity(store, 'local-developer', tennis({
    idempotencyKey: 'call_default_duration',
    durationMinutes: 0,
  }));
  assert.equal(saved.body.activity.durationMinutes, 45);
  assert.equal(saved.body.activity.durationSource, 'default');
  assert.equal(saved.body.activity.localEnd, '2026-10-29T13:45');
});

test('relative evening in Tokyo crosses midnight', () => {
  const store = createPlannerVoiceStore();
  const saved = commitPlannerActivity(store, 'local-developer', tennis({
    idempotencyKey: 'call_tokyo_night',
    date: '2026-10-31',
    startTime: '23:30',
    durationMinutes: 90,
    timeZone: 'Asia/Tokyo',
    now: '2026-10-29T01:30:00+09:00',
    existing: [{
      start: '2026-10-31T15:15:00.000Z',
      end: '2026-10-31T15:45:00.000Z',
      blocks: false,
    }],
  }));
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal(saved.body.activity.localStart, '2026-10-31T23:30');
  assert.equal(saved.body.activity.localEnd, '2026-11-01T01:00');
  assert.equal(saved.body.speak, 'Добавил теннис на послезавтра, с 23:30 до 1.');

  const blocked = commitPlannerActivity(store, 'local-developer', tennis({
    idempotencyKey: 'call_tokyo_blocked',
    date: '2026-10-31',
    startTime: '23:30',
    durationMinutes: 90,
    timeZone: 'Asia/Tokyo',
    now: '2026-10-29T01:30:00+09:00',
    existing: [{
      start: '2026-10-31T15:15:00.000Z',
      end: '2026-10-31T15:45:00.000Z',
      blocks: true,
    }],
  }));
  assert.equal(blocked.status, 409);
  assert.equal(blocked.body.saved, false);
  assert.equal(store.size(), 1);
});

test('the same call does not create a second activity', () => {
  const store = createPlannerVoiceStore();
  const first = commitPlannerActivity(store, 'local-developer', tennis());
  const second = commitPlannerActivity(store, 'local-developer', tennis());
  assert.equal(second.body.duplicate, true);
  assert.equal(second.body.activity.start, first.body.activity.start);
  assert.equal(store.size(), 1);
  assert.equal(store.get('devuid:other', 'call_tennis_1'), null);
});

test('empty allowlist denies every account', async () => {
  const settings = plannerVoiceSettings({
    PLANNER_VOICE_ENABLED: '1',
    PLANNER_VOICE_ALLOWED_UIDS: ' , ',
  });
  assert.deepEqual(settings.plannerVoiceAllowedUids, []);
  const handler = createPlannerVoiceHandler(config({
    plannerVoiceEnabled: true,
    plannerVoiceAllowedUids: settings.plannerVoiceAllowedUids,
  }), { authenticate, log: () => {} });
  const server = await start(handler);
  try {
    const owner = await request(server.url, 'GET', '/v1/planner-voice/access');
    const other = await request(server.url, 'GET', '/v1/planner-voice/access', {
      authorization: `Bearer ${token}.other`,
    });
    assert.equal(owner.body.enabled, false);
    assert.equal(owner.body.accountId, 'local-developer');
    assert.equal(other.body.enabled, false);
    assert.equal(other.body.accountId, 'devuid:other');
    const session = await request(server.url, 'POST', '/v1/planner-voice/session', {
      body: { timeZone: 'Europe/Moscow', now: '2026-10-28T09:00:00+03:00' },
    });
    const activity = await request(server.url, 'POST', '/v1/planner-voice/activities', { body: tennis() });
    assert.equal(session.status, 403);
    assert.equal(activity.status, 403);
    assert.equal(session.body.saved, false);
    assert.equal(activity.body.saved, false);
  } finally {
    await server.close();
  }
});

test('routes enforce the allowlist and never return the server key', async () => {
  let captured = null;
  const store = createPlannerVoiceStore();
  const handler = createPlannerVoiceHandler(config({ openAIMock: false }), {
    authenticate,
    store,
    log: () => {},
    fetch: async (url, init) => {
      captured = { url, init };
      return new Response(JSON.stringify({ value: 'ek_ephemeral', expires_at: 123 }), { status: 200 });
    },
  });
  const server = await start(handler);
  try {
    const denied = await request(server.url, 'GET', '/v1/planner-voice/access', {
      authorization: `Bearer ${token}.other`,
    });
    assert.equal(denied.status, 200);
    assert.equal(denied.body.enabled, false);
    assert.equal(denied.body.accountId, 'devuid:other');

    const sessionDenied = await request(server.url, 'POST', '/v1/planner-voice/session', {
      authorization: `Bearer ${token}.other`,
      body: { timeZone: 'Europe/Moscow', now: '2026-10-28T09:00:00+03:00' },
    });
    assert.equal(sessionDenied.status, 403);
    assert.equal(sessionDenied.body.saved, false);
    assert.equal(captured, null);

    const session = await request(server.url, 'POST', '/v1/planner-voice/session', {
      body: {
        timeZone: 'Asia/Tokyo',
        now: '2026-10-28T16:30:00Z',
        planningDay: '2026-10-29',
      },
    });
    assert.equal(session.status, 200);
    assert.equal(session.body.value, 'ek_ephemeral');
    assert.equal(session.body.model, 'gpt-realtime-2.1-mini');
    assert.equal(JSON.stringify(session.body).includes('sk-server-secret'), false);
    const sent = JSON.parse(captured.init.body);
    assert.equal(captured.url, 'https://api.openai.com/v1/realtime/client_secrets');
    assert.equal(captured.init.headers.Authorization, 'Bearer sk-server-secret');
    assert.equal(sent.session.model, 'gpt-realtime-2.1-mini');
    assert.equal(sent.session.audio.input.transcription, undefined);
    assert.deepEqual(sent.session.output_modalities, ['audio']);
    assert.equal(sent.session.tools[0].name, 'create_activity');
    assert.equal(sent.session.audio.input.turn_detection.interrupt_response, true);
    assert.match(sent.session.instructions, /2026-10-29/);
    assert.match(sent.session.instructions, /Послезавтра 2026-10-31/);

    const created = await request(server.url, 'POST', '/v1/planner-voice/activities', { body: tennis() });
    assert.equal(created.body.saved, true);
    const replay = await request(server.url, 'GET', '/v1/planner-voice/activities?idempotencyKey=call_tennis_1');
    assert.equal(replay.body.duplicate, true);
    const other = await request(server.url, 'GET', '/v1/planner-voice/activities?idempotencyKey=call_tennis_1', {
      authorization: `Bearer ${token}.other`,
    });
    assert.equal(other.status, 403);

    const page = await request(server.url, 'GET', '/v1/planner-voice/console');
    assert.equal(page.status, 200);
  } finally {
    await server.close();
  }
});

test('console releases the microphone and does not embed a server key', () => {
  const html = consoleDocument();
  assert.match(html, /track\.stop\(\)/);
  assert.match(html, /pc\.close\(\)/);
  assert.match(html, /function_call_output/);
  assert.match(html, /getUserMedia/);
  assert.equal(html.includes('OPENAI_API_KEY'), false);
  assert.equal(html.includes('sk-'), false);
  assert.equal(html.includes('MediaRecorder'), false);
  assert.equal(html.includes("type: 'transcript'"), false);
});

test('mock session does not call OpenAI', async () => {
  let called = false;
  const handler = createPlannerVoiceHandler(config(), {
    authenticate,
    fetch: async () => {
      called = true;
      throw new Error('network');
    },
    log: () => {},
  });
  const server = await start(handler);
  try {
    const session = await request(server.url, 'POST', '/v1/planner-voice/session', {
      body: { timeZone: 'Europe/Moscow', now: '2026-10-28T09:00:00+03:00' },
    });
    assert.equal(session.status, 200);
    assert.equal(session.body.value, 'ek_mock');
    assert.equal(called, false);
    const usage = await request(server.url, 'POST', '/v1/planner-voice/usage', {
      body: { responseId: 'resp_1', inputTokens: 10, outputTokens: 4 },
    });
    assert.equal(usage.status, 204);
  } finally {
    await server.close();
  }
});
