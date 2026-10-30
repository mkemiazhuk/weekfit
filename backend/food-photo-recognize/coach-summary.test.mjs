import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {configuration, createServer} from './server.mjs';
import {ServiceError} from './recognition.mjs';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {validateDay,validateSummary,generateSummary,localDayAndHour,normalizeLocale,hasEnglishLanguageLeak,emptyFactsFallbackSummary,countFacts,buildInstructions,unconfirmedConclusionIssues,SUMMARY_PROMPT_VERSION,SUMMARY_LIMITS,summaryResponseSchema,evidenceEnumForSchema} from './coach-summary.mjs';

const input=()=>({schemaVersion:1,day:'2026-10-12',timezone:'Europe/Warsaw',locale:'ru',phase:'evening',facts:{sleep:[{id:'sleep.duration',text:'Last night: 6 hours sleep.'}],nutrition:[{id:'nutrition.completeness',text:'Food log completeness unknown.'}],coachDecision:[{id:'coach.priority',text:'One priority: wind down for sleep.'}]}});
const result=()=>({headline:'Итог дня',today:{text:'Сон был коротким.',evidenceIds:['sleep.duration']},now:{text:'Пора готовиться ко сну.',evidenceIds:['coach.priority']},tomorrow:{text:'План на завтра пока неизвестен.',evidenceIds:[]},limitations:['Питание записано не полностью.']});
async function directory(t){const dir=await mkdtemp(path.join(tmpdir(),'weekfit-summary-'));t.after(()=>rm(dir,{recursive:true,force:true}));return dir;}
async function server(t,dir,generateSummary,options={}) {
  const config={apiKey:'test',summaryModel:'test-model',summaryStoreDir:dir,allowDevAuth:true,model:'test-photo',dailyLimit:20,maxConcurrency:4,globalDailyLimit:200,summaryOncePerDay:true,...options.config};
  const s=createServer(config,{generateSummary,authenticate:async h=>{if(!h)throw new ServiceError('unauthorized',401);return h;},summaryNow:()=>new Date('2026-10-12T18:00:00Z'),...options.dependencies});
  s.listen(0,'127.0.0.1');await once(s,'listening');t.after(()=>s.close());
  return {s,post:async(body,token='Bearer a')=>fetch(`http://127.0.0.1:${s.address().port}/v1/coach/day-summary`,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:token}:{})},body:JSON.stringify(body)})};
}
test('missing facts remain unknown',()=>assert.deepEqual(validateDay(input()).facts.tomorrow,[]));
test('invalid dates and timezones rejected',()=>{for(const change of [{day:'2026-02-31'},{timezone:'bad/zone'}])assert.throws(()=>validateDay({...input(),...change}));});
test('store/legacy clients: missing locale, regional tags and Accept-Language still validate',()=>{
  assert.equal(normalizeLocale(undefined,'pl-PL,en;q=0.8'),'pl');
  assert.equal(normalizeLocale('pl_PL'),'pl');
  assert.equal(normalizeLocale('zh'),'zh-Hans');
  assert.equal(normalizeLocale('xx'),'en');
  const legacy={schemaVersion:1,day:'2026-10-12',timezone:'Europe/Warsaw',facts:{sleep:[{id:'sleep.duration',text:'Last night: 6 hours sleep.'}]}};
  const a=validateDay(legacy,{acceptLanguage:'pl-PL,en;q=0.8'});
  assert.equal(a.locale,'pl');
  assert.equal(a.phase,'evening');
  assert.equal(validateDay({...input(),locale:'pl-PL'}).locale,'pl');
  assert.equal(validateDay({...input(),locale:'xx'}).locale,'en');
  // Unknown top-level / fact-group keys must not break older or newer clients.
  const withExtra={...input(),clientBuild:42,facts:{...input().facts,futureGroup:[{id:'x',text:'ignore'}]}};
  assert.equal(validateDay(withExtra).locale,'ru');
});
test('english leak detector catches store-client English notes under Polish',()=>{
  assert.equal(hasEnglishLanguageLeak('You have logged only one meal so far today and your food log completeness is unknown.','pl'),true);
  assert.equal(hasEnglishLanguageLeak('Spacer był spokojniejszy niż zwykle — daj nocom więcej snu.','pl'),false);
  assert.equal(hasEnglishLanguageLeak('You walked 3.8 km today.','en'),false);
});
test('duplicate IDs and excessive text rejected',()=>{const b=input();b.facts.feeling=[b.facts.sleep[0]];assert.throws(()=>validateDay(b));b.facts.feeling=[{id:'feeling',text:'a'.repeat(501)}];assert.throws(()=>validateDay(b));});
test('empty or missing facts validate without OpenAI and produce localized fallback',()=>{
  const empty=validateDay({...input(),facts:{}});
  assert.equal(countFacts(empty.facts).total,0);
  const missing=validateDay({schemaVersion:1,day:'2026-10-12',timezone:'Europe/Warsaw',locale:'pl',phase:'evening'});
  assert.equal(countFacts(missing.facts).total,0);
  const fb=emptyFactsFallbackSummary('pl');
  assert.doesNotThrow(()=>validateSummary(fb,missing));
  assert.match(fb.today.text,/brakuje danych/i);
  assert.deepEqual(fb.today.evidenceIds,[]);
});
test('invented evidence rejected',()=>{const r=result();r.today.evidenceIds=['invented'];assert.throws(()=>validateSummary(r,validateDay(input())),/invalid_summary_result/);});
test('english summary under non-english locale is rejected',()=>{
  const r=result();
  r.headline='Day wrap';
  r.today={text:'You have logged only one meal so far today and your food log completeness is unknown.',evidenceIds:['sleep.duration']};
  r.now={text:'Wind down for sleep tonight.',evidenceIds:['coach.priority']};
  r.tomorrow={text:'Tomorrow is still open.',evidenceIds:[]};
  r.limitations=[];
  assert.throws(()=>validateSummary(r,validateDay({...input(),locale:'pl'})),/invalid_summary_result/);
});
test('Warsaw DST determines 20:00 locally',()=>{assert.deepEqual(localDayAndHour(new Date('2026-10-12T18:00:00Z'),'Europe/Warsaw'),{day:'2026-10-12',hour:20});assert.equal(localDayAndHour(new Date('2026-11-12T19:00:00Z'),'Europe/Warsaw').hour,20);});
test('duplicate calls return persisted answer',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});assert.equal((await post(input())).status,200);const r=await(await post(input())).json();assert.equal(r.reused,true);assert.equal(calls,1);});
test('changed meals or plans cannot buy another call for the same language',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});
  await post(input());
  const b=input();
  b.facts.tomorrow=[{id:'tomorrow.run',text:'New run'}];
  assert.equal((await post(b)).status,200);
  assert.equal(calls,1);
});
test('language change reuses the day reservation and does not call the provider again',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});
  assert.equal((await post(input())).status,200);
  const en=await(await post({...input(),locale:'en'})).json();
  assert.equal(en.reused,true);
  assert.equal(en.locale,'ru');
  assert.equal(en.headline,'Итог дня');
  assert.equal(calls,1);
});
test('parallel identical requests invoke provider at most once',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;await new Promise(r=>setTimeout(r,40));return {result:result()};});const rs=await Promise.all([post(input()),post(input()),post(input())]);assert.equal(calls,1);assert.ok(rs.every(r=>[200,409].includes(r.status)));});
test('restart uses stored answer without invoking AI',async t=>{const dir=await directory(t);const a=await server(t,dir,async()=>({result:result()}));await a.post(input());await new Promise(r=>a.s.close(r));let calls=0;const b=await server(t,dir,async()=>{calls++;return {result:result()};});assert.equal((await b.post(input())).status,200);assert.equal(calls,0);});
test('provider failure is terminal even after restart',async t=>{const dir=await directory(t);let calls=0;const a=await server(t,dir,async()=>{calls++;throw new Error('down');});assert.equal((await a.post(input())).status,500);const b=await server(t,dir,async()=>{calls++;return {result:result()};});assert.equal((await b.post(input())).status,409);assert.equal(calls,1);});
test('timeout cannot automatically or manually regenerate',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;throw Object.assign(new Error(),{name:'TimeoutError'});});assert.equal((await post(input())).status,504);assert.equal((await post(input())).status,409);assert.equal(calls,1);});
test('storage scoped to authenticated UID',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});await post(input(),'Bearer a');await post(input(),'Bearer b');assert.equal(calls,2);});
test('no auth means no provider call',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});assert.equal((await post(input(),null)).status,401);assert.equal(calls,0);});
test('cannot generate before 20:00 or backdate requests',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};},{dependencies:{summaryNow:()=>new Date('2026-10-12T17:59:59Z')}});assert.equal((await post(input())).status,422);assert.equal((await post({...input(),day:'2026-10-11'})).status,422);assert.equal(calls,0);});
test('next local day permits one new request',async t=>{let calls=0;const dir=await directory(t);const generate=async()=>{calls++;return {result:result()};};const a=await server(t,dir,generate);await a.post(input());await new Promise(r=>a.s.close(r));const b=await server(t,dir,generate,{dependencies:{summaryNow:()=>new Date('2026-10-13T18:00:00Z')}});assert.equal((await b.post({...input(),day:'2026-10-13'})).status,200);assert.equal(calls,2);});
test('storage misconfiguration fails closed without AI',async t=>{let calls=0;const {post}=await server(t,'',async()=>{calls++;return {result:result()};});assert.equal((await post(input())).status,503);assert.equal(calls,0);});
test('concurrency limit is acquired before asynchronous reservation',async t=>{let running=0,peak=0;const {post}=await server(t,await directory(t),async()=>{running++;peak=Math.max(peak,running);await new Promise(r=>setTimeout(r,40));running--;return {result:result()};},{config:{summaryConcurrency:1}});const rs=await Promise.all([post(input(),'Bearer a'),post(input(),'Bearer b'),post(input(),'Bearer c')]);assert.equal(peak,1);assert.equal(rs.filter(r=>r.status===200).length,1);assert.equal(rs.filter(r=>r.status===503).length,2);});
test('structured output has bounded tokens, no photo and no storage',async()=>{let sent;const r=await generateSummary(validateDay(input()),{apiKey:'test',summaryModel:'test-model'},async(url,opts)=>{sent=JSON.parse(opts.body);return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(result())}]}]})};});assert.equal(sent.store,false);assert.equal(sent.max_output_tokens,8192);assert.equal(sent.text.format.strict,true);assert.equal(sent.reasoning,undefined);assert.equal(r.result.headline,'Итог дня');assert.match(sent.instructions,/25.45 words/);assert.equal(SUMMARY_PROMPT_VERSION,15);assert.match(sent.instructions,/personal activity, sleep and recovery coach/);assert.match(sent.instructions,/LANGUAGE LOCK/);assert.match(sent.instructions,/Russian/);assert.match(sent.instructions,/SEVEN days/);assert.match(sent.instructions,/Hard bans/);assert.match(sent.instructions,/At most ONE next-step/);assert.match(sent.instructions,/ready for load/);assert.match(sent.instructions,/single HRV/);assert.match(sent.instructions,/active calories/);assert.match(sent.instructions,/SAME cautious conclusion/);assert.match(sent.instructions,/several days/);assert.match(sent.instructions,/one recommendation for this evening/);assert.match(sent.instructions,/Do not recite/);assert.match(sent.instructions,/silently verify/);assert.match(sent.instructions,/Never claim professional credentials/);});
test('empty facts return fallback without calling the provider',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};},{
    config:{summaryOncePerDay:false},
    dependencies:{summaryNow:()=>new Date('2026-10-12T18:00:00Z')}
  });
  const res=await post({schemaVersion:1,day:'2026-10-12',timezone:'Europe/Warsaw',locale:'pl',phase:'evening',facts:{}});
  assert.equal(res.status,200);
  const body=await res.json();
  assert.equal(body.source,'fallback');
  assert.equal(body.promptVersion,SUMMARY_PROMPT_VERSION);
  assert.equal(body.factTotal,0);
  assert.equal(body.reused,false);
  assert.match(body.today.text,/brakuje danych/i);
  assert.equal(calls,0);
});
test('unconfirmed-conclusions v11 fixture is schema-valid yet fails quality lint; prompt hardens claims',async()=>{
  const fixturePath=path.join(path.dirname(fileURLToPath(import.meta.url)),'fixtures/coach-summary/unconfirmed-conclusions-v11.json');
  const fixture=JSON.parse(await readFile(fixturePath,'utf8'));
  const validated=validateDay(fixture.input);
  assert.doesNotThrow(()=>validateSummary(fixture.badResponse,validated));
  const issues=unconfirmedConclusionIssues(fixture.badResponse);
  for (const required of [
    'unconfirmed_readiness_or_recovery_praise',
    'sparse_coverage_only_in_limitations',
    'norm_compare_without_baseline_evidence',
    'skip_training_from_single_hrv',
    'intensity_from_active_calories',
    'past_feeling_as_today',
    'now_stronger_than_today'
  ]) assert.ok(issues.includes(required),`expected ${required}, got ${issues.join(',')}`);
  const instructions=buildInstructions(validated);
  assert.match(instructions,/ready for load/);
  assert.match(instructions,/sparse\/rare measurements/);
  assert.match(instructions,/matching baseline fact ID/);
  assert.match(instructions,/several days across the window/);
  assert.match(instructions,/Past self-reported feeling/);
  assert.match(instructions,/single HRV reading/);
  assert.match(instructions,/active calories \/ active energy/);
  assert.match(instructions,/SAME cautious conclusion as today/);
  assert.equal(SUMMARY_PROMPT_VERSION,15);
  assert.match(instructions,/one recommendation for this evening/);
  assert.match(instructions,/Do not recite/);
  assert.match(instructions,/Before returning JSON, silently verify/);
  assert.match(instructions,/Never claim professional credentials/);
});
test('malformed day and unauthorized still fail',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});
  assert.equal((await post({...input(),day:'not-a-date'})).status,400);
  assert.equal((await post(input(),null)).status,401);
  assert.equal(calls,0);
});
test('once-per-day flag and unrestricted header cannot call before 20:00 or twice',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};},{
    config:{summaryOncePerDay:false,summaryAllowUnrestrictedHeader:true},
    dependencies:{summaryNow:()=>new Date('2026-10-12T10:00:00Z')}
  });
  assert.equal((await post(input())).status,422);
  assert.equal((await post(input())).status,422);
  assert.equal(calls,0);
});
test('dev unrestricted header does not bypass the evening window or the day claim',async t=>{
  let calls=0;
  const dir=await directory(t);
  const config={apiKey:'test',summaryModel:'test-model',summaryStoreDir:dir,allowDevAuth:true,model:'test-photo',dailyLimit:20,maxConcurrency:4,globalDailyLimit:200,summaryOncePerDay:true,summaryAllowUnrestrictedHeader:true};
  const s=createServer(config,{
    generateSummary:async()=>{calls++;return {result:result()};},
    authenticate:async()=>'local-developer',
    summaryNow:()=>new Date('2026-10-12T18:00:00Z')
  });
  s.listen(0,'127.0.0.1');await once(s,'listening');t.after(()=>s.close());
  const post=async()=>fetch(`http://127.0.0.1:${s.address().port}/v1/coach/day-summary`,{
    method:'POST',
    headers:{
      'Content-Type':'application/json',
      Authorization:'Bearer a',
      'X-WeekFit-Coach-Summary-Unrestricted':'1'
    },
    body:JSON.stringify(input())
  });
  assert.equal((await post()).status,200);
  assert.equal((await post()).status,200);
  assert.equal(calls,1);
});
test('turning the once-per-day flag off does not ignore an existing claim',async t=>{
  const dir=await directory(t);
  let calls=0;
  const once=await server(t,dir,async()=>{calls++;return {result:result()};},{config:{summaryOncePerDay:true}});
  assert.equal((await once.post(input())).status,200);
  await new Promise(r=>once.s.close(r));
  const open=await server(t,dir,async()=>{calls++;return {result:result()};},{
    config:{summaryOncePerDay:false},
    dependencies:{summaryNow:()=>new Date('2026-10-12T18:30:00Z')}
  });
  const again=await open.post(input());
  assert.equal(again.status,200);
  assert.equal((await again.json()).reused,true);
  assert.equal(calls,1);
});

