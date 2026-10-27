/** Single-node capacity/safety check. Synthetic input, local HTTP, mock provider only.
 * It measures this host + mock delay, not OpenAI latency or production throughput.
 */
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { configuration, createServer } from '../server.mjs';
import { createAsyncStack } from '../async/bootstrap.mjs';
import { createWorkerRuntime } from '../async/worker-runtime.mjs';
import { createMockOpenAIAdapter } from '../openai-mock.mjs';
import { makeJpegBytes } from '../extended-load.mjs';

const dir = await mkdtemp(path.join(tmpdir(), 'weekfit-capacity-'));
const originalFetch = globalThis.fetch;
let forbiddenNetworkAttempts = 0;
globalThis.fetch = (url, options) => {
  const parsed = new URL(url);
  if (parsed.protocol !== 'http:' || parsed.hostname !== '127.0.0.1') {
    forbiddenNetworkAttempts++;
    throw new Error('capacity_check_forbids_external_network');
  }
  return originalFetch(url, { ...options, signal: AbortSignal.timeout(30000) });
};
const rows = [];
const started = performance.now();
const config = configuration({
  OPENAI_MOCK: '1', ALLOW_DEV_AUTH: '1', WEEKFIT_DEV_TOKEN: 'capacity-mock-token',
  DATA_DIR: dir, STATE_BACKEND: 'file', OBJECT_STORE: 'local', ASYNC_ANALYSIS: '1',
  FOOD_PHOTO_MOCK_DELAY_MS: '200', MAX_CONCURRENT_SCANS: '100',
  MAX_CONCURRENT_UPLOADS: '8', MAX_UPLOAD_QUEUE: '24', GLOBAL_AI_SLOTS: '16',
  DAILY_SCAN_LIMIT: '20', GLOBAL_DAILY_SCAN_LIMIT: '200', MAX_PROVIDER_CALLS_PER_DAY: '200',
  COACH_AI_ENABLED: '1', COACH_SUMMARY_SINGLE_INSTANCE: '1',
  COACH_SUMMARY_STORE_DIR: path.join(dir, 'coach-summary'),
  COACH_SUMMARY_NOW: '2026-10-27T19:00:00Z',
  COACH_SUMMARY_MAX_STARTS_PER_UTC_DAY: '100', COACH_SUMMARY_MAX_STARTS_PER_MINUTE: '10',
  COACH_SUMMARY_MAX_CONCURRENT: '2',
});
const photo = createMockOpenAIAdapter({ delayMs: 200 });
const coach = createMockOpenAIAdapter({ delayMs: 200 });
const stack = await createAsyncStack(config, { openaiFetcher: photo.fetcher });
const server = createServer(config, {
  asyncStack: stack, openaiFetcher: photo.fetcher, summaryFetcher: coach.fetcher,
  authenticate: async authorization => authorization,
  requirePaidSubscriptionJWS: () => ({ paid: true }),
});
const runtime = createWorkerRuntime({ config: stack.asyncConfig, ...stack, mockAdapter: photo });
let loop;
const percentile = (values, p) => [...values].sort((a,b) => a-b)[Math.max(0, Math.ceil(values.length*p)-1)] ?? null;
try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  loop = runtime.runLoop({ claimWaitMs: 100, localConcurrency: 8 });
  const imageBase64 = makeJpegBytes(128).toString('base64');
  const submit = async (index) => {
    const id = randomUUID();
    const user = `Bearer capacity-user-${index}`;
    const begin = performance.now();
    const r = await fetch(`${base}/v1/food/photo-analyze`, { method: 'POST',
      headers: { Authorization: user, 'Content-Type': 'application/json', 'X-WeekFit-Subscription-JWS': 'mock', 'Idempotency-Key': id, 'X-WeekFit-Analysis-Id': id },
      body: JSON.stringify({ imageBase64, mimeType: 'image/jpeg', locale: 'en' }) });
    let body = await r.json();
    const acceptMs = performance.now() - begin;
    if (![200,202].includes(r.status)) return { status: r.status, acceptMs, error: body.error };
    const deadline = performance.now()+60000;
    while (!['completed','failed'].includes(body.status) && performance.now()<deadline) {
      await new Promise(resolve => setTimeout(resolve,100));
      const poll = await fetch(`${base}/v1/food/photo-analyze/${body.analysisId}`, { headers: { Authorization: user } });
      body = await poll.json();
    }
    assert.equal(body.status,'completed',`accepted job ${index} lost or failed`);
    return { status: r.status, acceptMs, e2eMs: performance.now()-begin, completed: true };
  };
  // 100 daily users, 20 at a time, without raising any production admission limits.
  const daily=[];
  for (let wave=0;wave<5;wave++) daily.push(...await Promise.all(Array.from({length:20},(_,i)=>submit(wave*20+i))));
  assert.equal(daily.filter(x=>x.completed).length,100);
  assert.equal(photo.metrics().calls,100);
  rows.push({ phase:'daily_100_users', completed:100, acceptP95Ms:percentile(daily.map(x=>x.acceptMs),0.95), e2eP95Ms:percentile(daily.map(x=>x.e2eMs),0.95) });
  const before=photo.metrics().calls;
  const burst=await Promise.all(Array.from({length:100},(_,i)=>submit(100+i)));
  const completed=burst.filter(x=>x.completed).length;
  const rejected=burst.filter(x=>x.status===503||x.status===429).length;
  assert.equal(completed+rejected,100);
  assert.equal(photo.metrics().calls-before,completed);
  assert.ok(photo.metrics().peakParallelism<=16);
  rows.push({phase:'instant_food_burst_100',completed,rejected,peakMockProviderActive:photo.metrics().peakParallelism});
  const coachBody={schemaVersion:1,day:'2026-10-27',timezone:'Europe/Warsaw',locale:'en',facts:{sleep:[{id:'sleep.duration',text:'Synthetic sleep: 7 hours.'}]}};
  const coachPost=async(user)=> {
    const r=await fetch(`${base}/v1/coach/day-summary`,{method:'POST',headers:{Authorization:user,'Content-Type':'application/json'},body:JSON.stringify(coachBody)});
    await r.json();
    return {user,status:r.status};
  };
  const outcomes=await Promise.all(Array.from({length:100},(_,i)=>coachPost(`Bearer coach-${i}`)));
  const successes=outcomes.filter(x=>x.status===200);
  assert.ok(successes.length>=1&&successes.length<=10);
  assert.ok(outcomes.every(x=>[200,429,503].includes(x.status)));
  assert.equal(coach.metrics().calls,successes.length);
  assert.ok(coach.metrics().peakParallelism<=2);
  for(const success of successes) assert.equal((await coachPost(success.user)).status,200);
  assert.equal(coach.metrics().calls,successes.length);
  assert.equal((await fetch(`${base}/healthz`)).status,200);
  await new Promise(resolve=>setTimeout(resolve,250));
  assert.ok(stack.jobStore.metrics().readyWaiters<=1);
  assert.equal(forbiddenNetworkAttempts,0);
  rows.push({phase:'instant_coach_burst_100',completed:successes.length,rejected:100-successes.length,peakMockProviderActive:coach.metrics().peakParallelism,replayExtraCalls:0});
  console.log(JSON.stringify({event:'capacity_mock_report',openAIMock:true,realProviderNetworkAttempts:forbiddenNetworkAttempts,wallMs:Math.round(performance.now()-started),processRssBytes:process.memoryUsage().rss,rows}));
} finally {
  await runtime.stop({drainMs:2000});
  await loop;
  await new Promise(resolve=>server.close(resolve));
  globalThis.fetch=originalFetch;
  await rm(dir,{recursive:true,force:true});
}
