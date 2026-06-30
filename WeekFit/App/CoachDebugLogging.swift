import Foundation

enum CoachLogLevel: String, CaseIterable, Identifiable {
    case off
    case decisions
    case verbose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .decisions:
            return "Decisions"
        case .verbose:
            return "Verbose"
        }
    }
}

enum CoachDebugSettings {
    static let logLevelKey = "coach_log_level"
    static let pipelineTraceKey = "coach_pipeline_trace_enabled"
    static let todayDataAuditKey = "today_data_audit_enabled"

    static var logLevel: CoachLogLevel {
        get {
            CoachLogLevel(
                rawValue: UserDefaults.standard.string(forKey: logLevelKey) ?? CoachLogLevel.off.rawValue
            ) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: logLevelKey)
        }
    }

    static var verboseLoggingEnabled: Bool {
        get {
            logLevel == .verbose
        }
        set {
            logLevel = newValue ? .verbose : .off
        }
    }

    static var pipelineTraceEnabled: Bool {
        UserDefaults.standard.bool(forKey: pipelineTraceKey) ||
            ProcessInfo.processInfo.environment["WEEKFIT_COACH_PIPELINE_TRACE"] == "1"
    }

    static var todayDataAuditEnabled: Bool {
        UserDefaults.standard.bool(forKey: todayDataAuditKey) ||
            ProcessInfo.processInfo.environment["WEEKFIT_TODAY_DATA_AUDIT"] == "1"
    }

    static let tabSwitchDiagnosticsKey = "weekfit_tab_switch_diagnostics_enabled"
    static let lifecycleDiagnosticsKey = "weekfit_lifecycle_diagnostics_enabled"
    static let nightComfortDiagnosticsKey = "weekfit_night_comfort_diagnostics_enabled"

    static var tabSwitchDiagnosticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: tabSwitchDiagnosticsKey) ||
            ProcessInfo.processInfo.environment["WEEKFIT_TAB_SWITCH_DIAG"] == "1"
    }

    static var lifecycleDiagnosticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: lifecycleDiagnosticsKey) ||
            ProcessInfo.processInfo.environment["WEEKFIT_LIFECYCLE_DIAG"] == "1"
    }

    static var nightComfortDiagnosticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: nightComfortDiagnosticsKey) ||
            ProcessInfo.processInfo.environment["WEEKFIT_NIGHT_COMFORT_DIAG"] == "1"
    }

    static var healthRefreshGuardLoggingEnabled: Bool {
        pipelineTraceEnabled
    }
}

enum CoachDebug {
    static var isVerboseEnabled: Bool {
        CoachDebugSettings.logLevel == .verbose
    }

    static var isCompactEnabled: Bool {
        CoachDebugSettings.logLevel == .decisions || isVerboseEnabled
    }
}

enum CoachLogger {
    private static let throttleLock = NSLock()
    private static var lastThrottledMessages: [String: Date] = [:]

    static func decision(_ message: @autoclosure () -> String) {
        guard CoachDebugSettings.logLevel == .decisions ||
                CoachDebug.isVerboseEnabled else {
            return
        }
        emit("[CoachDecision]", message())
    }

    static func compact(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebug.isCompactEnabled else { return }
        emit(tag, message())
    }

    static func compactThrottled(
        _ tag: String,
        key: String,
        interval: TimeInterval = 8,
        _ message: @autoclosure () -> String
    ) {
        guard CoachDebug.isCompactEnabled else { return }

        let now = Date()
        throttleLock.lock()
        let shouldEmit = now.timeIntervalSince(lastThrottledMessages[key] ?? .distantPast) >= interval
        if shouldEmit {
            lastThrottledMessages[key] = now
        }
        throttleLock.unlock()

        guard shouldEmit else { return }
        emit(tag, message())
    }

    static func verbose(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebug.isVerboseEnabled else { return }
        emit(tag, message())
    }

    static func trace(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebugSettings.pipelineTraceEnabled else { return }
        emit(tag, message())
    }

    static func warning(_ message: @autoclosure () -> String) {
        #if DEBUG
        emit("[CoachWarning]", message())
        #endif
    }

    static func error(_ message: @autoclosure () -> String) {
        #if DEBUG
        emit("[CoachError]", message())
        #endif
    }

    private static func emit(_ tag: String, _ message: String) {
        #if DEBUG
        print("\(tag) \(message)")
        #endif
    }
}

enum CoachRefreshDebug {
    private static let lock = NSLock()
    private static var sequence = 0
    private static var lastTimestamp = Date.distantPast
    private static var burstCount = 0

    static func log(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebug.isVerboseEnabled && CoachDebugSettings.pipelineTraceEnabled else { return }

        let now = Date()
        let entrySequence: Int
        let entryBurstCount: Int

        lock.lock()
        sequence += 1
        entrySequence = sequence

        if now.timeIntervalSince(lastTimestamp) < 0.0167 {
            burstCount += 1
        } else {
            burstCount = 1
        }

        entryBurstCount = burstCount
        lastTimestamp = now
        lock.unlock()

        let timestamp = String(format: "%.6f", now.timeIntervalSince1970)
        let burstNote = entryBurstCount > 1 ? " burst=\(entryBurstCount) (<16ms)" : " burst=1"
        CoachLogger.verbose(
            tag,
            "seq=\(entrySequence) time=\(timestamp)\(burstNote) mainThread=\(Thread.isMainThread) \(message())"
        )
    }

    static func uuidChange(oldValue: UUID, newValue: UUID) -> String {
        "old=\(oldValue.uuidString) new=\(newValue.uuidString)"
    }

    static func hydrationSummary(current: Double, goal: Double) -> String {
        let ratio = goal > 0 ? current / goal : 0
        return "waterCurrent=\(String(format: "%.2f", current)) waterGoal=\(String(format: "%.2f", goal)) hydrationRatio=\(String(format: "%.2f", ratio))"
    }
}
