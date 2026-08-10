import Foundation
import OSLog

/// Temporary diagnostics for meal-library seeding (UserDefaults catalog, not SwiftData).
/// Filter Console: subsystem `com.weekfit.app` category `MealsSeed`.
/// DEBUG-only — Release builds are silent.
///
/// Intentionally does **not** mirror into `StartupDiagnostics` — dual-category mirrors made
/// every seed line appear twice when filtering by subsystem only.
enum MealsSeedDiagnostics {
    static let logger = Logger(subsystem: "com.weekfit.app", category: "MealsSeed")

    /// Set to `true` temporarily when diagnosing meal-library seed issues.
    private static let loggingEnabled = false

    static func begin(run: UUID, detail: String? = nil) {
        log("MEALS SEED BEGIN", run: run, detail: detail)
    }

    static func skipped(run: UUID, reason: String, detail: String? = nil) {
        let merged = detail.map { "reason=\(reason) | \($0)" } ?? "reason=\(reason)"
        log("MEALS SEED SKIPPED", run: run, detail: merged)
    }

    static func info(_ message: String, run: UUID) {
        log(message, run: run, detail: nil)
    }

    static func error(run: UUID, operation: String, error: Error) {
        let nsError = error as NSError
        log(
            "MEALS SEED ERROR",
            run: run,
            detail: "operation=\(operation) type=\(String(describing: type(of: error))) domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
        )
    }

    static func complete(run: UUID, detail: String) {
        log("MEALS SEED COMPLETE", run: run, detail: detail)
    }

    private static func log(_ headline: String, run: UUID, detail: String?) {
        guard loggingEnabled else { return }
        let runTag = "run=\(run.uuidString.prefix(8))"
        let message: String
        if let detail, !detail.isEmpty {
            message = "\(headline) | \(runTag) | \(detail)"
        } else {
            message = "\(headline) | \(runTag)"
        }
        logger.info("\(message, privacy: .public)")
    }
}
