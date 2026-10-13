import test from 'node:test';
import assert from 'node:assert/strict';
import { configuration, createServer } from './server.mjs';
import { makeJpegBytes } from './extended-load.mjs';

async function setup(t) {
  const server = createServer(configuration({ OPENAI_MOCK: '1', ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token', FOOD_PHOTO_MOCK_DELAY_MS: '5' }));
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise(r => server.close(r)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (route, { paid = true, auth = true, key = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' } = {}) => fetch(`${base}${route}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json',
      ...(auth ? { Authorization: 'Bearer weekfit-dev-local-token' } : {}),
      ...(paid ? { 'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription' } : {}),
      'Idempotency-Key': key },
    body: JSON.stringify({ imageBase64: makeJpegBytes(256).toString('base64'), mimeType: 'image/jpeg', locale: 'en_US' }),
  });
  return { base, post };
}

test('sync-only host accepts photo-analyze with completed envelope, shares idempotency with legacy route', async t => {
  const { base, post } = await setup(t);
  const response = await post('/v1/food/photo-analyze');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.status, 'completed');
  assert.equal(body.analysisId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert.equal(body.delivery, 'sync_compat');
  assert.ok(body.result.totals);
  const repeat = await post('/v1/food/photo-analyze');
  assert.equal(repeat.headers.get('X-WeekFit-Idempotent-Hit'), '1');
  assert.equal((await repeat.json()).status, 'completed');
  const legacy = await post('/v1/food/photo-recognize');
  assert.equal(legacy.status, 200);
  assert.equal(legacy.headers.get('X-WeekFit-Idempotent-Hit'), '1');
  assert.deepEqual((await legacy.json()).totals, body.result.totals);
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.asyncAnalysis, false);
  assert.equal(health.photoAnalyzeMode, 'sync_compat');
  assert.equal(health.mockMetrics.calls, 1);
  assert.equal(health.mockMetrics.realFetchAttempts, 0);
});

test('compatibility route keeps Firebase and paid access gates before AI', async t => {
  const { base, post } = await setup(t);
  assert.equal((await post('/v1/food/photo-analyze', { auth: false })).status, 401);
  assert.equal((await post('/v1/food/photo-analyze', { paid: false })).status, 402);
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.mockMetrics.calls, 0);
});
