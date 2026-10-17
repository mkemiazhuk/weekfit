# Evening Coach summary — deploy checklist

## Why this matters

`POST /v1/coach/day-summary` refuses to run when `COACH_SUMMARY_STORE_DIR` is empty (`503 summary_not_configured`). Photo recognition is independent and keeps working.

## Production evening recap (current default)

Client: `CoachEveningSummaryPolicy.isCoachSurfaceEnabled = true`  
Client: `CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow = true`  
Server: `COACH_SUMMARY_ONCE_PER_DAY` can stay `0` while fingerprint-based client refresh is active; set `1` for hard server once-per-day.

- Coach shows evening recap after 20:00 when there is no live/upcoming unresolved session.
- AI auto-runs with cache keyed by day + activity fingerprint (new completed workout regenerates).
- Stale AI replies are discarded if Coach left the evening-recap state.
- Numeric day metrics render without waiting for AI.
- UI is one calm card (personal headline, hero activity, compact rows, note, feeling).
- Feeling replies use a local short reaction (no extra AI call); redeploy backend after prompt voice tweaks.

### Console diagnostics

Filter: `subsystem:com.weekfit.app category:CoachEveningSummary`  
No tokens or personal fact/summary text are logged. Key events: `coach.enter`, `cache.hit` / `cache.miss`, `button.tap`, `refresh.blocked`, `http.request` / `http.response`, `cache.saved`, `ui.ready`.

## Production once-per-day (later)

1. Set client flag `enforcesOncePerDayAndEveningWindow = true`.
2. Set `COACH_SUMMARY_ONCE_PER_DAY=1` on the server and redeploy.
3. Confirm `/healthz` shows `"coachSummaryOncePerDay":true`.

## Render (or similar)

iOS base URL is correct: `https://weekfit-food-photo.onrender.com` → `POST /v1/coach/day-summary`.  
A `404 not_found` means the **running** container/commit is still photo-only (old `/healthz` without `coachSummaryConfigured`).

### Ship checklist

1. Backend with the route is on `main` (image `ghcr.io/mkemiazhuk/weekfit-food-photo:latest`).
2. In Render → `weekfit-food-photo` → **Manual Deploy** → deploy latest image/`main` (GitHub Actions does not restart Render by itself).
3. Persistent disk (for example mount `/var/data`) and env:
   - `COACH_SUMMARY_STORE_DIR=/var/data/coach-summary` (empty → route exists but returns **503**)
   - `COACH_SUMMARY_MODEL=gpt-4.1-mini` (optional)
   - `COACH_SUMMARY_ONCE_PER_DAY=0` while testing
   - keep `OPENAI_API_KEY`, `FIREBASE_PROJECT_ID=weekfitai`, `ALLOW_DEV_AUTH=0`
4. Confirm live health:
   ```bash
   curl -sS https://weekfit-food-photo.onrender.com/healthz
   # expect coachSummaryConfigured:true, coachSummaryOncePerDay:false,
   # coachSummaryPromptVersion:3  (evening recap; UI uses "now" passage)
   curl -sS -X POST https://weekfit-food-photo.onrender.com/v1/coach/day-summary \
     -H 'Content-Type: application/json' -d '{}'
   # expect 401 unauthorized (not 404 not_found)
   ```
   GitHub Actions publishes `ghcr.io/mkemiazhuk/weekfit-food-photo:latest` but does **not** restart Render unless secret `RENDER_DEPLOY_HOOK` is set. Otherwise use Manual Deploy after each prompt/backend change.
5. Then test Coach **Получить итог** on device; reopen Coach and confirm `cache.hit` with no second POST.

## Local backend

```bash
cd backend/food-photo-recognize
mkdir -p /tmp/weekfit-coach-summary
# in .env:
# COACH_SUMMARY_STORE_DIR=/tmp/weekfit-coach-summary
# COACH_SUMMARY_ONCE_PER_DAY=0
npm test
npm start
```

## Once-per-day guarantee (when flag on)

- **Client:** atomic attempt file before network; restore on launch; language/metrics/tab changes do not reclaim.
- **Server:** exclusive create per Firebase UID + local day before OpenAI; completed duplicates return saved answer; failed attempts stay terminal.
