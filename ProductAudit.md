# WeekFit Product Audit

## Executive Summary

* Highest-risk areas:
  * Coach still has multiple legacy/fallback narrative paths that can render static advice when `CoachFinalStory` is unavailable or when render de-duplication falls back to owner-level copy.
  * Insights appears implemented but is not exposed in the active tab shell, so a core product area can be unreachable even though the app contains Insights views and actions.
  * Insights, Activity detail, Coach evening review, Day Flow, and Meals contain substantial hardcoded English or raw localization-key copy, so Russian localization and premium tone are not guaranteed outside the main localization pipeline.
  * HealthKit state can be reported as connected when useful reads are denied or empty, and the live Watch bridge may not start at all because `watchBridge.start()` is not called from the coordinator startup path.
  * Workout reconciliation has important protections but still has boundary risks: future planned rows can match a just-finished same-type workout near the planned start, duplicate prevention is partly in memory, and completed saves can suppress retry if persistence fails.
  * Small-device and Russian Dynamic Type risk is concentrated in fixed-height planner/meal/insight cards, `lineLimit(1)` labels, and dense sheets.
* Highest-value improvements:
  * Add no-risk copy/localization fixes first: move hardcoded English strings into `Localizable.xcstrings`, shorten Russian status labels, and remove single-line truncation from primary explanatory text.
  * Add snapshot/UI tests for Russian + Dynamic Type before changing layouts.
  * Add Coach scenario tests before touching logic, especially no-activity, missing-sleep morning, Watch-live/completed, late-night, tomorrow-heavy-load, and hydration/fuel conflict cases.
  * Add HealthKit access-state, Watch bridge startup, reconciliation boundary, delayed-sleep, and app-restart duplicate tests.
* What should not be changed:
  * Do not redesign the app shell, theme, or Coach architecture as part of the first pass.
  * Do not delete legacy Coach code until runtime logs/tests prove the path is unreachable.
  * Do not make food or hydration a primary Coach decision except for safety-critical or activity-execution cases.
  * Do not change HealthKit sync or planner reconciliation behavior without tests around permission state, duplicate prevention, retry behavior, and planned-vs-completed matching.

## Critical Issues

### 1. Coach Can Still Fall Back To Static Or Owner-Level Advice

* Area: Coach product logic
* File(s): `WeekFit/Features/Nutrition/new/CoachEngine/ExpertCoachViewV3.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachFinalStoryRenderModel.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachState.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachNarrativeBuilder.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachScenarioRule.swift`
* Problem: The app is trying to make `CoachFinalStory` the source of truth, but fallback guidance, rule copy, narrative builder copy, render-model fallback copy, and hard overrides can still render generic advice.
* Evidence:
  * `ExpertCoachViewV3.fallbackGuidance` creates a stable overview when coordinator guidance is missing.
  * `CoachFinalStoryRenderModel.fallbackRecommendation(owner:)` returns generic owner-level advice such as "Keep the plan simple and avoid adding extra intensity."
  * `CoachCoordinator.applyStableRecoveryActivityVisibleOverride` and `CoachState` contain last-boundary guard stories with inline English/Russian copy.
  * `CoachNarrativeBuilder` and `CoachScenarioRule` still include static titles/messages such as "Everything looks steady", "Prepare for the ride", and "Nothing requires attention right now. Stay active, hydrate well and maintain healthy routines."
* User impact: On first launch, while syncing, or during edge states, Coach can feel robotic or disconnected from the actual day. This directly conflicts with the product goal that Coach reasons from current-day state.
* Recommended fix: Do not delete legacy paths yet. Add DEBUG/runtime assertions or tests proving when fallback paths render. Then gate user-visible Coach on `CoachFinalStory` plus a calm localized "syncing/missing data" state, and move any unavoidable fallback text into localized final-story copy with clear ownership.
* Risk of fix: Medium. The safest path is test-first because these paths may still protect real loading or missing-data states.

### 2. Coach Scenario Coverage Is Not Yet Complete For The Product Contract

* Area: Coach product logic
* File(s): `WeekFitTests/Coach/CoachCoordinatorXCTests.swift`, `WeekFitTests/Coach/CoachDayPriorityResolverXCTests.swift`, `WeekFitTests/Coach/HumanCoachDecisionEngineXCTests.swift`, `WeekFitTests/Coach/TodayCoachStressScenarioTests.swift`, `WeekFitTests/Coach/CoachStateNarrativeContractTests.swift`
* Problem: Existing Coach tests cover many contracts, but the requested product scenarios are not all explicitly locked: no planned activities must never say "next activity"; morning missing sleep must not start with food/water warnings; late-night use should wind down; active/completed Watch workouts should own the story correctly; tomorrow-heavy-load should protect tomorrow without inventing today's next activity.
* Evidence:
  * The engine contains many branches for `morning`, `sleep`, `hydration`, `fuel`, tomorrow protection, live activity, and fallback stories, but the scenario list is broader than the visible test names.
  * `CoachEngineV3.assertHydrationRenderConsistency` only guards a narrow hydration-owned critical case in DEBUG.
  * `ExpertCoachViewV3` has compatibility fallbacks for final-story support/actions.
