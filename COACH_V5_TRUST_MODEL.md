# Coach V5 Trust Model

> **Purpose:** Determine which Coach moments **create or destroy** user trust — not just what users hear.  
> **Inputs:** `COACH_V5_FREQUENCY_MODEL.md` · `COACH_V5_PRODUCT_SIMPLIFICATION.md` · V4 decision map  
> **Core question:** Which **20% of Coach moments** generate **80% of user trust**?

---

## Executive answer

Trust is **not** distributed like frequency.

| Lens | What dominates |
|------|----------------|
| **Volume trust** (daily habit) | **Steady Day** — ~45–50% of impressions slowly builds “Coach knows when to shut up” |
| **Decision trust** (will I listen next time?) | **Adjust**, **In Session**, and **critical Get Ready** — ~15–20% of impressions, **~80% of trust at stake** |
| **Trust destruction** | One bad **Adjust** or **In Session** call outweighs weeks of Steady Day |

**The 80/20 trust moments** are not seven families — they are **~6 critical tones** inside three families:

1. **Adjust** · plan check + prep reduction  
2. **In Session** · cautious / depleted  
3. **Get Ready** · key session with readiness gap  
4. **Recover** · post-hard + recovery-led  
5. **Wind Down** · protect tomorrow  
6. **Steady Day** · *only when it correctly stays calm* (wrong Steady Day erodes volume trust)

Invest product priority in **getting rare moments right**, not in making Steady Day louder.

---

## How to read this model

### Trust dimensions

| Dimension | Meaning |
|-----------|---------|
| **Frequency** | How often this family leads (from frequency model) |
| **Risk if wrong** | Cost of a **false negative** (should have intervened) or **false positive** (intervened when calm was correct) |
| **Trust gain if right** | How much the user thinks “Coach gets me” after a correct call |
| **Trust loss if wrong** | How much the user thinks “Coach is noise / dangerous / doesn’t know my body” |
| **Product priority** | Where engineering, copy, and QA should spend marginal effort |

### Scale

| Level | Frequency | Risk / gain / loss |
|-------|-----------|-------------------|
| Very low | <2% | Negligible or transformational |
| Low | 2–8% | Minor or significant |
| Low–medium | 8–12% | Moderate |
| Medium | 12–18% | Meaningful |
| High | 18–25% | Strong |
| Very high | >35% | Dominant |

**Trust loss** uses **catastrophic** for moments that can end Coach credibility in a single session (injury risk, shame spiral, plan abandonment).

---

## Family-by-family trust profile

### 1. Steady Day

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **Very high** (~45–50%) | Default voice; heard most days, most opens |
| **Risk if wrong** | **Low–medium** | False alarm → alarm fatigue. False calm → missed intervention elsewhere |
| **Trust gain if right** | **Low–medium** | Quiet permission: “I’m okay.” Compounds over weeks |
| **Trust loss if wrong** | **Medium** | Crying wolf or nagging on calm days erodes habit trust slowly |
| **Product priority** | **P1 — Foundation** | Protect through **restraint**, not polish |

**Creates trust when:** User feels no pressure to optimize; Coach matches their lived sense of an ordinary day.  
**Destroys trust when:** Steady copy appears while body/plan clearly need Adjust or Recover; generic calm after user just logged hard work; urgent nutrition tone on Steady Day without real gap.

**Design rule:** Steady Day wins by **not competing**. Every unnecessary intervention elsewhere is a Steady Day failure.

---

### 2. Get Ready

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **High** (~16–19%) | Training days, prep windows, “setup later” mornings |
| **Risk if wrong** | **Medium–high** | Under-prepare → bad session. Over-prepare → anxiety before start |
| **Trust gain if right** | **Medium–high** | “Coach helped me show up ready” — practical, timely |
| **Trust loss if wrong** | **High** | Nagging countdown, wrong fuel/hydration urgency, ignoring readiness |
| **Product priority** | **P0 — Critical path** | Session entry is a conversion moment for Coach belief |

