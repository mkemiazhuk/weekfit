# Coach V5 Failure Model

> **Purpose:** Identify the mistakes that **destroy trust** — false positives, false negatives, and what happens in real life.  
> **Inputs:** `COACH_V5_TRUST_MODEL.md` · `COACH_V5_FREQUENCY_MODEL.md` · `COACH_V4_DECISION_MAP.md`  
> **Core question:** If we could only prevent **5 mistakes** in the entire Coach, which **5** would matter most?

---

## Executive answer

Trust dies in **two ways**:

| Mode | Pattern | Typical severity |
|------|---------|------------------|
| **Single-shot failure** | One bad call during load (Adjust FN, In Session wrong) | **Catastrophic** — user stops listening |
| **Death by volume** | Steady Day / Get Ready noise on calm days | **Medium** — slow mute, habit trust erodes |

**False negatives during load** hurt more than **false positives during calm**.  
**Adjust** and **In Session** own the catastrophic tier. **Steady Day** owns the highest **volume** of trust erosion.

### The 5 mistakes to prevent (if you only get five)

| Rank | Failure | Family | Why it wins |
|------|---------|--------|-------------|
| **1** | **Failed to dial back before a hard start** | Adjust · FN | User enters session depleted; bad workout, injury risk, “Coach is useless” |
| **2** | **Missed live caution while body was limiting** | In Session · FN | User pushes through limiter; catastrophic embodied disproof |
| **3** | **“Ease up” when user felt fine mid-session** | In Session · FP | User learns to ignore live Coach entirely |
| **4** | **“Reduce intensity” when readiness was actually good** | Adjust · FP | Coach becomes conservative noise; user stops changing plan |
| **5** | **Calm Steady Day while a real limiter was active** | Steady Day · FP *(masking)* | Same as #1 from user view — Coach stayed quiet when body needed action |

Everything else is **important but secondary** until these five are guarded.

---

## How to read this model

| Term | Definition |
|------|------------|
| **False positive (FP)** | Coach **intervened** (led with this family) when **calm or a different family** was correct |
| **False negative (FN)** | Coach **stayed quiet** (Steady, wrong family, or absent) when **this family should have led** |
| **User consequence** | What the athlete **does or suffers** in the real world |
| **Trust consequence** | What the user **believes about Coach** afterward |
| **Severity** | Low · Medium · High · **Catastrophic** |

**Severity rules:**

| Level | Meaning |
|-------|---------|
| **Low** | Annoyance; no training harm; trust barely moves |
| **Medium** | Wrong decision possible; trust erodes over weeks |
| **High** | Clear bad outcome or ignored advice; trust drops sharply |
| **Catastrophic** | Injury risk, plan abandonment, or permanent “don’t listen to Coach” |

**Masking:** When Steady Day or Get Ready leads but Adjust should have, count as **Adjust FN** and **Steady/Get Ready FP** — same event, two labels.

---

## Family failure profiles

### 1. Steady Day

*Promise: Nothing needs fixing.*

#### Failure A — False positive (false calm)

| | |
|---|---|
| **False positive** | Steady Day leads — *“Nothing needs fixing”*, *“Recovery remains strong”*, *“Good window today”* — while readiness is poor, hard session is imminent, or post-workout absorption is still owed |
| **User consequence** | Starts or continues hard work without dialing back; skips refuel/recovery because Coach said all clear |
| **Trust consequence** | “Coach doesn’t see my body” — decision trust breaks in one glance |
| **Severity** | **High** (single day) · **Catastrophic** when user then has bad session/injury |

*Engine risk:* `stableOverview` wins over `trainingReadinessWarning` when scores tie wrong; assess fallback too optimistic.

#### Failure B — False positive (noise on calm day)

| | |
|---|---|
| **False positive** | Steady copy with **urgent nutrition tone**, opportunity push, or reset framing on a genuinely calm day |
| **User consequence** | User scans for problems that aren’t there; eats/drinks unnecessarily; feels managed |
| **Trust consequence** | “Coach cries wolf” — habit trust erodes |
| **Severity** | **Medium** (cumulative) |

#### Failure C — False negative

| | |
|---|---|
| **False negative** | User on a **true rest/easy day** gets Adjust, Get Ready, or Recover instead of calm permission |
| **User consequence** | Anxiety on day off; feels guilty resting; over-prepares for easy movement |
| **Trust consequence** | “Coach can’t leave me alone” |
| **Severity** | **Medium** |

