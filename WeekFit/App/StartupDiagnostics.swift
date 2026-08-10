import Foundation
import OSLog
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Temporary high-signal cold-start breadcrumbs.
/// Filter Console / device logs by subsystem `com.weekfit.app` and category `Startup`.
///
/// Off by default (DEBUG and Release). Flip `loggingEnabled` when diagnosing launch hangs.
/// Release still records warning/error to os.Logger + Crashlytics when enabled paths fire failures
/// via `failed` / task ERROR — those go through `record` which keeps errors unless fully muted.
enum StartupDiagnostics {
    static let logger = Logger(subsystem: "com.weekfit.app", category: "Startup")

    /// Set to `true` temporarily when investigating cold-start stalls.
    static let loggingEnabled = false

    /// Stable per-process cold-launch id for comparing success vs hang traces.
    static let launchID = UUID()
    static var launchIDShort: String { String(launchID.uuidString.prefix(8)) }

    private static let lock = NSLock()
    private static var lastStep: String = "none"
    private static var startedAt = CFAbsoluteTimeGetCurrent()
    private static var didMarkFirstScreenStable = false
    private static var crashlyticsBreadcrumbsEnabled = true

    static var lastCompletedStep: String {
        lock.lock()
        defer { lock.unlock() }
        return lastStep
    }

    /// `STARTUP NN — label` plus optional detail.
    static func step(_ number: Int, _ label: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        let padded = String(format: "%02d", number)
        var parts = ["STARTUP \(padded) — \(label)", "launch=\(launchIDShort)"]
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        record(parts.joined(separator: " | "), level: .info)
    }

    static func failed(
        operation: String,
        error: Error,
        step: Int? = nil,
        extras: [String: String] = [:]
    ) {
        let nsError = error as NSError
        var parts: [String] = [
            "operation=\(operation)",
            "errorType=\(String(describing: type(of: error)))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "localizedDescription=\(nsError.localizedDescription)"
        ]

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append(
                "underlying=\(underlying.domain)/\(underlying.code): \(underlying.localizedDescription)"
            )
        }

        for (key, value) in extras.sorted(by: { $0.key < $1.key }) {
            parts.append("\(key)=\(value)")
        }

        let prefix: String
        if let step {
            prefix = "STARTUP \(String(format: "%02d", step)) FAIL —"
        } else {
            prefix = "STARTUP FAIL —"
        }

