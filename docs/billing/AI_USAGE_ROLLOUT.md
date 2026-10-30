# Premium AI allowances and top-ups

Implementation starts from main `0e79aedd1d99c184910a695b04d1355fb2a9d48c`.
This change does not change live prices, create App Store products, deploy Render, or activate billing.

## Product configuration

Monthly `com.weekfit.subscription.monthly` and Annual `com.weekfit.subscription.annual` retain their prices and the same Premium access. New AI terms: 30 successful photo recognitions and 300 voice seconds per calendar-month anniversary. Annual gets twelve monthly windows, not an upfront annual allocation. No rollover of the monthly service allowance. Purchases are separate, non-expiring balances, used after the allowance.

| Consumable product | Units | Target Polish customer price |
| --- | --- | --- |
| com.weekfit.topup.photos20 | 20 photos | PLN 4.99 |
| com.weekfit.topup.photos50 | 50 photos | PLN 9.99 |
| com.weekfit.topup.voice15 | 900 seconds | PLN 6.99 |
| com.weekfit.topup.voice30 | 1,800 seconds | PLN 11.99 |

Confirm available price points in App Store Connect. UI uses StoreKit displayPrice, never these constants. StoreKit testing USD prices are illustrative, not production pricing. The obsolete fixture annual trial has been removed; both subscriptions are at the same fixture level. No Pro or Unlimited products.

## Access and migration

- Billing is off unless `AI_BILLING_ENABLED=1` on the backend and `WeekFitAIUsageEnabled` is true (Boolean) in the app Info.plist. This key is deliberately absent by default.
- When enabled, old POST photo/session endpoints return 426. Coordinate release; do not enable the server while old builds still need those endpoints. Existing asynchronous jobs must be drained before switching. Coach Summary routes are unchanged.
- Active subscriptions and signed billing grace grant AI access, including offer codes and other offers. Billing retry without grace does not. Cancellation preserves the paid period. Apple server status, not a client boolean or old JWS expiry alone, is authoritative.
- `BILLING_EXISTING_PHOTO_CUTOFF` is a required explicit UTC rollout instant. Standard paying subscription lineages originally purchased before that instant retain their previous photo access. Their photo top-ups are hidden. A numerical 1,000,000-unit internal reservation ceiling is a defensive implementation bound; UI never calls this unlimited. This exception must be checked against the final historical promises before rollout. New voice allowance is 300 seconds for all active subscriptions.
- The legacy AppTransaction cutoff (19 August 2026) and existing tab entitlements are unchanged. Legacy-only access does not grant the new cloud voice/photo subscription access.
- Expired subscribers may read their wallet and finish delivery of earlier purchases. Purchased balances persist; spending them currently requires an active subscription. Disclose this before purchase and in Review Notes. This precise dependency has not yet been approved by App Review.
- No database edits or forced conversions of existing users are performed.

## Durable wallet and transactions

The wallet is derived from Apple's verified original subscription transaction ID plus environment, not the Firebase anonymous UID. A restored subscription JWS recovers the same wallet on another device/install. New subscriptions and consumables use the server-issued UUID as StoreKit appAccountToken. A pre-purchase authenticated checkout endpoint issues this UUID for first-time subscribers; an existing expired subscription recovers the previous UUID before resubscribing. When Apple creates a new subscription lineage, its signed appAccountToken links it back to the old wallet, preserving top-ups. A consumable is credited once per environment/transaction ID, after live Apple transaction verification and matching that token. A signed transaction is a sensitive bearer proof: never log it.

SQLite WAL/FULL stores balances, periods, reservations, purchase/refund tombstones, audit events and metering. Exclusive database locking intentionally prevents a second API process from sweeping another process's reservations. **One API process, one persistent disk only.** Redis/multi-instance billing is rejected at startup. Back up the billing SQLite database using SQLite's backup API or a consistent stopped-volume snapshot; copying only the main file while WAL is active is not a backup. Never delete this database as ordinary cache cleanup.

An interrupted consumable remains unfinished until server acknowledgment. The subscription transaction observer must not finish consumables as if they were subscriptions. Recovery uses Transaction.unfinished plus the server wallet. Restore Purchases alone does not restore spent consumable transactions.

Refunds reverse credited quantities once, including a negative purchased balance if already consumed. That debt offsets an active monthly allowance once and is recorded as a refund adjustment; it is not deducted again in every future month. Expired months cannot repay debt. Refund-before-delivery is tombstoned. Server notification handling verifies Apple's signed envelope and transaction. Refund reversal notifications are not auto-recredited: reconcile them explicitly before adding support.

