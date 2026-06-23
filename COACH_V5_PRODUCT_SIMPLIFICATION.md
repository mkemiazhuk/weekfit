# Coach V5 Product Simplification

> **Purpose:** Redesign the Coach as a product — not as code.  
> **Inputs:** `COACH_V4_DECISION_MAP.md` · `COACH_V4_NARRATIVE_FAMILIES.md` · `COACH_V4_USER_MENTAL_MODEL.md`  
> **Constraint:** Reduce visible narrative families from 14 to **8** without losing capability.  
> **Out of scope:** Code changes, test changes, implementation plans.

---

## Executive summary

Coach V4 does the right jobs but tells them through **too many similar stories**. Users experience overlap — six variants of "you're fine," three variants of "wind down," prep copy that is indistinguishable from fuel/hydration copy.

**V5 proposal:** Collapse **14 active families → 7 families**, backed by **tone variations** (not separate product stories). Reduce **59 technical scenarios → 24 product scenarios**. Nutrition is a **tone**, not a family *(see Challenge review below)*.

The seven families map cleanly to how users already think:

| # | V5 family | One-line promise |
|---|-----------|------------------|
| 1 | **In Session** | Finish this block well |
| 2 | **Get Ready** | Show up ready for what's next |
| 3 | **Adjust** | Today's plan is too ambitious |
| 4 | **Recover** | Absorb what you already did |
| 5 | **Steady Day** | Nothing needs fixing |
| 6 | **Wind Down** | Close today without costing tomorrow |
| 7 | **Heat & Sauna** | Use heat safely |

Capability is preserved: every V4 trigger still resolves to a family + tone. What disappears is **duplicate framing**, not **duplicate logic**.

---

## Design principles for V5

1. **One leading family at a time** — never two cards, two stories, two badges for the same moment.
2. **Tone varies; family doesn't** — "ease up now" and "don't chase numbers" are both In Session, not two families.
3. **Nutrition is a tone, not a family** — eat/drink surfaces inside Get Ready, Recover, Wind Down, or Steady Day (urgent). See Challenge review.
4. **Evening is one story** — users don't distinguish "close out" from "protect tomorrow"; Wind Down names the stake when tomorrow matters.
5. **Calm is the default** — Steady Day should be the most common surfaced family over a month of use.
6. **Today vs Coach stays** — tactical Today, interpretive Coach; simplification is about *what* story, not *how many surfaces*.

---

## Current family → Future family

### Legend

| Action | Meaning |
|--------|---------|
| **Keep** | Becomes a V5 family (possibly renamed) |
| **Merge** | Absorbed into another V5 family |
| **Remove** | No user-facing family; logic routes elsewhere |
| **Tone** | Same V5 family, different copy intensity/context |

---

### Active Execution → **In Session** · **Keep**

| Current | V5 | Action |
|---------|-----|--------|
| Active Execution (1–6) | In Session | **Keep** |

**Notes:** Running caution, light walk, critical readiness mid-session, live fuel/hydration shaping — all **tones** of In Session, not separate families.

| Tone | When | Today example |
|------|------|---------------|
| Steady | Normal execution | Don't chase the numbers |
| Cautious | Limiter active | Ease up now |
| Light movement | Walk/mobility/yoga | Keep the walk easy |
| Depleted | Critical readiness live | Ease up now (red) |

---

### Workout Preparation → **Get Ready** · **Merge**

| Current | V5 | Action |
|---------|-----|--------|
| Workout Preparation (7, 8, 10, 12, 43) | Get Ready | **Merge** |
| Day Sequencing (11, 49) | Get Ready | **Merge** — *multi-event* tone |
| Fuel Support in prep window (43, 8) | Get Ready | **Tone** — *nutrition* sub-tone |
| Hydration Support in prep window (39, 8) | Get Ready | **Tone** — *nutrition* sub-tone |
| Primary session protection (10) | Get Ready | **Tone** — *key session* sub-tone |

**Notes:** "Set up the ride properly" (hours away) and "Prepare for the start" (30 min away) differ by **urgency tone**, not family. Sequencing ("don't let sauna steal the ride") is Get Ready with **sequence** tone.

