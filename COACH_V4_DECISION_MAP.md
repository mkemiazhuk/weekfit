# Coach V4 Decision Map

> **Scope:** Documents **actual engine behavior** as implemented in `CoachEngineV3` → `CoachDayPriorityResolver` → `HumanCoachDecisionEngine` → `CoachFinalStoryBuilder` → `CoachTabPresentationResolver` / `CoachTodayTeaserBuilder`.  
> **Last audited:** 2026-06-22 against the working tree.

---

## How decisions are made

```
Input (brain, activities, nutrition, recovery, time)
  ↓
CoachDayPriorityResolver.resolve()
  • Builds ~20 priority candidates (each with focus, strength, limiter, scores)
  • Filters eligible set by CoachIntent (liveGuidance, postActivity, sleepPreparation, …)
  • Picks winner: max(decisionScore), tie-break insightScore → confidence
  • decisionScore = priorityScore×0.58 + insightScore×0.32 + uniquenessScore×0.10
  ↓
HumanCoachDecisionEngine.resolve()
  • CoachSituationStory.assess() — situation narrative layer
  • Overrides/supplements resolver copy for active sessions, heat, fuel, recovery day, etc.
  ↓
CoachFinalStoryBuilder.build()
  • Assigns CoachFinalStoryOwner
  • CoachV4ActivityPlaybook for activity-family copy (endurance, strength, sauna, recovery modality)
  ↓
CoachTabPresentationResolver / CoachTodayTeaserBuilder
  • Maps owner → CoachPresentationScenario
  • Today = compressed teaser (idea + action, ≤44/88 chars)
  • Coach tab = interpretation headline + read + recommendation + why rows
```

**Surfacing gate:** Coach card surfaces when `priority.level >= .useful` OR intervention gate passes. Quiet/baseline scenarios may render minimally.

**Presentation scenario** (`CoachPresentationSanitizer.resolveScenario`) can override raw owner for Today/Coach split — e.g. `stableDayOwnership`, `morningWalkStart`, `heatSafetyPrep`.

---

## Priority & owner reference

| Field | Values |
|-------|--------|
| **Focus** | `activeActivity`, `prepareForActivity`, `postActivityRecovery`, `recoveryNeeded`, `trainingReadinessWarning`, `tomorrowPlanRisk`, `eveningWindDown`, `hydrationBehind`, `fuelBehind`, `performanceReadiness`, `nextActivityLater`, `dailyOverview` |
| **Priority class** | `activeSession`, `performance`, `recovery`, `hydration`, `fueling`, `planChallenge`, `sleepPreparation`, `stable` |
| **Strength** | `low` → `medium` → `high` → `critical` |
| **Owner** | `activeActivity`, `pacingExecution`, `sustainableExecution`, `activityPreparation`, `postActivityRecovery`, `recovery`, `hydration`, `hydrationExecution`, `fuel`, `fuelingDuringActivity`, `tomorrowProtection`, `stableOverview`, `readiness` |

---

# Active workout

Live session owns the narrative whenever `activityContext.activeActivity != nil`. `CoachIntent.liveGuidance` restricts candidate pool to `focus == .activeActivity` (plus recovery/readiness warnings if no active candidate).

---

### 1. Control the session (normal execution)

| | |
|---|---|
| **Owner** | `activeActivity` (endurance/strength → may become `pacingExecution` / `sustainableExecution` via playbook) |
| **Priority** | `activeSession` / `activeActivity` / strength `medium`–`high` / limiter `timing` |
| **Trigger** | Active planned activity; no caution limiter (sleep, recovery, fatigue, hydration, fuel all OK) |
| **Why it wins** | `activeExecutionCandidate` score ~62; `liveGuidance` intent isolates active candidates; beats all non-active focuses |
| **Suppresses** | Prep, post-workout, stable overview, fuel/hydration-led day stories, tomorrow protection |
| **Today** | Idea: *Don't chase the numbers* · Action: *Settle in before adding effort.* · Color: green |
| **Coach** | Headline: *The workout is going fine — no need to push harder now* · Read: *The session is already doing its job — pushing harder now adds little and costs more.* · Rec: *Keep reserve for the rest of today, not just this block.* |
| **Example screenshot** | **LIVE** · Don't chase the numbers · Settle in before adding effort. |
| **User situation** | Mid-ride or mid-lift, recovery OK, no major limiters |

---

### 2. Keep this run easy (running + caution limiter)

| | |
|---|---|
| **Owner** | `activeActivity` or `pacingExecution` |
| **Priority** | `activeSession` / `activeActivity` / strength `high`–`critical` / limiter ≠ `timing` |
| **Trigger** | Active run/jog + any caution limiter: poor sleep, low recovery, high load, behind hydration/fuel, hard tomorrow |
| **Why it wins** | Score ~82+ when limiterRequiresCaution; running + limiter sets `runningCaution = true` |
| **Suppresses** | Normal "control session" copy; prep; stable day |
| **Today** | Idea: *Ease up now* · Action: *Keep the next block lighter than usual.* · Color: red (if `trainingReadiness`) else green |
| **Coach** | Headline: *This is not the day to push.* · Read: contextual (recovery <70% or tomorrow hard) · Rec: reserve-focused, not pace instructions |
| **Example screenshot** | **LIVE** · Ease up now · Keep the next block lighter than usual. |
| **User situation** | Running after short sleep or on a high-load day |

---

### 3. Keep recovery easy (active recovery modality)

| | |
|---|---|
| **Owner** | `activeActivity` → playbook `recoveryModality` |
| **Priority** | `activeSession` / `activeActivity` / strength `medium` / limiter varies |
| **Trigger** | Active activity classified as recovery (walk, stretch, yoga, mobility, breathing) |
| **Why it wins** | Active session always wins; kind `.recovery` lowers base score but still dominates non-active |
| **Suppresses** | Training-hero language; intensity coaching |
| **Today** | Idea: *Don't chase the numbers* (or heat variant) · Action: easy pacing · Color: green/purple |
| **Coach** | Headline: *Keep the walk easy* · Read: *Stay comfortable and finish with more control than you started.* |
| **Example screenshot** | **LIVE** · Keep the walk easy · Stay conversational the whole time. |
| **User situation** | Easy walk or mobility block in progress |

