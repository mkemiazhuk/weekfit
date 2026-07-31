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
            return "Your recovery is lower today, so I’d reduce the load and keep movement easy."
        case .maintain:
            return "You’re in a steady place today. A familiar, manageable day should keep momentum."
        case .train:
            return "You’re well recovered, and today fits one of your successful training patterns."
        case .protectTomorrow:
            return "Tomorrow carries the bigger load, so today should support it rather than compete with it."
        case .continueExistingPlan:
            return "Your plan already looks coherent for today."
        }
    }
}
