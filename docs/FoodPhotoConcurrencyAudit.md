# Food Photo / Nutrition service — concurrency audit (extended)

Date: 2026-10-13  
Scope: `backend/food-photo-recognize` photo-recognize path + iOS overload/idempotency client behaviour.  
**Constraint honored: 0 real OpenAI API calls** (`OPENAI_MOCK=1`; mock fetcher forbids non-OpenAI URLs / real network).  
Raw machine output: `backend/food-photo-recognize/extended-load-results.json`.

**Production readiness:** **not claimed.** Render multi-instance behaviour and the real vision provider (latency, TPM, 429s, cost) remain unverified.

**Follow-up (distributed state):** Redis + HTTP object-store adapters, load `1000 @ 1/5/20 s`, and Node-vs-Java ADR are in `docs/NutritionAsyncCapacityPlan.md`, `docs/NutritionNodeVsJavaADR.md`, and `backend/food-photo-recognize/redis-load-results.json` (still mock OpenAI only; still not production-ready).

---

## 1. What changed since the ~40 ms mock pass

| Area | Change |
| --- | --- |
| AI slot | Still acquired **after** body read/validate (unchanged). |
| Upload gate | Separate `MAX_CONCURRENT_UPLOADS` (default 8) + upload queue so multi‑MB bodies cannot pin AI slots or grow RSS without bound. |
| Body read | `BODY_READ_TIMEOUT_MS` (default 30 s); size cap 12 MiB JSON. |
| Idempotency | SHA-256 fingerprint of `imageBase64`; same key + different photo → **409** `idempotency_key_reuse`. |
| Shared abort | One client cancel decrements waiters; shared AI aborts only when the **last** waiter leaves. Failures clear the key (no stuck in-progress). |
| Latency headers | `X-WeekFit-Queue-Wait-Ms`, `X-WeekFit-AI-Ms`, `X-WeekFit-E2E-Ms`, `X-WeekFit-Idempotent-Hit`. |
| Timeouts | Documented distinction: Node `requestTimeout` ≠ full AI e2e (see §5). |
| iOS | Sends `Idempotency-Key` / `X-WeekFit-Analysis-Id`; user Retry reuses analysis ID; 503 ends loading with busy copy; **no automatic retry loop**; Retry-After logged. |

---

## 2. Burst matrix — AI delay 1 / 5 / 20 s × concurrency 4…100

Config: `MAX_CONCURRENT_SCANS=4`, `MAX_AI_QUEUE=16`, `AI_QUEUE_WAIT_MS=8000`.  
Latencies below are **split**: successful requests vs fast 503 rejects (do not mix them for capacity claims).

### 2.1 Mock AI delay = 1 s

| C | OK | 503 | Success e2e p50 | Queue p50 | AI p50 | Reject e2e p50 | AI peak | Real OpenAI |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 4 | 0 | 1025 | 0 | 1002 | — | 4 | **0** |
| 10 | 10 | 0 | 2008 | 1000 | 1001 | — | 4 | **0** |
| 25 | 20 | 5 | 3009 | 2000 | 1001 | 8 ms | 4 | **0** |
| 50 | 20 | 30 | 3022 | 2001 | 1001 | 32 ms | 4 | **0** |
| 100 | 20 | 80 | 3030 | 2000 | 1001 | 36 ms | 4 | **0** |

Accepted work ≈ `active + queue` = **20** when the burst exceeds capacity; surplus sheds in tens of ms with `Retry-After`.

### 2.2 Mock AI delay = 5 s

| C | OK | 503 | Success e2e p50 | Queue p50 | AI p50 | Reject e2e p50 | AI peak | Real OpenAI |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 4 | 0 | 5007 | 0 | 5001 | — | 4 | **0** |
| 10 | 8 | 2 | 5015 | 0 | 5003 | ~8011 ms (queue wait timeout) | 4 | **0** |
| 25 | 8 | 17 | 5010 | 0 | 5001 | ~8009 ms / fast shed | 4 | **0** |
| 50 | 8 | 42 | 5020 | 0 | 5001 | ~26 ms (queue full) | 4 | **0** |
| 100 | 8 | 92 | 5038 | 0 | 5004 | ~48 ms | 4 | **0** |