---

### 4. Active session — critical readiness during workout

| | |
|---|---|
| **Owner** | `activeActivity` / `pacingExecution` |
| **Priority** | `planChallenge` / `trainingReadinessWarning` / strength `critical` |
| **Trigger** | `trainingReadinessWarning` candidate dominant + active session; presentation checks `guidance.priority.strength == .critical` && limiter/focus readiness |
| **Why it wins** | Dominant readiness warnings filtered first in `candidatesForSelection`; active context keeps session owner |
| **Suppresses** | Optimistic "going fine" endurance copy |
| **Today** | Idea: *Ease up now* · Action: *Keep the next block lighter than usual.* · Color: red |
| **Coach** | Headline: *This is not the day to push.* · Read: *Keep the rest of the day easy* |
| **Example screenshot** | **LIVE** · Ease up now · Keep the next block lighter than usual. |
| **User situation** | User started workout despite low readiness signals |

---

### 5. Overload-aware light activity (active walk on overload day)

| | |
|---|---|
| **Owner** | `activeActivity` |
| **Priority** | `planChallenge` / `recoveryNeeded` via day decision frame |
| **Trigger** | `dayDecisionFrame.shouldOwnNarrative` + `planStatus.requiresPlanChange` + active light recovery modality |
| **Why it wins** | `overloadAwareActiveSessionStory` in assess() before generic active training |
| **Suppresses** | Normal active training coaching |
| **Today** | Teaser falls through to sanitized story title |
| **Coach** | Title: *Keep this walk light* · Read: *Today's load is already high. Keep walk easy…* |
| **Example screenshot** | **LIVE** · Keep this walk light · Stay conversational, stop early if needed. |
| **User situation** | Overload day, user started a walk while serious training still planned |

---

### 6. Fuel / hydration during active session

| | |
|---|---|
| **Owner** | `fuelingDuringActivity` or `hydrationExecution` |
| **Priority** | `fueling`/`hydration` / `activeActivity` focus retained |
| **Trigger** | Active session + fuel/hydration critically behind; limiter resolves to `.fueling` or `.hydration` in `activeSessionLimiter` |
| **Why it wins** | Active session owns narrative; limiter shapes execution copy, not replacement |
| **Suppresses** | Standalone fuel/hydration day stories |
| **Today** | Story-driven (may use engine title e.g. *Control the session*) |
| **Coach** | Nutrition-aware support actions; badge stays **LIVE** |
| **Example screenshot** | **LIVE** · Control the session · Execute the current block first. |
| **User situation** | Long endurance session, user hasn't eaten/drunk enough |

---

# Workout preparation

Prep window = `activityContext.preparingActivity != nil`. When a training activity is preparing, `candidatesForSelection` prefers timing candidates for that activity unless heat+critical hydration overrides.

---

### 7. Prepare for [activity] — baseline prep

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | `performance` / `prepareForActivity` / strength `medium` / limiter `timing` |
| **Trigger** | Activity in prep window; fuel & hydration OK; from `baselineCandidate` or `performanceReadinessCandidate` |
| **Why it wins** | Timing filter when no critical limiter; beats stable overview (~44 priority score) |
| **Suppresses** | `dailyOverview`, distant `nextActivityLater` calm copy |
| **Today** | Idea: *Prepare for the start* · Action: *Eat lightly and hydrate before you go.* · Color: yellow |
| **Coach** | Headline: *You can move without rushing* · Read: engine prep message · Rec: *Start easy and let the first minutes confirm how the body responds.* |
| **Example screenshot** | **PREP** · Prepare for the start · Eat lightly and hydrate before you go. |
| **User situation** | 15–45 min before strength session, basics on track |

---

### 8. Prepare for [activity] — fuel/hydration gap

| | |
|---|---|
| **Owner** | `activityPreparation` (fuel/hydration limiter may surface nutrition owner if nutritionShouldOwnInsight) |
| **Priority** | `performance` / `prepareForActivity` / strength `critical` / limiter `timing` or `.fueling`/`.hydration` |
| **Trigger** | Prep window + (`fuelIsBehind` OR `hydrationIsBehind`); from `commonSenseCandidate(.preActivityPreparation)` or dedicated fuel/hydration candidates |
| **Why it wins** | Prep common-sense scores 72–94; heat critical hydration hits 94 |
| **Suppresses** | Calm stable day; performance readiness reinforcement |
| **Today** | Idea: *Prepare for the start* · Action: *Eat a little and hydrate before you go.* (if underfueled) · Color: yellow |
| **Coach** | Headline: *A little fuel now will help later* (if fuel prep) · Read: *Drink 300-500 ml now and eat 30-60 g carbs before leaving.* |
| **Example screenshot** | **PREP** · Prepare for the start · Eat a little and hydrate before you go. |
| **User situation** | Workout in 30 min, user hasn't eaten or drank |

---

### 9. Training readiness warning — prep window plan change

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | `planChallenge` / `trainingReadinessWarning` / strength `high`–`critical` |
| **Trigger** | Prep activity + (`isVeryLowSleep` OR `recoveryIsLow`); `sameDayTrainingAdjustmentCandidate` or dominant readiness warning |
| **Why it wins** | Dominant readiness filter; score ~78+; beats baseline prep |
| **Suppresses** | Optimistic prep; performance readiness |
| **Today** | Resolver title: *Manage intensity* · *Readiness sets the ceiling.* |
| **Coach** | Title: *Reduce [activity] intensity* · Read: *Readiness lowers today's ceiling.* · Rec: *Take [activity] easier… first 10-15 minutes easy…* |
| **Example screenshot** | **ADJUST** · Manage intensity · Readiness sets the ceiling. |
| **User situation** | Hard session planned, recovery 48%, prep window open |

---