## Backend secrets and environment

Install with `npm ci`. New dependencies are Apple's official App Store Server Library and `ws`. Both CI and Docker install locked dependencies.

Required when enabling billing:

```
AI_BILLING_ENABLED=1
DATA_DIR=/persistent/mount/path
ALLOW_SINGLE_NODE_ASYNC=1
STATE_BACKEND=file
BILLING_APPLE_ENVIRONMENT=Sandbox
BILLING_APPLE_KEY_PATH=/mounted/secrets/SubscriptionKey.p8
BILLING_APPLE_KEY_ID=<App Store Connect In-App Purchase key ID>
BILLING_APPLE_ISSUER_ID=<issuer UUID>
BILLING_EXISTING_PHOTO_CUTOFF=<confirmed rollout instant in ISO-8601 UTC>
```

`BILLING_APPLE_ENVIRONMENT` is either Sandbox or Production. Do not accept sandbox transactions on the production service. Use a separate staging service/app Debug base URL for sandbox. Local StoreKit .storekit transactions are not signed by Apple's production roots and cannot fund a live server; use StoreKit Sandbox for end-to-end verification. The local fixture supports purchase-sheet/UI testing only.

The Apple verifier pins the existing Apple G3 root, verifies bundle `com.weekfit.app`, App Store ID 6776311371 in production, environment, chain, signature and online certificate checks. Keep the `.p8` file outside Git and images. Existing OPENAI_API_KEY, Firebase and voice enable settings remain required. Never create a secret in a user-visible file.

App Store Connect notification URL: `https://<billing-host>/v2/billing/notifications`. Configure both environment URLs correctly and send Apple's test notification before launch. The first consumable type needs review with an app version. Create/localize all four products and disclose active subscription requirement and non-expiring purchased balance in all supported storefront metadata.

## Managed voice

The app receives no OpenAI ephemeral credential in the managed path. It sends its SDP through the authenticated native bridge; the backend creates a WebRTC call using the configured server session, saves the provider call ID and attaches a server-side WebSocket observer. Metering begins at the first observed response or speech event, after transport establishment. Per-call budget is at most the available balance, remaining subscription time, and 3,600 seconds. One live reservation per wallet and the configured global call count are enforced atomically.

A server timer hangs up through `/v1/realtime/calls/{call_id}/hangup` at the budget deadline. Provider closure must succeed before unused reserved seconds are returned. No client-reported token count or client timer can grant credit or authorize a longer call. The UI polls remaining time and warns in the last minute. Stop and reconnect do not create a second concurrent wallet call.

**Production launch gate:** the managed transport has mock integration tests, not a live iPhone/OpenAI end-to-end certification. Validate real Location headers, sideband events, hangup behavior, disconnect timing, lost response, and app/background behavior on staging. A dead control process cannot execute hangup while it is down; provider media can outlive it. Restart recovery attempts to close persisted call IDs before admitting calls and refunds uncertain duration. An independent watchdog or stronger provider-side maximum is required before claiming outage-proof hard spending caps. Do not launch paid voice until this failure mode has been exercised and accepted or resolved.

## Photo path and limits

V2 photo processing uses a bounded server queue and durable atomic quota reservation. Failed/non-food outcomes release units; successful validated results and idempotency keys are retained. Concurrent duplicates join a single promise; completed duplicates replay the saved result. A failed/unknown key never issues another provider call after restart. A new user-requested analysis uses a new key. Current provider timeout still applies. Global daily photo provider call budget is retained in the billing audit ledger; no debit occurs on a budget refusal. This is a provider safeguard, not a hidden subscription quota.

Do not erase idempotency/purchase history to reclaim disk space. Define archival/retention before sustained growth. Never store incoming images in this billing ledger; result data still contains personal nutrition information and must be included in the privacy/retention review.

## Validation

Run `npm ci && npm test` in backend/food-photo-recognize. Billing tests cover month-end/leap-day windows, duplicated delivery, cross-device quotas, refunds/debt, failure release, restart persistence, offers/grace/expiry, and server-controlled voice termination. Existing service tests must still pass with billing disabled.

The macOS GitHub Actions workflow builds the iOS simulator app without signing. No Xcode exists in the implementation Linux environment; a successful simulator build and device UI QA are required before release. Test light/dark, Dynamic Type, all ten app languages, localized StoreKit prices, pending/cancelled purchases, app kill during delivery, and subscription expiry with purchased balance. Source texts for the new screen live in AIUsage.xcstrings; the existing language resolver selects its table for ai.usage.* keys.