**Creates trust when:** Prep matches **this** session’s stakes — key ride gets structure; easy walk stays light; nutrition tone only when gap is real.  
**Destroys trust when:** Same prep intensity for walk and long ride; “eat before you go” when user already fueled; prep copy when Adjust should lead.

**Critical sub-moment:** **Get Ready · key session** + low readiness undertone → handoff to Adjust must be crisp.

---

### 3. Recover

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **High** (~17–20%) | Post-workout windows + recovery-led days |
| **Risk if wrong** | **Medium** | Under-recover → overtraining. Over-recover → guilt, lost momentum |
| **Trust gain if right** | **Medium–high** | Validates effort; gives permission to stop spending |
| **Trust loss if wrong** | **Medium–high** | “You should still push” after hard block; refuel nagging without load |
| **Product priority** | **P1 — High** | Second most common **training-adjacent** trust moment |

**Creates trust when:** Post-hard copy names absorption, not laziness; recovery-led day feels body-honest, not calendar-honest.  
**Destroys trust when:** Recover fires on light day (should be Steady); refuel tone without workout; conflicts with evening Wind Down stake.

**Critical sub-moment:** **Recover · post-hard** (first 90 min after meaningful load) — highest gain per impression in this family.

---

### 4. Wind Down

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **Medium** (~11–13%) | Evenings with sleep/tomorrow/load signals |
| **Risk if wrong** | **Medium** | False protect → preachy. Missed protect → tomorrow blow-up |
| **Trust gain if right** | **Medium–high** | “Coach saved tomorrow” — restraint at tired hours |
| **Trust loss if wrong** | **Medium–high** | Vague sleep advice; protect tomorrow when plan is empty |
| **Product priority** | **P1 — High** | Evening is when users are tired and judgment is fragile |

**Creates trust when:** Named stake (“protect tomorrow’s long run”); matches user’s felt fatigue; doesn’t moralize.  
**Destroys trust when:** Wind Down on calm evening (should be Steady · evening calm); generic “sleep more”; contradicts Recover still active post-workout.

**Critical sub-moment:** **Wind Down · protect tomorrow** — highest trust leverage in family.

---

### 5. In Session

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **Low–medium** (~8–10%; up to ~20% for live trackers) | Live window only |
| **Risk if wrong** | **Very high** | Body is under load; wrong cue → injury or blown session |
| **Trust gain if right** | **Very high** | “Coach saw me mid-effort” — embodied, immediate proof |
| **Trust loss if wrong** | **Catastrophic** | Micromanage, contradict sensation, miss depleted state |
| **Product priority** | **P0 — Critical path** | Highest per-moment trust leverage in product |

**Creates trust when:** One clear cue matches live limiter; cautious tone without panic; defers nutrition to brief tone, not second story.  
**Destroys trust when:** “Ease up” when user feels fine; numbers-chasing copy during limiter; Adjust duplicate card while live.

**Critical sub-moment:** **In Session · depleted / cautious** — single highest **trust gain** and **trust loss** density.

---

### 6. Adjust

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **Low** (~5–7%) | Must stay uncommon — rarity is part of credibility |
| **Risk if wrong** | **Very high** | Wrong plan change → bad training day or ignored real limiter |
| **Trust gain if right** | **Very high** | “Coach respected my body over my calendar” — defining moment |
| **Trust loss if wrong** | **Catastrophic** | Shame, plan abandonment, or pushing through when should dial back |
| **Product priority** | **P0 — Critical path** | Rarest high-stakes family; cannot sound like Steady or Get Ready |

**Creates trust when:** Clear alternative; no guilt frame; timing matches (morning warning vs prep-window reduction); user keeps agency.  
**Destroys trust when:** Adjust on good readiness; soft Adjust copy indistinguishable from Steady; repeated Adjust days without plan change pathway.

**Critical sub-moment:** **Adjust · prep-window reduction** — user is about to start; last chance to prevent trust-breaking session.

---

