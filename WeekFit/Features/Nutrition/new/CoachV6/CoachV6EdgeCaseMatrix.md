# CoachV6 Edge Case Matrix — Ownership Conflicts

> Not activity catalog. This matrix tracks **who owns the primary story** when signals compete.  
> Pipeline: `focus → sessionPhase → scenarioKey → modifiers (nutrition / stacked) → presentation overlay`

## Ownership vocabulary

| Owner | Meaning |
|-------|---------|
| `day.idle` | No focused activity — `morningReadiness` or `stableDay` |
| `session.activity` | Focus activity drives family + phase → scenario |
| `day.tomorrowProtection` | Heavy day + tomorrow demand + evening window — **replaces** completed-activity evening story |
| `overlay.stackedRisk` | Modifier on live training — **does not** change scenario key; overrides Today badge/title/copy |
| `overlay.nutrition` | `fuelBehind` / `hydrationBehind` / `safetyAlert` — **never** changes scenario (G1) |
| `day.readinessProtection` | Good recovery + hard/moderate tomorrow on idle morning/midday — `protectTomorrowFresh` |

## Priority rules (fixed)

```
1. Explicit focusActivity (if passed) > auto focus (active > recent completed ≤180m > next upcoming)
2. Active session on calendar > last completed > upcoming
3. tomorrowProtection context replaces completed-focus when: heavy day + tomorrow moderate/hard + afternoon/evening + no upcoming training today
4. protectTomorrowFresh: idle morning/midday + good recovery + no serious work today + tomorrow moderate/hard — does not override live/pre-session
5. lowRecoveryPrep: pre-session serious training + low recovery/sleep — shifts active* prep to protective story
6. recoveryAfterHeavyYesterday: idle + heavy yesterday + low recovery/sleep + fresh today
7. Live during* always wins — recovery/yesterday only in support/warning layers
8. stackedDayActiveRisk: modifier after scenario — pre/during serious training on heavy day + tomorrow demand
9. nutrition: modifiers + safetyAlert only — scenario unchanged
10. morningReadiness: nutrition signals suppressed in copy — no food/water at wake-up
```

---

## Matrix (13 required cases)

### 1. Morning → Active transition

| Step | Time | Focus | Expected owner | Expected scenario | Badge | Today title | Conflict |
|------|------|-------|----------------|-------------------|-------|-------------|----------|
| A | 07:30 | none | `day.idle` | `morningReadiness` | ВСЁ ХОРОШО | С чего начать | — |
| B | 08:00 | upcoming ride (+45m) | `session.activity` | `activeEndurance` | СЕЙЧАС ВАЖНО | Готовимся к заезду | Day idle **yields** once calendar focus exists |

**Conflict note:** Brain/hour alone does not flip scenario — **planned activity** must appear in focus chain.

---

### 2. Active → Post transition

| Step | Time | Focus | Expected owner | Expected scenario | Badge | Today title | Conflict |
|------|------|-------|----------------|-------------------|-------|-------------|----------|
| A | 14:00 | active ride (−30m) | `session.activity` | `duringEndurance` | СЕЙЧАС | На заезде | — |
| B | 14:15 | ride ended ~15m ago (**completed**) | `session.activity` | `postEnduranceImmediate` | СЕЙЧАС ВАЖНО | Заезд завершён | Phase from `minutesSinceEnd ≤ 60`; needs `isCompleted` |

**Conflict note:** Post window is **60 min** — not calendar “afternoon”.

---

### 3. Post → Evening transition

| Step | Time | Focus | Expected owner | Expected scenario | Badge | Today title | Conflict |
|------|------|-------|----------------|-------------------|-------|-------------|----------|
| A | 21:30 | completed ride (ended ~2h ago) | `session.activity` | `eveningAfterEndurance` | БЕРЕЖЁМ СИЛЫ | Вечер после нагрузки | Evening phase only when `finished` + evening time |
| B | 21:30 | same ride ended ~20m ago | `session.activity` | `postEnduranceImmediate` | СЕЙЧАС ВАЖНО | Заезд завершён | **Evening clock loses** to immediatePost window |

**Conflict note:** Same clock time, different owner — depends on `minutesSinceEnd`.

---

### 4. Evening → TomorrowProtection transition

| Step | Time | Focus | Expected owner | Expected scenario | Badge | Today title | Conflict |
|------|------|-------|----------------|-------------------|-------|-------------|----------|
| A | 21:30 | completed heavy ride, tomorrow hard | `day.tomorrowProtection` | `tomorrowProtection` | БЕРЕЖЁМ СИЛЫ | Сегодня уже достаточно | Protection **beats** `eveningAfter*` on completed focus |
| B | 20:15 | completed heavy ride + upcoming evening workout today | `session.activity` | `eveningAfterEndurance` | БЕРЕЖЁМ СИЛЫ | Вечер после нагрузки | Upcoming today **blocks** protection override on completed focus |
| B′ | 20:15 | same day, auto-focus (no explicit focus) | `session.activity+overlay.stackedRisk` | `activeStrength` | ВНИМАНИЕ | Нагрузка на пределе | Auto-focus picks upcoming core; **stacked overlay** on pre-session heavy day |

