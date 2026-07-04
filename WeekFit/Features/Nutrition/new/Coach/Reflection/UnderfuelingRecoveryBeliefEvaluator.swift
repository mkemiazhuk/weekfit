import Foundation

enum UnderfuelingRecoveryBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .underfuelingRecovery

    private static let emergedRecoveryDrop = 8.0
    private static let establishedRecoveryDrop = 6.0
    private static let underfuelDeficitThreshold = 450
    private static let adequatelyFueledDeficitMax = 200
    private static let minimumOverallRecoveryAverage = 58.0
    private static let minimumFueledBaselineRecoveryAverage = 58.0

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryDrop ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryDrop,
            establishedThreshold: establishedRecoveryDrop
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> UnderfuelingRecoveryEvaluation? {
        let eligible = observations
            .filter(\.hasPopulatedNutritionFieldsResolved)
            .filter(\.hasRecoverySignal)
            .filter { $0.calorieDeficit != nil }
            .sorted { $0.dayKey < $1.dayKey }

        guard eligible.count >= 12 else { return nil }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        guard overallAverage >= minimumOverallRecoveryAverage else { return nil }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var postUnderfueledRecoveries: [Int] = []
        var postFueledRecoveries: [Int] = []
        var underfueledAnchorCount = 0
        var adequatelyFueledAnchorCount = 0

        for anchor in eligible {
            guard let nextRecovery = nextDayRecovery(after: anchor, indexed: indexed, calendar: calendar) else {
                continue
            }

            if isUnderfueled(anchor) {
                underfueledAnchorCount += 1
                postUnderfueledRecoveries.append(nextRecovery)
            } else if isAdequatelyFueled(anchor) {
                adequatelyFueledAnchorCount += 1
                postFueledRecoveries.append(nextRecovery)
            }
        }

        guard underfueledAnchorCount >= 3,
              adequatelyFueledAnchorCount >= 3,
              postUnderfueledRecoveries.count >= 3,
              postFueledRecoveries.count >= 4 else {
            return nil
        }

        let fueledAverage = BeliefEvaluationSupport.average(postFueledRecoveries)
        guard fueledAverage >= minimumFueledBaselineRecoveryAverage else { return nil }

        let underfueledAverage = BeliefEvaluationSupport.average(postUnderfueledRecoveries)

        return UnderfuelingRecoveryEvaluation(
            adequatelyFueledRecoveryAverage: fueledAverage,
            underfueledRecoveryAverage: underfueledAverage,
            underfueledAnchorCount: underfueledAnchorCount,
            adequatelyFueledAnchorCount: adequatelyFueledAnchorCount,
            postUnderfueledSampleCount: postUnderfueledRecoveries.count,
            postFueledSampleCount: postFueledRecoveries.count,
            eligibleDayCount: eligible.count
        )
    }

    static func isUnderfueled(_ observation: CoachDailyObservation) -> Bool {
        guard let deficit = observation.calorieDeficit else { return false }
        return deficit >= underfuelDeficitThreshold
    }

    static func isAdequatelyFueled(_ observation: CoachDailyObservation) -> Bool {
        guard let deficit = observation.calorieDeficit else { return false }
        return deficit < adequatelyFueledDeficitMax
    }

    static func nextDayRecovery(
        after anchor: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> Int? {
        guard let anchorDate = CoachDailyObservation.date(fromDayKey: anchor.dayKey, calendar: calendar) else {
            return nil
        }
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) else {
            return nil
        }

        let dayKey = CoachDailyObservation.dayKey(for: nextDate, calendar: calendar)
        guard let observation = indexed[dayKey], observation.hasRecoverySignal else {
            return nil
        }
        return observation.recoveryPercent
    }

    private static func evidence(from evaluation: UnderfuelingRecoveryEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleDayCount,
            primaryGroupSampleCount: evaluation.postFueledSampleCount,
            comparisonGroupSampleCount: evaluation.postUnderfueledSampleCount,
            primaryGroupAverage: evaluation.adequatelyFueledRecoveryAverage,
            comparisonGroupAverage: evaluation.underfueledRecoveryAverage,
            notes: "next-day recovery after adequately fueled days vs after underfueled days"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let nutritionRecovery = observations
            .filter(\.hasPopulatedNutritionFieldsResolved)
            .filter(\.hasRecoverySignal)

        let missingDeficit = nutritionRecovery.filter { $0.calorieDeficit == nil }.count
        if missingDeficit > 0 {
            return .missingRequiredFields(["calorie deficit"])
        }

        let eligible = nutritionRecovery.filter { $0.calorieDeficit != nil }
        if eligible.count < 12 {
            return .insufficientObservations(required: 12, actual: eligible.count)
        }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        if overallAverage < minimumOverallRecoveryAverage {
            return .uniformLowBaseline
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryDrop
            )
        }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current
        var underfueledCount = 0
        var fueledCount = 0

        for anchor in eligible {
            guard nextDayRecovery(after: anchor, indexed: indexed, calendar: calendar) != nil else {
                continue
            }
            if isUnderfueled(anchor) {
                underfueledCount += 1
            } else if isAdequatelyFueled(anchor) {
                fueledCount += 1
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: 3,
            primaryActual: fueledCount,
            comparisonRequired: 3,
            comparisonActual: underfueledCount
        )
    }
}
