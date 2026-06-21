# Owner Collapse Review

**Branch:** `cursor-recover-coachengine-folder-0826`  
**Baseline:** 63 failing tests after `92a69e5`  
**Scope:** Owner-band and priority-downgrade failures — no engine or test changes until this review is accepted.  
**Core observation:** V4 day-centric owner bands (`pacingExecution`, `sustainableExecution`, `fuelingDuringActivity`, `hydrationExecution`, `activityPreparation`, `tomorrowProtection`) frequently collapse to `activeActivity` or `stableOverview` in current output.

---

## Summary

The engine appears to have simplified the owner taxonomy:

| Legacy owner | Common actual owner | Typical context |
|--------------|--------------------|-----------------|
| `pacingExecution` | `activeActivity` | Early during long endurance |
| `sustainableExecution` | `activeActivity` | Mid endurance session |
| `fuelingDuringActivity` | `activeActivity` | Low fuel during long active session |
| `hydrationExecution` | `activeActivity` | Low water during long active session |
| `activityPreparation` | `activeActivity` or `stableOverview` | Walk/ride prep, recovery modalities |
| `tomorrowProtection` | `stableOverview` | Evening before hard tomorrow session |
| `trainingReadinessWarning` / `planChallenge` | `activeActivity` / `activeSession` | Overload day plan replacement |

**Risk:** UI affordances, badge pairing, and section emphasis tied to granular owners may no longer fire even when copy content is semantically correct.

**Recommendation:** Treat granular owner transitions as **needs product decision** — either re-expand owner bands in engine or update V4 lifecycle tests to assert on copy/phase instead of owner enum. Treat overload plan-replacement collapse as **real regression** pending verification.

---

## Category B — Owner change (10 tests)

| Test | Old owner | Actual owner | Actual copy (summary) | Classification | Rationale |
|------|-----------|--------------|----------------------|----------------|-----------|
| `testEveningBeforeTomorrowLongRunOwnsCoachAfterCompletedWalk` | `tomorrowProtection` | `stableOverview` | Title `"Save the work for later"`, sleep-focused next step, tomorrow mentioned in read | **intentional new contract** | Phase 3 evening scenarios use calm wind-down with tomorrow in narrative; owner downgrade may be acceptable if `primaryFocus=.tomorrowPlanRisk` and limiter preserved. Failure also shows `primaryFocus=tomorrowPlanRisk` and limiter `.upcomingTraining` — only owner enum differs. |
| `testManualCyclingFreshDayUsesNormalActiveGuidance` | `pacingExecution` | `activeActivity` | Fuel/carb during-session copy present | **intentional new contract** | During-session guidance still correct; granular pacing owner removed. |
| `testV4ActiveLongEnduranceHydrationOwnerKeepsConcreteAction` | `hydrationExecution` | `activeActivity` | Carb/fuel during-session copy, not hydration-specific hero | **needs product decision** | Low water during long ride: should hydration own the story or stay as support under active owner? |
| `testV4LongCyclingSessionTransitionsThroughDayCentricOwners` | pacing → sustainable → fueling → post → tomorrow bands | `activeActivity` for mid-session phases | Fuel/carb copy still present in places | **needs product decision** | Full lifecycle band test — collapse loses observability of session phase transitions. Product must choose: restore bands or replace owner asserts with phase/copy asserts. |
| `testV4LowRecoveryWithOnlyWalkMakesRecoveryOwnsAndWalkDisappears` | recovery owns story | `activeActivity` | Walk frames as active performance | **real regression** | Low recovery + walk-only day should not read like training execution. |
| `testV4MorningWalkWithRideLaterProtectsUpcomingSession` | `activityPreparation` | `activeActivity` | `"Keep it easy. Save energy for the session ahead."` — prep intent in copy | **intentional new contract** (copy) + **needs product decision** (owner) | Semantic intent preserved in copy; owner enum changed. Overlap dedupe failure suggests copy duplication not owner issue. |
| `testV4RecoveryModalitiesDoNotOwnFinalStoryLifecycle` | `activityPreparation` for breathing/stretching/yoga before ride | `stableOverview` / `activeActivity` | `"Keep breathing relaxed"` etc. — modality treated as active | **real regression** | Light modalities before ride should support upcoming session, not active performance framing. |
| `testV4SaunaBeforeImportantTomorrowDoesNotOwnStory` | `tomorrowProtection` | `activeActivity` | Sauna/heat copy owns hero; tomorrow protection copy absent from assertions | **needs product decision** | Competing priorities: tomorrow hard session vs active sauna. Phase 3 may accept heat-as-active if tomorrow appears in support. |
| `testActiveActivityCannotHideOverloadPlanReplacement` | `planChallenge` / `trainingReadinessWarning` | `activeSession` / `activeActivity` | Frame `.replace` OK; priority masked | **needs product decision** | Resolver intentionally filters to `activeActivity` under `.liveGuidance` (see `OverloadMaskingReview.md`). Frame + execution provenance pass; priority layer conflicts with test safety contract. |
| `testTodayPresentationUsesComposedFrameNarrative` | Overload frame: `"Replace the run"` + overload read | Prep frame: `"The run is close now"` + conservative open | **real regression** | `screenStory` correct; `finalStory`/`todayPresentation` wrong. V4 `coachV4StoryOwner` prep rule lacks `shouldOwnNarrative` guard. |

