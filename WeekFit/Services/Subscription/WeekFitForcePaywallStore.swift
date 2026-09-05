internal import Combine
import Foundation

/// Temporary DEBUG-only override that allows presenting the real paywall
/// without changing entitlement / StoreKit state.
///
/// TestFlight and App Store are structurally excluded:
/// - only `AppDistribution.debug.allowsTemporaryForcePaywall == true`
/// - `isForcePaywallActive` requires that gate
/// - presentation hosts also re-check the gate
/// - persisted UserDefaults flags are ignored (and cleared) outside DEBUG
@MainActor
final class WeekFitForcePaywallStore: ObservableObject {
    static let shared = WeekFitForcePaywallStore()

    static let defaultsKey = "weekfit.diagnostics.forcePaywall"

    @Published private(set) var isEnabled: Bool
    /// Manual presentation of the production `WeekFitPaywallView` for diagnostics.
    @Published var isManualPaywallPresented = false

    private let defaults: UserDefaults
    private let distribution: AppDistribution

    private init(
        defaults: UserDefaults = .standard,
        distribution: AppDistribution = AppDistribution.current
    ) {
        self.defaults = defaults
        self.distribution = distribution
        if distribution.allowsTemporaryForcePaywall {
            self.isEnabled = defaults.bool(forKey: Self.defaultsKey)
        } else {
            // Fail closed: ignore and scrub any leftover diagnostic flag.
            self.isEnabled = false
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }

    var isAvailable: Bool {
        distribution.allowsTemporaryForcePaywall
    }

    /// Effective override — always false on App Store / unrecognized production.
    var isForcePaywallActive: Bool {
        isAvailable && isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else {
            isEnabled = false
            isManualPaywallPresented = false
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.defaultsKey)
        if !enabled {
            isManualPaywallPresented = false
        }
    }

    func requestOpenPaywall() {
        guard isForcePaywallActive else { return }
        isManualPaywallPresented = true
    }

    func dismissManualPaywall() {
        isManualPaywallPresented = false
    }

    /// Pure helper for unit tests — App Store never honors a stored flag.
    nonisolated static func resolvedIsEnabled(
        distribution: AppDistribution,
        storedValue: Bool
    ) -> Bool {
        distribution.allowsTemporaryForcePaywall && storedValue
    }

    /// Scrubs a persisted diagnostic flag when distribution is not DEBUG.
    nonisolated static func scrubStoredFlagIfNeeded(
        defaults: UserDefaults,
        distribution: AppDistribution,
        key: String = defaultsKey
    ) {
        guard distribution.allowsTemporaryForcePaywall == false else { return }
        defaults.removeObject(forKey: key)
    }
}
