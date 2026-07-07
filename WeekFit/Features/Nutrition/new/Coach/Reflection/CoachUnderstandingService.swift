import Foundation

@MainActor
enum CoachUnderstandingService {

    static func refresh(
        healthManager: HealthManager,
        through date: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil,
        backfillDays: Int = 21
    ) async {
        CoachObservationStore.recordToday(
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

        for result in CoachBeliefRegistry.evaluateAll(observations: observations) {
            CoachUnderstandingStore.applyEvaluation(result)
        }
    }
}
