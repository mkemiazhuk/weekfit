import Foundation

/// Privacy-preserving soft behavioral signals for Phase 1.5/v2 (no health values).
enum ProposalBehavioralPreferences {

    private static let storageKey = "coach.proposalBehavioral.v1"
    private static let generationKey = "coach.proposalBehavioral.generation"
    private static let minSamplesForPenalty = 3
    private static let maxWalkRejectPenalty = 12
    private static let lock = NSLock()

    struct Snapshot: Codable, Sendable, Equatable {
        var softDismissCount: Int
        var emptyApplyCount: Int
        var walkRejectCount: Int
        var walkAcceptCount: Int
        var deselectCounts: [String: Int]
        var updatedAt: Date

        static let empty = Snapshot(
            softDismissCount: 0,
            emptyApplyCount: 0,
            walkRejectCount: 0,
            walkAcceptCount: 0,
            deselectCounts: [:],
            updatedAt: .distantPast
        )
    }

    static var generation: Int {
        UserDefaults.standard.integer(forKey: generationKey)
    }

    static func bumpGeneration() {
        UserDefaults.standard.set(generation + 1, forKey: generationKey)
    }

    static func load() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()
    }

    static func recordSoftDismiss() {
        mutate { snapshot in
            snapshot.softDismissCount += 1
            snapshot.updatedAt = Date()
        }
        // Terminal outcome — safe to invalidate future generation fingerprints.
        bumpGeneration()
    }

    static func recordEmptyApply() {
        mutate { snapshot in
            snapshot.emptyApplyCount += 1
            snapshot.updatedAt = Date()
        }
        bumpGeneration()
    }

    /// Records a deselect during Review. Does **not** bump fingerprint generation —
    /// mid-review toggles must not stale/orphan the open proposal before Apply.
    static func recordDeselect(kind: CoachChangeKind, reason: CoachProposalReasonCode) {
        mutate { snapshot in
            let key = "\(kind.rawValue)|\(reason.rawValue)"
            snapshot.deselectCounts[key, default: 0] += 1
            if kind == .createRecoveryWalk {
                snapshot.walkRejectCount += 1
            }
            snapshot.updatedAt = Date()
        }
    }

    /// Records a Walk re-select during Review. Does not bump fingerprint generation.
    static func recordWalkAccept() {
        mutate { snapshot in
            snapshot.walkAcceptCount += 1
            snapshot.updatedAt = Date()
        }
    }

    /// Call after a successful Apply so the next morning proposal sees updated preferences.
    static func commitLearningGeneration() {
        bumpGeneration()
    }

    /// Coarse penalty 0...maxWalkRejectPenalty. Requires min samples; never bans safety dial-back.
    /// Applies a 45-day soft decay on older rejection history by requiring recency via updatedAt.
    static func walkRejectPenalty(from snapshot: Snapshot = load()) -> Int {
        let samples = snapshot.walkRejectCount + snapshot.walkAcceptCount
        guard samples >= minSamplesForPenalty else { return 0 }
        let ageDays = Calendar.current.dateComponents([.day], from: snapshot.updatedAt, to: Date()).day ?? 0
        let decayFactor: Double
        if ageDays <= 30 {
            decayFactor = 1.0
        } else if ageDays >= 45 {
            decayFactor = 0.35
        } else {
            decayFactor = 1.0 - (Double(ageDays - 30) / 15.0) * 0.65
        }
        let rejectRate = Double(snapshot.walkRejectCount) / Double(max(samples, 1))
        guard rejectRate >= 0.6 else { return 0 }
        let scaled = Int((rejectRate * Double(maxWalkRejectPenalty) * decayFactor).rounded())
        return min(maxWalkRejectPenalty, max(0, scaled))
    }

    static func stronglyRejectsWalk(from snapshot: Snapshot = load()) -> Bool {
        walkRejectPenalty(from: snapshot) >= 8
    }

    /// Soft confidence drag from repeated dismiss / empty Apply (capped, never overrides safety).
    static func softNegativePenalty(from snapshot: Snapshot = load()) -> Int {
        let dismissSamples = snapshot.softDismissCount + snapshot.emptyApplyCount
        guard dismissSamples >= minSamplesForPenalty else { return 0 }
        return min(6, dismissSamples)
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: generationKey)
        lock.unlock()
    }
    #endif

    private static func mutate(_ body: (inout Snapshot) -> Void) {
        lock.lock()
        var snapshot = loadUnsafe()
        body(&snapshot)
        saveUnsafe(snapshot)
        lock.unlock()
    }

    private static func loadUnsafe() -> Snapshot {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    private static func saveUnsafe(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
