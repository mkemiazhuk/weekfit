import test from 'node:test';
import assert from 'node:assert/strict';
import { runLoadSuite } from './load-test.mjs';

test('food-photo load suite (mock OpenAI only)', { timeout: 180_000 }, async () => {
  const { rows, totalRealFetches } = await runLoadSuite();
  assert.equal(totalRealFetches, 0);
  assert.ok(rows.find((r) => r.label === 'burst_100'));
  assert.ok(rows.find((r) => r.label === 'spike_overload_40')?.busy503 > 0);
  assert.equal(rows.find((r) => r.label === 'idempotent_25_same_key')?.aiCalls, 1);
  assert.equal(rows.find((r) => r.label === 'no_subscription_10')?.subscription402, 10);
});
