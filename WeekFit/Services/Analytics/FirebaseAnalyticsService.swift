import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import OSLog

/// Firebase-backed analytics + Crashlytics breadcrumbs.
/// Feature modules must not import Firebase — use `AppAnalytics` / `AnalyticsTracking`.
final class FirebaseAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")
    private let debugLoggingEnabled: Bool

    init(debugLoggingEnabled: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()) {
        self.debugLoggingEnabled = debugLoggingEnabled
    }

    func track(_ event: AnalyticsEvent, parameters: [String: String]) {
        if debugLoggingEnabled {
            let props = LoggingAnalyticsService.format(parameters)
            logger.debug("[event] \(event.rawValue, privacy: .public)\(props, privacy: .public)")
        }

        let firebaseParameters = Self.firebaseParameters(from: parameters)
        Analytics.logEvent(event.rawValue, parameters: firebaseParameters.isEmpty ? nil : firebaseParameters)
        Crashlytics.crashlytics().log("event:\(event.rawValue)")
    }

    func trackScreen(_ screen: AnalyticsScreen, parameters: [String: String]) {
        if debugLoggingEnabled {
            let props = LoggingAnalyticsService.format(parameters)
            logger.debug("[screen] \(screen.rawValue, privacy: .public)\(props, privacy: .public)")
        }

        var firebaseParameters = Self.firebaseParameters(from: parameters)
        firebaseParameters[AnalyticsParameterScreenName] = screen.rawValue
        firebaseParameters[AnalyticsParameterScreenClass] = screen.rawValue
        Analytics.logEvent(AnalyticsEventScreenView, parameters: firebaseParameters)
        Crashlytics.crashlytics().log("screen:\(screen.rawValue)")
    }

    private static func firebaseParameters(from parameters: [String: String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: parameters.map { ($0.key, $0.value as Any) })
    }
}