### 10. Primary session protection (day decision frame)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | `performance` / `prepareForActivity` / from frame |
| **Trigger** | `priority.reasons` contains `dayDecisionFrame=primarySessionProtection` |
| **Why it wins** | `primarySessionProtectionStory` checked before generic assess path when no active activity |
| **Suppresses** | Generic prep copy |
| **Today/Coach** | Composed via `CoachNarrativeComposer` — protect key session without changing plan |
| **Example screenshot** | **PREP** · Prepare for training · Hydrate and fuel before the session. |
| **User situation** | Key session today, frame says protect primary session |

---

### 11. Sequence-aware preparation (later serious training)

| | |
|---|---|
| **Owner** | `activityPreparation` (via `prepareForTraining` situation) |
| **Priority** | `stable` / `nextActivityLater` / strength `high` |
| **Trigger** | Serious training later + earlier events (meal, heat, other activities) before it; `sequenceAwarePreparationCandidate` |
| **Why it wins** | Sequence candidates filtered exclusively when present (score ~88) |
| **Suppresses** | Simple baseline prep; stable overview |
| **Today** | Dynamic titles e.g. *Fuel now, keep the heat easy* · *Do not let sauna steal the ride* |
| **Coach** | Full sequence message explaining meal/heat/training ordering |
| **Example screenshot** | **PLAN** · Fuel now, keep the heat easy · The heat comes before the real work. |
| **User situation** | Sauna at 2pm, long ride at 5pm; or meal + training sequence |

---

### 12. Set up training properly (training later, not in prep window)

| | |
|---|---|
| **Owner** | `readiness` or `activityPreparation` |
| **Priority** | `stable` / `nextActivityLater` / strength `medium` |
| **Trigger** | Meaningful training >240 min away; `baselineCandidate` training branch |
| **Why it wins** | Low score (~32) but wins when nothing else qualifies |
| **Suppresses** | Default empty overview |
| **Today** | *Set up the ride properly* · *[Activity] starts in X. Keep the day pointed at the work.* |
| **Coach** | Calm long-gap prep guidance |
| **Example screenshot** | **READY** · Set up training properly · Keep the gap calm, arrive fed enough. |
| **User situation** | Hard session at 6pm, currently 9am |

---

# Post-workout recovery

Post-workout window anchored on `recentlyCompletedActivity` via `postActivityCandidate`. `CoachIntent.postActivity` filters to `postActivityRecovery` / `recoveryNeeded`.

---

### 13. Make the workout count (standard post-workout)

| | |
|---|---|
| **Owner** | `postActivityRecovery` |
| **Priority** | `recovery` / `postActivityRecovery` / strength `medium`–`high` / limiter `insufficientRecoveryTime` |
| **Trigger** | Meaningful training just completed (`isMeaningfulPostActivityTraining`); not evening hard training |
| **Why it wins** | Score ~54+ (+8 each for fuel/hydration/recovery gaps); postActivity intent filter |
| **Suppresses** | Stable day; prep for next activity; active session |
| **Today** | Idea: *Recovery leads now* · Action: *Take the next hour easy — no extra load.* · Color: purple |
| **Coach** | Headline: *You can move without rushing* · Read: *Recovery should lead the rest of today* · Rec: *Refuel and rehydrate, then keep the rest of the day easy.* |
| **Example screenshot** | **RECOVER** · Recovery leads now · Take the next hour easy — no extra load. |
| **User situation** | Finished 60-min run 20 minutes ago |

---

### 14. Protect the work you just did (late hard training)

| | |
|---|---|
| **Owner** | `postActivityRecovery` |
| **Priority** | `recovery` / `postActivityRecovery` / strength `high` |
| **Trigger** | Evening+ hard training completed (high/extreme load or ≥ hard workout min duration) |
| **Why it wins** | Same candidate, different title/message branch |
| **Suppresses** | "Add another session" messaging |
| **Today** | *Recovery leads now* · evening protection tone |
| **Coach** | Read emphasizes sleep taking over · avoid hard work after sauna/training |
| **Example screenshot** | **RECOVER** · Protect the work you just did · Keep protein and fluids light, then let sleep take over. |
| **User situation** | Hard interval session at 8pm |

---

### 15. Small session logged (short completion)

| | |
|---|---|
| **Owner** | `stableOverview` or `readiness` |
| **Priority** | `stable` / `dailyOverview` / strength `medium` |
| **Trigger** | Recent completion < meaningful threshold; workout/endurance/recovery/heat kind; within 60–120 min |
| **Why it wins** | Score ~54; wins when postActivityCandidate returns nil |
| **Suppresses** | Full post-workout recovery narrative |
| **Today** | *Small session logged* · *Keep the next block steady.* |
| **Coach** | Reinforcement, not recovery alarm |
| **Example screenshot** | **ON TRACK** · Small session logged · It was short enough that it does not change the whole day. |
| **User situation** | Logged 15-min mobility, not enough for recovery story |

---

### 16. Post-workout — playbook variants (V4)

| | |
|---|---|
| **Owner** | `postActivityRecovery` |
| **Trigger** | V4 frame `sessionPhase == .post` + activity family |
| **Variants** | After strength: protein 25–40g · After long endurance: eat within 1h, rehydrate evening · Recovery modality post: "supported recovery" |
| **Today/Coach** | Playbook hero drives story; presentation maps to `postWorkoutRecovery` |
| **Example screenshot** | **RECOVER** · Recovery leads now · Refuel and rehydrate, then keep the rest of the day easy. |

---

# Stable day

No urgent limiter, no live session, no prep window dominance. Owner typically `stableOverview` or `readiness`.

---

### 17. Nothing needs fixing (stable day ownership)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `stable` / `dailyOverview` / strength `low`–`medium` |
| **Trigger** | `CoachLightRecoveryStableDayPolicy.ownsStableDayAfterCompletedLightActivity` — light recovery done, recovery strong, no serious work left |
| **Why it wins** | `stableDayAfterCompletedLightActivityCandidate` (~48+) or presentation policy forces scenario |
| **Suppresses** | Recovery alarm; post-workout re-coaching |
| **Today** | Idea: *Nothing needs fixing* · Action: *The day is unfolding calmly.* · Color: green |
| **Coach** | Headline: *Nothing needs fixing* · Read: *The day is unfolding without overload signs.* |
| **Example screenshot** | **ON TRACK** · Nothing needs fixing · The day is unfolding calmly. |
| **User situation** | Morning walk done, recovery 88%, nothing else planned |

