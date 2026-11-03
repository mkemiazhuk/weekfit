import { createHash, randomBytes } from 'node:crypto';
import { ServiceError } from './recognition.mjs';
import {
  askActivityLine,
  askTimeLine,
  conflictLine,
  confirmationLine,
  greetingLine,
  PLANNER_VOICE_LANGUAGES,
  plannerVoiceLanguage,
  plannerVoicePhrases,
  spokenActivityName,
  spokenClock,
} from './planner-voice-copy.mjs';
import { voiceGuide } from './planner-voice-guides.mjs';

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
  const languageModel = (env.PLANNER_VOICE_LANGUAGE_MODEL ?? '').trim();
  if (languageModel && !/^gpt-realtime(?:-[a-z0-9.]+)*$/.test(languageModel)) {
    throw Error('Invalid PLANNER_VOICE_LANGUAGE_MODEL');
  }
  const modelLanguages = String(env.PLANNER_VOICE_LANGUAGE_MODEL_LANGUAGES ?? '')
    .split(',').map(item => item.trim()).filter(Boolean);
  if (modelLanguages.some(item => !PLANNER_VOICE_LANGUAGES.includes(item))) {
    throw Error('Invalid PLANNER_VOICE_LANGUAGE_MODEL_LANGUAGES');
  }
  const noiseReduction = (env.PLANNER_VOICE_NOISE_REDUCTION ?? 'near_field').trim();
  if (!['near_field', 'far_field', 'off'].includes(noiseReduction)) throw Error('Invalid PLANNER_VOICE_NOISE_REDUCTION');
  const integer = (key, fallback, min, max) => {
    if (env[key] == null || env[key] === '') return fallback;
    const n = Number(env[key]);
    if (!Number.isInteger(n) || n < min || n > max) throw Error(`Invalid ${key}`);
    return n;
  };
  // The allowlist is kept so an old environment value does not crash. Any signed-in account can call.
  const allowed = String(env.PLANNER_VOICE_ALLOWED_UIDS ?? '')
    .split(',')
    .map(item => item.trim())
    .filter(Boolean)
    .slice(0, 20);
  return {
    plannerVoiceEnabled: env.PLANNER_VOICE_ENABLED === '1',
    plannerVoiceAllowedUids: allowed,
    plannerVoiceModel: model,
    // Optional stronger model for the listed app languages, e.g. ru,fr.
    plannerVoiceLanguageModel: languageModel && modelLanguages.length ? languageModel : null,
    plannerVoiceLanguageModelLanguages: modelLanguages,
    plannerVoiceVoice: voice,
    plannerVoiceNoiseReduction: noiseReduction,
    plannerVoiceIdleSeconds: integer('PLANNER_VOICE_IDLE_SECONDS', 75, 20, 180),
    plannerVoiceSecretSeconds: integer('PLANNER_VOICE_SECRET_SECONDS', 60, 10, 600),
    plannerVoiceMaxCalls: integer('PLANNER_VOICE_MAX_CALLS', 5, 1, 100),
    plannerVoiceMaxWaiting: integer('PLANNER_VOICE_MAX_WAITING', 100, 1, 500),
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

export function createPlannerCallLine({
  maxCalls = 5,
  maxWaiting = 100,
  waitMs = 20_000,
  holdMs = 45_000,
  now = () => Date.now(),
} = {}) {
  const waiting = [];
  const held = new Map();
  const byUid = new Map();

  const expire = (time) => {
    for (let index = waiting.length - 1; index >= 0; index -= 1) {
      if (time - waiting[index].beat <= waitMs) continue;
      if (byUid.get(waiting[index].uid) === waiting[index].ticket) byUid.delete(waiting[index].uid);
      waiting.splice(index, 1);
    }
    for (const [ticket, row] of held) {
      const limit = row.phase === 'active' ? holdMs : 20_000;
      if (time - row.beat <= limit) continue;
      held.delete(ticket);
      if (byUid.get(row.uid) === ticket) byUid.delete(row.uid);
    }
  };

  const promote = (time) => {
    while (held.size < maxCalls && waiting.length > 0) {
      const next = waiting.shift();
      held.set(next.ticket, { uid: next.uid, beat: time, phase: 'reserved' });
    }
  };

  const view = (uid) => {
    const ticket = byUid.get(uid);
    if (!ticket) return null;
    const row = held.get(ticket);
    if (row) {
      return { ticket, state: row.phase === 'active' ? 'active' : 'ready', position: 0 };
    }
    const index = waiting.findIndex(item => item.ticket === ticket);
    if (index < 0) return null;
    return { ticket, state: 'waiting', position: index + 1 };
  };

  const busy = (position) => ({
    ok: false,
    status: 429,
    body: { error: 'planner_voice_busy', saved: false, state: 'waiting', position },
  });

  return {
    place(uid) {
      const time = now();
      expire(time);
      const existing = view(uid);
      if (existing) {
        const queued = waiting.find(item => item.ticket === existing.ticket);
        if (queued) queued.beat = time;
        const row = held.get(existing.ticket);
        if (row) row.beat = time;
        promote(time);
        return view(uid);
      }
      if (held.size >= maxCalls && waiting.length >= maxWaiting) {
        return { error: 'planner_voice_line_full', status: 503, position: waiting.length };
      }
      const ticket = `q_${randomBytes(9).toString('hex')}`;
      waiting.push({ ticket, uid, beat: time });
      byUid.set(uid, ticket);
      promote(time);
      return view(uid);
    },

    claim(uid, requested) {
      const time = now();
      expire(time);
      promote(time);
      let ticket = typeof requested === 'string' ? requested : '';
      if (!ticket) {
        const current = view(uid);
        if (current?.state === 'waiting') return busy(current.position);
        if (current?.state === 'ready' || current?.state === 'active') {
          ticket = current.ticket;
        } else if (held.size >= maxCalls) {
          return busy(waiting.length + 1);
        } else {
          ticket = `q_${randomBytes(9).toString('hex')}`;
          held.set(ticket, { uid, beat: time, phase: 'minting' });
          byUid.set(uid, ticket);
          return { ok: true, ticket };
        }
      }
      const row = held.get(ticket);
      if (!row || row.uid !== uid) {
        return { ok: false, status: 409, body: { error: 'planner_voice_not_ready', saved: false } };
      }
      if (row.phase === 'active' || row.phase === 'minting') {
        if (!requested && row.phase === 'active') {
          row.phase = 'minting';
          row.beat = time;
          return { ok: true, ticket };
        }
        return { ok: false, status: 409, body: { error: 'planner_voice_already_started', saved: false } };
      }
      row.phase = 'minting';
      row.beat = time;
      return { ok: true, ticket };
    },

    activate(uid, ticket) {
      const row = held.get(ticket);
      if (!row || row.uid !== uid) return;
      row.phase = 'active';
      row.beat = now();
    },

    beat(uid, ticket) {
      const time = now();
      expire(time);
      const row = held.get(ticket);
      if (!row || row.uid !== uid || row.phase !== 'active') return false;
      row.beat = time;
      return true;
    },

    release(uid, ticket) {
      const time = now();
      const row = held.get(ticket);
      if (row && row.uid === uid) {
        held.delete(ticket);
        if (byUid.get(uid) === ticket) byUid.delete(uid);
      } else {
        const index = waiting.findIndex(item => item.ticket === ticket && item.uid === uid);
        if (index >= 0) {
          waiting.splice(index, 1);
          if (byUid.get(uid) === ticket) byUid.delete(uid);
        }
      }
      expire(time);
      promote(time);
    },
  };
}

export function createPlannerVoiceHandler(config, dependencies = {}) {
  const authenticate = dependencies.authenticate;
  const fetcher = dependencies.fetch ?? globalThis.fetch;
  const store = dependencies.store ?? createPlannerVoiceStore();
  const line = dependencies.line ?? createPlannerCallLine({
    maxCalls: config.plannerVoiceMaxCalls ?? 5,
    maxWaiting: config.plannerVoiceMaxWaiting ?? 100,
  });
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

      if (req.method === 'POST' && path === '/v1/planner-voice/line') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const placed = line.place(uid);
        if (placed.error) {
          sendJson(res, placed.status, { error: placed.error, saved: false, position: placed.position });
          return true;
        }
        sendJson(res, 200, placed);
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/line/beat') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        const alive = line.beat(uid, payload?.ticket);
        sendJson(res, alive ? 204 : 404, alive ? {} : { error: 'not_found', saved: false });
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/line/release') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        line.release(uid, payload?.ticket);
        sendJson(res, 204, {});
        return true;
      }

      if (req.method === 'POST' && path === '/v1/planner-voice/session') {
        const uid = await requireUser(authenticate, req, config);
        assertAllowed(config, uid);
        const payload = await readJson(req);
        const admission = line.claim(uid, payload?.ticket);
        if (!admission.ok) {
          sendJson(res, admission.status, admission.body);
          return true;
        }
        try {
          const secret = await mintSecret(config, fetcher, uid, payload, log);
          line.activate(uid, admission.ticket);
          sendJson(res, 200, secret);
        } catch (error) {
          line.release(uid, admission.ticket);
          throw error;
        }
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
  let hangupConfirmed = false;
  let goodbyeLocked = false;
  let greetingPending = false;
  let voiced = false;
  let micOpen = false;
  let audioPlaying = false;
  let responseAudio = false;
  let goodbyeFallback = null;
  let goodbyeTail = null;
  let presence = null;
  let closing = null;
  let presenceAsked = false;
  let returnedAfterCheck = false;
  let thinkHold = false;
  let answerNow = false;
  let replyWatch = null;
  let toolBusy = false;
  let toolFollowUp = false;
  let sessionLanguage = 'ru';
  let sessionName = '';
  let sdpResolve = null;
  const pending = new Map();
  const CHECK = {
    ru: { there: (n) => (n ? n + ', ты ещё здесь?' : 'Ты ещё здесь?'), bye: 'До свидания.' },
    en: { there: (n) => (n ? 'Still there, ' + n + '?' : 'Still there?'), bye: "I'll end the call now. Bye!" },
    pl: { there: (n) => (n ? n + ', jesteś tam?' : 'Jesteś tam?'), bye: 'Kończę rozmowę. Na razie!' },
    fr: { there: (n) => (n ? n + ', tu es là ?' : 'Tu es là ?'), bye: "Je termine l'appel. À plus !" },
    es: { there: (n) => (n ? n + ', ¿sigues ahí?' : '¿Sigues ahí?'), bye: 'Termino la llamada. Hasta luego!' },
    de: { there: (n) => (n ? n + ', bist du noch da?' : 'Bist du noch da?'), bye: 'Ich beende das Gespräch. Tschüss!' },
    it: { there: (n) => (n ? n + ', ci sei?' : 'Ci sei?'), bye: 'Chiudo la chiamata. A presto!' },
    ja: { there: (n) => (n ? n + '、まだいる？' : 'まだいる？'), bye: '通話を終えるね。またね！' },
    ko: { there: (n) => (n ? n + ', 아직 있어?' : '아직 있어?'), bye: '통화를 마칠게. 안녕!' },
    'zh-Hans': { there: (n) => (n ? n + '，你还在吗？' : '你还在吗？'), bye: '我先挂了。再见！' },
  };
  const NUDGE = {
    ru: 'Человек уже договорил и слышит тишину. Сразу ответь на его последнюю фразу, одной короткой фразой. Не говори, что думаешь, и не отвечай только «я здесь».',
    en: 'They just finished speaking and heard silence. Answer their last sentence now, in one short sentence. Do not say you are thinking, and do not only say that you are here.',
    pl: 'Osoba już skończyła i słyszy ciszę. Od razu odpowiedz na ostatnie zdanie, jednym krótkim zdaniem. Nie mów, że myślisz, i nie odpowiadaj tylko „jestem”.',
    fr: "La personne a fini de parler et entend le silence. Réponds tout de suite à sa dernière phrase, en une phrase courte. Ne dis pas que tu réfléchis, et ne réponds pas seulement « je suis là ».",
    es: 'La persona ya terminó y oye silencio. Responde ahora a su última frase, en una frase corta. No digas que estás pensando, y no contestes solo «aquí estoy».',
    de: 'Die Person ist fertig und hört Stille. Antworte sofort auf den letzten Satz, in einem kurzen Satz. Sag nicht, dass du nachdenkst, und antworte nicht nur mit „ich bin da“.',
    it: "La persona ha finito e sente silenzio. Rispondi subito all'ultima frase, in una frase corta. Non dire che stai pensando, e non rispondere solo «ci sono».",
    ja: '相手は話し終わって、無音が続いている。最後の一文にすぐ短く答える。考えているとは言わない。「いるよ」だけでも答えない。',
    ko: '상대는 말을 끝냈고 침묵이 이어진다. 마지막 문장에 바로 짧게 답한다. 생각 중이라고 말하지 말고, 「여기 있어」만 답하지 않는다.',
    'zh-Hans': '对方已经说完，现在是沉默。马上用一句短话回答刚才那句。不要说你在想，也不要只说「我在」。',
  };

  const post = (payload) => {
    const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plannerVoice;
    if (handler) handler.postMessage(payload);
  };

  const applyMic = () => {
    if (local) local.getAudioTracks().forEach((track) => { track.enabled = micOpen && !muted; });
  };

  const openMic = () => {
    micOpen = true;
    applyMic();
  };

  const closeMic = () => {
    micOpen = false;
    applyMic();
  };

  // Silence is not a hangup. The call stays up until they press end, or they
  // decline further help after the request is done.
  const armIdle = () => {
    if (idle) clearTimeout(idle);
    idle = null;
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
    clearReplyWatch();
    clearPresence();
    if (goodbyeFallback) clearTimeout(goodbyeFallback);
    if (goodbyeTail) clearTimeout(goodbyeTail);
    goodbyeFallback = null;
    goodbyeTail = null;
    callNumber++;
    release();
    post({ type: 'state', value: 'ended', reason: reason || 'user' });
  }

  function clearPresence() {
    if (presence) clearTimeout(presence);
    if (closing) clearTimeout(closing);
    presence = null;
    closing = null;
  }

  function presenceLine(kind) {
    const pack = CHECK[sessionLanguage] || CHECK.en;
    const line = pack[kind];
    return typeof line === 'function' ? line(sessionName) : line;
  }

  function clearReplyWatch() {
    if (replyWatch) clearTimeout(replyWatch);
    replyWatch = null;
  }

  function nudgeReply() {
    if (!channel || channel.readyState !== 'open' || hangup || goodbyeLocked || toolBusy || audioPlaying) return;
    const text = NUDGE[sessionLanguage] || NUDGE.en;
    channel.send(JSON.stringify({
      type: 'response.create',
      response: { instructions: text },
    }));
  }

  function armReplyWatch() {
    clearReplyWatch();
    replyWatch = setTimeout(() => {
      replyWatch = null;
      if (greetingPending) return;
      nudgeReply();
    }, 3000);
  }

  function speakExact(text, ending) {
    if (!channel || channel.readyState !== 'open') {
      if (ending) stop('silence');
      return;
    }
    if (ending) {
      hangup = true;
      hangupConfirmed = false;
    }
    channel.send(JSON.stringify({
      type: 'response.create',
      response: { instructions: 'Say exactly this and nothing else: ' + text },
    }));
  }

  function askIfThere() {
    presence = null;
    if (hangup || toolBusy || returnedAfterCheck || presenceAsked) return;
    presenceAsked = true;
    speakExact(presenceLine('there'), false);
  }

  function warnAndEnd() {
    closing = null;
    if (hangup || returnedAfterCheck) return;
    speakExact(presenceLine('bye'), true);
  }

  function armPresence() {
    clearPresence();
    thinkHold = false;
  }

  function cancelGoodbye() {
    hangup = false;
    hangupConfirmed = false;
    if (goodbyeFallback) clearTimeout(goodbyeFallback);
    if (goodbyeTail) clearTimeout(goodbyeTail);
    goodbyeFallback = null;
    goodbyeTail = null;
  }

  function watchLevel(stream, kind) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext || !stream) return;
    try {
      const context = new AudioContext();
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      const data = new Uint8Array(analyser.fftSize);
      const started = callNumber;
      const tick = () => {
        if (!pc || started !== callNumber) {
          try { context.close(); } catch (e) {}
          return;
        }
        analyser.getByteTimeDomainData(data);
        let sum = 0;
        for (let i = 0; i < data.length; i += 1) {
          const sample = (data[i] - 128) / 128;
          sum += sample * sample;
        }
        const level = Math.min(1, Math.sqrt(sum / data.length) * 5);
        const payload = { type: 'level' };
        payload[kind] = Math.round(level * 100) / 100;
        post(payload);
        setTimeout(tick, 100);
      };
      setTimeout(tick, 100);
    } catch (e) {}
  }

  function armGoodbyeFallback() {
    if (goodbyeFallback || goodbyeTail) return;
    goodbyeFallback = setTimeout(() => stop('goodbye'), 12000);
  }

  function finishGoodbye() {
    if (!hangup || goodbyeTail) return;
    if (goodbyeFallback) clearTimeout(goodbyeFallback);
    goodbyeFallback = null;
    goodbyeTail = setTimeout(() => stop('goodbye'), 20);
  }

  function sendToolOutput(callId, output) {
    if (!channel || channel.readyState !== 'open') return;
    toolFollowUp = true;
    channel.send(JSON.stringify({
      type: 'conversation.item.create',
      item: { type: 'function_call_output', call_id: callId, output: JSON.stringify(output) },
    }));
    channel.send(JSON.stringify({ type: 'response.create' }));
  }

  window.weekfit = {
    sdpAnswer: (sdp) => { if (sdpResolve) { sdpResolve(sdp); sdpResolve = null; } },
    stop: () => stop('user'),
    setMuted: (value) => {
      muted = Boolean(value);
      applyMic();
    },
    // Older apps call this when the greeting starts; the microphone waits for the greeting to finish.
    answered: () => {
      if (!local || greetingPending || goodbyeLocked) return;
      openMic();
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
        hangup = false;
        hangupConfirmed = false;
        goodbyeLocked = false;
        greetingPending = false;
        voiced = false;
        micOpen = false;
        audioPlaying = false;
        responseAudio = false;
        idleMs = Math.max(20000, Number(options.idleSeconds || 75) * 1000);
        post({ type: 'state', value: 'connecting' });
        pc = new RTCPeerConnection();
        pc.onconnectionstatechange = () => {
          if (!pc || thisCall !== callNumber) return;
          if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
            post({ type: 'state', value: 'ended', reason: 'connection' });
          }
        };
        remoteAudio = document.createElement('audio');
        remoteAudio.autoplay = true;
        remoteAudio.setAttribute('playsinline', '');
        document.body.appendChild(remoteAudio);
        pc.ontrack = (event) => {
          const stream = event.streams[0];
          if (remoteAudio) remoteAudio.srcObject = stream;
          watchLevel(stream, 'output');
        };
        const microphone = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
        if (thisCall !== callNumber || !pc) { microphone.getTracks().forEach((track) => track.stop()); return; }
        local = microphone;
        watchLevel(local, 'input');
        // Don't send locally played ringback audio to the assistant.
        local.getAudioTracks().forEach((track) => { track.enabled = false; });
        micOpen = false;
        local.getTracks().forEach((track) => pc.addTrack(track, local));
        channel = pc.createDataChannel('oai-events');
        channel.onmessage = (event) => onEvent(event.data);
        sessionLanguage = String((options && options.language) || 'ru');
        sessionName = String((options && options.givenName) || '').replace(/[\\r\\n"]/g, '').slice(0, 40);
        const reopen = Boolean(options && options.reconnected);
        channel.onopen = () => {
          if (thisCall !== callNumber || !local || !channel) return;
          post({ type: 'state', value: 'connected' });
          post({ type: 'state', value: 'answered' });
          armIdle();
          if (reopen) {
            openMic();
            return;
          }
          // Echo cancellation needs a moment on the speaker: an open microphone hears the
          // greeting, the server treats it as speech, and cuts the greeting off.
          greetingPending = true;
          setTimeout(() => {
            if (thisCall !== callNumber || !channel || channel.readyState !== 'open') return;
            channel.send(JSON.stringify({ type: 'response.create' }));
          }, 400);
          setTimeout(() => {
            if (thisCall !== callNumber || !greetingPending) return;
            greetingPending = false;
            if (!goodbyeLocked) openMic();
          }, 10000);
        };
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        if (options.managed) {
          const answer = new Promise((resolve, reject) => {
            sdpResolve = resolve;
            setTimeout(() => { if (sdpResolve === resolve) { sdpResolve = null; reject(new Error('connect_timeout')); } }, 25000);
          });
          post({ type: 'sdp', sdp: offer.sdp });
          const sdp = await answer;
          if (thisCall === callNumber && pc) await pc.setRemoteDescription({ type: 'answer', sdp });
          return;
        }
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
      if (goodbyeLocked) return;
      clearReplyWatch();
      clearPresence();
      cancelGoodbye();
      if (presenceAsked) returnedAfterCheck = true;
      thinkHold = false;
      post({ type: 'state', value: 'listening' });
      return;
    }
    if (type === 'input_audio_buffer.speech_stopped') {
      if (!goodbyeLocked && !hangup) armReplyWatch();
      return;
    }
    if (type === 'response.created') {
      responseAudio = false;
      if (!goodbyeLocked) post({ type: 'state', value: 'speaking' });
      return;
    }
    if (type === 'output_audio_buffer.started') {
      audioPlaying = true;
      responseAudio = true;
      clearReplyWatch();
      clearPresence();
      // The app keeps its connecting tone until this, so the line is never silent before Maya speaks.
      if (!voiced) {
        voiced = true;
        post({ type: 'state', value: 'voice' });
      }
      return;
    }
    if (type === 'output_audio_buffer.stopped' || type === 'output_audio_buffer.cleared') {
      const wasPlaying = audioPlaying;
      audioPlaying = false;
      if (greetingPending && wasPlaying) {
        greetingPending = false;
        if (!goodbyeLocked) openMic();
      }
      if (hangup) finishGoodbye();
      else if (wasPlaying) {
        toolFollowUp = false;
        toolBusy = false;
        armPresence();
      }
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
      if (answerNow && !hangup) {
        answerNow = false;
        nudgeReply();
      }
      if (hangup) {
        post({ type: 'state', value: 'ending' });
        // They said goodbye themselves: an echoed «пока» must not reopen the call.
        if (hangupConfirmed) {
          goodbyeLocked = true;
          closeMic();
        }
        // The goodbye audio can finish before end_call arrives; don't wait for a stop that already happened.
        if (!audioPlaying && responseAudio) finishGoodbye();
        else armGoodbyeFallback();
        return;
      }
      if (!audioPlaying && !toolBusy && !presence && !closing) armPresence();
      else if (toolFollowUp && !audioPlaying) {
        toolFollowUp = false;
        toolBusy = false;
        armPresence();
      }
      post({ type: 'state', value: 'listening' });
      return;
    }
    if (type === 'response.function_call_arguments.done' && event.name === 'end_call') {
      hangup = true;
      hangupConfirmed = true;
      clearPresence();
      return;
    }
    if (type === 'response.function_call_arguments.done' && event.name === 'need_a_moment') {
      thinkHold = false;
      toolBusy = false;
      answerNow = true;
      clearPresence();
      if (channel && channel.readyState === 'open') {
        channel.send(JSON.stringify({
          type: 'conversation.item.create',
          item: { type: 'function_call_output', call_id: event.call_id, output: JSON.stringify({ ok: true, wait: false }) },
        }));
      }
      return;
    }
    if (type === 'response.function_call_arguments.done' && ['create_activity', 'list_plan', 'update_activity', 'delete_activity'].includes(event.name)) {
      toolBusy = true;
      clearReplyWatch();
      clearPresence();
      post({ type: 'state', value: 'acting' });
      post({ type: 'tool', callId: event.call_id, name: event.name, arguments: event.arguments });
      return;
    }
    if (type === 'error') {
      // A provider error must not hang up. The line stays open until they end it.
      return;
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

export function plannerSessionConfiguration(config, payload) {
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
  const plan = planSnapshot(payload?.plan);
  const dayContext = dayContextSnapshot(payload?.dayContext);
  const introduced = payload?.introduced === true;
  const reconnected = payload?.reconnected === true;
  const session = {
    type: 'realtime',
    model: config.plannerVoiceLanguageModel && config.plannerVoiceLanguageModelLanguages?.includes(language)
      ? config.plannerVoiceLanguageModel : config.plannerVoiceModel,
    instructions: instructions(days, planningDay, safeName, language, plan, dayContext, introduced, reconnected),
    tools: [createActivityTool(), listPlanTool(), updateActivityTool(), deleteActivityTool(), endCallTool()],
    tool_choice: 'auto',
    // Budget covers audio and tool calls, not just the short spoken transcript.
    max_output_tokens: 2048,
    output_modalities: ['audio'],
    audio: {
      input: {
        turn_detection: {
          type: 'semantic_vad',
          eagerness: 'medium',
          create_response: true,
          interrupt_response: true,
        },
        // Phone held in front of the face; cleaner input keeps street noise from cutting Maya off.
        ...((config.plannerVoiceNoiseReduction ?? 'near_field') === 'off'
          ? {} : { noise_reduction: { type: config.plannerVoiceNoiseReduction ?? 'near_field' } }),
      },
      output: { voice: config.plannerVoiceVoice || 'marin' },
    },
  };
  return session;
}

async function mintSecret(config, fetcher, uid, payload, log) {
  const session = plannerSessionConfiguration(config, payload);
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

function planSnapshot(raw) {
  if (!Array.isArray(raw)) return [];
  const rows = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const ref = String(item.ref || '');
    const scope = String(item.scope || '');
    const title = String(item.title || '').replace(/[\r\n]/g, ' ').trim().slice(0, 80);
    const startTime = String(item.startTime || '');
    const duration = item.durationMinutes;
    if (!/^a[1-9]\d{0,2}$/.test(ref)) continue;
    if (!['today_done', 'today_planned', 'tomorrow'].includes(scope)) continue;
    if (!title || !/^([01]\d|2[0-3]):[0-5]\d$/.test(startTime)) continue;
    if (!Number.isInteger(duration) || duration < 1 || duration > 360) continue;
    rows.push({ ref, scope, title, startTime, durationMinutes: duration });
    if (rows.length === 24) break;
  }
  return rows;
}

function dayContextSnapshot(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const recovery = recoverySnapshot(raw.recovery);
  const meals = mealSnapshot(raw.meals);
  const nutrition = nutritionSnapshot(raw.nutrition);
  const trainingProvided = Array.isArray(raw.training);
  const training = trainingSnapshot(raw.training);
  if (!recovery && meals.length === 0 && !nutrition && !trainingProvided) return null;
  return { recovery, meals, nutrition, training, trainingProvided };
}

function boundedInteger(value, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) return null;
  return value;
}

function nutritionSnapshot(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const nutrition = {};
  const caloriesEaten = boundedInteger(raw.caloriesEaten, 0, 20000);
  const caloriesBudget = boundedInteger(raw.caloriesBudget, 1, 20000);
  const proteinGrams = boundedInteger(raw.proteinGrams, 0, 1000);
  const proteinGoalGrams = boundedInteger(raw.proteinGoalGrams, 1, 1000);
  const waterMilliliters = boundedInteger(raw.waterMilliliters, 0, 20000);
  const waterGoalMilliliters = boundedInteger(raw.waterGoalMilliliters, 1, 20000);
  if (caloriesEaten != null) nutrition.caloriesEaten = caloriesEaten;
  if (caloriesBudget != null) nutrition.caloriesBudget = caloriesBudget;
  if (proteinGrams != null) nutrition.proteinGrams = proteinGrams;
  if (proteinGoalGrams != null) nutrition.proteinGoalGrams = proteinGoalGrams;
  if (waterMilliliters != null) nutrition.waterMilliliters = waterMilliliters;
  if (waterGoalMilliliters != null) nutrition.waterGoalMilliliters = waterGoalMilliliters;
  return Object.keys(nutrition).length ? nutrition : null;
}

function trainingSnapshot(raw) {
  if (!Array.isArray(raw)) return [];
  const rows = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const title = String(item.title || '').replace(/[\r\n]/g, ' ').trim().slice(0, 60);
    const minutes = boundedInteger(item.minutes, 1, 360);
    if (!title || minutes == null || typeof item.done !== 'boolean') continue;
    rows.push({ title, minutes, done: item.done });
    if (rows.length === 4) break;
  }
  return rows;
}

function recoverySnapshot(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const percent = raw.percent;
  const sleepMinutes = raw.sleepMinutes;
  const hasPercent = Number.isInteger(percent) && percent >= 1 && percent <= 100;
  const hasSleep = Number.isInteger(sleepMinutes) && sleepMinutes >= 1 && sleepMinutes <= 24 * 60;
  if (!hasPercent && !hasSleep) return null;
  const recovery = {};
  if (hasPercent) recovery.percent = percent;
  if (hasPercent && ['good', 'ok', 'need_rest'].includes(raw.band)) recovery.band = raw.band;
  if (hasSleep) recovery.sleepMinutes = sleepMinutes;
  return recovery;
}

function mealSnapshot(raw) {
  if (!Array.isArray(raw)) return [];
  const meals = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const title = String(item.title || '').replace(/[\r\n]/g, ' ').trim().slice(0, 80);
    const time = String(item.time || '');
    if (!title || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) continue;
    meals.push({ title, time });
    if (meals.length === 8) break;
  }
  return meals;
}

