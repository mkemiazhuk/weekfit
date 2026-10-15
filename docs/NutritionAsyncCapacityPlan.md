# WeekFit Nutrition — async production preparation

Date: 2026-10-13  
Scope: `backend/food-photo-recognize` async accept/worker path + iOS polling client.  
**Real OpenAI calls during implementation and load: 0** (`OPENAI_MOCK=1`; mock forbids network fallback).  
**Paid cloud resources: not created.** Production Render was not modified.

**This document does not certify production-ready.** Local/mock multi-process tests prove the design; staging + real provider checks below are required before launch.

Raw results:

- File-store multi-process: `backend/food-photo-recognize/async-load-results.json`
- Redis + object-store: `backend/food-photo-recognize/redis-load-results.json`

Language decision: `docs/NutritionNodeVsJavaADR.md`.  
Latency path (inline idle + faster poll): `docs/NutritionLatencyOptimizations.md`.  
Burst-100 capacity (100 parallel, long-poll): `docs/NutritionBurst100Capacity.md`.

---

## 1. Architecture

```
iOS  --POST /v1/food/photo-analyze-->  API (auth, paid JWS, validate, store JPEG, enqueue)
     <--202 { analysisId, status:queued }--

iOS  --GET  /v1/food/photo-analyze/:id-->  API (owner check)  --poll backoff-->
Workers  --claim lease-->  global AI slots  --mock/OpenAI-->  complete|fail
```

| Concern | Choice | Why (minimal) |
| --- | --- | --- |
| Job + idempotency + queue + quota + leases | **Redis** (`STATE_BACKEND=redis`) via `async/redis-backend.mjs` | Atomic claim/quota scripts; multi-API + multi-worker without shared disk. |
| Dev single-node only | File `DATA_DIR` | Forbidden when `NODE_ENV=production` + async enabled. |
| Photos | **HTTP/S3 object store** (`OBJECT_STORE=http\|s3`); queue holds **keys only** | Production forbids `OBJECT_STORE=local`. Staging: S3/R2. |
| AI concurrency | **GLOBAL_AI_SLOTS** (Redis ZSET leases) + `WORKER_LOCAL_CONCURRENCY` | Fleet-wide spend/latency control. |
| Sync path | Legacy `POST /v1/food/photo-recognize` kept | New iOS client uses **async only**. |
| Language | **Node.js** (see `NutritionNodeVsJavaADR.md`) | Bottleneck is AI slots/time, not runtime. |

### Behaviour checklist

| Requirement | Implementation |
| --- | --- |
| Reliable accept within capacity | Durable job + photo before 202; 503 + Retry-After when queue/upload full |
| Available when overloaded | Accept path does not run AI; healthz stays up |
| Survive restart/deploy | Disk jobs/queue/photos; lease recovery requeues abandoned `processing` |
| No double analysis / quota | Idempotency key + fingerprint; exclusive quota markers per `analysisId` |
| No open HTTP for full AI | 202 + polling |
| Uncertain provider outcome | Entered provider then timeout/disconnect → `uncertain`; limited retries + jitter; circuit breaker |

---

## 2. Capacity model

| Concept | Meaning | Plan |
| --- | --- | --- |
| Concurrently active users | App sessions | **1000+** |
| Inbound accept RPS | `POST /photo-analyze` | Avg **~2 RPS**; spikes to hundreds of parallel accepts |
| Concurrent AI | `GLOBAL_AI_SLOTS` | **8** default (tune 4–16) |
| Queue depth | Waiting jobs | Cap **2000–5000** |

**Burst of 1000 analyses — theoretical drain** (AI time only):

| GLOBAL_AI_SLOTS | AI 1 s | AI 5 s | AI 20 s |
| ---: | ---: | ---: | ---: |
| 4 | 250 s | 1250 s | 5000 s |
| 8 | 125 s | 625 s | 2500 s |
| 16 | 62.5 s | 312.5 s | 1250 s |

