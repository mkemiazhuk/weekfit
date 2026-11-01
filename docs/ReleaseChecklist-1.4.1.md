# WeekFit 1.4.1 — Premium AI allowances release

Ships the AI balance (30 photos and 5 voice minutes a month with Premium), the four consumable top-ups, the stress-index morning hint and the Maya call fixes. Billing details: `docs/billing/AI_USAGE_ROLLOUT.md`, Sandbox setup: `docs/billing/STAGING_SETUP.md`.

## State on 1 November 2026

| Item | State |
| --- | --- |
| Code | `main` at `46fc56b3f` or later |
| Backend tests | 187 / 187 pass |
| iOS unit tests | AI balance suite passes. Full `WeekFitTests`: 2055 passed, 31 failed in Coach copy, analytics and onboarding tests; the same 31 fail on `0e79aedd1` before the billing branch, so not a regression. One parallel simulator clone hung near the end of the run |
| AI usage translations | pass, 10 languages |
| General localization parity / language mix | fail on 15 and 27 old keys, identical before the billing branch — not a regression |
| Live server | `weekfit-food-photo.onrender.com`: Sandbox billing on, Production billing off, image older than the Maya fixes |
| App Store products | four top-ups in Prepare for Submission, 10 localizations, 175 regions |
| App flag | `WeekFitAIUsageEnabled` absent in `WeekFit/Info.plist` — an archive from `main` ships with billing off |

## 1. Before the archive

- [ ] Render → `weekfit-food-photo` → Manual Deploy of the latest image (`ghcr.io/mkemiazhuk/weekfit-food-photo:latest`). Billing flags unchanged. Check `/healthz` uptime resets.
- [ ] Sandbox QA on a real iPhone with the Sandbox TestFlight build (`Scripts/archive_ai_sandbox.sh`):
  - [ ] each of the four top-ups is credited once; killing the app during delivery still credits after relaunch;
  - [ ] Log food: photos left, Add, purchase closes back to Log food;
  - [ ] photo limit error → Add photos → purchase → analysis resumes;
  - [ ] Maya with no minutes opens the minutes top-up; a call stops at the budget and returns unused seconds;
  - [ ] Maya in Russian: greeting not cut off, call ends by itself after goodbye, timer stops;
  - [ ] subscription expiry keeps the purchased balance; resubscribe and reinstall recover it;
  - [ ] refund in Sandbox reverses the credit once;
  - [ ] Apple test notification reaches the Sandbox URL.
- [ ] Decision on the voice launch gate: if the API process dies mid-call, the server cannot hang up and the provider call can outlive the budget (up to the provider's own session limit). Accept this risk in writing or add an independent watchdog before launch.
- [ ] Confirm `BILLING_EXISTING_PHOTO_CUTOFF` (UTC instant): paying subscribers who started before it keep their earlier photo access.

## 2. Archive

- [ ] Set `WeekFitAIUsageEnabled` = YES in `WeekFit/Info.plist` (Boolean) in the commit used for the archive. Without it the build ships with billing hidden.
- [ ] Build number: App Store Connect rejects a number that any earlier 1.4.1 upload used, including the Sandbox TestFlight build. Today `CURRENT_PROJECT_VERSION` = 4; raise it if 4 was uploaded.
- [ ] `Scripts/archive_for_app_store.sh` (it rejects Sandbox plist settings and checks the Firebase plist).
- [ ] Organizer → Validate → Distribute to App Store Connect.

## 3. App Store Connect

- [ ] Account Holder accepts the updated Developer Program License Agreement.
- [ ] Production notification URL `https://weekfit-food-photo.onrender.com/v2/billing/notifications`; send Apple's test notification.
- [ ] Version 1.4.1: attach the build and all four top-ups (the first consumables are reviewed with the version).
- [ ] Each top-up: review screenshot of the new purchase page, review note.
- [ ] Description and Review Notes in all storefront languages: purchased photos and minutes never expire, and using them requires an active Premium subscription.
- [ ] What's New.
- [ ] Release option: **Manually release this version**, with phased release on.

## 4. Launch day, in this order

Production billing makes the old photo and session endpoints return 426, so builds before 1.4.1 lose AI photo and voice the moment it is on. Turn it on only when 1.4.1 is approved and about to go live.

1. [ ] Wait until there are no queued photo jobs (`/healthz`: `asyncQueueDepth` 0).
2. [ ] Back up `/var/data/billing.sqlite` with SQLite's backup API or a stopped-volume snapshot.
3. [ ] Render env: `AI_BILLING_ENABLED=1`, `BILLING_EXISTING_PHOTO_CUTOFF=<confirmed instant>`. Keep the rest from STAGING_SETUP.md. Save and redeploy.
4. [ ] Check: `GET /v2/ai/usage` without a token now answers 401, not 404.
5. [ ] Release 1.4.1 in App Store Connect.
6. [ ] On a real iPhone with the App Store build: balance loads, one real photo top-up is credited.

## 5. First week

- [ ] Crashlytics, reviews, `/healthz` alerts and disk use daily.
- [ ] Billing audit: refunds, failed deliveries, calls that hit the budget.
- [ ] Phased release 10% → 50% → 100% if stable.

Rollback: set `AI_BILLING_ENABLED=0` and redeploy. Wallets stay in the database and older builds get their endpoints back, but 1.4.1 only talks to `/v2/ai/*`, so its AI photo, voice and balance stop working until billing is on again. Treat rollback as an emergency stop, not a way to keep 1.4.1 running.
