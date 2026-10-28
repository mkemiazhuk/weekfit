import { createHash } from 'node:crypto';
import { ServiceError } from './recognition.mjs';
import {
  askActivityLine,
  askTimeLine,
  conflictLine,
  confirmationLine,
  greetingLine,
  plannerVoiceLanguage,
  plannerVoicePhrases,
  saveFailedLine,
  spokenActivityName,
} from './planner-voice-copy.mjs';

const DEFAULT_MODEL = 'gpt-realtime-2.1-mini';
const VOICES = new Set(['marin', 'cedar', 'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', 'verse']);

/** Names, defaults, and spoken forms match the on-device planner catalog. Meals stay out. */
const CATALOG = [
  ['Cycling', 'Workout', 45],
  ['Running', 'Workout', 45],
  ['Swimming', 'Workout', 45],
  ['Hiking', 'Workout', 45],
  ['Snowboarding', 'Workout', 45],
  ['Alpine Skiing', 'Workout', 45],
  ['Upper Body', 'Workout', 45],
  ['Core', 'Workout', 45],
  ['Lower Body', 'Workout', 45],
  ['Full Body', 'Workout', 45],
  ['Tennis', 'Workout', 45],
  ['Padel', 'Workout', 45],
  ['Squash', 'Workout', 45],
  ['High Intensity Interval Training', 'Workout', 45],
  ['Stretching', 'Recovery', 20],
  ['Walk', 'Recovery', 20],
  ['Sauna', 'Recovery', 20],
  ['Yoga', 'Recovery', 20],
  ['Breathing', 'Recovery', 20],
  ['Drink Water', 'Habit', 15],
  ['Sleep Routine', 'Habit', 15],
  ['No Screens', 'Habit', 15],
  ['Morning Routine', 'Habit', 15],
].map(([catalogTitle, plannerTypeTitle, defaultDurationMinutes]) => ({
  catalogTitle,
  plannerTypeTitle,
  defaultDurationMinutes,
  blocks: true,
}));

const BY_TITLE = new Map(CATALOG.map(item => [item.catalogTitle, item]));

export function plannerVoiceSettings(env = {}) {
  const model = (env.PLANNER_VOICE_REALTIME_MODEL ?? DEFAULT_MODEL).trim();
  if (!/^gpt-realtime(?:-[a-z0-9.]+)*$/.test(model)) {
    throw Error('Invalid PLANNER_VOICE_REALTIME_MODEL');
  }
  const voice = (env.PLANNER_VOICE_VOICE ?? 'marin').trim();
  if (!VOICES.has(voice)) throw Error('Invalid PLANNER_VOICE_VOICE');
  const integer = (key, fallback, min, max) => {
    if (env[key] == null || env[key] === '') return fallback;
    const n = Number(env[key]);
    if (!Number.isInteger(n) || n < min || n > max) throw Error(`Invalid ${key}`);
    return n;
  };
  const allowed = String(env.PLANNER_VOICE_ALLOWED_UIDS ?? '')
    .split(',')
    .map(item => item.trim())
    .filter(Boolean)
    .slice(0, 20);
  return {
    plannerVoiceEnabled: env.PLANNER_VOICE_ENABLED === '1',
    plannerVoiceAllowedUids: allowed,
    plannerVoiceModel: model,
    plannerVoiceVoice: voice,
    plannerVoiceIdleSeconds: integer('PLANNER_VOICE_IDLE_SECONDS', 75, 20, 180),
    plannerVoiceSecretSeconds: integer('PLANNER_VOICE_SECRET_SECONDS', 60, 10, 600),
  };
}

export function createPlannerVoiceStore() {
  const records = new Map();
  const keyFor = (uid, idempotencyKey) => `${uid}\n${idempotencyKey}`;
  return {
    get(uid, idempotencyKey) {
      return records.get(keyFor(uid, idempotencyKey)) ?? null;
    },
    putIfAbsent(uid, idempotencyKey, record) {
      const key = keyFor(uid, idempotencyKey);
      const existing = records.get(key);
      if (existing) return existing;
      records.set(key, record);
      return record;
    },
    size() {
      return records.size;
    },
  };
}