---

### Dial Back the Plan → **Adjust** · **Keep**

| Current | V5 | Action |
|---------|-----|--------|
| Dial Back the Plan (4, 9, 50–53) | Adjust | **Keep** |

**Notes:** Trust-critical. Must never sound like Steady Day or Get Ready. Morning warning for evening workout, prep-window reduction, overload frame — one family, three **timing tones**.

| Tone | When | Today example |
|------|------|---------------|
| Plan check | Morning, session later | Manage intensity |
| Prep window | Session soon, low readiness | Reduce [activity] intensity |
| In session | Live + critical readiness | Ease up now *(routes via In Session if active; Adjust if pre-start)* |

*Product rule:* If user is **live**, Adjust expresses through **In Session · Cautious**. If user is **not live**, Adjust leads.

---

### Post-Workout Recovery → **Recover** · **Merge**

| Current | V5 | Action |
|---------|-----|--------|
| Post-Workout Recovery (13, 14, 16, 47 post) | Recover | **Merge** |
| Recovery Day (27) | Recover | **Merge** |
| Recovery-Led Day (28, 29) | Recover | **Merge** |
| After a Small Session (15) | Recover | **Tone** — *light* sub-tone |
| Sleep leads today (29) | Recover | **Tone** — *sleep-first* sub-tone |

**Notes:** Users don't distinguish "recovery day" (planned) from "recovery-led" (body forced). One family: **Recover**. Planned vs reactive is internal; copy can say "recovery day" or "protect recovery" as tones.

Post-sauna recovery (47) → **Recover** tone when heat session just ended; **Heat & Sauna** tone when still in post-heat guidance window.

---

### All Clear → **Steady Day** · **Keep** (renamed)

| Current | V5 | Action |
|---------|-----|--------|
| All Clear (17, 18, 19, 22, 55, 57, 58) | Steady Day | **Keep** |
| Good Window Today (20, 59) | Steady Day | **Tone** — *opportunity* sub-tone |
| Morning Orientation (23–26) | Steady Day | **Tone** — *morning* sub-tone |
| Plan Reset (21) | Steady Day | **Tone** — *reset* sub-tone |
| Empty Day with Context — calm branches (33, 56, 57) | Steady Day | **Merge** |
| Evening Close-Out — calm branches (30, 34) | Steady Day | **Tone** — *evening calm* sub-tone |

**Notes:** "Nothing needs fixing," "Good window today," "Recovery remains strong," "Reset the day," "No pressure yet" — one family, five tones. **Steady Day** is the default voice of the product.

---

### Evening Close-Out → **Wind Down** · **Merge**

| Current | V5 | Action |
|---------|-----|--------|
| Evening Close-Out — protective branches (31, 32, 33) | Wind Down | **Merge** |
| Protect Tomorrow (35–37) | Wind Down | **Merge** |
| Evening Close-Out — calm branches (30, 34) | Steady Day | **Tone** (see above) |

**Notes:** One evening family for anything that says *stop spending*. When tomorrow has hard training, Wind Down uses **named stake** tone: *"Protect tomorrow's long run"* not generic *"Wind down."*

| Tone | When | Today example |
|------|------|---------------|
| Close out | Late night, target chasing | Close the day · Sleep beats target chasing |
| Sleep first | Sleep deficit + evening | Protect tonight's sleep |
| Protect tomorrow | Hard session tomorrow | Protect tomorrow · Wind down tonight |
| Work done | Hard day complete, evening clear | The work is done · Enjoy the evening |

---

### Protect Tomorrow → **Wind Down** · **Merge**

*(See above — not a separate V5 family.)*

---

### Hydration Support → **Nutrition** · **Merge** (conditional lead)

| Current | V5 | Action |
|---------|-----|--------|
| Hydration Support — standalone (38) | Nutrition | **Merge** |
| Hydration Support — prep window (39, 8) | Get Ready | **Tone** |
| Hydration Support — heat (44, 48) | Heat & Sauna | **Tone** |
| Hydration Support — live (40) | In Session | **Tone** |
| Hydration Support — critical (54) | Nutrition | **Merge** — *urgent* tone |
| Hydration Support — evening empty day (33) | Wind Down or Nutrition | **Tone** by severity |

