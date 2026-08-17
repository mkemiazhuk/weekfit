import Foundation

enum CarbsTrainingDayRecoveryBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .carbsTrainingDayRecovery

    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0
    private static let minimumEligibleAnchors = 8
    private static let minimumTertileSampleCount = 3
    private static let minimumCarbsSpreadGrams = 40

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryDelta ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryDelta,
            establishedThreshold: establishedRecoveryDelta
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> CarbsTrainingDayRecoveryEvaluation? {
        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })

        let anchors = observations
            .filter(\.isModerateOrHardTrainingDay)
            .filter(\.hasTrustworthyNutritionForBeliefs)
            .filter { $0.carbsGrams != nil }
            .compactMap { observation -> (carbs: Int, nextRecovery: Int)? in
                guard let carbs = observation.carbsGrams,
                      let nextRecovery = nextDayRecovery(
                        after: observation,
                        indexed: indexed,
                        calendar: calendar
                      ) else {
                    return nil
                }
                return (carbs, nextRecovery)
            }
            .sorted { $0.carbs < $1.carbs }

        guard anchors.count >= minimumEligibleAnchors else { return nil }

        let tertileSize = anchors.count / 3
        guard tertileSize >= minimumTertileSampleCount else { return nil }

        let low = Array(anchors.prefix(tertileSize))
        let high = Array(anchors.suffix(tertileSize))

        guard let lowMedian = BeliefEvaluationSupport.median(low.map(\.carbs)),
              let highMedian = BeliefEvaluationSupport.median(high.map(\.carbs)),
              highMedian - lowMedian >= minimumCarbsSpreadGrams else {
            return nil
        }

        return CarbsTrainingDayRecoveryEvaluation(
            highCarbsRecoveryAverage: BeliefEvaluationSupport.average(high.map(\.nextRecovery)),
            lowCarbsRecoveryAverage: BeliefEvaluationSupport.average(low.map(\.nextRecovery)),
            highCarbsSampleCount: high.count,
            lowCarbsSampleCount: low.count,
            eligibleAnchorCount: anchors.count,
            highCarbsMedianGrams: highMedian,
            lowCarbsMedianGrams: lowMedian
        )
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

    private static func evidence(from evaluation: CarbsTrainingDayRecoveryEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleAnchorCount,
            primaryGroupSampleCount: evaluation.highCarbsSampleCount,
            comparisonGroupSampleCount: evaluation.lowCarbsSampleCount,
            primaryGroupAverage: evaluation.highCarbsRecoveryAverage,
            comparisonGroupAverage: evaluation.lowCarbsRecoveryAverage,
            notes: "next-day recovery after high-carb training days (median \(evaluation.highCarbsMedianGrams)g) vs low-carb (median \(evaluation.lowCarbsMedianGrams)g)"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let trainingNutrition = observations
            .filter(\.isModerateOrHardTrainingDay)
            .filter(\.hasTrustworthyNutritionForBeliefs)

        let missingCarbs = trainingNutrition.filter { $0.carbsGrams == nil }.count
        if missingCarbs > 0 {
            return .missingRequiredFields(["carbs"])
        }

        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })
        var anchorCount = 0
        for observation in trainingNutrition where observation.carbsGrams != nil {
            if nextDayRecovery(after: observation, indexed: indexed, calendar: calendar) != nil {
                anchorCount += 1
            }
        }

        if anchorCount < minimumEligibleAnchors {
            return .insufficientObservations(required: minimumEligibleAnchors, actual: anchorCount)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryDelta
            )
        }

        let tertileSize = anchorCount / 3
        return .insufficientGroupSamples(
            primaryRequired: minimumTertileSampleCount,
            primaryActual: tertileSize,
            comparisonRequired: minimumTertileSampleCount,
            comparisonActual: tertileSize
        )
    }
}
