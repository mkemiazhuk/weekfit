import Foundation

enum CoachObservationStore {

    private static let storageKey = "coach.dailyObservations.v1"
    private static let lock = NSLock()

    static func allObservations() -> [CoachDailyObservation] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe().values.sorted { $0.dayKey < $1.dayKey }
    }

    static func observation(for dayKey: String) -> CoachDailyObservation? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()[dayKey]
    }

    static func upsert(_ observation: CoachDailyObservation) {
        lock.lock()
        var stored = loadUnsafe()
        stored[observation.dayKey] = observation
        saveUnsafe(stored)
        lock.unlock()
    }

    @MainActor
    static func recordToday(from healthManager: HealthManager, date: Date) {
        guard healthManager.isHealthAccessRequested else { return }

        let sleepMinutes = healthManager.sleepMinutes
        guard sleepMinutes > 0 else { return }

        let recoveryPercent = healthManager.recoveryBreakdown.total > 0
            ? healthManager.recoveryBreakdown.total
            : Int(healthManager.readyScore.rounded())

        let bedStartMinutes = healthManager.bedStart.map {
            RecoveryScoreEngine.normalizedBedtimeMinutes($0)
        }

        upsert(
            CoachDailyObservation(
                dayKey: CoachDailyObservation.dayKey(for: date),
                sleepMinutes: sleepMinutes,
                recoveryPercent: recoveryPercent,
                bedStartNormalizedMinutes: bedStartMinutes
            )
        )
    }

    @MainActor
    static func backfill(
        healthManager: HealthManager,
        through endDate: Date,
        dayCount: Int = 21
    ) async {
        guard healthManager.isHealthAccessRequested else { return }

        let calendar = Calendar.current
        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: endDate)) else {
                continue
            }

            let dayKey = CoachDailyObservation.dayKey(for: date)
            if observation(for: dayKey) != nil {
                continue
            }

            async let metrics = healthManager.readActivityMetrics(for: date)
            async let sleepSnapshot = healthManager.loadRecoverySleepSnapshot(for: date)
            let loadedMetrics = await metrics
            let loadedSleep = await sleepSnapshot

            guard loadedMetrics.sleepMinutes > 0 else { continue }

            let bedStartMinutes = loadedSleep.bedStart.map {
                RecoveryScoreEngine.normalizedBedtimeMinutes($0)
            }

            upsert(
                CoachDailyObservation(
                    dayKey: dayKey,
                    sleepMinutes: loadedMetrics.sleepMinutes,
                    recoveryPercent: loadedMetrics.recoveryPercent,
                    bedStartNormalizedMinutes: bedStartMinutes
                )
            )
        }
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }
    #endif

    private static func loadUnsafe() -> [String: CoachDailyObservation] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: CoachDailyObservation].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveUnsafe(_ observations: [String: CoachDailyObservation]) {
        guard let data = try? JSONEncoder().encode(observations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