test('weekly evidence accepted without breaking legacy snapshots or evidence validation',()=>{
  const b=input();
  b.facts.recentSleep=[{id:'history.sleep.2026-10-12',text:'Wake-day 2026-10-12: asleep=505 min.'}];
  b.facts.recentActivity=[{id:'history.activity.2026-10-11',text:'Local day 2026-10-11: active energy=1747 kcal; day complete=true.'}];
  b.facts.baseline=[{id:'baseline.hrvSDNN',text:'Prior 28-day reference: insufficient baseline.'}];
  const validated=validateDay(b);
  const answer=result();
  answer.today.evidenceIds=['history.sleep.2026-10-12','history.activity.2026-10-11'];
  assert.doesNotThrow(()=>validateSummary(answer,validated));
  assert.throws(()=>validateSummary(answer,validateDay(input())),/invalid_summary_result/);
});

test('history remains bounded and cannot introduce duplicate evidence IDs',()=>{
  const b=input(); b.facts.recentSleep=Array.from({length:41},(_,i)=>({id:`h.${i}`,text:'Sleep history'}));
  assert.throws(()=>validateDay(b),/invalid_day_snapshot/);
  const ok=input(); ok.facts.recentSleep=Array.from({length:40},(_,i)=>({id:`h.${i}`,text:'Sleep history'}));
  assert.doesNotThrow(()=>validateDay(ok));
  b.facts.recentSleep=[b.facts.sleep[0]];
  assert.throws(()=>validateDay(b),/invalid_day_snapshot/);
});

