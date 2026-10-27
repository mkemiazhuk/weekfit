import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { configuration, createServer } from './server.mjs';
import { ServiceError } from './recognition.mjs';
import {
  assertDurableGeneration,
  errorForDirectoryFsync,
  probeDirectoryDurable,
} from './async/atomic-fs.mjs';
import { fileLedgerGenerationRefusal } from './photo-call-ledger.mjs';
import { makeJpegBytes } from './extended-load.mjs';

test('directory fsync failure is an explicit durability refusal', () => {
  const error = errorForDirectoryFsync({ code: 'EINVAL' });
  assert.equal(error instanceof ServiceError, true);
  assert.equal(error.code, 'durability_unconfirmed');
  assert.equal(error.status, 503);
  assert.equal(error.detail, 'directory_fsync_EINVAL');
  assert.throws(
    () => assertDurableGeneration({
      isProduction: true,
      directoryDurability: { confirmed: false, reason: 'directory_fsync_unconfirmed', errno: 'EINVAL' },
    }),
    (caught) => caught.code === 'durability_unconfirmed' && caught.detail === 'directory_fsync_EINVAL',
  );
  assert.doesNotThrow(() => assertDurableGeneration({
    isProduction: false,
    directoryDurability: { confirmed: false, reason: 'directory_fsync_unconfirmed', errno: 'EINVAL' },
  }));
});

test('a local directory probe confirms durability', async (t) => {
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-durable-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const status = probeDirectoryDurable(dir);
  assert.equal(status.confirmed, true);
  assert.equal(status.reason, null);
});

test('redis without one shared data dir refuses file-ledger generation', () => {
  const refused = fileLedgerGenerationRefusal({
    stateBackend: 'redis',
    allowSingleNode: false,
    dataDirExplicit: false,
    objectStoreKind: 'http',
  });
  assert.equal(refused.detail, 'redis_separate_data_dir');
  assert.equal(fileLedgerGenerationRefusal({
    stateBackend: 'redis',
    allowSingleNode: true,
    dataDirExplicit: true,
    objectStoreKind: 'local',
  }), null);
  assert.equal(fileLedgerGenerationRefusal({ stateBackend: 'file' }), null);
});

test('production blocks a new food call when directory durability is unconfirmed', async (t) => {
  let calls = 0;
  const config = configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    FOOD_PHOTO_MOCK_DELAY_MS: '0',
  });
  config.isProduction = true;
  const server = createServer(config, {
    asyncStack: null,
    directoryDurability: { confirmed: false, reason: 'directory_fsync_unconfirmed', errno: 'ENOTSUP' },
    recognize: async () => {
      calls += 1;
      throw new Error('provider must not be called');
    },
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer weekfit-dev-local-token',
      'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription',
      'Idempotency-Key': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    },
    body: JSON.stringify({
      imageBase64: makeJpegBytes(64).toString('base64'),
      mimeType: 'image/jpeg',
      locale: 'en_US',
    }),
  });
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, 'durability_unconfirmed');
  assert.equal(body.detail, 'directory_fsync_ENOTSUP');
  assert.equal(calls, 0);
  const health = await (await fetch(`http://127.0.0.1:${server.address().port}/healthz`)).json();
  assert.equal(health.directoryDurable, false);
  assert.equal(health.durabilityReason, 'directory_fsync_unconfirmed');
  assert.equal(health.durabilityErrno, 'ENOTSUP');
  assert.equal(health.mockMetrics.calls, 0);
});

test('sync food path refuses redis with a separate data dir before the provider', async (t) => {
  let calls = 0;
  const config = configuration({
    OPENAI_MOCK: '1',
    ALLOW_DEV_AUTH: '1',
    WEEKFIT_DEV_TOKEN: 'weekfit-dev-local-token',
    STATE_BACKEND: 'redis',
    REDIS_URL: 'redis://127.0.0.1:1',
    ASYNC_ANALYSIS: '1',
    OBJECT_STORE: 'http',
    OBJECT_STORE_BASE_URL: 'http://127.0.0.1:9',
  });
  const server = createServer(config, {
    asyncStack: null,
    recognize: async () => {
      calls += 1;
      throw new Error('provider must not be called');
    },
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/food/photo-recognize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer weekfit-dev-local-token',
      'X-WeekFit-Subscription-JWS': 'weekfit-dev-local-subscription',
      'Idempotency-Key': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    },
    body: JSON.stringify({
      imageBase64: makeJpegBytes(64).toString('base64'),
      mimeType: 'image/jpeg',
      locale: 'en_US',
    }),
  });
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, 'file_ledger_unsupported');
  assert.equal(body.detail, 'redis_separate_data_dir');
  assert.equal(calls, 0);
});

test('production blocks a new coach generation when directory fsync is unconfirmed', async (t) => {
  let calls = 0;
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-coach-durable-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const server = createServer({
    apiKey: 'test',
    summaryModel: 'test-model',
    summaryStoreDir: dir,
    allowDevAuth: true,
    model: 'gpt-6-astra',
    dailyLimit: 20,
    maxConcurrency: 4,
    globalDailyLimit: 200,
    coachAiEnabled: true,
    isProduction: true,
    directoryDurability: { confirmed: false, reason: 'directory_fsync_unconfirmed', errno: 'EPERM' },
  }, {
    authenticate: async (header) => header,
    summaryNow: () => new Date('2026-10-12T18:00:00Z'),
    generateSummary: async () => {
      calls += 1;
      return { result: { headline: 'Итог дня' } };
    },
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/coach/day-summary`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
    body: JSON.stringify({
      schemaVersion: 1,
      day: '2026-10-12',
      timezone: 'Europe/Warsaw',
      locale: 'ru',
      phase: 'evening',
      facts: {
        sleep: [{ id: 'sleep.duration', text: 'Last night: 6 hours sleep.' }],
        nutrition: [{ id: 'nutrition.completeness', text: 'Food log completeness unknown.' }],
        coachDecision: [{ id: 'coach.priority', text: 'One priority: wind down for sleep.' }],
      },
    }),
  });
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, 'durability_unconfirmed');
  assert.equal(body.detail, 'directory_fsync_EPERM');
  assert.equal(calls, 0);
});
