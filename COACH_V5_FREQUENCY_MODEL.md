# Coach V5 Frequency Model

> **Purpose:** Estimate what users **actually hear** — not what the engine *can* say.  
> **Inputs:** `COACH_V4_DECISION_MAP.md` (59 scenarios) · `CoachNarrativeMatrixFactory` (126 matrix cases) · V5 7-family model  
> **Question tested:** Is the expected order **Steady Day > Get Ready > Recover > In Session > Wind Down > Adjust > Heat & Sauna**?

---

## Executive answer

**Mostly yes on the ends, not fully in the middle.**

| Verdict | Families |
|---------|----------|
| **Confirmed** | Steady Day is **dominant** · Heat & Sauna is **exceptional** · Adjust is **uncommon** |
| **Partially confirmed** | Get Ready and Recover are **both common** — order **flips by persona** (often **Recover ≈ Get Ready**, not strict Get Ready > Recover) |
| **Rejected for default users** | **In Session > Wind Down** — only true for users who **open the app during most workouts** |
| **Recommended default ranking** | **Steady Day > Get Ready ≈ Recover > Wind Down > In Session > Adjust > Heat & Sauna** |

The hypothesis ranking is **directionally right** for product design (calm default, heat rare). It **overstates In Session** and **slightly overstates Get Ready over Recover** for a typical WeekFit user who opens the app before/after sessions more than during them.

---

## Methodology

Three lenses were combined — none alone is sufficient:

### 1. Time-budget lens

How many **waking hours per week** can each family *own* given engine priority rules?

| Family | Typical owning window | Hours/week (approx.) | Share of ~112 waking hrs |
|--------|----------------------|----------------------|---------------------------|
| Steady Day | Default when no stronger trigger | ~55–70 hrs | **49–63%** |
| Get Ready | Prep window + “setup later” on training days | ~8–14 hrs | **7–13%** |
| Recover | Post-workout 1–3h + recovery-led whole days | ~6–12 hrs | **5–11%** |
| In Session | Live activity only | ~3–5 hrs | **3–5%** |
| Wind Down | Evening protective (18:00–23:00, conditional) | ~4–8 hrs | **4–7%** |
| Adjust | Low readiness + planned work (morning + prep) | ~2–4 hrs | **2–4%** |
| Heat & Sauna | Heat planned/active/post | ~0.5–2 hrs | **<2%** |

*Assumptions: 4 training days/week, 60–75 min sessions, prep window ~90 min, post window ~2 hr.*

