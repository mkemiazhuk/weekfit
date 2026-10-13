import net from 'node:net';
import { EventEmitter } from 'node:events';

/**
 * Minimal Redis RESP client (no npm deps).
 * Works against real Redis and async/mini-redis.mjs.
 */
export function parseRedisUrl(url) {
  const u = new URL(url);
  if (u.protocol !== 'redis:' && u.protocol !== 'rediss:') {
    throw new Error('REDIS_URL must be redis:// or rediss://');
  }
  return {
    host: u.hostname || '127.0.0.1',
    port: Number(u.port || 6379),
    password: u.password ? decodeURIComponent(u.password) : null,
    db: u.pathname && u.pathname !== '/' ? Number(u.pathname.slice(1)) : 0,
    tls: u.protocol === 'rediss:',
  };
}

function encodeCommand(args) {
  const parts = [Buffer.from(`*${args.length}\r\n`)];
  for (const arg of args) {
    const buf = Buffer.isBuffer(arg) ? arg : Buffer.from(String(arg));
    parts.push(Buffer.from(`$${buf.length}\r\n`), buf, Buffer.from('\r\n'));
  }
  return Buffer.concat(parts);
}

function parseOne(buf) {
  if (buf.length === 0) return null;
  const walk = (offset) => {
    if (offset >= buf.length) return null;
    const type = String.fromCharCode(buf[offset]);
    const lineEnd = buf.indexOf('\r\n', offset);
    if (lineEnd < 0) return null;
    if (type === '+' || type === '-' || type === ':') {
      const line = buf.subarray(offset + 1, lineEnd).toString('utf8');
      if (type === '+') return { value: line, next: lineEnd + 2 };
      if (type === '-') {
        const err = new Error(line);
        err.redis = true;
        return { value: err, next: lineEnd + 2 };
      }
      return { value: Number(line), next: lineEnd + 2 };
    }
    if (type === '$') {
      const len = Number(buf.subarray(offset + 1, lineEnd).toString('utf8'));
      if (len === -1) return { value: null, next: lineEnd + 2 };
      const start = lineEnd + 2;
      const end = start + len;
      if (buf.length < end + 2) return null;
      return { value: buf.subarray(start, end).toString('utf8'), next: end + 2 };
    }
    if (type === '*') {
      const count = Number(buf.subarray(offset + 1, lineEnd).toString('utf8'));
      if (count === -1) return { value: null, next: lineEnd + 2 };
      let cursor = lineEnd + 2;
      const items = [];
      for (let i = 0; i < count; i += 1) {
        const part = walk(cursor);
        if (!part) return null;
        items.push(part.value);
        cursor = part.next;
      }
      return { value: items, next: cursor };
    }
    throw new Error(`Unsupported RESP type ${type}`);
  };
  return walk(0);
}