*Note:* Steady FN is less common than Steady FP because the engine **over-intervenes** more than under-intervenes (per frequency model red flags).

---

### 2. Get Ready

*Promise: Show up ready for what’s next.*

#### Failure A — False positive (over-prep)

| | |
|---|---|
| **False positive** | Full prep / key-session intensity for **easy walk**, distant low-stakes block, or session user already fueled for |
| **User consequence** | Pre-workout anxiety; ignores eat/hydrate nags; arrives flustered |
| **Trust consequence** | “Coach treats everything like a race” |
| **Severity** | **High** |

#### Failure B — False positive (prep instead of Adjust)

| | |
|---|---|
| **False positive** | Get Ready · *Prepare for the start* when readiness is **very low** and Adjust should lead |
| **User consequence** | User interprets as “go anyway”; no plan change offered |
| **Trust consequence** | “Coach won’t tell me the hard truth” |
| **Severity** | **High** |

#### Failure C — False negative (under-prep)

| | |
|---|---|
| **False negative** | Key session in ≤90 min, readiness gap or fuel/hydration hole — Coach shows **Steady** or generic prep without escalation |
| **User consequence** | Under-fueled or under-recovered start; bad session |
| **Trust consequence** | “Coach missed the only moment that mattered today” |
| **Severity** | **High** · **Catastrophic** before A-race/key block |

#### Failure D — False negative (no Adjust handoff)

| | |
|---|---|
| **False negative** | Low recovery + hard planned work; Get Ready never escalates to **Adjust · prep reduction** |
| **User consequence** | Same as Adjust FN — enters session too hot |
| **Trust consequence** | Same as Adjust FN |
| **Severity** | **Catastrophic** |

---

### 3. Recover

*Promise: Absorb what you already did.*

#### Failure A — False positive (over-recover)

| | |
|---|---|
| **False positive** | Heavy Recover / refuel tone after **light session**, on **recovery day that feels fine**, or hours after post window closed |
| **User consequence** | Guilt for wanting to move; eats beyond need; feels lazy |
| **Trust consequence** | “Coach wants me on the couch” |
| **Severity** | **Medium** · **High** if repeated |

#### Failure B — False positive (Recover vs Wind Down conflict)

| | |
|---|---|
| **False positive** | Recover “keep spending easy” copy **and** evening activity push when Wind Down should own tomorrow stake |
| **User consequence** | Conflicting signals; late hard effort |
| **Trust consequence** | “Coach contradicts itself” |
| **Severity** | **Medium** |

#### Failure C — False negative (under-recover)

| | |
|---|---|
| **False negative** | After **hard workout**, Coach shows Steady or Get Ready for next block — no absorption story |
| **User consequence** | Stacks load; evening workout; tomorrow blown |
| **Trust consequence** | “Coach doesn’t respect what I just did” |
| **Severity** | **High** |

#### Failure D — False negative (recovery-led day missed)

| | |
|---|---|
| **False negative** | Body-led low recovery day; Steady or Get Ready leads instead of **Recover · body-led** |
| **User consequence** | User trains through fatigue; illness/overtraining risk |
| **Trust consequence** | “Coach reads the calendar, not me” |
| **Severity** | **High** · **Catastrophic** over a training block |

---

### 4. Wind Down

*Promise: Close today without costing tomorrow.*

#### Failure A — False positive (preachy protect)

| | |
|---|---|
| **False positive** | *Protect tomorrow* or *sleep first* when tomorrow is **empty/easy** or evening is **genuinely calm** |
| **User consequence** | User dismisses as nanny app; ignores future Wind Down |
| **Trust consequence** | “Coach moralizes at night” |
| **Severity** | **Medium** |

#### Failure B — False positive (Wind Down too early)

| | |
|---|---|
| **False positive** | Wind Down leads while **Recover post-workout window** still active (<2 hr after hard block) |
| **User consequence** | Skips refuel/cooldown guidance; confused priority |
| **Trust consequence** | “Coach jumped ahead” |
| **Severity** | **Medium** |

#### Failure C — False negative (missed protect)

