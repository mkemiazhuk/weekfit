# Nutrition burst-100 validation

Implementation baseline: `95997a6`. Local mock only; no production mutation, paid resources or real OpenAI calls.

## Changes

- Independent execution lanes keep idle worker capacity available while other analyses run.
- Blocking Redis queue waits use separate connections, so they cannot block heartbeats and normal state operations. `rediss://` now selects a TLS connection.
- API and workers share an atomic Redis rolling RPM/estimated-TPM admission window. Acquire concurrency before consuming a rate reservation. Production Redis mode refuses unknown/zero provider limits.
- No automatic retry after entering a provider call with an uncertain outcome. Provider denial uses bounded pacing instead of hot requeue loops.
- Long-poll waits clean up their listeners every slice rather than leaving losing Promise.race listeners alive.
- The harness measures elapsed time from client submission through receipt of the terminal response, not job creation or the start of polling. Sustained clients start waiting immediately after acceptance.
- Burst fixtures are 450,000-byte synthetic JPEGs. The test-only child-process probe records RSS and CPU; production entrypoints do not import it.

## Reproduce without provider calls

```
cd backend/food-photo-recognize
npm test
npm run test:burst100
```

The harness starts two API processes and four workers (25 lanes each), with 100 shared AI slots, mini-Redis and an HTTP object-store test double. It never calls a real AI provider. `burst-100-results.json` contains raw metrics. The sample `.env.capacity-mock.example` is for isolated mock endpoints only.

## Capacity and production settings

100 free slots satisfy the idle burst of 100 requests in the mock. They do not guarantee the same result when those slots are already occupied. At 2 analyses/sec and 20-second mean provider time, ordinary load needs approximately 40 occupied slots; a simultaneous burst needs capacity in addition to that, plus headroom.

A burst of 100 needs at least 100 request admissions in the provider window and tokens for 100 inputs plus reserved outputs. At the test estimate of 4,000 tokens/call that is 400,000 estimated tokens. Sustained 2 RPS requires at least 120 RPM and 480,000 estimated TPM, with additional burst allowance and headroom. These are arithmetic requirements, not confirmed account limits. Token estimation must be calibrated against the actual model/image accounting.

Prepare at least two API instances and four pre-warmed workers for the tested profile. Select instance memory from measured peak RSS plus safety headroom and repeat on staging; local process metrics do not prove Render performance. Real endpoint latency, real provider limits, TLS/Auth and Redis Lua execution remain staging checks.

No production values were raised to 100, no Render service was deployed, and `ALLOW_SINGLE_NODE_ASYNC` was not enabled. Single-node file mode does not validate distributed capacity.

## Important limits and unresolved readiness gaps

- mini-Redis emulates Lua and has no persistent disk. Passing these tests does not prove real Lua execution, Redis persistence/failover, or S3 integration.
- Queue pop and recovery-index lease reservation are now atomic. Job creation/enqueue are still separate operations; a crash before enqueue can strand a job and a replay can return a queued status without repairing the enqueue. Atomic acceptance/replay repair remains a production blocker.
- Existing completion/failure fencing uses read/check/write rather than an atomic compare-and-set. Stale-owner race safety remains unproven.
- Existing Redis daily budget is read/modify/write; concurrent attempts can undercount. The new RPM/TPM limiter does not fix that daily budget race.
- Inline mode does not index/renew its lease through the worker recovery mechanism. The distributed benchmark deliberately disables inline mode. It must remain disabled until recovery and uncertain-outcome handling are fixed.
- The current checkout has no iOS async HTTP client or the reported sync fallback. Device compression, long-poll/resume and UI timing cannot be verified or modified here.
- The 1000-active-users scenario is an RPS proxy (1000 users × 0.12 analyses/min = 2 RPS), not a simulation of 1000 distinct authenticated device sessions.
- Slow-upload tests, Redis outage/restart, real object-store outages and deployment during a burst require additional validation; this PR does not claim they passed.

Consequently this is a draft for review, not a production-readiness certificate. Real OpenAI requests performed by this task: **0**.

## Observed failure during verification

The initial 450 KB suite passed the three speed bursts and the 2 RPS sustained proxy, but its worker/API kill phase timed out waiting for one of 20 accepted jobs (`chaos lost 1`). This is not a successful chaos run. It exposed the pop-before-lease recovery gap; the new atomic pop/lease reservation and a targeted crash-gap regression test address that specific window. Other atomicity gaps above remain.

## Final mock results after the claim fix

67/67 unit tests passed. Burst fixtures: 450 KB; 2 API processes + 4 workers × 25 lanes; 100 shared slots.

| AI delay | Accepted/completed | Queue p95 | Client E2E p95 | Errors / timeouts |
|---|---:|---:|---:|---:|
| 5s | 100/100 | 167ms | 5.92s | 0 / 0 |
| 10s | 100/100 | 77ms | 10.75s | 0 / 0 |
| 20s | 100/100 | 80ms | 20.87s | 0 / 0 |

Over-capacity burst: 200 accepted, 200 completed; queue p95 5.20s, E2E p95 10.97s. The ≤1s queue objective is NOT met above the 100-slot capacity.

Final sampled worker/API kill: 20 accepted, 20 completed, 0 timeouts. This passes the sampled test, not all crash windows.

The final run skipped the sustained proxy to retest changed claim semantics promptly. The separate quick run after the fix passed its 1 RPS proxy and kill phase. The earlier 2 RPS/60s run passed 121/121 analyses with 500ms mock AI; it is not a 20-second-provider sustained test.

Raw final measurements: `../backend/food-photo-recognize/burst-100-final-results.json`. CPU is expressed as percent of one core; RSS samples are taken every 500ms and are process peaks to date, not hard memory bounds.
