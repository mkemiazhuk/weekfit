import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createServer} from './server.mjs';
import {ServiceError} from './recognition.mjs';
import {validateDay,validateSummary,generateSummary,localDayAndHour,SUMMARY_PROMPT_VERSION} from './coach-summary.mjs';

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
test('invalid dates, locales, timezones rejected',()=>{for(const change of [{day:'2026-02-31'},{timezone:'bad/zone'},{locale:'xx'}])assert.throws(()=>validateDay({...input(),...change}));});
test('duplicate IDs and excessive text rejected',()=>{const b=input();b.facts.feeling=[b.facts.sleep[0]];assert.throws(()=>validateDay(b));b.facts.feeling=[{id:'feeling',text:'a'.repeat(501)}];assert.throws(()=>validateDay(b));});
test('empty snapshot rejected',()=>assert.throws(()=>validateDay({...input(),facts:{}}),/insufficient_day_data/));
test('invented evidence rejected',()=>{const r=result();r.today.evidenceIds=['invented'];assert.throws(()=>validateSummary(r,validateDay(input())),/invalid_summary_result/);});
test('Warsaw DST determines 20:00 locally',()=>{assert.deepEqual(localDayAndHour(new Date('2026-10-12T18:00:00Z'),'Europe/Warsaw'),{day:'2026-10-12',hour:20});assert.equal(localDayAndHour(new Date('2026-11-12T19:00:00Z'),'Europe/Warsaw').hour,20);});
test('duplicate calls return persisted answer',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});assert.equal((await post(input())).status,200);const r=await(await post(input())).json();assert.equal(r.reused,true);assert.equal(calls,1);});
test('changed meals, plans or language cannot buy another call',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});await post(input());const b=input();b.locale='en';b.facts.tomorrow=[{id:'tomorrow.run',text:'New run'}];assert.equal((await post(b)).status,200);assert.equal(calls,1);});
test('parallel identical requests invoke provider at most once',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;await new Promise(r=>setTimeout(r,40));return {result:result()};});const rs=await Promise.all([post(input()),post(input()),post(input())]);assert.equal(calls,1);assert.ok(rs.every(r=>[200,409].includes(r.status)));});
test('restart uses stored answer without invoking AI',async t=>{const dir=await directory(t);const a=await server(t,dir,async()=>({result:result()}));await a.post(input());await new Promise(r=>a.s.close(r));let calls=0;const b=await server(t,dir,async()=>{calls++;return {result:result()};});assert.equal((await b.post(input())).status,200);assert.equal(calls,0);});
test('provider failure is terminal even after restart',async t=>{const dir=await directory(t);let calls=0;const a=await server(t,dir,async()=>{calls++;throw new Error('down');});assert.equal((await a.post(input())).status,500);const b=await server(t,dir,async()=>{calls++;return {result:result()};});assert.equal((await b.post(input())).status,409);assert.equal(calls,1);});
test('timeout cannot automatically or manually regenerate',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;throw Object.assign(new Error(),{name:'TimeoutError'});});assert.equal((await post(input())).status,504);assert.equal((await post(input())).status,409);assert.equal(calls,1);});
test('storage scoped to authenticated UID',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});await post(input(),'Bearer a');await post(input(),'Bearer b');assert.equal(calls,2);});
test('no auth means no provider call',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};});assert.equal((await post(input(),null)).status,401);assert.equal(calls,0);});
test('cannot generate before 20:00 or backdate requests',async t=>{let calls=0;const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};},{dependencies:{summaryNow:()=>new Date('2026-10-12T17:59:59Z')}});assert.equal((await post(input())).status,422);assert.equal((await post({...input(),day:'2026-10-11'})).status,422);assert.equal(calls,0);});
test('next local day permits one new request',async t=>{let calls=0;const dir=await directory(t);const generate=async()=>{calls++;return {result:result()};};const a=await server(t,dir,generate);await a.post(input());const b=await server(t,dir,generate,{dependencies:{summaryNow:()=>new Date('2026-10-13T18:00:00Z')}});assert.equal((await b.post({...input(),day:'2026-10-13'})).status,200);assert.equal(calls,2);});
test('storage misconfiguration fails closed without AI',async t=>{let calls=0;const {post}=await server(t,'',async()=>{calls++;return {result:result()};});assert.equal((await post(input())).status,503);assert.equal(calls,0);});
test('concurrency limit is acquired before asynchronous reservation',async t=>{let running=0,peak=0;const {post}=await server(t,await directory(t),async()=>{running++;peak=Math.max(peak,running);await new Promise(r=>setTimeout(r,40));running--;return {result:result()};},{config:{summaryConcurrency:1}});const rs=await Promise.all([post(input(),'Bearer a'),post(input(),'Bearer b'),post(input(),'Bearer c')]);assert.equal(peak,1);assert.equal(rs.filter(r=>r.status===200).length,1);assert.equal(rs.filter(r=>r.status===503).length,2);});
test('structured output has bounded tokens, no photo and no storage',async()=>{let sent;const r=await generateSummary(validateDay(input()),{apiKey:'test',summaryModel:'test-model'},async(url,opts)=>{sent=JSON.parse(opts.body);return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(result())}]}]})};});assert.equal(sent.store,false);assert.equal(sent.max_output_tokens,1200);assert.equal(sent.text.format.strict,true);assert.equal(sent.reasoning,undefined);assert.equal(r.result.headline,'Итог дня');assert.match(sent.instructions,/40.65 words/);assert.equal(SUMMARY_PROMPT_VERSION,8);assert.match(sent.instructions,/personal activity, sleep and recovery coach/);assert.match(sent.instructions,/SEVEN days/);assert.match(sent.instructions,/Do NOT recite/);});
test('unrestricted mode allows before 20:00 and always calls AI',async t=>{
  let calls=0;
  const {post}=await server(t,await directory(t),async()=>{calls++;return {result:result()};},{
    config:{summaryOncePerDay:false},
    dependencies:{summaryNow:()=>new Date('2026-10-12T10:00:00Z')}
  });
  assert.equal((await post(input())).status,200);
  assert.equal((await post(input())).status,200);
  assert.equal(calls,2);
});
test('unrestricted mode ignores prior daily claim files',async t=>{
  const dir=await directory(t);
  let calls=0;
  const once=await server(t,dir,async()=>{calls++;return {result:result()};},{config:{summaryOncePerDay:true}});
  assert.equal((await once.post(input())).status,200);
  await new Promise(r=>once.s.close(r));
  const open=await server(t,dir,async()=>{calls++;return {result:result()};},{
    config:{summaryOncePerDay:false},
    dependencies:{summaryNow:()=>new Date('2026-10-12T10:00:00Z')}
  });
  assert.equal((await open.post(input())).status,200);
  assert.equal(calls,2);
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
  const b=input(); b.facts.recentSleep=Array.from({length:21},(_,i)=>({id:`h.${i}`,text:'Sleep history'}));
  assert.throws(()=>validateDay(b),/invalid_day_snapshot/);
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