* User impact: A small regression can make Coach give the wrong primary recommendation, especially around missing data or no-plan days, where user trust is fragile.
* Recommended fix: Add scenario fixtures before changing logic:
  * no planned activities: assert no "next activity", no activity-prep owner, stable or recovery ownership only when justified.
  * morning missing sleep / Apple Health not synced: assert calm data-readiness copy, no primary hydration/fuel warning.
  * active Watch workout / completed Watch workout / planned workout completed early / manually started early: assert active/post-activity ownership and correct action.
  * evening no activities left / late night: assert wind-down or close-day story.
  * tomorrow long endurance ride: assert tomorrow protection, not today's next activity.
  * conflicting hydration/fuel: assert activity/recovery remains primary unless dehydration/fueling is safety-critical.
* Risk of fix: Low for tests, medium for any subsequent logic cleanup.

### 3. Localization Gaps In Insights, Meals Recommendations, Health Copy, And Coach Runtime Copy

* Area: Localization
* File(s): `WeekFit/Features/Home/Views/Activity/ActivityIntelligenceView.swift`, `WeekFit/Features/Home/Views/DayFlowService.swift`, `WeekFit/Features/Insights/InsightsStoryEngine.swift`, `WeekFit/Features/Insights/InsightsView.swift`, `WeekFit/Features/Meals/MealsView.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachEveningReviewSection.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachNarrativeBuilder.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachScenarioRule.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/HumanCoachDecisionEngine.swift`, `WeekFit/Features/Auth/Views/HealthAccessView.swift`
* Problem: Several user-visible strings are composed directly in Swift instead of going through `Localizable.xcstrings` or a runtime localization key.
* Evidence:
  * `ActivityIntelligenceView` appears to pass raw localization keys such as `activity.score`, `activity.min`, `activity.noWorkoutsRecorded`, and `activity.activityTotalsAreShownFromAppleHealth` directly to visible text helpers.
  * `InsightsStoryEngine.fallbackStory` returns hardcoded English such as "Insufficient overlap", "Build a complete baseline", and "Log sleep, meals, drinks and activity every day for the next 7 days."
  * `InsightsView` includes visible English labels such as "WHY THIS SCORE", "DATA COVERAGE", "Trust meter", and coverage column names.
  * `MealsView.MealRecommendationEngine.copy` returns "Today's Best Match", "Best match for the current Coach focus", "Save this for after heat exposure — rehydrate first", and factor strings such as "Best macro balance today".
  * `CoachEveningReviewSection` contains visible English copy even though related keys exist in `Localizable.xcstrings`.
  * `DayFlowService` stores display copy such as "LIVE", "NEXT", "DONE", "SKIPPED", "Happening now", and "Nothing planned right now" as English strings.
  * `CoachNarrativeBuilder` and `CoachScenarioRule` include hardcoded English titles/messages and fallback activity names.
  * `HealthAccessView.HealthReadiness.qualityLabel` branches directly on `WeekFitCurrentLocale().identifier` for "Excellent", "Good", "Partial" instead of using keys.
* User impact: Russian users will see English in premium surfaces, and copy cannot be tuned for natural Russian tone or line length.
* Recommended fix: Move these strings into `Localizable.xcstrings` with domain-specific keys:
  * `insights.empty.insufficientOverlap.title`
  * `insights.empty.baseline.action`
  * `meals.recommendation.badge.bestMatch`
  * `meals.recommendation.reason.beforeActivityFormat`
  * `coach.runtime.*` keys for any user-visible narrative fallback.
  * `coach.eveningReview.*` existing keys for evening review.
  * Store semantic `DayFlowItem` statuses and localize at render time.
  * Replace `HealthAccessView` inline locale labels with `healthAccess.readiness.excellent`, `healthAccess.readiness.good`, `healthAccess.readiness.partial`.
* Risk of fix: Low if keys are added without changing logic.

### 4. Workout Sync Duplicate Prevention Is Partly In-Memory

