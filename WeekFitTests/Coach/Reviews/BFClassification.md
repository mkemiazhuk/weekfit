# B–F Failure Classification

**Branch:** `cursor-recover-coachengine-folder-0826`  
**Baseline:** 63 failing tests after `92a69e5` (`/tmp/weekfit-failures-63.json`)  
**After Category A commit `e2e36b3`:** 10 copy-only tests expected to pass; 2 Category A still pending; 51 B–F remain.  
**Phase 3 reference:** `CoachNarrativeMatrixValidationSuite` — 0 P0 fails.

**Classification key**

| Label | Meaning |
|-------|---------|
| **intentional new contract** | Engine behavior matches Phase 3 / a7b7d4d refactor; update test when approved |
| **stale legacy expectation** | Test or matrix assert obsolete copy, owner, or scenario setup |
| **real regression** | Behavior likely unintended; fix engine before updating test |
| **needs product decision** | Valid implementations exist; product must choose policy |

---

## Category B — Owner (10)

| Test | Classification | Notes |
|------|----------------|-------|
| `testEveningBeforeTomorrowLongRunOwnsCoachAfterCompletedWalk` | **intentional new contract** | `stableOverview` + tomorrow copy; `primaryFocus=.tomorrowPlanRisk` preserved |
| `testManualCyclingFreshDayUsesNormalActiveGuidance` | **intentional new contract** | `activeActivity` replaces `pacingExecution`; during-session copy OK |
| `testV4ActiveLongEnduranceHydrationOwnerKeepsConcreteAction` | **needs product decision** | See Owner Collapse Review |
| `testV4LongCyclingSessionTransitionsThroughDayCentricOwners` | **needs product decision** | Granular owner lifecycle vs simplified `activeActivity` |
| `testV4LowRecoveryWithOnlyWalkMakesRecoveryOwnsAndWalkDisappears` | **real regression** | Walk reads as active training on low recovery day |
| `testV4MorningWalkWithRideLaterProtectsUpcomingSession` | **intentional new contract** | Prep copy present; owner enum changed |
| `testV4RecoveryModalitiesDoNotOwnFinalStoryLifecycle` | **real regression** | Modalities framed as active performance |
| `testV4SaunaBeforeImportantTomorrowDoesNotOwnStory` | **needs product decision** | Tomorrow vs active sauna priority |
| `testActiveActivityCannotHideOverloadPlanReplacement` | **real regression** | Overload plan challenge masked |
| `testTodayPresentationUsesComposedFrameNarrative` | **real regression** | Overload replacement arc → prep-window arc |

---

## Category C — Priority (7)

| Test | Classification | Notes |
|------|----------------|-------|
| `testShortSleepFromBrainMetricsStillGeneratesTrainingCandidateAfterRefresh` | **intentional new contract** | Sleep-evidence gating after expert refresh |
| `testActiveWorkoutWithLowFuelAndHydrationStaysLiveGuidance` | **needs product decision** | Active fuel/hydration vs live priority |
| `testEmptyEveningWithTomorrowHardTrainingAndNutritionBehindClosesDayForTomorrow` | **needs product decision** | Evening close semantics shifted |
| `testEveningHardWorkoutTomorrow_protectsRecoveryTonight` | **stale legacy expectation** | Test asserted absence of protect copy that now exists |
| `testHighLoadLateEveningStretchingActiveBreathingUpcoming_recoveryPriorityWins` | **needs product decision** | Recovery vs modality timing |
| `testProtectTomorrowStoryBeatsHydrationStory` | **needs product decision** | See Hydration Policy Review |
| `testScenario7_eveningBeforeImportantTraining` | **intentional new contract** | Evening wind-down refactor |

---

## Category D — Badge / urgency (5)