Time-budget alone **underweights In Session** (users cluster opens during workouts) and **overweights Steady Day** (users don't stare at Coach all day).

### 2. App-open lens (what users hear)

Each app open gets **one leading family**. Weighted by **when users typically open WeekFit**:

| Open moment | Share of weekly opens | Likely leading family |
|-------------|---------------------|------------------------|
| Morning (6–10) | ~30% | Steady Day, Recover (body-led), Adjust, Get Ready (training later) |
| Midday (11–15) | ~25% | Steady Day, Get Ready, Recover (post-morning workout) |
| Pre-workout (≤90 min) | ~10% | **Get Ready**, Adjust |
| During workout | ~8% | **In Session** |
| Post-workout (≤2 hr) | ~12% | **Recover** |
| Evening (18–23) | ~15% | Wind Down, Recover (late post), Steady Day (calm evening) |

*Assumptions: 2.5 opens/day × 7 days ≈ **18 opens/week**; training 3–4×/week.*

### 3. Scenario matrix lens (QA coverage ≠ production frequency)

The narrative matrix contains **~126 cases**. Distribution is **not** representative of live usage — it overweight **edge cases** for contract testing:

| Matrix group | Cases | Maps to V5 | QA weight | Est. production weight |
|--------------|-------|------------|-----------|-------------------------|
| Calm overview | 18 | Steady Day | 14% | **40–55%** |
| Recovery needed | 12 | Recover / Adjust | 10% | 8–12% |
| Workout prep | 16 | Get Ready | 13% | 12–18% |
| Active session | 14 | In Session | 11% | 5–10% |
| Post-workout | 10 | Recover | 8% | 10–15% |
| Rest after load | 6 | Recover / Steady | 5% | 5–8% |
| Evening wind-down | 6 | Wind Down | 5% | 6–10% |
| Tomorrow protection | 6 | Wind Down | 5% | 4–8% |
| Nutrition-led | 10 | *(tone)* | 8% | *(not a family)* |
| Hydration-led | 10 | *(tone)* | 8% | *(not a family)* |
| Sauna / heat | 6 | Heat & Sauna | 5% | **1–3%** |
| Sync / missing data | 12 | Steady / edge | 10% | 2–4% |

**Do not** infer production frequency from matrix counts. Use matrix to verify **coverage**, not **prevalence**.

---

## Persona models (leading family per app open)

### Persona A — Typical planner (default)

Trains **3×/week**, opens app **2–3×/day**, tracks workouts in planner, **does not** live-open during every session.

| Family | Leading impressions/week | % of opens | Tier |
|--------|--------------------------|------------|------|
| **Steady Day** | 8–10 | **44–52%** | Dominant |
| **Get Ready** | 3–4 | 17–21% | Common |
| **Recover** | 3–4 | 17–21% | Common |
| **Wind Down** | 2–3 | 11–14% | Regular |
| **In Session** | 1 | 5–6% | Regular |
| **Adjust** | 1 | 5–6% | Uncommon |
| **Heat & Sauna** | <0.3 | **1–2%** | Exceptional |

**Order:** Steady > Get Ready ≈ Recover > Wind Down > In Session > Adjust > Heat

### Persona B — Live session tracker

Trains **4–5×/week**, opens app **during** most sessions + post-workout.

| Family | Leading impressions/week | % of opens | Tier |
|--------|--------------------------|------------|------|
| **Steady Day** | 7–9 | 33–40% | Dominant |
| **Get Ready** | 3–4 | 14–19% | Common |
| **Recover** | 3–4 | 14–19% | Common |
| **In Session** | 3–5 | **17–24%** | Common |
| **Wind Down** | 2 | 10–12% | Regular |
| **Adjust** | 1 | 5% | Uncommon |
| **Heat & Sauna** | <0.3 | 1–2% | Exceptional |

**Order:** Steady > In Session ≈ Get Ready ≈ Recover > Wind Down > Adjust > Heat

*This is the only cohort where **In Session > Wind Down** holds reliably.*

### Persona C — Recovery-first / low readiness

Trains **2×/week**, frequent low recovery, evening-focused.

| Family | Leading impressions/week | % of opens | Tier |
|--------|--------------------------|------------|------|
| **Steady Day** | 6–8 | 35–42% | Dominant |
| **Recover** | 4–5 | **22–28%** | Common |
| **Wind Down** | 3–4 | 17–21% | Common |
| **Adjust** | 2 | 10–12% | Regular |
| **Get Ready** | 2 | 10–12% | Regular |
| **In Session** | 0.5 | 3% | Uncommon |
| **Heat & Sauna** | <0.2 | 1% | Exceptional |

**Order:** Steady > Recover > Wind Down > Adjust > Get Ready > In Session > Heat

---

## Blended population estimate (recommended planning numbers)

Weighted mix: **60% Persona A**, **25% Persona B**, **15% Persona C**.

| Rank | Family | Expected frequency (% of leading impressions) | Tier | Product importance | User emotional impact |
|------|--------|--------------------------------------------------|------|-------------------|----------------------|
| 1 | **Steady Day** | **45–50%** | **Dominant — most common** | High — defines default trust | Low–medium — relief, permission to not optimize |
| 2 | **Recover** | **17–20%** | **Common** | Critical — absorption determines adaptation | Medium — “job done, care for yourself” |
| 3 | **Get Ready** | **16–19%** | **Common** | Critical — session quality gate | Medium — anticipatory, mild urgency |
| 4 | **Wind Down** | **11–13%** | **Regular — not rare** | High — protects tomorrow & sleep | Medium–high — restraint at tired hours |
| 5 | **In Session** | **8–10%** | **Regular — not rare** | Critical — only live tactical family | **High** — immediate, embodied |
| 6 | **Adjust** | **5–7%** | **Uncommon — should be rare** | **Critical** — prevents bad training days | **High** — plan negotiation, vulnerability |
| 7 | **Heat & Sauna** | **1–2%** | **Exceptional — rare** | Important for heat users | Medium — safety clarity |

### Frequency tier definitions

| Tier | % of leading impressions | Product meaning |
|------|--------------------------|-----------------|
| **Dominant** | >35% | Default voice; shapes brand (“Coach is usually calm”) |
| **Common** | 12–25% | Regular part of training life; users must recognize it |
| **Regular** | 6–12% | Frequent enough to need distinct copy; not the default |
| **Uncommon** | 3–6% | Rare but must be trustworthy when it appears |
| **Exceptional** | <3% | Edge modality; must not steal attention from core loop |

---

## Hypothesis validation

### Proposed order

`Steady Day > Get Ready > Recover > In Session > Wind Down > Adjust > Heat & Sauna`

### Actual (blended)

`Steady Day > Recover ≈ Get Ready > Wind Down > In Session > Adjust > Heat & Sauna`

| Pair | Hypothesis | Finding |
|------|------------|---------|
| Steady Day on top | ✓ | **Strongly confirmed** — ~half of all leading impressions |
| Heat & Sauna last | ✓ | **Confirmed** — exceptional tier (<2%) |
| Adjust near bottom | ✓ | **Confirmed** — uncommon but high importance |
| Get Ready > Recover | ✓ (narrow) | **Split** — Get Ready wins on **training-heavy mornings**; Recover wins **post-workout + recovery-led days**. Blended: **Recover slightly ≥ Get Ready** |
| In Session > Wind Down | ✓ | **Rejected for default users** — In Session is **time-narrow**; Wind Down covers **more evenings**. **In Session > Wind Down only for Persona B** |

### Why Get Ready vs Recover is close

From the decision map:

| Effect | Pushes **Get Ready** | Pushes **Recover** |
|--------|---------------------|-------------------|
| Scenario **12** “Set up training properly” (training >4h away) | Inflates morning/ midday impressions on training days | — |
| Scenario **11** sequence prep | Adds non-prep-window setup | — |
| Post-workout candidate **13–14** | — | Owns 1–3 hr after every hard session |
| Recovery candidate **28–29** | — | Owns whole day when recovery low |
| **Priority:** postActivity intent filters to Recover | — | Wins contiguous post-workout opens |
| Nutrition as tone | “Eat before you go” **inside** Get Ready | “Refuel now” **inside** Recover |

**Product read:** Users hear **Get Ready before** the work and **Recover after** — similar weekly counts, different **times of day**.

### Why In Session is not above Wind Down (default)

| Factor | In Session | Wind Down |
|--------|------------|-----------|
| **Time window** | ~60–90 min × 3 days ≈ 4.5 hr/week | ~4–5 hr/evening × ~4 days with trigger ≈ 6–10 hr/week |
| **Open behavior** | Requires open **during** exertion | Evening opens are habitual (plan tomorrow, wind down) |
| **Engine priority** | Wins absolutely when live — but **only while live** | Wins when evening + sleep/tomorrow/load signals |
| **Matrix intent** | 14 cases test live ownership | 12 cases test evening/tomorrow |

**In Session feels louder** when it happens (tactical, LIVE badge) but **Wind Down wins more opens** for typical usage.

---

## V4 scenario → V5 family → frequency contribution

Which of the **59 technical scenarios** materially drive **leading-family** impressions (not tones):

| V5 family | Primary V4 scenario drivers | Est. share of scenario-triggered leads |
|-----------|----------------------------|----------------------------------------|
| Steady Day | 17, 18, 19, 20, 21, 22, 55, 57, 58, 59, 30, 34, 15 (light) | **~50%** |
| Get Ready | 7, 8, 10, 11, 12, 43 + prep tones | **~18%** |
| Recover | 13, 14, 16, 27, 28, 29 + refuel tones | **~19%** |
| Wind Down | 31, 32, 33, 35, 36, 37 | **~12%** |
| In Session | 1, 2, 3, 4, 5, 6 | **~9%** |
| Adjust | 9, 50, 51, 52, 53 | **~6%** |
| Heat & Sauna | 44, 45, 46, 47, 48, 49 | **~2%** |

Scenarios **38, 41, 42, 54, 56** (nutrition-primary) → **tones** inside families above; **<2%** change which family leads (per V5 challenge review).

---

## Product importance vs frequency (inverse pairs)

High-frequency families should **not** scream. Low-frequency families **must** land with clarity.

```
Frequency (what users hear)          Importance (what product must not break)
───────────────────────────          ────────────────────────────────────────
Steady Day        ████████████         Medium — trust through restraint
Recover           ████                 Critical — adaptation
Get Ready         ████                 Critical — session entry
Wind Down         ███                  High — sleep / tomorrow
In Session        ██                   Critical — live safety & pacing
Adjust            █                    Critical — plan integrity
Heat & Sauna      ▌                    Important — modality safety
```

**Design implication:** **Adjust** and **In Session** are heard less often but carry **disproportionate trust risk**. **Steady Day** is heard most often but must **never** feel like noise.

---

## Emotional impact by family

| Family | Dominant emotions | Failure mode if wrong |
|--------|-------------------|------------------------|
| **Steady Day** | Calm, permission, “I’m okay” | Alarm fatigue; crying wolf |
| **Get Ready** | Anticipation, readiness | Nagging; calendar countdown |
| **Recover** | Accomplishment, care | Guilt for stopping; over-prescription |
| **In Session** | Focus, restraint | Micromanagement; contradicting body |
| **Wind Down** | Closure, protection | Preachy; vague “sleep more” |
| **Adjust** | Respect, adaptation | Shame; plan abandonment |
| **Heat & Sauna** | Safety, moderation | Treating sauna like training |

---

## Nutrition tones (non-family) — frequency add-on

Nutrition **does not change** family rank but **modifies copy** on ~**25–35%** of non-Steady leads:

| Tone | Parent family | % of all opens (approx.) |
|------|---------------|--------------------------|
| nutrition (prep) | Get Ready | 8–12% |
| refuel | Recover | 6–10% |
| rebuild | Wind Down | 3–5% |
| urgent | Steady Day | 1–2% |

Users **hear** eat/drink often; they **rarely** hear it as a separate eighth story — consistent with V5 challenge review.

---

## Recommendations

### 1. Accept the revised default ranking

Plan copy, onboarding, and analytics around:

**Steady Day > Recover ≈ Get Ready > Wind Down > In Session > Adjust > Heat & Sauna**

### 2. Segment analytics for In Session vs Wind Down

Report **`persona_live_opens`** or **`opened_during_active_session`**. Without this, product will **think** In Session is under-delivered when it is **correctly time-bound**.

### 3. Do not optimize for matrix distribution

126 matrix cases **over-represent** nutrition (20), heat (6), sync (12) vs calm steady state (18). Frequency testing needs **simulated day timelines**, not scenario counts.

### 4. Protect uncommon high-importance families

**Adjust** (~6%) and **In Session** (~9%) need **distinct badges and copy** even though Steady Day dominates — users judge Coach trust on the **rare hard moments**.

### 5. Steady Day is the product

If Steady Day is **not** ~45%+ of leading impressions in production analytics, something is **over-coaching** — engine or user base skews more interventionist than intended.

---

## Validation checklist (production)

When instrumenting `coach_family` + `coach_tone`:

| Metric | Expected range | Red flag |
|--------|----------------|----------|
| `steady_day` lead rate | 40–55% | <30% (noisy Coach) or >65% (under-coaching on training days) |
| `get_ready` + `recover` combined | 30–40% | <20% for active athletes |
| `in_session` lead rate | 5–12% | >20% (opens skew live-only cohort) |
| `wind_down` lead rate | 8–15% | <5% (evening protection not firing) |
| `adjust` lead rate | 4–8% | >15% (readiness warnings too aggressive) |
| `heat_sauna` lead rate | 0.5–3% | >5% (heat over-indexed) |

---

## Summary table (final)

| Family | Expected frequency | Tier | Product importance | User emotional impact |
|--------|-------------------|------|-------------------|----------------------|
| **Steady Day** | **45–50%** of leading impressions | Dominant (most common) | High | Low–medium |
| **Recover** | **17–20%** | Common | Critical | Medium |
| **Get Ready** | **16–19%** | Common | Critical | Medium |
| **Wind Down** | **11–13%** | Regular | High | Medium–high |
| **In Session** | **8–10%** | Regular | Critical | **High** |
| **Adjust** | **5–7%** | Uncommon (should stay rare) | Critical | **High** |
| **Heat & Sauna** | **1–2%** | **Exceptional (rarest)** | Important (modality) | Medium |

**Hypothesis status:** ✓ Steady dominant · ✓ Heat exceptional · ✓ Adjust uncommon · ~ Get Ready vs Recover **persona-dependent** · ✗ **In Session > Wind Down** only for live-tracker cohort, **not** blended default.

---

*Conceptual model only. Validate against production `coach_family` telemetry when available.*
