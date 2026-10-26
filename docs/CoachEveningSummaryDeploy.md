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

The reservation lives on one persistent disk. Every process that can call OpenAI for Coach must mount that same `COACH_SUMMARY_STORE_DIR`. A second disk, an ephemeral container filesystem, or Redis does not share the ledger. The in-memory map only joins waiters inside one process.

### Safe enablement

1. Keep the service suspended.
2. Mount the disk and set `COACH_SUMMARY_STORE_DIR` (for example `/var/data/coach-summary`). An empty value returns `503 summary_not_configured` and does not call OpenAI.
3. Remove `COACH_SUMMARY_ONCE_PER_DAY=0` and `COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER=1`. Production refuses to boot if either is set. The day guard cannot be turned off.
4. Leave `COACH_AI_ENABLED` unset or `0`.
5. Confirm `/healthz`: `coachSummaryConfigured: true`, `coachSummaryOncePerDay: true`, `coachAiEnabled: false`, `coachSummaryPromptVersion: 13`.
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

- Exclusive create (`O_EXCL`) of `coach-guard/users/<sha256 uid>/days/<local day>.json` before `callProvider`.
- The same directory holds the UTC-day budget, the minute budget, inflight slots, and the circuit file, so two processes on this volume share them.
- Existing flat day files are migrated on the next read: `completed` stays readable, `failed` and any other prior attempt become terminal. No OpenAI call during migration.
- A lock file left by a killed process fails closed (`503 coach_store_busy`) until an operator removes `coach-guard/lock`. That does not open a new provider call.
- After the provider timeout plus 5 seconds, a `reserved` or `provider_started` record whose owner is gone is rewritten to `unknown`. The next request returns `409 attempt_unknown` and does not call OpenAI.
