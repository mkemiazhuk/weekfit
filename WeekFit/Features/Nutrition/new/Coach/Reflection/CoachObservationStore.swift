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
    static func recordToday(
        from healthManager: HealthManager,
        date: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil
    ) {
        guard healthManager.isHealthAccessRequested else { return }

        let sleepMinutes = healthManager.sleepMinutes
        guard sleepMinutes > 0 else { return }

        let recoveryPercent = healthManager.recoveryBreakdown.total > 0
            ? healthManager.recoveryBreakdown.total
            : Int(healthManager.readyScore.rounded())

        let bedStartMinutes = healthManager.bedStart.map {
            RecoveryScoreEngine.normalizedBedtimeMinutes($0)
        }

        let dayActivities = DailyStateSnapshotBuilder.activities(on: date, from: plannedActivities)
        let healthSnapshot: NutritionMetricsSnapshot? = {
            guard healthManager.isHealthAccessGranted else { return nil }
            return NutritionMetricsSnapshot(
                protein: healthManager.protein,
                carbs: healthManager.carbs,
                fats: healthManager.fats,
                calories: healthManager.calories,
                waterLiters: healthManager.waterLiters,
                mealsLoggedCount: CoachNutritionObservationMapper.mealsLoggedCount(
                    for: date,
                    plannedActivities: dayActivities
                ),
                isResolved: true
            )
        }()

        upsert(
            CoachObservationAssembler.makeObservation(
                dayKey: CoachDailyObservation.dayKey(for: date),
                sleepMinutes: sleepMinutes,
                recoveryPercent: recoveryPercent,
                bedStartNormalizedMinutes: bedStartMinutes,
                metrics: healthManager.cachedCoachActivityMetricsSnapshot,
                workouts: [],
                trainingDataAvailable: true,
                healthNutritionSnapshot: healthSnapshot,
                plannedActivities: dayActivities.coachSnapshots(),
                calorieTarget: calorieTarget,
                nutritionDataAvailable: healthManager.isHealthAccessGranted || !dayActivities.isEmpty
            )
        )
    }

    @MainActor
    static func backfill(
        healthManager: HealthManager,
        through endDate: Date,
        plannedActivities: [PlannedActivity] = [],
        calorieTarget: Int? = nil,
        dayCount: Int = 21
    ) async {
        guard healthManager.isHealthAccessRequested else { return }

        let calendar = Calendar.current
        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: endDate)) else {
                continue
            }

            let dayKey = CoachDailyObservation.dayKey(for: date)
            let existing = observation(for: dayKey)
            let dayPlannedActivities = DailyStateSnapshotBuilder.activities(on: date, from: plannedActivities)

            if let existing,
               existing.hasSleepSignal,
               existing.hasPopulatedTrainingFields,
               existing.hasPopulatedNutritionFieldsResolved {
                continue
            }

            async let metrics = healthManager.readActivityMetrics(for: date)
            async let sleepSnapshot = healthManager.loadRecoverySleepSnapshot(for: date)
            async let workouts = healthManager.loadWorkoutSamples(for: date)
            async let nutritionSnapshot = healthManager.readNutritionMetricsSnapshot(
                for: date,
                plannedActivities: dayPlannedActivities
            )

            let loadedMetrics = await metrics
            let loadedSleep = await sleepSnapshot
            let loadedWorkouts = CoachWorkoutObservationMapper.samples(from: await workouts)
            let loadedNutrition = await nutritionSnapshot

            let sleepMinutes: Int
            let recoveryPercent: Int
            let bedStartMinutes: Int?

            if let existing, existing.hasSleepSignal {
                sleepMinutes = existing.sleepMinutes
                recoveryPercent = existing.recoveryPercent
                bedStartMinutes = existing.bedStartNormalizedMinutes
            } else {
                guard loadedMetrics.sleepMinutes > 0 else { continue }
                sleepMinutes = loadedMetrics.sleepMinutes
                recoveryPercent = loadedMetrics.recoveryPercent
                bedStartMinutes = loadedSleep.bedStart.map {
                    RecoveryScoreEngine.normalizedBedtimeMinutes($0)
                }
            }

            upsert(
                CoachObservationAssembler.makeObservation(
                    dayKey: dayKey,
                    sleepMinutes: sleepMinutes,
                    recoveryPercent: recoveryPercent,
                    bedStartNormalizedMinutes: bedStartMinutes,
                    metrics: loadedMetrics,
                    workouts: loadedWorkouts,
                    trainingDataAvailable: true,
                    healthNutritionSnapshot: loadedNutrition,
                    plannedActivities: dayPlannedActivities.coachSnapshots(),
                    calorieTarget: calorieTarget,
                    nutritionDataAvailable: loadedNutrition?.isResolved == true
                        || !dayPlannedActivities.isEmpty
                )
            )
        }
    }

    static func clearAll() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: storageKey)
        lock.unlock()
    }

    #if DEBUG
    static func resetForTests() {
        clearAll()
    }

    static func seedForTests(_ observations: [CoachDailyObservation]) {
        lock.lock()
        var stored: [String: CoachDailyObservation] = [:]
        for observation in observations {
            stored[observation.dayKey] = observation
        }
        saveUnsafe(stored)
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

@MainActor
extension HealthManager {
    var cachedCoachActivityMetricsSnapshot: ActivityMetricsSnapshot {
        ActivityMetricsSnapshot(
            activeCalories: activeCalories,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount,
            distanceKm: distanceKm,
            standHours: standHours,
            vo2Max: cardioFitnessVO2,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            coreSleepMinutes: coreSleepMinutes,
            restingHeartRate: restingHeartRate,
            hrvSDNN: hrvSDNN
        )
    }
}
