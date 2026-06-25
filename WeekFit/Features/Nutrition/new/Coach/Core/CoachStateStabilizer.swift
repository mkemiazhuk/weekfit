import Foundation

enum CoachStateStabilizer {
    private static let lock = NSLock()
    private static var syncSettlingUntilBySurface: [String: Date] = [:]
    private static let stabilizationInterval: TimeInterval = 0.55

    static func markSyncEvent(source: String) {
        let normalized = source.lowercased()
        let surfaceKey = surfaceKey(for: normalized)

        if isRealityChangeSource(normalized) {
            lock.lock()
            syncSettlingUntilBySurface.removeAll()
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

    static func isSettling(source: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
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
            source.contains("languagechange") ||
            source.contains("logout")
    }
}
