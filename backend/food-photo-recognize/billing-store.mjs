import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { ServiceError } from './recognition.mjs';

export const TOPUPS = Object.freeze({
  'com.weekfit.topup.photos20': { resource: 'photos', quantity: 20 },
  'com.weekfit.topup.photos50': { resource: 'photos', quantity: 50 },
  'com.weekfit.topup.voice15': { resource: 'voice', quantity: 900 },
  'com.weekfit.topup.voice30': { resource: 'voice', quantity: 1800 },
});
export const ALLOWANCES = Object.freeze({ photos: 30, voice: 300 });
export const hash = value => createHash('sha256').update(value).digest('hex');
const fail = (code, status = 409) => { throw new ServiceError(code, status); };

// Compute from the original day every time: Jan 31 -> Feb 28 -> Mar 31.
export function monthlyWindow(anchor, now) {
  const a = new Date(anchor), n = new Date(now);
  if (!Number.isFinite(a.getTime()) || anchor > now) fail('invalid_subscription_anchor');
  const boundary = offset => {
    const d = new Date(anchor);
    d.setUTCDate(1);
    d.setUTCMonth(a.getUTCMonth() + offset);
    const end = new Date(d); end.setUTCMonth(end.getUTCMonth() + 1, 0);
    d.setUTCDate(Math.min(a.getUTCDate(), end.getUTCDate()));
    return d.getTime();
  };
  let offset = (n.getUTCFullYear() - a.getUTCFullYear()) * 12 + n.getUTCMonth() - a.getUTCMonth();
  if (boundary(offset) > now) offset--;
  return { start: boundary(offset), end: boundary(offset + 1) };
}