* Area: Apple Health / Apple Watch sync
* File(s): `WeekFit/Services/connectors/HealthKitWorkoutSyncService.swift`, `WeekFit/Services/connectors/WeekFitActivityCoordinator.swift`, `WeekFit/Services/connectors/ActivityReconciler.swift`, `WeekFitTests/Coach/ActivityReconcilerXCTests.swift`
* Problem: `HealthKitWorkoutSyncService.seenWorkoutIDs` and `WeekFitActivityCoordinator.reconciledWorkoutUUIDs` are in-memory sets. The model check for existing `healthKitWorkoutUUID` prevents duplicates only when the already-imported activity is included in the `activities` array passed to reconciliation.
* Evidence:
  * `HealthKitWorkoutSyncService` stores `seenWorkoutIDs` only in memory.
  * `WeekFitActivityCoordinator.reconcileCompletedAppleWorkout` checks `activities.contains { $0.healthKitWorkoutUUID == workoutUUID || $0.id == workoutUUID }`, then inserts a new imported activity when no match exists.
  * Existing test `testSameHealthKitWorkoutReconciledTwiceImportsOnlyOnce` covers duplicate prevention within one coordinator lifetime, not app restart or stale query array.
* User impact: A restarted app or stale SwiftData query could import an Apple workout twice, creating duplicate planner rows and confusing Coach load.
* Recommended fix: Add tests first for app restart/stale-array duplicate risk. Then make duplicate prevention query SwiftData by `healthKitWorkoutUUID` or `id` before import, not only the current in-memory array.
* Risk of fix: Medium because reconciliation touches user data. Keep the change isolated to duplicate lookup.

### 5. Insights Is Implemented But Not Exposed In The Active App Shell

* Area: First-time journey, Insights / Highlights, navigation
* File(s): `WeekFit/Components/WeekFitBottomBar.swift`, `WeekFit/Features/AppShell/WeekFitRootView.swift`, `WeekFit/Features/Insights/InsightsView.swift`
* Problem: The app contains an Insights screen and story model, but the active tab shell does not expose it.
* Evidence:
  * `WeekFitTab.insights` and the `InsightsView` routing path are commented out while active tabs cover Today, Coach, Meals, and Plan.
  * The product brief treats Insights / Highlights as a core app area, and multiple screens/actions reference trend value.
* User impact: Users cannot reach a core value proposition around trends and interpretation, especially in the first-time journey where they need to understand what WeekFit will become after data accumulates.
* Recommended fix: Decide intentionally: either expose Insights with a localized "building patterns" empty state, or hide/avoid references and actions that imply Insights exists. If exposing, add a bottom-tab/manual navigation test and no-data snapshot first.
* Risk of fix: Medium if reintroducing tab navigation; low if hiding dead references.

### 6. Health Access State Can Be Reported As Granted When Useful Signals Are Missing

* Area: Apple Health / Apple Watch sync, first-time journey, Coach state
* File(s): `WeekFit/Services/HealthManager.swift`, `WeekFit/Features/Auth/Views/HealthAccessView.swift`, `WeekFit/Features/Home/Views/Recovery/RecoveryHealthKitProvider.swift`
* Problem: Health access state appears to conflate "requested", "authorization call succeeded", and "usable data exists". A no-error active-calorie query can be treated as granted even when reads are denied or empty, and `weekfit.healthAccessRequested` is set after the authorization prompt regardless of what the user allowed.
* Evidence:
  * `requestAuthorization()` sets the requested flag after `requestAuthorization(...)`.
  * The app uses aggregate booleans such as `isHealthAccessGranted`, `isHealthAccessRequested`, and `hasCompletedHealthAccessCheck` to drive Today/Coach/Health setup states.
* User impact: The UI can say Health is connected while sleep, recovery, and workout signals are unavailable. Coach may settle, show zero recovery, or give lower-confidence copy without explaining the real missing signal.
* Recommended fix: Separate `requested` from per-signal usability: sleep, workouts, HRV/resting HR, activity, nutrition, hydration. Render "connected but waiting for sleep" differently from "permission denied" and "no samples yet".
* Risk of fix: Medium because onboarding, Today, Coach, and Profile consume the same state.

### 7. Live Apple Watch Workout Bridge May Never Start

* Area: Apple Watch live sync, Planner, Coach
* File(s): `WeekFit/Services/connectors/WeekFitActivityCoordinator.swift`, `WeekFit/Services/connectors/WatchLiveWorkoutBridge.swift`, `WeekFit/App/WeekFitApp.swift`
* Problem: The coordinator starts HealthKit workout sync but does not appear to start the WatchConnectivity bridge.
* Evidence:
  * `WeekFitActivityCoordinator.start()` calls `healthSync.start()`.
  * `WatchLiveWorkoutBridge.start()` exists separately and needs to activate `WCSession`.
* User impact: Planner live status and Coach active-workout guidance from Apple Watch may never appear, undercutting a premium "live coach" experience.
* Recommended fix: Start the watch bridge from `WeekFitActivityCoordinator.start()` and add a startup test with an injectable bridge or a lightweight activation seam.
* Risk of fix: Low for startup; medium only if WatchConnectivity lifecycle side effects surface.

