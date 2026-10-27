# WeekFit Food Photo API

Production host: `https://weekfit-food-photo.onrender.com`

iOS app (`GoogleService-Info.plist`): `PROJECT_ID=weekfitai`. Render must set `FIREBASE_PROJECT_ID=weekfitai` and `ALLOW_DEV_AUTH=0`.

**If the phone says recognition fails / “service doesn’t respond”:** Firebase Authentication is often not initialized. Identity Toolkit returns `CONFIGURATION_NOT_FOUND` until you open **Firebase Console → Authentication → Get started** and enable **Anonymous** for `weekfitai`. Analytics alone is not enough. Verify with `Scripts/verify_firebase_photo_auth.sh`.

## Evening Coach summary

`POST /v1/coach/day-summary` uses the same Firebase Bearer auth and OpenAI server key as photo recognition. iOS sends one day snapshot after **20:00 local**, saves the answer, and shows it on Coach. Reopening the app, switching tabs, editing meals, or changing language must **not** spend another AI call.

**Deploy order (required before device QA):**

1. Attach a **persistent disk** to the Render service (or equivalent volume).
2. Set `COACH_SUMMARY_STORE_DIR` to an absolute path on that disk (example: `/var/data/coach-summary`). Empty → endpoint returns **503**; photo recognition keeps working.
3. Keep `COACH_SUMMARY_MODEL=gpt-4.1-mini` (separate from the photo model — does not change photo cost/settings).
4. Coach OpenAI starts are reserved on the persistent disk before the provider call: one UID per local day, at least 20 hours apart, and no retry. `COACH_SUMMARY_ONCE_PER_DAY=0` and `COACH_SUMMARY_ALLOW_UNRESTRICTED_HEADER=1` refuse to boot in production. Leave `COACH_AI_ENABLED` unset or `0` until a resume is intentional; `1` allows new generations. Food recognition does not use this switch.
5. Redeploy the backend, then ship the iOS build that includes evening summary.
5. The file ledger is for one process on one disk. Production sets `COACH_SUMMARY_SINGLE_INSTANCE=1` and does not scale this service. That flag is not proof the dashboard has one instance. `GET /v1/coach/day-summary` reads a saved result and does not call OpenAI. `COACH_SUMMARY_MAX_INPUT_TEXT_BYTES` caps the UTF-8 size of the instruction text plus the day snapshot. It is not a token budget for the whole model request.

Client attempt markers are written **before** auth/network. Failure/timeout also consumes the day’s attempt (no retry button).

Node 24, no runtime dependencies. Server-side OpenAI Responses API with strict structured output, `detail: high`, `store: false`. Default model: `gpt-6-astra`, reasoning effort `high`; configurable alternative `gpt-6.1-sol`. Model choice is controlled by the server, never by the phone. No silent fallback to a cheaper model.

The flagship model is a quality-first choice, not a food-recognition accuracy guarantee. Portion sizes, hidden oil, sauces and macros are estimates. Results always require user confirmation. This service does **not** query a nutrition database; all returned nutrient values are labeled `ai_estimate`. Totals are computed from component estimates. Add verified food-database matching separately before claiming database-backed values.

## Local start

```bash
cd backend/food-photo-recognize
cp .env.example .env
# Edit .env locally. Set OPENAI_API_KEY.
# For local testing: ALLOW_DEV_AUTH=1 and WEEKFIT_DEV_TOKEN=weekfit-dev-local-token
npm test
npm start
```

Do not overwrite an existing .env; back it up before replacing local code. The backend shown earlier on the Mac is not present in the GitHub main branch as of implementation, so this is a new service, not a verified drop-in replacement of its response schema.

Point iOS Debug at `http://MAC_LAN_IP:8080` (without `/healthz`). Allow Local Network access. Match the dev bearer token. Existing iOS request fields `imageBase64`, `mimeType`, `locale` are accepted; `model` is ignored. `note` is optional. The iOS response decoder must use the contract below; do not assume the old fixture decoder matches it.

## Async analysis (preferred)

Production-oriented path: `POST /v1/food/photo-analyze` returns **202** after durable accept (photo in object store + job enqueued). Workers (`node worker.mjs`) run AI under `GLOBAL_AI_SLOTS`. Clients poll `GET /v1/food/photo-analyze/:analysisId` (`queued` | `processing` | `completed` | `failed`). See `docs/NutritionAsyncCapacityPlan.md` and `docs/NutritionNodeVsJavaADR.md`.

