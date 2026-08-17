import Foundation

enum HardTrainingLowRecoveryCostBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .hardTrainingLowRecoveryCost

    private static let emergedRecoveryCost = 8.0
    private static let establishedRecoveryCost = 6.0
    private static let lowRecoveryThreshold = 60
    private static let goodRecoveryThreshold = 70
    private static let minimumEligibleDays = 12
    private static let minimumAnchorCount = 3

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryCost ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryCost,
            establishedThreshold: establishedRecoveryCost
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> HardTrainingLowRecoveryCostEvaluation? {
        let eligible = observations
            .filter(\.hasTrainingAndRecoverySignal)
            .sorted { $0.dayKey < $1.dayKey }

        guard eligible.count >= minimumEligibleDays else { return nil }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var postLowRecoveryHard: [Int] = []
        var postGoodRecoveryHard: [Int] = []

        for anchor in eligible where anchor.isModerateOrHardTrainingDay {
            guard let nextRecovery = nextDayRecovery(after: anchor, indexed: indexed, calendar: calendar) else {
                continue
            }

            if anchor.recoveryPercent < lowRecoveryThreshold {
                postLowRecoveryHard.append(nextRecovery)
            } else if anchor.recoveryPercent >= goodRecoveryThreshold {
                postGoodRecoveryHard.append(nextRecovery)
            }
        }

        guard postLowRecoveryHard.count >= minimumAnchorCount,
              postGoodRecoveryHard.count >= minimumAnchorCount else {
            return nil
        }

        return HardTrainingLowRecoveryCostEvaluation(
            goodRecoveryHardNextDayAverage: BeliefEvaluationSupport.average(postGoodRecoveryHard),
            lowRecoveryHardNextDayAverage: BeliefEvaluationSupport.average(postLowRecoveryHard),
            goodRecoveryHardAnchorCount: postGoodRecoveryHard.count,
            lowRecoveryHardAnchorCount: postLowRecoveryHard.count,
            eligibleDayCount: eligible.count
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

    private static func evidence(from evaluation: HardTrainingLowRecoveryCostEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleDayCount,
            primaryGroupSampleCount: evaluation.goodRecoveryHardAnchorCount,
            comparisonGroupSampleCount: evaluation.lowRecoveryHardAnchorCount,
            primaryGroupAverage: evaluation.goodRecoveryHardNextDayAverage,
            comparisonGroupAverage: evaluation.lowRecoveryHardNextDayAverage,
            notes: "next-day recovery after hard/moderate training while well recovered (>=70%) vs poorly recovered (<60%)"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let eligible = observations.filter(\.hasTrainingAndRecoverySignal)
        if eligible.count < minimumEligibleDays {
            return .insufficientObservations(required: minimumEligibleDays, actual: eligible.count)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryCost
            )
        }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current
        var lowCount = 0
        var goodCount = 0

        for anchor in eligible where anchor.isModerateOrHardTrainingDay {
            guard nextDayRecovery(after: anchor, indexed: indexed, calendar: calendar) != nil else {
                continue
            }
            if anchor.recoveryPercent < lowRecoveryThreshold {
                lowCount += 1
            } else if anchor.recoveryPercent >= goodRecoveryThreshold {
                goodCount += 1
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: minimumAnchorCount,
            primaryActual: goodCount,
            comparisonRequired: minimumAnchorCount,
            comparisonActual: lowCount
        )
    }
}