### 8. Future Planned Activities Can Still Match Past Watch Data Near The Boundary

* Area: Apple Health / Planner reconciliation
* File(s): `WeekFit/Services/connectors/ActivityReconciler.swift`, `WeekFitTests/Coach/ActivityReconcilerXCTests.swift`
* Problem: `bestMatch()` logs future candidates but still evaluates all same-day planned rows. `timingMatch()` accepts a same-type workout when the start delta is within 45 minutes, even if the workout ended before the planned start.
* Evidence:
  * `plannedBeforeEnd` and `plannedAfterEnd` are computed for debug output.
  * Matching eligibility is based on `allPlanned.compactMap`, type compatibility, and `timingMatch`.
  * `timingMatch` allows `overlapSeconds > 0 || startDeltaSeconds <= startProximityWindow`.
* User impact: A user who takes a walk at 09:20-09:50 could complete a planned 10:00 walk instead of importing as a separate completed workout. That corrupts planner intent and Coach's completed-vs-upcoming story.
* Recommended fix: Require overlap or `plannedStart <= workout.endDate` before auto-completing a planned activity. Keep early-start matching for workouts that overlap or reach the planned slot.
* Risk of fix: Medium. Add tests first for `09:20-09:50` not matching `10:00`, while `09:30-10:20` still matches `10:00`.

### 9. Coach Final Story Is Blocked Too Strictly By Missing Sleep / Recovery

* Area: Coach product logic, first-time morning journey
* File(s): `WeekFit/Features/Nutrition/new/CoachEngine/CoachState.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachCoordinator.swift`, `WeekFit/Features/Home/Views/TodayView.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/ExpertCoachViewV3.swift`
* Problem: `CoachFinalStory` readiness can block visible Coach guidance whenever sleep/recovery is missing, instead of giving limited-confidence guidance from available signals.
* Evidence:
  * Readiness gating blocks on placeholders such as missing sleep/recovery and moves the state to `.settling(reason: "Coach inputs are still syncing.")`.
  * Today then renders a generic sync fallback when no final story exists.
* User impact: A morning user with a hard workout planned but delayed Apple Health sleep sync may get no useful "what to do next" guidance.
* Recommended fix: Add a limited-confidence missing-sleep final story that explains the missing signal calmly, avoids recovery claims, and still reasons from known plan/live/completed load.
* Risk of fix: Medium. Add scenario tests before changing Coach state gating.

## Medium Issues

### 10. Health Access Flow Still Has Inline Locale Logic And Dense Fixed Layout

* Area: First-time journey, Health access, localization, accessibility
* File(s): `WeekFit/Features/Auth/Views/HealthAccessView.swift`
* Problem: The screen now scrolls, but it still mixes readiness logic, copy, and fixed-size decorative layout in one large view. Several row/icon heights are fixed, and readiness labels are inline English/Russian.
* Evidence:
  * `HealthAccessView` uses `ScrollView`, which is good for small devices.
  * Fixed frames include `frame(height: 16)`, `frame(height: 22)`, `frame(height: 44)`, and many fixed icon containers.
  * `HealthReadiness.qualityLabel` branches manually for Russian/English.
* User impact: Health setup is the first high-trust moment. If Russian clips or mixed-language labels appear, the app feels less premium before the user gets value.
* Recommended fix: Localize readiness labels, avoid fixed heights for text rows, and add Russian + Dynamic Type screenshot tests for Health access.
* Risk of fix: Low.

### 11. First-Time Value Depends Too Heavily On Health Data Without Enough "Do Next" Guidance

* Area: First-time journey
* File(s): `WeekFit/Features/Home/Views/TodayView.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/ExpertCoachViewV3.swift`, `WeekFit/Features/Planner/Views/WeekPlanerView.swift`, `WeekFit/Features/Meals/MealsView.swift`, `WeekFit/Features/Insights/InsightsStoryEngine.swift`
* Problem: When Health data is missing, Today and Coach mostly show connect/syncing states; Meals and Planner have creation empty states; Insights asks for a 7-day baseline. The product value can feel delayed.
* Evidence:
  * `TodayView.shouldShowHealthConnectPrompt` uses missing recovery signals plus Health access state to show a connect prompt.
  * `TodayView` shows `today.recovery.sleepSyncPending` when no final Coach story exists.
  * Planner empty day says `AppText.Planner.buildYourDay` but truncates the message to one line.
  * Insights fallback asks users to log sleep, meals, drinks, and activity for 7 days.
* User impact: A fresh install may not answer "what should I do next?" until data arrives.
* Recommended fix: Add a no-data "first useful day" path that suggests one simple manual plan action, one meal/drink log, and Health connection as optional enhancement. Keep it localized and avoid fake Coach certainty.
* Risk of fix: Low if copy/UI only.

