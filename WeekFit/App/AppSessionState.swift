import Foundation
internal import Combine

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
    private static let logLevelKey = "coach_log_level"

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
}

enum CoachLogger {
    static func decision(_ message: @autoclosure () -> String) {
        guard CoachDebugSettings.logLevel == .decisions ||
                CoachDebugSettings.logLevel == .verbose else {
            return
        }
        emit("[CoachDecision]", message())
    }

    static func verbose(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebugSettings.logLevel == .verbose else { return }
        emit(tag, message())
    }

    static func warning(_ message: @autoclosure () -> String) {
        emit("[CoachWarning]", message())
    }

    static func error(_ message: @autoclosure () -> String) {
        emit("[CoachError]", message())
    }

    private static func emit(_ tag: String, _ message: String) {
        print("\(tag) \(message)")
    }
}

enum CoachRefreshDebug {
    private static let lock = NSLock()
    private static var sequence = 0
    private static var lastTimestamp = Date.distantPast
    private static var burstCount = 0

    static func log(_ tag: String, _ message: @autoclosure () -> String) {
        guard CoachDebugSettings.logLevel == .verbose else { return }

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

final class AppSessionState: ObservableObject {

    @Published var returnToTodayTrigger = UUID()
    @Published var healthRefreshTrigger = UUID()
    @Published var coachRefreshTrigger = UUID()
    @Published var localDataResetTrigger = UUID()

    private var pendingHealthRefreshSources: [String] = []
    private var pendingCoachRefreshSources: [String] = []
    private var isHealthRefreshScheduled = false
    private var isCoachRefreshScheduled = false

    func triggerReturnToToday() {
        returnToTodayTrigger = UUID()
    }

    func triggerLocalDataResetCompleted() {
        localDataResetTrigger = UUID()
    }

    func triggerHealthRefresh(source: String = "unspecified") {
        CoachStateStabilizer.markSyncEvent(source: source)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.triggerHealthRefresh(source: source)
            }
            return
        }

        pendingHealthRefreshSources.append(source)
        guard !isHealthRefreshScheduled else { return }

        isHealthRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushHealthRefresh()
        }
    }

    func triggerCoachRefresh(source: String = "unspecified") {
        CoachStateStabilizer.markSyncEvent(source: source)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.triggerCoachRefresh(source: source)
            }
            return
        }

        pendingCoachRefreshSources.append(source)
        guard !isCoachRefreshScheduled else { return }

        isCoachRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushCoachRefresh()
        }
    }

    private func flushHealthRefresh() {
        let sources = pendingHealthRefreshSources
        pendingHealthRefreshSources.removeAll()
        isHealthRefreshScheduled = false

        let oldValue = healthRefreshTrigger
        let newValue = UUID()
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.healthRefreshTrigger sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
        )
        #endif
        healthRefreshTrigger = newValue
    }

    private func flushCoachRefresh() {
        let sources = pendingCoachRefreshSources
        pendingCoachRefreshSources.removeAll()
        isCoachRefreshScheduled = false

        let oldValue = coachRefreshTrigger
        let newValue = UUID()
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.coachRefreshTrigger sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
        )
        #endif
        coachRefreshTrigger = newValue
    }

    private func summarizeRefreshSources(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "unspecified" }

        let uniqueSources = Array(Set(sources)).sorted()
        let summary = uniqueSources.prefix(4).joined(separator: ",")
        let overflow = uniqueSources.count > 4 ? ",+\(uniqueSources.count - 4)" : ""
        return "[\(summary)\(overflow)]"
    }
}
