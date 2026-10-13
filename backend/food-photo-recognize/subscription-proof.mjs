import { X509Certificate, createPublicKey, verify } from 'node:crypto';
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

function assertAppleAnchoredChain(x5c) {
  if (!Array.isArray(x5c) || x5c.length < 1 || x5c.length > 3) {
    throw Error('x5c');
  }
  const certs = x5c.map(certFromX5C);
  for (let i = 0; i < certs.length - 1; i++) {
    if (!certs[i].checkIssued(certs[i + 1])) throw Error('chain');
  }
  const anchor = certs[certs.length - 1];
  if (anchor.fingerprint256 === appleRoot.fingerprint256) return certs[0];
  if (!anchor.checkIssued(appleRoot)) throw Error('root');
  return certs[0];
}

/**
 * Verify StoreKit Transaction JWS proves an active **paid** WeekFit subscription.
 * Rejects missing/invalid JWS, wrong product/bundle, expired/revoked, and introductory free trial.
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
    let leaf;
    try {
      leaf = assertAppleAnchoredChain(header.x5c);
    } catch {
      throw new ServiceError('subscription_required', 402);
    }
    const key = createPublicKey(leaf.publicKey);
    const signed = Buffer.from(`${parts[0]}.${parts[1]}`);
    const signature = Buffer.from(parts[2], 'base64url');
    // algorithm null → use key's default (ECDSA with SHA-256 for P-256).
    if (!verify(null, signed, key, signature)) {
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

  // Apple: offerType 1 = introductory (includes free trial).
  if (payload.offerType === 1) throw new ServiceError('subscription_required', 402);
  if (payload.offerDiscountType === 'FREE_TRIAL') {
    throw new ServiceError('subscription_required', 402);
  }

  return {
    productId: payload.productId,
    environment: payload.environment,
    expiresDate: expires,
  };
}
