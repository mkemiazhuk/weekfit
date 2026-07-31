import Foundation

enum MorningProposalStore {

    private static let storageKey = "coach.morningProposal.v1"
    private static let lock = NSLock()

    static func proposal(for dayKey: String) -> MorningPlanProposal? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()[dayKey]
    }

    static func upsert(_ proposal: MorningPlanProposal) {
        lock.lock()
        var stored = loadUnsafe()
        stored[proposal.dayKey] = proposal
        saveUnsafe(stored)
        lock.unlock()
    }

    static func update(_ dayKey: String, mutate: (inout MorningPlanProposal) -> Void) {
        lock.lock()
        var stored = loadUnsafe()
        guard var proposal = stored[dayKey] else {
            lock.unlock()
            return
        }
        mutate(&proposal)
        stored[dayKey] = proposal
        saveUnsafe(stored)
        lock.unlock()
    }

    static func remove(dayKey: String) {
        lock.lock()
        var stored = loadUnsafe()
        stored.removeValue(forKey: dayKey)
        saveUnsafe(stored)
        lock.unlock()
    }

    /// Expire proposals whose dayKey is strictly before `currentDayKey`.
    static func expireBefore(dayKey currentDayKey: String) {
        lock.lock()
        var stored = loadUnsafe()
        var changed = false
        for (key, var proposal) in stored where key < currentDayKey {
            if proposal.status != .expired && proposal.status != .applied {
                proposal.status = .expired
                stored[key] = proposal
                changed = true
            }
        }
        if changed {
            saveUnsafe(stored)
        }
        lock.unlock()
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }
    #endif

    private static func loadUnsafe() -> [String: MorningPlanProposal] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: MorningPlanProposal].self, from: data)) ?? [:]
    }

    private static func saveUnsafe(_ stored: [String: MorningPlanProposal]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