        record("\(prefix) \(parts.joined(separator: " | "))", level: .error)
    }

    // MARK: - Async task lifecycle

    static func taskBegin(_ name: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        taskPhase("BEGIN", name: name, detail: detail)
    }

    static func taskSuccess(_ name: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        taskPhase("SUCCESS", name: name, detail: detail)
    }

    static func taskError(_ name: String, error: Error, detail: String? = nil) {
        // Always keep task failures visible — useful in Release Crashlytics too.
        let nsError = error as NSError
        var parts = [
            "errorType=\(String(describing: type(of: error)))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "localizedDescription=\(nsError.localizedDescription)"
        ]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append(
                "underlying=\(underlying.domain)/\(underlying.code): \(underlying.localizedDescription)"
            )
        }
        if let detail, !detail.isEmpty {
            parts.insert(detail, at: 0)
        }
        taskPhase("ERROR", name: name, detail: parts.joined(separator: " | "))
    }

    static func taskCancelled(_ name: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        taskPhase("CANCELLED", name: name, detail: detail)
    }

    private static func taskPhase(_ phase: String, name: String, detail: String?) {
        var parts = ["STARTUP TASK \(phase) — \(name)", "launch=\(launchIDShort)"]
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        let message = parts.joined(separator: " | ")

        switch phase {
        case "ERROR":
            record(message, level: .error)
        case "CANCELLED":
            record(message, level: .warning)
        default:
            record(message, level: .info)
        }
    }

    /// Logs STARTUP 23 once when Today has appeared and the first health/coach settle completed.
    static func markFirstScreenStableIfNeeded(detail: String) {
        lock.lock()
        let already = didMarkFirstScreenStable
        if !already {
            didMarkFirstScreenStable = true
        }
        lock.unlock()
        guard !already else { return }
        if loggingEnabled {
            step(23, "first screen stable", detail: detail)
        }
        StartupHangDetector.disarm()
    }

    // MARK: - Crashlytics

    /// Call once after Firebase configure. Logs Crashlytics linkage for Debug installs.
    static func logCrashlyticsStatus() {
        #if canImport(FirebaseCrashlytics)
        guard FirebaseBootstrap.isConfigured else {
            if loggingEnabled {
                logger.warning("STARTUP — Crashlytics status skipped; Firebase not configured yet")
            }
            return
        }
        let crashlytics = Crashlytics.crashlytics()
        let distribution = AppDistribution.current
        crashlytics.setCustomValue(distribution.analyticsValue, forKey: "weekfit_build_config")
        if loggingEnabled {
            step(
                5,
                "Firebase configured",
                detail: "Crashlytics SDK present distribution=\(distribution.analyticsValue)"
            )
        }
        crashlytics.setCustomValue(lastCompletedStep, forKey: "weekfit_last_startup_step")
        #else
        if loggingEnabled {
            logger.warning("STARTUP — Crashlytics module not linked; breadcrumbs are os.Logger only")
        }
        #endif
    }

    private enum LogLevel {
        case info, warning, error
    }

    private static func record(_ message: String, level: LogLevel) {
        lock.lock()
        lastStep = message
        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000)
        lock.unlock()

        // Chatty info/warning only when explicitly enabled.
        // Errors always reach os.Logger + Crashlytics.
        switch level {
        case .info:
            guard loggingEnabled else { return }
            logger.info("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
            breadcrumb(message)
        case .warning:
            guard loggingEnabled else { return }
            logger.warning("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
            breadcrumb(message)
        case .error:
            logger.error("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
            breadcrumb(message)
        }
    }

    /// Never touch Crashlytics on the calling thread during UI construction —
    /// Firebase/Crashlytics may hop to Main and deadlock with analytics locks.
    private static func breadcrumb(_ message: String) {
        guard crashlyticsBreadcrumbsEnabled else { return }
        guard FirebaseBootstrap.isConfigured else { return }
        #if canImport(FirebaseCrashlytics)
        DispatchQueue.global(qos: .utility).async {
            let crashlytics = Crashlytics.crashlytics()
            crashlytics.log(message)
            crashlytics.setCustomValue(message, forKey: "weekfit_last_startup_step")
            crashlytics.setCustomValue(StartupDiagnostics.launchIDShort, forKey: "weekfit_launch_id")
        }
        #endif
    }
}

/// Fine-grained Today first-frame breadcrumbs.
/// Filter Console by subsystem `com.weekfit.app` category `TodayStartup`.
///
/// Off by default even in DEBUG — flip `loggingEnabled` when diagnosing cold-start hangs.
/// Does **not** mirror into `StartupDiagnostics.logger` — that made every line appear twice
/// with the same instance/run id when filtering by subsystem only.
enum TodayStartupDiagnostics {
    static let logger = Logger(subsystem: "com.weekfit.app", category: "TodayStartup")

    /// Set to `true` temporarily when investigating Today launch stalls.
    private static let loggingEnabled = false

    private static let lock = NSLock()
    private static var lastStep: String = "none"
    private static var startedAt = CFAbsoluteTimeGetCurrent()
    private static var didMarkFirstFrameStable = false
    /// Watchdog tokens still awaiting `disarmWatchdog` — checked off the main thread.
    private static var armedWatchdogs: [UUID: (label: String, startedAt: CFAbsoluteTime)] = [:]

    static var lastCompletedStep: String {
        lock.lock()
        defer { lock.unlock() }
        return lastStep
    }

    static func step(_ number: Int, _ label: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        let padded = String(format: "%02d", number)
        var parts = [
            "TODAY \(padded) — \(label)",
            "launch=\(StartupDiagnostics.launchIDShort)",
            threadTag()
        ]
        if let detail, !detail.isEmpty {
            parts.insert(detail, at: 1)
        }
        emit(parts.joined(separator: " | "), level: .info)
    }

    static func child(_ name: String, detail: String? = nil) {
        guard loggingEnabled else { return }
        var parts = [
            "TODAY CHILD — \(name)",
            "launch=\(StartupDiagnostics.launchIDShort)",
            threadTag()
        ]
        if let detail, !detail.isEmpty {
            parts.insert(detail, at: 1)
        }
        emit(parts.joined(separator: " | "), level: .info)
    }

    // MARK: - Timed QUICK probes (quickActionsSection)

    /// Marks begin of a timed probe. Returns `CFAbsoluteTime` start for `quickComplete`.
    @discardableResult
    static func quickBegin(_ number: Int, _ label: String, detail: String? = nil) -> CFAbsoluteTime {
        let start = CFAbsoluteTimeGetCurrent()
        guard loggingEnabled else { return start }
        let padded = String(format: "%02d", number)
        let message: String
        if let detail, !detail.isEmpty {
            message = "QUICK \(padded) — \(label) begin | \(detail) | \(threadTag())"
        } else {
            message = "QUICK \(padded) — \(label) begin | \(threadTag())"
        }
        emit(message, level: .info)
        return start
    }

    static func quickComplete(_ number: Int, _ label: String, startedAt start: CFAbsoluteTime, detail: String? = nil) {
        guard loggingEnabled else { return }
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let padded = String(format: "%02d", number)
        var parts = [
            "QUICK \(padded) — \(label) complete",
            String(format: "elapsed=%.2fms", elapsedMs),
            threadTag()
        ]
        if let detail, !detail.isEmpty {
            parts.insert(detail, at: 1)
        }
        let message = parts.joined(separator: " | ")
        if elapsedMs >= 100 {
            emit(message, level: .error)
            emit(
                "QUICK WATCHDOG — \(label) exceeded 100ms (\(String(format: "%.2f", elapsedMs))ms) | \(threadTag())",
                level: .error
            )
        } else if elapsedMs >= 50 {
            emit(message, level: .warning)
            emit(
                "QUICK WATCHDOG — \(label) exceeded 50ms (\(String(format: "%.2f", elapsedMs))ms) | \(threadTag())",
                level: .warning
            )
        } else {
            emit(message, level: .info)
        }
    }

    /// Arms a background watchdog that fires even if the main thread is blocked.
    /// Call `disarmWatchdog` when the section finishes constructing.
    @discardableResult
    static func armWatchdog(label: String) -> UUID {
        guard loggingEnabled else { return UUID() }
        let token = UUID()
        let started = CFAbsoluteTimeGetCurrent()
        lock.lock()
        armedWatchdogs[token] = (label, started)
        lock.unlock()

        let thresholdsMs: [UInt32] = [50, 100, 500]
        DispatchQueue.global(qos: .userInitiated).async {
            var waited: UInt32 = 0
            for threshold in thresholdsMs {
                let sleepMs = threshold - waited
                if sleepMs > 0 {
                    usleep(sleepMs * 1000)
                    waited = threshold
                }
                lock.lock()
                let pending = armedWatchdogs[token]
                lock.unlock()
                guard let pending else { return }
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - pending.startedAt) * 1000
                let level: LogLevel = threshold >= 500 ? .error : (threshold >= 100 ? .error : .warning)
                emit(
                    "QUICK WATCHDOG — \(pending.label) still in progress after \(threshold)ms (elapsed=\(String(format: "%.1f", elapsedMs))ms) — main thread likely blocked or starved | bgThread check",
                    level: level
                )
            }
        }
        return token
    }

    static func disarmWatchdog(_ token: UUID) {
        lock.lock()
        armedWatchdogs.removeValue(forKey: token)
        lock.unlock()
    }

    static func taskBegin(_ name: String, detail: String? = nil) {
        taskPhase("BEGIN", name: name, detail: detail)
    }

    static func taskSuccess(_ name: String, detail: String? = nil) {
        taskPhase("SUCCESS", name: name, detail: detail)
    }

    static func taskError(_ name: String, error: Error, detail: String? = nil) {
        let nsError = error as NSError
        taskPhase(
            "ERROR",
            name: name,
            detail: [
                detail,
                "errorType=\(String(describing: type(of: error)))",
                "domain=\(nsError.domain)",
                "code=\(nsError.code)",
                "localizedDescription=\(nsError.localizedDescription)"
            ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
        )
    }

    static func taskCancelled(_ name: String, detail: String? = nil) {
        taskPhase("CANCELLED", name: name, detail: detail)
    }

    private static func taskPhase(_ phase: String, name: String, detail: String?) {
        guard loggingEnabled else { return }
        var parts = [
            "TODAY TASK \(phase) — \(name)",
            "launch=\(StartupDiagnostics.launchIDShort)",
            threadTag()
        ]
        if let detail, !detail.isEmpty {
            parts.insert(detail, at: 1)
        }
        let message = parts.joined(separator: " | ")
        switch phase {
        case "ERROR":
            emit(message, level: .error)
        case "CANCELLED":
            emit(message, level: .warning)
        default:
            emit(message, level: .info)
        }
    }

    static func markFirstFrameStableIfNeeded(detail: String) {
        lock.lock()
        let already = didMarkFirstFrameStable
        if !already { didMarkFirstFrameStable = true }
        lock.unlock()
        guard !already else { return }
        step(11, "first frame stable", detail: detail)
    }

    static func selectedDaySanity(selectedDate: Date) -> String {
        let calendar = Calendar.current
        let tz = calendar.timeZone
        let dayStart = calendar.startOfDay(for: selectedDate)
        // Avoid allocating DateFormatter on the main-thread body/init hot path.
        return [
            "raw=\(selectedDate.timeIntervalSince1970)",
            "startOfDay=\(dayStart.timeIntervalSince1970)",
            "tz=\(tz.identifier)",
            "secondsFromGMT=\(tz.secondsFromGMT(for: selectedDate))"
        ].joined(separator: " ")
    }

    static func threadTag() -> String {
        if Thread.isMainThread {
            return "thread=main"
        }
        return "thread=bg name=\(Thread.current.name ?? "-") qos=\(qosLabel())"
    }

    private static func qosLabel() -> String {
        switch qos_class_self() {
        case QOS_CLASS_USER_INTERACTIVE: return "userInteractive"
        case QOS_CLASS_USER_INITIATED: return "userInitiated"
        case QOS_CLASS_DEFAULT: return "default"
        case QOS_CLASS_UTILITY: return "utility"
        case QOS_CLASS_BACKGROUND: return "background"
        default: return "other"
        }
    }

    private enum LogLevel {
        case info, warning, error
    }

    private static func emit(_ message: String, level: LogLevel) {
        lock.lock()
        lastStep = message
        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000)
        lock.unlock()

        #if DEBUG
        switch level {
        case .info:
            logger.info("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
        case .warning:
            logger.warning("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
        case .error:
            logger.error("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
        }

        #if canImport(FirebaseCrashlytics)
        if FirebaseBootstrap.isConfigured {
            // Off-main: never call Crashlytics from SwiftUI body / MainActor hot path.
            DispatchQueue.global(qos: .utility).async {
                Crashlytics.crashlytics().log(message)
                Crashlytics.crashlytics().setCustomValue(message, forKey: "weekfit_last_startup_step")
            }
        }
        #endif
        #else
        // Release: Today child/quick chatter stays off; keep hard failures only.
        guard level == .error else { return }
        logger.error("\(message, privacy: .public) +\(elapsedMs, privacy: .public)ms")
        #if canImport(FirebaseCrashlytics)
        if FirebaseBootstrap.isConfigured {
            DispatchQueue.global(qos: .utility).async {
                Crashlytics.crashlytics().log(message)
            }
        }
        #endif
        #endif
    }
}
