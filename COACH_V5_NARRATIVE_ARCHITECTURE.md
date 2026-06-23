# V5 Narrative Architecture

> **Purpose:** Single reference for how Coach tells stories across activity families.  
> **Status:** Product architecture · no code · no new owners  
> **Shipped:** Endurance Arc (Phase B, `fb16d58`)  
> **Designed:** Racket Arc, Heat Arc · **Flat:** Strength, Recovery

---

## North star (V5)

> **Arc появляется только тогда, когда течение времени меняет решение тренера.**

If time passing does not change what a good coach would advise, the session gets **one story** — not artificial chapters.

Everything below follows from this rule.

---

## Two layers (don’t confuse them)

| Layer | Scope | Example |
|-------|--------|---------|
| **Session lifecycle** | Universal for all activities | Prepare → Execute → Close → Recover |
| **Narrative Arc (chapters)** | Optional *inside* Execute / immediate Recover | Opening → … → Protect |

Every activity has a lifecycle. **Only some activities need chapters inside Execute.**

---

## V5 product principles

These sit under the north star and explain *why* structures differ.

### 1. Time changes advice → Arc

Chapters exist when elapsed time shifts the coach’s **leading decision** (fuel rhythm → steady middle → finish discipline; warm-in → manage sprints → close smart; hydrate before → moderate heat → rehydrate after).

### 2. Chapters, not owners

Priority class (`pacingExecution`, `fuelingDuringActivity`, …) answers **what job owns the moment**.  
Chapters answer **which sentence the coach says** within that job. Never multiply owners for narrative phases.

### 3. One narrative family per moment

Hero, Read, Recommendation, and primary Why share one theme (Phase A/B contract). No pacing Hero with fueling body.

### 4. Deficit beats chapter

When telemetry says the user is behind (fuel, hydration, readiness, heat stress), **alert copy overrides chapter logic** until recovered (with hysteresis against flicker).

### 5. Today = tactical, Coach = interpretive

Same **chapter family**, different wording. Today is one line; Coach is the full story.

### 6. Flat is valid

Strength, yoga, short racket — one good story beats a fake five-act structure.

### 7. Human cadence

A chapter change should sound like the **next line** from one coach, not a mode rotation or template swap.

---

## Architecture stack (conceptual)

```
PlannedActivity
    → Activity Family (endurance | racket | strength | recovery-* | heat)
    → Session Phase (pre | during | post)
    → Arc Template? (nil | endurance | racket | heat)
        → Chapter (family-specific)
            → Copy catalog (Hero, Rec, Why, Avoid)
    → Owners (unchanged — priority & deficit)
    → Surfaces
        Coach Story (full chapter)
        Today Teaser (same family, shorter)
```

---

# Family reference

---

## Endurance Arc

**Activities:** Cycling, Running  
**Arc threshold:** planned duration **≥ 60 min**  
**Implementation:** ✅ Phase B

### Structure

```
Opening → Establish → Maintain → Protect → Recovery Window
```

| Chapter | Coach decision over time |
|---------|--------------------------|
| **Opening** | Don’t spend early — ease into rhythm |
| **Establish** | Set **fuel/hydration schedule** before hunger |
| **Maintain** | Repeat rhythm; no surges |
| **Protect** | Finish without taxing tomorrow (`max(75% elapsed, last 60 min)`) |
| **Recovery Window** | First hour post — refuel & calm (protein + carbs) |

### Why this structure?

Endurance stress is **time-linear and fuel-linear**. The limiting factor shifts predictably:

1. Early: pacing mistakes are expensive for the whole ride.  
2. Middle: glycogen/hydration schedule dominates sustainable output.  
3. Long middle: holding steady beats heroics.  
4. Late: finish discipline matters more than extra pace.  
5. Post: metabolic window is real and time-bounded.

**Five chapters map to five real coach decisions** — not five labels on one decision.

### Flat fallback

**&lt; 60 min:** no arc — single pacing/sustainable block (legacy playbook).

### Deficit overrides

| State | Overrides chapter |
|-------|-------------------|
| Fuel deficit | `fuelingDuringActivity` copy |
| Hydration deficit | `hydrationExecution` copy |
| Critical readiness | Adjust tone (dial back) |

---

## Racket Arc

**Activities:** Tennis, Squash  
**Arc threshold:** planned duration **≥ 60 min**  
**Implementation:** 📋 designed, not shipped

### Structure by duration