| | |
|---|---|
| **False negative** | Hard session tomorrow + tired evening + load; Steady · evening calm leads |
| **User consequence** | Late hard effort, poor sleep, bad session next day |
| **Trust consequence** | “Coach didn’t save tomorrow when it mattered” |
| **Severity** | **High** |

#### Failure D — False negative (late-night chase)

| | |
|---|---|
| **False negative** | User chasing targets late; no *close the day* cue |
| **User consequence** | Sleep debt compounds |
| **Trust consequence** | “Coach is only useful mid-day” |
| **Severity** | **Medium** |

---

### 5. In Session

*Promise: Finish this block well.*

#### Failure A — False positive (ease up when fine)

| | |
|---|---|
| **False positive** | *Ease up now* / *This is not the day to push* when user feels **strong**, limiter is **stale or wrong**, or caution is from **over-sensitive readiness** |
| **User consequence** | User ignores Coach; completes session fine; learns live cues are noise |
| **Trust consequence** | “Coach doesn’t know my body **right now**” — live credibility **gone** |
| **Severity** | **Catastrophic** for live-tracking cohort |

#### Failure B — False positive (push / chase when limiting)

| | |
|---|---|
| **False positive** | *Don’t chase the numbers* / steady execution copy when user is **already over-paced** OR limiter says ease but copy sounds neutral-positive |
| **User consequence** | User pushes; blows session or next day |
| **Trust consequence** | “Coach cheerleads when it should shut me down” — less common but severe |
| **Severity** | **High** |

#### Failure C — False negative (miss limiter live)

| | |
|---|---|
| **False negative** | Active session + poor sleep / low recovery / critical readiness — Coach shows **normal execution** or **doesn’t surface** |
| **User consequence** | User pushes through; excessive fatigue, injury, blown tomorrow |
| **Trust consequence** | “Coach wasn’t there when it counted” |
| **Severity** | **Catastrophic** |

#### Failure D — False negative (Adjust not routed live)

| | |
|---|---|
| **False negative** | Critical readiness mid-workout; Adjust logic exists but **In Session · cautious** doesn’t fire |
| **User consequence** | Same as C |
| **Trust consequence** | Same as C |
| **Severity** | **Catastrophic** |

*Product rule:* If live, Adjust expresses through **In Session · cautious** — failure here is **In Session FN**, not Adjust FN.

---

### 6. Adjust

*Promise: Today’s plan is too ambitious.*

#### Failure A — False positive (conservative noise)

| | |
|---|---|
| **False positive** | *Reduce intensity* / *Manage intensity* when readiness is **actually good**, sleep was fine, or load is **normal** |
| **User consequence** | User ignores advice; keeps plan; no harm today |
| **Trust consequence** | “Coach is conservative noise” — future **real** Adjust calls ignored |
| **Severity** | **High** |

*User example — canonical Adjust FP.*

#### Failure B — False positive (shame frame)

| | |
|---|---|
| **False positive** | Adjust copy sounds like **Steady Day** soft caution or **guilt** — no clear alternative offered |
| **User consequence** | User feels judged; abandons plan entirely or rebels |
| **Trust consequence** | “Coach shames instead of helps” |
| **Severity** | **High** |

#### Failure C — False negative (failed to reduce)

| | |
|---|---|
| **False negative** | Poor recovery + hard session soon; Coach shows **Get Ready** or **Steady** — no reduction |
| **User consequence** | Bad workout, excessive fatigue, possible injury |
| **Trust consequence** | “Coach cannot be trusted when my body says no” |
| **Severity** | **Catastrophic** |

*User example — canonical Adjust FN.*

#### Failure D — False negative (morning warning missed)

| | |
|---|---|
| **False negative** | Hard **evening** session planned; morning readiness poor — no **Adjust · plan check** |
| **User consequence** | User commits mentally to hard day; no time to reschedule |
| **Trust consequence** | “Coach only speaks when it’s too late” |
| **Severity** | **High** |

---

### 7. Heat & Sauna

*Promise: Use heat safely.*

#### Failure A — False positive (heat on non-heat day)

| | |
|---|---|
| **False positive** | Heat & Sauna leads for user **without** heat planned; athletic intensity framing in **recovery context** |
| **User consequence** | Irrelevant advice; user confused |
| **Trust consequence** | “Coach doesn’t know my plan” |
| **Severity** | **Low** (most users) · **Medium** (heat users if repeated) |

#### Failure B — False positive (train like workout)

