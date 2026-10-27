# Evening Coach summary — deploy checklist

## Why this matters

`POST /v1/coach/day-summary` refuses to run when `COACH_SUMMARY_STORE_DIR` is empty (`503 summary_not_configured`). Photo recognition is independent and keeps working.

## Production evening recap (current default)

Client: `CoachEveningSummaryPolicy.isCoachSurfaceEnabled = true`  
Client: `CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow = true`  
Server: one OpenAI start per UID per local day after 20:00, reserved on the persistent disk before the call. Production refuses to boot if `COACH_SUMMARY_ONCE_PER_DAY=0`. Keep `COACH_AI_ENABLED` off until resume is intentional. Every instance must mount the same `COACH_SUMMARY_STORE_DIR` disk; a second disk or ephemeral Redis does not share the reservation.

- Coach shows evening recap after 20:00 when there is no live/upcoming unresolved session.
- AI auto-runs at most once per local day; first successful answer is cached and reused (activity fingerprint must not regenerate).
- Stale AI replies are discarded if Coach left the evening-recap state.
- Numeric day metrics render without waiting for AI.
- UI is one calm card (personal headline, hero activity, compact rows, note, feeling).
- Feeling replies use a local short reaction (no extra AI call); redeploy backend after prompt voice tweaks.

### Console diagnostics

Filter: `subsystem:com.weekfit.app category:CoachEveningSummary`  
No tokens or personal fact/summary text are logged. Key events: `coach.enter`, `cache.hit` / `cache.miss`, `button.tap`, `refresh.blocked`, `http.request` / `http.response`, `cache.saved`, `ui.ready`.

## Do not resume yet

Leave the Render service `weekfit-food-photo` suspended until an explicit resume command. A push to `main` that touches `backend/food-photo-recognize/**` publishes `ghcr.io/.../weekfit-food-photo:latest` and, when the `RENDER_DEPLOY_HOOK` secret is set, POSTs that hook. Keep this change off `main` until resume is intended.

`COACH_AI_ENABLED` defaults to off in production. A boot with the flag unset does not start new Coach generations. A saved successful summary can still be read. Food recognition does not use this switch.

## Render

iOS base URL: `https://weekfit-food-photo.onrender.com` → `POST /v1/coach/day-summary`.

The reservation is a file ledger on one directory. Production must set `COACH_SUMMARY_SINGLE_INSTANCE=1` and keep the service at one instance. Without that flag, new Coach generations stay off and a saved result can still be read. `COACH_SUMMARY_SINGLE_INSTANCE=1` is an operator declaration. It does not prove the dashboard is scaled to one instance.

Ownership is a SQLite reserved lock held until the process releases it or the process dies. A paused process still holds the lock. The age of a heartbeat or lock file does not transfer ownership. The committed fence increases only after that OS lock is acquired. A writer whose fence is stale does not publish records and does not delete another owner's files. If the lock cannot be acquired, new generation is refused.

`GET /v1/coach/day-summary?day=YYYY-MM-DD&timezone=Area/City` reads status only. It does not reserve and does not call OpenAI. `200` is the saved summary, `202` is still in progress, `409` is a terminal failure or unknown outcome, `404` means this day was never reserved.

The day record and `provider_started` are fsynced before the OpenAI request. A failed write does not call the provider. A directory fsync error, including `EINVAL`, `ENOTSUP`, and `EPERM`, is not treated as success. In production that process then blocks new AI calls with `503 durability_unconfirmed` and detail `directory_fsync_<errno>`. `/healthz` shows `directoryDurable`, `durabilityReason`, and `durabilityErrno`. `STATE_BACKEND=redis` with a separate `DATA_DIR` refuses new food generations (`file_ledger_unsupported` / `redis_separate_data_dir`); the file ledger is not a shared lock in that configuration. An inflight file older than the provider grace is closed to terminal `unknown` only by the current owner. `meta.lastAttemptAt` stays. That attempt does not call the provider again.

