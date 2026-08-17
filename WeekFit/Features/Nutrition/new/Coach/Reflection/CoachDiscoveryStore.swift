import Foundation

enum CoachDiscoveryStore {

    private static let storageKey = "coach.discoveries.v1"
    private static let lock = NSLock()

    static func allDiscoveries() -> [CoachDiscovery] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().discoveries.values.sorted { $0.firstLearnedAt < $1.firstLearnedAt }
    }

    static func activeDiscoveries() -> [CoachDiscovery] {
        allDiscoveries().filter { $0.status == .active }
    }

    static func discovery(for beliefID: CoachBeliefID) -> CoachDiscovery? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().discoveries[beliefID.rawValue]
    }

    static func nextOffer() -> CoachDiscoveryOffer? {
        lock.lock()
        defer { lock.unlock() }
        let snapshot = loadUnsafe()
        return snapshot.pendingOffers.first { !snapshot.consumedOfferIDs.contains($0.id) }
    }

    static func pendingOffersSnapshot() -> [CoachDiscoveryOffer] {
        lock.lock()
        defer { lock.unlock() }
        let snapshot = loadUnsafe()
        return snapshot.pendingOffers.filter { !snapshot.consumedOfferIDs.contains($0.id) }
    }

    static func upsert(_ discovery: CoachDiscovery) {
        lock.lock()
        var snapshot = loadUnsafe()
        snapshot.discoveries[discovery.id] = discovery
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func enqueueOffer(_ offer: CoachDiscoveryOffer) {
        lock.lock()
        var snapshot = loadUnsafe()
        guard !snapshot.consumedOfferIDs.contains(offer.id) else {
            lock.unlock()
            return
        }
        snapshot.pendingOffers.removeAll { $0.id == offer.id }
        snapshot.pendingOffers.append(offer)
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func markOfferConsumed(_ offerID: String) {
        lock.lock()
        var snapshot = loadUnsafe()
        snapshot.consumedOfferIDs.insert(offerID)
        snapshot.pendingOffers.removeAll { $0.id == offerID }
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func markSeen(beliefID: CoachBeliefID, at date: Date = Date()) {
        lock.lock()
        var snapshot = loadUnsafe()
        guard var discovery = snapshot.discoveries[beliefID.rawValue] else {
            lock.unlock()
            return
        }
        discovery.hasBeenSeenByUser = true
        discovery.lastSeenByUserAt = date
        discovery.lastSurfacedAt = date
        discovery.timesSurfaced += 1
        snapshot.discoveries[beliefID.rawValue] = discovery
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func markOfferDisplayed(_ offer: CoachDiscoveryOffer, at date: Date = Date()) {
        markOfferConsumed(offer.id)
        markSeen(beliefID: offer.beliefID, at: date)
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }

    static func seedForTests(
        discoveries: [CoachDiscovery] = [],
        pendingOffers: [CoachDiscoveryOffer] = [],
        consumedOfferIDs: Set<String> = []
    ) {
        lock.lock()
        var snapshot = Snapshot()
        for discovery in discoveries {
            snapshot.discoveries[discovery.id] = discovery
        }
        snapshot.pendingOffers = pendingOffers
        snapshot.consumedOfferIDs = consumedOfferIDs
        saveUnsafe(snapshot)
        lock.unlock()
    }

    static func consumedOfferIDsForTests() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().consumedOfferIDs
    }
    #endif

    private struct Snapshot: Codable {
        var discoveries: [String: CoachDiscovery]
        var pendingOffers: [CoachDiscoveryOffer]
        var consumedOfferIDs: Set<String>

        init(
            discoveries: [String: CoachDiscovery] = [:],
            pendingOffers: [CoachDiscoveryOffer] = [],
            consumedOfferIDs: Set<String> = []
        ) {
            self.discoveries = discoveries
            self.pendingOffers = pendingOffers
            self.consumedOfferIDs = consumedOfferIDs
        }
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
}
