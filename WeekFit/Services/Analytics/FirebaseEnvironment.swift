import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Central Firebase Analytics + Crashlytics collection policy.
/// Call once immediately after `FirebaseApp.configure()` — nowhere else for initial setup.
///
/// Distribution + consent policy:
/// - DEBUG / Xcode → Analytics OFF, Crashlytics OFF. No Share Usage Data toggle.
///   Launch args cannot re-enable collection (local deploys must not mix with
///   production Firebase).
/// - TestFlight / sandbox receipt → Analytics OFF (tester + Sandbox traffic
///   must not mix with production); Crashlytics ON; no Share Usage Data toggle
/// - App Store → Analytics ON when `ProductAnalyticsConsent` allows it
///   (default ON; user can disable in Settings); Crashlytics ON (crash diagnostics;
///   no health payloads — see `StartupDiagnostics`)
/// - Missing / never-set consent → Analytics ON on App Store only
///
/// `distribution` is a user property and a default event parameter (`debug`, `testflight`,
/// `appstore`). Default parameters are attached when an event is logged, including automatic
/// events logged after this call. DEBUG disables collection *before* `FirebaseApp.configure()`
/// so Xcode runs cannot emit `first_open`. On App Store, `first_open` can still be created
/// inside configure before this call; an event-parameter filter can drop a stray one.
/// Audience cuts should use the user property. `store_environment` is not a revenue-event
/// parameter.
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
            #if DEBUG
            logger.debug("Firebase telemetry: debug — analytics OFF, crashlytics OFF")
            #endif

        case .testFlight:
            Analytics.setAnalyticsCollectionEnabled(false)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            Crashlytics.crashlytics().setCustomValue(
                distribution.analyticsValue,
                forKey: AnalyticsParameterKey.distribution
            )
            #if DEBUG
            logger.debug("Firebase telemetry: testflight — analytics OFF, crashlytics ON")
            #endif

        case .appStore:
            applyCollection(
                analyticsOn: ProductAnalyticsConsent.isSharingEnabled(),
                crashlyticsOn: true,
                distribution: distribution
            )
            #if DEBUG
            logger.debug(
                "Firebase telemetry: appstore — analytics collection applied (consent), crashlytics ON"
            )
            #endif
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
        case .testFlight:
            Analytics.setAnalyticsCollectionEnabled(false)
        case .appStore:
            let analyticsOn = ProductAnalyticsConsent.isSharingEnabled()
            Analytics.setAnalyticsCollectionEnabled(analyticsOn)
            #if DEBUG
            logger.debug(
                "Firebase analytics collection \(analyticsOn ? "enabled" : "disabled", privacy: .public) via consent"
            )
            #endif
        }
    }

    private static func applyCollection(
        analyticsOn: Bool,
        crashlyticsOn: Bool,
        distribution: AppDistribution
    ) {
        Analytics.setAnalyticsCollectionEnabled(analyticsOn)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(crashlyticsOn)
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
    }

    /// Test seam.
    static func resetForTests() {
        lock.lock()
        didConfigure = false
        lock.unlock()
    }
}
