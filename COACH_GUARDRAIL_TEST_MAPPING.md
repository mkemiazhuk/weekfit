# Coach Guardrail Test Mapping

> **Purpose:** Map each V5 guardrail to automated tests — what is protected today and what is not.  
> **Source:** `COACH_V5_GUARDRAILS.md` · `WeekFitTests/Coach/`  
> **Update:** When adding a test for a gap, update this file in the same PR.

**Risk:** P0 = catastrophic trust failure · P1 = high · P2 = medium/niche

---

## Summary

| Rule | Risk | Protected | Gaps |
|------|------|-----------|------|
| 1 One leading family | P1 | **Strong** | Cross-surface copy marker edge cases |
| 2 Duplicate narratives | **P0** | Strong | Cross-surface duplicate card |
| 3 Steady masks limiter | **P0** | **Strong** | Post-workout window still Steady |
| 4 Adjust beats Get Ready | **P0** | **Strong** | — |
| 5 In Session absorbs Adjust | **P0** | **Strong** | — |
| 6 Live ease-up needs limiter | **P0** | **Strong** | — |
| 7 Adjust distinct copy | P1 | Weak | No copy-rhyme contract |
| 8 Recover after load | P1 | Strong | Light-session false-positive |
| 9 Wind Down named stake | P1 | **Strong** | Empty tomorrow plan → Steady not Wind Down |
| 10 Nutrition tone-only | P2 | Strong | Severe-orphan Steady urgent |
| 11 Today ≠ Coach story | P1 | Strong | Semantic overlap edge cases |
| 12 Heat not training | P2 | Strong | — |
| 13 Explain the stake | P1 | **Strong** | Russian locale stake parity |

---

## Full mapping

### Rule 1 — One leading family at a time

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `testUpcomingWorkoutOwnsStoryWhileFoodAndWaterStaySupport` · `testActiveWorkoutOverridesSupportSignals` · `testTodayCardAndCoachScreenUseSameResolvedPriorityDecision` · `testFinalStorySupportSignalsDoNotDuplicateHeroText` · `CoachNarrativeContractAuditor.ownerPriorityFindings` · **`CoachGuardrailStakeContractTests.testMatrixScenariosHaveExactlyOneLeadingFamily`** (matrix-wide · live → In Session · Today/Coach must not split families) |
| **Missing** | Copy-marker false positives on blended evening/post-workout transitions |
| **Matrix groups** | All |

---

### Rule 2 — Duplicate narratives are P0 defects

| | |
|---|---|
| **Risk** | **P0** |
| **Protected by** | `testSupportSignalDoesNotDuplicateTitleAndAction` · `testDuplicateHydrationSupportSignalsAreRemoved` · `testFinalStorySupportSignalsDoNotDuplicateHeroText` · `assertNoDuplicateHeroOrSupportCopy` (contract tests) · `CoachNarrativeContractAuditor.classifyDuplicateClusters` · `testPlannedWorkoutDoesNotDuplicateAfterBecomingActive` · `testScenarioSweepMessageFamiliesAndRecoveryRepetition` |
| **Missing** | Automated check: Today teaser + Coach tab must not repeat same headline; live session duplicate Adjust + In Session |
| **Matrix groups** | `activeSession` · `workoutPrep` |

---

### Rule 3 — Steady Day must never mask a real limiter

| | |
|---|---|
| **Risk** | **P0** |
| **Protected by** | `testLowRecoveryNoActivitiesUsesRecoveryLedDayNotWorkoutIntensity` · `testModerateRecoveryNoActivitiesNeverUsesWorkoutPrepCopy` · `testStableDayMildHydrationFuelGapDoesNotChangeOwner` · `testNoActivityNormalMetrics_staysSteadyWithoutGenericRecoveryWarning` · `CoachNarrativeContractAuditor.recoverySeverityFindings` (*very low recovery → not unrestricted stableOverview*) · `testCalmStableDayUnloggedFoodWaterDoesNotBecomeHero` · **`CoachGuardrailP0Tests.testStableOverviewNeverLeadsWhenReadinessWarningEligible`** |
| **Missing** | Post-workout window still Steady (explicit guard) |
| **Matrix groups** | `calmOverview` · `recoveryNeeded` · `postWorkout` · `workoutPrep` (via guardrail test) |

---

### Rule 4 — Adjust beats Get Ready when readiness is poor