### 12. Planner Reconciliation Logic Is Good But Has Missed-Match Edge Cases

* Area: Apple Health / Planner
* File(s): `WeekFit/Services/connectors/ActivityReconciler.swift`, `WeekFit/Features/Planner/Views/WeekPlanerView.swift`, `WeekFitTests/Coach/ActivityReconcilerXCTests.swift`
* Problem: Matching uses family compatibility, overlap, and a 45-minute start proximity window. It may falsely match a future same-day row near the boundary, and may miss clear real-world matches that start more than 45 minutes early.
* Evidence:
  * `ActivityReconciler.timingMatch` requires overlap or `startDeltaSeconds <= startProximityWindow`.
  * `pastMatchingWindow` exists but is only used by legacy helper `isWorkoutCloseEnoughToPlannedActivity`, not by `bestMatch`.
  * Existing tests cover early by 30 minutes and future planned walk not auto-completed.
* User impact: A manually-started workout well before the planned slot may import as a second row, leaving the planned row pending, while a just-finished workout near the planned slot may incorrectly complete the future row. Coach may count the wrong intended/completed load either way.
* Recommended fix: Add tests for workout ended before planned start, 46-75 minutes early same type, same-day multiple same-family workouts, walk logged before planned walk, and tiny-overlap/duration-mismatch cases. Only change matching gates after tests prove safe.
* Risk of fix: Medium. Matching must not regress future-plan protection.

### 13. Live Watch State Can Be Too Broad Or Too Short-Lived

* Area: Apple Watch live sync, Coach, Planner
* File(s): `WeekFit/Services/connectors/WatchLiveWorkoutBridge.swift`, `WeekFit/Services/connectors/WeekFitActivityCoordinator.swift`, `WeekFit/Features/Planner/Views/WeekPlanerView.swift`
* Problem: Live matching accepts same type within 2 hours of planned start, and ended live workouts are cleared after 3 seconds. Separately, the bridge may not start at all until `watchBridge.start()` is wired into coordinator startup. If HealthKit completion import is delayed, the app may briefly lose the live/post-workout state.
* Evidence:
  * `WeekFitActivityCoordinator.isLiveMatch` checks `abs(activity.date.timeIntervalSince(liveWorkout.startedAt)) <= 2 * 60 * 60`.
  * `WatchLiveWorkoutBridge` clears an ended live workout after 3 seconds.
* User impact: Planner and Coach can flicker from live to pending before HealthKit import arrives, especially with delayed Apple Health sync.
* Recommended fix: Add a short persisted "recently ended Watch workout" bridge state, then reconcile it with HealthKit UUID when available. Test Coach state during active, ended-before-import, and completed-imported phases.
* Risk of fix: Medium.

### 14. Insights Model Has The Right Shape But Empty/Missing Data Copy Is Generic And Unlocalized

* Area: Insights / Highlights
* File(s): `WeekFit/Features/Insights/InsightsStoryEngine.swift`, `WeekFit/Features/Insights/InsightsView.swift`, `WeekFit/Features/Highlights/HighlightsView.swift`, `WeekFit/Features/Highlights/HighlightsViewModel.swift`
* Problem: Insights has a ranked story model with top insight, driver, and action, but fallback states are generic and hardcoded in English. Highlights shows chart + driver grid, but driver cards have fixed height and can feel like equal cards rather than a prioritized coaching takeaway.
* Evidence:
  * `InsightsStoryEngine` uses `domainDiverseStories(... limit: 2)`, which is good prioritization.
  * Fallback strings are English and generic: "No dominant insight", "Insufficient overlap", "Keep collecting signal".
  * `HighlightsView.driverCard` uses `.frame(height: 82)` and "View %@ analysis" style text.
* User impact: Insights can feel like charts and generic advice instead of a premium coach explaining a trend.
* Recommended fix: Localize fallback stories, add a stronger "top insight first" empty state, and make the first insight visually dominant. Add snapshot tests for Russian `InsightsView` and `HighlightsView`.
* Risk of fix: Low to medium depending on layout changes.

### 15. Nutrition Recommendations Are Useful But Copy And Portion Behavior Need Tightening

* Area: Meals / Nutrition
* File(s): `WeekFit/Features/Meals/MealsView.swift`, `WeekFit/Features/Meals/CustomMealBuilderView.swift`, `WeekFit/Features/Meals/ManualMealFormView.swift`, `WeekFit/Services/MealsService.swift`
* Problem: The recommendation engine is context-aware, but the copy is hardcoded English and sometimes too technical. Portion and custom-food screens use many fixed heights/single-line labels.
* Evidence:
  * `MealsView.MealRecommendationEngine.score` is contextual, which is a strength.
  * `MealsView.MealRecommendationEngine.copy` and `recommendationFactors` return hardcoded English badges/reasons/factors.
  * `MealsView`, `MealBuilderView`, and `CustomMealBuilderView` have many `lineLimit(1)`, `minimumScaleFactor`, and fixed-height controls.
