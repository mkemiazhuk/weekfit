import Foundation

enum PostWorkoutProteinRecoveryBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .postWorkoutProteinRecovery

    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0
    private static let defaultSplitGrams = 30
    private static let minimumEligibleAnchors = 8
    private static let minimumGroupSampleCount = 3
    private static let minimumMedianSplitSpreadGrams = 15

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

    static func analyze(observations: [CoachDailyObservation]) -> PostWorkoutProteinRecoveryEvaluation? {
        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })

        let anchors = observations
            .filter(\.isModerateOrHardTrainingDay)
            .filter(\.hasTrustworthyNutritionForBeliefs)
            .filter { $0.hardestWorkoutEndMinutes != nil }
            .filter { $0.proteinWithinPostWorkoutWindowGrams != nil }
            .compactMap { observation -> (windowProtein: Int, nextRecovery: Int)? in
                guard let windowProtein = observation.proteinWithinPostWorkoutWindowGrams,
                      let nextRecovery = nextDayRecovery(
                        after: observation,
                        indexed: indexed,
                        calendar: calendar
                      ) else {
                    return nil
                }
                return (windowProtein, nextRecovery)
            }

        guard anchors.count >= minimumEligibleAnchors else { return nil }

        let split = resolveSplit(anchors: anchors)
        let higher = anchors.filter { $0.windowProtein >= split }
        let lower = anchors.filter { $0.windowProtein < split }

        guard higher.count >= minimumGroupSampleCount,
              lower.count >= minimumGroupSampleCount else {
            return nil
        }

        return PostWorkoutProteinRecoveryEvaluation(
            higherWindowProteinRecoveryAverage: BeliefEvaluationSupport.average(higher.map(\.nextRecovery)),
            lowerWindowProteinRecoveryAverage: BeliefEvaluationSupport.average(lower.map(\.nextRecovery)),
            higherWindowSampleCount: higher.count,
            lowerWindowSampleCount: lower.count,
            eligibleAnchorCount: anchors.count,
            splitThresholdGrams: split
        )
    }

    /// Prefer a 30g window split when both sides have enough samples; otherwise median split if spread is meaningful.
    static func resolveSplit(anchors: [(windowProtein: Int, nextRecovery: Int)]) -> Int {
        let higherAtDefault = anchors.filter { $0.windowProtein >= defaultSplitGrams }
        let lowerAtDefault = anchors.filter { $0.windowProtein < defaultSplitGrams }

        if higherAtDefault.count >= minimumGroupSampleCount,
           lowerAtDefault.count >= minimumGroupSampleCount {
            return defaultSplitGrams
        }

        guard let medianProtein = BeliefEvaluationSupport.median(anchors.map(\.windowProtein)) else {
            return defaultSplitGrams
        }

        let sorted = anchors.map(\.windowProtein).sorted()
        let spread = (sorted.last ?? 0) - (sorted.first ?? 0)
        if spread >= minimumMedianSplitSpreadGrams {
            return max(medianProtein, 1)
        }

        return defaultSplitGrams
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

    private static func evidence(from evaluation: PostWorkoutProteinRecoveryEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleAnchorCount,
            primaryGroupSampleCount: evaluation.higherWindowSampleCount,
            comparisonGroupSampleCount: evaluation.lowerWindowSampleCount,
            primaryGroupAverage: evaluation.higherWindowProteinRecoveryAverage,
            comparisonGroupAverage: evaluation.lowerWindowProteinRecoveryAverage,
            notes: "next-day recovery after post-workout protein >= \(evaluation.splitThresholdGrams)g vs lower"
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

        let missingTiming = trainingNutrition.filter {
            $0.hardestWorkoutEndMinutes == nil || $0.proteinWithinPostWorkoutWindowGrams == nil
        }.count
        if missingTiming > 0 {
            return .missingRequiredFields(["post-workout protein timing"])
        }

        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })
        var anchorCount = 0
        for observation in trainingNutrition
            where observation.hardestWorkoutEndMinutes != nil
            && observation.proteinWithinPostWorkoutWindowGrams != nil
        {
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

        return .insufficientGroupSamples(
            primaryRequired: minimumGroupSampleCount,
            primaryActual: 0,
            comparisonRequired: minimumGroupSampleCount,
            comparisonActual: 0
        )
    }
}
