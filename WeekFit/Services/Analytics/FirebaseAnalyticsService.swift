import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Firebase-backed analytics + Crashlytics breadcrumbs.
/// Feature modules must not import Firebase — use `AppAnalytics` / `AnalyticsTracking`.
///
/// Collection enable/disable is **not** decided here — see `FirebaseEnvironment.configureTelemetry()`.
/// Parameters are sanitized via `AnalyticsPrivacyContract` before upload.
final class FirebaseAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")
    private let debugLoggingEnabled: Bool

    init(debugLoggingEnabled: Bool = false) {
        self.debugLoggingEnabled = debugLoggingEnabled
    }

    func track(_ event: AnalyticsEvent, parameters: [String: String]) {
        let sanitized = AnalyticsPrivacyContract.sanitize(parameters)
        #if DEBUG
        let stripped = AnalyticsPrivacyContract.violations(in: parameters)
        if !stripped.isEmpty {
            logger.error("Analytics privacy strip: \(stripped.joined(separator: ","), privacy: .public)")
        }
        #endif

        if debugLoggingEnabled {
            let props = LoggingAnalyticsService.format(sanitized)
            logger.debug("[event] \(event.rawValue, privacy: .public)\(props, privacy: .public)")
        }

        let firebaseParameters = Self.firebaseParameters(from: sanitized)
        Analytics.logEvent(event.rawValue, parameters: firebaseParameters.isEmpty ? nil : firebaseParameters)
        let breadcrumb = "event:\(event.rawValue)"
        DispatchQueue.global(qos: .utility).async {
            Crashlytics.crashlytics().log(breadcrumb)
        }
    }

    func trackScreen(_ screen: AnalyticsScreen, parameters: [String: String]) {
        let sanitized = AnalyticsPrivacyContract.sanitize(parameters)
        if debugLoggingEnabled {
            let props = LoggingAnalyticsService.format(sanitized)
            logger.debug("[screen] \(screen.rawValue, privacy: .public)\(props, privacy: .public)")
        }

        var firebaseParameters = Self.firebaseParameters(from: sanitized)
        firebaseParameters[AnalyticsParameterScreenName] = screen.rawValue
        firebaseParameters[AnalyticsParameterScreenClass] = screen.rawValue
        Analytics.logEvent(AnalyticsEventScreenView, parameters: firebaseParameters)
        let breadcrumb = "screen:\(screen.rawValue)"
        DispatchQueue.global(qos: .utility).async {
            Crashlytics.crashlytics().log(breadcrumb)
        }
    }

    private static func firebaseParameters(from parameters: [String: String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: parameters.map { ($0.key, $0.value as Any) })
    }
}