**Product rule:** Nutrition **leads** only when eat/drink is the main story without a stronger frame (prep, recover, wind down, heat). Otherwise it's a **sub-tone** of whichever family owns the moment.

---

### Fuel Support → **Nutrition** · **Merge** (conditional lead)

| Current | V5 | Action |
|---------|-----|--------|
| Fuel Support — standalone (41, 42) | Nutrition | **Merge** |
| Fuel Support — prep (43, 8) | Get Ready | **Tone** |
| Fuel Support — critical (54) | Nutrition | **Merge** — *urgent* tone |
| Fuel before training situation (42) | Get Ready or Nutrition | **Get Ready** if session soon; **Nutrition** if session distant |

---

### Heat & Sauna → **Heat & Sauna** · **Keep**

| Current | V5 | Action |
|---------|-----|--------|
| Heat & Sauna (44–49) | Heat & Sauna | **Keep** |
| Hydrate around heat (48) | Heat & Sauna | **Tone** — *hydrate first* |
| Sauna changes rest of day (49) | Get Ready or Heat & Sauna | **Sequence** tone under Get Ready when training follows; else Heat |

**Notes:** Users have a clear mental model for sauna. Keep standalone. Pre / during / post are **phase tones**, not families.

---

### After a Small Session → **Recover** · **Tone**

| Current | V5 | Action |
|---------|-----|--------|
| After a Small Session (15) | Recover · *light* | **Tone** |

---

### Good Window Today → **Steady Day** · **Tone**

| Current | V5 | Action |
|---------|-----|--------|
| Good Window Today (20, 59) | Steady Day · *opportunity* | **Tone** |

---

### Morning Orientation → **Steady Day** · **Tone**

| Current | V5 | Action |
|---------|-----|--------|
| Morning Orientation (23–26) | Steady Day · *morning* | **Tone** |

*Exception:* Morning walk start (24) with walk in <60 min and recovery strong → **Get Ready · light* if walk is the next meaningful event; else Steady Day · morning.

---

### Recovery Day → **Recover** · **Merge**

| Current | V5 | Action |
|---------|-----|--------|
| Recovery Day (27) | Recover · *planned* | **Merge** |

---

### Recovery-Led Day → **Recover** · **Merge**

| Current | V5 | Action |
|---------|-----|--------|
| Recovery-Led Day (28, 29) | Recover · *body-led* / *sleep-first* | **Merge** |

---

### Plan Reset → **Steady Day** · **Tone**

| Current | V5 | Action |
|---------|-----|--------|
| Plan Reset (21) | Steady Day · *reset* | **Tone** |

---

### Day Sequencing → **Get Ready** · **Tone**

| Current | V5 | Action |
|---------|-----|--------|
| Day Sequencing (11, 49) | Get Ready · *sequence* | **Tone** |

---

### Empty Day with Context → **Remove** (as family)

| Current | V5 | Action |
|---------|-----|--------|
| Empty Day with Context (33, 56) | — | **Remove** |

**Routes to:** Steady Day (calm), Nutrition (hydration/fuel gap), Recover (recovery limited), Wind Down (evening + tomorrow/load). Not a user-facing story.

---

## Migration matrix (all 18 V4 family definitions)

