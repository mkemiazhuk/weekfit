import Foundation

/// Structured explanation for why a belief did not emit an upgrade event.
/// Used for developer inspection only; does not affect belief evaluation.
enum BeliefNoEventReason: Equatable, Sendable {
    case insufficientObservations(required: Int, actual: Int)
    case missingRequiredFields([String])
    case insufficientGroupSamples(
        primaryRequired: Int,
        primaryActual: Int,
        comparisonRequired: Int,
        comparisonActual: Int
    )
    case weakEffect(required: Double, actual: Double)
    case inverseOrConflictingEffect(expectedDirection: String, actualEffect: Double)
    case uniformLowBaseline
    case alreadyEstablished
    case alreadySpoken
    case noUpgradeFromCurrentMaturity(current: CoachBeliefMaturity, effectSize: Double, required: Double)
    case pendingUpgradeEvent

    var debugDescription: String {
        switch self {
        case let .insufficientObservations(required, actual):
            return "Need \(required)+ eligible observations; have \(actual)."
        case let .missingRequiredFields(fields):
            return "Missing required fields: \(fields.joined(separator: ", "))."
        case let .insufficientGroupSamples(primaryRequired, primaryActual, comparisonRequired, comparisonActual):
            return "Need more examples of both comparison groups (\(primaryActual)/\(primaryRequired) primary, \(comparisonActual)/\(comparisonRequired) comparison)."
        case .weakEffect:
            return "Enough data, but no stable pattern detected yet."
        case .inverseOrConflictingEffect:
            return "Current data points in the opposite direction."
        case .uniformLowBaseline:
            return "Overall recovery baseline is too uniformly low to detect a comparative pattern."
        case .alreadyEstablished:
            return "Belief is already established; no further upgrade event."
        case .alreadySpoken:
            return "Upgrade event already spoken."
        case let .noUpgradeFromCurrentMaturity(current, effectSize, required):
            return "Effect size \(Self.format(effectSize)) insufficient for upgrade from \(current.rawValue) (needs \(Self.format(required))+)."
        case .pendingUpgradeEvent:
            return "Pending upgrade event in queue."
        }
    }

    var inspectorCategory: String {
        switch self {
        case .insufficientObservations, .missingRequiredFields:
            return "missing data"
        case .insufficientGroupSamples:
            return "insufficient variation"
        case .weakEffect, .uniformLowBaseline:
            return "no stable signal yet"
        case .inverseOrConflictingEffect:
            return "conflicting signal"
        case .alreadyEstablished, .alreadySpoken, .noUpgradeFromCurrentMaturity, .pendingUpgradeEvent:
            return "event state"
        }
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

protocol CoachBeliefBlockingReasonProviding {
    static var beliefID: CoachBeliefID { get }

    static func blockingReason(
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult
    ) -> BeliefNoEventReason?
}

enum BeliefBlockingReasonSupport {

    static func weakOrInverseReason(
        effectSize: Double,
        emergedThreshold: Double,
        expectedDirection: String = "positive recovery delta"
    ) -> BeliefNoEventReason {
        if effectSize < 0 {
            return .inverseOrConflictingEffect(
                expectedDirection: expectedDirection,
                actualEffect: effectSize
            )
        }
        return .weakEffect(required: emergedThreshold, actual: effectSize)
    }

    static func noEventFromEvaluation(
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult,
        emergedThreshold: Double
    ) -> BeliefNoEventReason? {
        if currentMaturity == .established,
           evaluation.nextMaturity == .established,
           evaluation.event == nil {
            return .alreadyEstablished
        }

        if evaluation.evidence != nil {
            return weakOrInverseReason(
                effectSize: evaluation.effectSize,
                emergedThreshold: emergedThreshold
            )
        }

        return .noUpgradeFromCurrentMaturity(
            current: currentMaturity,
            effectSize: evaluation.effectSize,
            required: emergedThreshold
        )
    }
}

enum BeliefBlockingReasonRegistry {

    static func resolve(
        beliefID: CoachBeliefID,
        observations: [CoachDailyObservation],
        currentMaturity: CoachBeliefMaturity,
        evaluation: BeliefEvaluationResult,
        hasPendingEvent: Bool,
        hasSpokenEvent: Bool
    ) -> BeliefNoEventReason? {
        if hasPendingEvent {
            return .pendingUpgradeEvent
        }

        if hasSpokenEvent {
            return .alreadySpoken
        }

        if evaluation.event != nil {
            return nil
        }

        let providerReason: BeliefNoEventReason? = switch beliefID {
        case .sleepConsistencyRecovery:
            SleepConsistencyBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .sleepDurationRecovery:
            SleepDurationBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .lateBedtimeRecovery:
            LateBedtimeBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .heavyLoadRecoveryLag:
            HeavyLoadRecoveryLagBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .recoveryAfterRestDay:
            RecoveryAfterRestDayBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .consecutiveHardDaysFatigue:
            ConsecutiveHardDaysFatigueBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        case .underfuelingRecovery:
            UnderfuelingRecoveryBeliefEvaluator.blockingReason(
                observations: observations,
                currentMaturity: currentMaturity,
                evaluation: evaluation
            )
        }

        return providerReason
    }

    static func noEventReasonText(
        blockingReason: BeliefNoEventReason?,
        evaluation: BeliefEvaluationResult,
        hasPendingEvent: Bool,
        hasSpokenEvent: Bool
    ) -> String {
        if hasPendingEvent {
            return BeliefNoEventReason.pendingUpgradeEvent.debugDescription
        }

        if hasSpokenEvent {
            return BeliefNoEventReason.alreadySpoken.debugDescription
        }

        if let event = evaluation.event {
            return "Would emit \(event.change.rawValue) event (\(event.id)) on next evaluation apply."
        }

        if evaluation.nextMaturity.isDowngrade(from: evaluation.previousMaturity) {
            return "Downgraded \(evaluation.previousMaturity.rawValue) → \(evaluation.nextMaturity.rawValue)."
        }

        switch evaluation.nextMaturity {
        case .retired:
            return "Retired — effect size \(formatEffect(evaluation.effectSize)) below retirement threshold."
        case .weakening:
            return "Weakening — effect size \(formatEffect(evaluation.effectSize)) below established maintenance."
        default:
            break
        }

        return blockingReason?.debugDescription
            ?? "Effect size \(formatEffect(evaluation.effectSize)) insufficient for upgrade from \(evaluation.previousMaturity.rawValue)."
    }

    private static func formatEffect(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