* User impact: The nutrition feature may look intelligent in English but inconsistent in Russian, and small devices can clip meal names or portion labels.
* Recommended fix: Localize recommendation copy, shorten factor labels, add validation copy for missing title/portion/macros, and add Russian Dynamic Type snapshots for meal library, custom builder, and food details.
* Risk of fix: Low.

### 16. Semantic Color Ownership Is Inconsistent Across Premium Surfaces

* Area: UI consistency
* File(s): `WeekFit/Features/Home/Views/TodayView.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/CoachFinalStoryRenderModel.swift`, `WeekFit/Features/Nutrition/new/CoachEngine/ExpertCoachViewV3.swift`, `WeekFit/Features/Planner/Views/WeekPlanerView.swift`, `WeekFit/Theme/WeekFitTheme.swift`, `WeekFit/Theme/WeekFitSheetChrome.swift`
* Problem: Several surfaces define local colors instead of consistently using semantic theme tokens. Recovery/meal/nutrition colors are sometimes visually overloaded.
* Evidence:
  * `TodayView` defines local `activityColor`, `nutritionColor`, `recoveryColor`, and hardcoded card colors.
  * Planner empty day uses `#7E8CFF` purple for add activity instead of action green.
  * Insights previews use `WeekFitTheme.meal` for recovery in multiple places.
  * Coach render colors are semantic in places (`CoachPalette.hydration`, `.fueling`, `.warning`) but fallback/legacy views can still inherit hero/green colors.
* User impact: The app can feel polished screen-by-screen but less coherent as a premium system. Main actions may all feel like hero purple/green instead of semantically meaningful.
* Recommended fix: Add a small semantic color guide in code comments or theme extensions: action/start green, hydration blue, nutrition orange, warning orange/red, recovery teal/green, live/up-next bronze/champagne. Migrate one surface at a time.
* Risk of fix: Low for token additions, medium for broad visual changes.

## Low / Polish Issues

### 17. Planner Empty State And Status Copy Can Clip In Russian

* Area: Planner
* File(s): `WeekFit/Features/Planner/Views/WeekPlanerView.swift`, `WeekFit/Features/Planner/Views/PlanAddActivitySheet.swift`
* Problem: Empty state and row metadata often use single-line labels and fixed heights.
* Evidence:
  * `emptySelectedDay` applies `.lineLimit(1)` to `AppText.Planner.buildYourDayMessage`.
  * Planner rows use multiple `.lineLimit(1)` calls around title, subtitle, time, and status.
* User impact: Russian planner copy can truncate exactly where the user needs guidance.
* Recommended fix: Allow two lines for explanatory text, keep status badges short, and use `minimumScaleFactor` only for compact metadata, not descriptions.
* Risk of fix: Low.

### 18. Accessibility Labels Are Sparse For Charts, Rings, And Metric Cards

* Area: Accessibility
* File(s): `WeekFit/Features/Insights/InsightsView.swift`, `WeekFit/Features/Highlights/HighlightsView.swift`, `WeekFit/Features/Home/Views/TodayView.swift`, `WeekFit/Features/Home/Views/Activity/ActivityIntelligenceView.swift`, `WeekFit/Features/Home/Views/Recovery/RecoveryDetailsView.swift`
* Problem: Close buttons and tab labels are covered, but charts, rings, and dense metric cards do not appear to have accessible summaries.
* Evidence:
  * `rg accessibilityLabel` finds close buttons and the bottom tab bar, but little for chart/ring summaries.
  * `InsightLineChart` and bar/ring components are visual-first.
* User impact: VoiceOver users may hear isolated labels without the trend interpretation.
* Recommended fix: Add `.accessibilityElement(children: .ignore)` and localized summary labels to top insight charts, recovery rings, activity metrics, hydration/nutrition progress, and planner status cards.
* Risk of fix: Low.

### 19. Profile Debug Entry Is Hardcoded

* Area: Profile / Settings
* File(s): `WeekFit/Features/Auth/Views/ProfileView.swift`
* Problem: `Text("Coach Debug")` is hardcoded.
* Evidence: Direct string in `ProfileView`.
* User impact: If visible outside debug builds or in Russian, it breaks localization and premium polish.
* Recommended fix: Wrap in `#if DEBUG` if not already gated by surrounding logic, and localize if user-visible.
* Risk of fix: Low.

### 20. Month Planner Placeholder Feels Less Premium Than Week Planner

