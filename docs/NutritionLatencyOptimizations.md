# Nutrition photo → result latency optimizations

Date: 2026-10-13  
**Mock only (`OPENAI_MOCK=1`). Real OpenAI calls: 0.**  
Do **not** treat mock e2e as confirmed real-provider speed. Production unchanged.

Raw: `backend/food-photo-recognize/latency-opt-results.json`.

---

## What changed

| Area | Change |
| --- | --- |
| Idle path | **Inline fast-path**: if queue empty + AI slot free → analyze in accept, return **200 + result** (no poll, no queue wait). One AI call. |
| Busy path | Unchanged durable **202 + queue + workers** when slots full / `INLINE_FAST_PATH=0` |
| Upload gate | Released **before** AI (inline or queue) so uploads are not blocked by provider time |
| Prompt | Shorter instructions; `effort` default **medium**; `image detail` **auto**; `max_output_tokens` 2500 |
| HTTP | Keep-alive HTTPS agent for OpenAI; iOS `URLSession` connection reuse |
| Worker | Parallel circuit+budget; soft requeue without sleep; idle poll ~10 ms; lease sweep ≤1/s |
| iOS | JPEG ≤1536px, target ≤450 KB; auth∥subscription; no healthz warm-up; poll 150–1500 ms (was up to 8 s); inline 200 skips poll |
| Idempotency | Same analysis ID → completed result replay, **no** new AI / quota |

---

## Measured (mock AI delay = 120 ms)

### Idle (30 sequential)

| Stage | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Accept / e2e | **129 ms** | 139 ms | 141 ms |
| Queue wait | **0** | 0 | 0 |
| AI (mock) | 124 ms | 128 ms | 128 s |
| Poll gap | **0** | 0 | 0 |

All **30/30 inline**. Overhead beyond mock AI ≈ **5–20 ms**.

### Peak (40 concurrent, 4 slots)

| Stage | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Accept | 55 ms | 65 ms | 167 ms |
| Queue wait | 563 ms | 1207 ms | 1211 ms |
| AI (mock) | 126 ms | 130 ms | 134 ms |
| Poll gap | 209 ms | 433 ms | 480 ms |
| Client e2e | 931 ms | 1767 ms | 1768 ms |

Modes: 1 inline / 39 queued. Burst wall ≈ **1.8 s**.

---

## Eliminated vs provider-bound

**Eliminated / reduced (our stack):** queue wait when idle; long poll backoff; upload-gate holding AI; healthz warm-up; sequential auth+JWS; oversized JPEG; soft-requeue sleeps; verbose prompt / high effort default.

**Still provider-bound (real OpenAI):** model inference time, TPM/RPM, network to OpenAI. Under load, **queue wait ≈ f(N, slots, AI_ms)** remains.

---

## Commands

```bash
cd backend/food-photo-recognize
npm test
npm run test:latency:opt
```

Not production-ready until staging + real provider canary.
