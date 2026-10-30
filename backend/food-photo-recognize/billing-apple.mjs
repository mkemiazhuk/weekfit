import { readFileSync } from 'node:fs';
import { X509Certificate } from 'node:crypto';
import { AppStoreServerAPIClient, SignedDataVerifier, Environment } from '@apple/app-store-server-library';
import { APPLE_ROOT_CA_G3_PEM, WEEKFIT_SUBSCRIPTION_PRODUCT_IDS } from './subscription-proof.mjs';
import { ServiceError } from './recognition.mjs';

const required = (env, key) => { if (!env[key]) throw Error(`${key} is required for AI billing`); return env[key]; };
export function createAppleBilling(env = process.env, dependencies = {}) {
  const environment = required(env, 'BILLING_APPLE_ENVIRONMENT');
  if (![Environment.PRODUCTION, Environment.SANDBOX].includes(environment)) throw Error('Invalid BILLING_APPLE_ENVIRONMENT');
  const bundle = 'com.weekfit.app';
  const verifier = dependencies.verifier ?? new SignedDataVerifier([new X509Certificate(APPLE_ROOT_CA_G3_PEM).raw], true,
    environment, bundle, environment === Environment.PRODUCTION ? 6776311371 : undefined);
  const api = dependencies.api ?? new AppStoreServerAPIClient(readFileSync(required(env, 'BILLING_APPLE_KEY_PATH'), 'utf8'),
    required(env, 'BILLING_APPLE_KEY_ID'), required(env, 'BILLING_APPLE_ISSUER_ID'), bundle, environment);
  const grandfatherBefore = Date.parse(required(env, 'BILLING_EXISTING_PHOTO_CUTOFF'));
  if (!Number.isFinite(grandfatherBefore)) throw Error('Invalid BILLING_EXISTING_PHOTO_CUTOFF');
  return {
    environment,
    async subscription(jws) {
      try {
        const proof = await verifier.verifyAndDecodeTransaction(jws);
        if (!WEEKFIT_SUBSCRIPTION_PRODUCT_IDS.has(proof.productId) || !proof.originalTransactionId
          || proof.inAppOwnershipType !== 'PURCHASED') throw Error('product');
        // A signed, unexpired transaction alone cannot detect a subsequent refund.
        const status = await api.getAllSubscriptionStatuses(proof.originalTransactionId);
        const candidates = (status.data ?? []).flatMap(group => group.lastTransactions ?? []);
        const row = candidates.find(tx => tx.originalTransactionId === proof.originalTransactionId);
        if (!row?.signedTransactionInfo) throw Error('status');
        const tx = await verifier.verifyAndDecodeTransaction(row.signedTransactionInfo);
        if (tx.originalTransactionId !== proof.originalTransactionId || !WEEKFIT_SUBSCRIPTION_PRODUCT_IDS.has(tx.productId)) throw Error('lineage');
        let accessUntil = tx.expiresDate ?? 0;
        if (row.status === 4 && row.signedRenewalInfo) {
          const renewal = await verifier.verifyAndDecodeRenewalInfo(row.signedRenewalInfo);
          if (renewal.originalTransactionId !== tx.originalTransactionId) throw Error('renewal');
          accessUntil = renewal.gracePeriodExpiresDate ?? 0;
        }
        const active = [1,4].includes(row.status) && !tx.revocationDate && accessUntil > Date.now();
        if (!Number.isFinite(tx.originalPurchaseDate) || tx.originalPurchaseDate > Date.now()) throw Error('anchor');
        return { environment, originalTransactionId: tx.originalTransactionId, productId: tx.productId,
          active, anchor: tx.originalPurchaseDate, accessUntil, appAccountToken: tx.appAccountToken,
          grandfatheredPhotos: tx.originalPurchaseDate < grandfatherBefore && !tx.offerType && tx.price !== 0 };
      } catch (error) {
        if (error instanceof ServiceError) throw error;
        // Distinguish Apple availability failures from absence of a valid subscription.
        if (error.httpStatusCode >= 500 || error.name === 'FetchError') throw new ServiceError('billing_unavailable', 503);
        throw new ServiceError('subscription_required', 402);
      }
    },
    async purchase(jws) {
      try {
        const supplied = await verifier.verifyAndDecodeTransaction(jws);
        const live = await api.getTransactionInfo(supplied.transactionId);
        const tx = await verifier.verifyAndDecodeTransaction(live.signedTransactionInfo);
        if (tx.transactionId !== supplied.transactionId) throw Error('transaction');
        return tx;
      } catch { throw new ServiceError('purchase_verification_failed', 503); }
    },
    async notification(jws) {
      const message = await verifier.verifyAndDecodeNotification(jws);
      const tx = message.data?.signedTransactionInfo
        ? await verifier.verifyAndDecodeTransaction(message.data.signedTransactionInfo) : null;
      return { type: message.notificationType, transaction: tx };
    },
  };
}