| | |
|---|---|
| **Risk** | **P0** |
| **Protected by** | `testWorkoutSoonWithLowRecovery_readinessWarningWins` · `testCriticalTrainingReadinessWarningBeatsNormalRunPreparation` · `testCriticalSleepLimiterOverridesRunPreparationWindow` · `testMorningPoorSleepWithEveningWorkout_managesReadinessAndIntensity` · `testLowRecoveryWithOnlyWalkMakesRecoveryOwnsAndWalkDisappears` (resolver) · `HumanCoachDecisionEngineXCTests.testScenario2_poorSleepHardWorkoutPlanned` · `testPreparationPlanChallengeMentionsSelectedCycling` · **`CoachGuardrailP0Tests.testAdjustBeatsGetReadyWhenRecoveryPoorInPrepWindow`** (prep window 40–45 min · recovery 48–62% · matrix *Run in 2h low recovery*) · **`CoachGuardrailP0Tests.testMorningPlanCheckAdjustBeatsGetReady`** (morning · evening hard session 10h+ out · recovery 46–52% · outside prep window) |
| **Missing** | — |
| **Matrix groups** | `workoutPrep` · `recoveryNeeded` |

---

### Rule 5 — In Session absorbs Adjust when live

| | |
|---|---|
| **Risk** | **P0** |
| **Protected by** | `testActiveActivityWinsWithoutSeriousReadinessIssue` · `testActivePhaseCriticalReadinessOverrideChangesFinalVisibleStory` · `testVeryPoorActiveTrainingStillUsesRed` · `testActiveRunningOnOverloadDayGetsStrongerControlGuidance` · `testActiveWorkoutWithLowFuelAndHydrationStaysLiveGuidance` · `CoachNarrativeContractAuditor.activeContextFindings` · **`CoachGuardrailP0Tests.testLiveSessionNeverSurfacesSeparateAdjustCard`** (live strength · matrix *Strength active low recovery*) |
| **Missing** | — |
| **Matrix groups** | `activeSession` |

---

### Rule 6 — Live ease-up requires an active limiter

| | |
|---|---|
| **Risk** | **P0** |
| **Protected by** | `testLivePlannedCyclingWithReadyRecoveryUsesCautionNotRed` · `testExplicitReadyRecoveryOverridesStaleBrainFlags` · `testActiveWalkOnRecoveryDayStaysRelaxed` · `testActiveRunningUsesOneManageEffortStoryWhenRecoveryIsLimited` · `testScenario8_veryPoorStateUserStartsCycling` · **`CoachGuardrailP0Tests.testGoodRecoveryLiveWalkNeverShowsRedEaseUp`** (matrix *Easy walk active* · *Walk active excellent recovery*) |
| **Missing** | — |
| **Matrix groups** | `activeSession` (normal + light recovery branches) |

---

### Rule 7 — Adjust must not rhyme with Steady or Get Ready

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `testLaterActivityToday_readinessCanWinWithoutUrgency` · `testModerateRecoveryUpcomingWorkoutMayUseControlledPrepCopy` · `HumanCoachDecisionEngineXCTests.testScenario2_poorSleepHardWorkoutPlanned` (indirect) |
| **Missing** | Copy contract: Adjust titles must not match Steady/Get Ready phrase list; badge/color distinction for `planChallenge` vs `stable` |
| **Matrix groups** | `recoveryNeeded` · `workoutPrep` |

---

### Rule 8 — Recover must follow meaningful load

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `testPostWorkoutInsideWindow_recoveryWins` · `testHeavyWorkoutCompletedUsesConcreteRecoveryAction` · `testSuccessfulCompletedEnduranceRecoveryPrioritizesTrainingLoad` · `testRecentlyCompletedWorkoutKeepsOwnershipDuringRecoveryHold` · `testV4PostAfterRideWithTomorrowStretchingSaunaStaysRecoveryNotTomorrowProtection` · `testCompletedShortRecoveryWalkDoesNotTriggerPostActivityRecovery` · `testV4RecoveryWalkDoesNotTriggerMainWorkCompleted` |
| **Missing** | Explicit 90-min post window boundary; light walk completed → not `postActivityRecovery` (partially covered) |
| **Matrix groups** | `postWorkout` · `restAfterLoad` |

---

### Rule 9 — Wind Down requires a named stake

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `TodayCoachContradictionRegressionTests.testTomorrowProtectionRequiresReason` · `testEveningHardWorkoutTomorrow_protectsRecoveryTonight` · `testEmptyEveningWithTomorrowHardTrainingAndNutritionBehindClosesDayForTomorrow` · `testCoachLifecycle_1500HighActivityHardWorkoutTomorrowProtectsTomorrowPreventive` · `HumanCoachDecisionEngineXCTests.testScenario7_eveningBeforeImportantTraining` · **`CoachGuardrailStakeContractTests.testWindDownNamesTomorrowActivity`** (matrix `tomorrowProtection` · named tomorrow activity in visible copy) |
| **Missing** | Empty tomorrow plan → Steady not Wind Down |
| **Matrix groups** | `eveningWindDown` · `tomorrowProtection` |

---

### Rule 10 — Nutrition is a tone — cannot lead unless severe

