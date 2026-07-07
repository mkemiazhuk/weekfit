import Foundation

enum HeavyLoadRecoveryLagBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .heavyLoadRecoveryLag

    private static let emergedRecoveryLag = 8.0
    private static let establishedRecoveryLag = 6.0
    private static let minimumOverallRecoveryAverage = 58.0
    private static let minimumBaselineRecoveryAverage = 58.0

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryLag ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryLag,
            establishedThreshold: establishedRecoveryLag
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> HeavyLoadRecoveryLagEvaluation? {
        let eligible = observations
            .filter(\.hasTrainingAndRecoverySignal)
            .sorted { $0.dayKey < $1.dayKey }

        guard eligible.count >= 10 else { return nil }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        guard overallAverage >= minimumOverallRecoveryAverage else { return nil }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var postHardRecoveries: [Int] = []
        var baselineRecoveries: [Int] = []
        var hardAnchorCount = 0

        for anchor in eligible {
            let lagRecoveries = lagRecoveries(after: anchor, indexed: indexed, calendar: calendar)
            guard !lagRecoveries.isEmpty else { continue }

            if anchor.isHardTrainingDay {
                hardAnchorCount += 1
                postHardRecoveries.append(contentsOf: lagRecoveries)
            } else {
                baselineRecoveries.append(contentsOf: lagRecoveries)
            }
        }

        guard hardAnchorCount >= 3,
              postHardRecoveries.count >= 4,
              baselineRecoveries.count >= 4 else {
            return nil
        }

        let baselineAverage = BeliefEvaluationSupport.average(baselineRecoveries)
        guard baselineAverage >= minimumBaselineRecoveryAverage else { return nil }

        let postHardAverage = BeliefEvaluationSupport.average(postHardRecoveries)

        return HeavyLoadRecoveryLagEvaluation(
            baselineRecoveryAverage: baselineAverage,
            postHardRecoveryAverage: postHardAverage,
            hardAnchorCount: hardAnchorCount,
            postHardLagSampleCount: postHardRecoveries.count,
            baselineLagSampleCount: baselineRecoveries.count,
            eligibleDayCount: eligible.count
        )
    }

    static func lagRecoveries(
        after anchor: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> [Int] {
        guard let anchorDate = CoachDailyObservation.date(fromDayKey: anchor.dayKey, calendar: calendar) else {
            return []
        }

        var recoveries: [Int] = []
        for offset in 1...2 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchorDate) else { continue }
            let dayKey = CoachDailyObservation.dayKey(for: date, calendar: calendar)
            guard let observation = indexed[dayKey], observation.hasRecoverySignal else { continue }
            recoveries.append(observation.recoveryPercent)
        }
        return recoveries
    }

    private static func evidence(from evaluation: HeavyLoadRecoveryLagEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleDayCount,
            primaryGroupSampleCount: evaluation.baselineLagSampleCount,
            comparisonGroupSampleCount: evaluation.postHardLagSampleCount,
            primaryGroupAverage: evaluation.baselineRecoveryAverage,
            comparisonGroupAverage: evaluation.postHardRecoveryAverage,
            notes: "lag recovery after non-hard days vs after hard training days"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let eligible = observations.filter(\.hasTrainingAndRecoverySignal)
        if eligible.count < 10 {
            return .insufficientObservations(required: 10, actual: eligible.count)
        }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        if overallAverage < minimumOverallRecoveryAverage {
            return .uniformLowBaseline
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryLag
            )
        }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current
        var postHardCount = 0
        var baselineCount = 0

        for anchor in eligible {
            let lagRecoveries = lagRecoveries(after: anchor, indexed: indexed, calendar: calendar)
            guard !lagRecoveries.isEmpty else { continue }
            if anchor.isHardTrainingDay {
                postHardCount += lagRecoveries.count
            } else {
                baselineCount += lagRecoveries.count
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: 4,
            primaryActual: baselineCount,
            comparisonRequired: 4,
            comparisonActual: postHardCount
        )
    }
}
