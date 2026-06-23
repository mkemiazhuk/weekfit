# Coach V4 Narrative Families

> **Purpose:** Product audit — what stories the Coach is actually telling users.  
> **Source:** 59 technical scenarios from `COACH_V4_DECISION_MAP.md`, collapsed into human narrative families.  
> **Audience:** Product, design, content — not engineering.

---

# Active Execution

**User question:**  
*"What should I do right now in this session?"*

**Includes:** 1, 2, 3, 4, 5, 6

**Typical Today card:**
- Don't chase the numbers · Settle in before adding effort.
- Ease up now · Keep the next block lighter than usual.
- Keep the walk easy · Stay conversational the whole time.

**Typical Coach card:**
- The workout is going fine — no need to push harder now
- This is not the day to push
- Keep reserve for the rest of today, not just this block
- Keep this walk light · Stay conversational, stop early if needed

**Why this family exists:**  
The user is mid-activity. The Coach's job is pacing and restraint — help them finish usefully without turning the session into extra stress.

**How it differs from neighbors:**
- vs **Workout Preparation:** execution is *during*; prep is *before*
- vs **Post-Workout Recovery:** recovery is *after* meaningful load
- vs **Dial Back the Plan:** execution assumes the session continues; dial-back questions whether it should

**Potential overlap:**
- **Dial Back the Plan** when readiness is critical mid-session (4, 2)
- **Hydration / Fuel** when nutrition gaps shape live guidance (6)
- **Heat & Sauna** when the active session is sauna (46)

**Recommendation:** **Keep** — core Coach job. Merge internal variants (normal vs cautious vs light movement) into one user-facing family with tone shifts, not separate product stories.

---

# Workout Preparation

**User question:**  
*"How do I arrive ready for what's next?"*

**Includes:** 7, 8, 10, 12, 43

**Typical Today card:**
- Prepare for the start · Eat lightly and hydrate before you go.
- Prepare for the start · Eat a little and hydrate before you go.
- Set up the ride properly · Keep the day pointed at the work.

**Typical Coach card:**
- You can move without rushing
- A little fuel now will help later
- Start easy and let the first minutes confirm how the body responds
- Keep the gap calm, arrive fed enough

**Why this family exists:**  
There is a meaningful session ahead (soon or later today). The Coach helps the user show up fed, hydrated, and calm — not hyped or depleted.

**How it differs from neighbors:**
- vs **Active Execution:** prep is anticipatory; execution is live
- vs **Fuel / Hydration:** prep is session-framed; fuel/hydration can stand alone without a workout context
- vs **Day Sequencing:** prep is about one session; sequencing is about order of multiple events

**Potential overlap:**
- **Fuel Support** and **Hydration Support** when gaps are the main message (8, 43)
- **Heat & Sauna** when the upcoming activity is sauna (45)
- **Dial Back the Plan** when readiness warning fires in prep window (9 — listed there but surfaces here)

**Recommendation:** **Keep**, but **simplify** copy tiers. Users don't need distinct stories for "baseline prep," "fuel gap prep," and "primary session protection" — they need one prep story with stronger nutrition emphasis when relevant.

---

# Dial Back the Plan

**User question:**  
*"Should I still do today's workout as planned — and if so, how hard?"*

**Includes:** 4, 9, 50, 51, 52, 53

**Typical Today card:**
- Manage intensity · Readiness sets the ceiling.
- Ease up now · Keep the next block lighter than usual.
- Reduce [activity] intensity

**Typical Coach card:**
- Readiness lowers today's ceiling
- Take [activity] easier than planned, keep the first 10–15 minutes easy
- Keep the run, lower the ceiling · Warm-up decides how much effort belongs today
- Plan should change given how you're recovering

**Why this family exists:**  
Signals say the plan is ambitious relative to sleep, recovery, or accumulated load. The Coach negotiates between keeping the session and protecting the body.

**How it differs from neighbors:**
- vs **Workout Preparation:** prep assumes the session happens; dial-back questions intensity or viability
- vs **Recovery-Led Day:** dial-back is workout-specific; recovery-led is whole-day posture
- vs **Protect Tomorrow:** dial-back is about *today's* session; tomorrow protection is about *tonight* and *next day*

