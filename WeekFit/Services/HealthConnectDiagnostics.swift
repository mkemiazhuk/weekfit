import Foundation
import HealthKit
import os

enum HealthConnectDiagnostics {
    private static let logger = Logger(subsystem: "WeekFit", category: "HealthConnect")

    static func logButtonTapped(source: String) {
        log("Connect tapped source=\(source)")
    }

    static func logAuthorizationAttempt(
        source: String,
        accountMode: AccountMode,
        healthDataAvailable: Bool,
        readTypeCount: Int,
        readTypeSummary: String,
        accessRequestedFlag: Bool,
        accessGrantedFlag: Bool,
        hasCompletedAccessCheck: Bool
    ) {
        log(
            """
            authorization attempt source=\(source) \
            accountMode=\(String(describing: accountMode)) \
            healthAvailable=\(healthDataAvailable) \
            readTypes=\(readTypeCount) [\(readTypeSummary)] \
            accessRequested=\(accessRequestedFlag) \
            accessGranted=\(accessGrantedFlag) \
            hasCompletedAccessCheck=\(hasCompletedAccessCheck)
            """
        )
    }

    static func logBlocked(source: String, reason: String) {
        log("authorization blocked source=\(source) reason=\(reason)")
    }

    static func logAuthorizationStarted(source: String) {
        log("authorization started source=\(source)")
    }

    static func logAuthorizationReturned(
        source: String,
        errorDescription: String?,
        accessGrantedAfterProbe: Bool
    ) {
        log(
            """
            authorization returned source=\(source) \
            error=\(errorDescription ?? "none") \
            accessGrantedAfterProbe=\(accessGrantedAfterProbe)
            """
        )
    }

    static func logInitialSync(source: String, started: Bool, reason: String) {
        log("initial sync source=\(source) started=\(started) reason=\(reason)")
    }

    static func summarizeReadTypes(_ types: Set<HKObjectType>) -> String {
        types.map(\.identifier).sorted().joined(separator: ", ")
    }

    private static func log(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }
}
