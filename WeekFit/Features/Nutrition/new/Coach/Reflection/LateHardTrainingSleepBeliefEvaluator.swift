import Foundation

enum LateHardTrainingSleepBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .lateHardTrainingSleep

    /// Effect measured in sleep minutes drop after late hard sessions.
    private static let emergedSleepDropMinutes = 35.0
    private static let establishedSleepDropMinutes = 25.0
    private static let minimumEligibleAnchors = 8
    private static let minimumGroupSampleCount = 3
    /// Sessions finishing at/after 20:00 local minutes-from-midnight.
    static let lateThresholdMinutes = 20 * 60
    /// Earlier comparison band finishes before 18:00.
    private static let earlierThresholdMinutes = 18 * 60

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.sleepDropMinutes ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedSleepDropMinutes,
            establishedThreshold: establishedSleepDropMinutes
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> LateHardTrainingSleepEvaluation? {
        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })

        var earlierSleep: [Int] = []
        var lateSleep: [Int] = []

        for anchor in observations where anchor.isHardTrainingDay {
            guard let endMinutes = anchor.hardestWorkoutEndMinutes,
                  let nextSleep = nextNightSleepMinutes(
                    after: anchor,
                    indexed: indexed,
                    calendar: calendar
                  ) else {
                continue
            }

            if endMinutes >= lateThresholdMinutes {
                lateSleep.append(nextSleep)
            } else if endMinutes < earlierThresholdMinutes {
                earlierSleep.append(nextSleep)
            }
        }

        let eligible = earlierSleep.count + lateSleep.count
        guard eligible >= minimumEligibleAnchors,
              earlierSleep.count >= minimumGroupSampleCount,
              lateSleep.count >= minimumGroupSampleCount else {
            return nil
        }

        return LateHardTrainingSleepEvaluation(
            earlierHardSleepAverageMinutes: BeliefEvaluationSupport.average(earlierSleep),
            lateHardSleepAverageMinutes: BeliefEvaluationSupport.average(lateSleep),
            earlierHardSampleCount: earlierSleep.count,
            lateHardSampleCount: lateSleep.count,
            eligibleAnchorCount: eligible,
            lateThresholdMinutes: lateThresholdMinutes
        )
    }

    static func nextNightSleepMinutes(
        after anchor: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> Int? {
        guard let anchorDate = CoachDailyObservation.date(fromDayKey: anchor.dayKey, calendar: calendar) else {
            return nil
        }
        // Sleep logged on the following calendar day represents the night after the hard session.
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) else {
            return nil
        }

        let dayKey = CoachDailyObservation.dayKey(for: nextDate, calendar: calendar)
        guard let observation = indexed[dayKey],
              observation.hasSleepSignal,
              observation.sleepMinutes > 0 else {
            return nil
        }
        return observation.sleepMinutes
    }

    private static func evidence(from evaluation: LateHardTrainingSleepEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleAnchorCount,
            primaryGroupSampleCount: evaluation.earlierHardSampleCount,
            comparisonGroupSampleCount: evaluation.lateHardSampleCount,
            primaryGroupAverage: evaluation.earlierHardSleepAverageMinutes,
            comparisonGroupAverage: evaluation.lateHardSleepAverageMinutes,
            notes: "next-night sleep after earlier hard sessions (<18:00) vs late hard sessions (>=20:00)"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let hardWithEnd = observations.filter {
            $0.isHardTrainingDay && $0.hardestWorkoutEndMinutes != nil
        }
        if hardWithEnd.isEmpty {
            return .missingRequiredFields(["hardestWorkoutEndMinutes"])
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedSleepDropMinutes
            )
        }

        let calendar = Calendar.current
        let indexed = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })
        var earlier = 0
        var late = 0
        for anchor in hardWithEnd {
            guard let end = anchor.hardestWorkoutEndMinutes,
                  nextNightSleepMinutes(after: anchor, indexed: indexed, calendar: calendar) != nil else {
                continue
            }
            if end >= lateThresholdMinutes {
                late += 1
            } else if end < earlierThresholdMinutes {
                earlier += 1
            }
        }

        let eligible = earlier + late
        if eligible < minimumEligibleAnchors {
            return .insufficientObservations(required: minimumEligibleAnchors, actual: eligible)
        }

        return .insufficientGroupSamples(
            primaryRequired: minimumGroupSampleCount,
            primaryActual: earlier,
            comparisonRequired: minimumGroupSampleCount,
            comparisonActual: late
        )
    }
}
