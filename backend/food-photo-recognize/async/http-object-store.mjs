import http from 'node:http';
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
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

/** S3/R2 storage. Bucket lifecycle must expire the private food-photos/ prefix. */
export function createS3ObjectStore(env = process.env) {
  const bucket = env.S3_BUCKET;
  const endpoint = env.S3_ENDPOINT || undefined;
  const region = env.S3_REGION || 'auto';
  const accessKeyId = env.AWS_ACCESS_KEY_ID || env.S3_ACCESS_KEY_ID || '';
  const secretAccessKey = env.AWS_SECRET_ACCESS_KEY || env.S3_SECRET_ACCESS_KEY || '';
  const prefix = env.S3_PREFIX || 'food-photos/';
  const ttlMs = Number(env.PHOTO_TTL_MS || 86_400_000);
  if (!bucket || !accessKeyId || !secretAccessKey) throw Object.assign(new Error('S3 credentials required'), { code: 's3_not_configured' });
  if (env.NODE_ENV === 'production' && endpoint && new URL(endpoint).protocol !== 'https:') {
    throw new Error('Production S3 endpoint must use HTTPS');
  }
  const client = new S3Client({ region, endpoint, forcePathStyle: Boolean(endpoint), maxAttempts: 1,
    credentials: { accessKeyId, secretAccessKey, ...(env.AWS_SESSION_TOKEN ? { sessionToken: env.AWS_SESSION_TOKEN } : {}) } });
  const keyFor = (userId, analysisId) => `${prefix}${createHash('sha256').update(userId).digest('hex').slice(0, 16)}/${analysisId}.jpg`;
  const checkedKey = key => {
    if (typeof key !== 'string' || !key.startsWith(prefix) || key.includes('..')) throw new Error('invalid_object_key');
    return key;
  };
  const send = async command => {
    try { return await client.send(command, { abortSignal: AbortSignal.timeout(15_000) }); }
    catch (cause) { throw Object.assign(new Error('object_store_unavailable', { cause }), { code: 'object_store_unavailable' }); }
  };
  return {
    kind: 's3', bucket, endpoint, region, keyFor,
    async putJpeg(userId, analysisId, bytes) {
      const key = keyFor(userId, analysisId);
      await send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: bytes,
        ContentType: 'image/jpeg', ContentLength: bytes.length,
        Metadata: { 'expires-at': String(Date.now() + ttlMs) } }));
      return { key, bytes: bytes.length };
    },
    async getJpeg(key) {
      const response = await send(new GetObjectCommand({ Bucket: bucket, Key: checkedKey(key) }));
      if (Number(response.Metadata?.['expires-at']) <= Date.now()) {
        response.Body?.destroy();
        throw Object.assign(new Error('photo_expired'), { code: 'photo_expired' });
      }
      const chunks = []; let size = 0;
      try {
        for await (const chunk of response.Body) {
          size += chunk.length;
          if (size > 8 * 1024 * 1024) throw new Error('stored_photo_too_large');
          chunks.push(chunk);
        }
      } finally { response.Body?.destroy(); }
      return Buffer.concat(chunks);
    },
    async delete(key) { await send(new DeleteObjectCommand({ Bucket: bucket, Key: checkedKey(key) })); },
    async cleanupExpired() { return { removed: 0, managedBy: 'bucket_lifecycle', ttlMs }; },
    close() { client.destroy(); },
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
