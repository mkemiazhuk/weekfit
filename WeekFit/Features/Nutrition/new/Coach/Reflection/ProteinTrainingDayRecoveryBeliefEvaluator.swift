import Foundation

enum ProteinTrainingDayRecoveryBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .proteinTrainingDayRecovery

    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0
    private static let minimumEligibleAnchors = 8
    private static let minimumTertileSampleCount = 3
    private static let minimumProteinSpreadGrams = 20

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

    static func analyze(observations: [CoachDailyObservation]) -> ProteinTrainingDayRecoveryEvaluation? {
        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })

        let anchors = observations
            .filter(\.isModerateOrHardTrainingDay)
            .filter(\.hasTrustworthyNutritionForBeliefs)
            .filter { $0.proteinGrams != nil }
            .compactMap { observation -> (protein: Int, nextRecovery: Int)? in
                guard let protein = observation.proteinGrams,
                      let nextRecovery = nextDayRecovery(
                        after: observation,
                        indexed: indexed,
                        calendar: calendar
                      ) else {
                    return nil
                }
                return (protein, nextRecovery)
            }
            .sorted { $0.protein < $1.protein }

        guard anchors.count >= minimumEligibleAnchors else { return nil }

        let tertileSize = anchors.count / 3
        guard tertileSize >= minimumTertileSampleCount else { return nil }

        let low = Array(anchors.prefix(tertileSize))
        let high = Array(anchors.suffix(tertileSize))

        guard let lowMedian = BeliefEvaluationSupport.median(low.map(\.protein)),
              let highMedian = BeliefEvaluationSupport.median(high.map(\.protein)),
              highMedian - lowMedian >= minimumProteinSpreadGrams else {
            return nil
        }

        return ProteinTrainingDayRecoveryEvaluation(
            highProteinRecoveryAverage: BeliefEvaluationSupport.average(high.map(\.nextRecovery)),
            lowProteinRecoveryAverage: BeliefEvaluationSupport.average(low.map(\.nextRecovery)),
            highProteinSampleCount: high.count,
            lowProteinSampleCount: low.count,
            eligibleAnchorCount: anchors.count,
            highProteinMedianGrams: highMedian,
            lowProteinMedianGrams: lowMedian
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

    private static func evidence(from evaluation: ProteinTrainingDayRecoveryEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleAnchorCount,
            primaryGroupSampleCount: evaluation.highProteinSampleCount,
            comparisonGroupSampleCount: evaluation.lowProteinSampleCount,
            primaryGroupAverage: evaluation.highProteinRecoveryAverage,
            comparisonGroupAverage: evaluation.lowProteinRecoveryAverage,
            notes: "next-day recovery after high-protein training days (median \(evaluation.highProteinMedianGrams)g) vs low-protein (median \(evaluation.lowProteinMedianGrams)g)"
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

        let missingProtein = trainingNutrition.filter { $0.proteinGrams == nil }.count
        if missingProtein > 0 {
            return .missingRequiredFields(["protein"])
        }

        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })
        var anchorCount = 0
        for observation in trainingNutrition where observation.proteinGrams != nil {
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
