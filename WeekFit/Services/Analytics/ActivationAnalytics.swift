import Foundation

/// Once-per-install / once-per-day activation milestones.
/// Cleared with workspace UserDefaults wipe (local reset / account switch).
///
/// Privacy: milestones are product-interaction only — no recovery band, sleep presence,
/// or other HealthKit-derived state in Firebase parameters.
enum ActivationAnalytics {

    enum Keys {
        static let todayFirstView = "weekfit.analytics.activation.todayFirstView"
        static let recoveryAvailableDays = "weekfit.analytics.activation.recoveryAvailableDays"
    }

    static var allKnownKeys: [String] {
        [Keys.todayFirstView, Keys.recoveryAvailableDays]
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static var analyticsProvider: () -> AnalyticsTracking = { AppAnalytics.shared }
    private static let maxStoredDayKeys = 16

    /// First meaningful Today screen exposure for this workspace lifecycle.
    /// Scope: install/workspace UserDefaults (cleared on local data reset / account wipe).
    static func trackTodayFirstViewIfNeeded() {
        lock.lock()
        let already = defaults.bool(forKey: Keys.todayFirstView)
        if !already {
            defaults.set(true, forKey: Keys.todayFirstView)
        }
        lock.unlock()
        guard !already else { return }
        analyticsProvider().track(
            .todayFirstView,
            parameters: [AnalyticsParameterKey.source: AnalyticsSource.today.rawValue]
        )
    }

    /// First time today the recovery **product module** has usable inputs for Coach/Today.
    /// Once per local `dayKey`. Emits **no** health-state parameters.
    static func trackRecoveryAvailableIfNeeded(
        dayKey: String,
        recoveryDataAvailable: Bool,
        hasSettledMetrics: Bool,
        hasRecoverySignals: Bool
    ) {
        guard recoveryDataAvailable else { return }
        guard hasSettledMetrics || hasRecoverySignals else { return }

        lock.lock()
        var days = Set(defaults.stringArray(forKey: Keys.recoveryAvailableDays) ?? [])
        let inserted = days.insert(dayKey).inserted
        if inserted {
            let trimmed = Array(days).sorted().suffix(maxStoredDayKeys)
            defaults.set(Array(trimmed), forKey: Keys.recoveryAvailableDays)
        }
        lock.unlock()
        guard inserted else { return }

        analyticsProvider().track(
            .recoveryAvailable,
            parameters: [
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func setAnalyticsForTests(_ provider: @escaping () -> AnalyticsTracking) {
        lock.lock()
        analyticsProvider = provider
        lock.unlock()
    }

    static func resetAllForTests() {
        lock.lock()
        allKnownKeys.forEach { defaults.removeObject(forKey: $0) }
        defaults = .standard
        analyticsProvider = { AppAnalytics.shared }
        lock.unlock()
    }
    #endif
}