export function calendarContext(now, timeZone) {
  const today = isoDate(now, timeZone);
  return {
    timeZone,
    today,
    tomorrow: shiftDate(today, 1),
    dayAfterTomorrow: shiftDate(today, 2),
  };
}

export function commitPlannerActivity(store, uid, body, now = new Date()) {
  const language = plannerVoiceLanguage(body?.language);
  const key = typeof body?.idempotencyKey === 'string' ? body.idempotencyKey.trim() : '';
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(key)) {
    return reject(400, 'invalid_idempotency_key');
  }
  const existing = store.get(uid, key);
  if (existing) {
    return { status: 200, body: { ...existing, duplicate: true } };
  }

  const item = BY_TITLE.get(body?.catalogTitle);
  if (!item) return reject(422, 'unknown_activity', askActivityLine(language));

  const timeZone = typeof body.timeZone === 'string' ? body.timeZone : '';
  if (!validTimeZone(timeZone)) return reject(422, 'invalid_timezone');

  const date = body.date == null || body.date === '' ? body.planningDay : body.date;
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !validDate(date)) {
    return reject(422, 'date_required');
  }
  const startTime = typeof body.startTime === 'string' ? body.startTime.trim() : '';
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(startTime)) {
    return reject(422, 'start_time_required', askTimeLine(language));
  }

  let duration = body.durationMinutes;
  let durationSource = 'spoken';
  if (duration == null || duration === 0 || duration === '') {
    duration = item.defaultDurationMinutes;
    durationSource = 'default';
  }
  if (!Number.isInteger(duration) || duration < 1 || duration > 360) {
    return reject(422, 'invalid_duration');
  }

  const reference = body.now ? new Date(body.now) : now;
  if (Number.isNaN(reference.getTime())) return reject(422, 'invalid_now');

  const start = zonedTime(date, startTime, timeZone);
  const end = new Date(start.getTime() + duration * 60_000);
  const conflictWindowEnd = new Date(start.getTime() + Math.max(duration, 15) * 60_000);
  if (item.blocks && conflicts(start, conflictWindowEnd, body.existing)) {
    return reject(409, 'time_conflict', conflictLine(language));
  }

  const activity = {
    catalogTitle: item.catalogTitle,
    plannerTypeTitle: item.plannerTypeTitle,
    durationMinutes: duration,
    durationSource,
    timeZone,
    start: start.toISOString(),
    end: end.toISOString(),
    localDate: date,
    localStart: `${date}T${startTime}`,
    localEnd: localStamp(end, timeZone),
    blocks: item.blocks,
    idempotencyKey: key,
  };
  const days = calendarContext(reference, timeZone);
  const saved = {
    ok: true,
    saved: true,
    duplicate: false,
    activity,
    speak: confirmationLine(item.catalogTitle, activity, days, language),
  };
  store.putIfAbsent(uid, key, saved);
  return { status: 200, body: saved };
}