---

### 18. Default day overview (baseline calm)

| | |
|---|---|
| **Owner** | `stableOverview` or `readiness` |
| **Priority** | `stable` / `dailyOverview` / strength `low` / `.defaultOverview` |
| **Trigger** | No candidate scores; `baselineCandidate` returns `.defaultOverview` (priorityScore 10) |
| **Why it wins** | Fallback when all candidates nil |
| **Suppresses** | N/A — lowest priority |
| **Today** | Idea: *No changes needed* · Action: *Keep moving at your usual rhythm.* |
| **Coach** | Headline: *You are ready for a normal day* or *The day is unfolding smoothly* |
| **Example screenshot** | **ON TRACK** · No changes needed · Keep moving at your usual rhythm. |
| **User situation** | Normal day, no activities, metrics fine |

---

### 19. Keep the day simple (work already done)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `stable` / `dailyOverview` / strength `medium` |
| **Trigger** | Meaningful load completed + no performance work left + fuel/hydration/recovery OK |
| **Why it wins** | `dayManagementCandidate` score ~46 |
| **Suppresses** | Recovery warnings; extra training prompts |
| **Today** | *Keep the day simple* · *Protect the work already done.* |
| **Coach** | Reinforcement to stay flexible |
| **Example screenshot** | **ON TRACK** · Keep the day simple · Protect the work already done. |
| **User situation** | Hard session done at 10am, easy afternoon |

---

### 20. Strong recovery day (high readiness opportunity)

| | |
|---|---|
| **Owner** | `readiness` |
| **Priority** | `stable` / `dailyOverview` / strength `medium` / opportunity `highReadiness` |
| **Trigger** | Recovery ≥85%, sleep ≥7.5h, no load completed, no limiters, not evening |
| **Why it wins** | Score ~34 (low priority but unique); situation → `opportunityDay` |
| **Suppresses** | Recovery caution copy |
| **Today** | *Good window today* · *Use it calmly.* |
| **Coach** | *Strong recovery day* — opportunity, not pressure |
| **Example screenshot** | **READY** · Good window today · Use it calmly. |
| **User situation** | Rested, no workout yet, could train if desired |

---

### 21. Reset the day (missed/skipped activity)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `stable` / `dailyOverview` |
| **Trigger** | Skipped or missed activities in day context |
| **Why it wins** | `dayManagementCandidate` missed branch (~48) |
| **Suppresses** | Guilt/compensation messaging |
| **Today** | *Reset the day* · *One miss does not define it.* |
| **Coach** | Don't double workload to compensate |
| **Example screenshot** | **ON TRACK** · Reset the day · One miss does not define it. |
| **User situation** | Skipped morning workout, afternoon open |

---

### 22. Steady day (assess fallback)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | Various — assess() final fallback |
| **Trigger** | No higher-priority situation story matches |
| **Why it wins** | `steadyDay(i, legacyPriority:)` after all assess branches fail |
| **Suppresses** | N/A |
| **Today/Coach** | `general` scenario — sanitized render model copy |
| **Example screenshot** | **ON TRACK** · Stay with the plan · Keep the next step simple. |
| **User situation** | Ambiguous day state |

---

# Morning overview

Morning = hour 5–11 for presentation (`stableMorning`, `morningWalkStart`). Resolver uses `CoachCommonSenseMode.morningSetup`.

---

### 23. Morning setup / morning basics

| | |
|---|---|
| **Owner** | `readiness` |
| **Priority** | `stable` / `dailyOverview` or `planChallenge` / `trainingReadinessWarning` |
| **Trigger** | `commonSenseMode == .morningSetup`; may delegate to `morningBasicsCandidate` or readiness warning if training later + low sleep/recovery |
| **Why it wins** | Morning common-sense score up to 88 for readiness warning |
| **Suppresses** | Evening stories; post-workout |
| **Today** | Situation → `morningSetup` story |
| **Coach** | Morning-appropriate headline from `stableMorning` candidates |
| **Example screenshot** | **READY** · You are ready for a normal day · Keep a normal rhythm for now. |
| **User situation** | 7am, training planned later, average recovery |

---

### 24. Morning walk start (presentation scenario)

| | |
|---|---|
| **Owner** | `readiness` or `activityPreparation` |
| **Priority** | Varies — presentation override |
| **Trigger** | `profile.isMorningWalkStartCandidate`: recovery modality walk, recovery >80%, walk in <60 min, no serious workout planned, hour 5–11 |
| **Why it wins** | Presentation layer override in `resolveScenario`, not priority resolver |
| **Suppresses** | Schedule countdown narrative on Today |
| **Today** | Idea: *Good start to the day* · Action: *Take the walk easy — that is enough for now.* |
| **Coach** | Headline: *Good start to the day* · Read: *You can ease into the day — no need to add load before the walk.* |
| **Example screenshot** | **READY** · Good start to the day · Take the walk easy — that is enough for now. |
| **User situation** | 8am, recovery walk in 30 min, recovery 92% |

---

### 25. Stable morning overview

| | |
|---|---|
| **Owner** | `stableOverview` or `readiness` |
| **Priority** | `stable` / `dailyOverview` |
| **Trigger** | Hour 5–11 + owner stable/readiness + not other presentation scenario |
| **Why it wins** | Presentation `stableMorning` branch |
| **Suppresses** | Prep urgency if not in window |
| **Today** | Recovery ≥85%: *Recovery remains strong* · else *A calm day is unfolding* |
| **Coach** | *You are ready for a normal day* or *Good moment for light movement* (recovery modality) |
| **Example screenshot** | **ON TRACK** · Recovery remains strong · You can keep a normal rhythm for now. |
| **User situation** | Calm morning, no immediate activity |

---

### 26. Ease into the morning (recovery walk later)

