import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, access, rm, utimes, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createFileJobStore } from './async/job-store.mjs';
import { createLocalObjectStore } from './async/object-store.mjs';
import { createRuntimeMonitor, observedProviderFetch, resourceAlerts, safeUsage } from './observability.mjs';

async function directory(t) {
  const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-monitor-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

test('idle claims release ready listeners after 240 timeouts, and wake releases its listener', async (t) => {
  const store = await createFileJobStore({ dataDir: await directory(t) });
  for (let i = 0; i < 240; i++) {
    assert.equal(await store.claimNext({ workerId: 'idle', leaseMs: 5000, waitMs: 1 }), null);
    assert.equal(store.metrics().readyWaiters, 0);
  }
  const waiting = store.claimNext({ workerId: 'awake', leaseMs: 5000, waitMs: 1000 });
  const { job } = await store.createQueuedJob({ analysisId: 'wake', userId: 'a', photoKey: 'a/wake.jpg' });
  await store.enqueue(job.analysisId, job.userId);
  assert.equal((await waiting).analysisId, 'wake');
  assert.equal(store.metrics().readyWaiters, 0);
});

test('cleanup covers scoped and legacy terminal jobs but preserves active jobs and safety ledgers', async (t) => {
  const dir = await directory(t);
  const store = await createFileJobStore({ dataDir: dir });
  const old = Date.now() - 10000;
  for (const [name, status] of [['done', 'completed'], ['bad', 'failed'], ['active', 'processing'], ['queued', 'queued']]) {
    await store.saveJob({ analysisId: name, userId: 'a', status, expiresAt: old, photoKey: `a/${name}.jpg` });
  }
  await writeFile(path.join(dir, 'jobs', 'legacy.json'), JSON.stringify({ status: 'completed', expiresAt: old }));
  for (const folder of ['coach-guard', 'photo-calls', 'quota', 'idempotency']) {
    await mkdir(path.join(dir, folder), { recursive: true });
    await writeFile(path.join(dir, folder, 'sentinel.json'), 'keep');
  }
  assert.equal((await store.cleanupExpiredJobs()).removed, 3);
  assert.equal(await store.getJob('done', 'a'), null);
  assert.equal((await store.getJob('active', 'a')).status, 'processing');
  assert.deepEqual([...await store.protectedPhotoKeys()].sort(), ['a/active.jpg', 'a/queued.jpg']);
  for (const folder of ['coach-guard', 'photo-calls', 'quota', 'idempotency']) {
    assert.equal(await readFile(path.join(dir, folder, 'sentinel.json'), 'utf8'), 'keep');
  }
});

test('photo cleanup removes expired jpg and abandoned tmp, preserves active/recent files and ignores symlinks', async (t) => {
  const dir = await directory(t);
  const objects = createLocalObjectStore({ root: dir, ttlMs: 1000 });
  const photos = path.join(dir, 'photos', 'owner');
  await mkdir(photos, { recursive: true });
  const old = new Date(Date.now() - 10000);
  for (const name of ['old.jpg', 'active.jpg', 'orphan.tmp', 'keep.json', 'recent.jpg']) {
    const file = path.join(photos, name);
    await writeFile(file, 'bytes');
    if (name !== 'recent.jpg') await utimes(file, old, old);
  }
  const outside = path.join(dir, 'external.jpg');
  await writeFile(outside, 'outside');
  await utimes(outside, old, old);
  await symlink(outside, path.join(photos, 'link.jpg'));
  assert.equal((await objects.cleanupExpired(Date.now(), new Set(['owner/active.jpg']))).removed, 2);
  for (const name of ['active.jpg', 'recent.jpg', 'keep.json', 'link.jpg']) await access(path.join(photos, name));
  assert.equal(await readFile(outside, 'utf8'), 'outside');
});

test('transport telemetry counts one call and excludes payloads, credentials and arbitrary usage fields', async (t) => {
  const lines = [];
  const original = console.log;
  console.log = (s) => lines.push(JSON.parse(s));
  t.after(() => { console.log = original; });
  let calls = 0;
  const response = await observedProviderFetch(async () => {
    calls++;
    return new Response(JSON.stringify({ secret: 'health-body', usage: { input_tokens: 9, output_tokens: 3, secret: 'bad' } }), { headers: { 'x-request-id': 'req-safe' } });
  }, 'https://api.openai.com/v1/responses', { headers: { Authorization: 'secret-key' }, body: 'health-input' }, { endpoint: 'food_photo', model: 'mock', mock: true });
  await response.json();
  assert.equal(calls, 1);
  assert.deepEqual(lines.map(x => x.phase), ['started', 'finished']);
  assert.equal(lines[0].callId, lines[1].callId);
  assert.equal(lines[1].inputTokens, 9);
  assert.equal(lines[1].providerRequestId, 'req-safe');
  assert.doesNotMatch(JSON.stringify(lines), /health-body|health-input|secret-key|"bad"/);
  await assert.rejects(() => observedProviderFetch(async () => { calls++; throw Error('secret-error'); }, '', {}, { endpoint: 'food_photo', mock: true }));
  assert.equal(calls, 2);
  assert.equal(lines.at(-1).phase, 'network_error');
  assert.doesNotMatch(JSON.stringify(lines), /secret-error/);
  assert.equal(safeUsage({ input_tokens: 'bad' }).inputTokens, null);
});

test('runtime monitor caches samples, reads quotas and signals thresholds without mutating ledgers', async (t) => {
  const dir = await directory(t);
  const day = new Date().toISOString().slice(0, 10);
  const coach = path.join(dir, 'coach-summary');
  for (const [folder, file] of [[path.join(dir, 'quota', 'global', day), 'a.res'], [path.join(coach, 'coach-guard', 'budget', 'utc-day', day), 'a.json']]) {
    await mkdir(folder, { recursive: true });
    await writeFile(path.join(folder, file), 'keep');
  }
  const rows = [];
  const monitor = createRuntimeMonitor({ dataDir: dir, summaryStoreDir: coach, photoLimit: 1, coachLimit: 1,
    queueSnapshot: async () => ({ readyWaiters: 0, asyncQueueDepth: 0 }), emit: row => rows.push(row) });
  t.after(() => monitor.stop());
  assert.equal(monitor.snapshot(), null);
  await monitor.sample();
  const s = monitor.snapshot();
  assert.equal(s.photoReservationsUtcDay, 1);
  assert.equal(s.coachReservationsUtcDay, 1);
  assert.ok(s.diskTotalBytes > 0);
  assert.ok(s.alerts.includes('coach_quota_near_limit'));
  assert.deepEqual(resourceAlerts({ diskUsedRatio: 0.9, memoryUsedRatio: 0.9, readyWaiters: 201 }), ['disk_critical', 'memory_high', 'queue_waiters_high']);
  assert.deepEqual(resourceAlerts({ diskUsedRatio: null, memoryUsedRatio: null }), []);
  assert.equal(rows[0].event, 'runtime_metrics');
});
