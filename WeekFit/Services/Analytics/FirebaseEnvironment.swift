import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Central Firebase Analytics + Crashlytics collection policy.
/// Call once immediately after `FirebaseApp.configure()` — nowhere else for initial setup.
///
/// Distribution + consent policy:
/// - DEBUG / Xcode → Analytics OFF, Crashlytics OFF
///   (opt-in: launch arg `-weekfit-enable-debug-analytics` → Analytics ON with
///   `distribution=debug` for Sandbox QA / DebugView; still never `appstore`)
/// - TestFlight / App Store → Analytics ON when `ProductAnalyticsConsent` allows it
///   (default ON; user can disable in Settings); Crashlytics ON (crash diagnostics;
///   no health payloads — see `StartupDiagnostics`)
/// - Missing / never-set consent → Analytics ON
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
            #if DEBUG
            if WeekFitUITestSupport.shouldEnableDebugAnalytics {
                applyCollection(
                    analyticsOn: ProductAnalyticsConsent.isSharingEnabled(),
                    crashlyticsOn: true,
                    distribution: distribution
                )
                logger.debug("Firebase telemetry: debug — analytics ON (Sandbox QA launch arg), crashlytics ON")
            } else {
                Analytics.setAnalyticsCollectionEnabled(false)
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
                logger.debug("Firebase telemetry: debug — analytics OFF, crashlytics OFF")
            }
            #else
            Analytics.setAnalyticsCollectionEnabled(false)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            #endif

        case .testFlight, .appStore:
            applyCollection(
                analyticsOn: ProductAnalyticsConsent.isSharingEnabled(),
                crashlyticsOn: true,
                distribution: distribution
            )
            #if DEBUG
            logger.debug(
                "Firebase telemetry: \(distribution.analyticsValue, privacy: .public) — analytics collection applied (consent), crashlytics ON"
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
            #if DEBUG
            if WeekFitUITestSupport.shouldEnableDebugAnalytics {
                Analytics.setAnalyticsCollectionEnabled(ProductAnalyticsConsent.isSharingEnabled())
            } else {
                Analytics.setAnalyticsCollectionEnabled(false)
            }
            #else
            Analytics.setAnalyticsCollectionEnabled(false)
            #endif
        case .testFlight, .appStore:
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
