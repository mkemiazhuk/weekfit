# WeekFit 3-Month Scalability Plan

Track progress against the acquisition audit remediation roadmap.

## Phase 1 — Foundation (complete)

| Item | Status | Notes |
|------|--------|-------|
| Typed `AppRefreshEvent` bus | Done | `AppRefreshEvent` + `AppSessionState` refactor |
| Delete dead coach code | Done | Removed builder/engine; kept `CoachNarrative` type |
| Extract `CoachFinalStoryBuilder` | Done | `CoachState.swift` 997 LOC + `CoachFinalStoryBuilder.swift` 5780 LOC |
| Localization parity script | Done | `Scripts/check_localization_parity.py` |
| First SPM package scaffold | Done | `Packages/WeekFitWorkoutMetrics` linked in Xcode |

## Phase 2 — Module boundaries (complete)

| Item | Status | Notes |
|------|--------|-------|
| `WeekFitCoachCore` package | Done | `CoachActivityDescriptor` + classification in SPM |
| `WeekFitHealthKit` package | Done | `ActivityReconciler` moved to SPM |
| `WeekFitPlanner` package | Done | `PlannedActivity`, `TimelineLayoutEngine` in SPM |
| `WeekFitMealsUI` package | Deferred | Meals still in app target; VM extracted first |
| Localization key fixes | Done | `planner.weekOverview` alignment, `today.quickActions.liveActivity` |
| Module re-exports | Done | `WeekFitModuleExports.swift` |

## Phase 3 — View layer (complete)

| Item | Status | Notes |
|------|--------|-------|
| `TodayViewModel` | Done | Health refresh, nutrition sync, coach insight orchestration |
| `CoachScreenViewModel` | Done | Date selection, day context, health-connect gating |
| `PlannerViewModel` hardening | Done | `PlanViewModelTests` added |
| `MealsViewModel` | Done | Recommendations, custom meal loading |

## Phase 4 — Quality & compliance (in progress)

| Item | Status | Notes |
|------|--------|-------|
| Dynamic Type + VoiceOver pass | Checklist | See `docs/AccessibilityPass.md` |
| Ship or kill Insights | Done | Kill until QA sprint — see `docs/UnshippedFeatures.md` |
| UI tests (core flows) | Done | `-ui-testing` launch arg + tab navigation tests |
| HealthManager integration tests | Done | `HealthManagerIntegrationTests` |
| Auth / Keychain / backend | Pending | Greenfield |

## Phase 5 — Platform (in progress)

| Item | Status | Notes |
|------|--------|-------|
| Apple Watch target decision | Documented | See `docs/AppleWatchStrategy.md` |
| Subscription / account sync | Pending | |