With AI=5 s and queue wait=8 s, waiters that miss the first free wave often hit **queue timeout** (~8 s) rather than completing — capacity is “4 concurrent + short queue”, not “16 deep FIFO of full AI jobs”.

### 2.3 Mock AI delay = 20 s

| C | OK | 503 | Success e2e p50 | AI p50 | Reject e2e p50 | AI peak | Real OpenAI |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 4 | 0 | 20008 | 20001 | — | 4 | **0** |
| 10 | 4 | 6 | 20007 | 20001 | ~8008 ms | 4 | **0** |
| 25 | 4 | 21 | 20011 | 20002 | ~8017 ms | 4 | **0** |
| 50 | 4 | 46 | 20026 | 20003 | ~27 ms | 4 | **0** |
| 100 | 4 | 96 | 20027 | 20002 | ~39 ms | 4 | **0** |

When AI duration ≫ `AI_QUEUE_WAIT_MS`, the queue does **not** increase throughput — only the 4 in-flight succeed; everyone else gets 503 (queue timeout or queue full). That is intentional backpressure, not a bug.

`/healthz` stayed **200** on all burst probes. Peak mock AI parallelism never exceeded **4**.

---

## 3. Sustained load (≥ 5 minutes)

| Metric | Result |
| --- | --- |
| Duration | **300.9 s** (~5 min) |
| Driver rate | ~2 RPS (interval 500 ms), mock AI = 1 s, conc=4 |
| Requests | 599 |
| OK / 503 | **599 / 0** |
| Success e2e p50 / p95 / p99 | 1004 / 1008 / 1012 ms |
| Queue p50 | 0 ms |
| AI p50 | 1001 ms |
| AI peak | 3 |
| Health probes | 300, **0 failures** |
| RSS / heap max | 83.4 MB / 21 MB |
| Real OpenAI | **0** |

At ~2 RPS with AI=1 s, theoretical ceiling ≈ 4 RPS — sustained run stayed well under saturation with empty queues.

---

## 4. Photo upload stress (slow parallel)

Separate upload gate: `MAX_CONCURRENT_UPLOADS=4` for this suite (prod default 8). Six slow chunked uploads in parallel; bodies ~1 / ~7 / ~11 MB JSON (JPEG 1 / 5 / ~8 MiB).

| Payload | OK | 503 (upload busy) | Wall ms | RSS before → max | Health fail | AI peak | Real OpenAI |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| JPEG 1 MB | 6 | 0 | 1015 | 58 → 135 MB | 0 | 4 | **0** |
| JPEG 5 MB | 4 | 2 | 3421 | 135 → 265 MB | 0 | 4 | **0** |
| JPEG ~8 MB (body ~12 MB) | 4 | 2 | 5334 | 268 → 398 MB | 0 | 4 | **0** |

Upload gate shed excess readers (**503** + `Retry-After`) while four bodies completed; RSS grew with concurrent large bodies but **did not** run away unboundedly under the gate. `/healthz` remained responsive.

---

## 5. Timeouts (server ↔ iOS)

| Budget | Value | Meaning |
| --- | ---: | --- |
| Body read | 30 000 ms | Wall clock while reading JSON (`BODY_READ_TIMEOUT_MS`). |
| Upload queue wait | 2 000 ms (default) | Wait for an upload slot. |
| AI queue wait | 8 000 ms | Wait for an AI slot; then 503. |
| OpenAI / mock AI | 90 000 ms | `OPENAI_TIMEOUT_MS` — abortSignal around provider call. |
| Node `server.requestTimeout` | **120 000 ms** (`max(120s, timeoutMs+30s)`) | Incomplete / idle **HTTP request** budget on the socket. **Not** “AI finished within N ms”. Raising it prevents Node from killing a still-legal in-flight provider call that was previously cut off at 30 s. |
| Headers timeout | 15 000 ms | Time to receive request headers. |
| iOS overall deadline | **105 s** | Task-group wall clock in `PhotoFoodRecognitionClient`. |
| iOS `URLRequest.timeoutInterval` | 105 s | Waiting for the **next response chunk**, not a separate “full pipeline” timer. The true e2e cap is the 105 s task group, set **above** the 90 s server AI budget + upload margin. |

