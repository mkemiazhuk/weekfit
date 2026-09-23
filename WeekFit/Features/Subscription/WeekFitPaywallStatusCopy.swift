import Foundation

/// Which paywall action last wrote `SubscriptionManager.lastOutcome`.
enum WeekFitPaywallOutcomeSource: Equatable, Sendable {
    case purchase
    case restore
}

/// Maps shared `lastOutcome` + source into localized paywall footer copy.
/// Purchase and restore messages stay visually separate even though they share one outcome field.
enum WeekFitPaywallStatusCopy {
    static func purchaseMessage(
        outcome: WeekFitPurchaseOutcome?,
        source: WeekFitPaywallOutcomeSource?
    ) -> String? {
        guard source == .purchase else { return nil }
        switch outcome {
        case .pending:
            return WeekFitLocalizedString("paywall.error.pending")
        case .failedVerification:
            return WeekFitLocalizedString("paywall.error.verification")
        case .entitlementNotPropagated:
            return WeekFitLocalizedString("paywall.error.entitlementNotReady")
        case .failed, .productsUnavailable:
            return WeekFitLocalizedString("paywall.error.failed")
        case .cancelled, .success, .nothingToRestore, .none:
            return nil
        }
    }

    static func restoreMessage(
        outcome: WeekFitPurchaseOutcome?,
        source: WeekFitPaywallOutcomeSource?
    ) -> String? {
        guard source == .restore else { return nil }
        switch outcome {
        case .nothingToRestore:
            return WeekFitLocalizedString("paywall.restore.noneFound")
        case .failed, .productsUnavailable:
            return WeekFitLocalizedString("paywall.error.failed")
        case .cancelled, .success, .pending, .failedVerification,
             .entitlementNotPropagated, .none:
            // Cancel / success: no restore error copy.
            return nil
        }
    }
}