* Area: Planner
* File(s): `WeekFit/Features/Planner/Views/WeekPlanerView.swift`
* Problem: Month view is a placeholder. That is acceptable if intentional, but it should be framed as "coming soon" with a clear reason and not compete with the week planner.
* Evidence: `monthPlaceholderCard` renders `AppText.Planner.monthComing` and `AppText.Planner.monthSourceOfTruth`.
* User impact: Users may think a core planner mode is unfinished.
* Recommended fix: Either hide the mode until useful or position it as an explicit preview/coming-soon card.
* Risk of fix: Low.

## Suggested Test Plan

### Manual Test Scenarios

* Fresh install, English:
  * Open Today with no Health permission, no meals, no planner rows, no insights data.
  * Verify the app tells one next step and does not look broken.
* Fresh install, Russian:
  * Repeat on iPhone SE and iPhone 15 Pro with Dynamic Type Large and Extra Large.
  * Confirm no clipped Health access, Planner, Today Coach, Meals, Insights, and Profile strings.
* Health access:
  * Deny Health permission, return from Settings, grant later, open before sleep data arrives, open after sleep sync.
  * Verify calm missing-data copy and no fake recovery score.
* Coach scenarios:
  * No planned activities.
  * Morning missing sleep.
  * Morning Health not synced yet.
  * Active Watch workout.
  * Watch workout ended before HealthKit import.
  * Workout completed from Watch and matched to planned row.
  * Planned workout completed early.
  * Manual start before planned time.
  * Heavy workout later today.
  * Recovery walk later today.
  * Sauna later today.
  * Evening with no activities left.
  * Tomorrow long endurance ride.
  * Late-night app usage.
  * Completed heavy training.
  * Completed light walk.
  * Conflicting hydration/fuel signals.
* Planner:
  * Empty week, single workout, multiple same-day workouts, completed synced workout, unmatched imported workout, skipped activity, live activity.
* Nutrition/hydration:
  * Create custom food, create custom meal, log multiple portions, edit saved food, log drink, no saved items, recent/suggested items.
* Insights/Highlights:
  * No data, partial data, enough data, recovery decline, stable week, hydration gap, protein gap.

### Unit Tests

* Coach:
  * Add explicit scenario tests in `WeekFitTests/Coach/CoachStateNarrativeContractTests.swift` or a new `CoachProductScenarioXCTests.swift`.
  * Assert final story owner, color family, primary action, support actions, and forbidden phrases ("next activity" when none exists).
  * Assert hydration/fuel only become primary in safety-critical/activity-execution cases.
* HealthKit / Watch:
  * Extend `ActivityReconcilerXCTests` for:
    * workout ended before planned start
    * workout started 46-75 minutes early
    * same-day multiple workouts of same family
    * walk logged before planned walk
    * missing duration/zero duration import
    * missing HR does not block match
  * Add coordinator duplicate tests for app restart/stale activities array by querying SwiftData before insert.
* Recovery:
  * Extend `RecoveryScoreEngineXCTests` for missing sleep with HRV/RHR present and delayed sleep arrival.
* Insights:
  * Extend `InsightsSnapshotModelTests` for no-data, partial-data, and top-insight prioritization.
* Localization:
  * Extend `LocalizationRegressionTests` to fail on hardcoded English in release-visible Swift files where practical.
  * Add assertions for required Russian keys and short "Synced" status labels.

### Snapshot / UI Tests

* Russian + Dynamic Type Large and Extra Large snapshots:
  * `HealthAccessView`
  * `TodayView`
  * `ExpertCoachViewV3`
  * `WeekPlannerView`
  * `PlanAddActivitySheet`
  * `MealsView`
  * `CustomMealBuilderView`
  * `InsightsView`
  * `HighlightsView`
  * `ProfileView`
* Accessibility snapshots:
  * VoiceOver label checks for charts/rings/progress cards.
  * Tap target checks for compact sheet buttons and planner row actions.

## Safe Implementation Plan

### 1. No-Risk Copy / Localization Fixes

* Fix raw localization-key rendering in `ActivityIntelligenceView`.
* Move hardcoded Insights fallback copy from `InsightsStoryEngine` into `Localizable.xcstrings`.
* Wire existing `coach.eveningReview.*` keys in `CoachEveningReviewSection`.
* Move Day Flow display strings to semantic status keys and localize at render time.
* Move Meals recommendation badge/reason/factor copy from `MealsView` into localization keys.
* Replace `HealthAccessView` inline English/Russian readiness labels with localized keys.
* Localize or DEBUG-gate `ProfileView` "Coach Debug".
* Add/extend localization regression tests for the new keys.

### 2. UI Consistency Fixes