export function createPlannerVoiceHandler(config, dependencies = {}) {
  const authenticate = dependencies.authenticate;
  const fetcher = dependencies.fetch ?? globalThis.fetch;
  const store = dependencies.store ?? createPlannerVoiceStore();
  const log = dependencies.log ?? (entry => {
    console.info(JSON.stringify(entry));
  });

  return async function plannerVoice(req, res) {
    const path = (req.url ?? '').split('?')[0];
    if (!path.startsWith('/v1/planner-voice/')) return false;

    try {
      if (req.method === 'GET' && path === '/v1/planner-voice/console') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        sendHtml(res, consoleDocument());
        return true;
      }

      if (req.method === 'GET' && path === '/v1/planner-voice/access') {
        const uid = await requireUser(authenticate, req, config);
        const enabled = isAllowed(config, uid);
        sendJson(res, 200, { enabled, accountId: uid });
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/session') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        const secret = await mintSecret(config, fetcher, uid, payload, log);
        sendJson(res, 200, secret);
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/activities') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        const result = commitPlannerActivity(store, uid, payload);
        if (!result.body.saved) {
          log({
            event: 'planner_voice_save_rejected',
            account: accountHash(uid),
            error: result.body.error,
          });
        }
        sendJson(res, result.status, result.body);
        return true;
      }

      if (req.method === 'GET' && path === '/v1/planner-voice/activities') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const key = new URL(req.url, 'http://127.0.0.1').searchParams.get('idempotencyKey') ?? '';
        const found = store.get(uid, key);
        if (!found) {
          sendJson(res, 404, { error: 'not_found', saved: false });
          return true;
        }
        sendJson(res, 200, { ...found, duplicate: true });
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/usage') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        log({
          event: 'planner_voice_usage',
          account: accountHash(uid),
          model: config.plannerVoiceModel ?? DEFAULT_MODEL,
          responseId: typeof payload.responseId === 'string' ? payload.responseId.slice(0, 80) : null,
          inputTokens: numberOrNull(payload.inputTokens),
          outputTokens: numberOrNull(payload.outputTokens),
        });
        sendJson(res, 204, {});
        return true;
      }

      sendJson(res, 404, { error: 'not_found', saved: false });
    } catch (error) {
      const status = Number.isInteger(error.status) ? error.status : 500;
      const code = typeof error.code === 'string' ? error.code : 'planner_voice_failed';
      if (status >= 500) {
        log({ event: 'planner_voice_error', error: code });
      }
      sendJson(res, status, { error: code, saved: false });
    }
    return true;
  };
}

export function consoleDocument() {
  return `<!doctype html>
<html lang="ru">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WeekFit</title>
<body>
<script>
(() => {
  let pc = null;
  let local = null;
  let remoteAudio = null;
  let channel = null;
  let idle = null;
  let idleMs = 75000;
  let callNumber = 0;
  let muted = false;
  let hangup = false;
  const pending = new Map();

  const post = (payload) => {
    const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plannerVoice;
    if (handler) handler.postMessage(payload);
  };

  const armIdle = () => {
    if (idle) clearTimeout(idle);
    idle = setTimeout(() => stop('idle'), idleMs);
  };

  const release = () => {
    if (idle) clearTimeout(idle);
    idle = null;
    if (local) {
      local.getTracks().forEach((track) => track.stop());
      local = null;
    }
    if (remoteAudio) {
      remoteAudio.srcObject = null;
      remoteAudio.remove();
      remoteAudio = null;
    }
    if (channel) {
      try { channel.close(); } catch (e) {}
      channel = null;
    }
    if (pc) {
      try { pc.close(); } catch (e) {}
      pc = null;
    }
  };

  function stop(reason) {
    callNumber++;
    release();
    post({ type: 'state', value: 'ended', reason: reason || 'user' });
  }

  function sendToolOutput(callId, output) {
    if (!channel || channel.readyState !== 'open') return;
    channel.send(JSON.stringify({
      type: 'conversation.item.create',
      item: { type: 'function_call_output', call_id: callId, output: JSON.stringify(output) },
    }));
    channel.send(JSON.stringify({ type: 'response.create' }));
  }

  window.weekfit = {
    stop: () => stop('user'),
    setMuted: (value) => {
      muted = Boolean(value);
      if (local) local.getAudioTracks().forEach((track) => { track.enabled = !muted; });
    },
    toolResult: (callId, output) => {
      const resolve = pending.get(callId);
      pending.delete(callId);
      if (resolve) resolve(output);
      else sendToolOutput(callId, output);
    },
    start: async (options) => {
      let thisCall = 0;
      try {
        release();
        thisCall = ++callNumber;
        idleMs = Math.max(20000, Number(options.idleSeconds || 75) * 1000);
        post({ type: 'state', value: 'connecting' });
        pc = new RTCPeerConnection();
        remoteAudio = document.createElement('audio');
        remoteAudio.autoplay = true;
        remoteAudio.setAttribute('playsinline', '');
        document.body.appendChild(remoteAudio);
        pc.ontrack = (event) => { if (remoteAudio) remoteAudio.srcObject = event.streams[0]; };
        const microphone = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
        if (thisCall !== callNumber || !pc) { microphone.getTracks().forEach((track) => track.stop()); return; }
        local = microphone;
        // Don't send locally played ringback audio to the assistant.
        local.getAudioTracks().forEach((track) => { track.enabled = false; });
        local.getTracks().forEach((track) => pc.addTrack(track, local));
        channel = pc.createDataChannel('oai-events');
        channel.onmessage = (event) => onEvent(event.data);
        channel.onopen = () => {
          if (thisCall !== callNumber || !local || !channel) return;
          post({ type: 'state', value: 'connected' });
          // Native ringback stops on 'connected' before the microphone opens.
          setTimeout(() => {
            if (thisCall !== callNumber || !local || !channel || channel.readyState !== 'open') return;
            local.getAudioTracks().forEach((track) => { track.enabled = !muted; });
            channel.send(JSON.stringify({ type: 'response.create' }));
            armIdle();
          }, 180);
        };
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        const response = await fetch('https://api.openai.com/v1/realtime/calls', {
          method: 'POST',
          body: offer.sdp,
          headers: {
            Authorization: 'Bearer ' + options.ephemeralKey,
            'Content-Type': 'application/sdp',
          },
        });
        if (!response.ok) throw new Error('session_connect_failed');
        if (thisCall !== callNumber) return;
        await pc.setRemoteDescription({ type: 'answer', sdp: await response.text() });
      } catch (error) {
        if (thisCall !== callNumber) return;
        release();
        post({ type: 'state', value: 'failed', message: 'session_connect_failed' });
      }
    },
  };

  function onEvent(raw) {
    armIdle();
    let event;
    try { event = JSON.parse(raw); } catch (e) { return; }
    const type = event.type || '';
    if (type === 'input_audio_buffer.speech_started') {
      post({ type: 'state', value: 'listening' });
      return;
    }
    if (type === 'response.created') {
      post({ type: 'state', value: 'speaking' });
      return;
    }
    if (type === 'response.done') {
      const usage = event.response && event.response.usage;
      if (usage) {
        post({
          type: 'usage',
          responseId: event.response.id || '',
          inputTokens: usage.input_tokens || usage.input_token_count || 0,
          outputTokens: usage.output_tokens || usage.output_token_count || 0,
        });
      }
      if (hangup) {
        setTimeout(() => stop('goodbye'), 700);
        return;
      }
      post({ type: 'state', value: 'listening' });
      return;
    }
    if (type === 'response.function_call_arguments.done' && event.name === 'end_call') {
      hangup = true;
      return;
    }
    if (type === 'response.function_call_arguments.done' && event.name === 'create_activity') {
      post({ type: 'state', value: 'acting' });
      post({ type: 'tool', callId: event.call_id, name: event.name, arguments: event.arguments });
      return;
    }
    if (type === 'error') {
      post({ type: 'state', value: 'failed', message: 'realtime_error' });
    }
  }
})();
</script>
</body>
</html>`;
}