---

## Category C — Priority change (7 tests, owner-adjacent)

| Test | Old priority/limiter | Actual | Classification | Rationale |
|------|---------------------|--------|----------------|-----------|
| `testShortSleepFromBrainMetricsStillGeneratesTrainingCandidateAfterRefresh` | `limiter=.sleep` after refresh | `limiter=.upcomingTraining` with 8.2h sleep | **intentional new contract** | Expert refresh with adequate sleep should clear sleep limiter — aligns with a7b7d4d sleep-evidence gating. |
| `testActiveWorkoutWithLowFuelAndHydrationStaysLiveGuidance` | Live guidance priority | Different winner | **needs product decision** | Overlaps hydration + owner collapse during active session. |
| `testEmptyEveningWithTomorrowHardTrainingAndNutritionBehindClosesDayForTomorrow` | Tomorrow-close messaging | Shifted message/priority | **needs product decision** | May still close day semantically; verify copy not owner. |
| `testEveningHardWorkoutTomorrow_protectsRecoveryTonight` | Guard: protect phrase absent | Protect phrase now present | **stale legacy expectation** | Wind-down copy intentionally mentions protection; test asserted absence. |
| `testHighLoadLateEveningStretchingActiveBreathingUpcoming_recoveryPriorityWins` | Recovery priority wins over stretching/breathing | Different winner | **needs product decision** | Late evening modality vs recovery — overlaps `testV4RecoveryModalitiesDoNotOwnFinalStoryLifecycle`. |
| `testProtectTomorrowStoryBeatsHydrationStory` | Tomorrow story beats hydration | Hydration/other wins | **needs product decision** | See Hydration Policy Review. |
| `testScenario7_eveningBeforeImportantTraining` | Specific evening priority story | Changed story | **intentional new contract** | Likely aligns with calm evening wind-down refactor. |

---

## Cross-cutting patterns

### 1. Owner enum vs semantic content decoupling

Several failures show **correct narrative intent with wrong owner enum** (e.g. tomorrow long run after walk: title `"Save the work for later"`, sleep lever, tomorrow in visible text — but owner is `stableOverview` not `tomorrowProtection`).

**Question for product:** Is `story.owner` still a user-visible contract, or should tests migrate to `primaryFocus`, `limiter`, and copy assertions?

### 2. Active owner absorbs preparation and protection

Walk before ride, recovery modalities, and sauna-before-tomorrow all map to `activeActivity`. This suggests the resolver picks the **nearest timed activity** as owner regardless of recovery/protection framing.

**Question for product:** Should protection/tomorrow contexts force `stableOverview` or `tomorrowProtection` even when a light activity is scheduled?

### 3. Overload plan replacement masked by prep/active framing

`testTodayPresentationUsesComposedFrameNarrative` and `testActiveActivityCannotHideOverloadPlanReplacement` are the highest-severity owner-adjacent failures — they affect training safety messaging.

**Action:** Investigate as **real regression** before any test expectation update.

---

## Recommended owner policy (draft)

| Context | Proposed owner | Badge/phase |
|---------|---------------|-------------|
| Evening + hard tomorrow + no remaining today work | `stableOverview` or `tomorrowProtection` | `RECOVER` or `PROTECT TOMORROW` (product choice) |
| Light modality before hard session | `activityPreparation` or `stableOverview` | Support upcoming, not `activeActivity` |
| Long endurance mid-session | `activeActivity` acceptable if copy reflects phase (fuel vs pace) | `LIVE` / manage effort |
| Overload day, planned work still ahead | `planChallenge` / `trainingReadinessWarning` | Must not collapse to prep-window copy |
| Low recovery, walk only | `stableOverview` or recovery-framed owner | Not `activeActivity` |

---

## Next steps (after sign-off)

1. **Do not** bulk-update owner assertions until product confirms simplified taxonomy.
2. Investigate **real regression** trio: overload presentation, recovery modalities, low-recovery walk.
3. For **intentional new contract** cases, migrate tests from owner enum to `primaryFocus` + copy + Phase 3 matrix cross-reference.
4. Reconcile badge policy (`RECOVER` vs `PROTECT TOMORROW`) with owner policy in a single decision doc.