function dayContextLine(dayContext, language) {
  const facts = voiceGuide(language).facts;
  if (!dayContext) return facts.none;
  const parts = [];
  if (dayContext.recovery) {
    const recovery = dayContext.recovery;
    const bits = [];
    if (recovery.percent) bits.push(facts.percent(recovery.percent));
    if (recovery.band) bits.push(facts.band(recovery.band));
    if (recovery.sleepMinutes) bits.push(facts.sleep(recovery.sleepMinutes));
    parts.push(facts.recovery(bits.join(', ')));
  } else {
    parts.push(facts.noRecovery);
  }
  if (dayContext.meals.length) {
    const rows = dayContext.meals.map(meal => (
      `${meal.time} (${facts.say} ${spokenClock(meal.time, language)}) ${meal.title}`
    ));
    parts.push(facts.meals(rows.join('; ')));
  } else {
    parts.push(facts.noMeals);
  }
  if (dayContext.nutrition) {
    const nutrition = dayContext.nutrition;
    const bits = [];
    if (nutrition.caloriesEaten != null && nutrition.caloriesBudget != null) {
      bits.push(facts.eatenOf(nutrition.caloriesEaten, nutrition.caloriesBudget));
    } else if (nutrition.caloriesEaten != null) {
      bits.push(facts.eaten(nutrition.caloriesEaten));
    }
    if (nutrition.proteinGrams != null && nutrition.proteinGoalGrams != null) {
      bits.push(facts.proteinOf(nutrition.proteinGrams, nutrition.proteinGoalGrams));
    } else if (nutrition.proteinGrams != null) {
      bits.push(facts.protein(nutrition.proteinGrams));
    }
    if (nutrition.waterMilliliters != null) {
      const liters = (nutrition.waterMilliliters / 1000).toFixed(1);
      if (nutrition.waterGoalMilliliters != null) {
        bits.push(facts.waterOf(liters, (nutrition.waterGoalMilliliters / 1000).toFixed(1)));
      } else {
        bits.push(facts.water(liters));
      }
    }
    if (bits.length) parts.push(facts.nutrition(bits.join('; ')));
  } else {
    parts.push(facts.noNutrition);
  }
  if (dayContext.training.length) {
    const rows = dayContext.training.map(item => (
      `${item.title}, ${item.done ? facts.done : facts.planned}, ${facts.minutes(item.minutes)}`
    ));
    parts.push(facts.training(rows.join('; ')));
  } else if (dayContext.trainingProvided) {
    parts.push(facts.noTraining);
  } else {
    parts.push(facts.trainingMissing);
  }
  return parts.join(' ');
}