test('mock clock keeps one coach call across replay, language, GET and a failed retry', async (t) => {
  const dir = await directory(t);
  const token = 'weekfit-dev-local-token';
  const listen = async (extra) => {
    const config = configuration({
      OPENAI_MOCK: '1',
      ALLOW_DEV_AUTH: '1',
      WEEKFIT_DEV_TOKEN: token,
      COACH_SUMMARY_STORE_DIR: dir,
      COACH_SUMMARY_NOW: '2026-10-12T18:00:00.000Z',
      FOOD_PHOTO_MOCK_DELAY_MS: '40',
      COACH_AI_ENABLED: '1',
      ...extra,
    });
    const server = createServer(config);
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    t.after(() => server.close());
    return server;
  };
  const post = (server, body, bearer = token) => fetch(`http://127.0.0.1:${server.address().port}/v1/coach/day-summary`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
  const calls = async (server) => (await (await fetch(`http://127.0.0.1:${server.address().port}/healthz`)).json()).mockMetrics.calls;

  const first = await listen();
  const parallel = await Promise.all([post(first, input()), post(first, input()), post(first, input())]);
  assert.ok(parallel.every((response) => response.status === 200 || response.status === 409));
  assert.equal(await calls(first), 1);
  const changed = await post(first, { ...input(), locale: 'en' });
  const changedBody = await changed.json();
  assert.equal(changed.status, 200);
  assert.equal(changedBody.reused, true);
  assert.equal(changedBody.locale, 'ru');
  assert.equal(changedBody.headline, 'Итог дня');
  const saved = await fetch(`http://127.0.0.1:${first.address().port}/v1/coach/day-summary?day=2026-10-12&timezone=Europe%2FWarsaw`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal((await saved.json()).headline, 'Итог дня');
  assert.equal(await calls(first), 1);
  await new Promise((resolve) => first.close(resolve));

  const restarted = await listen();
  const replay = await post(restarted, input());
  assert.equal(replay.status, 200);
  assert.equal((await replay.json()).reused, true);
  assert.equal(await calls(restarted), 0);
  await new Promise((resolve) => restarted.close(resolve));

  const broken = await listen({ FOOD_PHOTO_MOCK_SCENARIO: 'server_error' });
  const failed = await post(broken, input(), `${token}.uid-err`);
  assert.equal(failed.status, 502);
  assert.equal((await failed.json()).error, 'provider_error');
  assert.equal((await post(broken, input(), `${token}.uid-err`)).status, 409);
  assert.equal(await calls(broken), 1);
  await new Promise((resolve) => broken.close(resolve));
  const brokenAgain = await listen();
  assert.equal((await post(brokenAgain, input(), `${token}.uid-err`)).status, 409);
  assert.equal(await calls(brokenAgain), 0);
  await new Promise((resolve) => brokenAgain.close(resolve));

  const invalid = await listen({ FOOD_PHOTO_MOCK_SCENARIO: 'coach_invalid' });
  const bad = await post(invalid, input(), `${token}.uid-bad`);
  assert.equal(bad.status, 502);
  assert.equal((await bad.json()).error, 'invalid_summary_result');
  assert.equal((await post(invalid, input(), `${token}.uid-bad`)).status, 409);
  assert.equal(await calls(invalid), 1);
  await new Promise((resolve) => invalid.close(resolve));
  const invalidAgain = await listen();
  assert.equal((await post(invalidAgain, input(), `${token}.uid-bad`)).status, 409);
  assert.equal(await calls(invalidAgain), 0);
});

test('weekly context reaches provider unchanged and outputs must cite supplied facts',async()=>{
  const b=input(); b.facts.recentVitals=[{id:'history.vitals.2026-10-12',text:'HRV unknown; RHR unknown; sparse readings.'}];
  let sent;
  await generateSummary(validateDay(b),{apiKey:'test',summaryModel:'mock'},async(_,opts)=>{
    sent=JSON.parse(opts.body);
    return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(result())}]}]})};
  });
  assert.deepEqual(JSON.parse(sent.input[0].content[0].text).facts.recentVitals,b.facts.recentVitals);
});

