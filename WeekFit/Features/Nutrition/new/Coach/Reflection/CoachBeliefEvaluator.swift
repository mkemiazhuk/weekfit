import Foundation

// MARK: - Evidence & result

struct BeliefEvidence: Equatable, Sendable {
    let eligibleDayCount: Int
    let primaryGroupSampleCount: Int
    let comparisonGroupSampleCount: Int
    let primaryGroupAverage: Double?
    let comparisonGroupAverage: Double?
    let notes: String?

    init(
        eligibleDayCount: Int,
        primaryGroupSampleCount: Int,
        comparisonGroupSampleCount: Int,
        primaryGroupAverage: Double? = nil,
        comparisonGroupAverage: Double? = nil,
        notes: String? = nil
    ) {
        self.eligibleDayCount = eligibleDayCount
        self.primaryGroupSampleCount = primaryGroupSampleCount
        self.comparisonGroupSampleCount = comparisonGroupSampleCount
        self.primaryGroupAverage = primaryGroupAverage
        self.comparisonGroupAverage = comparisonGroupAverage
        self.notes = notes
    }
}

struct BeliefEvaluationResult: Equatable, Sendable {
    let beliefID: CoachBeliefID
    let previousMaturity: CoachBeliefMaturity
    let nextMaturity: CoachBeliefMaturity
    let evidence: BeliefEvidence?
    let confidence: Double
    let effectSize: Double
    let event: UnderstandingEvent?

    var maturity: CoachBeliefMaturity { nextMaturity }
}

// MARK: - Evaluator protocol

protocol CoachBeliefEvaluator {
    static var beliefID: CoachBeliefID { get }

    static func evaluate(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity
    ) -> BeliefEvaluationResult
}

// MARK: - Shared maturity resolution

enum BeliefMaturityResolver {

    static func resolve(
        current: CoachBeliefMaturity,
        effectSize: Double,
        hasMinimumSamples: Bool,
        hasEstablishedSamples: Bool,
        emergedThreshold: Double,
        establishedThreshold: Double,
        weakeningThreshold: Double = 4.0,
        retirementThreshold: Double = 2.0
    ) -> CoachBeliefMaturity {
        guard hasMinimumSamples else {
            return resolveWhenInsufficientSamples(current: current)
        }

        if hasEstablishedSamples, effectSize >= establishedThreshold {
            return .established
        }

        if effectSize >= emergedThreshold {
            switch current {
            case .established:
                return .established
            case .retired:
                return .retired
            case .weakening:
                return .emerging
            case .watching, .emerging:
                return .emerging
            }
        }

        switch current {
        case .established:
            return effectSize < weakeningThreshold ? .weakening : .established
        case .weakening:
            return effectSize < retirementThreshold ? .retired : .weakening
        case .emerging:
            return .watching
        case .watching, .retired:
            return current
        }
    }

    private static func resolveWhenInsufficientSamples(current: CoachBeliefMaturity) -> CoachBeliefMaturity {
        switch current {
        case .established:
            return .weakening
        case .weakening:
            return .retired
        case .emerging:
            return .watching
        case .watching, .retired:
            return current
        }
    }
}

enum BeliefUpgradeEventFactory {

    static func makeEvent(
        beliefID: CoachBeliefID,
        previousMaturity: CoachBeliefMaturity,
        nextMaturity: CoachBeliefMaturity
    ) -> UnderstandingEvent? {
        guard nextMaturity.isUpgrade(from: previousMaturity) else { return nil }

        switch (previousMaturity, nextMaturity) {
        case (.watching, .emerging), (.watching, .established), (.weakening, .emerging):
            return UnderstandingEvent.make(
                beliefID: beliefID,
                change: .emerged,
                maturity: nextMaturity
            )
        case (.emerging, .established):
            return UnderstandingEvent.make(
                beliefID: beliefID,
                change: .strengthened,
                maturity: nextMaturity
            )
        default:
            return nil
        }
    }
}

enum BeliefEvaluationSupport {

    static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    static func confidence(
        effectSize: Double,
        emergedThreshold: Double,
        sampleCount: Int,
        minimumSampleCount: Int
    ) -> Double {
        guard emergedThreshold > 0, minimumSampleCount > 0 else { return 0 }
        let magnitude = min(max(effectSize / emergedThreshold, 0), 1.5)
        let sampleWeight = min(Double(sampleCount) / Double(minimumSampleCount), 1.5)
        return min(magnitude * sampleWeight / 1.5, 1.0)
    }

    static func makeResult(
        beliefID: CoachBeliefID,
        currentMaturity: CoachBeliefMaturity,
        effectSize: Double,
        evidence: BeliefEvidence?,
        hasMinimumSamples: Bool,
        hasEstablishedSamples: Bool,
        emergedThreshold: Double,
        establishedThreshold: Double
    ) -> BeliefEvaluationResult {
        let nextMaturity = BeliefMaturityResolver.resolve(
            current: currentMaturity,
            effectSize: effectSize,
            hasMinimumSamples: hasMinimumSamples,
            hasEstablishedSamples: hasEstablishedSamples,
            emergedThreshold: emergedThreshold,
            establishedThreshold: establishedThreshold
        )

        let sampleCount = (evidence?.primaryGroupSampleCount ?? 0)
            + (evidence?.comparisonGroupSampleCount ?? 0)

        return BeliefEvaluationResult(
            beliefID: beliefID,
            previousMaturity: currentMaturity,
            nextMaturity: nextMaturity,
            evidence: evidence,
            confidence: confidence(
                effectSize: effectSize,
                emergedThreshold: emergedThreshold,
                sampleCount: sampleCount,
                minimumSampleCount: 6
            ),
            effectSize: effectSize,
            event: BeliefUpgradeEventFactory.makeEvent(
                beliefID: beliefID,
                previousMaturity: currentMaturity,
                nextMaturity: nextMaturity
            )
        )
    }
}
