# Phase A Screen Audit — Presentation Contract

> Snapshot audit after `CoachPresentationNarrativeContract` (engine defers for activity-bound stories).  
> Locale: Russian · Generated from `CoachState` simulation · 2026-06-23

## Method

For each scenario we compare:

| Field | Meaning |
|-------|---------|
| **Today title** | Compressed teaser (`CoachTabPresentationResolver.resolveToday`) |
| **Coach Hero** | Coach tab headline (`resolveCoach`) |
| **Engine Hero** | `CoachFinalStory.title` |
| **defer** | `CoachPresentationNarrativeContract.defersVisibleCopyToEngine` |

**Pass criteria (Phase A):** When `defer=true`, Coach Hero must equal Engine Hero.

---

## Endurance scenarios

### Long cycling — opening (−15 min / 4 h ride)

| Surface | Copy |
|---------|------|
| Owner | `activeActivity` · defer **true** |
| Today | Не гонитесь за цифрами |
| Coach Hero | **Держите ровный ритм** |
| Engine Hero | **Держите ровный ритм** |
| Coach Rec | Углеводы каждые 20–30 минут… |

**Verdict:** ✅ Hero aligned · fueling family consistent · Today still tactical (expected).

### Long cycling — middle (−120 min)

Same as opening: Hero = «Держите ровный ритм», defer=true.

**Verdict:** ✅ No generic «качество > скорость» override.

**Note:** Story still static across middle/final hour — known Phase B gap (no chapter evolution yet).

### Long cycling — final hour (−180 min)

Same Hero/rec as middle.

**Verdict:** ✅ Contract holds · ⚠️ no narrative progression (Phase B).

### Long cycling — post immediate (+8 min after finish)

| Surface | Copy |
|---------|------|
| Owner | `postActivityRecovery` · defer **true** |
| Today | Сейчас важнее восстановление |
| Coach Hero | **Поездка позади — восстановление и еда** |
| Engine Hero | **Поездка позади — восстановление и еда** |
| Coach Rec | 25–40 г белка и 60–100 г углеводов… |

**Verdict:** ✅ Long-load magnitude visible · no «без спешки» override.

---

## Non-endurance scenarios (regression check)

### Short workout post (45 min run, just finished)

| Surface | Copy |
|---------|------|
| Owner | `postActivityRecovery` · defer **false** |
| Today | Сейчас важнее восстановление |
| Coach Hero | Сейчас можно двигаться без спешки *(interpretation layer)* |
| Engine Hero | Пробежка позади — восстановление и еда |
| Coach Rec | 5–10 минут лёгкой заминки… *(from engine)* |

**Verdict:** ⚠️ **Partial split** — Hero uses generic post-recovery pool (by design for non-significant load), but recommendation still passes engine copy. Acceptable for Phase A; optional polish: align short-post Hero with engine or genericize Rec too.

### Sauna prep (+30 min)

| Surface | Copy |
|---------|------|
| Owner | `activityPreparation` · defer **false** |
| Today | Хорошее окно для восстановления |
| Coach Hero | Хороший момент для восстановления |
| Engine Hero | Перед сауной — попейте воды |

**Verdict:** ✅ Interpretation layer still active for prep · heat/fuel theme preserved · no endurance override.

### Stable day (no activities)

| Surface | Copy |
|---------|------|
| Owner | `stableOverview` · defer **false** |
| Today | Изменений не нужно |
| Coach Hero | Сегодня можно двигаться в обычном режиме |
| Engine Hero | День идёт ровно |

**Verdict:** ✅ Calm-day interpretation unchanged · Today ≠ Coach (overlap guard intact).

---

## Summary

| Scenario | defer | Hero aligned | Unexpected regression |
|----------|-------|--------------|------------------------|
| Long ride (live) | yes | ✅ | None |
| Long ride (post) | yes | ✅ | None |
| Short post | no | N/A (interpretation) | Minor Hero/rec voice split |
| Sauna prep | no | N/A | None |
| Stable day | no | N/A | None |

**Phase A goal met:** Endurance live + long post no longer show pacing Hero over fueling/recovery body.

**Safe to proceed to Phase B design** after optional short-post polish (not blocking).
