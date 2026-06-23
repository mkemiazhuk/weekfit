# Phase E — Why Narrative Alignment

**Status:** In progress  
**Depends on:** Endurance Arc (B), Today alignment (C), Racket Arc (D)  
**Scope:** Why rows only — no new owners, no new narrative families, no arc work

---

## North Star

| Section | Question it answers |
|---------|-------------------|
| Hero | What the coach decides |
| Assessment (My Read) | Context and interpretation |
| Recommendation | What to do |
| **Why** | **Why this decision is correct right now** |

**Why must belong to the same narrative family as Hero and Recommendation.**

Anti-pattern: Hero «Вечер после длинной поездки» + Rec «Выспитесь сегодня» + Why «Восстановление для сегодня в норме».

---

## Root cause (pre-Phase E)

| Layer | Problem |
|-------|---------|
| `CoachEnduranceDuringPostCopyCatalog.reasons` | `postLong/postMedium/postShort` returned `[]` |
| `CoachFinalStoryRenderModel` | `postActivityRecovery` why limit = 0 (blocked all post Why) |
| `CoachPresentationSanitizer.sanitizeWhyRows` | Injected «Восстановление для сегодня в норме» when empty + recovery ≥75% |
| `stableOverviewReasons` / `defaultReasons` | Recovery/HRV status strings |
| Contract tests | Validated `renderModel.whyRows` only, not `coachPresentation.whyRows` |

---

## Why ownership model

**Rule:** Narrative family owns Why content. Owner owns visibility limits only.

### Classification

| Type | Use when | Example |
|------|----------|---------|
| **Decision Reason** | Explains why Hero/rec is right | «Первый час после нагрузки — главное окно восстановления» |
| **Context Signal** | Time/session anchor supporting decision | «До финиша около 40 минут» |
| **Hidden** | Read already explains; Why adds noise | Settled post evening |
| **Forbidden** | Status without decision link | «Восстановление в норме», «Самочувствие в обычном диапазоне» |

---

## Ownership map by owner / chapter

### `postActivityRecovery`

| Timing | Hero (example) | Recommendation | Why | Visibility |
|--------|----------------|----------------|-----|------------|
| Immediate (0–60 min, recovery window) | «Окно восстановления открыто» | Refuel meal | Catalog: window + protein/carbs rationale | **Show** (≤2 rows) |
| Settled (90–240 min) | «После сегодняшней поездки» | Easy day / sleep | «Основная работа сделана» + sleep/easy constraint | **Show** (≤2 decision rows) |
| Stale (≥4 h, evening) | «Вечер после длинной поездки» | Protect sleep | «Сон сегодня важнее, чем ещё одна нагрузка» | **Show** (≤2 decision rows) |

**Source:** `CoachEnduranceDuringPostCopyCatalog.reasons(.recoveryWindow)` for immediate; empty for settled/stale phases.

### `stableOverview`

| Scenario | Hero | Desired Why |
|----------|------|-------------|
| Calm day, no workout | «Ничего исправлять не нужно» | «Сегодня нет нагрузки, требующей коррекции» |
| + tomorrow demand | Calm wind-down | «Завтра серьёзная тренировка — лишняя нагрузка сегодня не поможет» |
| + session today | Plan-aware hero | «Главная нагрузка ещё впереди — сейчас не разгоняйте день» |
| Late evening | Sleep protection hero | «Поздний вечер лучше для сна, а не для нагрузки» |

**Source:** `stableOverviewReasons()` — decision strings only.

### `readiness`

Same family as stable overview for Why, but morning framing:

| Scenario | Desired Why |
|----------|-------------|
| Good recovery, session ahead | «Сейчас важнее выйти свежим, чем спешить с подготовкой» (prep) or time room |
| Sleep/recovery limited | Limiter-specific decision, not biomarker status |

### Endurance chapters (during, ≥60 min)