function rejectedSummary(value, day = validateDay(input())) {
  try {
    validateSummary(value, day);
  } catch (error) {
    return error;
  }
  assert.fail('expected invalid_summary_result');
}

test('summary rejection names the check and the exact length or count boundary', () => {
  assert.deepEqual(SUMMARY_LIMITS, {
    headlineChars: 120,
    passageChars: 700,
    limitationChars: 200,
    evidenceIdsPerPassage: 10,
    limitations: 6,
  });
  const day = validateDay(input());
  const atHeadline = result();
  atHeadline.headline = 'Я'.repeat(SUMMARY_LIMITS.headlineChars);
  assert.doesNotThrow(() => validateSummary(atHeadline, day));
  const longHeadline = result();
  longHeadline.headline = 'Я'.repeat(SUMMARY_LIMITS.headlineChars + 1);
  const headline = rejectedSummary(longHeadline, day);
  assert.equal(headline.code, 'invalid_summary_result');
  assert.equal(headline.validationReason, 'text_too_long');
  assert.equal(headline.fieldPath, 'headline');
  assert.equal(headline.actual, 121);
  assert.equal(headline.limit, 120);

  const atPassage = result();
  atPassage.today.text = 'Я'.repeat(SUMMARY_LIMITS.passageChars);
  assert.doesNotThrow(() => validateSummary(atPassage, day));
  const longPassage = result();
  longPassage.today.text = 'Я'.repeat(SUMMARY_LIMITS.passageChars + 1);
  const passage = rejectedSummary(longPassage, day);
  assert.equal(passage.validationReason, 'text_too_long');
  assert.equal(passage.fieldPath, 'today.text');
  assert.equal(passage.actual, 701);
  assert.equal(passage.limit, 700);

  const atLimit = result();
  atLimit.limitations = ['Я'.repeat(SUMMARY_LIMITS.limitationChars)];
  assert.doesNotThrow(() => validateSummary(atLimit, day));
  const longLimit = result();
  longLimit.limitations = ['Я'.repeat(SUMMARY_LIMITS.limitationChars + 1)];
  const limitation = rejectedSummary(longLimit, day);
  assert.equal(limitation.validationReason, 'text_too_long');
  assert.equal(limitation.fieldPath, 'limitations[0]');
  assert.equal(limitation.actual, 201);
  assert.equal(limitation.limit, 200);

  const ids = Array.from({length: 11}, (_, index) => `fact.${index}`);
  const wide = input();
  wide.facts.sleep = ids.map((id) => ({id, text: 'Факт.'}));
  const wideDay = validateDay(wide);
  const atCount = result();
  atCount.today.evidenceIds = ids.slice(0, 10);
  atCount.now.evidenceIds = [];
  atCount.tomorrow.evidenceIds = [];
  assert.doesNotThrow(() => validateSummary(atCount, wideDay));
  const overCount = result();
  overCount.today.evidenceIds = ids;
  overCount.now.evidenceIds = [];
  overCount.tomorrow.evidenceIds = [];
  const counted = rejectedSummary(overCount, wideDay);
  assert.equal(counted.validationReason, 'too_many_items');
  assert.equal(counted.fieldPath, 'today.evidenceIds');
  assert.equal(counted.actual, 11);
  assert.equal(counted.limit, 10);

  const manyLimits = result();
  manyLimits.limitations = Array.from({length: 7}, () => 'Коротко.');
  const limits = rejectedSummary(manyLimits, day);
  assert.equal(limits.validationReason, 'too_many_items');
  assert.equal(limits.fieldPath, 'limitations');
  assert.equal(limits.actual, 7);
  assert.equal(limits.limit, 6);
  const six = result();
  six.limitations = Array.from({length: 6}, () => 'Коротко.');
  assert.doesNotThrow(() => validateSummary(six, day));

  const missing = result();
  delete missing.headline;
  const missingField = rejectedSummary(missing, day);
  assert.equal(missingField.validationReason, 'missing_field');
  assert.equal(missingField.fieldPath, 'headline');
  const blank = result();
  blank.headline = '   ';
  assert.equal(rejectedSummary(blank, day).validationReason, 'missing_field');

  const extra = result();
  extra.note = 'лишнее';
  const unexpected = rejectedSummary(extra, day);
  assert.equal(unexpected.validationReason, 'unexpected_field');
  assert.equal(unexpected.fieldPath, 'note');

  const badId = result();
  badId.today.evidenceIds = ['invented'];
  const unknown = rejectedSummary(badId, day);
  assert.equal(unknown.validationReason, 'unknown_evidence_id');
  assert.equal(unknown.fieldPath, 'today.evidenceIds[0]');

  const english = result();
  english.headline = 'Day wrap';
  english.today = {text: 'You have logged only one meal so far today and your food log completeness is unknown.', evidenceIds: ['sleep.duration']};
  english.now = {text: 'Wind down for sleep tonight.', evidenceIds: ['coach.priority']};
  english.tomorrow = {text: 'Tomorrow is still open.', evidenceIds: []};
  english.limitations = [];
  const language = rejectedSummary(english, validateDay({...input(), locale: 'pl'}));
  assert.equal(language.validationReason, 'language_mismatch');
  assert.equal(language.fieldPath, 'today.text');
});

