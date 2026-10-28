import { createHash } from 'node:crypto';
import { ServiceError } from './recognition.mjs';

const DEFAULT_MODEL = 'gpt-realtime-2.1-mini';
const VOICES = new Set(['marin', 'cedar', 'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', 'verse']);

/** Names, defaults, and spoken forms match the on-device planner catalog. Meals stay out. */
const CATALOG = [
  ['Cycling', 'Workout', 45, 'велосипед'],
  ['Running', 'Workout', 45, 'бег'],
  ['Swimming', 'Workout', 45, 'плавание'],
  ['Hiking', 'Workout', 45, 'хайкинг'],
  ['Snowboarding', 'Workout', 45, 'сноуборд'],
  ['Alpine Skiing', 'Workout', 45, 'лыжи'],
  ['Upper Body', 'Workout', 45, 'верх тела'],
  ['Core', 'Workout', 45, 'кор'],
  ['Lower Body', 'Workout', 45, 'низ тела'],
  ['Full Body', 'Workout', 45, 'все тело'],
  ['Tennis', 'Workout', 45, 'теннис'],
  ['Padel', 'Workout', 45, 'падел'],
  ['Squash', 'Workout', 45, 'сквош'],
  ['High Intensity Interval Training', 'Workout', 45, 'интервальную'],
  ['Stretching', 'Recovery', 20, 'растяжку'],
  ['Walk', 'Recovery', 20, 'прогулку'],
  ['Sauna', 'Recovery', 20, 'сауну'],
  ['Yoga', 'Recovery', 20, 'йогу'],
  ['Breathing', 'Recovery', 20, 'дыхание'],
  ['Drink Water', 'Habit', 15, 'воду'],
  ['Sleep Routine', 'Habit', 15, 'сон'],
  ['No Screens', 'Habit', 15, 'без экрана'],
  ['Morning Routine', 'Habit', 15, 'утреннюю рутину'],
].map(([catalogTitle, plannerTypeTitle, defaultDurationMinutes, spoken]) => ({
  catalogTitle,
  plannerTypeTitle,
  defaultDurationMinutes,
  spoken,
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
  const key = typeof body?.idempotencyKey === 'string' ? body.idempotencyKey.trim() : '';
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(key)) {
    return reject(400, 'invalid_idempotency_key');
  }
  const existing = store.get(uid, key);
  if (existing) {
    return { status: 200, body: { ...existing, duplicate: true } };
  }

  const item = BY_TITLE.get(body?.catalogTitle);
  if (!item) return reject(422, 'unknown_activity');

  const timeZone = typeof body.timeZone === 'string' ? body.timeZone : '';
  if (!validTimeZone(timeZone)) return reject(422, 'invalid_timezone');

  const date = body.date == null || body.date === '' ? body.planningDay : body.date;
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !validDate(date)) {
    return reject(422, 'date_required');
  }
  const startTime = typeof body.startTime === 'string' ? body.startTime.trim() : '';
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(startTime)) {
    return reject(422, 'start_time_required');
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
    return reject(409, 'time_conflict');
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
    speak: speakLine(item.spoken, activity, days),
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
      post({ type: 'state', value: 'listening' });
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

function reject(status, error) {
  return { status, body: { ok: false, saved: false, error } };
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

function speakLine(spoken, activity, days) {
  const day = activity.localDate === days.today
    ? 'сегодня'
    : activity.localDate === days.tomorrow
      ? 'завтра'
      : activity.localDate === days.dayAfterTomorrow
        ? 'послезавтра'
        : activity.localDate;
  const start = clockWords(activity.localStart);
  const end = clockWords(activity.localEnd);
  return `Добавил ${spoken} на ${day}, с ${start} до ${end}.`;
}

function clockWords(stamp) {
  const time = stamp.slice(11, 16);
  const [hour, minute] = time.split(':').map(Number);
  return minute === 0 ? String(hour) : `${hour}:${String(minute).padStart(2, '0')}`;
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
  const session = {
    type: 'realtime',
    model: config.plannerVoiceModel,
    instructions: instructions(days, planningDay, safeName),
    tools: [createActivityTool()],
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

function instructions(days, planningDay, givenName) {
  const catalog = CATALOG.map(item => (
    `${item.catalogTitle} (${item.spoken}, ${item.defaultDurationMinutes} мин)`
  )).join('; ');
  return [
    'Ты голосовой планировщик WeekFit. Говори только по-русски, коротко, одно или два предложения.',
    givenName
      ? `В самом начале звонка первым поздоровайся с пользователем по имени ${givenName} и спроси, что запланировать. После приветствия не повторяй его без причины.`
      : 'В самом начале звонка первым поздоровайся и спроси, что запланировать. После приветствия не повторяй его без причины.',
    `Сегодня ${days.today}. Завтра ${days.tomorrow}. Послезавтра ${days.dayAfterTomorrow}. Часовой пояс ${days.timeZone}.`,
    `Открытый день плана: ${planningDay}. Если человек не назвал день, передай date пустой строкой.`,
    'На час значит 60 минут. На полтора часа значит 90. В час дня значит 13:00. В час ночи значит 01:00. В двенадцать ночи значит 00:00.',
    `Можно создать только активность из каталога: ${catalog}.`,
    'Вызови create_activity, когда известны название и время начала. Если человек не назвал длительность, передай durationMinutes 0.',
    'Если нет времени начала, спроси «Во сколько?» и не вызывай инструмент. Не проси отдельное подтверждение, когда данных достаточно.',
    'Фразу про успешное добавление произноси только если инструмент вернул ok true и saved true. Скажи поле speak дословно.',
    'Если ok не true, скажи, что сохранить не удалось, и предложи повторить. Не говори, что активность уже в плане.',
  ].join('\n');
}

function createActivityTool() {
  return {
    type: 'function',
    name: 'create_activity',
    description: 'Создать одну активность в текущем плане. Не подтверждать успех до ответа инструмента.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        catalogTitle: { type: 'string', enum: CATALOG.map(item => item.catalogTitle) },
        date: { type: 'string', description: 'YYYY-MM-DD в часовом поясе пользователя или пустая строка, если день не назван.' },
        startTime: { type: 'string', description: 'HH:mm, 24 часа. Пустая строка, если время не названо.' },
        durationMinutes: { type: 'integer', description: 'Минуты. 0, если человек не назвал длительность.' },
      },
      required: ['catalogTitle', 'date', 'startTime', 'durationMinutes'],
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
