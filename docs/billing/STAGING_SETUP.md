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

## Intended isolated Render service

The existing production service `weekfit-food-photo` follows main, has one
instance and a 1 GB disk at /var/data. Leave its billing flag and routes unchanged.
Create `weekfit-ai-sandbox` in My Workspace, Frankfurt, from
`mkemiazhuk/weekfit`, branch `feat/premium-ai-allowances`, with auto-deploy off.
Use the same Dockerfile/context as production:
`backend/food-photo-recognize/Dockerfile`, `backend/food-photo-recognize`.
Use one 0.5c-512mb instance and a separate 1 GB disk mounted at /var/data.
Configure /readyz as the health endpoint. Never share the production wallet disk.

Upload the approved key as a Render secret file named `SubscriptionKey.p8`.
Configure the following through the Dashboard (source of truth for this service):

| Variable | Value |
| --- | --- |
| AI_BILLING_ENABLED | 1 |
| BILLING_APPLE_ENVIRONMENT | Sandbox |
| BILLING_APPLE_KEY_PATH | /etc/secrets/SubscriptionKey.p8 |
| BILLING_APPLE_KEY_ID | Newly created key ID |
| BILLING_APPLE_ISSUER_ID | d551cf68-155e-4c65-8e31-288e1b2752e5 |
| BILLING_EXISTING_PHOTO_CUTOFF | 1970-01-01T00:00:00Z (Sandbox only: exercise photo quota) |
| DATA_DIR | /var/data |
| STATE_BACKEND | file |
| ALLOW_SINGLE_NODE_ASYNC | 1 |
| ALLOW_DEV_AUTH | 0 |
| FIREBASE_PROJECT_ID | weekfitai |
| PLANNER_VOICE_ENABLED | 1 |
| PLANNER_VOICE_MAX_CALLS | 1 |
| OPENAI_API_KEY | Explicitly supplied staging/provider key |

Preserve any additional provider/Firebase configuration required by the deployed
source. Do not enable a partially configured service. Verify live deploy status,
/healthz and /readyz without printing secrets, and send Apple's test notification
to `https://<actual-created-host>/v2/billing/notifications` using Sandbox only.
Do not change the production notification URL until production is prepared.
The Sandbox-only cutoff above is not the future production migration date.

## Internal TestFlight archive

On a Mac with Xcode, signing and the ignored Firebase plist configured, run from
the committed PR branch:

```sh
bash Scripts/archive_ai_sandbox.sh https://ACTUAL-SANDBOX-HOST NEW_BUILD_NUMBER
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
The Sandbox origin cannot equal the production host and cannot contain credentials,
query, fragment or a path. Debug permits local testing. The normal App Store archive script rejects Sandbox
plist settings. The dedicated Sandbox archive must never be submitted for App Store
release. Real TestFlight environment validation,
real purchase delivery, live voice events/hangup, backgrounding and outage behavior
still require real-device validation; simulator build success does not certify them.

## Launch gates still open

- Approved key creation, secure Render secret provisioning, separate paid staging
  service/disk creation and successful Sandbox deployment.
- Apple test notification and all four real Sandbox purchases, refund/redelivery,
  expiry, resubscription and reinstall with preserved purchased balance.
- Live iPhone voice and photo QA, including control-server crash handling.
- Independent voice watchdog or another validated way to enforce the duration
  deadline during API-process failure (see AI_USAGE_ROLLOUT.md).
- Real review screenshot from the new purchase screen, Account Holder agreement
  acceptance, and app/product review submission.

Do not merge/activate production solely because this preparation is committed.