function instructions(days, planningDay, givenName, language, plan = [], dayContext = null, introduced = false, reconnected = false) {
  const phrases = plannerVoicePhrases(language);
  const catalog = CATALOG.map(item => (
    `${item.catalogTitle} = ${spokenActivityName(item.catalogTitle, language)} (${item.defaultDurationMinutes} min, ${item.plannerTypeTitle})`
  )).join('; ');
  const guide = voiceGuide(language);
  const rows = plan.map(item => (
    `${item.ref} ${item.scope} ${item.title} ${item.startTime} ${item.durationMinutes}m (${guide.facts.say} ${spokenClock(item.startTime, language)})`
  )).join('; ');
  return [
    ...guide.rules(phrases, catalog),
    guide.marker,
    givenName ? guide.name(givenName) : guide.noName,
    guide.introduced(introduced),
    reconnected ? guide.reconnected : guide.opening(greetingLine(language, givenName, introduced)),
    guide.dates(days, planningDay),
    dayContextLine(dayContext, language),
    plan.length ? guide.plan(rows) : guide.emptyPlan,
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

function listPlanTool() {
  return {
    type: 'function',
    name: 'list_plan',
    description: 'Read activities already on the plan. Use today_done for what was completed today, tomorrow for what is planned tomorrow, today_planned for what is still planned today.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        scope: { type: 'string', enum: ['today_done', 'tomorrow', 'today_planned'] },
      },
      required: ['scope'],
    },
  };
}

