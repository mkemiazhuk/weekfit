import Foundation

enum SleepConsistencyBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .sleepConsistencyRecovery

    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0

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

    static func analyze(observations: [CoachDailyObservation]) -> SleepConsistencyEvaluation? {
        let eligible = observations
            .filter(\.hasSleepSignal)
            .filter(\.hasRecoverySignal)
            .compactMap { observation -> (bedtime: Int, recovery: Int)? in
                guard let bedStartMinutes = observation.bedStartNormalizedMinutes else { return nil }
                return (bedStartMinutes, observation.recoveryPercent)
            }

        guard eligible.count >= 8 else { return nil }

        let bedtimes = eligible.map(\.bedtime)
        let meanBedtime = RecoveryScoreEngine.circularAverageBedtimeMinutes(bedtimes)

        let paired = eligible.map { entry in
            (
                deviation: RecoveryScoreEngine.deviationMinutes(
                    current: entry.bedtime,
                    average: meanBedtime
                ),
                recovery: entry.recovery
            )
        }

        let sortedByDeviation = paired.sorted { $0.deviation < $1.deviation }
        let splitIndex = max(sortedByDeviation.count / 2, 1)

        let consistent = Array(sortedByDeviation.prefix(splitIndex))
        let inconsistent = Array(sortedByDeviation.suffix(sortedByDeviation.count - splitIndex))

        guard consistent.count >= 4, inconsistent.count >= 2 else { return nil }

        return SleepConsistencyEvaluation(
            consistentRecoveryAverage: BeliefEvaluationSupport.average(consistent.map(\.recovery)),
            inconsistentRecoveryAverage: BeliefEvaluationSupport.average(inconsistent.map(\.recovery)),
            consistentSampleCount: consistent.count,
            inconsistentSampleCount: inconsistent.count
        )
    }

    private static func evidence(from evaluation: SleepConsistencyEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.consistentSampleCount + evaluation.inconsistentSampleCount,
            primaryGroupSampleCount: evaluation.consistentSampleCount,
            comparisonGroupSampleCount: evaluation.inconsistentSampleCount,
            primaryGroupAverage: evaluation.consistentRecoveryAverage,
            comparisonGroupAverage: evaluation.inconsistentRecoveryAverage,
            notes: "consistent bedtime vs inconsistent bedtime"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let sleepRecoveryCount = observations.filter(\.hasSleepSignal).filter(\.hasRecoverySignal).count
        let missingBedtimeCount = observations
            .filter(\.hasSleepSignal)
            .filter(\.hasRecoverySignal)
            .filter { $0.bedStartNormalizedMinutes == nil }
            .count

        if missingBedtimeCount > 0, sleepRecoveryCount - missingBedtimeCount < 8 {
            return .missingRequiredFields(["bedtime"])
        }

        if sleepRecoveryCount < 8 {
            return .insufficientObservations(required: 8, actual: sleepRecoveryCount)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryDelta
            )
        }

        let paired = observations
            .filter(\.hasSleepSignal)
            .filter(\.hasRecoverySignal)
            .compactMap(\.bedStartNormalizedMinutes)
        let splitIndex = max(paired.count / 2, 1)
        let consistentCount = splitIndex
        let inconsistentCount = paired.count - splitIndex

        return .insufficientGroupSamples(
            primaryRequired: 4,
            primaryActual: consistentCount,
            comparisonRequired: 2,
            comparisonActual: inconsistentCount
        )
    }
}
