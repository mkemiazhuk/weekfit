import Foundation

/// App-facing analytics API. Feature code must depend on this protocol only —
/// never import Firebase Analytics / Crashlytics outside `Services/Analytics`.
///
/// Privacy: never pass HealthKit samples, biometric values, free-text personal
/// content, emails, names, or stable user identifiers as parameters.
protocol AnalyticsTracking: AnyObject, Sendable {
    func track(_ event: AnalyticsEvent, parameters: [String: String])
    func trackScreen(_ screen: AnalyticsScreen, parameters: [String: String])
}

extension AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        track(event, parameters: [:])
    }

    func trackScreen(_ screen: AnalyticsScreen) {
        trackScreen(screen, parameters: [:])
    }
}
