import Foundation
import os

enum AccountSessionDiagnostics {
    private static let logger = Logger(subsystem: "WeekFit", category: "AccountSession")

    static func log(
        _ message: String,
        mode: AccountMode? = nil,
        store: String? = nil,
        demoProviderEnabled: Bool? = nil,
        accountKind: String? = nil
    ) {
        #if DEBUG
        var parts = [message]
        if let accountKind { parts.append("account=\(accountKind)") }
        if let mode { parts.append("mode=\(mode)") }
        if let store { parts.append("store=\(store)") }
        if let demoProviderEnabled { parts.append("demoProvider=\(demoProviderEnabled)") }
        logger.debug("\(parts.joined(separator: " "), privacy: .public)")
        #endif
    }
}
