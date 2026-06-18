# Apple Watch Strategy

## Current state

WeekFit ships as a single iOS target. Watch connectivity code exists in the app (`WatchLiveWorkoutBridge`, `WatchWorkoutEventSender`) but there is no companion Watch app target in this repository.

## Decision (June 2026)

**Defer a standalone Watch target** until:

1. `WeekFitHealthKit` and `WeekFitPlanner` packages stabilize workout reconcile ownership.
2. Product confirms which live-session metrics must render on wrist vs phone.

## Interim approach

- Keep phone as the canonical workout session surface.
- Continue syncing completed workouts through HealthKit + `ActivityReconciler`.
- Document live-session gaps in `docs/UnshippedFeatures.md` rather than half-shipping a Watch UI.

## Next milestone

When Watch work resumes, create a `WeekFitWatch` extension target that depends only on:

- `WeekFitHealthKit`
- `WeekFitWorkoutMetrics`
- a thin shared connectivity package extracted from `WatchConnectivitySupport.swift`