Measured complete p50 for burst_1000 @ 1 s / 8 slots ≈ **130 s** — matches theory.

---

## 3. Load results (local mock, 0 OpenAI)

### 3.1 Redis + HTTP object store (production-shaped, preferred)

Fleet: **2 API + 4 workers**, mini-Redis, HTTP object store, `GLOBAL_AI_SLOTS=8`, `OPENAI_MOCK=1`.  
Raw: `redis-load-results.json`. Quick (`REDIS_LOAD_QUICK=1`, N=100) and full (N=1000).

| Scenario | Accept | Completed | Lost | Accept p95 | Queue p95 | E2E p95 | Burst wall | Real OpenAI |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| redis_burst_1000 @ 1 s | **1000** | **1000** | **0** | 505 ms | 119 s | 120 s | **131 s** | **0** |
| redis_burst_1000 @ 5 s | **1000** | **1000** | **0** | 476 ms | 591 s | 596 s | **632 s** | **0** |
| redis_burst_1000 @ 20 s | **1000** | **1000** | **0** | 473 ms | 2362 s | 2382 s | **2504 s** | **0** |
| redis_burst_100 @ 1/5/20 s | 100×3 | 100×3 | **0** | ≤110 ms | scales | scales | 15/66/263 s | **0** |
| chaos worker+API kill | 30 | 30 | **0** | — | — | — | — | **0** |
| chaos object-store blip | 20 | 20 | **0** | — | — | — | — | **0** |
| chaos lease expire reclaim | 8 | 8 | **0** | — | — | — | — | **0** |

**Worker / slot capacity for burst of 1000** (finish wall clock; slots ≈ concurrent AI):

| AI delay | Finish ≤60 s | ≤120 s | ≤300 s | Provider note |
| ---: | ---: | ---: | ---: | --- |
| 1 s | **17** slots | 9 | 4 | Cap slots ≤ provider RPM/TPM |
| 5 s | **84** | 42 | 17 | Cost rises linearly with slots |
| 20 s | **334** | 167 | 67 | Prefer longer wait or smaller bursts |

Unit/integration: `async/redis-adapters.test.mjs` — idempotency, atomic quota (no double charge), AI slots, lease recover, multi API restart, production rejects `DATA_DIR` file backend.

### 3.2 Legacy file DATA_DIR multi-process (dev only)

Fleet: **2 API + workers**, shared temp `DATA_DIR`, `GLOBAL_AI_SLOTS=8`.

| Scenario | Accept | Completed | Lost | Accept p95 | Complete p95 | Health | Real OpenAI |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| burst_1000_delay_1s | **1000** | **1000** | **0** | 1.25 s | 245 s | 0 | **0** |
| chaos (kill worker + API, respawn API) | 40 | 40 | **0** | — | — | 0 | **0** |
| sustained **1800 s** ~2 RPS | **3589** | **3589** | **0** | 15 ms | 1.76 s | 0 | **0** |
| burst_200_delay_5s | **200** | **200** | **0** | 0.28 s | 124 s* | 0 | **0** |
| burst_200_delay_20s | **200** | **200** | **0** | 0.33 s | 485 s | 0 | **0** |
| upload 20×1 MB / 5 MB | 20/20 | — | — | 0.19 s / 0.82 s | — | 0 | **0** |
| scenario rate_limit / server_error | 202 → **failed** terminal | — | — | — | — | — | **0** |

\* Complete p95 scales with AI delay × queue waves; accept stays fast.

Unit tests: `async/async.test.mjs` — 202 accept, worker complete, idempotent quota, owner 403, lease recovery.

---

## 4. SLO proposals

