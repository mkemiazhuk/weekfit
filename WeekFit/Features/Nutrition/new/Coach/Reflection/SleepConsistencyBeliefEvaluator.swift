import Foundation

enum SleepConsistencyBeliefEvaluator {

    private static let emergedRecoveryDelta = 8.0
    private static let establishedRecoveryDelta = 6.0

    static func evaluate(observations: [CoachDailyObservation]) -> (maturity: CoachBeliefMaturity, event: UnderstandingEvent?) {
        let currentBelief = CoachUnderstandingStore.belief(for: .sleepConsistencyRecovery)
        let evaluation = analyze(observations: observations)
        let nextMaturity = resolveMaturity(
            current: currentBelief.maturity,
            evaluation: evaluation
        )

        let event = makeEvent(
            previousMaturity: currentBelief.maturity,
            nextMaturity: nextMaturity
        )

        return (nextMaturity, event)
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
            consistentRecoveryAverage: average(consistent.map(\.recovery)),
            inconsistentRecoveryAverage: average(inconsistent.map(\.recovery)),
            consistentSampleCount: consistent.count,
            inconsistentSampleCount: inconsistent.count
        )
    }

    private static func resolveMaturity(
        current: CoachBeliefMaturity,
        evaluation: SleepConsistencyEvaluation?
    ) -> CoachBeliefMaturity {
        guard let evaluation, evaluation.hasMinimumSamples else {
            return .watching
        }

        if evaluation.hasEstablishedSamples,
           evaluation.recoveryDelta >= establishedRecoveryDelta {
            return .established
        }

        if evaluation.recoveryDelta >= emergedRecoveryDelta {
            return current == .established ? .established : .emerging
        }

        return .watching
    }

    private static func makeEvent(
        previousMaturity: CoachBeliefMaturity,
        nextMaturity: CoachBeliefMaturity
    ) -> UnderstandingEvent? {
        guard nextMaturity > previousMaturity else { return nil }

        switch (previousMaturity, nextMaturity) {
        case (.watching, .emerging), (.watching, .established):
            return UnderstandingEvent.make(
                beliefID: .sleepConsistencyRecovery,
                change: .emerged,
                maturity: nextMaturity
            )
        case (.emerging, .established):
            return UnderstandingEvent.make(
                beliefID: .sleepConsistencyRecovery,
                change: .strengthened,
                maturity: nextMaturity
            )
        default:
            return nil
        }
    }

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}
