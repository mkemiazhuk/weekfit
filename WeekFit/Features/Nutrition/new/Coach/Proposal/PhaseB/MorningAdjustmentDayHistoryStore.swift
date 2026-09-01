import Foundation

enum MorningAdjustmentDayHistoryStore {

    private static let storageKey = "coach.morningAdjustmentDayHistory.v1"
    static let retentionDays = 90
    private static let lock = NSLock()

    static func record(for dayKey: String) -> MorningAdjustmentDayRecord? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()[dayKey]
    }

    static func allRecords(excludingDayKey: String? = nil) -> [MorningAdjustmentDayRecord] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().values
            .filter { excludingDayKey == nil || $0.dayKey != excludingDayKey }
            .sorted { $0.dayKey < $1.dayKey }
    }

    static func upsert(_ record: MorningAdjustmentDayRecord) {
        lock.lock()
        var stored = loadUnsafe()
        if var existing = stored[record.dayKey] {
            existing.recordedAt = record.recordedAt
            for (familyRaw, outcome) in record.movementOutcomesRaw {
                var merged = existing.movementOutcomesRaw[familyRaw] ?? MovementFamilyOutcome()
                mergeOutcome(into: &merged, from: outcome)
                existing.movementOutcomesRaw[familyRaw] = merged
            }
            stored[record.dayKey] = existing
        } else {
            stored[record.dayKey] = record
        }
        saveUnsafe(stored)
        lock.unlock()
    }

    static func merge(
        dayKey: String,
        mutate: (inout MorningAdjustmentDayRecord) -> Void
    ) {
        lock.lock()
        var stored = loadUnsafe()
        var record = stored[dayKey] ?? MorningAdjustmentDayRecord.placeholder(dayKey: dayKey)
        mutate(&record)
        record.recordedAt = Date()
        stored[dayKey] = record
        saveUnsafe(stored)
        lock.unlock()
    }

    static func purgeOlderThan(referenceDate: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: referenceDate) else {
            return
        }
        let cutoffKey = ProposalInputFingerprintBuilder.dayKey(for: cutoff, calendar: calendar)
        lock.lock()
        let retained = loadUnsafe().filter { $0.key >= cutoffKey }
        saveUnsafe(retained)
        lock.unlock()
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }

    static func seedForTests(_ records: [MorningAdjustmentDayRecord]) {
        lock.lock()
        var stored: [String: MorningAdjustmentDayRecord] = [:]
        for record in records {
            stored[record.dayKey] = record
        }
        saveUnsafe(stored)
        lock.unlock()
    }
    #endif

    private static func mergeOutcome(into target: inout MovementFamilyOutcome, from source: MovementFamilyOutcome) {
        target.offered = target.offered || source.offered
        target.defaultSelected = target.defaultSelected || source.defaultSelected
        target.selectedAtSettle = target.selectedAtSettle || source.selectedAtSettle
        target.applied = target.applied || source.applied
        target.explicitlyRejected = target.explicitlyRejected || source.explicitlyRejected
        target.completed = target.completed || source.completed
        target.partialCompletion = target.partialCompletion || source.partialCompletion
        if let duration = source.durationMinutes { target.durationMinutes = duration }
        if let completed = source.completedDurationMinutes { target.completedDurationMinutes = completed }
        if let hour = source.scheduledHour { target.scheduledHour = hour }
        if let activityId = source.provenanceActivityId { target.provenanceActivityId = activityId }
        if let changeId = source.provenanceChangeId { target.provenanceChangeId = changeId }
        if let origin = source.origin { target.origin = origin }
    }

    private static func loadUnsafe() -> [String: MorningAdjustmentDayRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: MorningAdjustmentDayRecord].self, from: data)) ?? [:]
    }

    private static func saveUnsafe(_ stored: [String: MorningAdjustmentDayRecord]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private extension MorningAdjustmentDayRecord {
    static func placeholder(dayKey: String) -> MorningAdjustmentDayRecord {
        MorningAdjustmentDayRecord(
            dayKey: dayKey,
            recordedAt: Date(),
            weekday: 1,
            isWeekend: false,
            proposalTimeBucket: .morning,
            recoveryPercent: nil,
            recoveryBand: .unavailable,
            strategy: .recover,
            outdoorSuitability: .acceptable,
            weatherRiskToken: .unavailable,
            yesterdayHeavy: false,
            previousDayLoad: .unknown,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            existingPlanSuitability: .none,
            hadMorningProposal: false
        )
    }
}
