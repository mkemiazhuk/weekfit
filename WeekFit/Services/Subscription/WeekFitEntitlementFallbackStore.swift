import Foundation

/// Last StoreKit-verified entitlement on this install.
///
/// Used only when StoreKit cannot be verified. Never the source of truth
/// while AppTransaction or current entitlements are verified.
struct WeekFitEntitlementFallbackStore {
    static let key = "weekfit.subscription.lastVerifiedEntitlement"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastVerified: WeekFitVerifiedEntitlement? {
        get {
            guard let raw = defaults.string(forKey: Self.key) else { return nil }
            return WeekFitVerifiedEntitlement(rawValue: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