| V4 family | Disposition | V5 family | V5 tone (if applicable) |
|-----------|-------------|-----------|-------------------------|
| Active Execution | Keep | In Session | steady · cautious · light · depleted |
| Workout Preparation | Merge | Get Ready | standard · urgent · key-session |
| Dial Back the Plan | Keep | Adjust | morning · prep · plan-change |
| Day Sequencing | Merge | Get Ready | sequence |
| Post-Workout Recovery | Merge | Recover | standard · late-hard · activity-specific |
| After a Small Session | Tone | Recover | light |
| All Clear | Keep (rename) | Steady Day | default · work-done · no-pressure |
| Good Window Today | Tone | Steady Day | opportunity |
| Morning Orientation | Tone | Steady Day | morning |
| Recovery Day | Merge | Recover | planned |
| Recovery-Led Day | Merge | Recover | body-led · sleep-first |
| Evening Close-Out | Merge | Wind Down / Steady Day | protective → Wind Down; calm → Steady Day |
| Protect Tomorrow | Merge | Wind Down | protect-tomorrow |
| Hydration Support | Merge | Nutrition / sub-tone | standalone → Nutrition; else parent family |
| Fuel Support | Merge | Nutrition / sub-tone | standalone → Nutrition; else parent family |
| Heat & Sauna | Keep | Heat & Sauna | pre · during · post |
| Plan Reset | Tone | Steady Day | reset |
| Empty Day with Context | Remove | *(routed)* | — |

---

## V5 family reference

### 1. In Session

**User question:** *"What should I do right now in this session?"*

**Owns:** Live workouts, live walks/mobility, live sauna (during phase), live nutrition shaping.

**V4 scenarios absorbed:** 1, 2, 3, 4, 5, 6, 40, 46

**Never coexists with:** Get Ready, Recover, Steady Day, Adjust (as lead — cautious overlap only as tone)

---

### 2. Get Ready

**User question:** *"How do I arrive ready for what's next?"*

**Owns:** Prep window, distant session setup, multi-event sequencing, pre-session fuel/hydration.

**V4 scenarios absorbed:** 7, 8, 10, 11, 12, 43, 49 (+ prep-adjacent 39, 42, 45)

**Never coexists with:** In Session, Recover (as lead)

---

### 3. Adjust

**User question:** *"Should I change today's plan or intensity?"*

**Owns:** Readiness warnings, plan challenges, overload frame, same-day training adjustment.

**V4 scenarios absorbed:** 9, 50, 51, 52, 53 (+ 4 when not live)

**Never coexists with:** Steady Day, Good Window tones

---

### 4. Recover

**User question:** *"How do I absorb what I already did — or take the easy day I'm owed?"*

**Owns:** Post-workout, recovery day, body-led recovery, sleep-first days, light session acknowledgment, post-sauna.

**V4 scenarios absorbed:** 13, 14, 15, 16, 27, 28, 29, 47 (post)

**Never coexists with:** Get Ready, Adjust (optimistic), In Session

---

### 5. Steady Day

**User question:** *"Am I fine? Should I change anything?"*

**Owns:** Default calm, morning start, opportunity days, plan reset, low-urgency empty day, calm evening.

**V4 scenarios absorbed:** 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 55, 56, 57, 58, 59, 30, 34

**Never coexists with:** Adjust, Recover (body-led), Wind Down (protective)

---

### 6. Wind Down

**User question:** *"How do I finish today without costing tonight or tomorrow?"*

**Owns:** Evening protection, sleep priority, protect tomorrow, late-night close-out, post-load evening.

**V4 scenarios absorbed:** 31, 32, 33 (protective), 35, 36, 37, 14 (evening overlap tone)

**Never coexists with:** Get Ready, In Session, Steady Day (opportunity)

---

### 7. Heat & Sauna

**User question:** *"How do I use heat safely?"*

**Owns:** Sauna/heat pre, during, post; heat-hydration safety; heat before training (heat-specific framing).

**V4 scenarios absorbed:** 44, 45, 46, 48, 49 (heat-primary)

**Never coexists with:** In Session (training framing) — heat replaces training language

---

### Nutrition (tone only — not a family)

**User question:** *"Should I eat or drink right now?"* — answered **inside** the winning family, not as an eighth card.

**Routes to:**
- **Get Ready** · nutrition tone — 8, 41 (pre-workout), 42, 43, 38 (endurance soon)
- **Recover** · refuel tone — 13, 14, 41 (post-training / high-load day)
- **Wind Down** · rebuild tone — 33, 37, 41 (tomorrow hard)
- **Steady Day** · urgent nutrition tone — 38, 54, 56 *(only if 4 standalone gates pass)*