function reject(status, error, speak) {
  const body = { ok: false, saved: false, error };
  if (speak) body.speak = speak;
  return { status, body };
}

function conflicts(start, end, existing) {
  if (!Array.isArray(existing)) return false;
  return existing.some(item => {
    if (!item || item.blocks === false) return false;
    const otherStart = new Date(item.start);
    const otherEnd = new Date(item.end);
    if (Number.isNaN(otherStart.getTime()) || Number.isNaN(otherEnd.getTime())) return false;
    return start < otherEnd && end > otherStart;
  });
}

function isoDate(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const value = (type) => parts.find(part => part.type === type).value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}

function shiftDate(iso, days) {
  const [year, month, day] = iso.split('-').map(Number);
  const utc = new Date(Date.UTC(year, month - 1, day));
  utc.setUTCDate(utc.getUTCDate() + days);
  return utc.toISOString().slice(0, 10);
}

function validDate(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  const utc = new Date(Date.UTC(year, month - 1, day));
  return utc.getUTCFullYear() === year && utc.getUTCMonth() === month - 1 && utc.getUTCDate() === day;
}

function validTimeZone(timeZone) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
    return true;
  } catch {
    return false;
  }
}

function zonedTime(date, time, timeZone) {
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  const guess = Date.UTC(year, month - 1, day, hour, minute, 0);
  const offset = timeZoneOffset(new Date(guess), timeZone);
  const instant = new Date(guess - offset);
  const corrected = timeZoneOffset(instant, timeZone);
  return new Date(guess - corrected);
}