**Potential overlap:**
- **Active Execution** when warning fires during live session (2, 4)
- **Workout Preparation** when warning fires in prep window (9)
- **Morning Orientation** when warning fires at 7am for evening workout (50)

**Recommendation:** **Keep** as one family, **merge** morning vs prep-window vs mid-session variants. User hears one story: *"Your ceiling is lower today — adjust before you pay for it."*

---

# Day Sequencing

**User question:**  
*"I have multiple things today — what should I do first, and what should I stay easy on?"*

**Includes:** 11, 49

**Typical Today card:**
- Fuel now, keep the heat easy · The heat comes before the real work.
- Do not let sauna steal the ride
- Sauna changes the rest of today · Keep the rest of the day easy.

**Typical Coach card:**
- Sauna is the risky part before the ride — keep it conservative
- Eat now, then keep the gap calm so you're not flat when training starts
- Heat is useful only if it doesn't steal from training

**Why this family exists:**  
The user's day has competing demands (meal, sauna, training). The Coach explains order and tradeoffs — not just "prep for X."

**How it differs from neighbors:**
- vs **Workout Preparation:** sequencing is multi-event; prep is single-session
- vs **Heat & Sauna:** sequencing is about heat *before* training; heat family is about heat itself
- vs **Protect Tomorrow:** sequencing is same-day ordering

**Potential overlap:**
- **Heat & Sauna** (49)
- **Workout Preparation** (11 often reads like prep)
- **Fuel Support** when meal timing is the lever

**Recommendation:** **Keep**, but **Rare** — high value when triggered, confusing if copy feels like generic prep. Consider surfacing only when sequence is genuinely non-obvious (heat + hard training same day).

---

# Post-Workout Recovery

**User question:**  
*"I just finished something meaningful — what should I do now?"*

**Includes:** 13, 14, 16, 47

**Typical Today card:**
- Recovery leads now · Take the next hour easy — no extra load.
- Protect the work you just did · Keep protein and fluids light, then let sleep take over.
- After sauna — drink and rest

**Typical Coach card:**
- Recovery should lead the rest of today
- Refuel and rehydrate, then keep the rest of the day easy
- Make sleep part of recovery after long work
- Drink water and keep the evening calm

**Why this family exists:**  
Hard work is banked. The Coach shifts from performance to absorption — food, fluids, calm, sleep — so the training actually counts.

**How it differs from neighbors:**
- vs **After a Small Session:** post-workout is for meaningful load; small session is acknowledgment only
- vs **Evening Close-Out:** post-workout is training-triggered; evening is time-triggered
- vs **All Clear:** post-workout still asks for action; all clear says nothing needs fixing

**Potential overlap:**
- **Fuel / Hydration** when refuel is the main ask
- **Heat & Sauna** post-sauna (47)
- **Protect Tomorrow** when hard evening session + big day tomorrow (14)

**Recommendation:** **Keep** — distinct user moment. **Simplify** strength vs endurance vs sauna post-copy into one recovery story with activity-aware bullets, not separate families.

---

# After a Small Session

**User question:**  
*"I logged something short — does that change my day?"*

**Includes:** 15

**Typical Today card:**
- Small session logged · Keep the next block steady.

**Typical Coach card:**
- It was short enough that it does not change the whole day
- Good, but do not turn a small recovery action into a bigger task

**Why this family exists:**  
Prevents over-coaching after minor activity. Reassures without launching full recovery mode.

**How it differs from neighbors:**
- vs **Post-Workout Recovery:** no recovery alarm, no refuel urgency
- vs **All Clear:** acknowledges the log; all clear ignores it

**Potential overlap:**
- **All Clear** when user forgets the small session happened
- **Light Movement** active stories if session still live

**Recommendation:** **Merge** into **All Clear** or **Post-Workout Recovery** as a tone variant ("light acknowledgment"). Not worth a standalone family in the user's mental model.

---

# All Clear

