import Foundation

/// Pure freemium tab gate. UI must not change `selectedTab` until `.allow`.
enum WeekFitPremiumTabGate {
    enum Decision: Equatable, Sendable {
        /// Navigate to the tab now.
        case allow
        /// Entitlement still loading — keep Today, remember pending tab, no paywall yet.
        case deferUntilResolved
        /// Resolved without Premium — keep Today, show dismissible paywall.
        case presentPaywall
    }

    static func decision(
        for tab: WeekFitTab,
        hasResolved: Bool,
        hasFullAccess: Bool
    ) -> Decision {
        guard tab.requiresPremium else { return .allow }
        if !hasResolved { return .deferUntilResolved }
        return hasFullAccess ? .allow : .presentPaywall
    }

    /// After entitlement changes: open pending tab, present paywall, or snap back to Today.
    static func reconcile(
        selectedTab: WeekFitTab,
        pendingTab: WeekFitTab?,
        hasResolved: Bool,
        hasFullAccess: Bool,
        isPaywallPresented: Bool
    ) -> ReconcileResult {
        if hasResolved && !hasFullAccess && selectedTab.requiresPremium {
            return ReconcileResult(
                selectedTab: .today,
                pendingTab: nil,
                presentPaywall: false
            )
        }

        guard let pendingTab else {
            return ReconcileResult(
                selectedTab: selectedTab,
                pendingTab: nil,
                presentPaywall: isPaywallPresented && hasResolved && !hasFullAccess
            )
        }

        switch decision(for: pendingTab, hasResolved: hasResolved, hasFullAccess: hasFullAccess) {
        case .allow:
            return ReconcileResult(
                selectedTab: pendingTab,
                pendingTab: nil,
                presentPaywall: false
            )
        case .presentPaywall:
            return ReconcileResult(
                selectedTab: selectedTab.requiresPremium ? .today : selectedTab,
                pendingTab: pendingTab,
                presentPaywall: true
            )
        case .deferUntilResolved:
            return ReconcileResult(
                selectedTab: selectedTab.requiresPremium ? .today : selectedTab,
                pendingTab: pendingTab,
                presentPaywall: false
            )
        }
    }

    struct ReconcileResult: Equatable, Sendable {
        var selectedTab: WeekFitTab
        var pendingTab: WeekFitTab?
        var presentPaywall: Bool
    }
}

extension WeekFitTab {
    /// Stable analytics value for `requested_tab` (never localized).
    var paywallRequestedTabID: String? {
        switch self {
        case .today:
            return nil
        case .coach:
            return "coach"
        case .meals:
            return "meals"
        case .calendar:
            return "plan"
        }
    }
}