function timeZoneOffset(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(date);
  const value = (type) => parts.find(part => part.type === type).value;
  const hour = value('hour') === '24' ? 0 : Number(value('hour'));
  const asUTC = Date.UTC(
    Number(value('year')),
    Number(value('month')) - 1,
    Number(value('day')),
    hour,
    Number(value('minute')),
    Number(value('second')),
  );
  return asUTC - date.getTime();
}

function localStamp(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).formatToParts(date);
  const value = (type) => parts.find(part => part.type === type).value;
  const hour = value('hour') === '24' ? '00' : value('hour');
  return `${value('year')}-${value('month')}-${value('day')}T${hour}:${value('minute')}`;
}

async function mintSecret(config, fetcher, uid, payload, log) {
  if (!config.plannerVoiceModel) throw new ServiceError('planner_voice_unconfigured', 503);
  const now = payload?.now ? new Date(payload.now) : new Date();
  if (Number.isNaN(now.getTime())) throw new ServiceError('invalid_now', 422);
  const timeZone = payload?.timeZone;
  if (!validTimeZone(timeZone)) throw new ServiceError('invalid_timezone', 422);
  const days = calendarContext(now, timeZone);
  const planningDay = typeof payload?.planningDay === 'string' && validDate(payload.planningDay)
    ? payload.planningDay
    : days.today;
  const givenName = typeof payload?.givenName === 'string' ? payload.givenName.trim().normalize('NFC') : '';
  const safeName = /^[\p{L}\p{M}][\p{L}\p{M}'’-]{0,39}$/u.test(givenName) ? givenName : '';
  const language = plannerVoiceLanguage(payload?.language);
  const session = {
    type: 'realtime',
    model: config.plannerVoiceModel,
    instructions: instructions(days, planningDay, safeName, language),
    tools: [createActivityTool(), endCallTool()],
    tool_choice: 'auto',
    // Budget covers audio and tool calls, not just the short spoken transcript.
    max_output_tokens: 2048,
    output_modalities: ['audio'],
    audio: {
      input: {
        turn_detection: {
          type: 'server_vad',
          create_response: true,
          interrupt_response: true,
          prefix_padding_ms: 300,
          silence_duration_ms: 500,
        },
      },
      output: { voice: config.plannerVoiceVoice || 'marin' },
    },
  };
  if (config.openAIMock) {
    log({ event: 'planner_voice_session', account: accountHash(uid), model: session.model, mock: true });
    return {
      value: 'ek_mock',
      expiresAt: null,
      model: session.model,
      idleSeconds: config.plannerVoiceIdleSeconds,
      voice: session.audio.output.voice,
    };
  }
  if (!config.apiKey) throw new ServiceError('planner_voice_unconfigured', 503);
  const response = await fetcher('https://api.openai.com/v1/realtime/client_secrets', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      'Content-Type': 'application/json',
      'OpenAI-Safety-Identifier': accountHash(uid),
    },
    body: JSON.stringify({
      expires_after: { anchor: 'created_at', seconds: config.plannerVoiceSecretSeconds },
      session,
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || typeof data.value !== 'string' || !data.value.startsWith('ek_')) {
    log({
      event: 'planner_voice_session_failed',
      account: accountHash(uid),
      status: response.status,
    });
    throw new ServiceError('planner_voice_session_failed', 502);
  }
  log({ event: 'planner_voice_session', account: accountHash(uid), model: session.model, mock: false });
  return {
    value: data.value,
    expiresAt: data.expires_at ?? null,
    model: session.model,
    idleSeconds: config.plannerVoiceIdleSeconds,
    voice: session.audio.output.voice,
  };
}

function instructions(days, planningDay, givenName, language) {
  const phrases = plannerVoicePhrases(language);
  const catalog = CATALOG.map(item => (
    `${item.catalogTitle} = ${spokenActivityName(item.catalogTitle, language)} (${item.defaultDurationMinutes} min)`
  )).join('; ');
  const nameLine = givenName
    ? `Say the name ${givenName} exactly as written, with natural ${phrases.englishName} pronunciation. Do not translate, spell, or replace the name.`
    : 'No name was provided. Do not invent one.';
  return [
    `You are the WeekFit voice planner. Speak only in ${phrases.englishName}.`,
    `Use natural ${phrases.englishName} pronunciation and a normal pace. Say one short sentence, then stop. Never repeat yourself, the user's words, or a question you already asked. Do not ask what else to plan.`,
    nameLine,
    `The app language is ${language}. Do not choose the language from the device or the time zone.`,
    `Your first words must be exactly: ${greetingLine(language, givenName)} Do not repeat that greeting later.`,
    `Today is ${days.today}. Tomorrow is ${days.tomorrow}. The day after tomorrow is ${days.dayAfterTomorrow}. Time zone: ${days.timeZone}. Calculate dates and times in this time zone.`,
    `The open plan day is ${planningDay}. If the person does not name a day, pass date as an empty string.`,
    'One hour means 60 minutes. An hour and a half means 90. One in the afternoon means 13:00. One at night means 01:00. Midnight means 00:00.',
    `Create only a catalog activity. Pass the English catalogTitle, and say the activity in ${phrases.englishName}. Catalog: ${catalog}.`,
    'Call create_activity once the activity and start time are known. If the person did not say a duration, pass durationMinutes 0. Do not ask for an extra confirmation when the data is enough.',
    `If the start time is missing, ask exactly "${phrases.askTime}" and do not call the tool.`,
    'When the tool returns a speak field, say that field once and stop. Do not paraphrase it and do not add a question. Say the activity was added only when ok is true and saved is true.',
    `If the tool returns no speak field, say exactly: ${saveFailedLine(language)}`,
    `When the person is finished and is not naming another activity or time, say exactly "${phrases.goodbye}" and call end_call in that same response. Do not wait for a hang-up button. Treat these as done: ${phrases.closing}.${language === 'ru' ? '' : ' Also treat Russian «всё», «всё, спасибо», «спасибо», «до свидания», and «пока» as done.'}`,
  ].join('\n');
}

function createActivityTool() {
  return {
    type: 'function',
    name: 'create_activity',
    description: 'Create one activity in the current plan. Do not confirm success before the tool result.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        catalogTitle: { type: 'string', enum: CATALOG.map(item => item.catalogTitle) },
        date: { type: 'string', description: 'YYYY-MM-DD in the user time zone, or an empty string when the day was not spoken.' },
        startTime: { type: 'string', description: 'HH:mm, 24-hour. Empty string when the time was not spoken.' },
        durationMinutes: { type: 'integer', description: 'Minutes. 0 when the person did not say a duration.' },
      },
      required: ['catalogTitle', 'date', 'startTime', 'durationMinutes'],
    },
  };
}