test('schema sends supported bounds and snapshot evidence ids, not string length keys', () => {
  const day = validateDay(input());
  const ids = Object.values(day.facts).flat().map((fact) => fact.id);
  const schema = summaryResponseSchema(ids, 'gpt-4.1-mini');
  const banned = ['minLength', 'maxLength', 'pattern', 'format', 'allOf', 'oneOf'];
  const seen = [];
  const walk = (value) => {
    if (!value || typeof value !== 'object') return;
    for (const [key, child] of Object.entries(value)) {
      seen.push(key);
      walk(child);
    }
  };
  walk(schema);
  for (const key of banned) assert.equal(seen.includes(key), false, key);
  assert.equal(schema.properties.today.properties.evidenceIds.maxItems, 10);
  assert.equal(schema.properties.limitations.maxItems, 6);
  assert.deepEqual(schema.$defs.evidenceId.enum, evidenceEnumForSchema(ids));
  assert.equal(schema.$defs.evidenceId.enum.length, 3);

  const many = Array.from({length: 93}, (_, index) => `fact.${index}`);
  assert.equal(summaryResponseSchema(many, 'gpt-4.1-mini').$defs.evidenceId.enum.length, 93);

  const wide = Array.from({length: 251}, (_, index) => `${String(index).padStart(3, '0')}${'x'.repeat(77)}`);
  assert.equal(evidenceEnumForSchema(wide), null);
  assert.equal(summaryResponseSchema(wide, 'gpt-4.1-mini').$defs, undefined);
  assert.equal(summaryResponseSchema(wide, 'gpt-4.1-mini').properties.today.properties.evidenceIds.maxItems, 10);

  const tuned = summaryResponseSchema(ids, 'ft:gpt-4.1-mini:coach');
  assert.equal(tuned.properties.today.properties.evidenceIds.maxItems, undefined);
  assert.equal(tuned.$defs, undefined);
  assert.match(buildInstructions(day), /at most 120 characters/);
  assert.match(buildInstructions(day), /at most 700 characters/);
  assert.match(buildInstructions(day), /at most 6 entries/);
  assert.match(buildInstructions(day), /at most 10 ids/);
});

test('instructions call a workout planned only when that event is in the input', () => {
  const text = buildInstructions(input());
  assert.match(text, /only when a matching tomorrow\.item or tomorrow\.meal fact is present/);
  assert.match(text, /tomorrow\.none/);
  assert.match(text, /phrased explicitly as a suggestion/);
  assert.match(text, /must sound like a suggestion/);
});
