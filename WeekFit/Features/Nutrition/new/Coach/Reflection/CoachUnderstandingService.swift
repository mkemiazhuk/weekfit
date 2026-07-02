import Foundation

@MainActor
enum CoachUnderstandingService {

    static func refresh(
        healthManager: HealthManager,
        through date: Date,
        backfillDays: Int = 21
    ) async {
        CoachObservationStore.recordToday(from: healthManager, date: date)
        await CoachObservationStore.backfill(
            healthManager: healthManager,
            through: date,
            dayCount: backfillDays
        )
        evaluateBeliefs()
    }

    static func evaluateBeliefs() {
        let observations = CoachObservationStore.allObservations()
        let result = SleepConsistencyBeliefEvaluator.evaluate(observations: observations)
        CoachUnderstandingStore.applyEvaluation(
            beliefID: .sleepConsistencyRecovery,
            nextMaturity: result.maturity,
            event: result.event
        )
    }
}