**Conflict note:** Focus on completed vs auto-focus without override — protection requires `shouldPreferTomorrowProtectionOverCompletedFocus`.

---

### 5. Multiple activities same day

| Situation | Focus rule | Expected owner | Expected scenario | Badge | Today title | Conflict |
|-----------|------------|----------------|-------------------|-------|-------------|----------|
| Completed ride + **active** strength | active wins | `session.activity` | `duringStrength` | СЕЙЧАС | Силовая идёт | Completed story **paused** while live |
| Completed ride + upcoming tennis (+30m) | upcoming if no active | `session.activity` | `activeRacket` | СЕЙЧАС ВАЖНО | Игра скоро | Recent completed ignored if outside active |

**Conflict note:** Only one primary story — no multi-activity split in V6.

---

### 6. Active session + hydration risk

| Layer | Expected |
|-------|----------|
| Owner | `session.activity` → `duringEndurance` |
| Scenario | unchanged |
| Modifier | `hydrationBehind: true` → `alertSeverity: .elevated` |
| Safety | `hydrationCritical` → `safetyAlert`, badge **ВАЖНО** |
| Today title | На заезде (session chrome) |

**Conflict note:** Hydration must stay out of assessment main story (G1) — only supporting/warning layers.

---

### 7. Active session + nutrition (fuel) risk

| Layer | Expected |
|-------|----------|
| Owner | `session.activity` |
| Behind | `fuelBehind` → elevated severity, scenario unchanged |
| Critical | `fuelCritical` on **long/extended** (≥60m) endurance when calories &lt; 30% goal → `safetyAlert`, badge **ВАЖНО** |
| Today title | session title (not nutrition-led) |

**Conflict note:** Matrix row uses 59m ride to isolate the fuel-**behind** path; ≥60m + very low fuel crosses into `fuelCritical`.

---

### 8. Active session + stacked day risk

| Layer | Expected |
|-------|----------|
| Scenario key | `duringStrength` / `duringEndurance` (unchanged) |
| Owner | `session.activity` + **`overlay.stackedRisk`** |
| Badge | **ВНИМАНИЕ** |
| Today title | **Нагрузка на пределе** (overrides session title) |
| Color | `.risk` not `.live` |

**Conflict note:** Copy pack replaced via modifier — scenario key still `during*`.

---

### 9. Recovery + yesterday load (Phase 2)

| Case | Signals | Expected owner | Scenario | Badge | Today title | Conflict |
|------|---------|----------------|----------|-------|-------------|----------|
| 9A | recovery 90%, tomorrow hard, idle morning | `day.readinessProtection` | `protectTomorrowFresh` | БЕРЕЖЁМ СИЛЫ | Сохраните запас на зав… | Good recovery + hard tomorrow — protect reserve, not empty morning |
| 9B | recovery 35%, upcoming ride +1h | `session.activity` | `lowRecoveryPrep` | БЕРЕЖЁМ СИЛЫ | Проверьте готовность | Low recovery shifts pre-session to protective prep |
| 9C | sleep 4.5h, live ride | `session.activity` | `duringEndurance` | СЕЙЧАС | На заезде | Live session wins — low recovery in support only |
| 9D | recovery 90%, brain past high load | `day.idle` | `morningReadiness` | ВСЁ ХОРОШО | С чего начать | Heavy yesterday + good recovery — calm morning + support |

---

### 10. (merged into §9)

---

### 11. Empty day (no activity / no food / no water)

| Time | Nutrition | Expected owner | Scenario | Badge | Today title | Conflict |
|------|-----------|----------------|----------|-------|-------------|----------|
| 07:30 | empty | `day.idle` | `morningReadiness` | ВСЁ ХОРОШО | С чего начать | **No nutrition copy** in main/support/warning |
| 14:00 | empty | `day.idle` | `stableDay` | ВСЁ ХОРОШО | Спокойный день | Modifiers may flag behind; signals OK in support |
| 20:00 | empty | `day.idle` | `stableDay` | ВСЁ ХОРОШО | Спокойный день | No tomorrow demand → not protection |

**Rule:** Morning idle must not lead with еда/вода — enforced in `CoachV6CopyRegistry.shouldSurfaceNutritionSignals`.

---

### 12. Yesterday load (Phase 2)

| Case | Signals | Expected owner | Scenario | Badge | Today title | Conflict |
|------|---------|----------------|----------|-------|-------------|----------|
| 12A | brain past high load, recovery 92%, fresh today | `day.idle` | `morningReadiness` | ВСЁ ХОРОШО | С чего начать | Heavy yesterday + good recovery — calm morning, yesterday in support |
| 12B | brain past high load, recovery 38% | `day.idle` | `recoveryAfterHeavyYesterday` | БЕРЕЖЁМ СИЛЫ | День восстановления | Heavy yesterday + bad recovery — recovery day |
| 12C | brain past high load, empty plan afternoon, recovery 78% | `day.idle` | `stableDay` | ВСЁ ХОРОШО | Спокойный день | Good recovery afternoon — stable day + yesterday support |