| Test | Classification | Notes |
|------|----------------|-------|
| `testCoachHeroSemanticColorMatrix` | **intentional new contract** | Evening wind-down → stable color with good recovery |
| `testHeroAndActionsUseSameDayPhase` | **intentional new contract** | `RECOVER` badge pairs with wind-down actions |
| `testProtectTomorrowActionsContainNoExecutionLanguage` | **intentional new contract** | Badge `RECOVER` replaces `PROTECT TOMORROW` |
| `testProtectTomorrowLongRideTomorrowIsHighNotCriticalWithoutSafetyLimiter` | **needs product decision** | `safety` vs `caution` urgency for tomorrow hard session |
| `testProtectTomorrowWithGoodRecoveryIsHighNotCritical` | **needs product decision** | Same urgency calibration question |

---

## Category E — Support vs primary (19)

| Test | Classification | Notes |
|------|----------------|-------|
| `testFullCoachEngineScenarioMatrixEnglish` | **stale legacy expectation** (bulk) | Matrix support/no-action rules conflict with Phase 3 calm overview; subset scenarios need individual calls below |
| `testFullCoachEngineScenarioMatrixRussianCopyDoesNotLeakRawEnglish` | **stale legacy expectation** (bulk) | Same as English matrix subset |
| `testStableDayDoesNotShowMildFoodWaterSupportRows` | **intentional new contract** | Generic stable primary acceptable on calm days |
| `testV4HighRecoveryLowStrainCanRecommendDoingNothing` | **intentional new contract** | Calm template / stay-with-plan |
| `testBalancedStoryProducesMaintenanceSectionsOnly` | **needs product decision** | Section structure under composed-frame narrative |
| `testHydrationCannotBecomePrimaryActionOne` | **needs product decision** | See Hydration Policy Review |
| `testHydrationOnlyAppearsInSupportForNormalDays` | **needs product decision** | See Hydration Policy Review |
| `testMorningLowWaterAppearsAsSupportAction` | **needs product decision** | Calm morning hydration surfacing |
| `testNoActivityContextCannotRenderRideOrWorkoutSupportActions` | **real regression** | Workout support without activity context |
| `testPrepareRideShowsHydrationSupportWhenWaterZero` | **real regression** | Prep support channel not rendering injected hydration |
| `testPrepWindowMealLoggedButWaterZeroKeepsHydrationWarningVisible` | **real regression** | Prep-window water gap suppressed |
| `testRecoveryActionsRemoveFoodAndHydrationAsTheyAreCompleted` | **needs product decision** | Action lifecycle when items completed |
| `testSecondaryHydrationSupportUsesSoftLanguage` | **needs product decision** | Blocked on hydration surfacing policy |
| `testSupportSignalsContainHydrationWhenRelevant` | **real regression** | Support signals empty when water low |
| `testSupportSignalsNeverReplacePrimaryActions` | **stale legacy expectation** | Composed narrative may echo themes |
| `testSupportSignalsRenderForStableNextActivityLater` | **real regression** | Support bullets not rendering in story |
| `testCoachV5DynamicTextScenarioAudit` | **intentional new contract** | Evening scenarios use wind-down copy |
| `testProtectTomorrowMentionsHydrationOnlyWhenFuelCovered` | **intentional new contract** (badge) + **needs product decision** (hydration mention) | See Hydration Policy Review |
| `testUpcomingEnduranceWorkoutTimingOwnsWhileWaterAndFoodSupport` | **intentional new contract** | Prep primary is legs/stillness not fluids |

### Matrix scenario sub-classification (within `testFullCoachEngineScenarioMatrixEnglish`)

| Scenario | Classification |
|----------|----------------|
| A1 morning good recovery no workout | **intentional new contract** |
| A2 morning low water no heat | **intentional new contract** |
| A3 morning poor sleep workout later | **stale legacy expectation** | Missing prep tokens; copy structure changed |
| B3 workout soon severe hydration | **needs product decision** |
| C1 fresh manual workout | **stale legacy expectation** | Warm-up token set changed |
| D3 easy walk completed | **intentional new contract** |
| E3 easy day complete | **intentional new contract** |
| E4 late night food water low | **intentional new contract** |
| F1/F2/F3 recovery/no-training variants | **intentional new contract** |
| G1 mild hydration stable day | **intentional new contract** |
| G3 food low morning no workout | **intentional new contract** + **needs product decision** on `"breakfast"` forbid-list |