**60 min (compressed):**

```
Warm In → Manage Load → Close Smart
```

**90 min:**

```
Warm In → Find Rhythm → Manage Load → Close Smart
```

**120+ min:**

```
Warm In → Find Rhythm → Manage Load → Close Smart
```

(Close Smart: `max(75% elapsed, last 25–30 min)` — shorter final act than endurance.)

| Chapter | Coach decision over time |
|---------|--------------------------|
| **Warm In** | Don’t spike before first rallies |
| **Find Rhythm** | Timing, breathing, length — *not* carb schedule |
| **Manage Load** | **Sprint budget** — selective accelerations |
| **Close Smart** | Don’t pay for last points with legs/tomorrow |
| **Recovery Window** | Legs + fluids in first hour; calm evening |

### Why this structure?

Racket load is **intermittent and neuromuscular**, not steady aerobic:

- Time changes whether you advise **patience**, **selectivity**, or **closing discipline**.  
- It does **not** change whether you advise “carbs every 20–30 min” as the **leading** story (fuel is secondary / override only).  
- Find Rhythm has no endurance equivalent — it’s court-specific.  
- Close Smart is shorter than Protect on a 4 h ride because court sessions rarely need a 60-minute “final hour” narrative.

### Why not reuse Endurance Arc?

Same skeleton (temporal progression + deficit + recovery window), **different semantics**. Copying Establish/Maintain would feel like a cycling coach pasted onto a court.

### Flat fallback

**&lt; 60 min:** single story — «На корте лучше держать нагрузку под контролем».

### Deficit overrides

| State | Overrides chapter |
|-------|-------------------|
| Hydration deficit | Hydration copy (critical on court) |
| Low fuel (long match) | Fueling copy |
| Overheating | Heat-hydration tone |
| Critical readiness | Adjust / ease up |
| Fatigue (accumulated) | Stronger Manage Load tone, same chapter |

---

## Heat Arc

**Activities:** Sauna (+ heat-adjacent sessions)  
**Arc model:** **3-phase lifecycle** (not 5-chapter execute arc)  
**Implementation:** partial (playbook exists; arc not formalized as chapters)

### Structure

```
Prepare → During → Post Immediate
         (optional: settled / stale post timing)
```

| Phase | Coach decision |
|-------|----------------|
| **Prepare** | Hydrate **before** heat stress |
| **During** | Moderate exposure — exit before fatigue |
| **Post Immediate** | Rehydrate gradually; protect evening |

### Why this structure?

Heat sessions are usually **short (10–45 min)**. Time inside “during” rarely supports multiple narrative beats — the coach’s job is binary: **don’t overdo heat, get out in time**.

What *does* change over time is **phase of the heat journey**, not minute 12 vs minute 28 of sitting:

- Before: water is the decision.  
- During: moderation is the decision.  
- After: recovery & calm is the decision.

That’s a **3-phase arc**, not Opening/Establish/Maintain. Calling it a 5-chapter arc would be artificial.

### Why not Endurance Arc?

Heat is **recovery tool**, not training stimulus. Users must never hear “hold steady middle” in a sauna. Mental model is safety + hydration, not performance pacing.

### Flat vs arc nuance

Heat **has** an arc at the **lifecycle** level (pre/during/post). It **does not need** sub-chapters within During for typical duration.

### Deficit overrides

| State | Overrides phase copy |
|-------|---------------------|
| Severe dehydration pre-heat | Hydration-first prep |
| During + depleted fluids | Hydration alert |
| Should protect tomorrow | Wind-down / tomorrow tone in post |

---

## Strength — flat model

**Activities:** Upper Body, Lower Body, Core, Full Body  
**Arc:** **none** (optional lite 3-phase only for rare 90+ min sessions — defer)

### Structure

```
During:  one story — controlled execution (reps in reserve, form)
Post:    immediate recovery → settled → stale
```

| Moment | Coach decision |
|--------|----------------|
| **During** | Form & reserve > load; don’t grind |
| **Post immediate** | Protein / meal if depleted |
| **Post settled** | Protect rest of day |

### Why flat?

Strength is organized in **blocks and sets**, not in the user’s felt timeline of a continuous stream:

- Minute 25 vs minute 40 often asks the **same** coach decision: “leave reps in the tank.”  
- Split type (upper/lower/core/full) changes **tone**, not **time chapter**.  
- Adding Establish/Maintain/Protect would mimic endurance without matching gym psychology.

