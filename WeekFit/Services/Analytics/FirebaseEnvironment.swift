import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Central Firebase Analytics + Crashlytics collection policy.
/// Call once immediately after `FirebaseApp.configure()` — nowhere else for initial setup.
///
/// Distribution + consent policy:
/// - DEBUG / Xcode → Analytics OFF, Crashlytics OFF
/// - TestFlight / App Store → Analytics ON **only if** `ProductAnalyticsConsent` is enabled;
///   Crashlytics ON (crash diagnostics; no health payloads — see `StartupDiagnostics`)
/// - Missing / never-set consent → Analytics OFF (existing installs do not inherit prior auto-on)
///
/// Production product dashboards must filter `distribution = appstore` unless TestFlight
/// traffic is intentionally included.
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
            let analyticsOn = ProductAnalyticsConsent.isSharingEnabled()
            Analytics.setAnalyticsCollectionEnabled(analyticsOn)
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
                "Firebase telemetry: \(distribution.analyticsValue, privacy: .public) — analytics \(analyticsOn ? "ON" : "OFF", privacy: .public) (consent), crashlytics ON"
            )
        }

        // Privacy: never set Analytics or Crashlytics user identifiers.
        // Do not call Analytics.setUserID / Crashlytics.setUserID.
    }

    /// Re-applies Analytics collection from the current consent + distribution.
    /// Safe to call when the user toggles Settings → Share Product Analytics.
    static func applyAnalyticsCollectionPreference() {
        lock.lock()
        let configured = didConfigure
        lock.unlock()
        guard configured else { return }

        let distribution = AppDistribution.current
        switch distribution {
        case .debug:
            Analytics.setAnalyticsCollectionEnabled(false)
        case .testFlight, .appStore:
            let analyticsOn = ProductAnalyticsConsent.isSharingEnabled()
            Analytics.setAnalyticsCollectionEnabled(analyticsOn)
            logger.info(
                "Firebase analytics collection \(analyticsOn ? "enabled" : "disabled", privacy: .public) via consent"
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