export class BillingStore {
  constructor(filename, { now = Date.now, maxVoiceCalls = 5 } = {}) {
    mkdirSync(dirname(filename), { recursive: true });
    this.db = new DatabaseSync(filename);
    this.now = now;
    this.maxVoiceCalls = maxVoiceCalls;
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000; PRAGMA locking_mode=EXCLUSIVE;
      CREATE TABLE IF NOT EXISTS wallets (id TEXT PRIMARY KEY, token TEXT UNIQUE NOT NULL);
      CREATE TABLE IF NOT EXISTS subscriptions (id TEXT PRIMARY KEY, wallet TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS purchases (id TEXT PRIMARY KEY, wallet TEXT NOT NULL, product TEXT NOT NULL,
        resource TEXT NOT NULL, quantity INTEGER NOT NULL, refunded INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS periods (wallet TEXT, start INTEGER, resource TEXT, used INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(wallet,start,resource));
      CREATE TABLE IF NOT EXISTS balances (wallet TEXT, resource TEXT, amount INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(wallet,resource));
      CREATE TABLE IF NOT EXISTS operations (wallet TEXT, key TEXT, resource TEXT, fingerprint TEXT,
        period INTEGER, included INTEGER, purchased INTEGER, state TEXT, created INTEGER,
        result TEXT, callId TEXT, started INTEGER, deadline INTEGER,
        PRIMARY KEY(wallet,key));
      CREATE UNIQUE INDEX IF NOT EXISTS one_voice_call ON operations(wallet)
        WHERE resource='voice' AND state='reserved';
      CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY, wallet TEXT, event TEXT, resource TEXT,
        quantity INTEGER, reference TEXT, at INTEGER);
      CREATE TABLE IF NOT EXISTS usage (id TEXT PRIMARY KEY, wallet TEXT, value TEXT NOT NULL);
      PRAGMA user_version=1;`);
  }
  atomic(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const result = fn(); this.db.exec('COMMIT'); return result; }
    catch (e) { this.db.exec('ROLLBACK'); throw e; }
  }
  get(sql, ...args) { return this.db.prepare(sql).get(...args); }
  run(sql, ...args) { return this.db.prepare(sql).run(...args); }
  audit(wallet, event, resource, quantity, reference) {
    this.run('INSERT INTO audit(wallet,event,resource,quantity,reference,at) VALUES(?,?,?,?,?,?)',
      wallet, event, resource, quantity, reference, this.now());
  }
  // Restored StoreKit subscription lineage, NOT the ephemeral Firebase anonymous UID.
  wallet(subscription) {
    const id = `${subscription.environment}:${subscription.originalTransactionId}`;
    return this.atomic(() => {
      let row = this.get('SELECT wallet FROM subscriptions WHERE id=?', id);
      if (!row) {
        const wallet = hash(id);
        this.run('INSERT OR IGNORE INTO wallets VALUES(?,?)', wallet, randomUUID());
        this.run('INSERT INTO subscriptions VALUES(?,?)', id, wallet);
        row = { wallet };
      }
      return { id: row.wallet, token: this.get('SELECT token FROM wallets WHERE id=?', row.wallet).token };
    });
  }
  remaining(wallet, resource, start, unlimited = false) {
    const used = this.get('SELECT used FROM periods WHERE wallet=? AND start=? AND resource=?', wallet, start, resource)?.used ?? 0;
    const purchased = this.get('SELECT amount FROM balances WHERE wallet=? AND resource=?', wallet, resource)?.amount ?? 0;
    const included = unlimited ? 1_000_000 : Math.max(0, ALLOWANCES[resource] - used);
    // Refund debt is settled before allowing new usage, including the monthly allowance.
    return { included: Math.max(0, included + Math.min(0, purchased)), purchased: Math.max(0, purchased) };
  }
  snapshot(wallet, subscription) {
    const period = monthlyWindow(subscription.anchor, this.now());
    const photos = this.remaining(wallet.id, 'photos', period.start, subscription.grandfatheredPhotos);
    const voice = this.remaining(wallet.id, 'voice', period.start);
    return { appAccountToken: wallet.token, active: subscription.active, productId: subscription.productId,
      periodStart: period.start, periodEnd: Math.min(period.end, subscription.accessUntil || period.end),
      grandfatheredPhotos: Boolean(subscription.grandfatheredPhotos),
      photos, voice, limits: ALLOWANCES };
  }
  grant(wallet, transaction) {
    const pack = TOPUPS[transaction.productId];
    if (!pack || transaction.type !== 'Consumable' || transaction.appAccountToken?.toLowerCase() !== wallet.token.toLowerCase()) {
      fail('purchase_owner_mismatch', 403);
    }
    const id = `${transaction.environment}:${transaction.transactionId}`;
    return this.atomic(() => {
      const prior = this.get('SELECT * FROM purchases WHERE id=?', id);
      if (prior) {
        if (prior.wallet !== wallet.id || prior.product !== transaction.productId) fail('purchase_owner_mismatch', 403);
        if (transaction.revocationDate) this.refundInside(id, prior);
        return;
      }
      const refunded = transaction.revocationDate ? 1 : 0;
      this.run('INSERT INTO purchases VALUES(?,?,?,?,?,?)', id, wallet.id, transaction.productId, pack.resource, pack.quantity, refunded);
      if (!refunded) this.adjust(wallet.id, pack.resource, pack.quantity);
      this.audit(wallet.id, refunded ? 'purchase_revoked' : 'purchase', pack.resource, refunded ? 0 : pack.quantity, id);
    });
  }
  refund(transaction) {
    const id = `${transaction.environment}:${transaction.transactionId}`;
    this.atomic(() => {
      const prior = this.get('SELECT * FROM purchases WHERE id=?', id);
      if (prior) this.refundInside(id, prior);
      else {
        // Tombstone first: a delayed purchase upload must not credit a refunded transaction.
        const owner = this.get('SELECT id FROM wallets WHERE token=?', transaction.appAccountToken?.toLowerCase() ?? '');
        if (owner && TOPUPS[transaction.productId]) this.run('INSERT INTO purchases VALUES(?,?,?,?,?,1)',
          id, owner.id, transaction.productId, TOPUPS[transaction.productId].resource, TOPUPS[transaction.productId].quantity);
      }
    });
  }
  refundInside(id, prior) {
    if (prior.refunded) return;
    this.run('UPDATE purchases SET refunded=1 WHERE id=?', id);
    this.adjust(prior.wallet, prior.resource, -prior.quantity);
    this.audit(prior.wallet, 'refund', prior.resource, -prior.quantity, id);
  }
  adjust(wallet, resource, amount) {
    this.run(`INSERT INTO balances VALUES(?,?,?) ON CONFLICT(wallet,resource) DO UPDATE SET amount=amount+excluded.amount`, wallet, resource, amount);
  }
  operation(wallet, key) { return this.get('SELECT * FROM operations WHERE wallet=? AND key=?', wallet, key); }
  reserve(wallet, subscription, resource, key, fingerprint, maxUnits = 1) {
    if (!['photos','voice'].includes(resource) || !/^[A-Za-z0-9_-]{8,100}$/.test(key) || !Number.isSafeInteger(maxUnits) || maxUnits < 1) fail('invalid_usage_request', 400);
    if (!subscription.active) fail('subscription_required', 402);
    return this.atomic(() => {
      const prior = this.operation(wallet.id, key);
      if (prior) {
        if (prior.resource !== resource || prior.fingerprint !== fingerprint) fail('idempotency_key_reuse');
        return prior;
      }
      if (resource === 'voice' && this.get("SELECT key FROM operations WHERE wallet=? AND resource='voice' AND state='reserved'", wallet.id)) fail('voice_already_active');
      if (resource === 'voice' && this.get("SELECT COUNT(*) AS n FROM operations WHERE resource='voice' AND state='reserved'").n >= this.maxVoiceCalls) fail('planner_voice_busy', 503);
      const period = monthlyWindow(subscription.anchor, this.now());
      const remaining = this.remaining(wallet.id, resource, period.start, resource === 'photos' && subscription.grandfatheredPhotos);
      const units = Math.min(maxUnits, remaining.included + remaining.purchased,
        resource === 'voice' ? Math.max(0, Math.floor((subscription.accessUntil - this.now()) / 1000)) : maxUnits);
      if (units < 1) fail('quota_exhausted', 429);
      const included = Math.min(units, remaining.included), purchased = units - included;
      this.run(`INSERT INTO periods VALUES(?,?,?,?) ON CONFLICT(wallet,start,resource) DO UPDATE SET used=used+excluded.used`, wallet.id, period.start, resource, included);
      if (purchased) this.adjust(wallet.id, resource, -purchased);
      this.run('INSERT INTO operations(wallet,key,resource,fingerprint,period,included,purchased,state,created) VALUES(?,?,?,?,?,?,?,?,?)',
        wallet.id, key, resource, fingerprint, period.start, included, purchased, 'reserved', this.now());
      this.audit(wallet.id, 'reserve', resource, units, key);
      return this.operation(wallet.id, key);
    });
  }
  attachCall(wallet, key, callId) {
    this.run("UPDATE operations SET callId=? WHERE wallet=? AND key=? AND state='reserved'", callId, wallet, key);
  }
  startCall(wallet, key) {
    return this.atomic(() => {
      const op = this.operation(wallet, key);
      if (!op || op.state !== 'reserved') fail('call_not_active');
      if (!op.started) {
        const started = this.now();
        this.run('UPDATE operations SET started=?,deadline=? WHERE wallet=? AND key=?', started,
          started + (op.included + op.purchased) * 1000, wallet, key);
      }
      return this.operation(wallet, key);
    });
  }
  settle(wallet, key, used, result = null) {
    return this.atomic(() => {
      const op = this.operation(wallet, key);
      if (!op || op.state !== 'reserved') return op;
      if (!Number.isSafeInteger(used) || used < 0 || used > op.included + op.purchased) fail('invalid_settlement', 400);
      const refundIncluded = op.included - Math.min(op.included, used);
      const refundPurchased = op.purchased - Math.max(0, used - op.included);
      this.run('UPDATE periods SET used=used-? WHERE wallet=? AND start=? AND resource=?', refundIncluded, wallet, op.period, op.resource);
      if (refundPurchased) this.adjust(wallet, op.resource, refundPurchased);
      this.run("UPDATE operations SET state='settled',result=? WHERE wallet=? AND key=?", result == null ? null : JSON.stringify(result), wallet, key);
      this.audit(wallet, 'settle', op.resource, used, key);
      return this.operation(wallet, key);
    });
  }
  pending() { return this.db.prepare("SELECT * FROM operations WHERE state='reserved'").all(); }
  claimPhotoAttempt(wallet, key, limit) {
    this.atomic(() => {
      const day = new Date(this.now()); day.setUTCHours(0,0,0,0);
      const count = this.get("SELECT COUNT(*) AS n FROM audit WHERE event='photo_provider_attempt' AND at>=?", day.getTime()).n;
      if (count >= limit) fail('provider_budget_exhausted', 503);
      this.audit(wallet, 'photo_provider_attempt', 'photos', 1, key);
    });
  }
  recordUsage(wallet, id, value) {
    return this.run('INSERT OR IGNORE INTO usage VALUES(?,?,?)', hash(`${wallet}:${id}`), wallet, JSON.stringify(value)).changes === 1;
  }
  close() { this.db.close(); }
}