**Arc fails the north star test** for typical 45–75 min sessions.

### Deficit overrides

| State | Overrides flat story |
|-------|---------------------|
| Low fuel / post protein need | Refuel copy in post |
| Critical readiness | Dial back / reduce load |
| Should protect tomorrow | Lighter session tone |

---

## Recovery — flat model

**Activities:** Walk, Stretching, Yoga, Mobility, Breathing  
**Arc:** **none** (exception: very long walk/hike 120+ min → max 2 chapters: Easy Start → Steady Easy — optional, low priority)

### Structure

```
During:  one calm story — don’t turn recovery into training
Post:    usually merges into “rest of day calm” (no Recovery Window unless significant load)
```

| Modality | Coach decision |
|----------|----------------|
| **Walk** | Stay conversational; stop before fatigue |
| **Stretch / Yoga / Mobility** | Soft range; no forcing |
| **Breathing** | Short reset; one intention |

### Why flat?

Recovery activities **are** the recovery story. The coach’s job is restraint, not progression through performance phases:

- Time passing doesn’t flip the leading advice from “fuel rhythm” to “protect finish.”  
- It stays: **stay easy, don’t escalate**.  
- Multiple chapters would imply a training arc where none exists.

Long walk exception: only when duration makes “start easy vs steady easy” a **real** distinction — still not an endurance arc.

### Deficit overrides

Rare. Readiness / tomorrow protection may soften or shorten the activity — Adjust tone, not new chapters.

---

## Comparison at a glance

| Family | Arc? | Shape | Time changes leading decision? |
|--------|------|-------|--------------------------------|
| **Endurance** | Yes (≥60 min) | 5 chapters | ✅ fuel, pace, finish, recovery window |
| **Racket** | Yes (≥60 min) | 3–4 chapters | ✅ warm-up, rhythm, sprint budget, close |
| **Heat** | Yes (lifecycle) | 3 phases | ✅ hydrate / moderate / recover |
| **Strength** | No | flat + post timing | ❌ same block logic throughout |
| **Recovery** | No | flat | ❌ same restraint throughout |

---

## Cross-cutting: when Arc must NOT appear

| Anti-pattern | Why it violates V5 |
|--------------|-------------------|
| Universal Opening→Working→Protect→Recovery for all sports | Same words, different psychology → template rotation |
| Chapter every N minutes | Algorithm cadence, not coach cadence |
| New owner per chapter | Priority sprawl (V4 problem) |
| Today generic while Coach has chapters | Breaks family coherence |
| Maintain forever on long sessions without Protect | User feels stuck — Protect must be distinct |

---

## Today teaser rule (all families)

| Family | Today must… |
|--------|-------------|
| Endurance | Match chapter family (not «не гонитесь за цифрами» for every minute) |
| Racket | Match court chapter (warm / rhythm / load / close) |
| Heat | Match phase (water before / moderate heat / rest after) |
| Strength | Single tactical line (form / reserve) |
| Recovery | Single calm line (keep it light) |

---

## Implementation map (reference)

| Arc | Doc | Code status |
|-----|-----|-------------|
| Endurance | `COACH_ENDURANCE_NARRATIVE_ARC.md` | ✅ shipped |
| Racket | (Racket Arc design — this doc § Racket) | 📋 next candidate |
| Heat | V4 Heat & Sauna family + playbook | 🔶 formalize 3-phase |
| Strength | flat playbook | ✅ exists |
| Recovery | recovery modality playbook | ✅ exists |

---

## The V5 principle (canonical wording)

Use this in reviews, PRs, and content audits:

> **Arc появляется только тогда, когда течение времени меняет решение тренера.**

**Corollaries:**

1. If you cannot name **two different coach decisions** separated by time, there is no Arc.  
2. Chapters name those decisions — they are not UI modes.  
3. Owners express **priority and deficit**; Arc expresses **narrative progression**.  
4. Flat is the default; Arc is earned by duration + psychology.  
5. Different families may share **machinery** (chapter resolver, catalog, teaser map) but never **copy**.

When in doubt: read the Hero aloud at minute 20 and minute 90. If a real coach would say materially different things, consider an Arc. If not, stay flat.

---

*Related: `COACH_V5_PRODUCT_SIMPLIFICATION.md` · `COACH_V4_NARRATIVE_FAMILIES.md` · `COACH_PHASE_B_CHAPTER_SCREEN_AUDIT.md`*
