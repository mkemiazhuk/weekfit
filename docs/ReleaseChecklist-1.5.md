# WeekFit 1.5 — production archive

Ships the redesigned first-run, Maya on Today, Premium AI photo/voice allowances, and keeps TestFlight / Sandbox out of Firebase Analytics. Billing details: `docs/billing/AI_USAGE_ROLLOUT.md`.

## Build identity

| Item | Value |
| --- | --- |
| Marketing | `1.5` |
| Build | `32` (app + widget; higher than uploaded `26` and widget `31`) |
| App flag | `WeekFitAIUsageEnabled` = YES |
| Sandbox flags | absent — App Store archive must not include them |
| Server | `AI_BILLING_ENABLED` stays **0** until 1.5 is approved and about to go live |

## Archive

```sh
bash Scripts/archive_for_app_store.sh
```

Then Organizer → Validate → Distribute to App Store Connect. Attach the build to version **1.5**.

What's New and review notes: `docs/AppStoreListing.md`.

## Launch day (server, after approval)

Production billing keeps `POST /v1/food/photo-analyze` and `POST /v1/food/photo-recognize` on their existing paid rules, so installed builds keep photo analysis. `POST /v1/planner-voice/session` returns 426. Turn billing on when 1.5 is about to go live:

1. Back up `/var/data/billing.sqlite`.
2. Render: `AI_BILLING_ENABLED=1` and `BILLING_EXISTING_PHOTO_CUTOFF=<UTC now>`. Keep Sandbox settings from `docs/billing/STAGING_SETUP.md`.
3. Confirm `GET /v2/ai/usage` without a token answers 401, not 404.
4. Confirm `POST /v1/food/photo-analyze` without a token answers 401, not 426.
5. Release 1.5 in App Store Connect (manual + phased).
