import Foundation

/// UserDefaults-backed feeling check-ins. Self-reports stay separate from recovery scoring.
enum CoachFeelingCheckInStore {
    static let storageKey = "coach.feeling.checkIns.v1"
    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func all() -> [CoachFeelingCheckIn] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().sorted { $0.createdAt > $1.createdAt }
    }

    static func latest(on day: Date = Date(), calendar: Calendar = .current) -> CoachFeelingCheckIn? {
        let dayKey = CoachDailyObservation.dayKey(for: day, calendar: calendar)
        return all().first { $0.dayKey(calendar: calendar) == dayKey }
    }

    static func hasAnswer(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        latest(on: day, calendar: calendar) != nil
    }

    static func checkIn(id: String) -> CoachFeelingCheckIn? {
        all().first { $0.id == id }
    }

    static func upsert(_ checkIn: CoachFeelingCheckIn) {
        lock.lock()
        var items = loadUnsafe()
        if let index = items.firstIndex(where: { $0.id == checkIn.id }) {
            items[index] = checkIn
        } else {
            items.append(checkIn)
        }
        saveUnsafe(items)
        lock.unlock()
    }

    @discardableResult
    static func delete(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var items = loadUnsafe()
        let before = items.count
        items.removeAll { $0.id == id }
        saveUnsafe(items)
        return items.count < before
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    // MARK: - Test seam

    static func useDefaults(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func resetDefaults() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }

    // MARK: - Private

    private static func loadUnsafe() -> [CoachFeelingCheckIn] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([CoachFeelingCheckIn].self, from: data)) ?? []
    }

    private static func saveUnsafe(_ items: [CoachFeelingCheckIn]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
