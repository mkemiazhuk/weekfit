import Foundation

enum CoachBeliefRegistry {

    private static let evaluatorTypes: [any CoachBeliefEvaluator.Type] = [
        SleepConsistencyBeliefEvaluator.self,
        SleepDurationBeliefEvaluator.self,
        LateBedtimeBeliefEvaluator.self,
        HeavyLoadRecoveryLagBeliefEvaluator.self,
        RecoveryAfterRestDayBeliefEvaluator.self,
        ConsecutiveHardDaysFatigueBeliefEvaluator.self,
        UnderfuelingRecoveryBeliefEvaluator.self,
    ]

    static var registeredBeliefIDs: [CoachBeliefID] {
        evaluatorTypes.map { $0.beliefID }
    }

    static func evaluateAll(observations: [CoachDailyObservation]) -> [BeliefEvaluationResult] {
        evaluatorTypes.map { evaluator in
            let currentMaturity = CoachUnderstandingStore.belief(for: evaluator.beliefID).maturity
            return evaluator.evaluate(
                observations: observations,
                currentMaturity: currentMaturity
            )
        }
    }
}