**V4 scenarios absorbed as tones:** 6, 8, 38–43, 48, 54, 56 (+ partial 11, 13, 14, 33, 37)

---

## Scenario consolidation: 59 → 24

V5 keeps **full detection capability** (all 59 triggers may still exist internally) but **23 product scenarios** — canonical user-visible combinations of **family + tone**.

| ID | Family | Tone | V4 scenarios mapped |
|----|--------|------|---------------------|
| S1 | In Session | Steady | 1 |
| S2 | In Session | Cautious | 2, 4 |
| S3 | In Session | Light movement | 3, 5 |
| S4 | In Session | Nutrition-aware live | 6, 40 |
| S5 | Get Ready | Standard prep | 7, 12 |
| S6 | Get Ready | Nutrition prep | 8, 43, 42, 41 *(pre)* |
| S7 | Get Ready | Key session | 10 |
| S8 | Get Ready | Sequence | 11, 49 |
| S9 | Adjust | Readiness warning | 9, 50, 51, 53 |
| S10 | Adjust | Plan change / overload | 52 |
| S11 | Recover | Post-workout / refuel | 13, 14, 16, 41 *(post)* |
| S12 | Recover | Light acknowledgment | 15 |
| S13 | Recover | Planned recovery day | 27 |
| S14 | Recover | Body-led / sleep-first | 28, 29 |
| S15 | Steady Day | Default calm | 18, 22, 55, 58 |
| S16 | Steady Day | Morning (incl. walk start) | 23, 24, 25, 26 |
| S17 | Steady Day | Opportunity | 20, 59 |
| S18 | Steady Day | Work done / simple day | 17, 19, 57 |
| S19 | Steady Day | Reset | 21 |
| S20 | Steady Day | Evening calm | 30, 34 |
| S21 | Steady Day | Urgent nutrition *(4 gates)* | 38, 54, 56 |
| S22 | Wind Down | Close out / sleep / rebuild | 31, 32, 33, 37 |
| S23 | Wind Down | Protect tomorrow | 35, 36 |
| S24 | Heat & Sauna | Pre / during / post | 44, 45, 46, 47, 48, 39 |

**24 named product scenarios** (S1–S24) across **7 families**. All V4 fuel/hydration paths route as **tones** — no eighth family.

---

## Model comparison

### 1. Current model (V4)

| Dimension | Count |
|-----------|-------|
| Technical scenarios | **59** |
| Active narrative families | **14** |
| Merge-candidate families | **4** |
| Total family definitions | **18** |
| User mental model jobs | **10** (documented) |
| Documented "you're fine" variants | **~6** |
| Documented "wind down" variants | **~4** |

**Problem:** Family count exceeds what users can distinguish. Copy team maintains parallel storylines. QA combinatorics explode. Onboarding can't explain 14 stories.

---

### 2. Proposed model (V5)

| Dimension | Count |
|-----------|-------|
| Internal triggers (unchanged capability) | **59** *(implementation may still use these)* |
| **Product scenarios** (family + tone) | **23** |
| **Visible narrative families** | **7** *(8 pre-challenge)* |
| Tone variations per family (avg) | **3** |
| User mental model jobs | **8** *(aligned 1:1 with families)* |

**V5 family ↔ mental model mapping:**

| V5 family | Mental model job |
|-----------|------------------|
| In Session | Guide an active workout |
| Get Ready | Prepare for a workout |
| Adjust | Pull back when plan is too ambitious |
| Recover | Recover after work / easy day |
| Steady Day | Tell you the day is fine |
| Wind Down | Protect tonight & tomorrow *(incl. eat/drink rebuild)* |
| Heat & Sauna | Guide heat exposure |

*Eat/drink is a tone inside Get Ready, Recover, Wind Down, or Steady Day — not an eighth family.*

---

## Benefits

### Easier copy

- **One copy bible per family** (8 chapters, not 14).
- Tones are **intensity modifiers**, not new story arcs — writers adjust adverbs, not narratives.
- Today/Coach split stays: writers produce **8 × 2 = 16 base templates** + tone variants, vs ~28+ disconnected templates today.
- Eliminate duplicate lines: "wind down," "protect tomorrow," "protect tonight's sleep" consolidate under **Wind Down** with three tones.