function updateActivityTool() {
  return {
    type: 'function',
    name: 'update_activity',
    description: 'Change one planned activity identified by a plan ref. Do not use this to create a new activity.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        ref: { type: 'string', description: 'Plan ref such as a1.' },
        date: { type: 'string', description: 'YYYY-MM-DD, or empty to keep the current day.' },
        startTime: { type: 'string', description: 'HH:mm, or empty to keep the current time.' },
        durationMinutes: { type: 'integer', description: 'Minutes. 0 keeps the current duration.' },
        catalogTitle: { type: 'string', description: 'English catalog title, or empty to keep the current activity.' },
      },
      required: ['ref', 'date', 'startTime', 'durationMinutes', 'catalogTitle'],
    },
  };
}

function deleteActivityTool() {
  return {
    type: 'function',
    name: 'delete_activity',
    description: 'Remove one planned activity by its plan ref. Do not use this for an activity that is already done.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        ref: { type: 'string', description: 'Plan ref such as a1.' },
      },
      required: ['ref'],
    },
  };
}

function endCallTool() {
  return {
    type: 'function',
    name: 'end_call',
    description: 'Hang up after the request is done and they decline more help. «всё, спасибо», «все спасибо», «спасибо, всё», and "that\'s all, thanks" are a decline even though they contain thanks: say only the exact goodbye and call this in that same response. A bare спасибо, alright, okay, or thanks in the middle of a task is not a decline. Do not announce that you are ending the call. Do not use this before the save is confirmed.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {},
      required: [],
    },
  };
}

function isAllowed(config, uid) {
  return config.plannerVoiceEnabled === true && typeof uid === 'string' && uid.length > 0;
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