| | |
|---|---|
| **Risk** | P2 |
| **Protected by** | `testNoActivityNowWithNutritionBehind_doesNotMakeFuelPrimary` · `testFuelSupportSignalUsesFuelStyleWithoutOwningHero` · `testHydrationSupportSignalUsesHydrationStyleWithoutOwningHero` · `testCalmStableDayDoesNotHijackWithFuelHeroWhenUnlogged` · `testMorningLowWaterDoesNotCreateHydrationHero` · `testNightSuppressesFuelingWithoutClearRefuelReason` · `testRecoveryDayNoMealsDoesNotMakeFuelingLead` · `CoachNarrativeContractAuditor.nutritionTimingFindings` · `CoachNarrativeContractAuditor.hydrationTimingFindings` |
| **Missing** | Severe orphan gap → Steady · urgent only (no 8th family); nutrition-led matrix scenarios must assert parent family |
| **Matrix groups** | `nutritionLed` · `hydrationLed` |

---

### Rule 11 — Today and Coach cannot tell the same story

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `testTodayAndCoachPresentationIntentSeparationAcrossKeyScenarios` · `testTodayAndCoachTabCopyStaysBelowHalfOverlapAcrossStableScenarios` · `CoachPresentationIntentGuard.sharesSemanticIntent` · `testGuidanceUsesShortCopyForTodayAndDetailCopyForCoach` · `CoachNarrativeContractAuditor.todayCoachAlignmentFindings` · `testTodayAndCoachShareSelectedStoryColorAndIcon` (same story, different copy — allowed) |
| **Missing** | Full matrix pass: zero semantic intent overlap on behavior-change families; Russian locale parity |
| **Matrix groups** | All |

---

### Rule 12 — Heat is recovery, not training

| | |
|---|---|
| **Risk** | P2 |
| **Protected by** | `testPostSaunaUsesHeatRecoveryNotMainTrainingComplete` · `testUpcomingSaunaNeverUsesMainWorkoutCopy` · `testV4SaunaHasPreDuringPostPlaybooks` · `testStableSaunaIsNotHighRisk` · `testCompletedSaunaReinforcesRecoveryInsteadOfPostWorkoutRecovery` · `testSevereHydrationWithSaunaSoonUsesHeatSafetyNarrative` · `CoachNarrativeContractAuditor` active sauna → not stableOverview |
| **Missing** | — (best covered rule) |
| **Matrix groups** | `saunaHeat` |

---

### Rule 13 — Coach must explain the stake

| | |
|---|---|
| **Risk** | P1 |
| **Protected by** | `testTomorrowProtectionRequiresReason` (partial) · `testSuccessfulCompletedEnduranceRecoveryPrioritizesTrainingLoad` · `testFinalStoryProvidesTodaySemanticInsightMetadata` · `CoachNarrativeContractAuditor.sectionPresenceFindings` (why rows) · **`CoachGuardrailStakeContractTests.testBehaviorChangeCopyIncludesStake`** (curated + matrix behavior-change scenarios · Coach tab stake markers) |
| **Missing** | Russian locale stake parity; Today may remain action-only (by design) |
| **Matrix groups** | `recoveryNeeded` · `activeSession` · `postWorkout` · `eveningWindDown` |

---

## Test suites by role

| Suite | Guardrails primarily covered |
|-------|------------------------------|
| **`CoachGuardrailP0Tests`** | **3, 4, 5, 6** (explicit P0 guardrail contracts) |
| **`CoachGuardrailStakeContractTests`** | **1, 9, 13** (explanation-quality contracts) |
| `CoachDayPriorityResolverXCTests` | 1, 3, 4, 8, 9, 10 |
| `CoachStateNarrativeContractTests` | 1, 2, 3, 8, 10, 11, 12 |
| `HumanCoachDecisionEngineXCTests` | 4, 5, 6, 9, 12 |
| `CoachDynamicPriorityActionTests` | 5, 6, 10 |
| `TodayCoachContradictionRegressionTests` | 9, 10 |
| `CoachNarrativeMatrixValidationSuite` + `CoachNarrativeContractAuditor` | 2, 3, 5, 11, 12 (matrix-wide) |

---

## Recommended next tests (priority order)

*(No open P0/P1 guardrail gaps in mapping — add here when new gaps are identified.)*

---

## Running guardrail-related tests locally

```bash
# P0 guardrail contracts (run first on Coach PRs)
xcodebuild test -scheme WeekFit -only-testing:WeekFitTests/CoachGuardrailP0Tests

# Explanation-quality stake contracts (Rules 1, 9, 13)
xcodebuild test -scheme WeekFit -only-testing:WeekFitTests/CoachGuardrailStakeContractTests

# Priority resolver + contract (broad)
xcodebuild test -scheme WeekFit -only-testing:WeekFitTests/CoachDayPriorityResolverXCTests
xcodebuild test -scheme WeekFit -only-testing:WeekFitTests/CoachStateNarrativeContractTests

# Matrix audit (slow — run before release)
xcodebuild test -scheme WeekFit -only-testing:WeekFitTests/CoachNarrativeMatrixValidationSuite
```

---

*Update this mapping when tests are added. Do not change guardrail rules here — edit `COACH_V5_GUARDRAILS.md` instead.*
