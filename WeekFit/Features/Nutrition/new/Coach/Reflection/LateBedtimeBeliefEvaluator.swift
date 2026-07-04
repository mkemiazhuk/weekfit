import Foundation

enum LateBedtimeBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .lateBedtimeRecovery

    private static let emergedRecoveryDrop = 8.0
    private static let establishedRecoveryDrop = 6.0
    private static let minimumEligibleDays = 8
    private static let minimumNormalSampleCount = 4
    private static let minimumLateSampleCount = 2
    private static let minimumLateMinutesAfterAverage = 45

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

    static func analyze(observations: [CoachDailyObservation]) -> LateBedtimeEvaluation? {
        let eligible = observations
            .filter(\.hasSleepSignal)
            .filter(\.hasRecoverySignal)
            .compactMap { observation -> (bedtime: Int, recovery: Int)? in
                guard let bedStartMinutes = observation.bedStartNormalizedMinutes else { return nil }
                return (bedStartMinutes, observation.recoveryPercent)
            }

        guard eligible.count >= minimumEligibleDays else { return nil }

        let bedtimes = eligible.map(\.bedtime)
        let meanBedtime = RecoveryScoreEngine.circularAverageBedtimeMinutes(bedtimes)

        let late = eligible.filter {
            minutesAfterAverage(bedtime: $0.bedtime, average: meanBedtime) >= minimumLateMinutesAfterAverage
        }
        let normal = eligible.filter {
            minutesAfterAverage(bedtime: $0.bedtime, average: meanBedtime) < minimumLateMinutesAfterAverage
        }

        guard normal.count >= minimumNormalSampleCount,
              late.count >= minimumLateSampleCount else {
            return nil
        }

        return LateBedtimeEvaluation(
            normalRecoveryAverage: BeliefEvaluationSupport.average(normal.map(\.recovery)),
            lateRecoveryAverage: BeliefEvaluationSupport.average(late.map(\.recovery)),
            normalSampleCount: normal.count,
            lateSampleCount: late.count
        )
    }

    static func minutesAfterAverage(bedtime: Int, average: Int) -> Int {
        let forward = (bedtime - average + (24 * 60)) % (24 * 60)
        let backward = (average - bedtime + (24 * 60)) % (24 * 60)
        return forward <= backward ? forward : 0
    }

    private static func evidence(from evaluation: LateBedtimeEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.normalSampleCount + evaluation.lateSampleCount,
            primaryGroupSampleCount: evaluation.normalSampleCount,
            comparisonGroupSampleCount: evaluation.lateSampleCount,
            primaryGroupAverage: evaluation.normalRecoveryAverage,
            comparisonGroupAverage: evaluation.lateRecoveryAverage,
            notes: "normal bedtime vs late bedtime"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let sleepRecovery = observations.filter(\.hasSleepSignal).filter(\.hasRecoverySignal)
        let missingBedtime = sleepRecovery.filter { $0.bedStartNormalizedMinutes == nil }.count
        if missingBedtime > 0 {
            return .missingRequiredFields(["bedtime"])
        }

        if sleepRecovery.count < minimumEligibleDays {
            return .insufficientObservations(required: minimumEligibleDays, actual: sleepRecovery.count)
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryDrop
            )
        }

        let eligible = sleepRecovery.compactMap { observation -> Int? in
            observation.bedStartNormalizedMinutes
        }
        let meanBedtime = RecoveryScoreEngine.circularAverageBedtimeMinutes(eligible)
        var normalCount = 0
        var lateCount = 0
        for bedtime in eligible {
            if minutesAfterAverage(bedtime: bedtime, average: meanBedtime) >= minimumLateMinutesAfterAverage {
                lateCount += 1
            } else {
                normalCount += 1
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: minimumNormalSampleCount,
            primaryActual: normalCount,
            comparisonRequired: minimumLateSampleCount,
            comparisonActual: lateCount
        )
    }
}
