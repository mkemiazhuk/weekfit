import Foundation

/// Deterministic default-selection policy for Phase 1.5.
enum MorningProposalDefaultSelection {

    enum ConfidenceBucket: String, Sendable {
        case high
        case medium
        case low
    }

    static func confidenceBucket(
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        templateObservationAvailable: Bool?,
        walkRejectPenalty: Int
    ) -> ConfidenceBucket {
        if recoveryBand == .unavailable || sleepPresence != .present {
            return .low
        }
        if walkRejectPenalty >= 8 {
            return .medium
        }
        if templateObservationAvailable == false {
            return .medium
        }
        if recoveryBand == .good || recoveryBand == .moderate || recoveryBand == .low {
            return .high
        }
        return .medium
    }

    static func apply(
        to change: CoachProposedChange,
        input: MorningProposalEngineInput,
        mode: MorningProposalGenerationMode,
        confidence: ConfidenceBucket,
        stronglyRejectsWalk: Bool
    ) -> CoachProposedChange {
        var updated = change
        let selected = shouldSelect(
            change: change,
            input: input,
            mode: mode,
            confidence: confidence,
            stronglyRejectsWalk: stronglyRejectsWalk
        )
        updated.defaultSelected = selected
        updated.isSelected = selected
        return updated
    }

    static func shouldSelect(
        change: CoachProposedChange,
        input: MorningProposalEngineInput,
        mode: MorningProposalGenerationMode,
        confidence: ConfidenceBucket,
        stronglyRejectsWalk: Bool
    ) -> Bool {
        switch change.kind {
        case .guidanceOnly:
            return false

        case .modifyDuration, .moveActivity:
            return true

        case .skipActivity:
            return input.recoveryBand == .low
                && (input.yesterdayHeavy || input.stackedLoad.isElevated || input.tomorrowDemand == .hard)
                && confidence != .low

        case .createRecoveryWalk:
            guard !stronglyRejectsWalk else { return false }
            guard confidence == .high else { return false }
            return input.recoveryBand == .low || input.recoveryBand == .moderate

        case .createPlannedActivity:
            // New / cloned activities are opt-in.
            return false

        case .createMealFromLibrary:
            return confidence == .high && mode != .protect
        }
    }
}