| | |
|---|---|
| **Owner** | `readiness` |
| **Priority** | `stable` / `nextActivityLater` |
| **Trigger** | Walk/recovery planned later, not in prep window; morning hour; `baselineCandidate` |
| **Why it wins** | Baseline ~28 score |
| **Suppresses** | Default overview |
| **Today** | *Ease into the morning* · *Start with the walk, then reassess.* |
| **Coach** | Walk-comfortable messaging |
| **Example screenshot** | **READY** · Ease into the morning · Start with the walk, then reassess. |
| **User situation** | Walk at 10am, currently 7am |

---

# Recovery day

Explicit recovery day type OR recovery score dominates.

---

### 27. Recovery day (explicit day type)

| | |
|---|---|
| **Owner** | `recovery` |
| **Priority** | `stable` / `dailyOverview` / strength `low`–`medium` |
| **Trigger** | `dayContext.dayType == .recovery` + recovery activity planned; `dayManagementCandidate` |
| **Why it wins** | Score 48–58 depending on prep proximity |
| **Suppresses** | Performance prep; training readiness |
| **Today** | *Recovery day* · *Keep movement easy.* |
| **Coach** | Situation `recoveryDay`: *Keep recovery easy* · avoid unnecessary intensity |
| **Example screenshot** | **RECOVER** · Recovery day · Keep movement easy. |
| **User situation** | Planner marked recovery day, light movement scheduled |

---

### 28. Recovery-led day (low recovery score)

| | |
|---|---|
| **Owner** | `recovery` |
| **Priority** | `recovery` / `recoveryNeeded` / strength `high`–`critical` |
| **Trigger** | `recoveryCandidate` score ≥50: low recovery %, high load, poor sleep, evening, etc. |
| **Why it wins** | Scores 50–90+; dominant day frame can boost further |
| **Suppresses** | Performance readiness; high readiness opportunity |
| **Today/Coach** | Dynamic: *Protect recovery* / *Keep the day calm* / *Sleep leads today* |
| **Example screenshot** | **RECOVER** · Protect recovery · The body needs a calmer day. |
| **User situation** | Recovery 42%, hard training yesterday |

---

### 29. Sleep leads today

| | |
|---|---|
| **Owner** | `recovery` |
| **Priority** | `sleepPreparation` or `recovery` / `recoveryNeeded` / limiter `sleep` |
| **Trigger** | `isVeryLowSleep` or poor sleep dominates; from recovery or sleep candidates |
| **Why it wins** | High insight/uniqueness scores (~94 uniqueness for sleep narrative) |
| **Suppresses** | Training encouragement |
| **Today** | *Sleep leads today* · lower the day messaging |
| **Coach** | Read: *Fitness is not the issue today. Sleep is the bottleneck…* |
| **Example screenshot** | **REST** · Sleep leads today · Lower the day and protect tonight. |
| **User situation** | 4h sleep, training on calendar |

---

# Evening protection

Evening = `isEveningOrLater` or hour ≥18. Focus on wind-down, sleep, closing the day.

---

### 30. Keep the evening steady (baseline evening)

| | |
|---|---|
| **Owner** | `stableOverview` or `readiness` |
| **Priority** | `stable` / `eveningWindDown` / strength `low` |
| **Trigger** | Evening + no dominant limiter; `baselineCandidate` evening branch |
| **Why it wins** | Score ~28; wins if nothing else |
| **Suppresses** | Aggressive fuel/hydration catch-up |
| **Today** | Story title driven |
| **Coach** | *Keep the evening steady* — calm food/fluids/intensity |
| **Example screenshot** | **ON TRACK** · Keep the evening steady · No single blocker is loud. |
| **User situation** | 8pm, uneventful day |

---

### 31. Close the day (day closed / late night)

| | |
|---|---|
| **Owner** | `stableOverview` → situation `normalEvening` |
| **Priority** | `sleepPreparation` / `eveningWindDown` / strength `high` |
| **Trigger** | `commonSenseMode == .dayClosed`; late night or night bucket |
| **Why it wins** | Score ~76, high uniqueness 92 |
| **Suppresses** | Target chasing (calories, water, extra movement) |
| **Today** | *Close the day* · *Sleep beats target chasing.* (late night) |
| **Coach** | Protect sleep; don't chase missed targets |
| **Example screenshot** | **REST** · Close the day · Sleep beats target chasing. |
| **User situation** | 11:30pm, calories under goal |

---

### 32. Protect tonight's sleep (sleep preparation candidate)

| | |
|---|---|
| **Owner** | `recovery` or `tomorrowProtection` |
| **Priority** | `sleepPreparation` / `recoveryNeeded` / limiter `sleep` or `insufficientRecoveryTime` |
| **Trigger** | Evening + sleep deficit signals + score ≥58; not daytime post-workout window |
| **Why it wins** | Score stacks from sleep deficit, high load, no work left, hard tomorrow |
| **Suppresses** | Nutrition-led evening stories unless critical |
| **Today** | *Protect tonight's sleep* · *The useful move now is to bring the day down.* |
| **Coach** | Sleep-first framing |
| **Example screenshot** | **REST** · Protect tonight's sleep · More load will not help; sleep gives tomorrow a chance. |
| **User situation** | 9pm after hard day, short sleep last night |

---

### 33. Empty day evening (no activities planned)

| | |
|---|---|
| **Owner** | `stableOverview`, `recovery`, `tomorrowProtection`, or `hydration`/`fuel` |
| **Priority** | Varies — `emptyDayEveningCandidate` |
| **Trigger** | No active/prep/upcoming activities + evening + at least one of: hydration/fuel behind, tomorrow demand, load protection, sleep/recovery limited, late night |
| **Why it wins** | Score 38–91 depending on branch |
| **Suppresses** | Activity-specific prep |
| **Branches** | High load + OK recovery → *The work is done* · Late night → sleep protect · Hydration/fuel behind → support basics |
| **Example screenshot** | **REST** · The work is done · Nothing important needs protecting tonight. |
| **User situation** | Hard training done, empty evening calendar |

---

### 34. Normal evening (assess path)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `eveningWindDown` focus or balanced evening |
| **Trigger** | `legacyPriority.focus == .eveningWindDown` OR `isBalancedLateEvening` OR `everythingImportantIsDone` |
| **Why it wins** | Situation assess branch |
| **Suppresses** | Training prep |
| **Today/Coach** | Calm evening copy |
| **Example screenshot** | **ON TRACK** · Keep the evening calm · No urgent move needed. |

