import Foundation

enum CoachUnderstandingStore {

    private static let storageKey = "coach.understanding.v1"
    private static let lock = NSLock()

    static func belief(for id: CoachBeliefID) -> CoachBelief {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().beliefs[beliefIDKey(id)] ?? defaultBelief(for: id)
    }

    static func nextUnspokenEvent() -> UnderstandingEvent? {
        lock.lock()
        defer { lock.unlock() }
        let snapshot = loadUnsafe()
        return snapshot.pendingEvents.first { !snapshot.spokenEventIDs.contains($0.id) }
    }

    static func markSpoken(_ eventID: String) {
        lock.lock()
        var snapshot = loadUnsafe()
        snapshot.spokenEventIDs.insert(eventID)
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func applyEvaluation(
        beliefID: CoachBeliefID,
        nextMaturity: CoachBeliefMaturity,
        event: UnderstandingEvent?
    ) {
        lock.lock()
        var snapshot = loadUnsafe()
        var belief = snapshot.beliefs[beliefIDKey(beliefID)] ?? defaultBelief(for: beliefID)

        if nextMaturity != belief.maturity {
            belief.maturity = nextMaturity
            belief.lastUpdated = Date()
            snapshot.beliefs[beliefIDKey(beliefID)] = belief
        }

        if let event, !snapshot.spokenEventIDs.contains(event.id) {
            snapshot.pendingEvents.removeAll { $0.id == event.id }
            snapshot.pendingEvents.append(event)
        }

        saveUnsafe(snapshot)
        lock.unlock()
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
        CoachObservationStore.resetForTests()
    }

    static func seedForTests(
        belief: CoachBelief,
        pendingEvents: [UnderstandingEvent] = [],
        spokenEventIDs: Set<String> = []
    ) {
        lock.lock()
        var snapshot = Snapshot()
        snapshot.beliefs[beliefIDKey(belief.id)] = belief
        snapshot.pendingEvents = pendingEvents
        snapshot.spokenEventIDs = spokenEventIDs
        saveUnsafe(snapshot)
        lock.unlock()
    }
    #endif

    private struct Snapshot: Codable {
        var beliefs: [String: CoachBelief]
        var pendingEvents: [UnderstandingEvent]
        var spokenEventIDs: Set<String>

        init(
            beliefs: [String: CoachBelief] = [:],
            pendingEvents: [UnderstandingEvent] = [],
            spokenEventIDs: Set<String> = []
        ) {
            self.beliefs = beliefs
            self.pendingEvents = pendingEvents
            self.spokenEventIDs = spokenEventIDs
        }
    }

    private static func defaultBelief(for id: CoachBeliefID) -> CoachBelief {
        CoachBelief(id: id, maturity: .watching, lastUpdated: .distantPast)
    }

    private static func loadUnsafe() -> Snapshot {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot()
        }
        return decoded
    }

    private static func saveUnsafe(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func beliefIDKey(_ id: CoachBeliefID) -> String {
        id.rawValue
    }
}
