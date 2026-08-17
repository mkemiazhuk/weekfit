import Foundation

enum SleepDurationBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .sleepDurationRecovery

    private static let minimumThresholdMinutes = 6 * 60
    private static let maximumThresholdMinutes = Int(8.5 * 60) // 510
    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0
    private static let minimumEligibleDays = 8
    private static let minimumSufficientSampleCount = 4
    private static let minimumInsufficientSampleCount = 2

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

    static func analyze(observations: [CoachDailyObservation]) -> SleepDurationEvaluation? {
        let eligible = observations
            .filter(\.hasSleepSignal)
            .filter(\.hasRecoverySignal)

        guard eligible.count >= minimumEligibleDays else { return nil }
        guard let rawMedian = BeliefEvaluationSupport.median(eligible.map(\.sleepMinutes)) else {
            return nil
        }

        let threshold = min(max(rawMedian, minimumThresholdMinutes), maximumThresholdMinutes)
        let sufficient = eligible.filter { $0.sleepMinutes >= threshold }
        let insufficient = eligible.filter { $0.sleepMinutes < threshold }

        guard sufficient.count >= minimumSufficientSampleCount,
              insufficient.count >= minimumInsufficientSampleCount else {
            return nil
        }

        return SleepDurationEvaluation(
            sufficientRecoveryAverage: BeliefEvaluationSupport.average(sufficient.map(\.recoveryPercent)),
            insufficientRecoveryAverage: BeliefEvaluationSupport.average(insufficient.map(\.recoveryPercent)),
            sufficientSampleCount: sufficient.count,
            insufficientSampleCount: insufficient.count,
            sufficientSleepThresholdMinutes: threshold
        )
    }

    private static func evidence(from evaluation: SleepDurationEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.sufficientSampleCount + evaluation.insufficientSampleCount,
            primaryGroupSampleCount: evaluation.sufficientSampleCount,
            comparisonGroupSampleCount: evaluation.insufficientSampleCount,
            primaryGroupAverage: evaluation.sufficientRecoveryAverage,
            comparisonGroupAverage: evaluation.insufficientRecoveryAverage,
            notes: "sleep duration >= \(evaluation.sufficientSleepThresholdMinutes)m (learned threshold) vs shorter sleep"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let eligible = observations.filter(\.hasSleepSignal).filter(\.hasRecoverySignal)
        if eligible.count < minimumEligibleDays {
            return .insufficientObservations(required: minimumEligibleDays, actual: eligible.count)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryDelta
            )
        }

        let rawMedian = BeliefEvaluationSupport.median(eligible.map(\.sleepMinutes)) ?? (7 * 60)
        let threshold = min(max(rawMedian, minimumThresholdMinutes), maximumThresholdMinutes)
        let sufficient = eligible.filter { $0.sleepMinutes >= threshold }
        let insufficient = eligible.filter { $0.sleepMinutes < threshold }

        return .insufficientGroupSamples(
            primaryRequired: minimumSufficientSampleCount,
            primaryActual: sufficient.count,
            comparisonRequired: minimumInsufficientSampleCount,
            comparisonActual: insufficient.count
        )
    }
}