---

# Tomorrow protection

Protects next-day training quality when tomorrow demand exists and today's recovery is compromised.

---

### 35. Protect tomorrow (tomorrow plan risk)

| | |
|---|---|
| **Owner** | `tomorrowProtection` |
| **Priority** | `planChallenge` / `tomorrowPlanRisk` / strength `high` / limiter `upcomingTraining` |
| **Trigger** | Hard/moderate tomorrow demand + recovery/sleep/load reasons; `tomorrowAdjustmentCandidate`, `commonSenseCandidate(.lateEveningRecovery)`, or evening long endurance filter |
| **Why it wins** | Evening (≥18) + `tomorrowLongEnduranceCandidate` → filters to tomorrowPlanRisk only; late evening score ~66 |
| **Suppresses** | Stable evening; prep; performance opportunity |
| **Today** | Idea: *Protect tomorrow* · Action: *Wind down — no extra load tonight.* · Color: yellow |
| **Coach** | Headline: *Tonight sets up tomorrow* · Read: *Recovery comes first tonight — don't add anything extra.* |
| **Example screenshot** | **PLAN** · Protect tomorrow · Wind down — no extra load tonight. |
| **User situation** | Long run tomorrow, hard session today, 9pm |

---

### 36. Tomorrow protection active state

| | |
|---|---|
| **Owner** | `tomorrowProtection` |
| **Priority** | Any focus — `tomorrowProtection.active == true` |
| **Trigger** | `tomorrowProtectionState()`: hasTomorrowDemand + reasons (short sleep, compromised recovery, sauna impact, heavy load, tomorrow risk) + (late evening OR severe recovery OR protectTomorrow objective) |
| **Why it wins** | Assess checks `tomorrowProtection.active` → `protectTomorrow(i)` even if focus differs |
| **Suppresses** | Optimistic training copy |
| **Today/Coach** | Protection-first; may shift limiter to recovery after 15:00 |
| **Example screenshot** | **PLAN** · Protect tomorrow · Recovery starts tonight. |

---

### 37. Protect tomorrow — rebuild basics (situation story)

| | |
|---|---|
| **Owner** | `tomorrowProtection` |
| **Priority** | `planChallenge` / `tomorrowPlanRisk` |
| **Trigger** | `priorityPreservedStory` for tomorrowPlanRisk |
| **Why it wins** | Preserved priority path in assess |
| **Coach** | Read: *Tomorrow includes a meaningful [session]. Recovery/hydration/fuel are not yet where they should be.* · Rec: *Protect tomorrow by rebuilding basics today.* |
| **Example screenshot** | **PLAN** · Protect tomorrow · Rebuild basics today. |

---

# Hydration support

---

### 38. Hydration-led day story

| | |
|---|---|
| **Owner** | `hydration` (or `activityPreparation` if prep context) |
| **Priority** | `hydration` or `performance`/`recovery` / focus `prepareForActivity` or `recoveryNeeded` / limiter `hydration` |
| **Trigger** | `hydrationCandidate` score ≥52: behind for time, heat soon, endurance soon, post-load, hard training prep |
| **Why it wins** | Heat soon +36 score; can hit ~95 uniqueness; suppressed by severe fatigue unless heat/endurance/immediate |
| **Suppresses** | Generic stable day (when hydrationMayLead) |
| **Today** | Idea: *Fluids need attention* · Action: *Sip steadily through the rest of the day.* · Color: yellow |
| **Coach** | Headline: *Do not fall behind on fluids* · Read: fluids matter for next decision |
| **Example screenshot** | **HYDRATE** · Fluids need attention · Sip steadily through the rest of the day. |
| **User situation** | 2pm, 20% of water goal, long ride later |

---

### 39. Prepare for heat (hydration before sauna)

| | |
|---|---|
| **Owner** | `activityPreparation` or `hydration` |
| **Priority** | `performance` / `prepareForActivity` / strength `critical` |
| **Trigger** | Heat in prep window + fluids critically low (<30% goal) OR `hydrationCandidate` heatSoon |
| **Why it wins** | Heat critical hydration score 94 in prep common-sense |
| **Suppresses** | Normal heat prep without hydration emphasis |
| **Today** | May use heat safety teaser if presentation maps `heatSafetyPrep` |
| **Coach** | *Water comes first before heat* |
| **Example screenshot** | **HYDRATE** · Hydration matters before heat · Drink calmly before sauna. |

---

### 40. Hydration execution (during session)

| | |
|---|---|
| **Owner** | `hydrationExecution` |
| **Priority** | `hydration` / `activeActivity` |
| **Trigger** | Active session + hydration limiter in `activeSessionLimiter` |
| **Why it wins** | Active session owns; limiter shapes bullets |
| **Suppresses** | Standalone hydration day story |
| **Example screenshot** | **LIVE** · (session title) · Sip before you feel dry. |

---

# Fuel support

---

### 41. Fuel-led day story

| | |
|---|---|
| **Owner** | `fuel` |
| **Priority** | `fueling` / focus `fuelBehind` or prep / limiter `fueling` |
| **Trigger** | `fuelingCandidate`: behind + (hard activity soon OR tomorrow hard OR high load OR post-training refuel OR severe readiness risk) |
| **Why it wins** | Blocked if heat+hydration critical without hard activity; otherwise scores 26+ with bonuses |
| **Suppresses** | Calm stable day when fuel gap meaningful |
| **Today** | Idea: *Energy needs a top-up* · Action: *Eat before you ask for more effort.* · Color: yellow |
| **Coach** | Headline: *A little food would help right now* |
| **Example screenshot** | **FUEL** · Energy needs a top-up · Eat before you ask for more effort. |
| **User situation** | Underfueled before afternoon training |

---

### 42. Fuel before training (situation story)

| | |
|---|---|
| **Owner** | `fuel` or `activityPreparation` |
| **Priority** | Supporting fuel story |
| **Trigger** | `i.trainingFuelNeedsAttention` in assess() |
| **Why it wins** | Assess branch after prep/readiness checks |
| **Today/Coach** | *Make the next session easier to start* · recent food light for planned work |
| **Example screenshot** | **FUEL** · Make the next session easier to start · Eat before the session, not during it. |

