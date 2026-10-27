# Production rollout gate — WeekFit Nutrition backend

## Status

Code hardening is prepared on `fix/backend-production-readiness`. This does not certify the current Render deployment as production ready. Production was last observed in `sync_compat` mode, with async disabled and no Render Key Value instance. Persistent disk attachment and S3 credentials/lifecycle have not been verified. No production environment variables or infrastructure were changed by this hardening branch.

## Changes in this branch

- S3/R2 PUT, GET and DELETE use the pinned AWS SDK with signed requests, 15-second operation deadlines, bounded downloads and no automatic storage retries. Private bucket lifecycle expiration is still required.
- Server-generated analysis IDs prevent one user's client UUID colliding with another user's stored result.
- Async HTTP bodies are buffered under the upload admission limit.
- Legacy sync recognition uses the same async jobs, quota and global AI limiter when async is enabled. A storage outage cannot bypass those limits through the sync route.
- Redis queue pop and recovery-lease registration are atomic. Idle workers do not block other Redis commands, and workers fill spare slots while existing analyses run.
- `rediss://` uses certificate-verified TLS. Redis connect/command operations have timeouts.
- Long polling survives normal request completion; response disconnect cancels the wait.
- Readiness checks async initialization, Redis reachability and local data directory permissions. Readiness does not validate OpenAI credentials, S3 permissions, disk persistence or real model latency.
- Container PID 1 supervises the API and optional worker together. Unexpected child exit stops the companion; SIGTERM drains both with a bounded shutdown deadline.
- Uncertain provider failures are terminal instead of automatically issuing a second billable call. Lease recovery after a process crash still needs live canary validation; exactly-once provider billing is not promised.
- Production trials cannot fall back to process memory when their durable store is unavailable.

## Recommended initial production topology

Keep the existing `weekfit-food-photo` URL. Use one API/container initially, a **persistent** Render Key Value instance (`noeviction`) for jobs, idempotency, quota and global slots, and a private S3/R2 bucket for photos. The container includes a worker. Coach summary still requires an attached persistent disk because its daily attempt store is file-backed. Do not point this store at ephemeral `/tmp` or the container filesystem.

A single-node file backend is a smaller deployment option, but its concurrency/spend controls remain best-effort and it is not the basis of the distributed burst benchmark. Do not scale it horizontally.

## Configuration to apply after storage is provisioned

Set via Render secrets, never commit values:

```dotenv
NODE_ENV=production
ALLOW_DEV_AUTH=0
OPENAI_MOCK=0
FIREBASE_PROJECT_ID=weekfitai
ASYNC_ANALYSIS=1
STATE_BACKEND=redis
REDIS_URL=<private persistent Key Value URL>
OBJECT_STORE=s3
S3_BUCKET=<private bucket>
S3_ENDPOINT=<HTTPS endpoint; omit for AWS S3>
S3_REGION=<bucket region; auto for R2>
S3_ACCESS_KEY_ID=<secret>
S3_SECRET_ACCESS_KEY=<secret>
INLINE_FAST_PATH=0
GLOBAL_AI_SLOTS=16
WORKER_LOCAL_CONCURRENCY=16
WORKER_MAX_ATTEMPTS=1
DELETE_PHOTO_ON_COMPLETE=1
PHOTO_TTL_MS=86400000
JOB_TTL_MS=86400000
DAILY_SCAN_LIMIT=20
GLOBAL_DAILY_SCAN_LIMIT=200
MAX_PROVIDER_CALLS_PER_DAY=200
COACH_SUMMARY_ONCE_PER_DAY=1
COACH_SUMMARY_STORE_DIR=/var/data/coach-summary
```

The daily limits are an initial safety ceiling, **not** capacity for all 1,000 users to scan each day. Set global quota and spend limits from the actual subscription economics. Estimated USD counters are soft controls; concurrency can overshoot a soft threshold and estimates are not invoiced spend. RPM/TPM admission is process-local, so do not describe it as a fleet-wide provider limit.

Preserve the current photo model until the owner selects the quality/cost target and a real canary validates its credentials, latency and output. Do not raise production concurrency to 100 based only on mocks. Provider concurrency/RPM/TPM and Render CPU/RAM must support it.

Set the Render health check path to `/readyz`. Confirm the image runs `docker-entrypoint.sh`, not an override that launches only `server.mjs`.

## Validation before switching real clients

1. Run `npm ci --ignore-scripts`, `npm test`, and `npm run test:burst100` locally/CI. All OpenAI load traffic must remain mocked.
2. Test real Redis persistence/restarts and S3 upload/download/delete using a non-personal fixture. Local Redis tests use the miniature test server, not a real managed Redis instance.
3. Configure bucket lifecycle to remove abandoned/failed photo objects under the configured prefix. Metadata expiration alone does not delete objects. Check bucket privacy.
4. Verify Coach summary attempt/result state survives a Render restart and that the volume is writable by the container user.
5. Deploy this branch only after configuration is complete. Require `Live`, `/readyz` 200, `/healthz` async true, correct model, Redis state and S3 storage; verify runtime logs show the worker started.
6. Test valid Firebase auth, invalid auth, paid subscription, expired/revoked/offer proofs, trial, invalid input, idempotent retry, cross-user result denial, and user-visible failures with the shipping iOS client.
7. With explicit permission for paid AI calls, run a small end-to-end canary. A 202 is acceptance, not a completed result. Confirm the result arrives on the device, record tokens/cost and p95 latency.
8. Verify alerts for failed jobs, queue age, provider 429/5xx and budget exhaustion. Save the previous deploy ID for rollback.

No new paid resources and no real OpenAI calls were made while preparing this branch.