---

## Category F — Potential regression (10)

| Test | Classification | Notes |
|------|----------------|-------|
| `testSundayMorningModerateRecoveryNoWorkoutUsesCalmReadinessOverview` | **stale legacy expectation** | Scenario inputs contradict test name (short sleep + zero food) |
| `testEmptyEveningModeDoesNotRunWhenActivityRemainsToday` | **stale legacy expectation** | Test bug: UUID/`priority.activity` assertion; fixed via `activityContext.laterTodayActivity` |
| `testOverloadDayWithUnderfuelingOverridesGoodToGoPostActivityStory` | **real regression** | Post-activity underfuel story not surfacing |
| `testActiveSessionScreenStoryPreservesResolverActivitySpecificTitle` | **intentional new contract** | Generic `"Control the session"` title refactor |
| `testLiveLowSleepGuidanceIsSportSpecific` | **intentional new contract** | Generic manage-effort titles; sport copy in body |
| `testManualWalkAfterHeavyDayIsRecoveryOnly` | **real regression** | Active fueling copy after huge day + walk |
| `testV4PostWithRecoveryLimitedStillMentionsTomorrowPlan` | **stale legacy expectation** | Asserts obsolete phrases; new sleep-protection copy |
| `testV4PostAfterRideWithTomorrowStretchingSaunaStaysRecoveryNotTomorrowProtection` | **needs product decision** | Russian post-ride copy vs tomorrow protection |
| `testProtectTomorrowStoryBeatsHydrationStory` | **needs product decision** | Also Category C |
| `testHydrationCannotBecomePrimaryActionOne` | **needs product decision** | Also Category E |

### Additional failures not in original F list (same suite)

| Test | Category | Classification | Notes |
|------|----------|----------------|-------|
| `testUpcomingEnduranceWorkoutUsesConcreteHumanPrepStory` | E | **intentional new contract** | Legs/stillness prep primary |
| `testV4LongRideIn45MinutesUsesImmediatePreparationWindow` | E | **intentional new contract** | Prep copy refresh |
| `testRussianSaunaHydrationCopySoundsHumanAndKeepsSaunaHero` | A (pending) | **stale legacy expectation** | Category A copy refresh pending |
| `testV4LongRunIn45MinutesUsesRunningPreparationCopyRussian` | A (pending) | **stale legacy expectation** | Category A copy refresh pending |
| `testV4PostWithRecoveryLimitedStillMentionsTomorrowPlan` | F | **stale legacy expectation** | Listed above |

---

## Summary counts (51 B–F tests, some counted in multiple categories)

| Classification | Approx. count |
|----------------|--------------:|
| **intentional new contract** | 22 |
| **stale legacy expectation** | 12 |
| **real regression** | 11 |
| **needs product decision** | 18 |

*Counts exceed 51 because matrix rows and cross-category tests are split; use per-test row as source of truth.*

---

## Recommended fix order (post-review)

1. **Real regression (11):** prep-window hydration support pipeline, overload presentation, recovery modalities, low-recovery walk, post-activity underfuel, no-activity-context support leak.
2. **Product decisions (18):** owner taxonomy, hydration surfacing policy, urgency calibration, sauna/tomorrow priority — block bulk test updates.
3. **Stale legacy (12):** matrix auditor rules, contradictory scenarios, Russian Category A pending, resolver UUID test (done).
4. **Intentional new contract (22):** batch test refresh with Phase 3 cross-reference comments — only after product signs owner/badge/hydration policies.

---

## Related documents

- [HydrationPolicyReview.md](./HydrationPolicyReview.md)
- [OwnerCollapseReview.md](./OwnerCollapseReview.md)