**Production config (multi-instance):** `STATE_BACKEND=redis` does not share the file photo ledger. New food generations are refused with `503 file_ledger_unsupported` and detail `redis_separate_data_dir` unless the process is one shared disk: `ALLOW_SINGLE_NODE_ASYNC=1`, an explicit `DATA_DIR`, and `OBJECT_STORE=local`. A Redis fleet with a separate `DATA_DIR` per instance must not call the provider.

**Single Render instance (current `weekfit-food-photo`):** set `ALLOW_SINGLE_NODE_ASYNC=1`, `ASYNC_ANALYSIS=1`, `DATA_DIR=/var/data` (persistent disk), `OBJECT_STORE=local`, `STATE_BACKEND=file`, `GLOBAL_AI_SLOTS=16` (not 100 until provider confirmation). The image entrypoint runs API + worker in one container. Do not scale this service above 1 instance without Redis + object store. Sync `POST /v1/food/photo-recognize` and async `POST /v1/food/photo-analyze` share `DATA_DIR/quota` and `DATA_DIR/photo-calls`. One analysis id has one provider marker, synced before the call.

Distributed load (mini-Redis + HTTP object store, mock OpenAI, 0 real calls):

```bash
npm run test:load:redis:quick
npm run test:load:redis
node --test async/redis-adapters.test.mjs
```

Dev single-node file store (not for production):

```bash
npm run start:async:mock
npm run worker:mock
npm run test:load:async:quick
```

## Endpoints

- `GET /healthz`: liveness and configuration; does not prove provider credentials work.
- `GET /readyz`: 200 only when provider and authentication are configured.
- `POST /v1/food/photo-analyze`: **async accept** (202). **Standard paid** JWS (no App Store offer) **or** one complimentary free trial per Firebase UID (`X-WeekFit-Photo-Free-Trial: 1`) before enqueue. Idempotency via `Idempotency-Key` / `X-WeekFit-Analysis-Id`.
- `GET /v1/food/photo-analyze/:analysisId`: status/result for the owning user only.
- `POST /v1/food/photo-recognize`: legacy synchronous path (kept for compatibility). Requires a **standard paid** WeekFit subscription proof (`X-WeekFit-Subscription-JWS` — active auto-renewable, **no** `offerType` / offer identifier / offer discount, **not** `$0` price), **or** one complimentary free trial per authenticated user when the client sends `X-WeekFit-Photo-Free-Trial: 1`. Introductory trial, promotional offer, offer code, win-back, and free promo paths are rejected with `402 subscription_required` before OpenAI is called. After the free trial is claimed for that UID, further unpaid calls return `402`. Local `ALLOW_DEV_AUTH` may send `weekfit-dev-local-subscription` instead. Free-trial claims persist under `DATA_DIR/photo-free-trial` (or Redis when async uses Redis).

Request: `{ "imageBase64": "<JPEG base64>", "mimeType": "image/jpeg", "locale": "en_US", "note": "Optional food context" }`.

JPEG envelope and dimension validation: minimum 64 px, maximum 4096 px per dimension, maximum decoded size 8 MiB. Prefer approximately 1536-2048 px on the longest side for the quality-first capture path; preserve orientation and aspect ratio on the phone. The server validates JPEG metadata, not a full decoder. Never rely on headers alone to claim a photo is usable; non-food and bad imagery are also rejected by recognition.

Response fields:

```json
{
  "isFood": true,
  "name": "Chicken and rice",
  "items": [{
    "name": "Cooked rice", "preparation": "cooked",
    "grams": 150, "minGrams": 100, "maxGrams": 200,
    "calories": 195, "protein": 4, "carbs": 42, "fat": 0.5,
    "assumptions": []
  }],
  "uncertainties": ["Portion weight cannot be measured from this photo"],
  "clarificationQuestion": "Was oil or sauce added?",
  "totals": {"grams": 150, "calories": 195, "protein": 4, "carbs": 42, "fat": 0.5},
  "nutritionSource": "ai_estimate", "estimated": true,
  "requiresConfirmation": true, "model": "gpt-6-astra", "requestId": "uuid"
}
```

