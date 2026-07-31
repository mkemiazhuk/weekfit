import Foundation

enum CoachAdjustmentProvenanceStore {

    private static let storageKey = "coach.appliedAdjustments.v1"
    private static let retentionDays = 14
    private static let lock = NSLock()

    static func adjustments(forDayKey dayKey: String) -> [AppliedCoachAdjustment] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().filter { $0.dayKey == dayKey }
    }

    static func adjustment(forActivityId id: String) -> AppliedCoachAdjustment? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().last { $0.activityId == id }
    }

    static func upsert(_ adjustment: AppliedCoachAdjustment) {
        lock.lock()
        var stored = loadUnsafe()
        if let index = stored.firstIndex(where: { $0.id == adjustment.id }) {
            stored[index] = adjustment
        } else if let index = stored.firstIndex(where: {
            $0.activityId == adjustment.activityId && $0.dayKey == adjustment.dayKey
        }) {
            stored[index] = adjustment
        } else {
            stored.append(adjustment)
        }
        saveUnsafe(stored)
        lock.unlock()
        CoachProvenanceLookupCache.invalidate()
    }

    static func markManualEdit(activityId: String) {
        lock.lock()
        var stored = loadUnsafe()
        guard let index = stored.lastIndex(where: { $0.activityId == activityId }) else {
            lock.unlock()
            return
        }
        stored[index].userManuallyEditedAfterApply = true
        saveUnsafe(stored)
        lock.unlock()
        CoachProvenanceLookupCache.invalidate()
    }

    static func markTerminalOutcome(activityId: String, outcome: String) {
        lock.lock()
        var stored = loadUnsafe()
        guard let index = stored.lastIndex(where: { $0.activityId == activityId }) else {
            lock.unlock()
            return
        }
        stored[index].terminalOutcome = outcome
        saveUnsafe(stored)
        lock.unlock()
        CoachProvenanceLookupCache.invalidate()
    }

    static func lookupByActivityId(forDayKey dayKey: String) -> [String: AppliedCoachAdjustment] {
        Dictionary(
            adjustments(forDayKey: dayKey).map { ($0.activityId, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    static func purge(olderThanDayKey dayKey: String) {
        lock.lock()
        let retained = loadUnsafe().filter { $0.dayKey >= dayKey }
        saveUnsafe(retained)
        lock.unlock()
    }

    static func purgeOlderThan(referenceDate: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: referenceDate) else {
            return
        }
        let cutoffKey = ProposalInputFingerprintBuilder.dayKey(for: cutoff, calendar: calendar)
        purge(olderThanDayKey: cutoffKey)
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }
    #endif

    private static func loadUnsafe() -> [AppliedCoachAdjustment] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([AppliedCoachAdjustment].self, from: data)) ?? []
    }

    private static func saveUnsafe(_ stored: [AppliedCoachAdjustment]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