### Fewer overlaps

- **Steady Day** absorbs 6 "you're fine" families — users stop seeing contradictory calm messages.
- **Recover** absorbs planned + body-led recovery — one purple story, not two.
- **Get Ready** absorbs prep + sequencing + pre-nutrition — one yellow story before sessions.
- **Nutrition routing rules** prevent fuel/hydration from spawning a third card when Get Ready or Recover already leads.

### Easier testing

- QA matrix: **7 families × ~3 tones × 2 surfaces ≈ 42 core cases** (plus edge routing), down from 59+ scenario-first tests.
- Contract tests validate **family + tone + forbidden overlaps**, not 59 isolated titles.
- Narrative auditor checks: *"Does this moment belong to exactly one V5 family?"*

### Easier onboarding

- Explain Coach in **30 seconds:** seven things we might tell you, one at a time.
- Onboarding carousel: **7 panels**, not 14.
- Help center: one article per family; tones are sections, not articles.

### Stronger user mental model

- **Family names match jobs** — no gap between "what product says" and "what user remembers."
- **Steady Day as default** sets expectation: Coach is quiet unless something matters.
- **Wind Down names tomorrow** when stake exists — one evening story with increasing urgency, not three evening families.

---

## What we deliberately do not lose

| Capability | V5 preservation |
|------------|-----------------|
| Live session coaching | In Session |
| Prep + fuel + hydration before sessions | Get Ready (+ nutrition tone) |
| Readiness / plan adjustment | Adjust |
| Post-workout refuel | Recover |
| Recovery & sleep-led days | Recover |
| Calm / opportunity / reset days | Steady Day (tones) |
| Evening & tomorrow protection | Wind Down (tones) |
| Sauna-specific guidance | Heat & Sauna |
| Standalone eat/drink urgency | Steady Day · urgent tone *(rare)* + Get Ready / Recover / Wind Down tones |
| Multi-event sequencing (sauna → ride) | Get Ready · sequence tone |
| Today tactical vs Coach interpretive | Unchanged surfaces |
| Skip/miss anti-guilt | Steady Day · reset tone |
| Small session acknowledgment | Recover · light tone |

---

## Priority hierarchy (V5 — unchanged logic, cleaner labels)

When multiple triggers fire, **first matching family wins:**

1. **In Session** — live activity
2. **Recover** — meaningful work just finished (post window)
3. **Get Ready** — prep window or imminent session
4. **Adjust** — readiness/plan challenge (if not live)
5. **Heat & Sauna** — heat in prep/live/post (heat-specific framing)
6. **Recover** — body-led / recovery day (whole-day)
7. **Wind Down** — evening + protective need
8. **Nutrition** — standalone critical gap
9. **Steady Day** — default

*Nutrition often subordinates to 2–7 as a tone rather than winning slot 8.*

---

## Challenge review: Nutrition as family (not top-level)

**Assumption tested:** Nutrition is **not** a V5 family. It absorbs into **Get Ready**, **Recover**, and **Wind Down** as a **tone**. Standalone Nutrition is allowed only when all four gates pass:

1. No workout context (no live session, prep window, or consequential training ahead)
2. No recovery context (no post-workout window, recovery-led day, or meaningful load absorption)
3. No evening protection context (not wind-down / protect-tomorrow window)
4. Nutrition gap is **severe** (not “a little behind”)

**Verdict:** Standalone Nutrition fails the 5% bar. **Convert to tone only.** V5 becomes **7 families**.

---

### V4 nutrition-touching scenarios → absorption map

