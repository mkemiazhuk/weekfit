/**
 * Runs inside the built image with --network none.
 * Proves a production process refuses a generation when no persistent directory
 * was configured, without OPENAI_MOCK and without contacting a provider.
 */
import assert from 'node:assert/strict';
import { configuration, createServer } from './server.mjs';

const jpeg = Buffer.from([
  255, 216, 255, 192, 0, 17, 8, 0, 100, 0, 100, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0, 255, 217,
]).toString('base64');

async function productionWithoutDataDir() {
  assert.throws(
    () => configuration({
      NODE_ENV: 'production',
      OPENAI_MOCK: '1',
      OPENAI_API_KEY: 'unused-not-sent',
      FIREBASE_PROJECT_ID: 'weekfitai',
    }),
    /OPENAI_MOCK is forbidden in production/,
  );

  let calls = 0;
  const config = configuration({
    NODE_ENV: 'production',
    OPENAI_API_KEY: 'unused-not-sent',
    FIREBASE_PROJECT_ID: 'weekfitai',
    PORT: '18081',
  });
  assert.equal(config.isProduction, true);
  assert.equal(config.openAIMock, false);
  assert.equal(config.allowDevAuth, false);
  assert.equal(config.dataDirExplicit, false);

  const server = createServer(config, {
    asyncStack: null,
    authenticate: async () => 'uid-prod',
    requirePaidSubscriptionJWS: () => ({ productId: 'dev', environment: 'Sandbox' }),
    recognize: async () => {
      calls += 1;
      throw new Error('provider_was_called');
    },
  });
  await new Promise((resolve) => server.listen(18081, '127.0.0.1', resolve));
  try {
    const response = await fetch('http://127.0.0.1:18081/v1/food/photo-recognize', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer unused',
        'X-WeekFit-Subscription-JWS': 'unused',
        'Idempotency-Key': 'abababab-abab-4aba-8aba-abababababab',
      },
      body: JSON.stringify({ imageBase64: jpeg, mimeType: 'image/jpeg', locale: 'en_US' }),
    });
    const body = await response.json();
    assert.equal(response.status, 503);
    assert.equal(body.error, 'persistent_data_dir_required');
    assert.equal(body.detail, 'persistent_mount_unconfirmed');
    assert.equal(calls, 0);
    const health = await (await fetch('http://127.0.0.1:18081/healthz')).json();
    assert.equal(health.persistentDataDir, false);
    assert.equal(health.persistentDataDirReason, 'persistent_mount_unconfirmed');
    assert.equal(health.openAIMock, false);
    assert.equal(health.directoryDurable, null);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
  console.log('production without DATA_DIR blocked the generation');
}

const mode = process.argv[2];
if (mode !== 'production-no-dir') {
  console.error('usage: node image-runtime-check.mjs production-no-dir');
  process.exit(2);
}
await productionWithoutDataDir();
