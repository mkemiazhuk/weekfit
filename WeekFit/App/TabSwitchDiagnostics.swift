import Foundation
import SwiftUI

// MARK: - Tab visibility

private struct TabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var tabIsActive: Bool {
        get { self[TabIsActiveKey.self] }
        set { self[TabIsActiveKey.self] = newValue }
    }
}

// MARK: - Planned activity signature (input-only, for refresh coalescing)

enum PlannedActivityRefreshSignature {
    static func make(from activities: [PlannedActivity]) -> String {
        activities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.title,
                    activity.type,
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    "\(activity.actualDurationMinutes ?? -1)",
                    activity.healthKitWorkoutUUID ?? "nil",
                    activity.source
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    /// Compact token for Equatable gates — avoids comparing multi-KB revision strings.
    static func compactToken(from revision: String) -> String {
        var hasher = Hasher()
        hasher.combine(revision)
        return "\(revision.count)-\(hasher.finalize())"
    }
}

// MARK: - Live instance tracking (DEBUG)

enum WeekFitLifecycleTracker {
    private static let lock = NSLock()
    private static var liveCounts: [String: Int] = [:]

    static func attach(_ typeName: String) {
        #if DEBUG
        guard CoachDebugSettings.lifecycleDiagnosticsEnabled else { return }
        lock.lock()
        liveCounts[typeName, default: 0] += 1
        let count = liveCounts[typeName] ?? 0
        lock.unlock()
        print("[Lifecycle] init \(typeName) live=\(count)")
        #endif
    }

    static func detach(_ typeName: String) {
        #if DEBUG
        guard CoachDebugSettings.lifecycleDiagnosticsEnabled else { return }
        lock.lock()
        if let count = liveCounts[typeName], count > 0 {
            liveCounts[typeName] = count - 1
        }
        let remaining = liveCounts[typeName] ?? 0
        lock.unlock()
        print("[Lifecycle] deinit \(typeName) live=\(remaining)")
        #endif
    }

    static var snapshot: [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return liveCounts
    }
}

// MARK: - Tab switch diagnostics (DEBUG)

enum TabSwitchDiagnostics {
    private static let lock = NSLock()
    private static var switchCount = 0
    private static var tapStart: CFAbsoluteTime = 0
    private static var committedStart: CFAbsoluteTime = 0
    private static var modalDepth = 0

    static func markSwitchStarted() {
        #if DEBUG
        lock.lock()
        tapStart = CFAbsoluteTimeGetCurrent()
        lock.unlock()
        #endif
    }

    /// Call when `selectedTab` actually changes — authoritative switch stopwatch.
    static func markSwitchCommitted() {
        #if DEBUG
        lock.lock()
        committedStart = CFAbsoluteTimeGetCurrent()
        lock.unlock()
        #endif
    }

    /// Modals/sheets/profile can delay tab commits — invalidate stale bar-tap timers.
    static func notifyModalPresented() {
        #if DEBUG
        lock.lock()
        modalDepth += 1
        tapStart = 0
        lock.unlock()
        #endif
    }

    static func notifyModalDismissed() {
        #if DEBUG
        lock.lock()
        modalDepth = max(0, modalDepth - 1)
        tapStart = 0
        lock.unlock()
        #endif
    }