This example illustrates the contract, not a complete chicken meal. Errors: `{ "error": "machine_code", "requestId": "uuid" }`. 401 auth, 402 paid subscription required, 413 size, 422 no food/refusal, 429 local quota, 502 invalid/provider/incomplete result, 503 busy/queue overload (may include `Retry-After`), 504 timeout. Preserve the photo on recoverable errors; never silently substitute a fixture.

Optional headers: `Idempotency-Key` or `X-WeekFit-Analysis-Id` (same key, user-scoped) coalesce in-flight duplicates and cache a successful result briefly so retries do not double-call OpenAI.

## Local mock / load testing (no OpenAI spend)

```bash
# Unit + concurrency tests (mocked)
npm test

# Full local load suite — OPENAI_MOCK forced, real OpenAI calls = 0
npm run test:load

# Manual mock server (never set OPENAI_MOCK in production)
OPENAI_MOCK=1 ALLOW_DEV_AUTH=1 WEEKFIT_DEV_TOKEN=weekfit-dev-local-token \
  FOOD_PHOTO_MOCK_DELAY_MS=50 npm run start:mock
```

`OPENAI_MOCK=1` is rejected when `NODE_ENV=production`. Mock mode never falls back to real `fetch` against api.openai.com.

## Production authentication

Set `NODE_ENV=production`, `ALLOW_DEV_AUTH=0`, `FIREBASE_PROJECT_ID` and `OPENAI_API_KEY` through the host's secret manager. iOS supplies a Firebase Auth ID token, including anonymous Auth users if desired. Firebase Analytics alone does not provide this token; Firebase Authentication must actually be configured in the app. Server verifies RS256 signature, trusted Google certificates, issuer, audience and timestamps. No shared release bearer. Revoked-token checks and immediate disabled-user enforcement are not implemented; tokens remain valid until expiry. Protect the host with TLS and consider App Check and gateway abuse protection.

## GitHub Actions publication

`Food Photo API - Test and Publish` runs tests and builds/publishes:

`ghcr.io/mkemiazhuk/weekfit-food-photo:<commit SHA>` and `:latest`.

No OpenAI key is needed in CI. Secrets are not baked into the image. GitHub Actions and GitHub Pages cannot serve this long-lived backend. Run the published image on a container host behind HTTPS, with runtime secrets. New GHCR packages may be private; configure host registry access or explicitly change package visibility if needed.

For an already configured container host:

```bash
docker run --rm -p 8080:8080 --env-file /secure/path/weekfit-food.env ghcr.io/mkemiazhuk/weekfit-food-photo:latest
```

There is no live deployment URL until a host is selected and runtime secrets are provisioned. The workflow does not deploy to an invented server.

## Limits, privacy and cost

Default quotas: 20 successful AI starts per user/day (idempotent retries of the same key do not re-charge), 200 globally/day, **4 concurrent AI scans** with a bounded wait queue (`MAX_AI_QUEUE`, default 16, wait `AI_QUEUE_WAIT_MS`). Overload returns **503** + **Retry-After**. All quotas / concurrency / idempotency are **in-memory per process** and reset on restart. Multiple Render instances do **not** share these limits — keep a single instance or put a shared gateway quota in front before multi-replica rollout. No automatic provider retries. Prefer client `Idempotency-Key` / `X-WeekFit-Analysis-Id` to avoid duplicate AI spend.

No images, names or raw model text are logged or persisted. Logs contain request ID, model, duration, outcome and successful-request token counts. `store:false` does not remove OpenAI's separate abuse-monitoring retention policy.

The prior GPT-4.1 mini estimate of $2-3/1,000 photos does not apply to Astra. Current Astra Standard rates: $10/M input and $50/M output tokens. Reasoning tokens count towards output billing. Example assumption: 3,000 input and 2,000 total output tokens => $0.13/scan; this is not a measured benchmark. The 16,000-output-token cap is a safety ceiling, not expected usage, and may still produce incomplete results. Tune latency, cost and completeness using real photos and provider usage logs. Do not enable unlimited scanning at the existing subscription price without measuring economics.

## Evaluation

Build an opt-in private set of 30-50 meals with weighed ingredients and recorded oil/sauce. Compare Astra and Sol for component precision/recall, weight and calorie error, user corrections, latency, tokens and successful-confirmation cost. Do not publish personal photos to this public repository. Tests cover contracts, authorization boundaries, input limits and failure behavior, using mocked OpenAI responses. They do not establish real-world recognition quality or live provider access.