* Add semantic color tokens or comments to `WeekFitTheme`/Coach palette for action, hydration, nutrition, warning, recovery, and live/up-next.
* Update Planner empty action from purple toward action green.
* Replace one-line explanatory labels with two-line/flexible text in Planner empty state, Health access readiness rows, and meal recommendation text.
* Add Russian Dynamic Type snapshots before broader layout changes.

### 3. Coach Logic Cleanup

* Add Coach product scenario tests first.
* Add limited-confidence missing-sleep/missing-recovery tests before relaxing `CoachFinalStory` readiness gates.
* Instrument or assert user-visible fallback usage in `ExpertCoachViewV3`, `CoachFinalStoryRenderModel`, `CoachState`, `CoachNarrativeBuilder`, and `CoachScenarioRule`.
* Only after tests pass, narrow fallback rendering so user-visible Coach stories come from `CoachFinalStory` or explicit localized missing-data states.
* Preserve hydration/fuel as support signals unless activity execution or safety-critical thresholds justify primary ownership.

### 4. HealthKit Sync / Reconciliation Tests

* Add Health access state tests that distinguish requested, denied, partial, empty, and usable signal states.
* Start `WatchLiveWorkoutBridge` from coordinator startup and add a startup/live-message test.
* Extend `ActivityReconcilerXCTests` before changing matching windows.
* Add tests for the future-boundary case where a workout ends before the planned start.
* Add duplicate prevention tests that simulate app restart/stale activity arrays.
* If needed, add a SwiftData lookup by `healthKitWorkoutUUID` before imported insert.
* Add delayed sleep retry/observer tests for app-open-before-sleep-arrives.
* Add a short recently-ended Watch workout state test before changing live bridge behavior.

### 5. Insights Improvements

* Decide whether Insights is a shipped tab. If yes, restore tab routing with no-data snapshots; if no, remove/defer user-facing links/actions that imply Insights exists.
* Localize and strengthen no-data/partial-data states.
* Ensure one top insight is visually dominant and includes reason, evidence, concrete action, and destination.
* Add snapshot tests for Russian and small devices.

## Smallest Safe Set Of Fixes To Start

* `WeekFit/Features/Home/Views/Activity/ActivityIntelligenceView.swift`
  * Fix raw localization keys by wrapping existing keys with `WeekFitLocalizedString` or localizing inside reusable label helpers.
  * Test coverage: English/Russian Activity detail snapshots for empty workouts, HR zones, and synced source badges.
* `WeekFit/Services/connectors/WeekFitActivityCoordinator.swift`
  * Start `WatchLiveWorkoutBridge` from coordinator startup.
  * Test coverage: coordinator startup/live-message test; manual Watch live workout verification.
* `WeekFit/Services/connectors/ActivityReconciler.swift`
  * Add a tested guard that prevents workouts ending before a planned start from completing that future planned row.
  * Test coverage: `09:20-09:50` must not complete `10:00`; `09:30-10:20` still should.
* `WeekFit/Components/WeekFitBottomBar.swift` and `WeekFit/Features/AppShell/WeekFitRootView.swift`
  * Make an explicit product decision for Insights reachability: restore with no-data state or remove/defer references.
  * Test coverage: bottom-tab routing test plus no-data Insights snapshot if restored.
* `WeekFit/Features/Insights/InsightsStoryEngine.swift`
  * Move fallback story copy into `Localizable.xcstrings`.
  * Test coverage: extend `LocalizationRegressionTests` and `InsightsSnapshotModelTests`.
* `WeekFit/Features/Nutrition/new/CoachEngine/CoachEveningReviewSection.swift`
  * Wire existing localized evening-review keys.
  * Test coverage: Russian Coach evening review snapshots for none/planned/completed/skipped.
* `WeekFit/Features/Meals/MealsView.swift`
  * Move recommendation badge/reason/factor strings into localization keys.
  * Test coverage: add a meal recommendation localization regression test and Russian snapshot for `MealsView`.
* `WeekFit/Features/Auth/Views/HealthAccessView.swift`
  * Replace inline readiness labels with keys; remove fixed text-height assumptions where text can expand.
  * Test coverage: Health access Russian Dynamic Type snapshot.
* `WeekFit/Features/Planner/Views/WeekPlanerView.swift`
  * Allow Planner empty-state message to wrap and use action-green styling for add activity.
  * Test coverage: Planner empty week Russian snapshot.
* `WeekFitTests/Coach/CoachProductScenarioXCTests.swift`
  * Add scenario tests before touching Coach logic.
  * Coverage: no-activity, missing-sleep morning, Watch live/completed, early completion, late night, tomorrow-heavy-load, hydration/fuel conflict.
* `WeekFitTests/Coach/ActivityReconcilerXCTests.swift`
  * Add matching/duplicate edge tests before changing HealthKit sync.
  * Coverage: same-day multiple workouts, ended-before-planned-start, early-start threshold, restart duplicate risk.