### 7. Heat & Sauna

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Frequency** | **Very low** (~1–2%) | Modality-specific |
| **Risk if wrong** | **High** (for heat users) · **Low** (for non-users) | Dehydration / heat stress; irrelevant for most |
| **Trust gain if right** | **Medium** | “Coach knows heat isn’t training” — niche but loyal |
| **Trust loss if wrong** | **High** (heat users) · **Low** (non-users) | Treating sauna like workout; missing hydration lead |
| **Product priority** | **P2 — Modality** | Correctness matters; don’t over-invest in prominence |

**Creates trust when:** Safety-first; distinct from Get Ready / Recover framing; hydration tone when warranted.  
**Destroys trust when:** Heat story leads for non-heat day; athletic intensity copy in sauna block.

---

## Summary table

| Family | Frequency | Risk if wrong | Trust gain if right | Trust loss if wrong | Product priority |
|--------|-----------|---------------|----------------------|---------------------|------------------|
| **Steady Day** | Very high | Low–medium | Low–medium | Medium | **P1 — Foundation** |
| **Get Ready** | High | Medium–high | Medium–high | High | **P0 — Critical path** |
| **Recover** | High | Medium | Medium–high | Medium–high | **P1 — High** |
| **Wind Down** | Medium | Medium | Medium–high | Medium–high | **P1 — High** |
| **In Session** | Low–medium | Very high | Very high | **Catastrophic** | **P0 — Critical path** |
| **Adjust** | Low | Very high | Very high | **Catastrophic** | **P0 — Critical path** |
| **Heat & Sauna** | Very low | High† | Medium | High† | **P2 — Modality** |

†Conditional on user having heat/sauna in plan.

---

## Rankings

### By frequency (what users hear)

| Rank | Family | Est. share |
|------|--------|------------|
| 1 | Steady Day | 45–50% |
| 2 | Recover | 17–20% |
| 3 | Get Ready | 16–19% |
| 4 | Wind Down | 11–13% |
| 5 | In Session | 8–10% |
| 6 | Adjust | 5–7% |
| 7 | Heat & Sauna | 1–2% |

*Same order as `COACH_V5_FREQUENCY_MODEL.md`.*

---

### By trust impact (per-moment + at-stake)

**Trust impact** = potential to change whether user listens next time.  
Scored 1–5 on gain and loss; **impact index** = max(gain, loss) × risk weight.

| Rank | Family | Impact index | Why |
|------|--------|--------------|-----|
| 1 | **In Session** | **5.0** | Live body + catastrophic loss |
| 2 | **Adjust** | **5.0** | Plan vs body + catastrophic loss |
| 3 | **Get Ready** | **3.8** | Session gate; high loss if mis-timed |
| 4 | **Recover** | **3.5** | Post-effort validation; guilt risk |
| 5 | **Wind Down** | **3.2** | Tomorrow stake at tired hours |
| 6 | **Steady Day** | **2.5** | Low per-moment; medium cumulative loss |
| 7 | **Heat & Sauna** | **2.0** | High for subset; irrelevant for most |

---

### By product value (where to invest marginal effort)

Combines **trust impact ÷ frequency** (leverage) with **downside if neglected**:

| Rank | Family | Product value | Rationale |
|------|--------|---------------|-----------|
| 1 | **Adjust** | **Highest leverage** | Low frequency × catastrophic downside |
| 2 | **In Session** | **Highest leverage** | Live proof of Coach; same catastrophic downside |
| 3 | **Get Ready** | **High** | Common + session entry; wrong prep ends belief early |
| 4 | **Recover** | **Medium–high** | Common; mostly right today; refuel tone is risk |
| 5 | **Wind Down** | **Medium–high** | Evening judgment calls; protect-tomorrow is memorable |
| 6 | **Steady Day** | **Medium (foundational)** | High volume; wins through silence and accurate calm |
| 7 | **Heat & Sauna** | **Medium (niche)** | Correct for heat users; don’t optimize globally |

**Product value ≠ frequency.** The best ROI is **P0 families** (Adjust, In Session, Get Ready), not Steady Day copy variants.

