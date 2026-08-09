import Foundation

/// Proposal-level strategy summary for Today / Review (no medical claims).
enum MorningProposalStrategyCopy {

    static func localizationKey(for strategy: DailyStrategy) -> String {
        switch strategy {
        case .recover:
            return "coach.proposal.strategy.recover"
        case .maintain:
            return "coach.proposal.strategy.maintain"
        case .train:
            return "coach.proposal.strategy.train"
        case .protectTomorrow:
            return "coach.proposal.strategy.protectTomorrow"
        case .continueExistingPlan:
            return "coach.proposal.strategy.continueExistingPlan"
        }
    }

    static func localizedSummary(for strategy: DailyStrategy?) -> String? {
        guard let strategy, strategy != .continueExistingPlan else { return nil }
        return WeekFitLocalizedString(localizationKey(for: strategy))
    }

    static func englishFallback(for strategy: DailyStrategy) -> String {
        switch strategy {
        case .recover:
            return "Today should be lighter."
        case .maintain:
            return "Today should stay steady."
        case .train:
            return "You’re ready for a proper session."
        case .protectTomorrow:
            return "Save energy for tomorrow’s load."
        case .continueExistingPlan:
            return "Your current plan already fits today."
        }
    }
}
