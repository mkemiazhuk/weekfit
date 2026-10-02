import Foundation

/// Pure rules for root-level subscription UI presentation.
///
/// SwiftUI only supports one sheet/fullScreenCover presentation at a time.
/// Settings is presented as a sheet from tab content; root also owns the feature
/// paywall fullScreenCover and the legacy-thanks sheet. Requesting either while
/// Settings (or another root modal) is active queues a second presentation and
/// emits "Currently, only presenting a single sheet is supported" — repeatedly
/// on every view refresh while the conflicting binding stays true.
enum WeekFitSubscriptionPresentationCoordinator {
    /// Root may start a new subscription presentation only when no competing
    /// modal already owns the presentation slot.
    static func canPresentRootSubscriptionUI(
        isSettingsPresented: Bool,
        isOnboardingPresented: Bool,
        isHealthAccessPresented: Bool,
        isFeaturePaywallPresented: Bool,
        isLegacyThanksPresented: Bool
    ) -> Bool {
        !(isSettingsPresented
            || isOnboardingPresented
            || isHealthAccessPresented
            || isFeaturePaywallPresented
            || isLegacyThanksPresented)
    }

    enum LegacyThanksAction: Equatable, Sendable {
        /// Set the root legacy-thanks sheet binding to `true` now.
        case present
        /// Eligible, but another modal owns the slot — remember and flush later.
        case deferUntilClear
        /// Not eligible, or already presenting — do not touch the binding.
        case idle
    }

    /// Idempotent legacy-thanks decision. Never returns `.present` when the
    /// sheet is already requested — that re-request is what spams the warning.
    static func legacyThanksAction(
        isEligible: Bool,
        isAlreadyPresented: Bool,
        canPresent: Bool
    ) -> LegacyThanksAction {
        guard isEligible else { return .idle }
        if isAlreadyPresented { return .idle }
        return canPresent ? .present : .deferUntilClear
    }

    /// Feature paywall must not open while Settings occupies the sheet slot
    /// (bottom bar can still receive taps under a large detent sheet).
    static func shouldPresentFeaturePaywall(
        desired: Bool,
        isSettingsPresented: Bool,
        isLegacyThanksPresented: Bool
    ) -> Bool {
        desired && !isSettingsPresented && !isLegacyThanksPresented
    }

    enum FeaturePaywallOpenAction: Equatable, Sendable {
        /// Mint a new instance ID and set the fullScreenCover binding to `true`.
        case beginPresentation
        /// Cover is already up or mid-transition — update pending tab only.
        /// Reminting the instance ID mid-presentation freezes SwiftUI.
        case updatePendingOnly
        /// Settings / legacy-thanks owns the slot, or not desired.
        case suppress
    }

    /// Coalesce rapid premium-tab taps so we never re-request fullScreenCover
    /// while one is presenting or animating away.
    static func featurePaywallOpenAction(
        desired: Bool,
        isAlreadyPresented: Bool,
        isTransitioning: Bool,
        isSettingsPresented: Bool,
        isLegacyThanksPresented: Bool
    ) -> FeaturePaywallOpenAction {
        guard shouldPresentFeaturePaywall(
            desired: desired,
            isSettingsPresented: isSettingsPresented,
            isLegacyThanksPresented: isLegacyThanksPresented
        ) else {
            return .suppress
        }
        if isAlreadyPresented || isTransitioning {
            return .updatePendingOnly
        }
        return .beginPresentation
    }
}
