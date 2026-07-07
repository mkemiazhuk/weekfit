import Foundation

enum CoachStateStabilizer {
    private static let lock = NSLock()
    private static var syncSettlingUntilBySurface: [String: Date] = [:]
    private static var coachReadyConfirmedDayStart: Int?
    static let stabilizationInterval: TimeInterval = 0.55

    static func markCoachReadyForDay(_ dayStart: Date, calendar: Calendar = .current) {
        lock.lock()
        coachReadyConfirmedDayStart = CoachTodayInsightCache.dayKey(for: dayStart, calendar: calendar)
        lock.unlock()
    }

    static func clearCoachReadyForDay() {
        lock.lock()
        coachReadyConfirmedDayStart = nil
        lock.unlock()
    }

    static func markSyncEvent(source: String) {
        let normalized = source.lowercased()
        let surfaceKey = surfaceKey(for: normalized)

        if isRealityChangeSource(normalized) {
            lock.lock()
            syncSettlingUntilBySurface.removeAll()
            coachReadyConfirmedDayStart = nil
            lock.unlock()
            return
        }

        guard normalized.contains("health") ||
                normalized.contains("sync") ||
                normalized.contains("completedworkoutsbatch") ||
                normalized.contains("activitycoordinator") else {
            return
        }

        lock.lock()
        let nextSettlingTime = Date().addingTimeInterval(stabilizationInterval)
        let affectedSurfaces = surfaceKey == "shared" ? ["today", "coach", "shared"] : [surfaceKey]
        for affectedSurface in affectedSurfaces {
            syncSettlingUntilBySurface[affectedSurface] = max(
                syncSettlingUntilBySurface[affectedSurface] ?? Date.distantPast,
                nextSettlingTime
            )
        }
        lock.unlock()
    }

    static func markRealityChange(source: String) {
        markSyncEvent(source: source)
    }

    static func isSettling(source: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if coachReadyConfirmedDayStart == nil {
            return false
        }
        let surfaceKey = surfaceKey(for: source)
        return Date() < (syncSettlingUntilBySurface[surfaceKey] ?? syncSettlingUntilBySurface["shared"] ?? Date.distantPast)
    }

    private static func surfaceKey(for source: String) -> String {
        if source.contains("today") { return "today" }
        if source.contains("coach") { return "coach" }
        return "shared"
    }

    private static func isRealityChangeSource(_ source: String) -> Bool {
        source.contains("plannedactivities.removed") ||
            source.contains("plannedactivitiesreset") ||
            source.contains("planneractivitydelete") ||
            source.contains("plannedactivitieschanged") ||
            source.contains("languagechange") ||
            source.contains("logout") ||
            source.contains("dayrollover") ||
            source.contains("dayboundary")
    }
}