Checked while the service was suspended, 2026-10-27 02:54:15 GMT: `GET https://weekfit-food-photo.onrender.com/healthz` returned HTTP 503 with `x-render-routing: suspend-by-user` and the body "This service has been suspended by its owner." That response does not include the disk mount, the instance count, autoscaling, or env values. `render.yaml` in this repo is a blueprint marked not applied. README text is not a reading of the live service.

### Dashboard checks before any resume

These were not verified from this environment. In the Render dashboard for `weekfit-food-photo`, confirm each line. Do not treat this file as the confirmation.

- Service status remains suspended until a separate resume command.
- Settings → Scaling: web instances exactly 1, autoscaling off. No second web service sharing this disk.
- Disks: one persistent disk is attached. Note its mount path.
- Environment: `DATA_DIR` and `COACH_SUMMARY_STORE_DIR` are absolute paths inside that mount path. `COACH_SUMMARY_STORE_DIR` is not empty.
- After a redeploy that does not delete the disk, `coach-guard/` under `COACH_SUMMARY_STORE_DIR` is still present.
- `COACH_AI_ENABLED` is unset or `0`.
- `COACH_SUMMARY_ONCE_PER_DAY` is not `0`. `COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER` is not `1`.
- `DAILY_SCAN_LIMIT=20`, `GLOBAL_DAILY_SCAN_LIMIT=200`, `MAX_PROVIDER_CALLS_PER_DAY=200`.
- `COACH_SUMMARY_MAX_STARTS_PER_UTC_DAY=100`, `COACH_SUMMARY_MAX_STARTS_PER_MINUTE=10`, `COACH_SUMMARY_MAX_CONCURRENT=2`.
- `COACH_SUMMARY_MAX_INPUT_TEXT_BYTES=80000` (or the legacy name `COACH_SUMMARY_MAX_INPUT_TOKENS`, which is the same byte ceiling, not a token budget).
- `COACH_SUMMARY_MAX_OUTPUT_TOKENS=8192` is an output budget only. It does not promise a finished JSON object.

### Safe enablement

1. Keep the service suspended.
2. Mount the disk and set `COACH_SUMMARY_STORE_DIR` (for example `/var/data/coach-summary`). An empty value returns `503 summary_not_configured` and does not call OpenAI.
3. Remove `COACH_SUMMARY_ONCE_PER_DAY=0` and `COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER=1`. Production refuses to boot if either is set. The day guard cannot be turned off.
4. Leave `COACH_AI_ENABLED` unset or `0`.
5. Confirm `/healthz`: `coachSummaryConfigured: true`, `coachSummaryOncePerDay: true`, `coachAiEnabled: false`, `coachSummaryPromptVersion: 14`.
6. Only on a later explicit command, set `COACH_AI_ENABLED=1` and resume the service.

```bash
curl -sS https://weekfit-food-photo.onrender.com/healthz
curl -sS -X POST https://weekfit-food-photo.onrender.com/v1/coach/day-summary \
  -H 'Content-Type: application/json' -d '{}'
# expect 401 unauthorized while the process is up, not 404
```

## Local backend

```bash
cd backend/food-photo-recognize
mkdir -p /tmp/weekfit-coach-summary
# COACH_SUMMARY_STORE_DIR=/tmp/weekfit-coach-summary
# Do not set COACH_SUMMARY_ONCE_PER_DAY=0. It no longer disables the guard,
# and production will not boot with that value.
npm test
```

## What the disk guarantees

- The day file is created and fsynced before `provider_started`. `provider_started` is fsynced before `callProvider`. A failed sync or write throws and does not call OpenAI.
- The same directory holds the UTC-day budget, the minute budget, inflight slots, and the circuit file. The process lock is `coach-guard/owner.sqlite`. The fence is `coach-guard/fence.sqlite`.
- Existing flat day files are migrated by the current owner: `completed` stays readable, `failed` and any other prior attempt become terminal. No OpenAI call during migration.
- A dead process releases the OS lock. The next process may take the fence. It does not start a provider call for an attempt that is already reserved or `provider_started`.
- After the provider timeout plus 5 seconds, the current owner rewrites a `reserved` or `provider_started` record to `unknown`. The next request returns `409 attempt_unknown`.
