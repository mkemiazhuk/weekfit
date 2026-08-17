import Foundation

@MainActor
enum CoachUnderstandingService {

    static func refresh(
        healthManager: HealthManager,
        through date: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil,
        backfillDays: Int = 42
    ) async {
        await CoachObservationStore.recordToday(
            from: healthManager,
            date: date,
            plannedActivities: plannedActivities,
            calorieTarget: calorieTarget
        )
        await CoachObservationStore.backfill(
            healthManager: healthManager,
            through: date,
            plannedActivities: plannedActivities,
            calorieTarget: calorieTarget,
            dayCount: backfillDays
        )
        evaluateBeliefs()
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
