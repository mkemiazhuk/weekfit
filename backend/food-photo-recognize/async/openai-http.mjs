/**
 * Keep-alive HTTPS client for OpenAI Responses API (no npm deps).
 * Reuses TLS sockets across analyses in this process.
 */
import https from 'node:https';
import { URL } from 'node:url';

const agent = new https.Agent({
  keepAlive: true,
  maxSockets: 64,
  maxFreeSockets: 16,
  timeout: 120_000,
});

/** @type {typeof fetch} */
export function openaiFetch(url, init = {}) {
  const u = new URL(typeof url === 'string' ? url : String(url));
  const method = init.method || 'GET';
  const headers = { ...(init.headers || {}) };
  const body = init.body == null ? null : Buffer.from(init.body);

  return new Promise((resolve, reject) => {
    const req = https.request({
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || 443,
      path: `${u.pathname}${u.search}`,
      method,
      headers,
      agent,
      signal: init.signal,
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        resolve(new Response(buf, {
          status: res.statusCode || 0,
          headers: res.headers,
        }));
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}