    static func reportTabSwitch(
        from oldTab: WeekFitTab,
        to newTab: WeekFitTab,
        coachRecomputeCount: Int,
        coachRecomputeDelta: Int,
        coachSkippedUnchangedCount: Int,
        coachSkippedDelta: Int,
        coachEvaluationTriggered: Bool,
        coachRefreshDurationMs: Double?,
        healthRefreshSkipped: Bool = false,
        handlerMs: Double? = nil
    ) {
        #if DEBUG
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else { return }
        lock.lock()
        switchCount += 1
        let count = switchCount
        lock.unlock()

        let now = CFAbsoluteTimeGetCurrent()

        lock.lock()
        let tapStartSnapshot = tapStart
        let committedStartSnapshot = committedStart
        tapStart = 0
        committedStart = 0
        lock.unlock()

        let switchMs: Double
        if committedStartSnapshot > 0 {
            switchMs = (now - committedStartSnapshot) * 1000
        } else if tapStartSnapshot > 0 {
            switchMs = (now - tapStartSnapshot) * 1000
        } else {
            switchMs = 0
        }

        let tapToCommitMs: Double? = {
            guard tapStartSnapshot > 0, committedStartSnapshot > 0 else { return nil }
            return (committedStartSnapshot - tapStartSnapshot) * 1000
        }()

        let handlerNote = handlerMs.map {
            String(format: " handlerMs=%.1f layoutMs=%.1f", $0, max(0, switchMs - $0))
        } ?? ""

        let tapNote = tapToCommitMs.map {
            String(format: " tapToCommitMs=%.1f", $0)
        } ?? ""

        let memoryMB = Self.residentMemoryMB()
        let instances = WeekFitLifecycleTracker.snapshot
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")

        let coachRefreshNote = coachRefreshDurationMs.map {
            String(format: " coachRefreshMs=%.1f", $0)
        } ?? ""
        let healthNote = healthRefreshSkipped ? " healthRefresh=skipped" : ""

        print(
            """
            [TabSwitchDiag] #\(count) tab=\(newTab) from=\(oldTab) memoryMB=\(String(format: "%.1f", memoryMB)) switchMs=\(String(format: "%.1f", switchMs))\(tapNote)\(handlerNote)\(coachRefreshNote)\(healthNote) coachRecomputeTotal=\(coachRecomputeCount) coachRecomputeDelta=\(coachRecomputeDelta) coachSkippedTotal=\(coachSkippedUnchangedCount) coachSkippedDelta=\(coachSkippedDelta) coachEval=\(coachEvaluationTriggered) live=[\(instances)]
            """
        )
        #endif
    }

    static func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_024 / 1_024
    }
}

extension View {
    func weekFitTabSwitchModalOverlay() -> some View {
        onAppear {
            TabSwitchDiagnostics.notifyModalPresented()
        }
        .onDisappear {
            TabSwitchDiagnostics.notifyModalDismissed()
        }
    }
}

// MARK: - Planner body diagnostics (DEBUG)

enum PlannerBodyDiagnostics {
    private static let lock = NSLock()
    private static var bodyEvaluationCount = 0
    private static var mountStartedAt: CFAbsoluteTime?

    static func markBodyEvaluation() {
        #if DEBUG
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else { return }
        lock.lock()
        if mountStartedAt == nil {
            mountStartedAt = CFAbsoluteTimeGetCurrent()
        }
        bodyEvaluationCount += 1
        let count = bodyEvaluationCount
        lock.unlock()
        TabSwitchProfiler.markEvent("WeekPlannerLiveQueryView.bodyEval count=\(count)")
        #endif
    }

    static func reportMountCompleted() {
        #if DEBUG
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else { return }
        lock.lock()
        let startedAt = mountStartedAt
        let bodyEvaluations = bodyEvaluationCount
        mountStartedAt = nil
        bodyEvaluationCount = 0
        lock.unlock()
        guard let startedAt else { return }
        let mountMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        TabSwitchProfiler.markEvent(
            "WeekPlannerLiveQueryView.mountComplete ms=\(String(format: "%.1f", mountMs)) bodyEvals=\(bodyEvaluations)"
        )
        #endif
    }

    @discardableResult
    static func measure<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        #if DEBUG
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else {
            return try work()
        }
        let start = CFAbsoluteTimeGetCurrent()
        let result = try work()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("[PlannerBodyProfile] \(name) ms=\(String(format: "%.2f", ms))")
        return result
        #else
        return try work()
        #endif
    }
}

// MARK: - Meal memory audit (DEBUG)

enum MealMemoryAudit {
    static func checkpoint(_ label: String) {
        #if DEBUG
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else { return }
        let memoryMB = TabSwitchDiagnostics.residentMemoryMB()
        print("[MealMemoryAudit] \(label) memoryMB=\(String(format: "%.1f", memoryMB))")
        #endif
    }
}