| V4 # | Scenario | Absorbs into | Standalone under 4 gates? |
|------|----------|--------------|---------------------------|
| 6 | Fuel/hydration during active session | **In Session** · nutrition tone | No — live workout |
| 8 | Prep fuel/hydration gap | **Get Ready** · nutrition tone | No — prep window |
| 11 | Sequence (fuel before training) | **Get Ready** · sequence + nutrition | No |
| 13 | Post-workout (refuel need) | **Recover** · refuel tone | No — recovery context |
| 14 | Late hard post-workout | **Recover** · refuel tone | No — recovery + evening overlap → Recover leads |
| 33 | Empty evening hydration/fuel branch | **Wind Down** · rebuild tone | No — evening |
| 37 | Protect tomorrow rebuild basics | **Wind Down** · rebuild tone | No — evening/tomorrow |
| 38 | Hydration-led day story | **Recover** or **Get Ready** *(see below)* | **Rarely** |
| 39 | Prep heat + critical hydration | **Heat & Sauna** · hydrate-first tone | No |
| 40 | Hydration during session | **In Session** · nutrition tone | No |
| 41 | Fuel-led day story | **Get Ready** / **Recover** / **Wind Down** | **No** — engine requires context |
| 42 | Fuel before training | **Get Ready** · nutrition tone | No |
| 43 | Fuel prep presentation | **Get Ready** · nutrition tone | No |
| 48 | Hydrate around heat | **Heat & Sauna** · hydrate-first tone | No |
| 54 | Critical hydration/fuel | Parent family · **urgent** nutrition tone | **Rarely** |
| 56 | Contextual fallback hydration | **Steady Day** · urgent nutrition tone | **Borderline** |

**Count:** 16 V4 scenario paths touch nutrition as primary or co-primary messaging.

---

### Engine reality (why standalone almost never wins)

Current behavior already treats nutrition as **contextual**, not **ambient**:

**Fuel candidate** does not fire unless at least one of: hard activity soon, hard tomorrow, high-load day, post-training refuel need, or severe readiness risk. An empty afternoon with low calories and **no workout** → fuel story **does not run**.

**Hydration candidate** requires `hydrationCanLeadAsPrimary`, which needs heat soon, hard/endurance within 90 minutes, **or** dehydration risk indicators — and those indicators are tied to **completed load**, **high strain**, or **endurance within 4 hours**. Pure “rest day, forgot water” without load → hydration **does not lead**.

**Product implication:** The engine was already designed so nutrition **supports** a frame (prep, recover, protect), not **replaces** it. A top-level Nutrition family fights the architecture.

---

### Scenarios that still *might* need standalone Nutrition

Under the strict four gates, only these edge paths remain:

| Candidate | Why borderline | Recommended routing |
|-----------|----------------|---------------------|
| **38** Hydration-led | Only fires with load/strain/endurance/heat — all imply another frame | **Recover** (post-load) or **Get Ready** (endurance soon) |
| **54** Critical fuel/hydration | Usually co-occurs with prep, heat, or readiness | Parent family · **urgent** tone |
| **56** Fallback hydration | No workout/recovery/evening if midday, empty calendar | **Steady Day** · **urgent nutrition** tone if severe; default calm if moderate |

**Estimated V4 scenarios needing true standalone Nutrition family: 0–1** (not 3–5).  
Scenario **56** severe midday dehydration on an empty rest day is the only plausible orphan — and it reads better as **Steady Day · urgent** (“Fluids need attention”) than as an eighth family.

---

### Frequency estimate: how often would standalone Nutrition surface?

| User archetype | Nutrition as **tone** (any family) | Nutrition as **standalone family** |
|----------------|--------------------------------------|-------------------------------------|
| Trains 3–4× / week | **35–45%** of days (prep + post refuel tones) | **<0.5%** |
| Trains 1–2× / week | **15–25%** of days | **<1%** |
| Recovery / rest focused | **5–10%** (load-linked hydration only) | **1–2%** |
| No planned activity, logs lightly | **2–5%** (severe gap only) | **1–3%** |
| **Blended active user (weighted)** | **~25–35%** of user-days | **~1–2%** |

**Coach opens per day** (user views Today/Coach): assume 1–3 meaningful Coach surfaces/day.

| Metric | Estimate |
|--------|----------|
| User-days where nutrition messaging appears (any form) | **~30%** |
| User-days where nutrition **leads** the story (tone within winning family) | **~12–18%** |
| User-days where **standalone Nutrition family** would lead | **~1–2%** |
| Share of all Coach impressions that are standalone Nutrition | **<3%** |

