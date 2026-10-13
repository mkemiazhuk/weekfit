import test from 'node:test';
import assert from 'node:assert/strict';
import { X509Certificate, createPrivateKey, generateKeyPairSync, sign } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { requirePaidSubscriptionJWS, verifyStoreKitSignature } from './subscription-proof.mjs';

function fixtures() {
  const dir = mkdtempSync(path.join(tmpdir(), 'weekfit-jws-test-'));
  const file = n => path.join(dir, n);
  const openssl = args => execFileSync('openssl', args, { stdio: 'ignore' });
  try {
    openssl(['req','-x509','-newkey','ec','-pkeyopt','ec_paramgen_curve:P-256','-nodes','-subj','/CN=Test Root','-days','1','-keyout',file('root.key'),'-out',file('root.pem'),'-addext','basicConstraints=critical,CA:TRUE']);
    for (const [name, issuer, purpose, ca] of [
      ['intermediate','root','1.2.840.113635.100.6.2.1',true],
      ['leaf','intermediate','1.2.840.113635.100.6.11.1',false],
      ['unrelated','intermediate',null,false],
    ]) {
      openssl(['req','-new','-newkey','ec','-pkeyopt','ec_paramgen_curve:P-256','-nodes','-subj',`/CN=Test ${name}`,'-keyout',file(`${name}.key`),'-out',file(`${name}.csr`)]);
      writeFileSync(file(`${name}.ext`), `basicConstraints=critical,CA:${ca ? 'TRUE' : 'FALSE'}\nkeyUsage=critical,${ca ? 'keyCertSign,cRLSign' : 'digitalSignature'}\n${purpose ? purpose+'=DER:05:00\n' : ''}`);
      openssl(['x509','-req','-in',file(`${name}.csr`),'-CA',file(`${issuer}.pem`),'-CAkey',file(`${issuer}.key`),'-CAcreateserial','-days','1','-extfile',file(`${name}.ext`),'-out',file(`${name}.pem`)]);
    }
    return Object.fromEntries(['root','intermediate','leaf','unrelated'].map(name => [name, {
      cert: new X509Certificate(readFileSync(file(`${name}.pem`))),
      key: createPrivateKey(readFileSync(file(`${name}.key`))),
    }]));
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
const f = fixtures();
function jws({ leaf = 'leaf', overrides = {}, encoding = 'ieee-p1363' } = {}) {
  const head = Buffer.from(JSON.stringify({ alg: 'ES256', x5c: [f[leaf].cert,f.intermediate.cert,f.root.cert].map(c => c.raw.toString('base64')) })).toString('base64url');
  const body = Buffer.from(JSON.stringify({ bundleId: 'com.weekfit.app', productId: 'com.weekfit.subscription.monthly', type: 'Auto-Renewable Subscription', environment: 'Sandbox', signedDate: Date.now(), expiresDate: Date.now()+3600000, ...overrides })).toString('base64url');
  const signature = sign('sha256', Buffer.from(`${head}.${body}`), { key: f[leaf].key, dsaEncoding: encoding });
  return `${head}.${body}.${signature.toString('base64url')}`;
}
const opts = { rootCertificate: f.root.cert };
const denied = fn => assert.throws(fn, e => e.code === 'subscription_required' && e.status === 402);

test('real ECDSA P1363 subscription signature verifies without skipSignature', () => {
  assert.equal(requirePaidSubscriptionJWS(jws(), opts).productId, 'com.weekfit.subscription.monthly');
});
test('DER signatures and modified signed payload are denied, not internal errors', () => {
  denied(() => requirePaidSubscriptionJWS(jws({ encoding: 'der' }), opts));
  const parts = jws().split('.');
  const body = JSON.parse(Buffer.from(parts[1],'base64url'));
  body.expiresDate += 10000; parts[1] = Buffer.from(JSON.stringify(body)).toString('base64url');
  denied(() => requirePaidSubscriptionJWS(parts.join('.'), opts));
});
test('untrusted root, unrelated Apple-purpose certificate, expired and trial transactions denied', () => {
  denied(() => requirePaidSubscriptionJWS(jws()));
  denied(() => requirePaidSubscriptionJWS(jws({ leaf: 'unrelated' }), opts));
  denied(() => requirePaidSubscriptionJWS(jws({ overrides: { expiresDate: Date.now()-1 } }), opts));
  denied(() => requirePaidSubscriptionJWS(jws({ overrides: { offerType: 1 } }), opts));
});
test('public KeyObject works directly; malformed signature never throws', () => {
  const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const parts = ['e30','e30',sign('sha256', Buffer.from('e30.e30'), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')];
  assert.equal(verifyStoreKitSignature(parts, publicKey), true);
  assert.equal(verifyStoreKitSignature(['e30','e30','bad'], publicKey), false);
});