**User question:**  
*"Is anything wrong? Do I need to change anything?"*

**Includes:** 17, 18, 19, 22, 30, 55, 57, 58

**Typical Today card:**
- Nothing needs fixing · The day is unfolding calmly.
- No changes needed · Keep moving at your usual rhythm.
- Keep the day simple · Protect the work already done.
- No pressure yet · Keep fuel, fluids, and energy steady.
- The work is done · Nothing important needs protecting.

**Typical Coach card:**
- Nothing needs fixing · The day is unfolding without overload signs
- You are ready for a normal day
- Keep the rest of the day simple and let recovery continue in the background
- No urgent move is needed

**Why this family exists:**  
Most days should feel calm. The Coach validates that the user doesn't need to optimize, compensate, or stress.

**How it differs from neighbors:**
- vs **Good Window Today:** all clear is permission to stay steady; good window is permission to optionally push
- vs **Morning Orientation:** all clear is status; morning is about starting rhythm
- vs **Evening Close-Out:** all clear evening says "steady"; close-out says "wind down"

**Potential overlap:**
- **Morning Orientation** (25 stable morning)
- **Evening Close-Out** (30 baseline evening)
- **After a Small Session** (15)
- **Recovery Day** when day type is recovery but tone is calm (27)

**Recommendation:** **Keep** — this should be the **default voice** of the Coach. **Simplify** aggressively: users currently see ~8 variants of "you're fine" that read similarly.

---

# Good Window Today

**User question:**  
*"Today's a good day — should I do more?"*

**Includes:** 20, 59

**Typical Today card:**
- Good window today · Use it calmly.
- Strong recovery day · (open day messaging)

**Typical Coach card:**
- This is one of the better recovery windows — room for meaningful work, but nothing to force
- Keep the day flexible

**Why this family exists:**  
Positive opportunity without pressure. Counterweight to all the "hold back" messaging.

**How it differs from neighbors:**
- vs **All Clear:** good window invites optional ambition; all clear invites steadiness
- vs **Workout Preparation:** good window is open-ended; prep is session-specific

**Potential overlap:**
- **Morning Orientation** on strong mornings
- **All Clear** — users may not hear the difference

**Potential overlap risk:** **High** — "Good window" vs "Ready for a normal day" vs "Recovery remains strong" blur together.

**Recommendation:** **Merge** with **All Clear** as an optional upbeat tone, OR **remove** as separate surfacing unless user has no plan and explicitly high readiness. Rarely needs its own card.

---

# Morning Orientation

**User question:**  
*"How should I start today?"*

**Includes:** 23, 24, 25, 26

**Typical Today card:**
- Good start to the day · Take the walk easy — that is enough for now.
- Recovery remains strong · You can keep a normal rhythm for now.
- A calm day is unfolding · Keep the day steady.
- Ease into the morning · Start with the walk, then reassess.

**Typical Coach card:**
- Good start to the day · You can ease into the day
- You are ready for a normal day
- Good moment for light movement
- Start with the walk, keep it comfortable, then reassess

**Why this family exists:**  
Morning is psychologically distinct — users decide rhythm before the day accelerates. Coach sets tone: calm, not urgent.

**How it differs from neighbors:**
- vs **All Clear:** morning is time-of-day specific; adds "how to enter the day"
- vs **Workout Preparation:** morning orients the whole day; prep is session-specific
- vs **Recovery Day:** morning orientation can happen on any day type

**Potential overlap:**
- **All Clear** (25 stable morning = same story)
- **Morning walk start** (24) vs **Ease into morning** (26) — nearly identical user story
- **Dial Back the Plan** when morning setup includes readiness warning (50)

**Recommendation:** **Simplify** — merge 24, 25, 26 into one **Morning Start** story. Keep distinct from all-clear only if copy explicitly references upcoming walk/session.

---

# Recovery Day

**User question:**  
*"Today is supposed to be easy — am I doing it right?"*

**Includes:** 27

**Typical Today card:**
- Recovery day · Keep movement easy.

**Typical Coach card:**
- Keep recovery easy · The goal is to feel better afterward, not fitter by force
- Today is built to absorb training stress, not create a new one

