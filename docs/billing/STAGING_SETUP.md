# AI billing Sandbox preparation — 30 October 2026

## Verified external state

App Store Connect has all four consumables in Prepare for Submission, each with
10 localizations and availability in all 175 regions. Poland is the base region:

| Product ID | Apple ID | PLN |
| --- | --- | --- |
| com.weekfit.topup.photos20 | 6828816705 | 4.99 |
| com.weekfit.topup.photos50 | 6828816948 | 9.99 |
| com.weekfit.topup.voice15 | 6828817921 | 6.99 |
| com.weekfit.topup.voice30 | 6828818563 | 11.99 |

The In-App Purchase integrations page shows Active (0). Create a dedicated
`WeekFit Billing Server` In-App Purchase key after explicit credential-creation
approval. Use the In-App Purchase key type, not the existing ASO admin key.
Issuer ID: `d551cf68-155e-4c65-8e31-288e1b2752e5`.
Never store the downloaded .p8 in this repository or a build artifact.

Apple also requires the Account Holder to review an updated Developer Program
License Agreement before submitting app updates. Do not accept it implicitly.

## Same Render service, separate tables

Use the existing `weekfit-food-photo` service in My Workspace, Frankfurt
(`srv-db6fccdckfvc73d98l8g`). It has one instance and a 1 GB disk at /var/data.
Do not create another service, disk or paid compute resource for these tests.

One connection to `/var/data/billing.sqlite` owns two disjoint sets of tables:
`prod_wallets` / `sandbox_wallets`, `prod_subscriptions` / `sandbox_subscriptions`,
`prod_checkout_identities` / `sandbox_checkout_identities`, `prod_purchases` /
`sandbox_purchases`, `prod_periods` / `sandbox_periods`, `prod_balances` /
`sandbox_balances`, `prod_operations` / `sandbox_operations`, `prod_audit` /
`sandbox_audit` and `prod_usage` / `sandbox_usage`. Each also has its own unique
one-active-voice-call index. Transactions stay within one namespace. One API
process owns the SQLite connection, including exclusive locking and WAL/FULL.

`AI_BILLING_SANDBOX_ENABLED=1` enables Sandbox independently.
Leave `AI_BILLING_ENABLED=0` during testing: production legacy routes remain
available, and the new Production billing path stays off. Sandbox requests use
`X-WeekFit-Billing-Environment: Sandbox`. Missing header selects Production;
unknown values are rejected on billing routes. This header selects a verifier,
never proves access: subscription, purchase and notification signatures are
verified using the pinned Apple environment before accessing a namespace.
App-account tokens cannot link wallets across the two table sets.

Voice queue identities, activity-save receipts, sessions, idempotency, refunds,
usage records and audit entries are isolated. Voice admission shares the existing
global capacity cap. Sandbox allows one active call and one concurrent photo
analysis, with a separate daily photo provider-attempt budget of 20 by default
(`BILLING_SANDBOX_PHOTO_BUDGET`). Sandbox still uses paid OpenAI calls. The host,
disk, CPU, provider account and process remain shared resources.

Upload the separately approved Apple key as the existing service's Render secret
file named `SubscriptionKey.p8`. Dashboard remains the configuration source of truth:

| Variable | Testing value |
| --- | --- |
| AI_BILLING_ENABLED | 0 (preserve current production behavior) |
| AI_BILLING_SANDBOX_ENABLED | 1 |
| BILLING_APPLE_KEY_PATH | /etc/secrets/SubscriptionKey.p8 |
| BILLING_APPLE_KEY_ID | Newly approved key ID |
| BILLING_APPLE_ISSUER_ID | d551cf68-155e-4c65-8e31-288e1b2752e5 |
| DATA_DIR | /var/data |
| STATE_BACKEND | file |
| ALLOW_SINGLE_NODE_ASYNC | 1 |
| ALLOW_DEV_AUTH | 0 |
| FIREBASE_PROJECT_ID | weekfitai |
| PLANNER_VOICE_ENABLED | 1 |
| BILLING_SANDBOX_PHOTO_BUDGET | 20 |

Preserve existing provider, Firebase, Coach and legacy photo settings and secrets.
The router pins Production and Sandbox internally; it does not use a globally
selected BILLING_APPLE_ENVIRONMENT. Sandbox fixes its migration cutoff at the
Unix epoch so test subscriptions exercise photo quotas. Before later enabling
Production, set BILLING_EXISTING_PHOTO_CUTOFF to the confirmed real migration
instant; do not use the Sandbox cutoff for real subscribers.

Notification URLs on the same host:
- Production: `https://weekfit-food-photo.onrender.com/v2/billing/notifications`
- Sandbox: `https://weekfit-food-photo.onrender.com/v2/billing/notifications/sandbox`

Their environment is fixed by the path. A conflicting header or a signed
transaction for another environment is rejected. Configure and test Sandbox
notifications first; do not point production notifications at Sandbox.

No billing ledger has been activated by this PR. If an earlier deployment already
created `billing-Production.sqlite` or `billing-Sandbox.sqlite`, startup explicitly
refuses rather than silently replacing their balances. Back up and migrate those
files into the namespaced schema before enabling this version. Never delete them
as a workaround. Existing other production data files are unchanged.

## Internal TestFlight archive

On a Mac with Xcode, signing and the ignored Firebase plist configured, run from
the committed PR branch:

```sh
bash Scripts/archive_ai_sandbox.sh https://weekfit-food-photo.onrender.com NEW_BUILD_NUMBER
```

The script archives an isolated detached worktree, adds Sandbox settings only to
that temporary app plist, verifies the archived settings, and removes the temporary
worktree. The normal checkout and normal App Store archive remain unchanged.
Upload the resulting `build/WeekFit-AI-Sandbox.xcarchive` for internal TestFlight
only. The script does not upload automatically or provide signing credentials.

The explicit `WeekFitAISandboxEnabled` flag plus HTTPS
`WeekFitAISandboxBaseURL` opt this archive into staging. Release builds additionally
require the explicit WEEKFIT_AI_SANDBOX compilation condition set by this script.
Normal Release builds ignore the Sandbox route and disable Sandbox billing.
The origin may be the same production host; it cannot contain credentials,
query, fragment or a path. The Sandbox build sends the environment header on
AI billing and voice requests. Debug permits local testing. The normal App Store archive script rejects Sandbox
plist settings. The dedicated Sandbox archive must never be submitted for App Store
release. Real TestFlight environment validation,
real purchase delivery, live voice events/hangup, backgrounding and outage behavior
still require real-device validation; simulator build success does not certify them.

## Launch gates still open

- Approved key creation, secure Render secret provisioning, existing-service
  configuration and successful Sandbox deployment.
- Apple test notification and all four real Sandbox purchases, refund/redelivery,
  expiry, resubscription and reinstall with preserved purchased balance.
- Live iPhone voice and photo QA, including control-server crash handling.
- Independent voice watchdog or another validated way to enforce the duration
  deadline during API-process failure (see AI_USAGE_ROLLOUT.md).
- Real review screenshot from the new purchase screen, Account Holder agreement
  acceptance, and app/product review submission.

Do not merge/activate production solely because this preparation is committed.
