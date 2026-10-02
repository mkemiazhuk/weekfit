import Foundation

@MainActor
enum CoachUnderstandingService {

    /// Coalesced historical observation fill — must never block tab switches / live UI.
    private static var backfillTask: Task<Void, Never>?

    static func refresh(
        healthManager: HealthManager,
        through date: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil,
        backfillDays: Int = 42
    ) async {
        // Critical path: today's observation only. A 42-day HealthKit backfill used to
        // await here on MainActor after Watch workout stop — under weak connectivity
        // HK/Watch updates arrive in fragments and the queued work starved tab switching.
        await CoachObservationStore.recordToday(
            from: healthManager,
            date: date,
            plannedActivities: plannedActivities,
            calorieTarget: calorieTarget
        )
        evaluateBeliefs()
        scheduleBackfill(
            healthManager: healthManager,
            through: date,
            plannedActivities: plannedActivities,
            calorieTarget: calorieTarget,
            backfillDays: backfillDays
        )
    }

    /// Starts (or restarts) a low-priority historical backfill without awaiting it.
    static func scheduleBackfill(
        healthManager: HealthManager,
        through date: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil,
        backfillDays: Int = 42
    ) {
        backfillTask?.cancel()
        backfillTask = Task(priority: .utility) { @MainActor in
            // Let the workout-stop / tab-switch UI settle first.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            await CoachObservationStore.backfill(
                healthManager: healthManager,
                through: date,
                plannedActivities: plannedActivities,
                calorieTarget: calorieTarget,
                dayCount: backfillDays
            )
            guard !Task.isCancelled else { return }
            evaluateBeliefs()
        }
    }

    static func evaluateBeliefs() {
        let observations = CoachObservationStore.allObservations()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        for result in results {
            CoachUnderstandingStore.applyEvaluation(result)
        }

        CoachDiscoveryProjector.project(
            results: results,
            spokenEventIDs: CoachUnderstandingStore.spokenEventIDsSnapshot()
        )
    }
}
