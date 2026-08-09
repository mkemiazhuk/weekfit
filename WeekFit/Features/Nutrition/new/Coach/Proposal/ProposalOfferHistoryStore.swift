import Foundation

/// Cross-day memory of optional Morning Adjustment offers (not Apply outcomes).
/// Used to avoid mechanically resurfacing the same optional create every morning.
enum ProposalOfferHistoryStore {

    private static let storageKey = "coach.proposalOfferHistory.v1"
    private static let retentionDays = 21
    private static let lock = NSLock()

    struct Entry: Codable, Sendable, Equatable {
        let dayKey: String
        let changeId: String
        let kindRaw: String
        let recordedAt: Date
    }

    /// Records optional creates offered in a ready proposal for this day (idempotent per day+id).
    static func recordOffers(
        dayKey: String,
        changes: [CoachProposedChange],
        now: Date = Date()
    ) {
        let optional = changes.filter { isOptionalCreate($0.kind) }
        guard !optional.isEmpty else { return }

        let ids = Set(optional.map(\.id))
        lock.lock()
        var stored = loadUnsafe()
        stored.removeAll { $0.dayKey == dayKey && ids.contains($0.changeId) }
        for change in optional {
            stored.append(
                Entry(
                    dayKey: dayKey,
                    changeId: change.id,
                    kindRaw: change.kind.rawValue,
                    recordedAt: now
                )
            )
        }
        saveUnsafe(stored)
        lock.unlock()
    }

    static func wasRecentlyOffered(
        changeId: String,
        excludingDayKey: String,
        lookingBackDays: Int,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard lookingBackDays > 0 else { return false }
        guard let cutoff = calendar.date(byAdding: .day, value: -lookingBackDays, to: referenceDate) else {
            return false
        }
        let cutoffKey = ProposalInputFingerprintBuilder.dayKey(for: cutoff, calendar: calendar)

        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().contains { entry in
            entry.changeId == changeId
                && entry.dayKey != excludingDayKey
                && entry.dayKey >= cutoffKey
        }
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

    static func entriesForTests() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()
    }
    #endif

    private static func isOptionalCreate(_ kind: CoachChangeKind) -> Bool {
        switch kind {
        case .createPlannedActivity, .createRecoveryWalk:
            return true
        case .createMealFromLibrary, .modifyDuration, .moveActivity, .skipActivity, .guidanceOnly:
            return false
        }
    }

    private static func loadUnsafe() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func saveUnsafe(_ stored: [Entry]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