**Why this family exists:**  
Planner or program marked recovery. Coach reinforces restraint so easy days stay easy.

**How it differs from neighbors:**
- vs **Recovery-Led Day:** recovery day is intentional/planned; recovery-led is body-forced
- vs **Light Movement (Active Execution):** recovery day is whole-day framing; light movement is in-session

**Potential overlap:**
- **All Clear** when recovery day is uneventful
- **Morning Orientation** on recovery mornings

**Recommendation:** **Keep** — users who plan recovery days expect explicit validation. **Merge** with Recovery-Led Day only in copy tone, not in triggering logic.

---

# Recovery-Led Day

**User question:**  
*"My body is tired — should I push through or back off?"*

**Includes:** 28, 29

**Typical Today card:**
- Protect recovery · The body needs a calmer day.
- Sleep leads today · Lower the day and protect tonight.
- Keep the day calm

**Typical Coach card:**
- Fitness is not the issue today — sleep is the bottleneck
- Stop chasing extra work and make tonight the intervention
- The useful move now is to bring the day down

**Why this family exists:**  
Recovery score, sleep debt, or load says the day should shrink — regardless of what the plan says.

**How it differs from neighbors:**
- vs **Recovery Day:** recovery-led is reactive to signals; recovery day is plan-intentional
- vs **Dial Back the Plan:** recovery-led is whole-day; dial-back is session-scoped
- vs **Evening Close-Out:** recovery-led can happen at 10am; evening is time-bound

**Potential overlap:**
- **Sleep-Led Day** (29) vs **Protect Tonight's Sleep** (32) — same lever, different times
- **Protect Tomorrow** when recovery is low + hard tomorrow
- **Day decision frame overload** (52)

**Recommendation:** **Keep**, but **merge** sleep-led (29) with evening sleep (32) into one **Rest & Sleep Priority** family with time-appropriate copy. User doesn't distinguish "sleep leads today" from "protect tonight's sleep."

---

# Evening Close-Out

**User question:**  
*"The day is ending — how do I finish well?"*

**Includes:** 30, 31, 32, 33, 34

**Typical Today card:**
- Keep the evening steady · No single blocker is loud.
- Close the day · Sleep beats target chasing.
- Protect tonight's sleep · More load will not help.
- Keep the evening calm · No urgent move needed.
- The work is done · Enjoy the evening.

**Typical Coach card:**
- Keep food, fluids, and intensity calm so the day finishes cleanly
- Do not chase calories or water aggressively now — protect sleep
- Recovery comes first tonight — don't add anything extra

**Why this family exists:**  
Evening is when users make mistakes — chasing targets, adding sessions, scrolling instead of sleeping. Coach closes the loop.

**How it differs from neighbors:**
- vs **Protect Tomorrow:** close-out is about tonight's behavior; tomorrow protection is about next day's session
- vs **Post-Workout Recovery:** close-out is time-triggered; post-workout is event-triggered
- vs **All Clear:** close-out actively says "don't add"; all clear says "you're fine"

**Potential overlap:**
- **Protect Tomorrow** (35) — users hear "wind down" in both
- **Recovery-Led Day** sleep messaging (29, 32)
- **Empty evening branches** of 33 overlap with All Clear (57) and hydration/fuel

**Recommendation:** **Keep**, **merge** 30/34/57 into calm evening variant of All Clear. Reserve distinct **Close the Day** story for late-night target-chasing only (31).

---

# Protect Tomorrow

**User question:**  
*"I have something important tomorrow — what should I do tonight?"*

**Includes:** 35, 36, 37

**Typical Today card:**
- Protect tomorrow · Wind down — no extra load tonight.
- Protect tomorrow · Recovery starts tonight.

**Typical Coach card:**
- Tonight sets up tomorrow
- Recovery comes first tonight — don't add anything extra
- Protect tomorrow by rebuilding basics today
- Tomorrow includes a meaningful session — recovery, hydration, and fuel aren't where they should be yet

