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

## Phase 2 — Module boundaries (in progress)

| Item | Status | Notes |
|------|--------|-------|
| `WeekFitCoachCore` package | Done | `CoachActivityDescriptor` + classification in SPM |
| `WeekFitHealthKit` package | Pending | Reconciler, sync services, elevation |
| `WeekFitPlanner` package | Pending | `PlannedActivity`, plan view models |
| `WeekFitMealsUI` package | Pending | Meals surfaces |
| Localization key fixes | Done | `planner.weekOverview` alignment, `today.quickActions.liveActivity` |

## Phase 3 — View layer (in progress)

| Item | Status | Notes |
|------|--------|-------|
| `TodayViewModel` | Done | Health refresh, nutrition sync, coach insight orchestration |
| `CoachScreenViewModel` | Pending | Extract from `ExpertCoachViewV3` |
| `PlannerViewModel` hardening | Pending | Tests + reconcile ownership |
| `MealsViewModel` | Pending | Recommendations, logging |

## Phase 4 — Quality & compliance

| Item | Status | Notes |
|------|--------|-------|
| Dynamic Type + VoiceOver pass | Pending | Today, Coach, Plan, Meals |
| Ship or kill Insights | Pending | See `docs/UnshippedFeatures.md` |
| UI tests (core flows) | Pending | Login → Today → meal → plan |
| HealthManager integration tests | Pending | |
| Auth / Keychain / backend | Pending | Greenfield |

## Phase 5 — Platform

| Item | Status | Notes |
|------|--------|-------|
| Apple Watch target decision | Pending | Document strategy if no companion repo |
| Subscription / account sync | Pending | |