| | |
|---|---|
| **False positive** | Sauna block coached like **endurance session** — pace, push, performance |
| **User consequence** | Overstay in heat; dehydration |
| **Trust consequence** | “Coach doesn’t understand sauna” |
| **Severity** | **High** (heat users) |

#### Failure C — False negative (hydration before heat)

| | |
|---|---|
| **False negative** | Sauna in ≤45 min, hydration low — **Get Ready** or **Steady** without hydrate-first tone |
| **User consequence** | Dehydrated heat session; headache, poor recovery |
| **Trust consequence** | “Coach missed an obvious safety cue” |
| **Severity** | **High** (heat users) · **Low** (non-users) |

#### Failure D — False negative (post-heat recovery)

| | |
|---|---|
| **False negative** | Hard training planned after sauna; no **sequence / ease** guidance |
| **User consequence** | Stacks heat stress + training |
| **Trust consequence** | “Coach treats sauna as checkbox” |
| **Severity** | **Medium** |

---

## Cross-family failures (system-level)

These aren’t one family’s fault — they’re pipeline failures.

| ID | Failure | FP/FN | User consequence | Trust consequence | Severity |
|----|---------|-------|------------------|-------------------|----------|
| **X1** | **Wrong family wins** (score/tie-break) | Both | Advice feels off-topic | “Coach is random” | **High** |
| **X2** | **Today vs Coach contradict** | Both | User doesn’t know which to follow | “Product is broken” | **High** |
| **X3** | **Nutrition tone on wrong parent** | FP | Nagging eat/drink at wrong moment | “Coach is a food app” | **Medium** · **High** if urgent on Steady |
| **X4** | **Duplicate stories** (Adjust + In Session cards) | FP | Cognitive overload during load | “Too much noise when I’m busy” | **High** |
| **X5** | **Stale readiness** (yesterday’s sleep drives today’s live call) | Both | Wrong caution or wrong calm | “Coach data is wrong” | **Catastrophic** |
| **X6** | **Over-coaching** (Steady <30% of leads) | FP volume | Constant intervention fatigue | Mute Coach | **Medium** (cumulative) |

---

## Master ranking: all failure modes

Scored for **prevention priority** = severity × trust asymmetry × (1 + exposure proxy).  
Exposure proxy: very high freq families’ cumulative FPs rank higher than rare family FNs.

| Rank | ID | Failure mode | Family | Type | Severity |
|------|-----|--------------|--------|------|----------|
| **1** | C3 | Failed to reduce when recovery poor | Adjust | FN | **Catastrophic** |
| **2** | C4 | Missed live caution / critical readiness | In Session | FN | **Catastrophic** |
| **3** | A1 | Ease up when user felt fine | In Session | FP | **Catastrophic** |
| **4** | D4 | Get Ready without Adjust handoff | Get Ready | FN | **Catastrophic** |
| **5** | 1A | Steady calm while limiter active *(masking)* | Steady Day | FP | **Catastrophic** |
| **6** | X5 | Stale/wrong readiness drives call | System | Both | **Catastrophic** |
| **7** | C6 | Missed morning plan check | Adjust | FN | **High** |
| **8** | 3C | No post-hard Recover | Recover | FN | **High** |
| **9** | A1 | Reduce intensity when readiness good | Adjust | FP | **High** |
| **10** | 2A | Over-prep for easy session | Get Ready | FP | **High** |
| **11** | 2B | Prep instead of Adjust | Get Ready | FP | **High** |
| **12** | 3D | Recovery-led day missed | Recover | FN | **High** |
| **13** | 4C | Missed protect tomorrow | Wind Down | FN | **High** |
| **14** | X4 | Duplicate stories during live | System | FP | **High** |
| **15** | X2 | Today vs Coach contradict | System | Both | **High** |
| **16** | B2 | Adjust shame / indistinguishable from Steady | Adjust | FP | **High** |
| **17** | 7C | Missed hydrate before heat | Heat & Sauna | FN | **High**† |
| **18** | 1B | Urgent nutrition on calm Steady | Steady Day | FP | **Medium** |
| **19** | 3A | Over-recover / guilt refuel | Recover | FP | **Medium** |
| **20** | 4A | Preachy Wind Down | Wind Down | FP | **Medium** |
| **21** | 1C | No calm on true rest day | Steady Day | FN | **Medium** |
| **22** | 4D | Missed late-night close | Wind Down | FN | **Medium** |
| **23** | X3 | Nutrition tone wrong parent | System | FP | **Medium** |
| **24** | X6 | Over-coaching volume | System | FP | **Medium** (cumulative) |
| **25** | 7A | Heat on non-heat day | Heat & Sauna | FP | **Low–Medium** |