export function createRedisClient(url) {
  const cfg = parseRedisUrl(url);
  const ee = new EventEmitter();
  /** @type {import('node:net').Socket | null} */
  let socket = null;
  let connecting = null;
  let buf = Buffer.alloc(0);
  /** @type {Array<{resolve: Function, reject: Function}>} */
  const waiters = [];

  const drain = () => {
    for (;;) {
      let parsed;
      try {
        parsed = parseOne(buf);
      } catch (error) {
        const w = waiters.shift();
        w?.reject(error);
        return;
      }
      if (!parsed) return;
      buf = buf.subarray(parsed.next);
      const w = waiters.shift();
      if (!w) return;
      if (parsed.value instanceof Error && parsed.value.redis) w.reject(parsed.value);
      else w.resolve(parsed.value);
    }
  };

  const call = async (args) => {
    await connect();
    return new Promise((resolve, reject) => {
      waiters.push({ resolve, reject });
      try {
        socket.write(encodeCommand(args));
      } catch (error) {
        waiters.pop();
        reject(error);
      }
    });
  };

  const connect = async () => {
    if (socket && !socket.destroyed) return;
    if (connecting) return connecting;
    connecting = new Promise((resolve, reject) => {
      let settled = false;
      const s = net.createConnection({ host: cfg.host, port: cfg.port }, () => {
        // Mark connected before AUTH so nested call() does not re-enter connect().
        socket = s;
        connecting = null;
        (async () => {
          try {
            if (cfg.password) await call(['AUTH', cfg.password]);
            if (cfg.db) await call(['SELECT', String(cfg.db)]);
            settled = true;
            resolve();
          } catch (error) {
            settled = true;
            reject(error);
          }
        })();
      });
      s.on('data', (chunk) => {
        buf = Buffer.concat([buf, chunk]);
        drain();
      });
      s.on('error', (error) => {
        const err = error;
        err.code = err.code || 'redis_error';
        while (waiters.length) waiters.shift().reject(err);
        if (!settled) {
          settled = true;
          connecting = null;
          reject(err);
        }
        // Avoid unhandled 'error' EventEmitter crash when no subscriber is attached.
        if (ee.listenerCount('error') > 0) ee.emit('error', err);
      });
      s.on('close', () => {
        socket = null;
        const err = new Error('redis_connection_closed');
        err.code = 'redis_connection_closed';
        while (waiters.length) waiters.shift().reject(err);
        ee.emit('close');
      });
    });
    return connecting;
  };

  return {
    call,
    on: (...a) => ee.on(...a),
    async get(key) { return call(['GET', key]); },
    async set(key, value, opts = {}) {
      const args = ['SET', key, value];
      if (opts.nx) args.push('NX');
      if (opts.xx) args.push('XX');
      if (opts.ex != null) args.push('EX', String(opts.ex));
      if (opts.px != null) args.push('PX', String(opts.px));
      return call(args);
    },
    async del(...keys) { return keys.length ? call(['DEL', ...keys]) : 0; },
    async exists(...keys) { return keys.length ? call(['EXISTS', ...keys]) : 0; },
    async incr(key) { return call(['INCR', key]); },
    async lpush(key, ...values) { return call(['LPUSH', key, ...values]); },
    async rpop(key) { return call(['RPOP', key]); },
    /** @returns {Promise<[string, string] | null>} */
    async brpop(key, timeoutSec) {
      const result = await call(['BRPOP', key, String(timeoutSec)]);
      if (!result) return null;
      return result;
    },
    async llen(key) { return call(['LLEN', key]); },
    async hset(key, objOrField, maybeValue) {
      if (typeof objOrField === 'object' && objOrField !== null && maybeValue === undefined) {
        const flat = [];
        for (const [k, v] of Object.entries(objOrField)) flat.push(k, String(v));
        return flat.length ? call(['HSET', key, ...flat]) : 0;
      }
      return call(['HSET', key, objOrField, String(maybeValue)]);
    },
    async hget(key, field) { return call(['HGET', key, field]); },
    async hgetall(key) {
      const flat = await call(['HGETALL', key]);
      if (!Array.isArray(flat) || flat.length === 0) return {};
      const obj = {};
      for (let i = 0; i < flat.length; i += 2) obj[flat[i]] = flat[i + 1];
      return obj;
    },
    async hdel(key, ...fields) { return fields.length ? call(['HDEL', key, ...fields]) : 0; },
    async zadd(key, score, member) { return call(['ZADD', key, String(score), member]); },
    async zrem(key, ...members) { return members.length ? call(['ZREM', key, ...members]) : 0; },
    async zrangebyscore(key, min, max) {
      return call(['ZRANGEBYSCORE', key, String(min), String(max)]);
    },
    async zcard(key) { return call(['ZCARD', key]); },
    async expire(key, seconds) { return call(['EXPIRE', key, String(seconds)]); },
    async eval(script, keys = [], args = []) {
      return call(['EVAL', script, String(keys.length), ...keys, ...args]);
    },
    async ping() { return call(['PING']); },
    async quit() {
      try {
        if (socket && !socket.destroyed) await call(['QUIT']);
      } catch { /* ignore */ }
      socket?.destroy();
      socket = null;
    },
    async close() { return this.quit(); },
  };
}