---

### 43. Fuel prep in session prep (presentation)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Trigger** | `CoachPresentationNutritionGuard.shouldSurfaceFuelPrep`: serious workout planned + `meaningfulUnderfueling` (<25% calories or underfueled + <400 cal) |
| **Today** | *Prepare for the start* · *Eat a little and hydrate before you go.* |
| **Coach** | *A little fuel now will help later* |
| **Example screenshot** | **PREP** · Prepare for the start · Eat a little and hydrate before you go. |

---

# Heat / sauna

Heat activities use `CoachActivityContextResolverV3.kind == .heat` or sauna family. V4 playbook `sauna()` provides phase-specific copy.

---

### 44. Heat safety prep (presentation scenario)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | Prep/focus from resolver |
| **Trigger** | `CoachPresentationHeatSafetyGuard.shouldUseHeatSafetyNarrative`: heat family + ≤180 min until + hydration risk ≠ none |
| **Why it wins** | Presentation override to `heatSafetyPrep` scenario |
| **Suppresses** | Workout-language for heat (sanitized) |
| **Today** | Severe: *Hydration matters before heat* · Moderate: *Top up water before heat* |
| **Coach** | *Water comes first before heat* or *Top up water before sauna* |
| **Example screenshot** | **HEAT** · Top up water before heat · Sauna is recovery heat, not training. |
| **User situation** | Sauna in 45 min, barely drank today |

---

### 45. Sauna — before (playbook pre)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | `performance` or `recovery` / `prepareForActivity` |
| **Trigger** | Heat in prep window; playbook `sessionPhase == .pre` |
| **Why it wins** | V4 playbook for heat class |
| **Today** | *Good window for recovery* (heat prep teaser) · *Keep heat moderate and the rest calm.* |
| **Coach** | Hero: *Before sauna — drink up* · Rec: *Drink 300-500 ml water in the hour before sauna* |
| **Example screenshot** | **HEAT** · Before sauna — drink up · Sauna still stresses your body. |

---

### 46. Sauna — during (active heat)

| | |
|---|---|
| **Owner** | `activeActivity` (situation `manageActiveSauna`) |
| **Priority** | `activeSession` / `activeActivity` |
| **Trigger** | `i.activeHeat != nil` in assess() — before generic active training |
| **Why it wins** | Assess prioritizes heat over training manager |
| **Today** | Idea: *Keep the heat moderate* · Action: *Leave before fatigue shows.* · Color: purple |
| **Coach** | Headline: *Keep the heat moderate* · Read: *Right now the load is heat, not training.* |
| **Example screenshot** | **LIVE** · Keep the heat moderate · Leave before fatigue shows. |
| **User situation** | In sauna session |

---

### 47. Sauna — after (playbook post)

| | |
|---|---|
| **Owner** | `postActivityRecovery` |
| **Priority** | `recovery` / post focus |
| **Trigger** | Heat completed; playbook `sessionPhase == .post` |
| **Why it wins** | Post activity candidate or playbook |
| **Today** | Post-workout recovery teaser if presentation maps |
| **Coach** | Hero: *After sauna — drink and rest* · Avoid hard work right after |
| **Example screenshot** | **RECOVER** · After sauna — drink and rest · Drink water and keep the evening calm. |

---

### 48. Hydrate around heat (situation story)

| | |
|---|---|
| **Owner** | `hydration` or `activityPreparation` |
| **Trigger** | `hydrateAroundHeat(i)` — heat planned/active + hydration priority |
| **Why it wins** | Assess branches for heat+hydration before generic prep |
| **Example screenshot** | **HYDRATE** · Fluids before heat · Sip steadily before sauna. |

---

### 49. Sauna changes the rest of today (heat before training)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Trigger** | Active/preparing sauna + training ahead today |
| **Why it wins** | `manageActiveSauna` branch when `beforeTraining` |
| **Example screenshot** | **HEAT** · Sauna changes the rest of today · Keep the rest of the day easy. |

---

# Critical readiness

Plan adjustment when body state doesn't support planned load.

---

### 50. Manage intensity today (morning readiness warning)

| | |
|---|---|
| **Owner** | `readiness` or `activityPreparation` |
| **Priority** | `planChallenge` / `trainingReadinessWarning` / strength `high` / limiter `sleep` or `trainingReadiness` |
| **Trigger** | Morning + training later + (`isVeryLowSleep` OR `recoveryIsLow`); `commonSenseCandidate(.morningSetup)` |
| **Why it wins** | Score ~88; dominant readiness filter |
| **Suppresses** | Performance readiness; calm morning |
| **Today** | *Manage intensity* · *Readiness sets the ceiling.* |
| **Coach** | Plan challenge to reduce intensity or move it |
| **Example screenshot** | **ADJUST** · Manage intensity today · Readiness sets the ceiling. |
| **User situation** | 7am, intervals at 6pm, recovery 55% |

---

### 51. Same-day training adjustment

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | `planChallenge` / `trainingReadinessWarning` |
| **Trigger** | Training planned + very low sleep OR low recovery; `sameDayTrainingAdjustmentCandidate` |
| **Why it wins** | Score 58+ with sleep/recovery bonuses |
| **Suppresses** | Unmodified prep |
| **Example screenshot** | **ADJUST** · Reduce [activity] intensity · If warm-up feels flat, make session easier. |

---

### 52. Day decision frame — overload / plan change

| | |
|---|---|
| **Owner** | `recovery` or `activityPreparation` |
| **Priority** | `recovery` or `planChallenge` |
| **Trigger** | `dayDecisionFrame.shouldOwnNarrative` + planStatus cancel/replace/downgrade/adjust/complete + overload drivers |
| **Why it wins** | Dominant day frame filter; scores up to ~139 decision |
| **Suppresses** | Stable overview; optimistic readiness |
| **Variants** | Cancel/replace → reduce plan · Downgrade → adjust plan · Complete → recovery first |
| **Example screenshot** | **ADJUST** · (frame title) · Plan should change given recovery contributors. |