†High for heat users only.

### By severity tier (count)

| Severity | Count | Dominant families |
|----------|-------|-------------------|
| **Catastrophic** | 6 | Adjust FN, In Session FN/FP, Steady masking, Get Ready handoff, stale data |
| **High** | 9 | Adjust FP, Recover FN, Wind Down FN, Get Ready FP, system duplicates |
| **Medium** | 8 | Steady noise, Recover over-prescription, Wind Down preach, volume fatigue |
| **Low** | 2 | Heat irrelevance for non-users |

---

## Rankings by dimension

### By frequency of occurrence (which failures users hit most)

| Rank | Failure type | Est. exposure |
|------|--------------|---------------|
| 1 | Steady · false calm / noise (1A, 1B) | Highest — ~45–50% of opens at risk |
| 2 | Get Ready · over-prep (2A) | ~16–19% of opens |
| 3 | Recover · over-recover / refuel nag (3A) | ~17–20% of opens |
| 4 | Wind Down · preachy (4A) | ~11–13% of opens |
| 5 | Nutrition tone wrong parent (X3) | ~25–35% of non-Steady tones |
| 6 | Adjust · conservative noise (A1) | ~5–7% of opens |
| 7 | In Session · wrong ease up (A1) | ~8–10% of opens (subset live) |
| 8 | Adjust / In Session · FN | **Rare** but catastrophic |

*Most **instances** are medium-severity FPs on high-frequency families. Most **damage** is from rare catastrophic FNs.*

---

### By trust destruction (which failures hurt most per event)

| Rank | Failure |
|------|---------|
| 1 | In Session · FN (miss limiter live) |
| 2 | Adjust · FN (fail to reduce before start) |
| 3 | In Session · FP (ease up when fine) |
| 4 | Steady · FP masking limiter |
| 5 | Get Ready · FN (no Adjust handoff) |
| 6 | Stale readiness (X5) |
| 7 | Adjust · FP (reduce when good) |
| 8 | Recover · FN (post-hard missed) |

---

### By preventability (where product should invest)

| Rank | Failure | Prevention lever |
|------|---------|------------------|
| 1 | Adjust · FN | Readiness gate before prep window; `trainingReadinessWarning` must beat `stableOverview` / `activityPreparation` |
| 2 | In Session · FN | Limiter → cautious copy mandatory; never “going fine” when `limiterRequiresCaution` |
| 3 | In Session · FP | Require **live + limiter + confidence** before red ease-up; degrade to neutral steady |
| 4 | Adjust · FP | Raise Adjust threshold; require multi-signal (sleep + recovery + load), not single metric |
| 5 | Steady · masking | **When uncertain, don’t Steady** — prefer Adjust over false calm |
| 6 | Get Ready handoff | Product rule: low recovery + hard session → Adjust **always** beats Get Ready in prep window |
| 7 | X4 duplicates | One leading family; In Session absorbs Adjust when live |
| 8 | X5 stale data | Surface data freshness; soften calls when sync stale |

---

## The 5 mistakes — detailed prevention spec

If engineering, copy, and QA get **one sprint**, guard these five contracts:

### Mistake 1 · Adjust false negative — prep window

```
WHEN  recovery low OR sleep very low
AND   hard/meaningful session within 90 min
THEN  Adjust MUST lead (not Get Ready, not Steady)
```

**Test:** Matrix `workoutPrep` · *Run in 45 min* + low recovery · *Strength in 45 min* + moderate recovery near threshold.

---

### Mistake 2 · In Session false negative — live limiter

```
WHEN  active session
AND   limiterRequiresCaution (sleep, recovery, load, hydration, fuel, tomorrow)
THEN  In Session · cautious/depleted MUST lead (not normal execution)
```

**Test:** Matrix `activeSession` · running + caution limiter · critical readiness live.

---

### Mistake 3 · In Session false positive — ease up when fine

```
WHEN  active session
AND   limiter absent OR limiter confidence low OR user modality is light recovery
THEN  MUST NOT show red “ease up” / “not the day to push”
```