| Chapter | Hero | Desired Why #1 | Desired Why #2 |
|---------|------|----------------|----------------|
| Opening | «Войдите в поездку плавно» | «Спокойный старт делает сессию ровнее» | Time remaining (context) |
| Establish | «Задайте ритм питания» | «Регулярное питание сделает вторую половину ровнее» | «Пора задать ритм питания» |
| Maintain | «Держите ровную середину» | «Середина — про повторение того, что работает» | Elapsed time (optional context) |
| Protect | «Берегите финиш» | «Берегите финиш — лишних рывков не нужно» | Time to finish |
| Recovery window | «Окно восстановления открыто» | First hour rationale | Protein/carbs rationale |

**Source:** Catalog `reasons(for: phase)` — same file as Hero copy.

**Removed:** Pacing legacy recovery % strings («Восстановление ещё даёт запас»).

### Deficit overrides

| Owner | Desired Why |
|-------|-------------|
| `fuelingDuringActivity` | Fuel behind workload + remaining work needs energy |
| `hydrationExecution` | Fluid behind session + catch-up harder later |

### Sauna (heat family)

| Phase | Desired Why |
|-------|-------------|
| Pre | Heat is main stressor + hydration before heat (+ tomorrow if applicable) |
| Active | Heat not training + leave before fatigue |
| Post | Slow rehydration + plan balance / no more load (not «still recovering» status) |

### `tomorrowProtection`

| Desired Why |
|-------------|
| Tomorrow is higher-priority demand |
| Extra load today lowers readiness |
| Sleep prepares next session |

---

## Implementation checklist

- [x] Remove sanitizer recovery fallback
- [x] `postActivityRecovery` render why limit → 2 (empty when catalog returns `[]`)
- [x] Rewrite `stableOverviewReasons` — decision not status
- [x] Rewrite `finalStoryReasons` stable/readiness branch
- [x] Fix `defaultReasons` default + sauna pre recovery status
- [x] Fix pacing catalog recovery % → session decision
- [x] Contract tests on `coachPresentation.whyRows`
- [ ] Screenshot audit (manual, below)

---

## Screenshot audit (before / after)

Run on Russian locale. Verify **Why** column matches Hero family; no status-only rows.

### Post recovery

| # | Setup | Hero (expect) | Why (expect) |
|---|-------|---------------|--------------|
| E-P1 | Long ride ended 20 min ago | «Окно восстановления открыто» | 1–2 rows: window + refuel rationale. **Not** «в норме» |
| E-P2 | Long ride ended 4+ h, evening | «Вечер после длинной поездки» | 1–2 decision rows (work done + sleep beats load). **Not** «в норме» |
| E-P3 | Strength post settled | «Силовая позади» | Empty or sleep-protection decision only |

### Stable day

| # | Setup | Why (expect) |
|---|-------|--------------|
| E-S1 | No workouts, recovery good | «Сегодня нет нагрузки, требующей коррекции» |
| E-S2 | Evening calm, no session | Sleep-protection decision if Why shown |

### Endurance during

| # | Chapter | Why must mention |
|---|---------|------------------|
| E-D1 | Opening @15 min | Calm start / long session ahead |
| E-D2 | Maintain @120 min | Middle / repeat rhythm — not recovery % |

### Sauna

| # | Phase | Why must NOT contain |
|---|-------|---------------------|
| E-H1 | Pre | «Сил хватает», «в норме» |
| E-H2 | Post | Generic recovery status |

**Gate:** All E-* rows pass before Phase E marked complete.

---

## Contract tests

| Test | Asserts |
|------|---------|
| `testPhaseEImmediatePostRecoveryWindowPresentationWhyExplainsDecision` | Presentation Why shows window/refuel rationale |
| `testPhaseEStableDayPresentationWhyUsesDecisionNotStatus` | Stable Why = correction/decision, not status |
| `testV4StalePostLongRideUsesEveningCopyNotImmediateProtocol` | Presentation Why empty for stale post |
| Matrix `assertScenario` | Post: immediate vs settled Why rules on **presentation** layer |
| `XCTAssertWhyRowsAreRationale` | Rejects recovery status phrases |

---

## Related

- `COACH_V5_NARRATIVE_ARCHITECTURE.md` — Hero/Why same theme (§3)
- `COACH_ROADMAP.md` — Phase E entry
