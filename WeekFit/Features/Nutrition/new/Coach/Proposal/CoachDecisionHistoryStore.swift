import Foundation

enum CoachDecisionHistoryStore {

    private static let storageKey = "coach.decisionHistory.v1"
    private static let retentionDays = 60
    private static let lock = NSLock()

    static func append(_ entry: CoachDecisionHistoryEntry) {
        lock.lock()
        var stored = loadUnsafe()
        stored.append(entry)
        saveUnsafe(stored)
        lock.unlock()
    }

    static func append(_ entries: [CoachDecisionHistoryEntry]) {
        guard !entries.isEmpty else { return }
        lock.lock()
        var stored = loadUnsafe()
        stored.append(contentsOf: entries)
        saveUnsafe(stored)
        lock.unlock()
    }

    static func entries(forDayKey dayKey: String) -> [CoachDecisionHistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().filter { $0.dayKey == dayKey }
    }

    static func purgeOlderThan(referenceDate: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: referenceDate) else {
            return
        }
        let cutoffKey = ProposalInputFingerprintBuilder.dayKey(for: cutoff, calendar: calendar)
        lock.lock()
        let retained = loadUnsafe().filter { $0.dayKey >= cutoffKey }
        saveUnsafe(retained)
        lock.unlock()
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }
    #endif

    private static func loadUnsafe() -> [CoachDecisionHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([CoachDecisionHistoryEntry].self, from: data)) ?? []
    }

    private static func saveUnsafe(_ stored: [CoachDecisionHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