| SLO | Target | Local mock |
| --- | --- | --- |
| Accept latency | p95 &lt; 2 s (≤5 MB) | **Met** (burst/upload) |
| No lost accepted jobs | 0 after worker/API kill (within lease recovery) | **Met** (chaos) |
| Sustained 30 min | Completions without lost IDs; healthz up | **Met** (3589/3589) |
| Burst 1000 | All accepted jobs complete under planned slots | **Met** @ 1 s mock |
| Idempotent retry | Same key+photo → same id; quota +1 | **Met** |
| Real provider p95 / Render Redis | — | **Not verified** |

---

## 5. Render & infra cost (assumptions only)

Blueprint: `backend/food-photo-recognize/render.yaml` (**not applied**).

Suggested staging: 2× API + 4× workers + Redis + S3/R2.

| Item | Assumption | Est. USD/mo |
| --- | --- | --- |
| 2× API standard | | $50–170 |
| 4× workers standard | | $100–340 |
| Redis | | $10–30 |
| Object storage | | $5–20 |
| **Infra total** | | **~$165–560** |

**AI cost is separate** and usually dominates — gate with `GLOBAL_AI_SLOTS`, daily user/global limits, `MAX_PROVIDER_CALLS_PER_DAY`, `MAX_ESTIMATED_USD_PER_DAY`.

Alerts: circuit open &gt; 2 m; queue &gt; 1500 for 5 m; accept p95 &gt; 3 s; 5xx &gt; 2%; daily USD &gt; 80% budget.

---

## 6. iOS

- Async accept + poll with backoff (cap 8 s)  
- Progress: uploading → queued → processing  
- `PhotoFoodPendingAnalysisStore` survives dismiss/relaunch  
- Retry reuses analysis UUID; no automatic 503 loop  
- Accept HTTP timeout 60 s; overall deadline 180 s  

---

## 7. Done vs before production

### Done in repo (mock)

- [x] Async 202 + status API + workers + leases  
- [x] **Redis adapters**: jobs, queue, idempotency, quota, AI slots, circuit, budget  
- [x] **HTTP/S3 object-store adapters**; production rejects shared `DATA_DIR` / local photos  
- [x] Atomicity tests: no lost accepted jobs, no double quota, AI slot cap  
- [x] Redis load: 1000 @ 1/5/20 s (0 lost); chaos: worker/API kill, object-store blip, lease reclaim  
- [x] Paid check before accept; limited retry; circuit; uncertain outcome  
- [x] Owner check; graceful worker shutdown  
- [x] File-store load (dev): burst 1000, delays 5/20 s, chaos, sustained 30 min  
- [x] iOS async client + progress + pending store  
- [x] Node vs Java ADR (stay on Node)  
- [x] Render blueprint + this capacity plan  
- [x] **Real OpenAI = 0**

### Required on staging before launch

1. Provision **managed Redis + S3/R2**; set `STATE_BACKEND=redis`, `REDIS_URL`, `OBJECT_STORE=s3`.  
2. Deploy API+workers to **staging only**; confirm `/healthz` shows `asyncAnalysis`, `stateBackend=redis`, `objectStore`.  
3. Mock load against staging multi-instance (`npm run test:load:redis`).  
4. Tiny real OpenAI canary with hard USD/QPS caps; tune `GLOBAL_AI_SLOTS`.  
5. Device E2E: StoreKit JWS + Firebase + resume after kill.  
6. Photo TTL + log redaction audit.  
7. Game-day: deploy mid-burst, kill worker, brief Redis/object-store outage.  

**Do not call the system production-ready until the staging checklist passes.**

---

## 8. Local commands

```bash
cd backend/food-photo-recognize
# Redis-shaped local (mini-Redis + HTTP object store inside the harness):
npm run test:load:redis:quick
npm run test:load:redis
node --test async/redis-adapters.test.mjs

# Dev file DATA_DIR path (not for production):
npm run start:async:mock   # terminal 1
npm run worker:mock        # terminal 2
npm run test:load:async:quick
```

Never `OPENAI_MOCK=1` with `NODE_ENV=production`. Never load-test production.
