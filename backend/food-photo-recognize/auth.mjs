import { createPublicKey, verify, timingSafeEqual } from 'node:crypto';
import { ServiceError } from './recognition.mjs';
let certificates = {}, validUntil = 0;
export function equalSecret(a, b) {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}
export async function authenticate(header, config) {
  if (!header?.startsWith('Bearer ')) throw new ServiceError('unauthorized', 401);
  const token = header.slice(7);
  if (config.allowDevAuth && equalSecret(token, config.devToken)) return 'local-developer';
  if (!config.firebaseProject) throw new ServiceError('unauthorized', 401);
  try {
    const parts = token.split('.');
    if (parts.length !== 3 || token.length > 10000) throw Error();
    const head = JSON.parse(Buffer.from(parts[0], 'base64url'));
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url'));
    const now = Math.floor(Date.now()/1000);
    if (head.alg !== 'RS256' || typeof head.kid !== 'string' || claims.aud !== config.firebaseProject || claims.iss !== `https://securetoken.google.com/${config.firebaseProject}` || !Number.isFinite(claims.exp) || claims.exp <= now || !Number.isFinite(claims.iat) || claims.iat > now + 30 || !Number.isFinite(claims.auth_time) || claims.auth_time > now + 30 || typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128) throw Error();
    if (Date.now() >= validUntil) {
      const response = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com', { signal: AbortSignal.timeout(5000) });
      if (!response.ok) throw Error();
      certificates = await response.json();
      const seconds = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] ?? 300);
      validUntil = Date.now() + Math.min(seconds, 3600) * 1000;
    }
    if (!Object.hasOwn(certificates, head.kid) || !verify('RSA-SHA256', Buffer.from(`${parts[0]}.${parts[1]}`), createPublicKey(certificates[head.kid]), Buffer.from(parts[2], 'base64url'))) throw Error();
    return claims.sub;
  } catch { throw new ServiceError('unauthorized', 401); }
}
