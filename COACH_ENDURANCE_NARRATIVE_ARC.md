# Endurance Narrative Arc — Design Doc (Phase B)

> **Status:** Design only · no implementation in this doc  
> **Prerequisite:** Phase A presentation contract (engine owns Hero for activity-bound stories)  
> **Constraint:** Do **not** add new `CoachFinalStoryOwner` values in v1 — chapters live inside existing owners + copy catalog.

---

## Problem

After ~30 minutes of a long session, owner locks to `sustainableExecution` (or `activeActivity` playbook equivalent) until finish. Copy is static; only Why countdown changes. A human coach would shift emphasis across the same ride without changing the fundamental job of the session.

Phase A fixed **who speaks** (engine vs presentation). Phase B fixes **how the story evolves** within one owner family.

---

## Design principles

1. **One narrative family per moment** — Hero, Read, Rec, Why stay in the same chapter (Phase A contract).
2. **Chapters, not new owners** — use `EnduranceSessionChapter` derived from time, not a new priority class.
3. **Compliance ≠ silence** — good fueling/hydration still gets progression («первая половина закрыта», «финишный отрезок»).
4. **Deficit chapters stay** — existing `fuelingDuringActivity` / `hydrationExecution` override when telemetry says behind.
5. **Human cadence** — a chapter should feel like the next sentence in one conversation, not a mode switch.

---

## Chapters

| Chapter | Job (coach mental model) | Typical user feeling |
|---------|--------------------------|----------------------|
| **Opening** | Enter rhythm; don’t spend matches early | «Разогреться, не рвануть» |
| **Establish** | Build fueling/hydration habit | «График важнее аппетита» |
| **Maintain** | Steady state; no surges | «Держать, не ускорять» |
| **Protect** | Finish without a tax | «Дожить ритм до финиша» |
| **Recovery Window** | Close the training stress; refuel now | «Работа сделана — окно восстановления» |

Post-ride **day protection** (evening, sleep) stays in existing post timing (`immediate` / `settled` / `stale`) — not a sixth chapter inside the ride.

---

## Switching criteria

Inputs (all from existing snapshot):

- `elapsedMinutes` — since activity start  
- `remainingMinutes` — until planned end  
- `durationBand` — `.shortUnder60` / `.medium60To120` / `.longOver120`  
- Optional: `fuelRisk`, `hydrationRisk` (existing limiter booleans)

### Default thresholds (long ride ≥ 120 min planned)

| Chapter | Enter when | Exit when |
|---------|------------|-----------|
| **Opening** | session start | `elapsed ≥ 20` **or** `elapsed ≥ 10` && `duration < 120` |
| **Establish** | after Opening | `elapsed ≥ 60` **or** `remaining ≤ 90` (whichever comes first on long rides) |
| **Maintain** | after Establish | `remaining ≤ 60` |
| **Protect** | `remaining ≤ 60` && session still active | session ends |
| **Recovery Window** | session ended && `minutesSinceEnd ≤ 60` | `minutesSinceEnd > 60` → post settled/stale copy |

### Medium ride (60–120 min planned)

Compress arc:

- Opening: `elapsed < 15`
- Establish: `15 ≤ elapsed < 45`
- Maintain: `45 ≤ remaining > 30`
- Protect: `remaining ≤ 30`

### Short ride (< 60 min)

No arc — keep current pacing → single execution block.

### Deficit overrides (any chapter)

| Condition | Chapter replaced by |
|-----------|---------------------|
| `fuelRisk && elapsed ≥ 45` | Fueling alert chapter (existing `fuelingDuringActivity` copy) |
| `hydrationRisk && elapsed ≥ 30` | Hydration alert chapter (existing `hydrationExecution` copy) |

Overrides win until ratio recovers (hysteresis: stay alert for ≥15 min once triggered, to avoid flicker).

---

## Copy strategy (per chapter)

Each chapter updates **Hero + situation + primary action + one Why row** — not the whole card.

| Chapter | Hero direction (RU examples) | Primary action emphasis |
|---------|------------------------------|-------------------------|
| Opening | «Войдите в поездку плавно» | Next 10 min easy |
| Establish | «Держите график питания» | Carbs every 20–30 min |
| Maintain | «Середина — про стабильность» | Repeat rhythm; no surges |
| Protect | «Финиш — без рывка» | Hold cadence; last fuel block |
| Recovery Window | «Поездка позади — восстановление» | Protein + carbs now |

Assessment (`whatHappened`) may reference elapsed/load holistically via existing `CoachHolisticReadBuilder`.

**Why row evolution (in addition to countdown):**

- Establish: «Регулярное питание делает вторую половину ровнее»
- Maintain: «Вы уже N минут в работе — темп держится»
- Protect: «До финиша около N минут — не добавляйте интensity»

---

## Architecture (minimal)

```
CoachFinalStoryBuilder
  └─ enduranceSessionChapter(elapsed, remaining, durationBand, fuelRisk, hydrationRisk)
       └─ CoachEnduranceDuringPostCopyCatalog.window(for: chapter, ...)
            └─ same owners: pacingExecution | sustainableExecution | fuelingDuringActivity | …

CoachTabPresentationResolver
  └─ Phase A: defer Hero when activity-bound (unchanged)

CoachTodayTeaserBuilder
  └─ map chapter → one tactical line (different from Coach Hero wording, same family)
```

No new owner enum in v1. Optional internal enum:

```swift
enum CoachEnduranceSessionChapter {
    case opening, establish, maintain, protect
    case fuelingAlert, hydrationAlert  // maps to existing owner copy paths
}
```

Post-session `recoveryWindow` maps to existing `postLong` immediate window.

---

## Acceptance criteria (Phase B)

1. **Same family:** For each chapter, Hero / Rec / primary Why share fueling, pacing, or recovery theme — no pacing Hero + fueling body.
2. **Progression:** On a simulated 4 h ride, at least **3 distinct Heroes** appear at Opening / Establish(or Maintain) / Protect without user falling behind on fuel.
3. **No flicker:** Chapter changes at most once per 15 min unless deficit override.
4. **Today vs Coach:** Today remains shorter and tactical; both reference same chapter family.
5. **Regression:** Sauna, stable day, short post unchanged from Phase A audit baselines.
6. **Human read-aloud test:** Copy for each chapter must sound like the next line from one coach, not a template rotation.

---

## Out of scope (Phase B v1)

- New `CoachFinalStoryOwner` values  
- ML / feel-based chapter detection  
- Weather/course profile chapters  
- Rewriting Priority Resolver  
- English copy overhaul (follow existing bilingual catalog pattern)

---

## Suggested implementation order

1. `enduranceSessionChapter()` pure function + unit tests on thresholds  
2. Extend `CoachEnduranceDuringPostCopyCatalog` with chapter-specific windows  
3. Wire playbook to chapter instead of flat `sustainable` for all elapsed > 30  
4. Update Why builder to prefer chapter context over static fuel line  
5. Today teaser chapter mapping  
6. Contract tests: 4 h ride timeline expects Hero changes at defined elapsed points

---

## Open questions

1. **Opening length:** 20 min vs 30 min for cycling — validate with ride data / product feel.  
2. **Protect start:** 60 vs 45 min remaining on 3–4 h rides.  
3. **Short post Hero split** (Phase A audit): align 45 min post Hero with engine or keep generic — product call independent of arc.
