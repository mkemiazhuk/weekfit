import Foundation

/// Day-scoped in-memory map over applied Coach adjustments.
/// Avoids decoding UserDefaults once per Plan / Up Next row.
enum CoachProvenanceLookupCache {

    private static let lock = NSLock()
    private static var dayKey: String?
    private static var byActivityId: [String: AppliedCoachAdjustment] = [:]
    private static var generation: UInt64 = 0

    /// Call after apply / manual-edit / purge so views refresh from storage.
    static func invalidate() {
        lock.lock()
        dayKey = nil
        byActivityId = [:]
        generation &+= 1
        lock.unlock()
    }

    @discardableResult
    static func ensureLoaded(dayKey: String) -> UInt64 {
        lock.lock()
        if Self.dayKey != dayKey {
            Self.dayKey = dayKey
            byActivityId = CoachAdjustmentProvenanceStore.lookupByActivityId(forDayKey: dayKey)
        }
        let value = generation
        lock.unlock()
        return value
    }

    static func adjustment(forActivityId id: String, dayKey: String) -> AppliedCoachAdjustment? {
        ensureLoaded(dayKey: dayKey)
        lock.lock()
        if let cached = byActivityId[id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Cross-day moves / created items: fall back to global id lookup once.
        if let fallback = CoachAdjustmentProvenanceStore.adjustment(forActivityId: id) {
            lock.lock()
            byActivityId[id] = fallback
            lock.unlock()
            return fallback
        }
        return nil
    }

    #if DEBUG
    static func resetAllForTests() {
        invalidate()
    }
    #endif
}

enum CoachProvenanceCopy {
    static func compactLabel(for kind: CoachChangeKind) -> String {
        switch kind {
        case .createRecoveryWalk, .createPlannedActivity, .createMealFromLibrary:
            return WeekFitLocalizedString("coach.provenance.addedByCoach")
        case .skipActivity, .modifyDuration, .moveActivity, .guidanceOnly:
            return WeekFitLocalizedString("coach.provenance.adjustedByCoach")
        }
    }

    static func accessibilityLabel(for kind: CoachChangeKind) -> String {
        compactLabel(for: kind)
    }

    static func detailTitle(for kind: CoachChangeKind) -> String {
        switch kind {
        case .createRecoveryWalk, .createPlannedActivity, .createMealFromLibrary:
            return WeekFitLocalizedString("coach.provenance.detail.addedTitle")
        default:
            return WeekFitLocalizedString("coach.provenance.detail.adjustedTitle")
        }
    }
}
