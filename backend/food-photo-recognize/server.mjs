import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { authenticate } from './auth.mjs';
import { recognize, validateInput, ServiceError } from './recognition.mjs';

export function configuration(env = process.env) {
  const integer = (key, fallback, min, max) => {
    const n = Number(env[key] ?? fallback);
    if (!Number.isInteger(n) || n < min || n > max) throw Error(`Invalid ${key}`);
    return n;
  };
  const allowDevAuth = env.ALLOW_DEV_AUTH === '1';
  if (allowDevAuth && (env.NODE_ENV === 'production' || !env.WEEKFIT_DEV_TOKEN || env.WEEKFIT_DEV_TOKEN.length < 16)) throw Error('Development auth requires a non-production environment and a token of at least 16 characters');
  const effort = env.FOOD_PHOTO_REASONING_EFFORT ?? 'low';
  if (!['low','medium','high','xhigh','max'].includes(effort)) throw Error('Invalid reasoning effort');
  const model = env.FOOD_PHOTO_MODEL ?? 'gpt-6-luna';
  if (!['gpt-6-astra','gpt-6.1-sol','gpt-6-luna'].includes(model)) throw Error('Unsupported model; explicitly update the server allowlist after evaluation');
  return { apiKey: env.OPENAI_API_KEY ?? '', model, effort, allowDevAuth, devToken: env.WEEKFIT_DEV_TOKEN ?? '', firebaseProject: env.FIREBASE_PROJECT_ID ?? '', port: integer('PORT',8080,1,65535), timeoutMs: integer('OPENAI_TIMEOUT_MS',90000,1000,180000), maxOutputTokens: integer('OPENAI_MAX_OUTPUT_TOKENS',4000,2000,32000), dailyLimit: integer('DAILY_SCAN_LIMIT',20,1,1000), maxConcurrency: integer('MAX_CONCURRENT_SCANS',4,1,100), globalDailyLimit: integer('GLOBAL_DAILY_SCAN_LIMIT',200,1,100000) };
}
export function createServer(config, dependencies = {}) {
  const auth = dependencies.authenticate ?? authenticate, analyze = dependencies.recognize ?? recognize;
  const limits = new Map(); let active = 0, day = '', dailyCount = 0;
  const send = (res, status, body) => {
    res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(JSON.stringify(body));
  };
  const configured = () => Boolean(config.apiKey && (config.firebaseProject || config.allowDevAuth));
  const server = http.createServer(async (req, res) => {
    const requestId = randomUUID(), started = Date.now(); let acquired = false;
    if (req.method === 'GET' && req.url === '/healthz') return send(res,200,{ok:true,configured:configured(),model:config.model,allowDevAuth:config.allowDevAuth});
    if (req.method === 'GET' && req.url === '/readyz') return send(res,configured()?200:503,{ready:configured()});
    if (req.method !== 'POST' || req.url !== '/v1/food/photo-recognize') return send(res,404,{error:'not_found',requestId});
    try {
      if (!configured()) throw new ServiceError('service_not_configured',503);
      const user = await auth(req.headers.authorization,config);
      if (!req.headers['content-type']?.startsWith('application/json')) throw new ServiceError('json_required',415);
      const today = new Date().toISOString().slice(0,10);
      if (day !== today) { limits.clear(); dailyCount = 0; day = today; }
      if ((limits.get(user)??0)>=config.dailyLimit || dailyCount>=config.globalDailyLimit) throw new ServiceError('daily_scan_limit',429);
      if (active >= config.maxConcurrency) throw new ServiceError('server_busy',503);
      active++; acquired = true;
      const chunks=[]; let size=0;
      for await (const chunk of req) {
        size+=chunk.length;
        if (size>12*1024*1024) throw new ServiceError('request_too_large',413);
        chunks.push(chunk);
      }
      let body; try { body=JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new ServiceError('invalid_json'); }
      const input = validateInput(body);
      // Recheck after reading: concurrent uploads must not bypass daily limits.
      if ((limits.get(user)??0)>=config.dailyLimit || dailyCount>=config.globalDailyLimit) throw new ServiceError('daily_scan_limit',429);
      limits.set(user,(limits.get(user)??0)+1); dailyCount++;
      const {result,usage} = await analyze(input,config);
      console.log(JSON.stringify({requestId,model:config.model,latencyMs:Date.now()-started,outcome:'success',inputTokens:usage?.input_tokens,outputTokens:usage?.output_tokens,reasoningTokens:usage?.output_tokens_details?.reasoning_tokens,cachedInputTokens:usage?.input_tokens_details?.cached_tokens}));
      send(res,200,{...result,model:config.model,requestId});
    } catch(error) {
      const timeout = ['TimeoutError','AbortError'].includes(error.name);
      const code = timeout?'recognition_timeout':error instanceof ServiceError?error.code:'internal_error';
      console.log(JSON.stringify({requestId,model:config.model,latencyMs:Date.now()-started,outcome:code,inputTokens:error.usage?.input_tokens,outputTokens:error.usage?.output_tokens,reasoningTokens:error.usage?.output_tokens_details?.reasoning_tokens}));
      if (!res.destroyed) send(res,timeout?504:error instanceof ServiceError?error.status:500,{error:code,requestId});
    } finally { if(acquired) active--; }
  });
  server.requestTimeout = 30000; server.headersTimeout = 15000;
  return server;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = configuration();
  const server=createServer(config);
  server.listen(config.port,'0.0.0.0',()=>console.log(JSON.stringify({outcome:'listening',port:config.port,model:config.model,configured:Boolean(config.apiKey)})));
  for (const signal of ['SIGTERM','SIGINT']) process.on(signal,()=>{server.close(()=>process.exit(0)); setTimeout(()=>process.exit(1),10000).unref();});
}
