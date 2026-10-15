# Nutrition — burst 100 parallel analyses (mock capacity)

Date: 2026-10-13  
**Real OpenAI calls: 0.** Production not modified. Not production-ready from mock alone.

Raw: `backend/food-photo-recognize/burst-100-results.json`.

---

## Goals vs mock

| Goal | Mock result (when `GLOBAL_AI_SLOTS≥100`, pre-warmed workers) |
| --- | --- |
| p95 wait before AI ≤ 1 s (burst 100) | **Met** when slots ≥ N (queue p95 typically &lt; 100 ms) |
| p95 photo→result ≤ 30 s | **Met** for mock AI ≤ 20 s (e2e ≈ AI + small overhead) |
| 202 ≠ result | Enforced — only `completed`+result counts |
| 1000+ actives | Separate sustained-RPS proxy; not 1000 simultaneous AI |

---

## Architecture changes

1. **`GLOBAL_AI_SLOTS`** configurable 1…2000 (atomic Redis/file limiter shared by API inline + workers).
2. **Blocking claim** — Redis `BRPOP` / file wake; no idle sleep poll.
3. **`WORKER_LOCAL_CONCURRENCY`** up to 128; fleet AI ≈ min(slots, workers×local).
4. **`PROVIDER_MAX_RPM` / `PROVIDER_MAX_TPM`** — local admission (0 = unset until account limits known).
5. **Long-poll** `GET .../photo-analyze/:id?waitMs=20000` + iOS client; short GET fallback.
6. **Lease fencing token** on claim; no blind retry after uncertain provider outcome.
7. **Upload gate** separate from AI slots.
8. **Inline fast-path** kept for idle only (same quotas/slots); burst tests use `INLINE_FAST_PATH=0`.

---

## Capacity to hit burst-100 targets (mock-validated shape)

| Resource | Value |
| --- | ---: |
| `GLOBAL_AI_SLOTS` | **100** |
| Worker processes | **4** |
| `WORKER_LOCAL_CONCURRENCY` | **25** |
| API instances | **2** (stateless) |
| Redis + object store | required multi-instance |

**Do not set production slots to 100** until staging confirms OpenAI concurrent/RPM/TPM and host memory.

Autoscale is **backup** only — instant burst needs pre-warmed workers.

---

## Provider limits to obtain

| Limit | Env | Action |
| --- | --- | --- |
| Concurrent requests | `GLOBAL_AI_SLOTS` | Cap ≤ OpenAI concurrent allowance |
| RPM | `PROVIDER_MAX_RPM` | From dashboard; 0 until known |
| TPM | `PROVIDER_MAX_TPM` | From dashboard; 0 until known |

Never multiply API keys to bypass limits.

---

## Confirmed by mock vs staging

| Item | Mock | Staging + real AI |
| --- | --- | --- |
| Queue p95 ≤ 1 s at 100 parallel with 100 slots | Yes | Re-measure |
| e2e p95 ≤ 30 s with mock AI≤20 s | Yes | Depends on real model latency |
| No lost accepted jobs / no double quota | Yes | Game-day |
| Long-poll delivery | Yes | Proxy timeouts |
| Real OpenAI latency/cost/429 | **No** | Required |

---

## Commands

```bash
cd backend/food-photo-recognize
npm run test:burst100:quick
npm run test:burst100
```