**What was fixed earlier:** treating `requestTimeout=30s` as if it covered whole recognition. It does not — and must stay ≥ AI timeout so the HTTP server does not abort work the AI budget still allows.

---

## 6. Idempotency, cancel, process-local limits

| Check | Result |
| --- | --- |
| Replay after success, same key + same photo | Cached **200**, **no** second AI call (`X-WeekFit-Idempotent-Hit: 1`). |
| Same key + different photo | **409** `idempotency_key_reuse`. |
| Cancel one of two shared waiters | Sibling completes; **1** AI call. |
| Provider error | Key **cleared** (not stuck in-progress); retry can run again. |
| Process restart | Cache/in-flight state **gone** — new AI call for same key. |

**Process-local storage limitations (explicit):**

- Idempotency map, daily counters, AI/upload gates live in **one Node process memory**.
- **Not** shared across Render replicas → N instances ≈ N× capacity and N× independent idempotency caches.
- **Lost on deploy/restart** → clients may pay a second AI call after restart even with the same analysis ID (acceptable; prefer one instance until a shared store exists).
- Multi-instance sticky routing does **not** fix cross-replica duplicate keys.

---

## 7. iOS client under overload

| Behaviour | Status |
| --- | --- |
| Clear message | `today.photoLog.error.unavailable` — busy / wait / tap Retry; no auto-loop wording. |
| Loading ends | 503 maps to `.unavailable` → coordinator `phase = .error` (loading stops). |
| Same analysis ID on Retry | `retryAnalysis()` passes `reuseAnalysisId: lastAnalysisId`; client sends `Idempotency-Key` + `X-WeekFit-Analysis-Id`. |
| Retry-After | Parsed/logged (`serverBusyRetryAfter`); **not** used to spin an automatic retry loop. |
| Auto retries | Only a **single** forced auth refresh on 401; timeouts/network/503 are **not** auto-retried. |

---

## 8. Why concurrency = 4 and queue ≈ 16

Evidence from this mock suite (not from Render/OpenAI):

1. **Cost / product posture** — flagship vision model; 4 parallel analyses per process is a deliberate spend ceiling.
2. **Delay scaling** — at AI=1 s, ~4 RPS theoretical; sustained 2 RPS for 5 min was clean. At AI=5–20 s, throughput collapses to ~4 / delay; raising concurrency without measuring real $ and TPM is unjustified.
3. **Queue role** — `MAX_AI_QUEUE=16` absorbs short bursts when AI is fast (1 s matrix accepted 20). When AI ≫ `AI_QUEUE_WAIT_MS` (20 s), queue waiters time out → clients get Retry-After instead of multi-minute hangs. Keep queue for spikes; do not treat it as deep FIFO of 20 s jobs.
4. **Upload gate** — keeps memory bounded when bodies are multi‑MB; AI slots stay reserved for validated work.
5. **Still unknown** — real OpenAI latency distribution, Render CPU/RAM under concurrent ~12 MB JSON, multi-replica races.

**Recommendation:** keep `MAX_CONCURRENT_SCANS=4`, `MAX_AI_QUEUE≈16`, `AI_QUEUE_WAIT_MS≈8000`, `MAX_CONCURRENT_UPLOADS≈8` on a **single** instance until staging with a real key + Render metrics says otherwise.

---

## 9. Limits of verification

| Verified locally (mock) | Not verified |
| --- | --- |
| Backpressure, upload gate, fingerprint idempotency, shared cancel, timeout wiring, 5 min sustained, large slow uploads, healthz under load | Real OpenAI QPS / TPM / 429 / $ |
| Peak AI parallelism ≤ 4 | Render instance size, multi-replica |
| Zero OpenAI network calls in all suites above | Production deploy config |

**Confirmation: real OpenAI requests during this extended audit = 0.**

---

## 10. How to re-run

```bash
cd backend/food-photo-recognize
npm test                          # unit + concurrency (mock)
npm run test:load                 # short burst table (~40 ms mock)
npm run test:load:extended        # full matrix + 5 min sustained (slow)
# partial re-run example:
EXTENDED_LOAD_PHASES=upload,idempotency,timeouts npm run test:load:extended
```

Never set `OPENAI_MOCK=1` with `NODE_ENV=production`. Never point these load scripts at the production Render URL.
