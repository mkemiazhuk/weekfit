import Foundation

enum RecoveryAfterRestDayBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .recoveryAfterRestDay

    private static let emergedRecoveryRebound = 8.0
    private static let establishedRecoveryRebound = 6.0
    private static let maximumPostHeavyRecoveryAverage = 82.0

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryRebound ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryRebound,
            establishedThreshold: establishedRecoveryRebound
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> RecoveryAfterRestDayEvaluation? {
        let eligible = observations
            .filter(\.hasTrainingAndRecoverySignal)
            .sorted { $0.dayKey < $1.dayKey }

        guard eligible.count >= 12 else { return nil }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var postHeavyRecoveries: [Int] = []
        var postRestFollowUpRecoveries: [Int] = []

        for anchor in eligible where anchor.isModerateOrHardTrainingDay {
            guard let sequence = reboundSequence(after: anchor, indexed: indexed, calendar: calendar) else {
                continue
            }
            postHeavyRecoveries.append(sequence.postHeavyRecovery)
            postRestFollowUpRecoveries.append(sequence.postRestFollowUpRecovery)
        }

        guard postHeavyRecoveries.count >= 3, postRestFollowUpRecoveries.count >= 3 else {
            return nil
        }

        let postHeavyAverage = BeliefEvaluationSupport.average(postHeavyRecoveries)
        guard postHeavyAverage <= maximumPostHeavyRecoveryAverage else { return nil }

        let postRestAverage = BeliefEvaluationSupport.average(postRestFollowUpRecoveries)

        return RecoveryAfterRestDayEvaluation(
            postHeavyRecoveryAverage: postHeavyAverage,
            postRestFollowUpRecoveryAverage: postRestAverage,
            sequenceCount: postHeavyRecoveries.count,
            eligibleDayCount: eligible.count
        )
    }

    static func reboundSequence(
        after anchor: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> (postHeavyRecovery: Int, postRestFollowUpRecovery: Int)? {
        guard let anchorDate = CoachDailyObservation.date(fromDayKey: anchor.dayKey, calendar: calendar),
              let followUpDate = calendar.date(byAdding: .day, value: 1, to: anchorDate),
              let reboundDate = calendar.date(byAdding: .day, value: 2, to: anchorDate) else {
            return nil
        }

        let followUpKey = CoachDailyObservation.dayKey(for: followUpDate, calendar: calendar)
        let reboundKey = CoachDailyObservation.dayKey(for: reboundDate, calendar: calendar)

        guard let followUpDay = indexed[followUpKey],
              followUpDay.hasTrainingAndRecoverySignal,
              followUpDay.isRestOrLightRecoveryDay,
              let reboundDay = indexed[reboundKey],
              reboundDay.hasRecoverySignal else {
            return nil
        }

        return (followUpDay.recoveryPercent, reboundDay.recoveryPercent)
    }

    private static func evidence(from evaluation: RecoveryAfterRestDayEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleDayCount,
            primaryGroupSampleCount: evaluation.sequenceCount,
            comparisonGroupSampleCount: evaluation.sequenceCount,
            primaryGroupAverage: evaluation.postRestFollowUpRecoveryAverage,
            comparisonGroupAverage: evaluation.postHeavyRecoveryAverage,
            notes: "recovery after rest/light follow-up vs recovery after heavier training"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let eligible = observations.filter(\.hasTrainingAndRecoverySignal)
        if eligible.count < 12 {
            return .insufficientObservations(required: 12, actual: eligible.count)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryRebound
            )
        }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current
        var sequenceCount = 0
        for anchor in eligible where anchor.isModerateOrHardTrainingDay {
            if reboundSequence(after: anchor, indexed: indexed, calendar: calendar) != nil {
                sequenceCount += 1
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: 3,
            primaryActual: sequenceCount,
            comparisonRequired: 3,
            comparisonActual: sequenceCount
        )
    }
}