**5% threshold:** Failed. Standalone Nutrition is **not** justified as a family.

Even when users **need** to eat or drink, the **frame** is almost always:

- *Before* → Get Ready  
- *After* → Recover  
- *Tonight* → Wind Down  
- *Severe, nothing else* → Steady Day · urgent tone (not a new family)

---

### Revised tone model (Nutrition as modifier)

| Tone | Label | When | Today example |
|------|-------|------|---------------|
| **nutrition** | Standard | Gap matters inside parent frame | Eat a little and hydrate before you go |
| **refuel** | Recover | Post-workout absorption | Refuel and rehydrate, then keep the rest easy |
| **rebuild** | Wind Down | Evening/tomorrow basics gap | Rebuild basics before tomorrow |
| **urgent** | Steady Day | Severe gap, no other frame | Fluids need attention *(only if 4 gates pass)* |

In Session and Heat & Sauna keep **sip / hydrate-first** copy as local variants — not a Nutrition family.

---

### Updated V5 model (post-challenge)

| | Before challenge | After challenge |
|---|------------------|-----------------|
| Visible families | 8 | **7** |
| Product scenarios | 24 | **24** *(no standalone Nutrition scenario)* |
| Nutrition standalone | Allowed (slot 8) | **Removed** — tone only |

**Seven families:**

1. In Session  
2. Get Ready  
3. Adjust  
4. Recover  
5. Steady Day  
6. Wind Down  
7. Heat & Sauna  

**Recommendation:** **Convert Nutrition from family to tone.** Do not teach users an eighth Coach mode for eat/drink — teach them that **Get Ready / Recover / Wind Down** already cover it, with **Steady Day** for the rare severe orphan.

---

### Priority hierarchy (revised — no Nutrition slot)

1. In Session  
2. Recover *(incl. refuel tone)*  
3. Get Ready *(incl. nutrition tone)*  
4. Adjust  
5. Heat & Sauna  
6. Recover *(body-led / planned recovery day)*  
7. Wind Down *(incl. rebuild tone)*  
8. Steady Day *(incl. urgent nutrition tone if 4 gates pass)*  

---

## Recommended next steps (product only)

1. **Copy audit** — map every live string to V5 family + tone; flag orphans.
2. **Design system** — 8 badge/color identities (V4 has more ambiguous overlap).
3. **QA contract** — rewrite narrative matrix around 24 product scenarios, not 59 technical IDs.
4. **Onboarding** — ship 8-panel "What Coach tells you" flow.
5. **Analytics** — instrument `family` + `tone` (not 59 scenario IDs) for product learning.
6. **Engineering alignment** — separate conversation; this doc does not prescribe refactor.

---

## Appendix: side-by-side

```
V4 (14 families)                    V5 (7 families)
─────────────────                   ─────────────────
Active Execution          ────────► In Session
Workout Preparation       ──┐
Day Sequencing            ──┼──────► Get Ready (+ nutrition tone)
Fuel (in prep)            ──┘
Dial Back the Plan        ────────► Adjust
Post-Workout Recovery     ──┐
Recovery Day              ──┼──────► Recover (+ refuel tone)
Recovery-Led Day          ──┘
After a Small Session     ── tone ─► Recover · light
All Clear                 ──┐
Good Window Today         ──┤
Morning Orientation       ──┼──────► Steady Day (+ urgent nutrition tone)
Plan Reset                ── tone ─┘
Evening Close-Out (calm)  ── tone ──┘
Evening Close-Out (prot.) ──┐
Protect Tomorrow          ──┴──────► Wind Down (+ rebuild tone)
Heat & Sauna              ────────► Heat & Sauna (+ hydrate-first tone)
Hydration (standalone)    ──┐
Fuel (standalone)         ──┴──────► (tones only — no family)
Empty Day with Context    ── remove ► (routed)
```

---

*V5 product model — conceptual redesign only. No code or tests modified.*
