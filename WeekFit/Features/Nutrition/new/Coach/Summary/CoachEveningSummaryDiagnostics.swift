import CryptoKit
import Foundation
import OSLog

/// Sanitized evening-summary diagnostics. Never log tokens, fact text, or summary body.
enum CoachEveningSummaryDiagnostics {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "CoachEveningSummary")

    static func ownerTag(_ owner: String) -> String {
        let digest = SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
        return String(digest.prefix(8))
    }

    static func event(_ name: String, detail: String? = nil) {
        if let detail {
            logger.info("event=\(name, privacy: .public) \(detail, privacy: .public)")
        } else {
            logger.info("event=\(name, privacy: .public)")
        }
    }

    static func error(_ name: String, detail: String? = nil) {
        if let detail {
            logger.error("event=\(name, privacy: .public) \(detail, privacy: .public)")
        } else {
            logger.error("event=\(name, privacy: .public)")
        }
    }
}