---

## The 80/20: which moments generate 80% of trust?

### Two types of trust (both matter)

```
┌─────────────────────────────────────────────────────────────────┐
│  HABIT TRUST (80% built by volume)                              │
│  Steady Day correct × ~9 opens/week × 52 weeks                  │
│  → "Coach is usually calm and I can ignore it safely"           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DECISION TRUST (80% built by rare moments)                     │
│  ~6 critical tones × ~3–4 impressions/week                      │
│  → "When it matters, Coach tells me the truth"                  │
└─────────────────────────────────────────────────────────────────┘
```

Users **stay** because of habit trust. Users **believe** because of decision trust.

---

### The ~20% of moments (~80% of decision trust)

Estimated **~18 leading impressions/week**. The **~4 critical impressions** (~22%) below carry **~80% of decision trust**:

| # | Moment | Family · tone | Est. weekly leads | Trust role |
|---|--------|---------------|-------------------|------------|
| 1 | **Dial back before start** | Adjust · prep reduction | ~0.4 | Prevent bad session; respect body |
| 2 | **Morning plan check** | Adjust · plan check | ~0.5 | Reframe day before commitment |
| 3 | **Ease up live** | In Session · cautious / depleted | ~0.8 | Embodied proof Coach works |
| 4 | **Key session prep** | Get Ready · key session | ~1.2 | Entry to hard work |
| 5 | **Post-hard absorption** | Recover · post-hard | ~1.5 | Validate effort + stop spending |
| 6 | **Protect tomorrow** | Wind Down · named stake | ~0.8 | Evening restraint |

**Subtotal:** ~5.2 impressions/week ≈ **29% of leads** — slightly above 20% because critical tones overlap high-intent opens.

If trimmed to strict **20% (~3.6 impressions/week)**, drop #5 and #6 partially → core triad remains:

**Adjust + In Session (depleted) + Get Ready (key session)** ≈ **~15–18% of impressions, ~65–75% of decision trust**.

Adding **Recover · post-hard** and **Wind Down · protect tomorrow** completes the **80%**.

---

### The ~20% that destroy 80% of trust

Trust destruction is **asymmetric** — one failure weighs more than one success.

| Failure mode | Family | Est. frequency of failure exposure | Destruction power |
|--------------|--------|-----------------------------------|-------------------|
| **Pushed through when should Adjust** | Adjust missed → Steady/Get Ready wrong | ~2–3% of weeks | **Weeks of credibility lost** |
| **Wrong live cue** | In Session | ~1% of sessions | **Immediate uninstall consideration** |
| **Alarm on calm day** | Steady Day false positive | ~5–10% of Steady leads | **Slow erosion** (death by 1000 nudges) |
| **Guilt refuel / over-prescription** | Recover · refuel tone | ~3–5% of Recover leads | **Medium erosion** |
| **Preachy evening** | Wind Down false positive | ~2–4% of Wind Down leads | **Medium erosion** |

**80% of trust destruction** comes from:

1. **Missed or soft Adjust** (should have dialed back)  
2. **Bad In Session call** (ease up / don’t ease up wrong)  
3. **Steady Day on a day that wasn’t steady** (cumulative)

---

## Trust creation vs destruction matrix

| Family | Primary trust **creator** | Primary trust **destroyer** |
|--------|--------------------------|----------------------------|
| Steady Day | Accurate calm over months | False calm; hidden urgency |
| Get Ready | Right prep for right session | Nagging; wrong intensity |
| Recover | Permission after real work | Guilt; refuel without cause |
| Wind Down | Named tomorrow stake | Generic sleep lecture |
| In Session | One true live cue | Contradicting body |
| Adjust | Body over calendar | Shame or false alarm |
| Heat & Sauna | Safety clarity | Training intensity framing |

---

## Recommended product priorities (actionable)

### P0 — Must never break (QA, copy review, regression tests)

