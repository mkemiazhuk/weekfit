import Foundation

/// UserDefaults-backed Coach Assistant conversations.
enum CoachAssistantConversationStore {
    static let storageKey = "coach.assistant.conversations.v1"
    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func all() -> [CoachAssistantConversation] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().sorted { $0.updatedAt > $1.updatedAt }
    }

    static func latest(on day: Date = Date(), calendar: Calendar = .current) -> CoachAssistantConversation? {
        let dayKey = CoachDailyObservation.dayKey(for: day, calendar: calendar)
        return all().first { $0.dayKey(calendar: calendar) == dayKey }
    }

    static func conversation(id: String) -> CoachAssistantConversation? {
        all().first { $0.id == id }
    }

    /// Keep at most this many distinct calendar days of conversations.
    static let retentionDayCount = 14

    static func upsert(_ conversation: CoachAssistantConversation) {
        lock.lock()
        var items = loadUnsafe()
        if let index = items.firstIndex(where: { $0.id == conversation.id }) {
            items[index] = conversation
        } else {
            items.append(conversation)
        }
        items = pruneUnsafe(items, calendar: .current)
        saveUnsafe(items)
        lock.unlock()
    }

    /// Removes other same-day conversations so intentional “New” doesn’t accumulate drafts.
    static func supersedeSameDay(
        keeping id: String,
        on day: Date = Date(),
        calendar: Calendar = .current
    ) {
        lock.lock()
        let dayKey = CoachDailyObservation.dayKey(for: day, calendar: calendar)
        var items = loadUnsafe()
        items.removeAll { conversation in
            conversation.id != id
                && conversation.dayKey(calendar: calendar) == dayKey
        }
        saveUnsafe(items)
        lock.unlock()
    }

    private static func pruneUnsafe(
        _ items: [CoachAssistantConversation],
        calendar: Calendar
    ) -> [CoachAssistantConversation] {
        let dayKeys = Array(
            Set(items.map { $0.dayKey(calendar: calendar) })
        ).sorted(by: >)
        guard dayKeys.count > retentionDayCount else { return items }
        let keep = Set(dayKeys.prefix(retentionDayCount))
        return items.filter { keep.contains($0.dayKey(calendar: calendar)) }
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

    private static func loadUnsafe() -> [CoachAssistantConversation] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([CoachAssistantConversation].self, from: data)) ?? []
    }

    private static func saveUnsafe(_ items: [CoachAssistantConversation]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