### 13. Heavy today + active session now

| Signal | Expected owner | Scenario | Badge | Today title |
|--------|----------------|----------|-------|-------------|
| heavy `actualLoad` + live ride | `session.activity` | `duringEndurance` | СЕЙЧАС | На заезде |
| + tomorrow hard + completed serious earlier | `session.activity` + `overlay.stackedRisk` | `duringEndurance` | **ВНИМАНИЕ** | **Нагрузка на пределе** |

**Conflict note:** Day load affects modifiers + stacked overlay, not scenario name.

---

### 14. Sauna conflicts

| Case | Situation | Owner | Scenario | Badge | Today title | Conflict |
|------|-----------|-------|----------|-------|-------------|----------|
| 14A | long ride done + upcoming sauna | `session.activity` | `saunaPreparation` | СЕЙЧАС ВАЖНО | Перед баней | Endurance post story **yields** when outside 180m focus window |
| 14B | active sauna + hydration critical | `session.activity+overlay.nutrition` | `saunaActive` | ВАЖНО | В бане | Hydration warning — scenario unchanged |
| 14C | sauna active 22:15 | `session.activity` | `saunaActive` | СЕЙЧАС | В бане | Late clock does not idle-wind-down over live heat |
| 14D | sauna prep + tomorrow hard run | `session.activity` | `saunaPreparation` | СЕЙЧАС ВАЖНО | Перед баней | Tomorrow demand **does not** override explicit sauna focus |

---

### 15. Multi-activity day (one primary story)

| Case | Calendar | Focus winner | Scenario | Badge | Today title | Conflict |
|------|----------|--------------|----------|-------|-------------|----------|
| 15A | walk done + **live ride** + strength later | live ride | `duringEndurance` | СЕЙЧАС | На заезде | No split narration |
| 15B | ride done + **live sauna** | live sauna | `saunaActive` | СЕЙЧАС | В бане | Heat beats endurance post |
| 15C | strength done + upcoming recovery walk | walk | `walkRecoveryAction` | СЕЙЧАС ВАЖНО | Прогулка для ног | Walk routing after serious work |
| 15D | tennis done + upcoming sauna | sauna | `saunaPreparation` | СЕЙЧАС ВАЖНО | Перед баней | Single upcoming heat story |

**Rule:** V6 never narrates activity-by-activity — focus chain picks one owner.

---

### 16. Transition stability (no flicker)

| Path | Checkpoints | Expected monotonic progression |
|------|-------------|--------------------------------|
| Endurance day | during @+0/+10/+15m → postImmediate @+5/+12m after end → settled @+105m → evening @21:30 | No backward jumps within 10–15m windows |
| During window | +0/+10/+15m into session | Stays `duringEndurance` |

**Note:** `isCompleted` must be false during live window — premature complete flag jumps to immediatePost early.

---

## Summary — highest-risk conflicts

| # | Conflict | Winner today | Risk |
|---|----------|--------------|------|
| 3 | Evening clock vs postImmediate window | postImmediate if ≤60m since end | User sees “Заезд завершён” at 21:30 |
| 4 | eveningAfter vs tomorrowProtection | tomorrowProtection when guard passes | Correct — but depends on focus/auto-focus |
| 4b | Upcoming workout today blocks protection | session.activity | User may expect protection anyway |
| 4b′ | Auto-focus upcoming + stacked pre-session | stacked overlay on `activeStrength` | Protection lost twice — focus shift + stacked title |
| 8 | during* vs stacked overlay presentation | stacked copy/title | Scenario key misleading in logs |
| 9–10 | Recovery vs V6 | **ignored** | Wire `recoveryContext` into modifiers / protection |
| 11 | Morning empty nutrition | copy suppressed | Modifiers still behind — OK |
| 12 | Yesterday load vs V6 | **ignored** | Wire `brain.past` into day load |
| 14 | Sauna vs tomorrow/endurance | session.activity (heat) | Product may want protection |
| 15 | Multi-activity | single focus | Log scenario key ≠ all calendar items |
| 16 | Premature `isCompleted` | immediatePost too early | HealthKit sync timing |

---

## Test coverage

Automated: `CoachV6EdgeCaseSnapshotTests` — **38 tests** covering §1–§16 (incl. sub-cases).  
Registry guard: `CoachV6CopyRegistryTests.testMorningReadinessEmptyNutritionSuppressesSupportingSignals`.  
Manual: run `testPrintEdgeCaseMatrix` → `/tmp/WeekFitCoachV6EdgeCaseMatrix.txt`.
