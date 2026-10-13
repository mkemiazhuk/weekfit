import net from 'node:net';
import { pathToFileURL } from 'node:url';

/**
 * In-process Redis-compatible TCP server for local multi-process tests.
 * Not a full Redis; implements the subset WeekFit uses (strings, lists, hashes, zsets, EVAL scripts).
 * Production uses a real Redis via REDIS_URL — same client protocol.
 */
export function createMiniRedisServer() {
  /** @type {Map<string, any>} */
  const store = new Map();
  /** @type {Map<string, number>} */
  const expiry = new Map();
  /** @type {Map<string, Array<{ resolve: Function, timer: NodeJS.Timeout }>>} */
  const listWaiters = new Map();

  const wakeList = (key, value) => {
    const waiters = listWaiters.get(key);
    if (!waiters?.length) return false;
    while (waiters.length) {
      const w = waiters.shift();
      clearTimeout(w.timer);
      // Drop waiters whose client already disconnected (killed workers).
      if (w.socket?.destroyed || w.socket?.readableEnded) continue;
      if (!waiters.length) listWaiters.delete(key);
      w.resolve([key, value]);
      return true;
    }
    listWaiters.delete(key);
    return false;
  };

  const now = () => Date.now();
  const alive = (key) => {
    const exp = expiry.get(key);
    if (exp != null && exp <= now()) {
      store.delete(key);
      expiry.delete(key);
      return false;
    }
    return store.has(key);
  };
  const touchExpire = (key, ms) => {
    if (ms > 0) expiry.set(key, now() + ms);
  };

  const getType = (key) => {
    if (!alive(key)) return 'none';
    const v = store.get(key);
    if (Array.isArray(v)) return 'list';
    if (v && typeof v === 'object' && v.__z) return 'zset';
    if (v && typeof v === 'object') return 'hash';
    return 'string';
  };

  const scripts = {
    // KEYS[1]=queue KEYS[2]=leasePrefix KEYS[3]=leaseZset ARGV[1]=workerId ARGV[2]=leaseUntil ARGV[3]=leaseJson
    claim: (keys, args) => {
      const [queue, leasePrefix, leaseZ] = keys;
      const [, leaseUntil, leaseJson, leaseMs] = args;
      const list = alive(queue) ? store.get(queue) : null;
      if (!Array.isArray(list) || list.length === 0) return null;
      const id = list.pop();
      store.set(queue, list);
      const leaseKey = `${leasePrefix}${id}`;
      store.set(leaseKey, leaseJson);
      touchExpire(leaseKey, Number(leaseMs) || 60_000);
      let z = store.get(leaseZ);
      if (!z || !z.__z) z = { __z: true, members: new Map() };
      z.members.set(id, Number(leaseUntil));
      store.set(leaseZ, z);
      return id;
    },
    // KEYS[1]=resKey KEYS[2]=userKey KEYS[3]=globalKey ARGV[1]=userLimit ARGV[2]=globalLimit ARGV[3]=ttlSec
    quota: (keys, args) => {
      const [resKey, userKey, globalKey] = keys;
      const userLimit = Number(args[0]);
      const globalLimit = Number(args[1]);
      const ttlSec = Number(args[2] || 172800);
      if (alive(resKey)) return 'EXISTING';
      const user = Number((alive(userKey) && store.get(userKey)) || 0);
      const global = Number((alive(globalKey) && store.get(globalKey)) || 0);
      if (user >= userLimit || global >= globalLimit) return 'LIMIT';
      store.set(resKey, '1');
      touchExpire(resKey, ttlSec * 1000);
      store.set(userKey, String(user + 1));
      touchExpire(userKey, ttlSec * 1000);
      store.set(globalKey, String(global + 1));
      touchExpire(globalKey, ttlSec * 1000);
      return 'OK';
    },
    // KEYS[1]=slotZset ARGV[1]=slotId ARGV[2]=owner ARGV[3]=expiresAt ARGV[4]=max
    slot: (keys, args) => {
      const [zkey] = keys;
      const [slotId, owner, expiresAt, max] = args;
      const maxN = Number(max);
      const exp = Number(expiresAt);
      let z = store.get(zkey);
      if (!z || !z.__z) z = { __z: true, members: new Map() };
      // sweep expired
      for (const [m, score] of [...z.members.entries()]) {
        if (score <= now()) z.members.delete(m);
      }
      if (z.members.size >= maxN) {
        store.set(zkey, z);
        return null;
      }
      z.members.set(slotId, exp);
      store.set(zkey, z);
      store.set(`ai-slot:${slotId}`, JSON.stringify({ id: slotId, ownerId: owner, expiresAt: exp }));
      touchExpire(`ai-slot:${slotId}`, Math.max(1000, exp - now()));
      return slotId;
    },
  };

  const runEval = (script, keys, args) => {
    if (script.includes('RPOP') && script.includes('lease')) return scripts.claim(keys, args);
    if (script.includes('quota') || script.includes('userLimit')) return scripts.quota(keys, args);
    if (script.includes('ai-slot') || script.includes('slotZ')) return scripts.slot(keys, args);
    // Fallback: detect by markers we embed in scripts
    if (script.includes('WEEKFIT_CLAIM')) return scripts.claim(keys, args);
    if (script.includes('WEEKFIT_QUOTA')) return scripts.quota(keys, args);
    if (script.includes('WEEKFIT_SLOT')) return scripts.slot(keys, args);
    throw new Error('ERR unknown lua script');
  };

  const encode = (value) => {
    if (value instanceof Error) return Buffer.from(`-${value.message}\r\n`);
    if (value === null || value === undefined) return Buffer.from('$-1\r\n');
    if (typeof value === 'number') return Buffer.from(`:${value}\r\n`);
    if (typeof value === 'string') {
      const b = Buffer.from(value);
      return Buffer.concat([Buffer.from(`$${b.length}\r\n`), b, Buffer.from('\r\n')]);
    }
    if (Array.isArray(value)) {
      const parts = [Buffer.from(`*${value.length}\r\n`)];
      for (const item of value) parts.push(encode(item));
      return Buffer.concat(parts);
    }
    const b = Buffer.from(String(value));
    return Buffer.concat([Buffer.from(`$${b.length}\r\n`), b, Buffer.from('\r\n')]);
  };

  const parseCommands = (buffer) => {
    const commands = [];
    let offset = 0;
    while (offset < buffer.length) {
      if (buffer[offset] !== 42) break; // *
      const lineEnd = buffer.indexOf('\r\n', offset);
      if (lineEnd < 0) break;
      const count = Number(buffer.subarray(offset + 1, lineEnd).toString());
      let cursor = lineEnd + 2;
      const args = [];
      let ok = true;
      for (let i = 0; i < count; i += 1) {
        if (buffer[cursor] !== 36) { ok = false; break; }
        const lenEnd = buffer.indexOf('\r\n', cursor);
        if (lenEnd < 0) { ok = false; break; }
        const len = Number(buffer.subarray(cursor + 1, lenEnd).toString());
        const start = lenEnd + 2;
        const end = start + len;
        if (buffer.length < end + 2) { ok = false; break; }
        args.push(buffer.subarray(start, end).toString('utf8'));
        cursor = end + 2;
      }
      if (!ok) break;
      commands.push(args);
      offset = cursor;
    }
    return { commands, rest: buffer.subarray(offset) };
  };

  const dispatch = (args) => {
    const cmd = (args[0] || '').toUpperCase();
    try {
      switch (cmd) {
        case 'PING': return 'PONG';
        case 'AUTH':
        case 'SELECT':
        case 'QUIT': return 'OK';
        case 'GET': {
          const key = args[1];
          if (!alive(key)) return null;
          const v = store.get(key);
          return typeof v === 'string' || typeof v === 'number' ? String(v) : JSON.stringify(v);
        }
        case 'SET': {
          const key = args[1];
          const value = args[2];
          const opts = args.slice(3).map((s) => s.toUpperCase());
          const nx = opts.includes('NX');
          const xx = opts.includes('XX');
          const exIdx = opts.indexOf('EX');
          const pxIdx = opts.indexOf('PX');
          const exists = alive(key);
          if (nx && exists) return null;
          if (xx && !exists) return null;
          store.set(key, value);
          if (exIdx >= 0) touchExpire(key, Number(args[3 + exIdx + 1]) * 1000);
          if (pxIdx >= 0) touchExpire(key, Number(args[3 + pxIdx + 1]));
          return 'OK';
        }
        case 'DEL': {
          let n = 0;
          for (const key of args.slice(1)) {
            if (store.delete(key)) n += 1;
            expiry.delete(key);
          }
          return n;
        }
        case 'EXISTS': {
          let n = 0;
          for (const key of args.slice(1)) if (alive(key)) n += 1;
          return n;
        }
        case 'INCR': {
          const key = args[1];
          const cur = Number((alive(key) && store.get(key)) || 0) + 1;
          store.set(key, String(cur));
          return cur;
        }
        case 'LPUSH': {
          const key = args[1];
          const values = args.slice(2);
          // Prefer waking a blocked BRPOP before storing.
          let woken = 0;
          for (const v of values) {
            if (wakeList(key, v)) woken += 1;
            else {
              let list = alive(key) ? store.get(key) : [];
              if (!Array.isArray(list)) list = [];
              list.unshift(v);
              store.set(key, list);
            }
          }
          const list = alive(key) ? store.get(key) : [];
          return (Array.isArray(list) ? list.length : 0) + woken;
        }
        case 'RPOP': {
          const key = args[1];
          if (!alive(key)) return null;
          const list = store.get(key);
          if (!Array.isArray(list) || list.length === 0) return null;
          const v = list.pop();
          store.set(key, list);
          return v;
        }
        case 'BRPOP': {
          // BRPOP key [key ...] timeout
          const timeoutSec = Number(args[args.length - 1]);
          const keys = args.slice(1, -1);
          for (const key of keys) {
            if (!alive(key)) continue;
            const list = store.get(key);
            if (!Array.isArray(list) || list.length === 0) continue;
            const v = list.pop();
            store.set(key, list);
            return [key, v];
          }
          // Blocking wait — socket association set by caller via dispatch.socket
          return new Promise((resolve) => {
            const key = keys[0];
            const timeoutMs = timeoutSec === 0 ? 3600_000 : Math.max(1, timeoutSec) * 1000;
            const timer = setTimeout(() => {
              const arr = listWaiters.get(key) || [];
              const idx = arr.findIndex((w) => w.resolve === resolve);
              if (idx >= 0) arr.splice(idx, 1);
              resolve(null);
            }, timeoutMs);
            if (!listWaiters.has(key)) listWaiters.set(key, []);
            listWaiters.get(key).push({ resolve, timer, socket: dispatch.socket || null });
          });
        }
        case 'LLEN': {
          const key = args[1];
          if (!alive(key)) return 0;
          const list = store.get(key);
          return Array.isArray(list) ? list.length : 0;
        }
        case 'HSET': {
          const key = args[1];
          let hash = alive(key) ? store.get(key) : {};
          if (!hash || typeof hash !== 'object' || Array.isArray(hash) || hash.__z) hash = {};
          let added = 0;
          for (let i = 2; i < args.length; i += 2) {
            if (!(args[i] in hash)) added += 1;
            hash[args[i]] = args[i + 1];
          }
          store.set(key, hash);
          return added;
        }
        case 'HGET': {
          const key = args[1];
          if (!alive(key)) return null;
          const hash = store.get(key);
          if (!hash || typeof hash !== 'object') return null;
          return hash[args[2]] ?? null;
        }
        case 'HGETALL': {
          const key = args[1];
          if (!alive(key)) return [];
          const hash = store.get(key);
          if (!hash || typeof hash !== 'object' || hash.__z) return [];
          const flat = [];
          for (const [k, v] of Object.entries(hash)) flat.push(k, String(v));
          return flat;
        }
        case 'HDEL': {
          const key = args[1];
          if (!alive(key)) return 0;
          const hash = store.get(key);
          if (!hash || typeof hash !== 'object') return 0;
          let n = 0;
          for (const f of args.slice(2)) {
            if (f in hash) { delete hash[f]; n += 1; }
          }
          store.set(key, hash);
          return n;
        }
        case 'ZADD': {
          const key = args[1];
          let z = alive(key) ? store.get(key) : null;
          if (!z || !z.__z) z = { __z: true, members: new Map() };
          const score = Number(args[2]);
          const member = args[3];
          const existed = z.members.has(member);
          z.members.set(member, score);
          store.set(key, z);
          return existed ? 0 : 1;
        }
        case 'ZREM': {
          const key = args[1];
          if (!alive(key)) return 0;
          const z = store.get(key);
          if (!z || !z.__z) return 0;
          let n = 0;
          for (const m of args.slice(2)) if (z.members.delete(m)) n += 1;
          store.set(key, z);
          return n;
        }
        case 'ZRANGEBYSCORE': {
          const key = args[1];
          if (!alive(key)) return [];
          const z = store.get(key);
          if (!z || !z.__z) return [];
          const min = args[2] === '-inf' ? -Infinity : Number(args[2]);
          const max = args[3] === '+inf' ? Infinity : Number(args[3]);
          return [...z.members.entries()]
            .filter(([, s]) => s >= min && s <= max)
            .sort((a, b) => a[1] - b[1])
            .map(([m]) => m);
        }
        case 'ZCARD': {
          const key = args[1];
          if (!alive(key)) return 0;
          const z = store.get(key);
          return z && z.__z ? z.members.size : 0;
        }
        case 'EXPIRE': {
          const key = args[1];
          if (!alive(key)) return 0;
          touchExpire(key, Number(args[2]) * 1000);
          return 1;
        }
        case 'EVAL': {
          const script = args[1];
          const nkeys = Number(args[2]);
          const keys = args.slice(3, 3 + nkeys);
          const evalArgs = args.slice(3 + nkeys);
          return runEval(script, keys, evalArgs);
        }
        default:
          return new Error(`ERR unknown command '${cmd}'`);
      }
    } catch (error) {
      return new Error(`ERR ${error.message}`);
    }
  };

  const server = net.createServer((socket) => {
    let pending = Buffer.alloc(0);
    let chain = Promise.resolve();
    // Client kill / fleet teardown must not crash the broker with unhandled ECONNRESET.
    socket.on('error', () => {});
    socket.on('close', () => {
      for (const [key, arr] of listWaiters.entries()) {
        for (let i = arr.length - 1; i >= 0; i -= 1) {
          if (arr[i].socket === socket) {
            clearTimeout(arr[i].timer);
            arr[i].resolve(null);
            arr.splice(i, 1);
          }
        }
        if (!arr.length) listWaiters.delete(key);
      }
    });
    socket.on('data', (chunk) => {
      pending = Buffer.concat([pending, chunk]);
      const { commands, rest } = parseCommands(pending);
      pending = rest;
      for (const args of commands) {
        chain = chain.then(async () => {
          dispatch.socket = socket;
          const result = await Promise.resolve(dispatch(args));
          try {
            socket.write(encode(result));
          } catch {
            return;
          }
          if ((args[0] || '').toUpperCase() === 'QUIT') {
            socket.end();
          }
        }).catch(() => {});
      }
    });
  });

  const listen = () => new Promise((resolve, reject) => {
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      resolve({
        port: addr.port,
        url: `redis://127.0.0.1:${addr.port}`,
        close: () => new Promise((r) => server.close(() => r())),
        _store: store,
      });
    });
    server.on('error', reject);
  });

  return { listen, server };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const mini = createMiniRedisServer();
  const info = await mini.listen();
  console.log(JSON.stringify({ outcome: 'mini_redis_listening', url: info.url }));
}