function endCallTool() {
  return {
    type: 'function',
    name: 'end_call',
    description: 'Hang up after a short goodbye when the person is done, says thanks, or says goodbye. Do not use this while they are still planning.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {},
      required: [],
    },
  };
}

function isAllowed(config, uid) {
  return config.plannerVoiceEnabled === true
    && Array.isArray(config.plannerVoiceAllowedUids)
    && config.plannerVoiceAllowedUids.includes(uid);
}

function assertAllowed(config, uid) {
  if (!isAllowed(config, uid)) throw new ServiceError('planner_voice_forbidden', 403);
}

async function requireUser(authenticate, req, config) {
  if (!authenticate) throw new ServiceError('unauthorized', 401);
  return authenticate(req.headers.authorization, config);
}

function accountHash(uid) {
  return createHash('sha256').update(String(uid)).digest('hex').slice(0, 16);
}

function numberOrNull(value) {
  return Number.isFinite(value) ? value : null;
}

function sendJson(res, status, body) {
  const payload = status === 204 ? '' : JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(payload);
}

function sendHtml(res, html) {
  res.writeHead(200, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(html);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 32_768) {
        reject(new ServiceError('request_too_large', 413));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!chunks.length) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new ServiceError('invalid_json', 400));
      }
    });
    req.on('error', reject);
  });
}
