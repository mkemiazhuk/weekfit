# ADR: Node.js vs Java for Nutrition async photo analysis

Date: 2026-10-13  
Status: **Stay on Node.js** for the async API + workers until staging proves otherwise.  
Scope: `backend/food-photo-recognize` (accept/queue/workers/quotas).  
Constraint: decisions based on measured bottlenecks with Redis adapters + mock OpenAI only. **Not production-ready** until staging + real provider.

---

## 1. Measured bottlenecks (Redis + HTTP object store, mock AI)

Fleet under test: 2 API + 4 workers, `GLOBAL_AI_SLOTS=8`, mini-Redis, HTTP object store, `OPENAI_MOCK=1`.

| What dominates wait | Evidence (1000 jobs, 8 slots, Redis) |
| --- | --- |
| **AI provider time** | AI p50 ≈ 1.003 s / 5.006 s / 20.006 s |
| **Global AI slot cap** | Burst wall 131 s / 632 s / **2504 s** ≈ theory 125 / 625 / 2500 s |
| **Accept path** | Accept p95 **~0.5 s** — not the limiter |
| **Queue wait** | Queue p95 119 s / 591 s / **2362 s** — slot backlog, not Redis lag |

**Conclusion:** Latency and cost are governed by **provider concurrency + duration**, not by Node event-loop CPU. Java would not change the drain formula `T ≈ N × AI / GLOBAL_AI_SLOTS`.

---

## 2. What Java would / would not solve

| Problem | Java helps? | Notes |
| --- | --- | --- |
| Predictable queue wait under burst | No (same math) | Need more slots / more provider quota |
| Uncontrolled AI spend | No | Already gated: slots, daily quotas, budget, circuit |
| Multi-instance shared state | No (already Redis) | Atomic claim/quota via Redis scripts |
| Lost jobs after crash | No | Lease recovery already proven in tests |
| CPU-heavy image prep at scale | Maybe later | Current path stores JPEG bytes; prep is light |
| Strict typed runtime / hiring | Organizational | Not a measured reliability gap |
| Virtual threads for many blocking HTTP calls | Marginal | Workers already async I/O; bottleneck is OpenAI |

Java is **not justified** as a rewrite to meet 1000+ active-user SLOs given these measurements.

---

## 3. Migration cost (if revisited)

| Item | Estimate |
| --- | --- |
| Port API contract (auth, 202, poll, errors) | 2–4 weeks |
| Redis + object-store adapters + lease/quota parity | 2–3 weeks |
| Test/load parity + chaos | 1–2 weeks |
| Ops (build, deploy, metrics, dual-run) | 1–2 weeks |
| **Total** | **~6–11 weeks** + dual-stack support risk |

Ongoing: two languages in WeekFit backend increases review surface and on-call complexity.

---

## 4. When to prototype Java

Only if staging shows **Node-specific** failure modes, e.g.:

- Accept p95 &gt; SLO under multi-MB uploads with Redis healthy (CPU/event-loop saturation).
- Memory leaks / GC pauses under sustained multi-hour load that Java + bounded pools fix cheaper than Node fixes.
- Team mandate for JVM platform with equal resources A/B.

**Prototype rules (if approved):** same HTTP contract; same Redis key layout; same mock OpenAI; same machine size; compare accept/queue/e2e + chaos. Do **not** create paid resources or change production for the prototype.

---

## 5. Decision

1. **Keep Node.js** for Nutrition async path.
2. Scale with **`GLOBAL_AI_SLOTS` + workers ≥ slots**, Redis, object store — not a language rewrite.
3. Revisit Java only after staging metrics contradict §1.

See also: `NutritionAsyncCapacityPlan.md`, `redis-load-results.json`.
