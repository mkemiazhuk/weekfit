import Foundation
import OSLog

/// Debug / fallback sink used when Firebase is not configured.
/// Logs events via OSLog only — never sends remote telemetry.
final class LoggingAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    static let shared = LoggingAnalyticsService()

    private let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")
    /// Opt in when debugging without Firebase configured.
    private static let loggingEnabled = false

    func track(_ event: AnalyticsEvent, parameters: [String: String]) {
        log(kind: "event", name: event.rawValue, parameters: parameters)
    }

    func trackScreen(_ screen: AnalyticsScreen, parameters: [String: String]) {
        log(kind: "screen", name: screen.rawValue, parameters: parameters)
    }

    private func log(kind: String, name: String, parameters: [String: String]) {
        guard Self.loggingEnabled else { return }
        let props = Self.format(parameters)
        logger.debug("[\(kind, privacy: .public)] \(name, privacy: .public)\(props, privacy: .public)")
    }

    static func format(_ parameters: [String: String]) -> String {
        guard !parameters.isEmpty else { return "" }
        let body = parameters
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")
        return " \(body)"
    }
}
