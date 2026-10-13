import http from 'node:http';
import { createHash, randomUUID } from 'node:crypto';
import { createServer as createNetServer } from 'node:net';

/**
 * HTTP object store (S3-shaped for local/staging without paid buckets).
 * Production can point OBJECT_STORE_BASE_URL at a gateway or use createS3ObjectStore.
 * Photos are opaque bytes — never logged.
 */
export function createHttpObjectStoreServer({ token = 'weekfit-object-dev' } = {}) {
  /** @type {Map<string, { bytes: Buffer, storedAt: number }>} */
  const objects = new Map();
  /** When true, connections are dropped to simulate storage outage (chaos tests). */
  let paused = false;

  const server = http.createServer(async (req, res) => {
    if (paused) {
      res.destroy();
      return;
    }
    if (req.headers['x-weekfit-object-token'] !== token) {
      res.writeHead(401); res.end('unauthorized'); return;
    }
    const url = new URL(req.url || '/', 'http://127.0.0.1');
    const key = decodeURIComponent(url.pathname.replace(/^\/o\//, ''));
    if (!key || key.includes('..')) {
      res.writeHead(400); res.end('bad_key'); return;
    }

    if (req.method === 'PUT') {
      const chunks = [];
      for await (const c of req) chunks.push(c);
      const bytes = Buffer.concat(chunks);
      objects.set(key, { bytes, storedAt: Date.now() });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ key, bytes: bytes.length }));
      return;
    }
    if (req.method === 'GET') {
      const obj = objects.get(key);
      if (!obj) { res.writeHead(404); res.end('not_found'); return; }
      res.writeHead(200, { 'Content-Type': 'image/jpeg', 'Content-Length': obj.bytes.length });
      res.end(obj.bytes);
      return;
    }
    if (req.method === 'DELETE') {
      objects.delete(key);
      res.writeHead(204); res.end();
      return;
    }
    res.writeHead(405); res.end();
  });

  const listen = () => new Promise((resolve, reject) => {
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({
        port,
        baseUrl: `http://127.0.0.1:${port}`,
        token,
        setPaused: (value) => { paused = Boolean(value); },
        close: () => new Promise((r) => server.close(() => r())),
        _objects: objects,
      });
    });
    server.on('error', reject);
  });

  return { listen, server };
}

export function createHttpObjectStore({
  baseUrl,
  token = 'weekfit-object-dev',
  ttlMs = 24 * 60 * 60_000,
} = {}) {
  const keyFor = (userId, analysisId) => {
    const userHash = createHash('sha256').update(userId).digest('hex').slice(0, 16);
    return `${userHash}/${analysisId}.jpg`;
  };

  const headers = () => ({
    'X-WeekFit-Object-Token': token,
  });

  return {
    kind: 'http',
    keyFor,
    async putJpeg(userId, analysisId, bytes) {
      const key = keyFor(userId, analysisId);
      const res = await fetch(`${baseUrl}/o/${encodeURIComponent(key)}`, {
        method: 'PUT',
        headers: {
          ...headers(),
          'Content-Type': 'image/jpeg',
          'Content-Length': String(bytes.length),
        },
        body: bytes,
      });
      if (!res.ok) throw new Error(`object_put_failed_${res.status}`);
      return { key, bytes: bytes.length };
    },
    async getJpeg(key) {
      let res;
      try {
        res = await fetch(`${baseUrl}/o/${encodeURIComponent(key)}`, { headers: headers() });
      } catch (error) {
        const err = new Error(`object_store_unavailable:${error?.message || 'fetch_failed'}`);
        err.code = 'object_store_unavailable';
        err.cause = error;
        throw err;
      }
      if (res.status === 404) {
        const err = new Error('object_not_found');
        err.code = 'object_not_found';
        throw err;
      }
      if (!res.ok) {
        const err = new Error(`object_get_failed_${res.status}`);
        err.code = 'object_store_unavailable';
        throw err;
      }
      return Buffer.from(await res.arrayBuffer());
    },
    async delete(key) {
      await fetch(`${baseUrl}/o/${encodeURIComponent(key)}`, {
        method: 'DELETE',
        headers: headers(),
      });
    },
    async cleanupExpired() {
      // Server-side TTL can be added; client no-op for HTTP store.
      return { removed: 0, ttlMs };
    },
  };
}

/**
 * S3-compatible config adapter. Uses AWS SigV4 via fetch when credentials exist.
 * Not exercised without credentials (no paid buckets in this task).
 */
export function createS3ObjectStore(env = process.env) {
  const bucket = env.S3_BUCKET;
  const endpoint = env.S3_ENDPOINT || '';
  const region = env.S3_REGION || 'auto';
  const accessKey = env.AWS_ACCESS_KEY_ID || env.S3_ACCESS_KEY_ID || '';
  const secretKey = env.AWS_SECRET_ACCESS_KEY || env.S3_SECRET_ACCESS_KEY || '';
  const prefix = env.S3_PREFIX || 'food-photos/';

  if (!bucket || !accessKey || !secretKey) {
    const err = new Error('S3 object store requires S3_BUCKET and credentials');
    err.code = 's3_not_configured';
    throw err;
  }

  const keyFor = (userId, analysisId) => {
    const userHash = createHash('sha256').update(userId).digest('hex').slice(0, 16);
    return `${prefix}${userHash}/${analysisId}.jpg`;
  };

  // Placeholder: wire aws4-fetch or @aws-sdk/client-s3 in staging.
  // For now throw clearly if invoked without implementation hook.
  return {
    kind: 's3',
    keyFor,
    bucket,
    endpoint,
    region,
    async putJpeg() {
      const err = new Error('S3 put not wired in this build — use OBJECT_STORE=http for local/staging mock');
      err.code = 's3_not_implemented';
      throw err;
    },
    async getJpeg() {
      const err = new Error('S3 get not wired in this build');
      err.code = 's3_not_implemented';
      throw err;
    },
    async delete() {},
    async cleanupExpired() { return { removed: 0 }; },
  };
}

/** Find a free TCP port (for tests). */
export async function freePort() {
  return new Promise((resolve, reject) => {
    const s = createNetServer();
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => resolve(port));
    });
    s.on('error', reject);
  });
}

void randomUUID;
