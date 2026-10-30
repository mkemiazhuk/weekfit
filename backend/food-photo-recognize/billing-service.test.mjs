import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createBillingService } from './billing-service.mjs';
import { ServiceError } from './recognition.mjs';
const jpeg=Buffer.from([255,216,255,192,0,17,8,0,100,0,100,3,1,17,0,2,17,0,3,17,0,255,217]).toString('base64');
const input={imageBase64:jpeg,mimeType:'image/jpeg',locale:'en'};
async function fixture(t, overrides={}) {
 const dir=mkdtempSync(path.join(tmpdir(),'billing-api-'));
 const sub={environment:'Sandbox',originalTransactionId:'1',productId:'com.weekfit.subscription.annual',
  active:true,anchor:Date.now()-86400000,accessUntil:Date.now()+86400000};
 let calls=0,hangups=0,observer;
 const service=createBillingService({billingEnabled:true,dataDirExplicit:true,dataDir:dir,stateBackend:'file',allowSingleNode:true,
  plannerVoiceEnabled:true,plannerVoiceModel:'gpt-realtime-2.1-mini',plannerVoiceIdleSeconds:75,apiKey:'unit-test-only',model:'gpt-6.1-sol'}, {
  authenticate:async header=>{if(!header)throw new ServiceError('unauthorized',401);return header;},
  apple:{environment:'Sandbox',subscription:async jws=>{if(jws!=='test-proof')throw new ServiceError('subscription_required',402);return sub;},
   purchase:async jws=>JSON.parse(jws),notification:async()=>({type:'TEST'})},
  analyze:async()=>{calls++;await new Promise(r=>setTimeout(r,10));if(overrides.failure)throw Error('provider');return {result:{isFood:true,name:'Rice'},usage:{input_tokens:100,output_tokens:30}};},
  fetcher:async url=>{if(url.endsWith('/hangup')){hangups++;return new Response(null,{status:200});}
   return new Response('answer-sdp',{status:201,headers:{location:'/v1/realtime/calls/rtc_test'}});},
  connectObserver:(id,onEvent)=>{observer=onEvent;return {close(){},terminate(){}};},log:()=>{},
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
 return {send,sub,service,calls:()=>calls,hangups:()=>hangups,event:e=>observer(e)};
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
