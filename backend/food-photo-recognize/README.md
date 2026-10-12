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
4. For manual Coach testing leave `COACH_SUMMARY_ONCE_PER_DAY` unset/`0` (calls AI every time, before 20:00 allowed). Set to `1` for production once-per-day after 20:00.
5. Redeploy the backend, then ship the iOS build that includes evening summary.
5. One service instance + one volume is supported; multiple instances need a shared durable store.

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

## Endpoints

- `GET /healthz`: liveness and configuration; does not prove provider credentials work.
- `GET /readyz`: 200 only when provider and authentication are configured.
- `POST /v1/food/photo-recognize`: authenticated JSON request.

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

This example illustrates the contract, not a complete chicken meal. Errors: `{ "error": "machine_code", "requestId": "uuid" }`. 401 auth, 413 size, 422 no food/refusal, 429 local quota, 502 invalid/provider/incomplete result, 503 busy/provider quota, 504 timeout. Preserve the photo on recoverable errors; never silently substitute a fixture.

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

Default quotas: 20 attempts per user/day, 200 globally/day, 4 concurrent scans. Provider attempts count even on failure. All quotas are in memory and reset on restart, per process. Run a single instance for initial testing; use Redis or gateway quotas for multiple replicas and a persistent budget cutoff before public rollout. No automatic provider retries. IDs are generated server-side. Retries can incur another provider charge; there is no request-id deduplication.

No images, names or raw model text are logged or persisted. Logs contain request ID, model, duration, outcome and successful-request token counts. `store:false` does not remove OpenAI's separate abuse-monitoring retention policy.

The prior GPT-4.1 mini estimate of $2-3/1,000 photos does not apply to Astra. Current Astra Standard rates: $10/M input and $50/M output tokens. Reasoning tokens count towards output billing. Example assumption: 3,000 input and 2,000 total output tokens => $0.13/scan; this is not a measured benchmark. The 16,000-output-token cap is a safety ceiling, not expected usage, and may still produce incomplete results. Tune latency, cost and completeness using real photos and provider usage logs. Do not enable unlimited scanning at the existing subscription price without measuring economics.

## Evaluation

Build an opt-in private set of 30-50 meals with weighed ingredients and recorded oil/sauce. Compare Astra and Sol for component precision/recall, weight and calorie error, user corrections, latency, tokens and successful-confirmation cost. Do not publish personal photos to this public repository. Tests cover contracts, authorization boundaries, input limits and failure behavior, using mocked OpenAI responses. They do not establish real-world recognition quality or live provider access.
