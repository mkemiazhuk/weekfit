import Foundation

enum ConsecutiveHardDaysFatigueBeliefEvaluator: CoachBeliefEvaluator {

    static let beliefID: CoachBeliefID = .consecutiveHardDaysFatigue

    private static let emergedRecoveryFatigue = 8.0
    private static let establishedRecoveryFatigue = 6.0
    private static let minimumOverallRecoveryAverage = 58.0
    private static let minimumIsolatedRecoveryAverage = 58.0

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult {
        let evaluation = analyze(observations: observations)
        return BeliefEvaluationSupport.makeResult(
            beliefID: beliefID,
            currentMaturity: currentMaturity,
            effectSize: evaluation?.recoveryFatigue ?? 0,
            evidence: evaluation.map(evidence(from:)),
            hasMinimumSamples: evaluation?.hasMinimumSamples ?? false,
            hasEstablishedSamples: evaluation?.hasEstablishedSamples ?? false,
            emergedThreshold: emergedRecoveryFatigue,
            establishedThreshold: establishedRecoveryFatigue
        )
    }

    static func analyze(observations: [CoachDailyObservation]) -> ConsecutiveHardDaysFatigueEvaluation? {
        let eligible = observations
            .filter(\.hasTrainingAndRecoverySignal)
            .sorted { $0.dayKey < $1.dayKey }

        guard eligible.count >= 14 else { return nil }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        guard overallAverage >= minimumOverallRecoveryAverage else { return nil }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var consecutiveRecoveries: [Int] = []
        for run in consecutiveRuns(in: eligible, calendar: calendar) {
            guard let lastDay = run.last,
                  let recovery = recovery(onDayAfter: lastDay, indexed: indexed, calendar: calendar) else {
                continue
            }
            consecutiveRecoveries.append(recovery)
        }

        var isolatedRecoveries: [Int] = []
        for day in eligible where isIsolatedModerateOrHardDay(day, indexed: indexed, calendar: calendar) {
            guard let recovery = recovery(onDayAfter: day, indexed: indexed, calendar: calendar) else {
                continue
            }
            isolatedRecoveries.append(recovery)
        }

        guard consecutiveRecoveries.count >= 3, isolatedRecoveries.count >= 4 else {
            return nil
        }

        let isolatedAverage = BeliefEvaluationSupport.average(isolatedRecoveries)
        guard isolatedAverage >= minimumIsolatedRecoveryAverage else { return nil }

        let consecutiveAverage = BeliefEvaluationSupport.average(consecutiveRecoveries)

        return ConsecutiveHardDaysFatigueEvaluation(
            isolatedRecoveryAverage: isolatedAverage,
            consecutiveRecoveryAverage: consecutiveAverage,
            consecutiveSequenceCount: consecutiveRecoveries.count,
            isolatedSampleCount: isolatedRecoveries.count,
            eligibleDayCount: eligible.count
        )
    }

    static func consecutiveRuns(
        in eligible: [CoachDailyObservation],
        calendar: Calendar
    ) -> [[CoachDailyObservation]] {
        var runs: [[CoachDailyObservation]] = []
        var currentRun: [CoachDailyObservation] = []

        for observation in eligible where observation.isModerateOrHardTrainingDay {
            if extendsRun(currentRun.last, with: observation, calendar: calendar) {
                currentRun.append(observation)
            } else {
                if currentRun.count >= 2 {
                    runs.append(currentRun)
                }
                currentRun = [observation]
            }
        }

        if currentRun.count >= 2 {
            runs.append(currentRun)
        }

        return runs
    }

    static func isIsolatedModerateOrHardDay(
        _ day: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> Bool {
        guard day.isModerateOrHardTrainingDay,
              let date = CoachDailyObservation.date(fromDayKey: day.dayKey, calendar: calendar) else {
            return false
        }

        if let previousDate = calendar.date(byAdding: .day, value: -1, to: date),
           let previousDay = indexed[CoachDailyObservation.dayKey(for: previousDate, calendar: calendar)],
           previousDay.isModerateOrHardTrainingDay {
            return false
        }

        if let nextDate = calendar.date(byAdding: .day, value: 1, to: date),
           let nextDay = indexed[CoachDailyObservation.dayKey(for: nextDate, calendar: calendar)],
           nextDay.isModerateOrHardTrainingDay {
            return false
        }

        return true
    }

    static func recovery(
        onDayAfter day: CoachDailyObservation,
        indexed: [String: CoachDailyObservation],
        calendar: Calendar
    ) -> Int? {
        guard let date = CoachDailyObservation.date(fromDayKey: day.dayKey, calendar: calendar),
              let followingDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }

        let followingKey = CoachDailyObservation.dayKey(for: followingDate, calendar: calendar)
        guard let followingDay = indexed[followingKey], followingDay.hasRecoverySignal else {
            return nil
        }

        return followingDay.recoveryPercent
    }

    private static func extendsRun(
        _ previous: CoachDailyObservation?,
        with current: CoachDailyObservation,
        calendar: Calendar
    ) -> Bool {
        guard let previous,
              let previousDate = CoachDailyObservation.date(fromDayKey: previous.dayKey, calendar: calendar),
              let currentDate = CoachDailyObservation.date(fromDayKey: current.dayKey, calendar: calendar),
              let expectedDate = calendar.date(byAdding: .day, value: 1, to: previousDate) else {
            return false
        }

        return calendar.isDate(currentDate, inSameDayAs: expectedDate)
    }

    private static func evidence(from evaluation: ConsecutiveHardDaysFatigueEvaluation) -> BeliefEvidence {
        BeliefEvidence(
            eligibleDayCount: evaluation.eligibleDayCount,
            primaryGroupSampleCount: evaluation.isolatedSampleCount,
            comparisonGroupSampleCount: evaluation.consecutiveSequenceCount,
            primaryGroupAverage: evaluation.isolatedRecoveryAverage,
            comparisonGroupAverage: evaluation.consecutiveRecoveryAverage,
            notes: "recovery after isolated load vs recovery after consecutive load"
        )
    }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason? {
        let eligible = observations.filter(\.hasTrainingAndRecoverySignal)
        if eligible.count < 14 {
            return .insufficientObservations(required: 14, actual: eligible.count)
        }

        let overallAverage = BeliefEvaluationSupport.average(eligible.map(\.recoveryPercent))
        if overallAverage < minimumOverallRecoveryAverage {
            return .uniformLowBaseline
        }

        if analyze(observations: observations) != nil {
            return BeliefBlockingReasonSupport.noEventFromEvaluation(
                currentMaturity: currentMaturity,
                evaluation: evaluation,
                emergedThreshold: emergedRecoveryFatigue
            )
        }

        let indexed = Dictionary(uniqueKeysWithValues: eligible.map { ($0.dayKey, $0) })
        let calendar = Calendar.current

        var consecutiveCount = 0
        for run in consecutiveRuns(in: eligible, calendar: calendar) {
            guard let lastDay = run.last,
                  recovery(onDayAfter: lastDay, indexed: indexed, calendar: calendar) != nil else {
                continue
            }
            consecutiveCount += 1
        }

        var isolatedCount = 0
        for day in eligible where isIsolatedModerateOrHardDay(day, indexed: indexed, calendar: calendar) {
            if recovery(onDayAfter: day, indexed: indexed, calendar: calendar) != nil {
                isolatedCount += 1
            }
        }

        return .insufficientGroupSamples(
            primaryRequired: 4,
            primaryActual: isolatedCount,
            comparisonRequired: 3,
            comparisonActual: consecutiveCount
        )
    }
}
