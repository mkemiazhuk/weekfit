import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createBillingService } from './billing-service.mjs';
import { BillingStore } from './billing-store.mjs';
import { ServiceError } from './recognition.mjs';
const jpeg=Buffer.from([255,216,255,192,0,17,8,0,100,0,100,3,1,17,0,2,17,0,3,17,0,255,217]).toString('base64');
const input={imageBase64:jpeg,mimeType:'image/jpeg',locale:'en'};
async function fixture(t, overrides={}, options={}) {
 const dir=mkdtempSync(path.join(tmpdir(),'billing-api-'));
 const clock={t:Date.now()};
 const sub={environment:'Sandbox',originalTransactionId:'1',productId:'com.weekfit.subscription.annual',
  active:true,anchor:clock.t-86400000,accessUntil:clock.t+86400000};
 let calls=0,hangups=0,observer,hangupFails=false,connectFails=false;
 const service=createBillingService({billingEnabled:true,dataDirExplicit:true,dataDir:dir,stateBackend:'file',allowSingleNode:true,
  plannerVoiceEnabled:true,plannerVoiceModel:'gpt-realtime-2.1-mini',plannerVoiceIdleSeconds:75,apiKey:'unit-test-only',model:'gpt-6.1-sol'}, {
  authenticate:async header=>{if(!header)throw new ServiceError('unauthorized',401);return header;},
  apple:{environment:'Sandbox',subscription:async jws=>{if(jws!=='test-proof')throw new ServiceError('subscription_required',402);return sub;},
   purchase:async jws=>JSON.parse(jws),notification:async()=>({type:'TEST'})},
  analyze:async()=>{calls++;await new Promise(r=>setTimeout(r,10));if(overrides.failure)throw Error('provider');return {result:{isFood:true,name:'Rice'},usage:{input_tokens:100,output_tokens:30}};},
  fetcher:async url=>{if(url.endsWith('/hangup')){hangups++;return new Response(null,{status:hangupFails?503:200});}
   if(url.endsWith('/calls')&&connectFails)return new Response('no',{status:502});
   return new Response('answer-sdp',{status:201,headers:{location:'/v1/realtime/calls/rtc_test'}});},
  connectObserver:(id,onEvent)=>{observer=onEvent;return {close(){},terminate(){}};},log:entry=>{options.logs?.push(entry);},
  now:options.freezeClock?()=>clock.t:Date.now,
 });
 const server=http.createServer(async(req,res)=>{if(!await service.handle(req,res)){res.writeHead(404);res.end();}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const send=async(route,{body,headers={},method=body?'POST':'GET'}={})=>{
  const response=await fetch(`http://127.0.0.1:${server.address().port}${route}`,{method,
   headers:{Authorization:'Bearer user', 'X-WeekFit-Subscription-JWS':'test-proof','Content-Type':'application/json',...headers},
   body:body?JSON.stringify(body):undefined});
  return {status:response.status,body:await response.json()};
 };
 t.after(async()=>{await service.close();server.closeAllConnections();await new Promise(r=>server.close(r));rmSync(dir,{recursive:true,force:true});});
 return {send,sub,service,calls:()=>calls,hangups:()=>hangups,event:e=>observer(e),failHangup:value=>hangupFails=value,
  advance(ms){clock.t+=ms;},failConnect:value=>{connectFails=value;}};
}
test('API subscription gate, shared-device balance, paid delivery replay and photo concurrency',async t=>{
 const f=await fixture(t);
 assert.equal((await f.send('/v2/ai/usage',{headers:{'X-WeekFit-Subscription-JWS':'invalid'}})).status,402);
 const usage=(await f.send('/v2/ai/usage')).body;
 const purchase={environment:'Sandbox',transactionId:'purchase1',type:'Consumable',productId:'com.weekfit.topup.photos20',appAccountToken:usage.appAccountToken};
 for(let i=0;i<2;i++)assert.equal((await f.send('/v2/ai/purchases',{body:{signedTransaction:JSON.stringify(purchase)}})).status,200);
 const options={body:input,headers:{'Idempotency-Key':'photo_test_1'}};
 const [a,b]=await Promise.all([f.send('/v2/ai/photo',options),f.send('/v2/ai/photo',options)]);
 assert.equal(a.status,200);assert.equal(b.status,200);assert.equal(f.calls(),1);
 const other=(await f.send('/v2/ai/usage',{headers:{Authorization:'Bearer second-device'}})).body;
 assert.equal(other.photos.included,29);assert.equal(other.photos.purchased,20);
 assert.equal((await f.send('/v2/ai/photo',options)).status,200);assert.equal(f.calls(),1);
 f.sub.active=false;
 assert.equal((await f.send('/v2/ai/photo',{...options,headers:{'Idempotency-Key':'photo_test_2'}})).status,402);
 assert.equal((await f.send('/v2/ai/usage')).body.photos.purchased,20);
});
test('provider failure releases allowance and a failed key never runs the provider twice',async t=>{
 const f=await fixture(t,{failure:true});const options={body:input,headers:{'Idempotency-Key':'photo_failed'}};
 assert.equal((await f.send('/v2/ai/photo',options)).status,503);
 assert.equal((await f.send('/v2/ai/usage')).body.photos.included,30);
 assert.equal((await f.send('/v2/ai/photo',options)).status,409);assert.equal(f.calls(),1);
});
test('managed voice never returns provider credentials, rejects parallel calls and hangs up on server deadline',async t=>{
 const f=await fixture(t);
 const body={idempotencyKey:'voice_session1',timeZone:'Europe/Warsaw',language:'en',plan:[]};
 const session=await f.send('/v2/ai/voice/session',{body});assert.equal(session.status,200);assert.equal(session.body.value,'');assert.equal(session.body.budgetSeconds,300);
 assert.equal((await f.send('/v2/ai/voice/session',{body:{...body,idempotencyKey:'voice_session2'}})).status,409);
 const connect=await f.send('/v2/ai/voice/connect',{body:{sessionId:'voice_session1',sdp:'offer-sdp'}});assert.equal(connect.body.sdp,'answer-sdp');
 f.event({type:'response.created'});
 const wallet=f.service.store.wallet(f.sub);
 f.service.store.run('UPDATE operations SET deadline=? WHERE wallet=? AND key=?',Date.now()-1,wallet.id,'voice_session1');
 await new Promise(r=>setTimeout(r,650));
 assert.equal(f.hangups(),1);
 assert.equal((await f.send('/v2/ai/voice/status',{body:{sessionId:'voice_session1'}})).body.active,false);
});

test('failed provider hangup keeps credit reserved and blocks a second call until closure is confirmed',async t=>{
 const f=await fixture(t);
 await f.send('/v2/ai/voice/session',{body:{idempotencyKey:'voice_failure',timeZone:'Europe/Warsaw',language:'en'}});
 await f.send('/v2/ai/voice/connect',{body:{sessionId:'voice_failure',sdp:'offer'}});
 f.event({type:'response.created'});f.failHangup(true);
 assert.equal((await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_failure'}})).status,503);
 assert.equal((await f.send('/v2/ai/usage')).body.voice.included,0);
 assert.equal((await f.send('/v2/ai/voice/session',{body:{idempotencyKey:'voice_blocked',timeZone:'Europe/Warsaw',language:'en'}})).status,409);
 f.failHangup(false);
 assert.equal((await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_failure'}})).status,200);
 assert.equal((await f.send('/v2/ai/voice/status',{body:{sessionId:'voice_failure'}})).body.active,false);
});
test('a forty second call leaves 260 seconds when stop is retried long after the hangup',async t=>{
 const logs=[];
 const f=await fixture(t,{},{freezeClock:true,logs});
 const body={idempotencyKey:'voice_forty',timeZone:'Europe/Warsaw',language:'en'};
 const session=await f.send('/v2/ai/voice/session',{body});
 assert.equal(session.body.budgetSeconds,300);
 await f.send('/v2/ai/voice/connect',{body:{sessionId:'voice_forty',sdp:'offer'}});
 f.event({type:'response.created'});
 f.advance(40_000);
 f.failHangup(true);
 assert.equal((await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_forty'}})).status,503);
 const held=(await f.send('/v2/ai/usage')).body;
 assert.equal(held.voice.included,0);
 assert.equal(held.voice.reserved,300);
 assert.equal(held.voice.used,0);
 assert.equal(held.voiceFinalizing,true);
 f.advance(120_000);
 f.failHangup(false);
 assert.equal((await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_forty'}})).status,200);
 assert.equal((await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_forty'}})).status,200);
 const usage=(await f.send('/v2/ai/usage')).body;
 assert.equal(usage.voice.included,260);
 assert.equal(usage.voice.used,40);
 assert.equal(usage.voice.reserved,0);
 assert.equal(usage.voiceFinalizing,false);
 assert.equal(logs.filter(entry=>entry.event==='billing_voice_settled'&&entry.seconds===40&&entry.operation==='voice_forty').length,1);
});
test('expired subscription can still finish the call it already started',async t=>{
 const f=await fixture(t,{},{freezeClock:true});
 await f.send('/v2/ai/voice/session',{body:{idempotencyKey:'voice_expired',timeZone:'Europe/Warsaw',language:'en'}});
 await f.send('/v2/ai/voice/connect',{body:{sessionId:'voice_expired',sdp:'offer'}});
 f.event({type:'response.created'});
 f.advance(40_000);
 f.sub.active=false;f.sub.accessUntil=0;
 const stopped=await f.send('/v2/ai/voice/stop',{body:{sessionId:'voice_expired'}});
 assert.equal(stopped.status,200);
 assert.equal(stopped.body.voice.included,260);
 assert.equal(stopped.body.voice.used,40);
});
test('a failed connection returns the reserve and a silent client is not billed for the whole budget',async t=>{
 const failed=await fixture(t);
 failed.failConnect(true);
 await failed.send('/v2/ai/voice/session',{body:{idempotencyKey:'voice_noconnect',timeZone:'Europe/Warsaw',language:'en'}});
 assert.equal((await failed.send('/v2/ai/voice/connect',{body:{sessionId:'voice_noconnect',sdp:'offer'}})).status,502);
 const restored=(await failed.send('/v2/ai/usage')).body;
 assert.equal(restored.voice.included,300);
 assert.equal(restored.voice.reserved,0);
 assert.equal(restored.voice.used,0);
 const quiet=await fixture(t,{},{freezeClock:true});
 await quiet.send('/v2/ai/voice/session',{body:{idempotencyKey:'voice_quiet',timeZone:'Europe/Warsaw',language:'en'}});
 await quiet.send('/v2/ai/voice/connect',{body:{sessionId:'voice_quiet',sdp:'offer'}});
 quiet.event({type:'response.created'});
 quiet.advance(15_000);
 await quiet.send('/v2/ai/voice/status',{body:{sessionId:'voice_quiet'}});
 quiet.advance(50_000);
 await new Promise(r=>setTimeout(r,700));
 assert.equal(quiet.hangups(),1);
 const usage=(await quiet.send('/v2/ai/usage')).body;
 assert.equal(usage.voice.used,15);
 assert.equal(usage.voice.included,285);
 assert.equal(usage.voice.reserved,0);
});
test('restart settles a provider call that is already gone without billing the reserved budget',async t=>{
 const dir=mkdtempSync(path.join(tmpdir(),'billing-restart-'));
 const clock={t:Date.now()};
 const sub={environment:'Sandbox',originalTransactionId:'1',productId:'com.weekfit.subscription.annual',
  active:true,anchor:clock.t-86400000,accessUntil:clock.t+86400000};
 const prepared=new BillingStore(path.join(dir,'billing-Sandbox.sqlite'),{now:()=>clock.t});
 const wallet=prepared.wallet(sub);
 prepared.reserve(wallet,sub,'voice','voice_restart','fingerprint',300);
 prepared.attachCall(wallet.id,'voice_restart','rtc_old');
 prepared.startCall(wallet.id,'voice_restart');
 prepared.run('UPDATE operations SET started=? WHERE wallet=? AND key=?',clock.t-40_000,wallet.id,'voice_restart');
 prepared.close();
 const logs=[];
 const service=createBillingService({billingEnabled:true,dataDirExplicit:true,dataDir:dir,stateBackend:'file',allowSingleNode:true,
  plannerVoiceEnabled:true,apiKey:'unit-test-only',model:'gpt-6.1-sol'},{
  authenticate:async()=>'user',now:()=>clock.t,
  apple:{environment:'Sandbox',subscription:async()=>sub,purchase:async()=>{throw new ServiceError('unused',400);},notification:async()=>({})},
  fetcher:async url=>new Response(null,{status:url.endsWith('/hangup')?404:201,headers:{location:'/v1/realtime/calls/rtc_test'}}),
  connectObserver:()=>({close(){},terminate(){}}),log:entry=>logs.push(entry),
 });
 const server=http.createServer(async(req,res)=>{if(!await service.handle(req,res)){res.writeHead(404);res.end();}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 t.after(async()=>{await service.close();server.closeAllConnections();await new Promise(r=>server.close(r));rmSync(dir,{recursive:true,force:true});});
 const response=await fetch(`http://127.0.0.1:${server.address().port}/v2/ai/usage`,{headers:{Authorization:'Bearer user','X-WeekFit-Subscription-JWS':'proof'}});
 const usage=await response.json();
 assert.equal(usage.voice.included,300);
 assert.equal(usage.voice.used,0);
 assert.equal(usage.voice.reserved,0);
 assert.equal(logs.some(entry=>entry.event==='billing_voice_settled'&&entry.seconds===0&&entry.end==='unknown'),true);
 assert.equal(service.store.db.prepare("SELECT name FROM sqlite_master WHERE name LIKE 'prod_%'").all().length,0);
});
test('unsubscribed callers cannot occupy the voice admission line',async t=>{
 const f=await fixture(t);f.sub.active=false;
 assert.equal((await f.send('/v1/planner-voice/line',{body:{}})).status,402);
});
