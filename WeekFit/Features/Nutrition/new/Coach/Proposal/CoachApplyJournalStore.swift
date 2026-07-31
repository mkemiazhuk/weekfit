import Foundation

enum CoachApplyJournalStore {

    private static let storageKey = "coach.applyJournal.v1"
    private static let lock = NSLock()

    static func current() -> CoachApplyJournal? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()
    }

    static func save(_ journal: CoachApplyJournal) {
        lock.lock()
        saveUnsafe(journal)
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }

    #if DEBUG
    static func resetAllForTests() {
        clear()
    }
    #endif

    private static func loadUnsafe() -> CoachApplyJournal? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CoachApplyJournal.self, from: data)
    }

    private static func saveUnsafe(_ journal: CoachApplyJournal) {
        guard let data = try? JSONEncoder().encode(journal) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