| Family | Non-negotiable behaviors |
|--------|-------------------------|
| **Adjust** | Visually and verbally distinct from Steady/Get Ready; never guilt; fires before damage |
| **In Session** | Single cue; limiter-aware; no duplicate stories |
| **Get Ready** | Stakes-proportional; hand off to Adjust when readiness gap is real |

**Contract tests:** All matrix cases in `workoutPrep` (low readiness), `activeSession` (cautious/depleted), `recoveryNeeded` (Adjust branches).

### P1 — High volume, moderate stakes

| Family | Focus |
|--------|-------|
| **Recover** | Post-hard vs light session tone separation; refuel only with load |
| **Wind Down** | Named stake when tomorrow hard; calm → Steady not Wind Down |
| **Steady Day** | Default when uncertain; suppress rather than speculate |

### P2 — Niche correctness

| Family | Focus |
|--------|-------|
| **Heat & Sauna** | Modality-safe copy; don’t lead globally |

---

## Nutrition tones (trust modifier, not family)

Nutrition modifies trust **inside** parent families. Wrong nutrition tone destroys trust **in the parent moment**:

| Tone | Parent | Trust risk if wrong |
|------|--------|---------------------|
| nutrition (prep) | Get Ready | High — feels like nagging app |
| refuel | Recover | Medium–high — guilt after workout |
| rebuild | Wind Down | Medium — diet culture at night |
| urgent | Steady Day | **Very high** — breaks calm promise |

**Rule:** Nutrition tone failure = **parent family trust failure**. No separate nutrition trust bucket.

---

## Instrumentation (validate trust model in production)

| Event | Trust signal |
|-------|--------------|
| `coach_family` + `coach_tone` | Exposure to critical moments |
| `user_dismissed` / `user_tapped_through` | Engagement vs rejection |
| `plan_changed_after_adjust` | Adjust trust validated |
| `session_completed_after_in_session_cautious` | In Session trust validated |
| `next_day_open_after_wind_down` | Wind Down stickiness |
| `coach_muted` / `notifications_off` | **Trust collapse proxy** — segment by last family seen |

**Hypothesis to test:** Users who mute Coach within 7 days disproportionately saw **false-positive Adjust** or **wrong In Session** last — not Steady Day volume.

---

## Design principles (trust-first)

1. **Rare moments earn belief; common moments earn habit.** Optimize P0 before polishing Steady copy.
2. **Asymmetric trust.** One catastrophic In Session loss > ten Steady wins.
3. **Adjust and In Session must not rhyme.** If users confuse them with Steady/Get Ready, trust is already lost.
4. **Steady Day is trust through absence.** The best Steady Day is often the shortest.
5. **Protect the 6 critical tones.** They are the product’s trust engine; everything else is wrapper.

---

## One-page reference

| Family | Freq | Risk↓ | Gain↑ | Loss↓ | Priority | 80/20 bucket |
|--------|------|-------|-------|-------|----------|--------------|
| Steady Day | Very high | Low–med | Low–med | Med | P1 | Habit trust (volume) |
| Get Ready | High | Med–high | Med–high | High | **P0** | **Decision trust** |
| Recover | High | Med | Med–high | Med–high | P1 | **Decision trust** |
| Wind Down | Med | Med | Med–high | Med–high | P1 | **Decision trust** |
| In Session | Low–med | **Very high** | **Very high** | **Catastrophic** | **P0** | **Decision trust** |
| Adjust | Low | **Very high** | **Very high** | **Catastrophic** | **P0** | **Decision trust** |
| Heat & Sauna | Very low | High† | Med | High† | P2 | Niche |

**80% of decision trust ≈ Adjust + In Session + Get Ready (key) + Recover (post-hard) + Wind Down (protect tomorrow).**  
**80% of habit trust ≈ Steady Day correct by default.**  
**80% of trust destruction ≈ missed Adjust + wrong In Session + Steady false alarms.**

---

*Conceptual model. Pair with `COACH_V5_FREQUENCY_MODEL.md` for exposure rates and production telemetry targets.*
