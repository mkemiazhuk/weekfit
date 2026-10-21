import CryptoKit
import Foundation
import OSLog

/// Sanitized evening-summary diagnostics. Never log tokens, HealthKit/fact payloads, or summary body.
enum CoachEveningSummaryDiagnostics {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "CoachEveningSummary")

    static var appVersionBuild: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version)/\(build)"
    }

    /// Stable anonymized owner tag (first 8 hex of SHA-256) — safe for Release correlation.
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

    static func flightDetail(
        owner: String,
        day: String,
        source: String,
        requestId: String? = nil,
        extra: String? = nil
    ) -> String {
        var parts = [
            "owner=\(ownerTag(owner))",
            "day=\(day)",
            "source=\(source)",
            "app=\(appVersionBuild)"
        ]
        if let requestId, !requestId.isEmpty {
            parts.append("requestId=\(requestId)")
        }
        if let extra, !extra.isEmpty {
            parts.append(extra)
        }
        return parts.joined(separator: " ")
    }
}
