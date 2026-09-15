import Foundation

/// User preference for Firebase **product Analytics** collection.
///
/// - Default / missing choice → **ON** (Share Usage Data).
/// - Users can still turn it off in Settings.
/// - Crashlytics is independent (see `FirebaseEnvironment`).
/// - Preference is local-only; never sent as an analytics parameter.
enum ProductAnalyticsConsent {
    static let storageKey = "weekfit.analytics.productSharing.enabled"
    static let defaultOnMigrationKey = "weekfit.analytics.productSharing.migratedDefaultOn.v1"

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    /// Missing key (fresh install / never chosen) → `true`.
    /// Explicit `false` still disables collection after the one-time default-on migration.
    static func isSharingEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard defaults.object(forKey: storageKey) != nil else { return true }
        return defaults.bool(forKey: storageKey)
    }

    /// One-time flip to ON for installs that still have the old opt-in default (or no choice).
    /// After this runs, the user can turn the toggle off again.
    static func migrateToDefaultOnIfNeeded() {
        lock.lock()
        let alreadyMigrated = defaults.bool(forKey: defaultOnMigrationKey)
        if !alreadyMigrated {
            defaults.set(true, forKey: storageKey)
            defaults.set(true, forKey: defaultOnMigrationKey)
        }
        lock.unlock()
        if !alreadyMigrated {
            FirebaseEnvironment.applyAnalyticsCollectionPreference()
        }
    }

    /// Persist the default ON choice once so Settings shows the toggle enabled
    /// and Firebase collection matches. Does not override an explicit OFF.
    static func ensureDefaultEnabled() {
        lock.lock()
        let needsDefault = defaults.object(forKey: storageKey) == nil
        if needsDefault {
            defaults.set(true, forKey: storageKey)
        }
        lock.unlock()
        if needsDefault {
            FirebaseEnvironment.applyAnalyticsCollectionPreference()
        }
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
        defaults.removeObject(forKey: defaultOnMigrationKey)
        lock.unlock()
    }

    static func useStandardDefaultsForTests() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }
    #endif
}
