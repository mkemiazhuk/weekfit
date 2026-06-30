import Foundation
import OSLog

/// Production-safe counters for Coach vs V5 presentation fallback.
enum CoachIntegrationMetrics {

    struct Snapshot: Equatable, Sendable, Codable {
        let totalReadyEvaluations: Int
        let activeCount: Int
        let fallbackCount: Int
        let fallbackCountsByScenario: [String: Int]
        let fallbackCountsByReason: [String: Int]
        let lastFallbackScenario: String?
        let lastFallbackReason: String?
        let lastRecordedAt: Date?

        static let empty = Snapshot(
            totalReadyEvaluations: 0,
            activeCount: 0,
            fallbackCount: 0,
            fallbackCountsByScenario: [:],
            fallbackCountsByReason: [:],
            lastFallbackScenario: nil,
            lastFallbackReason: nil,
            lastRecordedAt: nil
        )

        var activeRate: Double {
            guard totalReadyEvaluations > 0 else { return 0 }
            return Double(activeCount) / Double(totalReadyEvaluations)
        }

        var logSummary: String {
            let rate = String(format: "%.1f%%", activeRate * 100)
            return [
                "ready=\(totalReadyEvaluations)",
                "v6=\(activeCount)",
                "fallback=\(fallbackCount)",
                "v6Rate=\(rate)"
            ].joined(separator: " ")
        }
    }

    private static let storageKey = "coach_v6_integration_metrics_v1"
    private static let lock = NSLock()
    private static var memory = Snapshot.empty
    private static let logger = Logger(subsystem: "WeekFit", category: "CoachIntegration")

    static var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return memory
    }

    static func record(debug: CoachIntegrationDebug, recomputeReason: String) {
        lock.lock()
        let previous = memory
        let scenarioKey = debug.scenario.rawValue
        let reasonKey = debug.fallbackReason ?? "unknown"

        let next = Snapshot(
            totalReadyEvaluations: previous.totalReadyEvaluations + 1,
            activeCount: previous.activeCount + (debug.usingCoach ? 1 : 0),
            fallbackCount: previous.fallbackCount + (debug.usingCoach ? 0 : 1),
            fallbackCountsByScenario: debug.usingCoach
                ? previous.fallbackCountsByScenario
                : increment(previous.fallbackCountsByScenario, key: scenarioKey),
            fallbackCountsByReason: debug.usingCoach
                ? previous.fallbackCountsByReason
                : increment(previous.fallbackCountsByReason, key: reasonKey),
            lastFallbackScenario: debug.usingCoach ? previous.lastFallbackScenario : scenarioKey,
            lastFallbackReason: debug.usingCoach ? previous.lastFallbackReason : reasonKey,
            lastRecordedAt: Date()
        )

        memory = next
        lock.unlock()

        persist(next)

        #if DEBUG
        guard CoachDebug.isCompactEnabled else { return }
        if debug.usingCoach {
            logger.debug("usingCoach=yes scenario=\(debug.scenario.rawValue, privacy: .public) reason=\(recomputeReason, privacy: .public)")
        } else {
            logger.notice(
                "usingCoach=no scenario=\(debug.scenario.rawValue, privacy: .public) copyPack=\(debug.copyPackExists ? "yes" : "nil", privacy: .public) fallbackReason=\(reasonKey, privacy: .public) recomputeReason=\(recomputeReason, privacy: .public) totals=\(next.logSummary, privacy: .public)"
            )
        }
        #endif
    }

    private static func increment(_ counts: [String: Int], key: String) -> [String: Int] {
        var updated = counts
        updated[key, default: 0] += 1
        return updated
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        memory = .empty
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static func resetMemoryForTests() {
        lock.lock()
        memory = .empty
        lock.unlock()
    }
    #endif

    static func restoreFromStorageIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }

        lock.lock()
        memory = stored
        lock.unlock()
    }

    private static func persist(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
