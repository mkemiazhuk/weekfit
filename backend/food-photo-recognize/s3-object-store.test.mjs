import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createS3ObjectStore } from './async/http-object-store.mjs';

test('S3 adapter signs PUT/GET/DELETE, preserves bytes, and fails on storage errors', async t => {
  const objects = new Map(); const requests = [];
  const server = http.createServer(async (req, res) => {
    requests.push({ method: req.method, authorization: req.headers.authorization });
    const key = req.url.split('?')[0];
    if (key.includes('unavailable')) { res.writeHead(503); return res.end('<Error><Code>ServiceUnavailable</Code></Error>'); }
    if (req.method === 'PUT') {
      const chunks = []; for await (const chunk of req) chunks.push(chunk);
      objects.set(key, { bytes: Buffer.concat(chunks), expires: req.headers['x-amz-meta-expires-at'] });
      res.writeHead(200); return res.end();
    }
    if (req.method === 'GET') {
      const object = objects.get(key);
      if (!object) { res.writeHead(404); return res.end('<Error><Code>NoSuchKey</Code></Error>'); }
      res.writeHead(200, { 'Content-Length': object.bytes.length, 'x-amz-meta-expires-at': object.expires }); return res.end(object.bytes);
    }
    if (req.method === 'DELETE') { objects.delete(key); res.writeHead(204); return res.end(); }
    res.writeHead(405); res.end();
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const env = { S3_BUCKET: 'test-bucket', S3_ENDPOINT: `http://127.0.0.1:${server.address().port}`, S3_REGION: 'us-east-1', S3_ACCESS_KEY_ID: 'test-access-key', S3_SECRET_ACCESS_KEY: 'test-secret-key' };
  const store = createS3ObjectStore(env);
  t.after(async () => { store.close(); await new Promise(resolve => server.close(resolve)); });
  const bytes = Buffer.from([255, 216, 1, 2, 255, 217]);
  const saved = await store.putJpeg('alice', 'test-analysis', bytes);
  assert.equal(saved.bytes, bytes.length);
  assert.deepEqual(await store.getJpeg(saved.key), bytes);
  await store.delete(saved.key);
  await assert.rejects(() => store.getJpeg(saved.key), e => e.code === 'object_store_unavailable');
  const before = requests.length;
  await assert.rejects(() => store.getJpeg('food-photos/unavailable'), e => e.code === 'object_store_unavailable');
  assert.equal(requests.length - before, 1, 'no hidden SDK retries');
  for (const req of requests) assert.match(req.authorization, /^AWS4-HMAC-SHA256 /);
  assert.throws(() => createS3ObjectStore({ ...env, NODE_ENV: 'production' }), /HTTPS/);
  await assert.rejects(() => store.getJpeg('../other-bucket'), /invalid_object_key/);
});
