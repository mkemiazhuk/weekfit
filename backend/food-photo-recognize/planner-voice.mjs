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

const DEFAULT_MODEL = 'gpt-realtime-2.1';
const LIVE_MODEL = 'gpt-live-1';
const DEFAULT_LIVE_BACKEND = 'gpt-6.1-sol';
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
    plannerVoiceLiveModel: LIVE_MODEL,
    plannerVoiceLiveBackendModel: (env.PLANNER_VOICE_LIVE_BACKEND_MODEL ?? DEFAULT_LIVE_BACKEND).trim() || DEFAULT_LIVE_BACKEND,
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
          if (plannerVoiceEngine(payload) === 'live') {
            line.release(uid, admission.ticket);
            sendJson(res, 503, { error: 'planner_voice_live_unavailable' });
            return true;
          }
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
  let userSpokeBeforeGreeting = false;
  let sessionIntroduced = false;
  let introductionNoted = false;
  let voiced = false;
  let micOpen = false;
  let audioPlaying = false;
  let responseAudio = false;
  let goodbyeFallback = null;
  let goodbyeTail = null;
  let farewellForced = false;
  let farewellWait = null;
  let userSaid = '';
  let goodbyeIntent = null;
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
  let liveEngine = false;
  let liveGreet = false;
  const liveCalls = new Set();
  let sdpResolve = null;
  const pending = new Map();
  const CHECK = {
    ru: { there: (n) => (n ? n + ', ты ещё здесь?' : 'Ты ещё здесь?'), bye: 'До встречи.' },
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
  const FIRST_GREET = ${JSON.stringify(Object.fromEntries(PLANNER_VOICE_LANGUAGES.map((code) => [code, greetingLine(code, '', false)])))};
  const AGAIN_GREET = ${JSON.stringify(Object.fromEntries(PLANNER_VOICE_LANGUAGES.map((code) => [code, greetingLine(code, '', true)])))};
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
    if (farewellWait) clearTimeout(farewellWait);
    goodbyeFallback = null;
    goodbyeTail = null;
    farewellWait = null;
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
    if (liveEngine) {
      channel.send(JSON.stringify({
        type: 'session.commentary.append',
        event_id: 'line_' + Date.now(),
        delegation_id: null,
        content: text,
      }));
      return;
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
    farewellForced = false;
    if (goodbyeFallback) clearTimeout(goodbyeFallback);
    if (goodbyeTail) clearTimeout(goodbyeTail);
    if (farewellWait) clearTimeout(farewellWait);
    goodbyeFallback = null;
    goodbyeTail = null;
    farewellWait = null;
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

  function armGoodbyeFallback(ms) {
    if (goodbyeFallback || goodbyeTail) return;
    goodbyeFallback = setTimeout(() => finishGoodbye(), ms || 12000);
  }

  function wantsToHangUp(text) {
    return /(?:^|\\s)пока(?:\\s|$|[.!,])|до свидания|до встречи|это всё,\\s*заканчиваем|that's all|goodbye|(?:^|\\s)bye(?:\\s|$|[.!,])/i.test(text || '');
  }

  function beginHangup() {
    hangup = true;
    hangupConfirmed = true;
    clearPresence();
    if (goodbyeIntent) clearTimeout(goodbyeIntent);
    goodbyeIntent = null;
    if (goodbyeLocked) return;
    goodbyeLocked = true;
    closeMic();
    post({ type: 'state', value: 'ending' });
    if (audioPlaying) {
      armGoodbyeFallback(12000);
      return;
    }
    if (responseAudio || farewellForced) {
      finishGoodbye();
      return;
    }
    ensureSpokenFarewell();
    armGoodbyeFallback(4000);
  }

  function ensureSpokenFarewell() {
    if (farewellWait) clearTimeout(farewellWait);
    farewellWait = setTimeout(() => {
      farewellWait = null;
      if (!hangup || farewellForced || responseAudio || audioPlaying) return;
      farewellForced = true;
      speakExact(presenceLine('bye'), false);
    }, 400);
  }

  function finishGoodbye() {
    if (!hangup || goodbyeTail) return;
    if (goodbyeFallback) clearTimeout(goodbyeFallback);
    goodbyeFallback = null;
    goodbyeTail = setTimeout(() => {
      try {
        if (liveEngine && channel && channel.readyState === 'open') {
          channel.send(JSON.stringify({ type: 'session.close' }));
        }
      } catch (e) {}
      stop('goodbye');
    }, 20);
  }

  function sendToolOutput(callId, output) {
    if (!channel || channel.readyState !== 'open') return;
    toolFollowUp = true;
    if (liveEngine) {
      const payload = typeof output === 'string' ? output : JSON.stringify(output ?? { ok: false, saved: false });
      channel.send(JSON.stringify({
        type: 'response.item.create',
        item: { type: 'function_call_output', call_id: callId, output: payload },
      }));
      channel.send(JSON.stringify({ type: 'response.create' }));
      return;
    }
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
        liveEngine = options && options.engine === 'live';
        sessionIntroduced = Boolean(options && options.introduced);
        userSpokeBeforeGreeting = false;
        introductionNoted = false;
        const reopen = Boolean(options && options.reconnected);
        liveGreet = liveEngine && !reopen;
        liveCalls.clear();
        channel.onopen = () => {
          if (thisCall !== callNumber || !local || !channel) return;
          post({ type: 'state', value: 'connected' });
          post({ type: 'state', value: 'answered' });
          armIdle();
          if (reopen) {
            openMic();
            return;
          }
          // The microphone stays open so a question can replace the greeting and the greeting can be interrupted.
          greetingPending = true;
          openMic();
          setTimeout(() => {
            if (thisCall !== callNumber || !channel || channel.readyState !== 'open') return;
            if (userSpokeBeforeGreeting) {
              greetingPending = false;
              return;
            }
            if (!liveEngine) channel.send(JSON.stringify({ type: 'response.create' }));
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
    if (type === 'response.event' && event.event) {
      onEvent(JSON.stringify(event.event));
      return;
    }
    if (/input/.test(type) && /transcript|transcription/.test(type)) {
      const text = event.transcript || event.delta || (event.item && (event.item.transcript || event.item.text)) || '';
      if (text) userSaid = (userSaid + ' ' + text).slice(-500);
    }
    if (liveEngine && type === 'response.function_call_arguments.done') return;
    if (type === 'session.started') {
      post({ type: 'state', value: 'voice' });
      if (liveGreet && channel && channel.readyState === 'open') {
        liveGreet = false;
        if (userSpokeBeforeGreeting) return;
        const greet = (sessionIntroduced ? AGAIN_GREET : FIRST_GREET)[sessionLanguage] || FIRST_GREET.ru;
        channel.send(JSON.stringify({
          type: 'session.commentary.append',
          event_id: 'greeting_1',
          delegation_id: null,
          content: greet,
        }));
      }
      return;
    }
    if (type === 'session.closed') {
      stop('provider');
      return;
    }
    if (liveEngine && type === 'response.output_item.done' && event.item && event.item.type === 'function_call') {
      const name = event.item.name;
      const callId = event.item.call_id;
      if (!callId || liveCalls.has(callId)) return;
      liveCalls.add(callId);
      const args = typeof event.item.arguments === 'string'
        ? event.item.arguments
        : JSON.stringify(event.item.arguments || {});
      if (name === 'set_call_language') {
        try {
          const requested = JSON.parse(args).language;
          if (requested) sessionLanguage = String(requested);
        } catch (e) {}
      }
      if (name === 'end_call') {
        beginHangup();
        return;
      }
      if (['create_activity', 'list_plan', 'update_activity', 'delete_activity', 'log_water', 'remind_water', 'set_call_language'].includes(name)) {
        toolBusy = true;
        clearReplyWatch();
        clearPresence();
        post({ type: 'state', value: 'acting' });
        post({ type: 'tool', callId, name, arguments: args });
      }
      return;
    }
    if (type === 'input_audio_buffer.speech_started') {
      if (greetingPending && !voiced) userSpokeBeforeGreeting = true;
      if (!introductionNoted) {
        introductionNoted = true;
        post({ type: 'state', value: 'introduced' });
      }
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
      if (!goodbyeLocked && !hangup && wantsToHangUp(userSaid)) {
        if (goodbyeIntent) clearTimeout(goodbyeIntent);
        goodbyeIntent = setTimeout(() => {
          goodbyeIntent = null;
          if (!hangup) beginHangup();
        }, 2500);
      }
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
      if (!introductionNoted) {
        introductionNoted = true;
        post({ type: 'state', value: 'introduced' });
      }
      if (!voiced) {
        voiced = true;
        post({ type: 'state', value: 'voice' });
      }
      if (farewellWait) {
        clearTimeout(farewellWait);
        farewellWait = null;
      }
      if (hangup && goodbyeFallback) {
        clearTimeout(goodbyeFallback);
        goodbyeFallback = null;
        armGoodbyeFallback(12000);
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
        beginHangup();
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
      beginHangup();
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
    if (type === 'response.function_call_arguments.done' && ['create_activity', 'list_plan', 'update_activity', 'delete_activity', 'log_water', 'remind_water'].includes(event.name)) {
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

export function plannerVoiceEngine(body) {
  const engine = typeof body?.engine === 'string' ? body.engine.trim() : '';
  if (engine === '') return 'realtime';
  if (engine === 'live' || engine === 'realtime') return engine;
  throw new ServiceError('invalid_voice_engine', 422);
}

const LIVE_OPEN = 'On a plain greeting, say only the greeting and wait. Do not mention the sauna or any other activity. If they already asked a question, answer that question.';

const RECOVERY_BAND = {
  ru: { good: 'хорошо', ok: 'умеренная готовность', need_rest: 'низкое восстановление' },
  en: { good: 'good recovery', ok: 'moderate readiness', need_rest: 'low recovery' },
  pl: { good: 'dobra regeneracja', ok: 'umiarkowana gotowość', need_rest: 'niska regeneracja' },
  fr: { good: 'bonne récupération', ok: 'disponibilité modérée', need_rest: 'faible récupération' },
  es: { good: 'recuperación buena', ok: 'disponibilidad moderada', need_rest: 'recuperación baja' },
  de: { good: 'gute Erholung', ok: 'mäßige Bereitschaft', need_rest: 'geringe Erholung' },
  it: { good: 'recupero buono', ok: 'disponibilità moderata', need_rest: 'recupero basso' },
  ja: { good: '回復良好', ok: '中程度の準備', need_rest: '回復が低め' },
  ko: { good: '좋은 회복', ok: '중간 준비', need_rest: '낮은 회복' },
  'zh-Hans': { good: '恢复良好', ok: '中等准备', need_rest: '恢复偏低' },
};

function answerRules(language) {
  const code = plannerVoiceLanguage(language);
  const band = RECOVERY_BAND[code] || RECOVERY_BAND.en;
  const rules = {
    ru: [
      'На обычное приветствие скажи только приветствие и жди. Сауну и другое занятие не заводи, пока человек сам не спросил. Если первые слова уже вопрос, ответь на него.',
      `На вопрос про восстановление и еду используй только данные звонка. Назови процент и слова класса: ${band.good}, ${band.ok} или ${band.need_rest}. Не говори «ты умеренно готова». «${band.ok}» не называй средней. Затем скажи, что записано, и разницу между дневной целью и записанным потреблением. Затем одно предложение, не приказ, и причину из этих цифр. Нет записи еды не значит, что человек не ел. Не предлагай одни и те же продукты каждый раз: смотри на остаток белка, записанные приёмы, время и полноту дневника.`,
      'На вопрос, поесть до занятия или после, используй время этого занятия и время последней записанной еды. Если времени еды нет, задай один короткий вопрос или ответь условно. Не выбирай «после» только потому, что занятие есть в плане.',
      '«Её», «это занятие» и «то же» — это последнее занятие, которое уже однозначно обсудили, и его ref. Если подходят несколько, спроси какое. Не выбирай последнюю запись только потому, что она последняя.',
      'После инструмента список items — это уже текущий план. Если человек сообщает новое, например что уже поел или как себя чувствует, используй это в следующем ответе. Такая реплика не становится записью еды и не новым измерением. Тот же факт заново не спрашивай.',
      '«Спасибо» и «понятно» звонок не заканчивают. «Пока», «до свидания», «до встречи» и «это всё, заканчиваем» заканчивают. Скажи одно короткое прощание и в том же ответе вызови end_call.',
    ],
    en: [
      'A plain greeting gets only the greeting, then wait. Do not bring up the sauna or another activity unless they asked. If their first words are already a question, answer it.',
      `When they ask about recovery and food, use only the call details. Say the percent and these band words exactly: ${band.good}, ${band.ok}, or ${band.need_rest}. Never call ${band.ok} average. Then say the logged food and what remains to the goals. Then one next action and the reason from those numbers. No meal log does not mean they did not eat. Do not offer the same foods every time; use the gap, the logged meals, and the clock.`,
      'If they ask whether to eat before or after an activity, use that activity\'s time and the last logged meal time. If the last meal is missing, ask one short question or answer conditionally. Do not choose after only because the activity is on the plan.',
      '"It", "that activity", and "the same one" mean the last activity that was discussed clearly, and its ref. If more than one activity could match, ask which one. Do not choose the latest row only because it is last.',
      'After a tool returns items, those refs and times are the current plan. If they tell you something new, such as that they already ate or how they feel, use it in the next answer. That remark is not a saved meal or a new measurement. Do not ask for the same fact again.',
      'Thanks and got it do not end the call. Goodbye, bye, and that\'s all do. Say one short goodbye and call end_call in that same response.',
    ],
    pl: [
      'Na zwykłe przywitanie powiedz tylko przywitanie i czekaj. Nie zaczynaj o saunie ani o innym zajęciu, dopóki osoba o to nie spyta. Jeśli pierwsze słowa są już pytaniem, odpowiedz na nie.',
      `Gdy pytają o regenerację i jedzenie, użyj tylko szczegółów rozmowy. Podaj procent i dokładnie te słowa: ${band.good}, ${band.ok} albo ${band.need_rest}. Nie nazywaj „${band.ok}” średnią. Potem powiedz, co jest zapisane i ile zostało do celów. Potem jedno następne działanie i powód z tych liczb. Brak zapisu posiłku nie znaczy, że osoba nie jadła. Nie proponuj wciąż tych samych produktów: patrz na lukę, zapisane posiłki i godzinę.`,
      'Gdy pytają, czy zjeść przed zajęciem czy po nim, użyj godziny tego zajęcia i godziny ostatniego zapisanego posiłku. Gdy godziny posiłku nie ma, zadaj jedno krótkie pytanie albo odpowiedz warunkowo. Nie wybieraj „po” tylko dlatego, że zajęcie jest w planie.',
      '„To”, „to zajęcie” i „to samo” oznaczają ostatnie zajęcie, które już jednoznacznie omówiliście, i jego ref. Gdy pasuje kilka, spytaj które. Nie wybieraj ostatniego wpisu tylko dlatego, że jest ostatni.',
      'Po narzędziu lista items to już bieżący plan. Gdy osoba mówi coś nowego, na przykład że już jadła albo jak się czuje, użyj tego w następnej odpowiedzi. Ta wypowiedź nie jest zapisanym posiłkiem ani nowym pomiarem. Tego samego faktu nie pytaj ponownie.',
      'Same „dzięki” i „jasne” nie kończą rozmowy. „Pa”, „do widzenia”, „na razie” i „to wszystko” kończą. Powiedz jedno krótkie pożegnanie i w tej samej odpowiedzi wywołaj end_call.',
    ],
    fr: [
      'À une simple salutation, dis seulement la salutation et attends. Ne lance pas le sauna ni une autre activité tant qu\'on ne te le demande pas. Si les premiers mots sont déjà une question, réponds-y.',
      `S'ils demandent la récupération et les repas, utilise seulement les détails de l'appel. Dis le pourcentage et exactement ces mots : ${band.good}, ${band.ok} ou ${band.need_rest}. N'appelle pas « ${band.ok} » moyen. Puis dis ce qui est noté et ce qui reste avant les objectifs. Puis une seule action suivante et sa raison à partir de ces chiffres. L'absence de repas noté ne veut pas dire que la personne n'a pas mangé. Ne propose pas toujours les mêmes aliments : regarde l'écart, les repas notés et l'heure.`,
      'S\'ils demandent s\'il vaut mieux manger avant ou après une activité, utilise l\'heure de cette activité et l\'heure du dernier repas noté. Si l\'heure du repas manque, pose une courte question ou réponds de façon conditionnelle. Ne choisis pas « après » seulement parce que l\'activité est au planning.',
      '« Ça », « cette activité » et « la même » désignent la dernière activité déjà discutée sans ambiguïté, et son ref. Si plusieurs correspondent, demande laquelle. Ne choisis pas la dernière ligne seulement parce qu\'elle est la dernière.',
      'Après un outil, la liste items est déjà le planning actuel. Si la personne dit quelque chose de nouveau, par exemple qu\'elle a déjà mangé ou comment elle se sent, utilise-le dans la réponse suivante. Cette phrase n\'est pas un repas enregistré ni une nouvelle mesure. Ne redemande pas le même fait.',
      'Un simple merci ou « d\'accord » ne termine pas l\'appel. « Au revoir », « à plus » et « c\'est tout » le terminent. Dis un court au revoir et appelle end_call dans la même réponse.',
    ],
    es: [
      'Ante un saludo normal, di solo el saludo y espera. No saques la sauna ni otra actividad si no te lo han pedido. Si las primeras palabras ya son una pregunta, respóndela.',
      `Si preguntan por la recuperación y la comida, usa solo los datos de la llamada. Di el porcentaje y exactamente estas palabras: ${band.good}, ${band.ok} o ${band.need_rest}. No llames «${band.ok}» media. Luego di lo que está anotado y lo que falta para los objetivos. Luego una sola acción siguiente y su motivo con esos números. Que no haya una comida anotada no significa que la persona no haya comido. No ofrezcas siempre los mismos alimentos: mira el hueco, las comidas anotadas y la hora.`,
      'Si preguntan si comer antes o después de una actividad, usa la hora de esa actividad y la hora de la última comida anotada. Si falta la hora de la comida, haz una pregunta corta o responde de forma condicional. No elijas «después» solo porque la actividad está en el plan.',
      '«Esa», «esa actividad» y «la misma» son la última actividad que ya se habló sin ambigüedad, y su ref. Si encajan varias, pregunta cuál. No elijas la última fila solo porque es la última.',
      'Después de una herramienta, la lista items ya es el plan actual. Si la persona cuenta algo nuevo, por ejemplo que ya comió o cómo se siente, úsalo en la siguiente respuesta. Esa frase no es una comida guardada ni una medición nueva. No vuelvas a pedir el mismo dato.',
      'Un simple gracias o «vale» no termina la llamada. «Adiós», «hasta luego» y «eso es todo» sí. Di una despedida corta y llama a end_call en esa misma respuesta.',
    ],
    de: [
      'Auf einen normalen Gruß sag nur den Gruß und warte. Sprich Sauna oder eine andere Aktivität nicht an, solange niemand danach fragt. Wenn die ersten Worte schon eine Frage sind, beantworte sie.',
      `Fragen sie nach Erholung und Essen, nutze nur die Anrufdetails. Nenne den Prozentwert und genau diese Wörter: ${band.good}, ${band.ok} oder ${band.need_rest}. Nenne „${band.ok}“ nicht mittel. Dann sag, was eingetragen ist und was bis zu den Zielen fehlt. Dann eine nächste Handlung und den Grund aus diesen Zahlen. Kein eingetragenes Essen heißt nicht, dass die Person nicht gegessen hat. Schlage nicht immer dieselben Lebensmittel vor: nimm die Lücke, die Einträge und die Uhrzeit.`,
      'Fragen sie, ob sie vor oder nach einer Aktivität essen sollen, nutze die Uhrzeit dieser Aktivität und die Uhrzeit der letzten eingetragenen Mahlzeit. Fehlt die Uhrzeit der Mahlzeit, stell eine kurze Frage oder antworte bedingt. Wähle nicht „danach“ nur, weil die Aktivität im Plan steht.',
      '„Sie“, „diese Aktivität“ und „dieselbe“ meinen die letzte Aktivität, die schon eindeutig besprochen wurde, und ihre ref. Passen mehrere, frag welche. Wähle nicht den letzten Eintrag nur, weil er der letzte ist.',
      'Nach einem Werkzeug ist die Liste items schon der aktuelle Plan. Sagt die Person etwas Neues, etwa dass sie schon gegessen hat oder wie sie sich fühlt, nutze das in der nächsten Antwort. Dieser Satz ist keine gespeicherte Mahlzeit und keine neue Messung. Dieselbe Angabe frag nicht noch einmal.',
      'Ein bloßes Danke oder „alles klar“ beendet den Anruf nicht. „Tschüss“, „bis dann“ und „das war alles“ schon. Sag einen kurzen Abschied und rufe end_call in derselben Antwort auf.',
    ],
    it: [
      'A un saluto normale di\' solo il saluto e aspetta. Non tirare fuori la sauna o un\'altra attività se non te l\'hanno chiesta. Se le prime parole sono già una domanda, rispondi a quella.',
      `Se chiedono recupero e pasti, usa solo i dettagli della chiamata. Di\' la percentuale e esattamente queste parole: ${band.good}, ${band.ok} o ${band.need_rest}. Non chiamare «${band.ok}» media. Poi di\' che cosa è annotato e quanto manca agli obiettivi. Poi una sola azione successiva e il motivo da quei numeri. Nessun pasto annotato non vuol dire che la persona non abbia mangiato. Non proporre sempre gli stessi cibi: guarda il divario, i pasti annotati e l\'ora.`,
      'Se chiedono se mangiare prima o dopo un\'attività, usa l\'ora di quell\'attività e l\'ora dell\'ultimo pasto annotato. Se manca l\'ora del pasto, fai una domanda breve o rispondi in modo condizionale. Non scegliere «dopo» solo perché l\'attività è nel piano.',
      '«Quella», «quell\'attività» e «la stessa» sono l\'ultima attività già discussa senza ambiguità, e il suo ref. Se ne corrispondono più di una, chiedi quale. Non scegliere l\'ultima riga solo perché è l\'ultima.',
      'Dopo uno strumento, la lista items è già il piano attuale. Se la persona dice qualcosa di nuovo, per esempio che ha già mangiato o come si sente, usalo nella risposta successiva. Quella frase non è un pasto salvato né una nuova misura. Non richiedere lo stesso dato.',
      'Un semplice grazie o «va bene» non chiude la chiamata. «Ciao», «a dopo» e «è tutto» sì. Di\' un breve commiato e chiama end_call nella stessa risposta.',
    ],
    ja: [
      '普通の挨拶には挨拶だけを言って待つ。相手が聞くまでサウナや別の予定を持ち出さない。最初の言葉がすでに質問なら、その質問に答える。',
      `回復と食事を聞かれたら、通話の内容だけを使う。パーセントと、次の言葉をそのまま言う：${band.good}、${band.ok}、${band.need_rest}。「${band.ok}」を平均と呼ばない。それから記録された食事と、目標までの残りを言う。それから次の一つだけと、その数字が理由であることを言う。食事の記録がないことは、食べていないという意味ではない。毎回同じ食べ物を出さない。不足、記録、時刻を見る。`,
      '予定の前に食べるか後に食べるかを聞かれたら、その予定の時刻と最後に記録された食事の時刻を使う。食事の時刻がなければ、短い質問を一つするか、条件つきで答える。予定があるというだけで「後」を選ばない。',
      '「それ」「その予定」「同じもの」は、すでに一意に話した最後の予定とその ref を指す。複数が当たるならどれか聞く。最後の行だからという理由だけでは選ばない。',
      'ツールのあと、items が今の予定である。相手が新しい事情を言ったら、たとえばもう食べた、気分がこうだ、それを次の返事に使う。その発言は保存された食事でも新しい測定でもない。同じ事実を聞き直さない。',
      '「ありがとう」や「わかった」だけでは切らない。「じゃあね」「またね」「以上です」で切る。短い別れを一言言って、同じ応答で end_call を呼ぶ。',
    ],
    ko: [
      '평범한 인사에는 인사만 하고 기다린다. 상대가 묻기 전에는 사우나나 다른 활동을 꺼내지 않는다. 첫 말이 이미 질문이면 그 질문에 답한다.',
      `회복과 식사를 물으면 통화 내용만 쓴다. 퍼센트와 이 말을 그대로 한다: ${band.good}, ${band.ok}, ${band.need_rest}. 「${band.ok}」를 평균이라고 하지 않는다. 그다음 기록된 식사와 목표까지 남은 양을 말한다. 그다음 다음 행동 하나와 그 숫자가 이유임을 말한다. 식사 기록이 없다는 것은 먹지 않았다는 뜻이 아니다. 매번 같은 음식을 권하지 않는다. 부족한 양, 기록, 시각을 본다.`,
      '활동 전에 먹을지 후에 먹을지 물으면 그 활동의 시각과 마지막으로 기록된 식사의 시각을 쓴다. 식사 시각이 없으면 짧은 질문 하나를 하거나 조건부로 답한다. 활동이 있다는 이유만으로 「후」를 고르지 않는다.',
      '「그거」, 「그 활동」, 「같은 것」은 이미 하나로 이야기한 마지막 활동과 그 ref다. 여러 개가 맞으면 어느 것인지 묻는다. 마지막 줄이라는 이유만으로 고르지 않는다.',
      '도구 뒤에 items가 현재 계획이다. 상대가 새 사정을 말하면, 예를 들어 이미 먹었다거나 컨디션이 어떻다거나, 다음 답에 그것을 쓴다. 그 말은 저장된 식사도 새 측정도 아니다. 같은 사실을 다시 묻지 않는다.',
      '「고마워」나 「알겠어」만으로는 통화를 끝내지 않는다. 「잘 가」, 「나중에 봐」, 「이걸로 끝」이면 끝낸다. 짧은 작별 한 마디를 하고 같은 응답에서 end_call을 호출한다.',
    ],
    'zh-Hans': [
      '普通问候只说问候，然后等。对方没有问，就不要提起桑拿或其他活动。如果开口已经是问题，就回答那个问题。',
      `问到恢复和饮食时，只用这通电话里的资料。说出百分比，并原样使用这些词：${band.good}、${band.ok}、${band.need_rest}。不要把「${band.ok}」说成一般。然后说已记录的饮食，以及离目标还差多少。然后只给一个下一步，并用这些数字说明原因。没有饮食记录不等于没吃。不要每次都推荐同样的食物：看缺口、已记录的餐和钟点。`,
      '问到活动前吃还是活动后吃，用这个活动的时间和最近一次已记录用餐的时间。如果没有用餐时间，就问一个短问题，或者有条件地回答。不要只因为计划里有这个活动就选「之后」。',
      '「它」「这个活动」「同一个」指已经明确谈过的最后一个活动，以及它的 ref。如果有几个都符合，就问是哪一个。不要只因为它是最后一行就选它。',
      '工具返回之后，items 就是当前计划。如果对方说出新情况，比如已经吃过，或者现在感觉如何，就在下一句里用上。这句话不是已保存的一餐，也不是一次新测量。不要再问同一个事实。',
      '单独的「谢谢」或「知道了」不结束通话。「再见」「回头见」「就这些」才结束。说一句短告别，并在同一轮调用 end_call。',
    ],
  };
  return (rules[code] || rules.en).concat([deliveryRules(code)]).join('\n');
}

function deliveryRules(language) {
  const lines = {
    ru: 'Рекомендацию формулируй как предложение, не приказ. Не говори «ешь свой…». Не называй продукт низкокалорийным или богатым белком без данных о продукте и порции. В речи округляй расчётные калории до десятка: «около 1780», не «примерно 1782». Точные числа оставляй в данных. Остаток калорий — это дневная цель минус записанное потребление. Не называй его обязательной едой и не советуй автоматически добирать весь остаток. На «что это значит?» объясни практический смысл числа. Для конкретной рекомендации учти остаток белка, время дня и полноту дневника. Не заменяй объяснение словами «обычная еда, без спешки».',
    en: 'Phrase a recommendation as a suggestion, not an order. Do not say "eat your…". Do not call a food low-calorie or high-protein without data about the product and the portion. In speech, round calculated calories to the nearest ten: "about 1780", not "about 1782". Keep exact numbers in the data. Remaining calories are the daily goal minus logged intake. Do not treat that as a required amount of food and do not automatically tell them to eat the whole remainder. If they ask what a number means, explain its practical meaning. A specific suggestion also uses remaining protein, the time of day, and how complete the diary is. Do not replace that explanation with "ordinary food, no rush".',
    pl: 'Zalecenie formułuj jako propozycję, nie polecenie. Nie mów „zjedz swoje…”. Nie nazywaj produktu niskokalorycznym ani bogatym w białko bez danych o produkcie i porcji. W mowie zaokrąglaj wyliczone kalorie do dziesiątki: „około 1780”, nie „około 1782”. Dokładne liczby zostaw w danych. Reszta kalorii to cel dzienny minus zapisane spożycie. Nie przedstawiaj jej jako obowiązkowej porcji i nie radź automatycznie zjadać całości. Na „co to znaczy?” wyjaśnij praktyczny sens liczby. Do konkretnej propozycji weź też resztę białka, porę dnia i kompletność dziennika. Nie zastępuj wyjaśnienia słowami „zwykłe jedzenie, bez pośpiechu”.',
    fr: 'Formule une recommandation comme une proposition, pas un ordre. Ne dis pas « mange ton… ». N\'appelle pas un aliment peu calorique ou riche en protéines sans données sur le produit et la portion. À l\'oral, arrondis les calories calculées à la dizaine : « environ 1780 », pas « environ 1782 ». Garde les valeurs exactes dans les données. Le reste de calories est l\'objectif du jour moins ce qui est noté. Ne le présente pas comme une quantité obligatoire et ne conseille pas automatiquement de tout finir. À « qu\'est-ce que ça veut dire ? », explique le sens pratique du nombre. Une suggestion précise tient aussi compte des protéines restantes, de l\'heure et du journal complet ou non. Ne remplace pas l\'explication par « un repas ordinaire, sans se presser ».',
    es: 'Formula la recomendación como una propuesta, no como una orden. No digas «cómete tu…». No llames a un producto bajo en calorías o rico en proteína sin datos del producto y de la porción. Al hablar, redondea las calorías calculadas a la decena: «unos 1780», no «unos 1782». Deja los valores exactos en los datos. Las calorías que quedan son la meta del día menos lo registrado. No las presentes como una cantidad obligatoria y no aconsejes automáticamente comer todo el resto. Si preguntan «¿qué significa esto?», explica el sentido práctico del número. Una sugerencia concreta también usa la proteína que queda, la hora y si el diario está completo. No sustituyas la explicación por «comida normal, sin prisa».',
    de: 'Formuliere eine Empfehlung als Vorschlag, nicht als Befehl. Sag nicht „iss dein…“. Nenne ein Lebensmittel nicht kalorienarm oder eiweißreich ohne Angaben zu Produkt und Portion. Sprich berechnete Kalorien auf zehn gerundet: „etwa 1780“, nicht „etwa 1782“. Genaue Werte bleiben in den Daten. Die übrigen Kalorien sind das Tagesziel minus das Eingetragene. Das ist keine Pflichtmenge und kein Grund, automatisch alles aufzuessen. Auf „was bedeutet das?“ erkläre den praktischen Sinn der Zahl. Ein konkreter Vorschlag berücksichtigt auch das übrige Protein, die Tageszeit und wie vollständig das Tagebuch ist. Ersetze die Erklärung nicht durch „normales Essen, ohne Eile“.',
    it: 'Formula il consiglio come una proposta, non come un ordine. Non dire «mangia il tuo…». Non chiamare un alimento ipocalorico o ricco di proteine senza dati sul prodotto e sulla porzione. A voce, arrotonda le calorie calcolate alla decina: «circa 1780», non «circa 1782». Lascia i valori esatti nei dati. Le calorie restanti sono l\'obiettivo del giorno meno quanto è registrato. Non presentarle come una quantità obbligatoria e non consigliare automaticamente di finirle tutte. A «che cosa significa?», spiega il senso pratico del numero. Un consiglio concreto considera anche le proteine rimaste, l\'ora e quanto è completo il diario. Non sostituire la spiegazione con «cibo normale, senza fretta».',
    ja: '提案は命令にしない。「自分の…を食べて」と言わない。食品と分量のデータがなければ、低カロリーや高たんぱくとは言わない。話すときは計算したカロリーを十の位に丸める。「約1780」であり「約1782」ではない。正確な数値はデータに残す。残りのカロリーは一日の目標から記録した摂取を引いた差である。必ず食べる量として扱わず、残りを全部食べるよう自動では勧めない。「これはどういう意味？」には数の実際の意味を説明する。具体的な提案では残りのたんぱく質、時刻、日記が揃っているかも見る。「普通の食事で急がなくていい」で説明を代えない。',
    ko: '권유는 제안으로 말하고 명령으로 하지 않는다. “네 …를 먹어”라고 하지 않는다. 식품과 분량 데이터가 없으면 저칼로리나 고단백이라고 하지 않는다. 말할 때는 계산된 칼로리를 십 단위로 반올림한다. “약 1780”이지 “약 1782”가 아니다. 정확한 값은 데이터에 둔다. 남은 칼로리는 하루 목표에서 기록된 섭취를 뺀 차이다. 꼭 먹어야 하는 양으로 말하지 않고, 나머지를 다 먹으라고 자동으로 권하지 않는다. “이게 무슨 뜻이야?”에는 숫자의 실제 의미를 설명한다. 구체적인 제안에는 남은 단백질, 시각, 일기가 얼마나 채워졌는지도 본다. “평범한 식사, 서두르지 마”로 설명을 바꾸지 않는다.',
    'zh-Hans': '建议说成提议，不要说成命令。不要说「吃掉你的…」。没有食物和分量的数据，就不要说它低热量或高蛋白。说话时把算出的热量四舍五入到十位：「大约1780」，不是「大约1782」。精确数字留在数据里。剩余热量是每日目标减去已记录摄入。不要把它说成必须吃完的量，也不要自动建议把差额全部补上。问「这是什么意思？」时，解释这个数字的实际含义。具体建议还要看剩余蛋白质、时间，以及日记是否记全。不要用「普通的饭，不用着急」代替解释。',
  };
  return lines[language] || lines.en;
}

function addressRule(language, addressee) {
  const sex = addressee === 'female' || addressee === 'male' ? addressee : 'unknown';
  const label = {
    ru: { female: 'женский', male: 'мужской', unknown: 'неизвестен' },
    en: { female: 'female', male: 'male', unknown: 'unknown' },
    pl: { female: 'żeński', male: 'męski', unknown: 'nieznany' },
    fr: { female: 'féminin', male: 'masculin', unknown: 'inconnu' },
    es: { female: 'femenino', male: 'masculino', unknown: 'desconocido' },
    de: { female: 'weiblich', male: 'männlich', unknown: 'unbekannt' },
    it: { female: 'femminile', male: 'maschile', unknown: 'sconosciuto' },
    ja: { female: '女性', male: '男性', unknown: '不明' },
    ko: { female: '여성', male: '남성', unknown: '알 수 없음' },
    'zh-Hans': { female: '女', male: '男', unknown: '未知' },
  }[language] || { female: 'female', male: 'male', unknown: 'unknown' };
  const lines = {
    ru: `О себе говори в женском роде: «я добавила», «я перенесла». Поле профиля сейчас: ${label[sex]}. Род человека бери только из этого поля. По голосу и имени его не определяй. Если поле неизвестно, не согласуй слова с человеком: «Восстановление — 77%», «Сегодня можно выбрать лёгкую нагрузку». Класс восстановления называй по шкале, не «ты умеренно готова».`,
    en: `Speak about yourself in the feminine where the language marks it. The profile field is ${label[sex]}. Use that field only. Do not infer it from the voice or the name. If it is unknown, do not attach a gendered adjective to the person: say "Recovery is 77 percent" and "A light session is an option today". Name the recovery band from the scale, not "you are moderately ready".`,
    pl: `O sobie mów w rodzaju żeńskim, jeśli język to zaznacza. Pole profilu: ${label[sex]}. Bierz je tylko stamtąd. Nie wnioskuj z głosu ani z imienia. Gdy jest nieznane, nie odmieniaj przymiotnika przy osobie: „Regeneracja — 77%”, „Dziś można wybrać lekkie obciążenie”. Klasę regeneracji nazywaj według skali.`,
    fr: `Parle de toi au féminin quand la langue le marque. Champ du profil : ${label[sex]}. Ne le prends que là. Ne le déduis pas de la voix ni du prénom. S'il est inconnu, n'accorde pas un adjectif avec la personne : « Récupération — 77 % », « Aujourd'hui, une charge légère est possible ». Nomme la classe selon l'échelle.`,
    es: `Habla de ti en femenino cuando el idioma lo marca. Campo del perfil: ${label[sex]}. Úsalo solo desde ahí. No lo deduzcas de la voz ni del nombre. Si es desconocido, no concuerdes un adjetivo con la persona: «Recuperación — 77%», «Hoy se puede elegir una carga ligera». Nombra la clase según la escala.`,
    de: `Sprich über dich im Femininum, wo die Sprache es markiert. Profilfeld: ${label[sex]}. Nimm es nur von dort. Schließe es nicht aus der Stimme oder dem Namen. Ist es unbekannt, hänge kein Genus an die Person: „Erholung — 77 %“, „Heute kann eine leichte Belastung gewählt werden“. Nenne die Stufe nach der Skala.`,
    it: `Parla di te al femminile dove la lingua lo segna. Campo del profilo: ${label[sex]}. Prendilo solo da lì. Non dedurlo dalla voce o dal nome. Se è sconosciuto, non concordare un aggettivo con la persona: «Recupero — 77%», «Oggi si può scegliere un carico leggero». Nomina la classe secondo la scala.`,
    ja: `自分のことは女性として話す。プロフィールの値は${label[sex]}。それだけを使う。声や名前から決めない。不明なら人に性別のある言い方をしない。「回復は77%」「今日は軽い負荷を選べる」。回復の段階は尺度の名前で言う。`,
    ko: `자기 자신은 여성으로 말한다. 프로필 값은 ${label[sex]}이다. 거기에서만 가져온다. 목소리나 이름으로 정하지 않는다. 알 수 없으면 사람에게 성별이 드러나는 말을 붙이지 않는다. 「회복은 77%」, 「오늘은 가벼운 부하를 고를 수 있다」. 회복 단계는 척도 이름으로 말한다.`,
    'zh-Hans': `说到自己用女性。档案字段现在是${label[sex]}。只使用这个字段。不要根据声音或名字判断。如果未知，不要把带性别的形容词安到对方身上：「恢复是77%」，「今天可以选择轻负荷」。恢复等级用量表上的名称。`,
  };
  return lines[language] || lines.en;
}

const LIVE_LIMIT = {
  ru: 'Этот звонок меняет только сегодняшний план. Еду, здоровье, цели и завершённые записи не меняй. Другой день не планируй. Если просят сменить язык, говори на нём до конца звонка и не меняй язык приложения. Обычное «спасибо» звонок не завершает.',
  en: 'This call changes only today\'s plan. Do not change food, health, goals, or completed items, and do not plan another day. If they ask to switch language, speak it for the rest of this call and do not change the app language. A bare thanks does not end the call.',
  pl: 'Ta rozmowa zmienia tylko dzisiejszy plan. Nie zmieniaj jedzenia, zdrowia, celów ani ukończonych pozycji i nie planuj innego dnia. Jeśli poproszą o zmianę języka, mów w nim do końca rozmowy i nie zmieniaj języka aplikacji. Samo „dziękuję” nie kończy rozmowy.',
  fr: 'Cet appel ne change que le plan d\'aujourd\'hui. Ne change pas la nourriture, la santé, les objectifs ni les activités terminées, et ne planifie pas un autre jour. S\'ils demandent une autre langue, parle-la jusqu\'à la fin de l\'appel sans changer la langue de l\'app. Un simple merci ne raccroche pas.',
  es: 'Esta llamada solo cambia el plan de hoy. No cambies comida, salud, objetivos ni actividades terminadas, y no planifiques otro día. Si piden otro idioma, háblalo el resto de la llamada sin cambiar el idioma de la app. Un simple gracias no cuelga.',
  de: 'Dieser Anruf ändert nur den Plan von heute. Ändere nicht Essen, Gesundheit, Ziele oder erledigte Einträge und plane keinen anderen Tag. Wenn sie die Sprache wechseln wollen, sprich sie bis zum Ende und ändere nicht die App-Sprache. Ein bloßes Danke beendet den Anruf nicht.',
  it: 'Questa chiamata cambia solo il piano di oggi. Non cambiare cibo, salute, obiettivi o attività completate e non pianificare un altro giorno. Se chiedono un\'altra lingua, parlala fino alla fine senza cambiare la lingua dell\'app. Un semplice grazie non chiude.',
  ja: 'この通話で変えるのは今日の予定だけ。食事、健康、目標、完了した記録は変えない。別の日は計画しない。言語を変えてほしいと言われたら、この通話の終わりまでその言語で話し、アプリの言語は変えない。ただの「ありがとう」では切らない。',
  ko: '이 통화는 오늘 계획만 바꾼다. 음식, 건강, 목표, 완료된 기록은 바꾸지 않고 다른 날은 계획하지 않는다. 언어를 바꾸자고 하면 이 통화가 끝날 때까지 그 언어로 말하고 앱 언어는 바꾸지 않는다. 단순한 고마워는 통화를 끝내지 않는다.',
  'zh-Hans': '这通电话只改今天的计划。不要改饮食、健康、目标或已完成的记录，也不要安排别的日子。如果对方要求换语言，就用那种语言说到通话结束，不要改应用语言。单独一句谢谢不会结束通话。',
};

export function plannerLiveConfiguration(config, payload) {
  const session = plannerSessionConfiguration(config, payload);
  const language = plannerVoiceLanguage(payload?.language);
  const backend = config.plannerVoiceLiveBackendModel || DEFAULT_LIVE_BACKEND;
  if (!/^gpt-[a-z0-9._-]+$/i.test(backend)) throw new ServiceError('planner_voice_live_unavailable', 503);
  return {
    model: LIVE_MODEL,
    instructions: `${session.instructions}\n${LIVE_LIMIT[language] || LIVE_LIMIT.en}\n${LIVE_OPEN}\nDelegation policy:\nBackend tools:\n- Today's plan, and ending the call.\nGenerate <|SpawnThinking|> when:\n- They ask to add, move, change, or remove a planned activity, or a short follow-up such as "move it" continues that change.\n- They clearly end the call: bye, goodbye, «пока», «до свидания», «до встречи», or «это всё, заканчиваем». The backend must call end_call.\nDo not generate <|SpawnThinking|> for a bare thanks, «спасибо», or «понятно», or when one short clarification is still required.\nGenerate <|SpawnThinking|> before saying that a change was saved. Say the saved activity, time, and duration only from the backend result.`,
    audio: { output: { voice: session.audio.output.voice } },
    input: [{
      type: 'message',
      role: 'developer',
      content: [{ type: 'input_text', text: LIVE_OPEN }],
    }],
    delegation: {
      type: 'responses',
      responses: {
        model: backend,
        instructions: [
          'You choose plan tools for this live call. The application checks ownership and saves. Record ids and tool arguments stay language-independent.',
          'Use the plan, meals, and recovery in the context below. Missing meals do not mean the person did not eat. Do not invent numbers or give a medical diagnosis.',
          'A question or a tentative idea does not call a tool. An explicit request does, without asking "are you sure?".',
          'Resolve "it" or "this one" to the activity just discussed. If several activities match, ask which one and do not call a tool.',
          'create_activity adds one catalog activity. update_activity changes that same ref: time, duration, or both. delete_activity removes that ref. Never create a second activity to move or resize one.',
          'Before and after another activity uses place and anchorRef. If the exact time conflicts, the tool offers one alternative and saves nothing until the caller accepts it.',
          'Say a change happened only when saved is true. Speak the returned speak text: it is the saved activity, time, and duration. If saved is false or the result is unknown, say what failed and call list_plan before trying again.',
          'After a saved change, the returned items are the current plan. Use those refs for the next request.',
          'Change only today, and do not schedule a time that has already passed. Do not change food, health, goals, or completed activities.',
          'Call end_call after one short goodbye when they clearly end the call. Do not call it for thanks or «понятно».',
          session.instructions,
        ].join('\n'),
        tools: [
          createActivityTool(), listPlanTool(), updateActivityTool(), deleteActivityTool(),
          logWaterTool(), remindWaterTool(), endCallTool(), setCallLanguageTool(),
        ],
        tool_choice: 'auto',
        parallel_tool_calls: false,
      },
    },
  };
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
  const addressee = payload?.addressee === 'female' || payload?.addressee === 'male' ? payload.addressee : 'unknown';
  const session = {
    type: 'realtime',
    model: config.plannerVoiceLanguageModel && config.plannerVoiceLanguageModelLanguages?.includes(language)
      ? config.plannerVoiceLanguageModel : config.plannerVoiceModel,
    instructions: instructions(days, planningDay, safeName, language, plan, dayContext, introduced, reconnected, addressee),
    tools: [createActivityTool(), listPlanTool(), updateActivityTool(), deleteActivityTool(), logWaterTool(), remindWaterTool(), endCallTool()],
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
    const catalogTitle = String(item.catalogTitle || '').replace(/[\r\n]/g, ' ').trim().slice(0, 80);
    rows.push({
      ref,
      scope,
      title,
      catalogTitle: BY_TITLE.has(catalogTitle) ? catalogTitle : '',
      startTime,
      durationMinutes: duration,
    });
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
  const carbsGrams = boundedInteger(raw.carbsGrams, 0, 2000);
  const carbsGoalGrams = boundedInteger(raw.carbsGoalGrams, 1, 2000);
  const fatGrams = boundedInteger(raw.fatGrams, 0, 1000);
  const fatGoalGrams = boundedInteger(raw.fatGoalGrams, 1, 1000);
  const waterMilliliters = boundedInteger(raw.waterMilliliters, 0, 20000);
  const waterGoalMilliliters = boundedInteger(raw.waterGoalMilliliters, 1, 20000);
  const foodGoal = ['lose', 'maintain', 'gain'].includes(raw.goal) ? raw.goal : null;
  if (caloriesEaten != null) nutrition.caloriesEaten = caloriesEaten;
  if (caloriesBudget != null) nutrition.caloriesBudget = caloriesBudget;
  if (proteinGrams != null) nutrition.proteinGrams = proteinGrams;
  if (proteinGoalGrams != null) nutrition.proteinGoalGrams = proteinGoalGrams;
  if (carbsGrams != null) nutrition.carbsGrams = carbsGrams;
  if (carbsGoalGrams != null) nutrition.carbsGoalGrams = carbsGoalGrams;
  if (fatGrams != null) nutrition.fatGrams = fatGrams;
  if (fatGoalGrams != null) nutrition.fatGoalGrams = fatGoalGrams;
  if (waterMilliliters != null) nutrition.waterMilliliters = waterMilliliters;
  if (waterGoalMilliliters != null) nutrition.waterGoalMilliliters = waterGoalMilliliters;
  if (foodGoal) nutrition.goal = foodGoal;
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

function spokenCalorieCount(value) {
  const sign = value < 0 ? -1 : 1;
  const magnitude = Math.abs(value);
  const rounded = magnitude < 50 ? magnitude : Math.round(magnitude / 10) * 10;
  return sign * rounded;
}

function spokenCaloriePair(eaten, budget, language) {
  const said = spokenCalorieCount(eaten);
  const goal = spokenCalorieCount(budget);
  const lines = {
    ru: `вслух около ${said} из около ${goal}`,
    en: `say about ${said} of about ${goal}`,
    pl: `powiedz około ${said} z około ${goal}`,
    fr: `dis environ ${said} sur environ ${goal}`,
    es: `di unos ${said} de unos ${goal}`,
    de: `sag etwa ${said} von etwa ${goal}`,
    it: `di' circa ${said} di circa ${goal}`,
    ja: `話すときは約${said}、目標は約${goal}`,
    ko: `말할 때는 약 ${said}, 목표는 약 ${goal}`,
    'zh-Hans': `说话时大约${said}，目标大约${goal}`,
  };
  return lines[language] || lines.en;
}

function calorieGapLine(left, language) {
  const spoken = spokenCalorieCount(left);
  const lines = {
    ru: `разница между дневной целью и записанным потреблением: точно ${left}, вслух около ${spoken}. Это не обязательный объём еды и не повод советовать добрать весь остаток`,
    en: `difference between the daily goal and logged intake: exactly ${left}, say about ${spoken}. This is not a required amount of food and not a reason to eat the whole remainder`,
    pl: `różnica między celem dziennym a zapisanym spożyciem: dokładnie ${left}, powiedz około ${spoken}. To nie jest obowiązkowa ilość jedzenia i nie powód, by radzić zjeść całość`,
    fr: `différence entre l'objectif du jour et ce qui est noté : exactement ${left}, dis environ ${spoken}. Ce n'est pas une quantité obligatoire et pas une raison de tout finir`,
    es: `diferencia entre la meta del día y lo registrado: exactamente ${left}, di unos ${spoken}. No es una cantidad obligatoria ni un motivo para comer todo el resto`,
    de: `Differenz zwischen Tagesziel und Eingetragenem: genau ${left}, sag etwa ${spoken}. Das ist keine Pflichtmenge und kein Grund, alles aufzuessen`,
    it: `differenza tra l'obiettivo del giorno e quanto è registrato: esattamente ${left}, di' circa ${spoken}. Non è una quantità obbligatoria e non un motivo per finirla tutta`,
    ja: `一日の目標と記録した摂取の差: 正確には${left}、話すときは約${spoken}。必ず食べる量ではなく、残りを全部食べる理由でもない`,
    ko: `하루 목표와 기록된 섭취의 차이: 정확히는 ${left}, 말할 때는 약 ${spoken}. 꼭 먹어야 하는 양이 아니고 나머지를 다 먹을 이유도 아니다`,
    'zh-Hans': `每日目标与已记录摄入的差：精确是${left}，说话时大约${spoken}。这不是必须吃完的量，也不是把差额全部补上的理由`,
  };
  return lines[language] || lines.en;
}

function dayContextLine(dayContext, language) {
  const facts = voiceGuide(language).facts;
  if (!dayContext) return facts.none;
  const parts = [];
  if (dayContext.recovery) {
    const recovery = dayContext.recovery;
    const bits = [];
    if (recovery.percent) bits.push(facts.percent(recovery.percent));
    if (recovery.band) {
      const words = (RECOVERY_BAND[language] || RECOVERY_BAND.en)[recovery.band];
      if (words) bits.push(facts.band(words));
    }
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
      bits.push(spokenCaloriePair(nutrition.caloriesEaten, nutrition.caloriesBudget, language));
      const left = nutrition.caloriesBudget - nutrition.caloriesEaten;
      bits.push(calorieGapLine(left, language));
    } else if (nutrition.caloriesEaten != null) {
      bits.push(facts.eaten(nutrition.caloriesEaten));
    }
    if (nutrition.proteinGrams != null && nutrition.proteinGoalGrams != null) {
      bits.push(facts.proteinOf(nutrition.proteinGrams, nutrition.proteinGoalGrams));
    } else if (nutrition.proteinGrams != null) {
      bits.push(facts.protein(nutrition.proteinGrams));
    }
    if (nutrition.carbsGrams != null && nutrition.carbsGoalGrams != null && facts.carbsOf) {
      bits.push(facts.carbsOf(nutrition.carbsGrams, nutrition.carbsGoalGrams));
    }
    if (nutrition.fatGrams != null && nutrition.fatGoalGrams != null && facts.fatsOf) {
      bits.push(facts.fatsOf(nutrition.fatGrams, nutrition.fatGoalGrams));
    }
    if (nutrition.goal && facts.foodGoal) {
      const name = nutrition.goal === 'lose' ? facts.goalLose
        : nutrition.goal === 'gain' ? facts.goalGain
        : facts.goalMaintain;
      if (name) bits.push(facts.foodGoal(name));
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

function instructions(days, planningDay, givenName, language, plan = [], dayContext = null, introduced = false, reconnected = false, addressee = 'unknown') {
  const phrases = plannerVoicePhrases(language);
  const catalog = CATALOG.map(item => (
    `${item.catalogTitle} = ${spokenActivityName(item.catalogTitle, language)} (${item.defaultDurationMinutes} min, ${item.plannerTypeTitle})`
  )).join('; ');
  const guide = voiceGuide(language);
  const rows = plan.map(item => {
    const name = item.catalogTitle && item.catalogTitle !== item.title
      ? `${item.title} [${item.catalogTitle}]`
      : item.title;
    return `${item.ref} ${item.scope} ${name} ${item.startTime} ${item.durationMinutes}m (${guide.facts.say} ${spokenClock(item.startTime, language)})`;
  }).join('; ');
  return [
    ...guide.rules(phrases, catalog),
    answerRules(language),
    guide.marker,
    givenName ? guide.name(givenName) : guide.noName,
    guide.introduced(introduced),
    reconnected ? guide.reconnected : guide.opening(greetingLine(language, givenName, introduced)),
    addressRule(language, addressee),
    guide.dates(days, planningDay),
    dayContextLine(dayContext, language),
    plan.length ? guide.plan(rows) : guide.emptyPlan,
  ].join('\n');
}
function createActivityTool() {
  return {
    type: 'function',
    name: 'create_activity',
    description: 'Create one catalog activity. Not a meal, not water already drunk, and not a water reminder. For before or after one plan item, set place to before or after and anchorRef to its ref, and leave startTime empty. Do not ask for a clock time when that ref is unique. Say the speak field once, and only after saved is true.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        catalogTitle: { type: 'string', enum: CATALOG.map(item => item.catalogTitle) },
        date: { type: 'string', description: 'YYYY-MM-DD in the user time zone, or an empty string when the day was not spoken.' },
        startTime: { type: 'string', description: 'HH:mm, 24-hour. Empty when place and anchorRef choose the time.' },
        durationMinutes: { type: 'integer', description: 'Minutes. 0 when the person did not say a duration.' },
        place: { type: 'string', enum: ['', 'before', 'after'], description: 'Empty unless the time is before or after another plan item.' },
        anchorRef: { type: 'string', description: 'Plan ref such as a1. Empty unless place is before or after.' },
      },
      required: ['catalogTitle', 'date', 'startTime', 'durationMinutes', 'place', 'anchorRef'],
    },
  };
}

function listPlanTool() {
  return {
    type: 'function',
    name: 'list_plan',
    description: 'Read the plan before suggesting an activity or a time. items has ref, title, startTime, durationMinutes, and done. Do not read speak aloud. ok false means the plan was not read: say so. This does not save anything.',
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

function logWaterTool() {
  return {
    type: 'function',
    name: 'log_water',
    description: 'Record water the person already drank, in milliliters. This is the only way to increase water already drunk. Do not use it for a reminder or a plan activity. Do not invent an amount: if they did not say one, ask once. A glass is 250.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        milliliters: { type: 'integer', description: 'Milliliters already drunk, from 50 to 2000. 0 when they did not say an amount.' },
      },
      required: ['milliliters'],
    },
  };
}

function remindWaterTool() {
  return {
    type: 'function',
    name: 'remind_water',
    description: 'Put a water reminder on the plan. It does not increase water already drunk and it is not a 15-minute activity. For before or after one plan item, set place and anchorRef and leave startTime empty. Do not ask for a clock time when that ref is unique.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        date: { type: 'string', description: 'YYYY-MM-DD, or empty for today.' },
        startTime: { type: 'string', description: 'HH:mm, or empty when place and anchorRef choose the time.' },
        place: { type: 'string', enum: ['', 'before', 'after'] },
        anchorRef: { type: 'string', description: 'Plan ref such as a1. Empty unless place is before or after.' },
      },
      required: ['date', 'startTime', 'place', 'anchorRef'],
    },
  };
}

function setCallLanguageTool() {
  return {
    type: 'function',
    name: 'set_call_language',
    description: 'Switch the spoken language for the rest of this call only. Does not change the app language setting.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        language: { type: 'string', enum: ['ru', 'en', 'zh-Hans', 'ko', 'ja', 'de', 'it', 'pl', 'fr', 'es'] },
      },
      required: ['language'],
    },
  };
}

function endCallTool() {
  return {
    type: 'function',
    name: 'end_call',
    description: 'Hang up after a short farewell when the person clearly wants to end the call. «пока», «до свидания», «до встречи», «это всё, заканчиваем», «всё, спасибо», «все спасибо» and «спасибо, всё» are explicit endings. A short «До встречи.» is enough. Say that farewell, then call this in the same response so the session ends. A bare спасибо, понятно, alright, okay, or thanks is not an ending. Do not announce that you are ending the call. Do not use this before a save is confirmed. Do not call this in a response that has no spoken farewell.',
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
