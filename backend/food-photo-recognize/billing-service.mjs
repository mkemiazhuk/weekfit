import path from 'node:path';
import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';
import { BillingStore, TOPUPS, hash } from './billing-store.mjs';
import { createAppleBilling } from './billing-apple.mjs';
import { recognize, validateInput, ServiceError } from './recognition.mjs';
import { plannerSessionConfiguration } from './planner-voice.mjs';
import { createConcurrencyGate } from './concurrency.mjs';

const error = (code, status) => { throw new ServiceError(code, status); };
async function json(req) {
  let size = 0; const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 12 * 1024 * 1024) error('request_too_large', 413);
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { error('invalid_json', 400); }
}
const send = (res, status, body) => {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
};

export function createBillingService(config, { authenticate, apple, store, fetcher = fetch,
  analyze = recognize, connectObserver, line, log = entry => console.info(JSON.stringify(entry)) } = {}) {
  if (!config.billingEnabled) return { handle: async () => false, close() {} };
  if (!config.dataDirExplicit || config.stateBackend === 'redis' || !config.allowSingleNode) {
    throw Error('AI billing requires one API process and an explicit persistent DATA_DIR');
  }
  apple ??= createAppleBilling();
  store ??= new BillingStore(path.join(config.dataDir, `billing-${apple.environment}.sqlite`),
    { maxVoiceCalls: config.plannerVoiceMaxCalls ?? 5 });
  const gate = createConcurrencyGate({ maxConcurrent: config.maxConcurrency ?? 4, maxQueue: 1000,
    queueWaitMs: 120000, retryAfterSeconds: 5 });
  const inflight = new Map(), sessions = new Map(), stopping = new Map();
  let closing = false;
  const context = async (req, requireActive = true) => {
    const uid = await authenticate(req.headers.authorization, config);
    const jws = req.headers['x-weekfit-subscription-jws'];
    if (typeof jws !== 'string' || jws.length > 200000) error('subscription_required', 402);
    const subscription = await apple.subscription(jws);
    if (requireActive && !subscription.active) error('subscription_required', 402);
    return { subscription, wallet: store.wallet(subscription), uid };
  };
  const hangup = async (op) => {
    if (!op.callId) return;
    const response = await fetcher(`https://api.openai.com/v1/realtime/calls/${encodeURIComponent(op.callId)}/hangup`, {
      method: 'POST', headers: { Authorization: `Bearer ${config.apiKey}` }, signal: AbortSignal.timeout(5000),
    });
    if (!response.ok && response.status !== 404 && response.status !== 410) error('voice_stop_pending', 503);
  };
  const stop = (wallet, key, uncertain = false) => {
    const identifier = `${wallet}:${key}`;
    if (stopping.has(identifier)) return stopping.get(identifier);
    const task = (async () => {
      const op = store.operation(wallet, key);
      if (!op || op.state !== 'reserved') return;
      await hangup(op); // Keep reserved until provider confirms closure.
      const seconds = !uncertain && op.started
        ? Math.min(op.included + op.purchased, Math.max(0, Math.ceil((Date.now() - op.started) / 1000))) : 0;
      store.settle(wallet, key, seconds);
      const live = sessions.get(identifier);
      live?.socket?.close();
      if (live?.uid && live?.ticket) line?.release(live.uid, live.ticket);
      sessions.delete(identifier);
      log({ event: 'billing_voice_settled', seconds });
    })();
    stopping.set(identifier, task);
    void task.finally(() => { if (stopping.get(identifier) === task) stopping.delete(identifier); }).catch(() => {});
    return task;
  };
  const attachObserver = connectObserver ?? ((callId, onEvent, onFailure) => {
    const socket = new WebSocket(`wss://api.openai.com/v1/realtime?call_id=${encodeURIComponent(callId)}`,
      { headers: { Authorization: `Bearer ${config.apiKey}` }, handshakeTimeout: 5000 });
    socket.on('message', data => { try { onEvent(JSON.parse(String(data))); } catch { onFailure(); } });
    socket.on('error', onFailure);
    socket.on('close', onFailure);
    return socket;
  });
  const sweep = async () => {
    for (const op of store.pending()) {
      const live = sessions.get(`${op.wallet}:${op.key}`);
      if (op.resource === 'photos') {
        // Photos are processed in this process only. On restart the old attempt is refunded
        // and its idempotency key stays terminal; it can never generate a second provider call.
        if (!inflight.has(`${op.wallet}:${op.key}`)) store.settle(op.wallet, op.key, 0);
      } else if (!live || (op.deadline && Date.now() >= op.deadline) || (!op.started && Date.now() - op.created >= 30000)) {
        await stop(op.wallet, op.key, !live).catch(() => log({ event: 'billing_voice_stop_pending' }));
      }
    }
  };
  const ready = sweep();
  const timer = setInterval(() => { if (!closing) void sweep().catch(() => log({ event: 'billing_recovery_failed' })); }, 500);
  timer.unref();

  async function handle(req, res) {
    const route = (req.url ?? '').split('?')[0];
    const paidLineEntry = route === '/v1/planner-voice/line' && req.method === 'POST';
    if (!paidLineEntry && !route.startsWith('/v2/ai/') && route !== '/v2/billing/notifications') return false;
    try {
      await ready;
      if (closing) error('billing_unavailable', 503);
      if (paidLineEntry) { await context(req); return false; }
      if (route === '/v2/billing/notifications' && req.method === 'POST') {
        const body = await json(req);
        const notification = await apple.notification(body.signedPayload);
        if (['REFUND','REVOKE'].includes(notification.type) && notification.transaction) {
          store.refund(notification.transaction);
        }
        send(res, 200, { ok: true }); return true;
      }
      if (route === '/v2/ai/account' && req.method === 'GET') {
        const uid = await authenticate(req.headers.authorization, config);
        const wallet = req.headers['x-weekfit-subscription-jws']
          ? (await context(req, false)).wallet : store.checkoutWallet(uid, apple.environment);
        send(res, 200, { appAccountToken: wallet.token }); return true;
      }
      const ctx = await context(req, route !== '/v2/ai/usage' && route !== '/v2/ai/purchases' && route !== '/v2/ai/voice/stop');
      const { wallet, subscription } = ctx;
      if (route === '/v2/ai/usage' && req.method === 'GET') {
        send(res, 200, store.snapshot(wallet, subscription)); return true;
      }
      const body = await json(req);
      if (route === '/v2/ai/purchases' && req.method === 'POST') {
        // Delivery of a purchase completed while subscribed must still succeed after expiry.
        const transaction = await apple.purchase(body.signedTransaction);
        store.grant(wallet, transaction);
        send(res, 200, store.snapshot(wallet, subscription)); return true;
      }
      if (route === '/v2/ai/photo' && req.method === 'POST') {
        const input = validateInput(body);
        const key = req.headers['idempotency-key'];
        const fingerprint = hash(JSON.stringify(input));
        const existing = store.operation(wallet.id, key);
        if (existing && existing.fingerprint !== fingerprint) error('idempotency_key_reuse', 409);
        const inflightKey = `${wallet.id}:${key}`;
        let task = inflight.get(inflightKey);
        if (!task) {
          const op = store.reserve(wallet, subscription, 'photos', key, fingerprint);
          if (op.state === 'settled') {
            if (!op.result) error('attempt_failed', 409);
            send(res, 200, JSON.parse(op.result)); return true;
          }
          task = (async () => {
            let slot;
            try {
              slot = await gate.acquire();
              store.claimPhotoAttempt(wallet.id, key, config.maxProviderCallsPerDay ?? config.globalDailyLimit ?? 200);
              const output = await analyze(input, { ...config, observerAttemptKey: hash(`${wallet.id}:${key}`) });
              const result = { ...output.result, model: config.model };
              store.settle(wallet.id, key, result.isFood ? 1 : 0, result);
              store.recordUsage(wallet.id, `photo:${key}`, { feature: 'photo', model: config.model,
                usage: output.usage, pricingVersion: '2026-10-30-estimate', estimatedUsd: 0.02 });
              return result;
            } catch (e) { store.settle(wallet.id, key, 0); throw e; }
            finally { slot?.release(); }
          })();
          inflight.set(inflightKey, task);
        }
        try { send(res, 200, await task); }
        finally { if (inflight.get(inflightKey) === task) inflight.delete(inflightKey); }
        return true;
      }
      if (route === '/v2/ai/voice/session' && req.method === 'POST') {
        if (!config.plannerVoiceEnabled) error('planner_voice_forbidden', 403);
        const key = body.idempotencyKey;
        const admission = line?.claim(ctx.uid, body.ticket);
        if (admission && !admission.ok) error(admission.body.error, admission.status);
        let op;
        try { op = store.reserve(wallet, subscription, 'voice', key, hash(JSON.stringify(body)), 3600); }
        catch (e) { if (admission?.ticket) line.release(ctx.uid, admission.ticket); throw e; }
        if (op.state !== 'reserved' || sessions.has(`${wallet.id}:${key}`) || op.callId) error('voice_already_active', 409);
        sessions.set(`${wallet.id}:${key}`, { session: plannerSessionConfiguration(config, body),
          uid: ctx.uid, ticket: admission?.ticket });
        if (admission?.ticket) line.activate(ctx.uid, admission.ticket);
        send(res, 200, { value: '', model: config.plannerVoiceModel, idleSeconds: config.plannerVoiceIdleSeconds,
          managed: true, sessionId: key, budgetSeconds: op.included + op.purchased });
        return true;
      }
      if (route === '/v2/ai/voice/connect' && req.method === 'POST') {
        const key = body.sessionId, live = sessions.get(`${wallet.id}:${key}`);
        const op = store.operation(wallet.id, key);
        if (!live || !op || op.state !== 'reserved' || live.connecting || op.callId) error('call_not_active', 409);
        if (typeof body.sdp !== 'string' || body.sdp.length > 100000) error('invalid_sdp', 400);
        live.connecting = true;
        const form = new FormData(); form.set('sdp', body.sdp); form.set('session', JSON.stringify(live.session));
        try {
          const response = await fetcher('https://api.openai.com/v1/realtime/calls', {
            method: 'POST', headers: { Authorization: `Bearer ${config.apiKey}` }, body: form,
            signal: AbortSignal.timeout(15000),
          });
          if (!response.ok) error('voice_connect_failed', 502);
          const rawLocation = response.headers.get('location');
          const location = rawLocation ? new URL(rawLocation, 'https://api.openai.com').href : null;
          const match = /^https:\/\/api\.openai\.com\/v1\/realtime\/calls\/([A-Za-z0-9_-]+)$/.exec(location ?? '');
          if (!match) error('voice_call_id_missing', 502);
          store.attachCall(wallet.id, key, match[1]);
          live.socket = attachObserver(match[1], event => {
            if (event.type === 'response.created' || event.type === 'input_audio_buffer.speech_started') {
              store.startCall(wallet.id, key);
            }
            if (event.type === 'response.done' && event.response?.id && event.response?.usage) {
              store.recordUsage(wallet.id, event.response.id, { feature: 'voice', model: config.plannerVoiceModel,
                usage: event.response.usage, source: 'server_sideband' });
            }
          }, () => { void stop(wallet.id, key).catch(() => {}); });
          // Do not let a client start generating audio before metering is attached.
          if (live.socket.readyState === WebSocket.CONNECTING) {
            await new Promise((resolve, reject) => {
              live.socket.once('open', resolve);
              live.socket.once('error', reject);
              live.socket.once('close', () => reject(new Error('voice_observer_closed')));
            });
          }
          const sdp = await response.text();
          send(res, 200, { sdp }); return true;
        } catch (e) {
          await stop(wallet.id, key).catch(() => {});
          throw e;
        }
      }
      if (route === '/v2/ai/voice/stop' && req.method === 'POST') {
        await stop(wallet.id, body.sessionId);
        send(res, 200, store.snapshot(wallet, subscription)); return true;
      }
      if (route === '/v2/ai/voice/status' && req.method === 'POST') {
        const op = store.operation(wallet.id, body.sessionId);
        send(res, 200, { active: op?.state === 'reserved', remainingSeconds: op?.state === 'reserved'
          ? Math.max(0, Math.ceil(((op.deadline ?? Date.now() + (op.included + op.purchased) * 1000) - Date.now()) / 1000)) : 0 });
        return true;
      }
      error('not_found', 404);
    } catch (e) {
      const code = e instanceof ServiceError ? e.code : 'billing_unavailable';
      send(res, e instanceof ServiceError ? e.status : 503, { error: code });
    }
    return true;
  }
  return { handle, store, async close() {
    closing = true; clearInterval(timer);
    await Promise.allSettled(store.pending().filter(op => op.resource === 'voice').map(op => stop(op.wallet, op.key)));
    await Promise.allSettled([...inflight.values()]);
    for (const live of sessions.values()) live.socket?.terminate();
    store.close();
  } };
}