**Why this family exists:**  
Future training quality depends on tonight's choices. Coach makes the tradeoff explicit: stop spending now.

**How it differs from neighbors:**
- vs **Evening Close-Out:** tomorrow protection names the reason (next session); close-out is generic wind-down
- vs **Post-Workout Recovery:** tomorrow protection is forward-looking; post-workout is backward-looking
- vs **Dial Back the Plan:** tomorrow protection doesn't change today's plan — it protects the next day

**Potential overlap:**
- **Evening Close-Out** — very high; users cannot distinguish "wind down" from "protect tomorrow"
- **Recovery-Led Day** when recovery is the stated reason
- **Day Sequencing** when tomorrow is hard endurance (evening filter)

**Recommendation:** **Keep** — high product value for serious athletes. **Simplify** copy so it always names *what* tomorrow holds (run, long ride, etc.) or merge into Evening Close-Out when tomorrow isn't hard.

---

# Hydration Support

**User question:**  
*"Am I drinking enough — and does it matter right now?"*

**Includes:** 38, 39, 40, 48, 54 (hydration)

**Typical Today card:**
- Fluids need attention · Sip steadily through the rest of the day.
- Hydration matters before heat · Drink calmly before sauna.
- Top up water before heat · Sauna is recovery heat, not training.

**Typical Coach card:**
- Do not fall behind on fluids
- Fluids matter for the next decision — sip steadily now
- Water comes first before heat
- Do not start heat exposure dry

**Why this family exists:**  
Hydration is a lever users neglect. Coach surfaces it when timing, heat, training, or load makes fluids consequential — not as a daily nag.

**How it differs from neighbors:**
- vs **Fuel Support:** different intervention; often co-occur but distinct user action
- vs **Heat & Sauna:** hydration is the means; heat is the context
- vs **Workout Preparation:** hydration can appear without prep window

**Potential overlap:**
- **Heat & Sauna** (39, 44, 48) — users experience one "drink before sauna" story
- **Workout Preparation** (8) when both fuel and hydration missing
- **Active Execution** (40, 6) when live session needs sips

**Recommendation:** **Keep** as support family, not primary story unless critical. **Merge** heat-hydration (39, 44, 48) into **Heat & Sauna** for user-facing purposes; hydration standalone when no heat/training context.

---

# Fuel Support

**User question:**  
*"Have I eaten enough to do what I'm asking of my body?"*

**Includes:** 41, 42, 43, 54 (fuel)

**Typical Today card:**
- Energy needs a top-up · Eat before you ask for more effort.
- Prepare for the start · Eat a little and hydrate before you go.
- Make the next session easier to start

**Typical Coach card:**
- A little food would help right now
- Running on empty will catch up with you
- Eat before the session, not during it
- Drink 300–500 ml now and eat 30–60 g carbs before leaving

**Why this family exists:**  
Underfueling breaks sessions and recovery. Coach catches it before effort, not after failure.

**How it differs from neighbors:**
- vs **Hydration Support:** eat vs drink — users understand the distinction
- vs **Workout Preparation:** fuel can be standalone; prep bundles fuel with session framing
- vs **Post-Workout Recovery:** fuel support is often pre-effort or gap-fill; post-workout is refuel after load

**Potential overlap:**
- **Workout Preparation** (8, 43) — same Today card in practice
- **Dial Back the Plan** when underfueling contributes to readiness risk

**Recommendation:** **Keep**, but **never show separately from Workout Preparation** when a session is imminent. Standalone fuel story only when no workout context (rare).

---

# Heat & Sauna

**User question:**  
*"How do I use heat safely — before, during, and after?"*

**Includes:** 44, 45, 46, 47, 49

**Typical Today card:**
- Top up water before heat · Sauna is recovery heat, not training.
- Good window for recovery · Keep heat moderate and the rest calm.
- Keep the heat moderate · Leave before fatigue shows.
- Sauna changes the rest of today · Keep the rest of the day easy.

**Typical Coach card:**
- Before sauna — drink up · Sauna still stresses your body
- Keep the heat moderate · Right now the load is heat, not training
- Leave before you feel worn out
- After sauna — drink and rest · Don't do hard work right after sauna