**Test:** Matrix `activeSession` · normal execution · light walk · strength with good recovery.

---

### Mistake 4 · Adjust false positive — reduce when good

```
WHEN  recovery good AND sleep adequate AND load normal
THEN  MUST NOT lead Adjust (Steady or Get Ready instead)
```

**Test:** Matrix `calmOverview` + planned training later · prep cases with excellent recovery.

---

### Mistake 5 · Steady false calm — masking limiter

```
WHEN  trainingReadinessWarning eligible OR postActivityRecovery window active
THEN  Steady Day MUST NOT lead
```

**Test:** Post-workout matrix · recovery-needed with planned work same day · low recovery morning with evening hard session.

---

## Failure ↔ family quick reference

| Family | Worst FP | Worst FN | Default severity |
|--------|----------|----------|------------------|
| **Steady Day** | Calm while limiter active | Rest day over-coached | Medium (volume) / Catastrophic (masking) |
| **Get Ready** | Over-prep / prep not Adjust | No handoff before key session | High / Catastrophic |
| **Recover** | Guilt / over-recover | Post-hard or body-led missed | Medium / High |
| **Wind Down** | Preachy protect | Missed protect tomorrow | Medium / High |
| **In Session** | Ease up when fine | Miss live limiter | **Catastrophic** / **Catastrophic** |
| **Adjust** | Reduce when good | Fail to reduce | **High** / **Catastrophic** |
| **Heat & Sauna** | Training-like heat copy | Miss hydrate before heat | Medium / High† |

---

## QA matrix mapping (failures → test groups)

| Failure rank | Primary matrix group | V4 scenarios |
|--------------|---------------------|--------------|
| Adjust FN | `workoutPrep`, `recoveryNeeded` | 9, 50–53 |
| In Session FN | `activeSession` | 2, 4, 5 |
| In Session FP | `activeSession` | 1, 3 |
| Steady masking | `postWorkout`, `recoveryNeeded`, `calmOverview` | 13–14 vs 17–22 |
| Get Ready handoff | `workoutPrep` | 8, 10 + low recovery variants |
| Wind Down FN | `eveningWindDown`, `tomorrowProtection` | 31–37 |
| Heat FN | `saunaHeat`, `workoutPrep` | 44–49 |

---

## Instrumentation (detect failures in production)

| Signal | Failure detected |
|--------|------------------|
| `planned_family` vs `actual_family` (shadow resolver) | Wrong family wins (X1) |
| `readiness_at_surface` vs `readiness_at_workout_start` | Stale readiness (X5) |
| `adjust_lead` → `user_kept_plan` + `session_rpe_high` | Adjust FN proxy |
| `in_session_ease_up` → `user_increased_intensity` | In Session FP proxy |
| `steady_lead` + `workout_within_2h` + `recovery_low` | Steady masking |
| `coach_muted_within_7d` + last family | Catastrophic FP cluster |

---

## Design rules (failure prevention)

1. **Never false-calm a limiter.** Steady loses to any credible readiness warning.
2. **Adjust beats Get Ready in prep window** when recovery is poor — no exceptions.
3. **In Session cautious requires live + limiter** — not historical sleep alone.
4. **One card, one family** — duplicates are a P0 bug, not a polish item.
5. **False positive Adjust is a tax on false negative Adjust** — tune threshold knowing users will ignore future Adjust after conservative noise.
6. **Steady Day failure is cumulative** — track weekly Steady rate; >65% suggests under-intervention, <30% suggests noise.

---

## One-page summary

| If you prevent only… | You stop… |
|----------------------|-----------|
| **#1 Adjust FN** | Bad sessions before they start |
| **#2 In Session FN** | Push-through injury/fatigue during load |
| **#3 In Session FP** | Live Coach becoming ignorable |
| **#4 Adjust FP** | Future real Adjust calls being dismissed |
| **#5 Steady masking** | “Coach stayed quiet when I needed help” |

**80% of trust destruction** ≈ these five + stale readiness (X5).  
**80% of failure instances** ≈ medium FPs on Steady, Get Ready, Recover — fix after P0 guards ship.

---

*Pairs with `COACH_V5_TRUST_MODEL.md` (impact) and `COACH_V5_FREQUENCY_MODEL.md` (exposure).*
