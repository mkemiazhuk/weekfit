import { X509Certificate, verify } from 'node:crypto';
import { ServiceError } from './recognition.mjs';

/** WeekFit auto-renewable product ids (must match iOS `WeekFitSubscriptionProductID`). */
export const WEEKFIT_SUBSCRIPTION_PRODUCT_IDS = new Set([
  'com.weekfit.subscription.monthly',
  'com.weekfit.subscription.annual',
]);

export const WEEKFIT_BUNDLE_IDS = new Set([
  'com.weekfit.app',
]);

/**
 * Apple Root CA - G3 (ECC), used to anchor StoreKit Transaction JWS `x5c` chains.
 * https://www.apple.com/certificateauthority/
 */
const APPLE_ROOT_CA_G3_PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----`;

const appleRoot = new X509Certificate(APPLE_ROOT_CA_G3_PEM);

function decodePart(part) {
  return JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
}

function certFromX5C(entry) {
  return new X509Certificate(Buffer.from(entry, 'base64'));
}

// Read extension OIDs from the certificate's DER extension container, not
// arbitrary bytes in its subject/public key. No new runtime dependencies.
function extensionOids(cert) {
  const der = cert.raw;
  const read = (at, end = der.length) => {
    if (at + 2 > end) throw Error('der');
    const tag = der[at++];
    let length = der[at++];
    if (length & 128) {
      const n = length & 127;
      if (!n || n > 4 || at + n > end) throw Error('der');
      length = 0;
      for (let i = 0; i < n; i++) length = length * 256 + der[at++];
    }
    if (at + length > end) throw Error('der');
    return { tag, start: at, end: at + length };
  };
  const outer = read(0), tbs = read(outer.start, outer.end);
  for (let at = tbs.start; at < tbs.end;) {
    const field = read(at, tbs.end); at = field.end;
    if (field.tag !== 0xa3) continue;
    const extensions = read(field.start, field.end);
    const oids = [];
    for (let x = extensions.start; x < extensions.end;) {
      const extension = read(x, extensions.end); x = extension.end;
      const oid = read(extension.start, extension.end);
      if (oid.tag !== 6) throw Error('der');
      oids.push(der.subarray(oid.start, oid.end).toString('hex'));
    }
    return oids;
  }
  return [];
}

function assertAppleAnchoredChain(x5c, effectiveDate, root = appleRoot) {
  if (!Array.isArray(x5c) || x5c.length !== 3) throw Error('x5c');
  const [leaf, intermediate, suppliedRoot] = x5c.map(certFromX5C);
  if (suppliedRoot.fingerprint256 !== root.fingerprint256) throw Error('root');
  if (!intermediate.ca || !intermediate.checkIssued(root)
    || !intermediate.verify(root.publicKey)
    || !leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) throw Error('chain');
  // App Store signing leaf/intermediate purpose, as required by Apple's verifier.
  if (!extensionOids(leaf).includes('2a864886f76364060b01')
    || !extensionOids(intermediate).includes('2a864886f76364060201')) throw Error('purpose');
  for (const cert of [leaf, intermediate, root]) {
    if (effectiveDate < Date.parse(cert.validFrom) - 60000
      || effectiveDate > Date.parse(cert.validTo) + 60000) throw Error('certificate_date');
  }
  return leaf;
}

export function verifyStoreKitSignature(parts, publicKey) {
  try {
    const signature = Buffer.from(parts[2], 'base64url');
    if (signature.length !== 64 || publicKey.asymmetricKeyType !== 'ec'
      || publicKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') return false;
    return verify('sha256', Buffer.from(`${parts[0]}.${parts[1]}`),
      { key: publicKey, dsaEncoding: 'ieee-p1363' }, signature);
  } catch { return false; }
}

/**
 * Apple JWS `offerType` — any of these means the period is not standard paid list price.
 * 1 introductory · 2 promotional · 3 offer code · 4 win-back
 * @see https://developer.apple.com/documentation/appstoreserverapi/offertype
 */
export const NON_STANDARD_PAID_OFFER_TYPES = new Set([1, 2, 3, 4]);

/**
 * Verify StoreKit Transaction JWS proves an active **standard paid** WeekFit subscription.
 * Rejects missing/invalid JWS, wrong product/bundle, expired/revoked, free trial,
 * and any App Store offer (introductory / promotional / offer code / win-back).
 * Zero-price transactions are also rejected when `price` is present.
 */
export function requirePaidSubscriptionJWS(headerValue, options = {}) {
  const nowMs = options.nowMs ?? Date.now();
  const productIds = options.productIds ?? WEEKFIT_SUBSCRIPTION_PRODUCT_IDS;
  const bundleIds = options.bundleIds ?? WEEKFIT_BUNDLE_IDS;
  const skipSignature = options.skipSignature === true;

  if (typeof headerValue !== 'string' || !headerValue || headerValue.length > 200_000) {
    throw new ServiceError('subscription_required', 402);
  }

  // Local developer bypass token (iOS DEBUG → localhost only).
  if (options.allowDevAuth && headerValue === 'weekfit-dev-local-subscription') {
    return { productId: 'dev', environment: 'Xcode' };
  }

  const parts = headerValue.split('.');
  if (parts.length !== 3) throw new ServiceError('subscription_required', 402);

  let header;
  let payload;
  try {
    header = decodePart(parts[0]);
    payload = decodePart(parts[1]);
  } catch {
    throw new ServiceError('subscription_required', 402);
  }

  if (header.alg !== 'ES256') throw new ServiceError('subscription_required', 402);

  if (!skipSignature) {
    try {
      // Offline certificate validation uses the signed date, matching Apple's
      // verifier; expiry of the subscription itself is checked against now below.
      const effectiveDate = Number(payload.signedDate ?? nowMs);
      if (!Number.isFinite(effectiveDate) || effectiveDate > nowMs + 60000) throw Error('signed_date');
      const leaf = assertAppleAnchoredChain(header.x5c, effectiveDate, options.rootCertificate ?? appleRoot);
      if (!verifyStoreKitSignature(parts, leaf.publicKey)) throw Error('signature');
    } catch {
      throw new ServiceError('subscription_required', 402);
    }
  }

  if (!productIds.has(payload.productId)) throw new ServiceError('subscription_required', 402);
  if (!bundleIds.has(payload.bundleId)) throw new ServiceError('subscription_required', 402);
  if (payload.type && payload.type !== 'Auto-Renewable Subscription') {
    throw new ServiceError('subscription_required', 402);
  }
  if (payload.revocationDate) throw new ServiceError('subscription_required', 402);

  const expires = Number(payload.expiresDate);
  if (!Number.isFinite(expires) || expires <= nowMs) {
    throw new ServiceError('subscription_required', 402);
  }

  // Reject every App Store offer period — only ordinary paid renewals unlock AI.
  // offerType: 1 intro · 2 promo · 3 offer code · 4 win-back (and any future value).
  if (payload.offerType != null && payload.offerType !== '') {
    throw new ServiceError('subscription_required', 402);
  }
  if (typeof payload.offerIdentifier === 'string' && payload.offerIdentifier.length > 0) {
    throw new ServiceError('subscription_required', 402);
  }
  if (typeof payload.offerDiscountType === 'string' && payload.offerDiscountType.length > 0) {
    throw new ServiceError('subscription_required', 402);
  }
  // price is milliunits when present; free / $0 must not unlock paid AI.
  if (payload.price === 0 || payload.price === '0') {
    throw new ServiceError('subscription_required', 402);
  }

  return {
    productId: payload.productId,
    environment: payload.environment,
    expiresDate: expires,
  };
}