---

### 53. Keep the [activity], lower the ceiling (adjust planned training)

| | |
|---|---|
| **Owner** | `activityPreparation` |
| **Priority** | Plan challenge |
| **Trigger** | `i.shouldAdjustPlannedTraining` in assess() |
| **Why it wins** | Assess branch |
| **Example screenshot** | **ADJUST** · Keep the run, lower the ceiling · Warm-up decides how much effort belongs today. |

---

### 54. Critical hydration / fuel (strength critical)

| | |
|---|---|
| **Owner** | `hydration` or `fuel` |
| **Priority** | strength `critical` + limiter |
| **Trigger** | `hydrationCanLeadNarrative`: limiter hydration + strength critical; fuel severe readiness risk |
| **Why it wins** | High candidate scores; nutrition guard owns presentation |
| **Suppresses** | "Good to go" / "On track" badges (debug asserts) |
| **Example screenshot** | **HYDRATE** · Prepare for heat · Do not start heat exposure dry. |

---

# No planned activities

---

### 55. Default overview (no activities, quiet)

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `stable` / `dailyOverview` / `.defaultOverview` |
| **Trigger** | No upcoming/active/preparing activities; baseline falls through to `.defaultOverview` |
| **Why it wins** | priorityScore 10 — ultimate fallback |
| **Suppresses** | Nothing — lowest tier |
| **Today** | *No changes needed* · *Keep moving at your usual rhythm.* (general scenario) |
| **Coach** | *You are ready for a normal day* |
| **Example screenshot** | **ON TRACK** · No changes needed · Keep moving at your usual rhythm. |
| **User situation** | Empty planner, metrics normal |

---

### 56. Contextual fallback (no workout context but day has history)

| | |
|---|---|
| **Owner** | `stableOverview` or `hydration`/`recovery` |
| **Priority** | `stable` / `dailyOverview` |
| **Trigger** | No active/prep/recent completion + `genericFallbackAllowed == false` + meaningful context; `contextualFallbackCandidate` |
| **Why it wins** | Score 34–52 depending on hydration/recovery/last completed |
| **Suppresses** | Generic empty-day copy |
| **Branches** | Hydration behind → *Bring the basics back up* · Recovery limited → *Keep the next block easy* · Last completed → *Day is already started* |
| **Example screenshot** | **ON TRACK** · Day is already started · Keep food, fluids, and effort steady from here. |
| **User situation** | Logged walk earlier, no future plans |

---

### 57. Empty day evening — work done, nothing to protect

| | |
|---|---|
| **Owner** | `stableOverview` |
| **Priority** | `stable` / `eveningWindDown` |
| **Trigger** | Empty evening + high load today + recovery OK + no hydration/fuel/tomorrow pressure |
| **Why it wins** | `emptyDayEveningCandidate` baseScore 91 |
| **Suppresses** | Protection narratives |
| **Today** | *Recovery is holding up* · *Nothing important needs protecting.* |
| **Example screenshot** | **ON TRACK** · The work is done · Enjoy the evening. |
| **User situation** | Hard training done, empty calendar, 8pm |

---

### 58. No pressure yet (activity later, outside windows)

| | |
|---|---|
| **Owner** | `readiness` |
| **Priority** | `stable` / `dailyOverview` |
| **Trigger** | Later activity exists but outside prep/coaching window; baseline |
| **Why it wins** | Score ~22 |
| **Today** | *No pressure yet* · *Keep fuel, fluids, and energy steady.* |
| **Example screenshot** | **ON TRACK** · No pressure yet · No urgent move is needed. |

---

### 59. Available day / good open day

| | |
|---|---|
| **Owner** | `readiness` |
| **Priority** | `stable` / opportunity |
| **Trigger** | `i.isGoodOpenDay` in assess() |
| **Why it wins** | Assess branch before steadyDay |
| **Example screenshot** | **READY** · (open day title) · Keep the day flexible. |

---

# Suppression matrix (quick reference)

| Winning context | Typically suppressed |
|-----------------|---------------------|
| **Active session** | All non-active focuses; prep; post-workout; stable; tomorrow (unless limiter-only shaping) |
| **Prep window + training** | Stable overview; distant nextActivityLater; baseline calm |
| **Post-workout meaningful** | Prep; performance readiness; stable "nothing to do" |
| **Dominant readiness warning** | Optimistic prep; performance readiness; calm morning |
| **Dominant day decision frame (overload)** | Stable overview; high readiness opportunity |
| **Sequence prep** | Simple prep; baseline |
| **Tomorrow plan risk (evening filter)** | Non-tomorrow focuses after 6pm when long endurance tomorrow |
| **Sleep preparation / day closed** | Target chasing; extra load |
| **Recovery candidate (high score)** | Performance readiness; training prep without adjustment |
| **Heat critical hydration** | Normal heat prep; fatigue-only stories |
| **Stable day ownership policy** | Recovery owner for light completed activity |

---

# Today vs Coach split (design intent)

| Surface | Role | Builder |
|---------|------|---------|
| **Today card** | One idea + one action; tactical for active/prep | `CoachTodayTeaserBuilder.scenarioTeaser` |
| **Coach tab** | Interpretation + reasons; no duplicate pacing instructions during active workout | `CoachTabPresentationResolver.resolveCoach` + sanitizers |

Active workout: Today gets pacing (*Don't chase the numbers*); Coach gets reserve/quality framing (*The workout is going fine*). `CoachPresentationIntentGuard` prevents semantic duplication.

---

# Debug / audit hooks

- Priority resolution logs: `[CoachPriorityResolution]` with all candidate scores
- Story build audit: `logV4AuditBuilderIn/Out` with owner candidate and playbook source
- Contract tests: `CoachNarrativeMatrixFactory` (~13 scenario groups, 100+ matrix cases)
- Narrative auditor: `CoachNarrativeContractAuditor` validates owner/priority/badge alignment

---

*Generated from codebase audit. Update when changing `CoachDayPriorityResolver`, `HumanCoachDecisionEngine.assess`, `CoachFinalStoryBuilder`, or presentation sanitizers.*
