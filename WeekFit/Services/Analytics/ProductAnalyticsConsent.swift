import Foundation

/// User preference for Firebase **product Analytics** collection.
///
/// - Default / missing choice → **OFF** (privacy-conservative).
/// - Crashlytics is independent (see `FirebaseEnvironment`).
/// - Preference is local-only; never sent as an analytics parameter.
enum ProductAnalyticsConsent {
    static let storageKey = "weekfit.analytics.productSharing.enabled"

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    /// `true` only when the user has explicitly enabled sharing.
    /// Missing key (fresh install / pre-consent migration) → `false`.
    static func isSharingEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard defaults.object(forKey: storageKey) != nil else { return false }
        return defaults.bool(forKey: storageKey)
    }

    /// Whether an explicit ON/OFF choice has been stored.
    static func hasExplicitChoice() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.object(forKey: storageKey) != nil
    }

    /// Persists the choice and applies Firebase Analytics collection immediately.
    static func setSharingEnabled(_ enabled: Bool) {
        lock.lock()
        defaults.set(enabled, forKey: storageKey)
        lock.unlock()
        FirebaseEnvironment.applyAnalyticsCollectionPreference()
    }

    /// Snapshot for local-data reset preservation.
    static func storedChoiceForPreservation() -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard defaults.object(forKey: storageKey) != nil else { return nil }
        return defaults.bool(forKey: storageKey)
    }

    static func restorePreservedChoice(_ value: Bool?) {
        guard let value else { return }
        lock.lock()
        defaults.set(value, forKey: storageKey)
        lock.unlock()
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func resetForTests() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    static func useStandardDefaultsForTests() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }
    #endif
}