**Why this family exists:**  
Users treat sauna like a workout or wellness luxury. Coach reframes it as recovery heat with hydration and moderation rules.

**How it differs from neighbors:**
- vs **Active Execution:** heat is not training — different pacing logic
- vs **Hydration Support:** heat gives *why* fluids matter
- vs **Post-Workout Recovery:** post-sauna is lighter-touch recovery

**Potential overlap:**
- **Hydration Support** (44, 48) — product should present as one heat story
- **Day Sequencing** (49) when sauna precedes training
- **Workout Preparation** (45) when in prep window

**Recommendation:** **Keep** — users understand sauna as distinct. **Merge** pre/during/post into one family with phase-appropriate copy (user knows they're in sauna).

---

# Plan Reset

**User question:**  
*"I missed something — should I make up for it?"*

**Includes:** 21

**Typical Today card:**
- Reset the day · One miss does not define it.

**Typical Coach card:**
- Missing one block does not define the day
- Do not double the workload to compensate
- Use the next useful choice to get back into rhythm

**Why this family exists:**  
Skipped workouts trigger guilt compensation. Coach explicitly blocks the "make up for it" impulse.

**How it differs from neighbors:**
- vs **All Clear:** reset acknowledges the miss; all clear ignores it
- vs **Dial Back the Plan:** reset is emotional/plan hygiene; dial-back is physiological

**Potential overlap:**
- **All Clear** if skip isn't surfaced
- **Recovery-Led Day** if user interprets miss as need to rest

**Recommendation:** **Keep** as a **tone variant** of All Clear, not standalone family — unless skip/miss is a primary user anxiety (then keep visible).

---

# Empty Day with Context

**User question:**  
*"Nothing is planned — but something still matters today."*

**Includes:** 33, 56, (partial 55, 58, 59)

**Typical Today card:**
- Day is already started · Keep food, fluids, and effort steady from here.
- Bring the basics back up · (hydration branch)
- Keep the next block easy · (recovery branch)

**Typical Coach card:**
- The day is already in motion — keep the next choice simple
- Fluids are behind for this point in the day
- No urgent workout move, but the day still has context

**Why this family exists:**  
Empty planner ≠ empty day. User may have logged activity, missed hydration, or finished hard work with nothing left scheduled.

**How it differs from neighbors:**
- vs **All Clear:** empty-with-context has a specific gap or history
- vs **Hydration / Recovery-Led:** those are limiter-specific; this is "something happened today"

**Potential overlap:**
- **All Clear**, **Hydration**, **Recovery-Led**, **Evening Close-Out** (33 branches) — engineering sees one candidate; user may hear four families

**Recommendation:** **Remove** as user-facing family — route branches to Hydration, Recovery-Led, All Clear, or Evening Close-Out. Users don't ask "empty day with context."

---

# Final Summary

## Counts

| Metric | Count |
|--------|-------|
| **Total technical scenarios** | 59 |
| **Total narrative families (proposed)** | 14 active + 2 merge candidates |

### Active families (keep as user-visible stories)

1. Active Execution  
2. Workout Preparation  
3. Dial Back the Plan  
4. Day Sequencing  
5. Post-Workout Recovery  
6. All Clear  
7. Morning Orientation  
8. Recovery Day  
9. Recovery-Led Day  
10. Evening Close-Out  
11. Protect Tomorrow  
12. Hydration Support  
13. Fuel Support  
14. Heat & Sauna  

### Merge / demote (not standalone in mental model)

- After a Small Session → merge into All Clear  
- Good Window Today → merge into All Clear (upbeat tone)  
- Plan Reset → tone variant of All Clear  
- Empty Day with Context → split across other families  

---

## Family frequency & importance

| Family | Frequency | Importance |
|--------|-----------|------------|
| Active Execution | Very Common | Critical |
| Workout Preparation | Common | Critical |
| All Clear | Very Common | Important |
| Post-Workout Recovery | Common | Critical |
| Morning Orientation | Common | Nice-to-have |
| Evening Close-Out | Common | Important |
| Hydration Support | Common | Important |
| Dial Back the Plan | Common | Critical |
| Recovery-Led Day | Common | Critical |
| Protect Tomorrow | Common (evening athletes) | Important |
| Heat & Sauna | Rare | Important |
| Fuel Support | Common | Important |
| Recovery Day | Rare | Important |
| Day Sequencing | Rare | Nice-to-have |
| Plan Reset | Rare | Nice-to-have |

---

## Product audit findings

### 1. Families that tell nearly the same story

| Group | Families | User-perceived sameness |
|-------|----------|-------------------------|
| "You're fine" | All Clear, Good Window, Morning stable (25), Steady day (22), No pressure yet (58), baseline Evening (30) | **Very high** — ~6 variants of calm |
| "Wind down" | Evening Close-Out, Protect Tomorrow, Recovery-Led (evening), Post-workout (late) | **High** — all say "don't add load tonight" |
| "Eat/drink before session" | Workout Prep, Fuel Support, Hydration Support, Heat pre-hydration | **High** when prep window open |
| "Go easier" | Dial Back, Active Execution (caution), Recovery-Led, Overload walk (5) | **Medium** — same advice, different triggers |
| "Recovery now" | Post-Workout, Recovery-Led, Recovery Day, After sauna | **Medium** — share "keep it easy" DNA |

### 2. Families users cannot distinguish

- **Morning Orientation** vs **All Clear** on calm mornings  
- **Protect Tomorrow** vs **Evening Close-Out** — both say wind down tonight  
- **Recovery Day** vs **Recovery-Led Day** — both say take it easy (plan vs body is invisible)  
- **Workout Preparation** vs **Fuel/Hydration** when prep card says "eat and hydrate"  
- **Good Window Today** vs **All Clear** — both feel like green light days  
- **Day Sequencing** vs **Workout Preparation** — "fuel now for later ride" reads as prep  

### 3. Families that are probably over-engineered

- **59 scenarios → 14+ families** — still too many for two surfaces (Today + Coach)  
- **Morning walk start (24)** vs **Ease into morning (26)** vs **Stable morning (25)** — three stories for "calm morning"  
- **Post-workout playbook variants (16)** — strength vs endurance vs heat post; user needs "recover now"  
- **Empty day evening (33)** — six internal branches users never see as distinct  
- **Sequence narratives (11)** — many IDs, one user question  
- **Today vs Coach intentional split** on active workouts — good design, but doubles scenario count in engineering without doubling user stories  

### 4. Families that should remain separate

- **Active Execution** — only family for live session; must stay tactically distinct on Today  
- **Dial Back the Plan** — trust-critical; user must hear "adjust" not "you're fine"  
- **Post-Workout Recovery** — clear life moment after hard work  
- **Heat & Sauna** — users have strong mental model; don't merge with generic workout  
- **Protect Tomorrow** — worth naming tomorrow's stake explicitly for committed athletes  
- **Plan Reset** — short, distinct emotional job (anti-guilt)  

### 5. Families that should never appear at the same time

| If this is showing… | Should NOT also show… | Why |
|---------------------|------------------------|-----|
| Active Execution | Workout Preparation, Post-Workout, All Clear | Live session owns the moment |
| Post-Workout Recovery | Workout Preparation, Active Execution | Temporal mutual exclusion |
| Dial Back the Plan | Good Window Today, Performance prep optimism | Contradictory permission |
| All Clear | Recovery-Led Day, Dial Back | Can't be "fine" and " struggling" |
| Protect Tomorrow | Good Window, Active Execution (evening) | Can't spend and protect simultaneously |
| Heat & Sauna (during) | Active Execution (training) | Sauna replaces training framing |
| Close the Day (late night) | Fuel/Hydration catch-up urgency | Chasing targets vs sleep |
| Recovery Day | Dial Back the Plan (same session) | Plan already says easy — don't also warn |

---

*Product audit derived from `COACH_V4_DECISION_MAP.md`. For user-facing mental model, see `COACH_V4_USER_MENTAL_MODEL.md`.*
