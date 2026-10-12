import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { configuration, createServer } from './server.mjs';
import { validateInput, validateResult, recognize, ServiceError } from './recognition.mjs';
import { authenticate } from './auth.mjs';
const valid = () => ({isFood:true,name:'Rice',items:[{name:'Rice',preparation:'cooked',grams:100,minGrams:80,maxGrams:150,calories:130,protein:3,carbs:28,fat:0.3,assumptions:[]}],uncertainties:['Weight is estimated'],clarificationQuestion:null});
// Header-only fixture tests image-envelope checks, not visual recognition.
const jpeg = Buffer.from([255,216,255,192,0,17,8,0,100,0,100,3,1,17,0,2,17,0,3,17,0,255,217]).toString('base64');
const input = () => ({imageBase64:jpeg,mimeType:'image/jpeg',locale:'en_US'});
test('default uses Astra and dev authentication is opt-in',()=>{const c=configuration({});assert.equal(c.model,'gpt-6-astra');assert.equal(c.allowDevAuth,false);});
test('production refuses developer token',()=>assert.throws(()=>configuration({NODE_ENV:'production',ALLOW_DEV_AUTH:'1',WEEKFIT_DEV_TOKEN:'weekfit-dev-local-token'})));
test('validates JPEG and rejects disguised or tiny images',()=>{assert.equal(validateInput(input()).locale,'en_US');assert.throws(()=>validateInput({...input(),imageBase64:Buffer.from('not an image').toString('base64')}));const tiny=Buffer.from(jpeg,'base64');tiny[8]=1;assert.throws(()=>validateInput({...input(),imageBase64:tiny.toString('base64')}));});
test('rejects invalid locale and oversized context',()=>{assert.throws(()=>validateInput({...input(),locale:'ignore instructions!'}));assert.throws(()=>validateInput({...input(),note:'a'.repeat(1001)}));});
test('totals are recomputed and marked as estimates',()=>{const r=validateResult(valid());assert.equal(r.totals.calories,130);assert.equal(r.nutritionSource,'ai_estimate');assert.equal(r.requiresConfirmation,true);});
test('rejects negative, impossible or inconsistent portions',()=>{for(const change of [{grams:-1},{minGrams:120},{maxGrams:90},{protein:300},{calories:Infinity}]){const v=valid();Object.assign(v.items[0],change);assert.throws(()=>validateResult(v));}});
test('non-food is a recoverable 422',()=>assert.throws(()=>validateResult({...valid(),isFood:false,items:[]}),e=>e.status===422));
test('provider receives high detail, schema, no storage and server-selected model',async()=>{
  let sent;const c={...configuration({}),apiKey:'test-key'};
  const r=await recognize(validateInput(input()),c,async(url,options)=>{assert.equal(url,'https://api.openai.com/v1/responses');sent=JSON.parse(options.body);return new Response(JSON.stringify({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(valid())}]}],usage:{input_tokens:100,output_tokens:200}}));});
  assert.equal(sent.model,'gpt-6-astra');assert.equal(sent.store,false);assert.equal(sent.text.format.strict,true);assert.equal(sent.input[0].content[1].detail,'high');assert.equal(r.result.name,'Rice');
});
test('provider failures, refusals and truncated output never become meals',async()=>{
  const c={...configuration({}),apiKey:'test-key'};
  for(const body of [{status:'incomplete',output:[]},{status:'completed',output:[{content:[{type:'refusal'}]}]},{status:'completed',output:[{content:[{type:'output_text',text:'broken'}]}]}]) await assert.rejects(()=>recognize(validateInput(input()),c,async()=>new Response(JSON.stringify(body))));
  await assert.rejects(()=>recognize(validateInput(input()),c,async()=>new Response('',{status:429})),e=>e.status===503);
});
test('missing/forged auth rejected; explicit local dev token accepted',async()=>{const c=configuration({ALLOW_DEV_AUTH:'1',WEEKFIT_DEV_TOKEN:'weekfit-dev-local-token'});await assert.rejects(()=>authenticate(undefined,c));await assert.rejects(()=>authenticate('Bearer wrong',c));assert.equal(await authenticate('Bearer weekfit-dev-local-token',c),'local-developer');await assert.rejects(()=>authenticate('Bearer a.b.c',{...c,firebaseProject:'test'}));});
test('Firebase verifies signature, audience and expiry using trusted certificates',async t=>{
  const {publicKey,privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
  t.mock.method(globalThis,'fetch',async url=>{assert.equal(url,'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');return new Response(JSON.stringify({test:publicKey.export({type:'spki',format:'pem'})}),{headers:{'cache-control':'max-age=300'}});});
  const now=Math.floor(Date.now()/1000), config=configuration({FIREBASE_PROJECT_ID:'project'});
  const token=changes=>{const head=Buffer.from(JSON.stringify({alg:'RS256',kid:'test'})).toString('base64url');const body=Buffer.from(JSON.stringify({aud:'project',iss:'https://securetoken.google.com/project',sub:'user',iat:now,auth_time:now,exp:now+3600,...changes})).toString('base64url');const data=`${head}.${body}`;return `${data}.${sign('RSA-SHA256',Buffer.from(data),privateKey).toString('base64url')}`;};
  assert.equal(await authenticate('Bearer '+token({}),config),'user');
  await assert.rejects(()=>authenticate('Bearer '+token({aud:'different'}),config));
  await assert.rejects(()=>authenticate('Bearer '+token({exp:now-1}),config));
  const forged=token({}).split('.');forged[1]=Buffer.from(JSON.stringify({aud:'project',iss:'https://securetoken.google.com/project',sub:'attacker',iat:now,auth_time:now,exp:now+3600})).toString('base64url');
  await assert.rejects(()=>authenticate('Bearer '+forged.join('.'),config));
});
test('HTTP auth, client-model isolation and quota enforcement',async t=>{
  const config={...configuration({ALLOW_DEV_AUTH:'1',WEEKFIT_DEV_TOKEN:'weekfit-dev-local-token',OPENAI_API_KEY:'test'}),dailyLimit:1};let calls=0;
  const server=createServer(config,{recognize:async(i,c)=>{calls++;assert.equal(c.model,'gpt-6-astra');return{result:validateResult(valid()),usage:null};}});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base=`http://127.0.0.1:${server.address().port}`;
  const request=auth=>fetch(base+'/v1/food/photo-recognize',{method:'POST',headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer weekfit-dev-local-token'}:{})},body:JSON.stringify({...input(),model:'arbitrary-expensive-model'})});
  assert.equal((await request(false)).status,401);assert.equal((await request(true)).status,200);assert.equal((await request(true)).status,429);assert.equal(calls,1);
  assert.equal((await fetch(base+'/readyz')).status,200);
});
