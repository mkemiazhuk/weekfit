import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createServer} from './server.mjs';
import {ServiceError} from './recognition.mjs';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {validateDay,validateSummary,generateSummary,localDayAndHour,normalizeLocale,hasEnglishLanguageLeak,emptyFactsFallbackSummary,countFacts,buildInstructions,unconfirmedConclusionIssues,SUMMARY_PROMPT_VERSION} from './coach-summary.mjs';

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
test('structured output has bounded tokens, no photo and no storage',async()=>{let sent;const r=await generateSummary(validateDay(input()),{apiKey:'test',summaryModel:'test-model'},async(url,opts)=>{sent=JSON.parse(opts.body);return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(result())}]}]})};});assert.equal(sent.store,false);assert.equal(sent.max_output_tokens,8192);assert.equal(sent.text.format.strict,true);assert.equal(sent.reasoning,undefined);assert.equal(r.result.headline,'Итог дня');assert.match(sent.instructions,/40.65 words/);assert.equal(SUMMARY_PROMPT_VERSION,13);assert.match(sent.instructions,/personal activity, sleep and recovery coach/);assert.match(sent.instructions,/LANGUAGE LOCK/);assert.match(sent.instructions,/Russian/);assert.match(sent.instructions,/SEVEN days/);assert.match(sent.instructions,/Hard bans/);assert.match(sent.instructions,/At most ONE next-step/);assert.match(sent.instructions,/ready for load/);assert.match(sent.instructions,/single HRV/);assert.match(sent.instructions,/active calories/);assert.match(sent.instructions,/SAME cautious conclusion/);assert.match(sent.instructions,/several days/);assert.match(sent.instructions,/principal personal fitness assistant/);assert.match(sent.instructions,/30 years of experience/);assert.match(sent.instructions,/silently verify/);assert.match(sent.instructions,/Never claim professional credentials/);});
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
  assert.equal(body.promptVersion,13);
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
  assert.equal(SUMMARY_PROMPT_VERSION,13);
  assert.match(instructions,/principal personal fitness assistant/);
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

test('weekly context reaches provider unchanged and outputs must cite supplied facts',async()=>{
  const b=input(); b.facts.recentVitals=[{id:'history.vitals.2026-10-12',text:'HRV unknown; RHR unknown; sparse readings.'}];
  let sent;
  await generateSummary(validateDay(b),{apiKey:'test',summaryModel:'mock'},async(_,opts)=>{
    sent=JSON.parse(opts.body);
    return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(result())}]}]})};
  });
  assert.deepEqual(JSON.parse(sent.input[0].content[0].text).facts.recentVitals,b.facts.recentVitals);
});
