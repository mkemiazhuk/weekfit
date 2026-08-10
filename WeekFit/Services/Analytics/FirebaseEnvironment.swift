import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Central Firebase Analytics + Crashlytics collection policy.
/// Call once immediately after `FirebaseApp.configure()` — nowhere else.
enum FirebaseEnvironment {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")
    private static let lock = NSLock()
    private static var didConfigure = false

    /// Applies distribution-aware Analytics / Crashlytics collection policy exactly once.
    static func configureTelemetry() {
        lock.lock()
        defer { lock.unlock() }
        guard !didConfigure else { return }
        didConfigure = true

        let distribution = AppDistribution.current
        switch distribution {
        case .debug:
            Analytics.setAnalyticsCollectionEnabled(false)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            logger.info("Firebase telemetry: debug — analytics OFF, crashlytics OFF")

        case .testFlight, .appStore:
            Analytics.setAnalyticsCollectionEnabled(true)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            Analytics.setUserProperty(
                distribution.analyticsValue,
                forName: AnalyticsParameterKey.distribution
            )
            Analytics.setDefaultEventParameters([
                AnalyticsParameterKey.distribution: distribution.analyticsValue
            ])
            Crashlytics.crashlytics().setCustomValue(
                distribution.analyticsValue,
                forKey: AnalyticsParameterKey.distribution
            )
            logger.info(
                "Firebase telemetry: \(distribution.analyticsValue, privacy: .public) — analytics ON, crashlytics ON"
            )
        }
    }

    /// Test seam.
    static func resetForTests() {
        lock.lock()
        didConfigure = false
        lock.unlock()
    }
}
