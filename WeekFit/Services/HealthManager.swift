import Foundation
import CoreLocation
import HealthKit
internal import Combine

struct WorkoutHeartRateSample: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let beatsPerMinute: Double
}

struct WorkoutRoutePoint: Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
}

struct WorkoutHealthDetailSnapshot: Hashable {
    let source: String?
    let activeCalories: Double?
    let distanceKm: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let heartRateSamples: [WorkoutHeartRateSample]
    let routePoints: [WorkoutRoutePoint]
    let elevationGain: Double?
    let steps: Int?
    let cadence: Double?
}

struct ActivityMetricsSnapshot: Hashable {
    let activeCalories: Double
    let steps: Int
    let exerciseMinutes: Int

    let sleepMinutes: Int
    let timeInBedMinutes: Int
    let awakeMinutes: Int
    let awakeningsCount: Int

    let distanceKm: Double
    let standHours: Int
    let vo2Max: Double

    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let coreSleepMinutes: Int

    let restingHeartRate: Double
    let hrvSDNN: Double

    var sleepHours: Double {
        Double(sleepMinutes) / 60.0
    }

    var sleepScore: Int {
        guard sleepMinutes > 0 else { return 0 }

        let durationScore = min(Double(sleepMinutes) / 480.0, 1.0) * 45
        let deepRatio = Double(deepSleepMinutes) / Double(max(sleepMinutes, 1))
        let deepScore = min(deepRatio / 0.18, 1.0) * 20
        let remRatio = Double(remSleepMinutes) / Double(max(sleepMinutes, 1))
        let remScore = min(remRatio / 0.22, 1.0) * 20
        let awakePenalty = min(Double(awakeMinutes) / 60.0, 1.0) * 8
        let wakePenalty = min(Double(awakeningsCount) / 6.0, 1.0) * 7

        return Int(max(0, min(100, durationScore + deepScore + remScore + 15 - awakePenalty - wakePenalty)).rounded())
    }

    var recoveryBreakdown: RecoveryScoreBreakdown {
        RecoveryScoreEngine.calculate(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            hrvSDNN: hrvSDNN,
            restingHeartRate: restingHeartRate
        )
    }

    var recoveryPercent: Int {
        recoveryBreakdown.total
    }

    static let empty = ActivityMetricsSnapshot(
        activeCalories: 0,
        steps: 0,
        exerciseMinutes: 0,
        sleepMinutes: 0,
        timeInBedMinutes: 0,
        awakeMinutes: 0,
        awakeningsCount: 0,
        distanceKm: 0,
        standHours: 0,
        vo2Max: 0,
        deepSleepMinutes: 0,
        remSleepMinutes: 0,
        coreSleepMinutes: 0,
        restingHeartRate: 0,
        hrvSDNN: 0
    )
}


struct RecoverySleepSnapshot: Hashable {
    let sleepMinutes: Int
    let timeInBedMinutes: Int
    let awakeMinutes: Int
    let awakeningsCount: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let coreSleepMinutes: Int
    let bedStart: Date?
    let wakeTime: Date?

    static let empty = RecoverySleepSnapshot(
        sleepMinutes: 0,
        timeInBedMinutes: 0,
        awakeMinutes: 0,
        awakeningsCount: 0,
        deepSleepMinutes: 0,
        remSleepMinutes: 0,
        coreSleepMinutes: 0,
        bedStart: nil,
        wakeTime: nil
    )
}

@MainActor
final class HealthManager: ObservableObject {

    @Published var isHealthAccessGranted = false

    @Published var activeCalories: Double = 0
    @Published var steps: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var sleepMinutes: Int = 0
    @Published var distanceKm: Double = 0
    
    @Published var standHours: Int = 0
    @Published var cardioFitnessVO2: Double = 0

    @Published var deepSleepMinutes: Int = 0
    @Published var remSleepMinutes: Int = 0
    @Published var coreSleepMinutes: Int = 0
    @Published var timeInBedMinutes: Int = 0
    @Published var awakeMinutes: Int = 0
    @Published var awakeningsCount: Int = 0
    @Published var recoveryBreakdown: RecoveryScoreBreakdown = .empty
    @Published var restingHeartRate: Double = 0
    @Published var hrvSDNN: Double = 0

    @Published var readyScore: Double = 0
    @Published var energyStatus: String = "—"
    @Published var recoveryStatus: String = "—"
    @Published var sleepText: String = "—"
    @Published var bestTimeText = WeekFitLocalizedString("health.syncHealthToPersonalizeYourDay")

    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fats: Double = 0
    @Published var fiber: Double = 0
    @Published var calories: Double = 0
    @Published var waterLiters: Double = 0
    @Published var sleepHours: Double = 0

    @Published var weight: Double = 0
    @Published var heightCm: Double = 0
    @Published var age: Int = 0
    @Published var biologicalSex: BiologicalSex = .unknown
    
    @Published var isRecoveryLoading: Bool = false

    private let healthStore = HKHealthStore()
    private let healthAccessRequestedKey = "weekfit.healthAccessRequested"
    
    
    func automatedActivityGoal(for metrics: ActivityMetricsSnapshot) -> Double {
        max(
            ActivityGoalEngine.calculate(
                weightKg: weight,
                heightCm: heightCm,
                age: age,
                sex: biologicalSex,
                recoveryPercent: metrics.recoveryPercent,
                sleepHours: metrics.sleepHours,
                vo2Max: metrics.vo2Max
            ),
            1
        )
    }
    
    func readActivityMetrics(for date: Date) async -> ActivityMetricsSnapshot {
        guard isHealthAccessRequested else {
            return .empty
        }

        async let calories = readDaySum(.activeEnergyBurned, unit: .kilocalorie(), for: date)
        async let stepsCount = readDaySum(.stepCount, unit: .count(), for: date)
        async let distanceMeters = readDaySum(.distanceWalkingRunning, unit: .meter(), for: date)
        async let exercise = readDaySum(.appleExerciseTime, unit: .minute(), for: date)
        async let sleepSnapshot = readRecoverySleepSnapshot(for: date)
        async let stand = readStandHours(for: date)
        async let vo2 = readLatestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"))

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 14, to: dayStart) ?? dayStart

        async let hrv = readLatestQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            start: sleepStart,
            end: sleepEnd
        )

        async let rhr = readLatestQuantity(
            .restingHeartRate,
            unit: .count().unitDivided(by: .minute()),
            start: sleepStart,
            end: sleepEnd
        )

        let loadedSleepSnapshot = await sleepSnapshot

        return ActivityMetricsSnapshot(
            activeCalories: await calories,
            steps: Int(await stepsCount),
            exerciseMinutes: Int(await exercise),

            sleepMinutes: loadedSleepSnapshot.sleepMinutes,
            timeInBedMinutes: loadedSleepSnapshot.timeInBedMinutes,
            awakeMinutes: loadedSleepSnapshot.awakeMinutes,
            awakeningsCount: loadedSleepSnapshot.awakeningsCount,

            distanceKm: await distanceMeters / 1000.0,
            standHours: await stand,
            vo2Max: await vo2,

            deepSleepMinutes: loadedSleepSnapshot.deepSleepMinutes,
            remSleepMinutes: loadedSleepSnapshot.remSleepMinutes,
            coreSleepMinutes: loadedSleepSnapshot.coreSleepMinutes,

            restingHeartRate: await rhr,
            hrvSDNN: await hrv
        )
    }
    
    var isHealthAccessRequested: Bool {
        UserDefaults.standard.bool(forKey: healthAccessRequestedKey)
    }

    func requestAuthorization(
        for date: Date = Date(),
        plannedActivities: [PlannedActivity] = []
    ) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isHealthAccessGranted = false
            resetHealthDependentValues()
//            print("❌ Health data is not available")
            return
        }

        guard let readTypes = makeReadTypes() else {
            isHealthAccessGranted = false
            resetHealthDependentValues()
//            print("❌ Failed to create HealthKit types")
            return
        }

        do {
//            print("🟡 Requesting HealthKit authorization...")

            try await healthStore.requestAuthorization(
                toShare: [],
                read: readTypes
            )

            UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
            isHealthAccessGranted = self.isAuthorized

//            print("✅ HealthKit authorization request completed. Granted: \(isHealthAccessGranted)")

            try? await Task.sleep(nanoseconds: 800_000_000)

            await loadHealthData(
                for: date,
                plannedActivities: plannedActivities
            )
            
            NotificationCenter.default.post(
                name: .healthAccessDidChange,
                object: nil
            )

        } catch {
            isHealthAccessGranted = false
            resetHealthDependentValues()
//            print("❌ HealthKit authorization failed:", error.localizedDescription)
        }
    }
    
    var isAuthorized: Bool {
        guard let activeCaloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return false
        }
        let status = healthStore.authorizationStatus(for: activeCaloriesType)
        return status == .sharingAuthorized
    }

    // MARK: - Исправленный метод в HealthManager.swift
    func loadHealthData(
        for date: Date = Date(),
        plannedActivities: [PlannedActivity] = []
    ) async {
        // 1. Базовая проверка: включен ли вообще HealthKit на девайсе и нажимал ли юзер кнопку ранее
        guard HKHealthStore.isHealthDataAvailable() && isHealthAccessRequested else {
            await MainActor.run {
                self.isHealthAccessGranted = false
                self.resetHealthDependentValues()
            }
            return
        }

        // 2. Пробиваем реальный статус чтения через наш новый метод микро-запроса
        let actualAccessGranted = await checkReadAuthorizationStatus()

        // 3. Переносим публикацию флага на MainActor, чтобы UI мгновенно перестроился
        await MainActor.run {
            self.isHealthAccessGranted = actualAccessGranted
        }

        // 4. Если доступ действительно есть — загружаем метрики
        if actualAccessGranted {
            await loadUserProfile()
            await loadHeaderMetrics(for: date)
            await loadNutritionMetrics(for: date, plannedActivities: plannedActivities)
        } else {
            // Если галочки были сняты — сбрасываем интерфейс
            await MainActor.run {
                self.resetHealthDependentValues()
            }
        }
    }

    func updateAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isHealthAccessGranted = false
            notifyHealthChanged()
            return
        }

        isHealthAccessGranted = self.isAuthorized
        notifyHealthChanged()
    }
    
    private func notifyHealthChanged() {
        NotificationCenter.default.post(
            name: .healthAccessDidChange,
            object: nil
        )
    }

    private func makeReadTypes() -> Set<HKObjectType>? {
        guard
            let activeCalories = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let fats = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            let dietaryFiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
            let foodCalories = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
            let weight = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let height = HKObjectType.quantityType(forIdentifier: .height),
            let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            let stand = HKObjectType.categoryType(forIdentifier: .appleStandHour),
            let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max)
        else {
            return nil
        }

        // Характеристики извлекаем безопасно, так как они могут возвращать nil на старых iOS
        let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex)
        let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)

        var types: Set<HKObjectType> = [
            activeCalories, steps, distance, exercise, heartRate, sleep,
            protein, carbs, fats, dietaryFiber, foodCalories, water, weight, height,
            hrv, restingHR, stand, vo2Max,
            HKObjectType.workoutType()
        ]
        types.insert(HKSeriesType.workoutRoute())

        // Добавляем характеристики в коллекцию только если они успешно создались
        if let bioSex = biologicalSex { types.insert(bioSex) }
        if let dob = dateOfBirth { types.insert(dob) }

        return types
    }

    func loadUserProfile() async {
        guard isHealthAccessGranted else {
            resetProfileValues()
            return
        }

        async let heightMeters = readLatestQuantity(.height, unit: .meter())
        async let weightKg = readLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))

        let loadedHeight = await heightMeters * 100
        let loadedWeight = await weightKg

        heightCm = loadedHeight
        weight = loadedWeight
        age = readAge()
        biologicalSex = readBiologicalSex()
    }

    func loadHeaderMetrics(for date: Date = Date()) async {
        guard isHealthAccessGranted else {
            resetHeaderValues()
            return
        }

        async let calories = readDaySum(.activeEnergyBurned, unit: .kilocalorie(), for: date)
        async let stepsCount = readDaySum(.stepCount, unit: .count(), for: date)
        async let distanceMeters = readDaySum(.distanceWalkingRunning, unit: .meter(), for: date)
        async let exercise = readDaySum(.appleExerciseTime, unit: .minute(), for: date)
        async let sleepSnapshot = readRecoverySleepSnapshot(for: date)
        async let stand = readStandHours(for: date)
        async let vo2 = readLatestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"))

        let hkCalories = await calories
        let hkSteps = Int(await stepsCount)
        let hkDistanceKm = await distanceMeters / 1000.0
        let hkExercise = Int(await exercise)
        let loadedSleepSnapshot = await sleepSnapshot
        let hkStand = await stand
        let hkVo2 = await vo2

        self.activeCalories = hkCalories
        self.steps = hkSteps
        self.distanceKm = hkDistanceKm
        self.exerciseMinutes = hkExercise

        self.sleepMinutes = loadedSleepSnapshot.sleepMinutes
        self.timeInBedMinutes = loadedSleepSnapshot.timeInBedMinutes
        self.awakeMinutes = loadedSleepSnapshot.awakeMinutes
        self.awakeningsCount = loadedSleepSnapshot.awakeningsCount
        self.deepSleepMinutes = loadedSleepSnapshot.deepSleepMinutes
        self.remSleepMinutes = loadedSleepSnapshot.remSleepMinutes
        self.coreSleepMinutes = loadedSleepSnapshot.coreSleepMinutes

        self.standHours = hkStand
        self.sleepHours = Double(self.sleepMinutes) / 60.0
        self.cardioFitnessVO2 = hkVo2
        
        self.isRecoveryLoading = true
        defer { self.isRecoveryLoading = false }

        await loadPremiumRecoveryMetrics(for: date)
        calculateHeaderMetrics()
    }
    
    // Внутри HealthManager.swift — замени старое свойство на этот метод:
    func checkReadAuthorizationStatus() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let activeCaloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return false }
        
        // Пробуем сделать микро-запрос на чтение одной верхней записи калорий
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: activeCaloriesType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if error != nil {
                    // Если система выдала ошибку доступа — авторизации точно нет
                    continuation.resume(returning: false)
                } else {
                    // Если запрос прошел успешно (даже если samples пустой) — доступ открыт!
                    continuation.resume(returning: true)
                }
            }
            self.healthStore.execute(query)
        }
    }

    func loadNutritionMetrics(
        for date: Date = Date(),
        plannedActivities: [PlannedActivity] = []
    ) async {
        guard isHealthAccessGranted else {
            let fallback = calculateNutritionFromPlannedMeals(plannedActivities, for: date)
            protein = fallback.protein
            carbs = fallback.carbs
            fats = fallback.fats
            fiber = fallback.fiber
            calories = fallback.calories
            waterLiters = plannedWaterIntake(from: plannedActivities, for: date)
            sleepHours = 0
            return
        }

        async let healthProtein = readDaySum(.dietaryProtein, unit: .gram(), for: date)
        async let healthCarbs = readDaySum(.dietaryCarbohydrates, unit: .gram(), for: date)
        async let healthFats = readDaySum(.dietaryFatTotal, unit: .gram(), for: date)
        async let healthFiber = readDaySum(.dietaryFiber, unit: .gram(), for: date)
        async let healthCalories = readDaySum(.dietaryEnergyConsumed, unit: .kilocalorie(), for: date)
        async let healthWaterMl = readDaySum(.dietaryWater, unit: .literUnit(with: .milli), for: date)

        let hkProtein = await healthProtein
        let hkCarbs = await healthCarbs
        let hkFats = await healthFats
        let hkFiber = await healthFiber
        let hkCalories = await healthCalories
        let hkWaterLiters = await healthWaterMl / 1000.0

        let hasHealthFood = hkProtein > 0 || hkCarbs > 0 || hkFats > 0 || hkFiber > 0 || hkCalories > 0

        if hasHealthFood {
            protein = hkProtein
            carbs = hkCarbs
            fats = hkFats
            fiber = hkFiber
            calories = hkCalories
        } else {
            let fallback = calculateNutritionFromPlannedMeals(plannedActivities, for: date)
            protein = fallback.protein
            carbs = fallback.carbs
            fats = fallback.fats
            fiber = fallback.fiber
            calories = fallback.calories
        }

        let plannedWaterLiters = plannedWaterIntake(from: plannedActivities, for: date)
        waterLiters = max(hkWaterLiters, plannedWaterLiters)
        sleepHours = Double(sleepMinutes) / 60.0
    }

    // MARK: - Recovery HRV / RHR
    func loadPremiumRecoveryMetrics(for date: Date) async {
        guard isHealthAccessGranted else { return }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 14, to: dayStart) ?? dayStart

        async let hrv = readLatestQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            start: sleepStart,
            end: sleepEnd
        )

        async let rhr = readLatestQuantity(
            .restingHeartRate,
            unit: .count().unitDivided(by: .minute()),
            start: sleepStart,
            end: sleepEnd
        )

        self.hrvSDNN = await hrv
        self.restingHeartRate = await rhr

        self.recoveryBreakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: self.sleepMinutes,
            timeInBedMinutes: self.timeInBedMinutes,
            awakeMinutes: self.awakeMinutes,
            awakeningsCount: self.awakeningsCount,
            deepSleepMinutes: self.deepSleepMinutes,
            remSleepMinutes: self.remSleepMinutes,
            hrvSDNN: self.hrvSDNN,
            restingHeartRate: self.restingHeartRate
        )
    }

    private func readStandHours(for date: Date) async -> Int {
        guard let standType = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return 0 }
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: standType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let standSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                // СТРОГОЕ ИСПРАВЛЕНО: Оставляем только те сэмплы, где value == 0 (HKCategoryValueAppleStandHour.stood)
                // Сэмплы с value == 1 (idle / сидение) теперь полностью игнорируются!
                let stoodSamples = standSamples.filter { sample in
                    return sample.value == 0 || sample.value == HKCategoryValueAppleStandHour.stood.rawValue
                }
                
                // Собираем уникальные часы
                let uniqueHours = Set(stoodSamples.map { sample in
                    calendar.component(.hour, from: sample.startDate)
                })
                
//                print("🕦 [Stand Debug] Реальные уникальные часы стояния: \(uniqueHours.count) -> \(uniqueHours.sorted())")
                
                continuation.resume(returning: uniqueHours.count)
            }
            self.healthStore.execute(query)
        }
    }

    private func readSleepPhases(for date: Date) async -> (deep: Int, rem: Int) {

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, 0)
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let sleepStart =
            calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart

        let sleepEnd =
            calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: []
        )

        return await withCheckedContinuation { continuation in

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in

                let sleepSamples = samples as? [HKCategorySample] ?? []

                let appleSamples = sleepSamples.filter {
                    $0.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple")
                }

                var deepMin = 0
                var remMin = 0

                for sample in appleSamples {

                    let minutes = Int(
                        sample.endDate.timeIntervalSince(sample.startDate) / 60
                    )

                    switch sample.value {

                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepMin += minutes

                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remMin += minutes

                    default:
                        break
                    }
                }

                continuation.resume(returning: (
                    deep: deepMin,
                    rem: remMin
                ))
            }

            self.healthStore.execute(query)
        }
    }
    
    private func resetHealthDependentValues() {
        resetProfileValues()
        resetHeaderValues()

        protein = 0
        carbs = 0
        fats = 0
        fiber = 0
        calories = 0
        waterLiters = 0
        sleepHours = 0
    }

    private func resetProfileValues() {
        weight = 0
        heightCm = 0
        age = 0
        biologicalSex = .unknown
    }

    private func resetHeaderValues() {
        activeCalories = 0
        steps = 0
        distanceKm = 0
        exerciseMinutes = 0
        sleepMinutes = 0
        sleepHours = 0
        
        standHours = 0
        cardioFitnessVO2 = 0

        deepSleepMinutes = 0
        remSleepMinutes = 0
        coreSleepMinutes = 0
        timeInBedMinutes = 0
        awakeMinutes = 0
        awakeningsCount = 0
        recoveryBreakdown = .empty
        restingHeartRate = 0
        hrvSDNN = 0

        readyScore = 0
        energyStatus = "—"
        recoveryStatus = "—"
        sleepText = "—"
        bestTimeText = WeekFitLocalizedString("health.syncHealthToPersonalizeYourDay")
    }

    private func readAge() -> Int {
        do {
            let components = try healthStore.dateOfBirthComponents()
            guard let birthDate = Calendar.current.date(from: components) else { return 0 }
            return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        } catch {
            return 0
        }
    }

    private func readBiologicalSex() -> BiologicalSex {
        do {
            let sex = try healthStore.biologicalSex().biologicalSex
            switch sex {
            case .male: return .male
            case .female: return .female
            default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private func readLatestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date? = nil,
        end: Date? = nil
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate: NSPredicate?

        if let start, let end {
            predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: []
            )
        } else {
            predicate = nil
        }

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in

                guard error == nil else {
                    continuation.resume(returning: 0)
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                let value = sample?.quantity.doubleValue(for: unit) ?? 0

                continuation.resume(returning: value)
            }

            self.healthStore.execute(query)
        }
    }

    private func readDaySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.isDateInToday(date) ? Date() : (calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if error != nil {
                    continuation.resume(returning: 0)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }

    private func readRecoverySleepSnapshot(for date: Date) async -> RecoverySleepSnapshot {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return .empty
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 14, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: []
        )

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: .empty)
                    return
                }

                let allSamples = samples as? [HKCategorySample] ?? []
                let appleSamples = allSamples.filter {
                    $0.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple")
                }

                let inBedSamples = appleSamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue
                }

                let awakeSamples = appleSamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.awake.rawValue
                }

                let asleepSamples = appleSamples.filter {
                    Self.isAnyAsleepValue($0.value)
                }

                let deepSamples = appleSamples.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    }
                    return false
                }

                let remSamples = appleSamples.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    return false
                }

                let coreSamples = appleSamples.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    }
                    return false
                }

                guard let session = Self.primarySleepSession(
                    inBedSamples: inBedSamples,
                    asleepSamples: asleepSamples
                ) else {
                    continuation.resume(returning: .empty)
                    return
                }

                let sessionStart = session.start
                let sessionEnd = session.end

                let filteredAsleep = Self.overlappingSamples(asleepSamples, start: sessionStart, end: sessionEnd)
                let filteredAwake = Self.overlappingSamples(awakeSamples, start: sessionStart, end: sessionEnd)
                let filteredDeep = Self.overlappingSamples(deepSamples, start: sessionStart, end: sessionEnd)
                let filteredREM = Self.overlappingSamples(remSamples, start: sessionStart, end: sessionEnd)
                let filteredCore = Self.overlappingSamples(coreSamples, start: sessionStart, end: sessionEnd)

                let timeInBed = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)

                let deep = Self.clippedMinutes(filteredDeep, start: sessionStart, end: sessionEnd)
                let rem = Self.clippedMinutes(filteredREM, start: sessionStart, end: sessionEnd)
                let core = Self.clippedMinutes(filteredCore, start: sessionStart, end: sessionEnd)

                let stagedAsleep = deep + rem + core
                let rawAsleep = Self.clippedMinutes(filteredAsleep, start: sessionStart, end: sessionEnd)
                let sleepMinutes = min(stagedAsleep > 0 ? stagedAsleep : rawAsleep, timeInBed)

                let rawAwake = Self.clippedMinutes(filteredAwake, start: sessionStart, end: sessionEnd)
                let awakeMinutes = min(max(rawAwake, timeInBed - sleepMinutes), timeInBed)

                continuation.resume(
                    returning: RecoverySleepSnapshot(
                        sleepMinutes: sleepMinutes,
                        timeInBedMinutes: timeInBed,
                        awakeMinutes: awakeMinutes,
                        awakeningsCount: filteredAwake.count,
                        deepSleepMinutes: deep,
                        remSleepMinutes: rem,
                        coreSleepMinutes: core,
                        bedStart: sessionStart,
                        wakeTime: sessionEnd
                    )
                )
            }

            self.healthStore.execute(query)
        }
    }

    private static func isAnyAsleepValue(_ value: Int) -> Bool {
        if value == HKCategoryValueSleepAnalysis.asleep.rawValue {
            return true
        }

        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }

        return false
    }

    private static func primarySleepSession(
        inBedSamples: [HKCategorySample],
        asleepSamples: [HKCategorySample]
    ) -> DateInterval? {
        let source = !inBedSamples.isEmpty ? inBedSamples : asleepSamples
        guard !source.isEmpty else { return nil }

        let sorted = source.sorted { $0.startDate < $1.startDate }
        var sessions: [DateInterval] = []

        for sample in sorted {
            let interval = DateInterval(start: sample.startDate, end: sample.endDate)

            guard let last = sessions.last else {
                sessions.append(interval)
                continue
            }

            let gap = interval.start.timeIntervalSince(last.end)

            if gap <= 90 * 60 {
                sessions.removeLast()
                sessions.append(
                    DateInterval(
                        start: min(last.start, interval.start),
                        end: max(last.end, interval.end)
                    )
                )
            } else {
                sessions.append(interval)
            }
        }

        return sessions.max { $0.duration < $1.duration }
    }

    private static func overlappingSamples(
        _ samples: [HKCategorySample],
        start: Date,
        end: Date
    ) -> [HKCategorySample] {
        samples.filter { $0.startDate < end && $0.endDate > start }
    }

    private static func clippedMinutes(
        _ samples: [HKCategorySample],
        start: Date,
        end: Date
    ) -> Int {
        let seconds = samples.reduce(0.0) { result, sample in
            let clippedStart = max(sample.startDate, start)
            let clippedEnd = min(sample.endDate, end)

            guard clippedEnd > clippedStart else { return result }
            return result + clippedEnd.timeIntervalSince(clippedStart)
        }

        return Int(seconds / 60)
    }

    private func readSleepMinutes(for date: Date) async -> Int {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: []
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in

                guard error == nil else {
                    continuation.resume(returning: 0)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []

                let appleAsleepSamples = sleepSamples
                    .filter { sample in
                        sample.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple")
                    }
                    .filter { sample in
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                             HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                             HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            return true
                        default:
                            return false
                        }
                    }

                let intervals = appleAsleepSamples
                    .map { ($0.startDate, $0.endDate) }
                    .sorted { $0.0 < $1.0 }

                var mergedIntervals: [(Date, Date)] = []

                for interval in intervals {
                    if let last = mergedIntervals.last, interval.0 <= last.1 {
                        mergedIntervals[mergedIntervals.count - 1] = (
                            last.0,
                            max(last.1, interval.1)
                        )
                    } else {
                        mergedIntervals.append(interval)
                    }
                }

                let totalSeconds = mergedIntervals.reduce(0.0) { total, interval in
                    total + interval.1.timeIntervalSince(interval.0)
                }

                continuation.resume(returning: Int(totalSeconds / 60))
            }

            self.healthStore.execute(query)
        }
    }

    private func calculateNutritionFromPlannedMeals(
        _ plannedActivities: [PlannedActivity],
        for date: Date
    ) -> DailyNutritionMetrics {
        let calendar = Calendar.current
        let meals = NutritionRepository().loadMeals()

        let completedMealActivities = plannedActivities.filter { activity in
            guard calendar.isDate(activity.date, inSameDayAs: date) else { return false }
            guard hasActivityPassed(activity.date, for: date) else { return false }
            let type = activity.type.normalized
            return (type == "meal" || type == "drink") && !isHydrationActivityByText(activity)
        }

        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFats: Double = 0
        var totalFiber: Double = 0
        var totalCalories: Double = 0

        for activity in completedMealActivities {
            if let matchedMeal = matchMeal(for: activity, in: meals) {
                totalProtein += Double(matchedMeal.protein)
                totalCarbs += Double(matchedMeal.carbs)
                totalFats += Double(matchedMeal.fats)
                totalFiber += Double(matchedMeal.fiber)
                totalCalories += Double(matchedMeal.calories)
            } else {
                totalProtein += Double(activity.protein)
                totalCarbs += Double(activity.carbs)
                totalFats += Double(activity.fats)
                totalFiber += Double(activity.fiber)
                totalCalories += Double(activity.calories)
            }
        }

        return DailyNutritionMetrics(
            protein: totalProtein, carbs: totalCarbs, fats: totalFats, fiber: totalFiber, calories: totalCalories,
            waterLiters: 0, activeCalories: activeCalories, sleepHours: Double(sleepMinutes) / 60.0, weightKg: weight
        )
    }

    private func plannedWaterIntake(
        from plannedActivities: [PlannedActivity],
        for date: Date
    ) -> Double {
        let calendar = Calendar.current
        let meals = NutritionRepository().loadMeals()

        let completedActivities = plannedActivities.filter { activity in
            guard calendar.isDate(activity.date, inSameDayAs: date) else { return false }
            return hasActivityPassed(activity.date, for: date)
        }

        let hydrationActivities = completedActivities.filter { activity in
            if isHydrationActivityByText(activity) { return true }
            if let matchedMeal = matchMeal(for: activity, in: meals) { return matchedMeal.type == .hydration }
            return false
        }

        let totalMl = hydrationActivities.count * 250
        return Double(totalMl) / 1000.0
    }

    private func hasActivityPassed(_ activityDate: Date, for selectedDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(selectedDate) { return activityDate < now }
        if selectedDate < calendar.startOfDay(for: now) { return true }
        return false
    }

    private func matchMeal(for activity: PlannedActivity, in meals: [Meals]) -> Meals? {
        let activityTitle = activity.title.normalized
        let activityImage = activity.imageName.normalized

        if let exactTitleMatch = meals.first(where: { $0.title.normalized == activityTitle }) { return exactTitleMatch }
        if let imageMatch = meals.first(where: { $0.imageName.normalized == activityImage }) { return imageMatch }

        if let containsMatch = meals.first(where: {
            let mealTitle = $0.title.normalized
            return mealTitle.contains(activityTitle) || activityTitle.contains(mealTitle)
        }) { return containsMatch }

        return nil
    }

    private func isHydrationActivityByText(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title) \(activity.imageName)".normalized
        return text.contains("hydration") || text.contains("water")
    }

    private func calculateHeaderMetrics() {
        let sleepHours = Double(sleepMinutes) / 60.0

        if sleepMinutes == 0 {
            readyScore = 0.0
        } else if sleepHours < 4.0 {
            readyScore = 3.0
        } else if sleepHours < 5.0 {
            readyScore = 4.5
        } else if sleepHours < 6.0 {
            readyScore = 5.8
        } else if sleepHours < 7.0 {
            readyScore = 6.8
        } else if sleepHours < 8.0 {
            readyScore = 8.0
        } else {
            readyScore = 9.0
        }

        energyStatus = {
            if readyScore >= 8.0 { return WeekFitLocalizedString("health.high") }
            if readyScore >= 6.5 { return WeekFitLocalizedString("health.good") }
            if readyScore >= 4.5 { return WeekFitLocalizedString("health.low") }
            if readyScore > 0 { return WeekFitLocalizedString("health.rest") }
            return "—"
        }()

        sleepText = sleepMinutes > 0
            ? "\(sleepMinutes / 60)h \(sleepMinutes % 60)m"
            : "—"

        let recovery = recoveryPercent

        if recovery >= 85 {
            recoveryStatus = WeekFitLocalizedString("health.ready")
        } else if recovery >= 70 {
            recoveryStatus = WeekFitLocalizedString("health.good")
        } else if recovery >= 50 {
            recoveryStatus = WeekFitLocalizedString("health.ok")
        } else if recovery > 0 {
            recoveryStatus = WeekFitLocalizedString("health.needRest")
        } else {
            recoveryStatus = "—"
        }
    }
    
    var recoveryPercent: Int {
        recoveryBreakdown.total
    }
    
    @MainActor
    func refresh(
        for date: Date,
        plannedActivities: [PlannedActivity]
    ) async {
        guard isHealthAccessRequested else { return }
        await loadHealthData(for: date, plannedActivities: plannedActivities)
    }

    func loadWorkoutSamples(for date: Date) async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: true
            )

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }

            healthStore.execute(query)
        }
    }

    func loadWorkoutHealthDetails(for workout: HKWorkout) async -> WorkoutHealthDetailSnapshot {
        async let heartRateSamples = loadWorkoutHeartRateSamples(for: workout)
        async let routePoints = loadWorkoutRoutePoints(for: workout)
        async let steps = readQuantitySum(
            .stepCount,
            unit: .count(),
            start: workout.startDate,
            end: workout.endDate
        )
        async let activeCalories = readQuantitySum(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            start: workout.startDate,
            end: workout.endDate
        )
        async let distanceMeters = readQuantitySum(
            .distanceWalkingRunning,
            unit: .meter(),
            start: workout.startDate,
            end: workout.endDate
        )

        let loadedHeartRateSamples = await heartRateSamples
        let loadedRoutePoints = await routePoints
        let loadedSteps = await steps
        let summedActiveCalories = await activeCalories
        let summedDistanceMeters = await distanceMeters
        let loadedActiveCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? summedActiveCalories
        let loadedDistanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? summedDistanceMeters

        let heartRates = loadedHeartRateSamples.map(\.beatsPerMinute)
        let averageHeartRate = heartRates.isEmpty
            ? nil
            : heartRates.reduce(0, +) / Double(heartRates.count)

        let maxHeartRate = heartRates.max()

        return WorkoutHealthDetailSnapshot(
            source: workout.sourceRevision.source.name,
            activeCalories: loadedActiveCalories > 0 ? loadedActiveCalories : nil,
            distanceKm: loadedDistanceMeters > 0 ? loadedDistanceMeters / 1000.0 : nil,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateSamples: loadedHeartRateSamples,
            routePoints: loadedRoutePoints,
            elevationGain: elevationGain(from: loadedRoutePoints),
            steps: loadedSteps > 0 ? Int(loadedSteps.rounded()) : nil,
            cadence: nil
        )
    }

    func loadWorkoutHealthDetails(
        for workoutID: UUID,
        start: Date,
        end: Date,
        activityType: HKWorkoutActivityType
    ) async -> WorkoutHealthDetailSnapshot? {
        guard let workout = await loadWorkoutSample(
            id: workoutID,
            start: start,
            end: end
        ) else {
            return nil
        }

        async let metrics = loadWorkoutSupplementalMetrics(
            for: workout,
            activityType: activityType
        )
        async let heartRate = loadWorkoutHeartRateDetails(start: start, end: end)
        async let route = loadWorkoutRouteDetails(for: workout)

        let loadedMetrics = await metrics
        let loadedHeartRate = await heartRate
        let loadedRoute = await route

        return WorkoutHealthDetailSnapshot(
            source: workout.sourceRevision.source.name,
            activeCalories: loadedMetrics.activeCalories,
            distanceKm: loadedMetrics.distanceKm,
            averageHeartRate: loadedHeartRate.averageHeartRate,
            maxHeartRate: loadedHeartRate.maxHeartRate,
            heartRateSamples: loadedHeartRate.heartRateSamples,
            routePoints: loadedRoute.routePoints,
            elevationGain: loadedRoute.elevationGain,
            steps: loadedMetrics.steps,
            cadence: loadedMetrics.cadence
        )
    }

    func loadWorkoutSupplementalMetrics(
        for workoutID: UUID,
        start: Date,
        end: Date,
        activityType: HKWorkoutActivityType
    ) async -> WorkoutHealthDetailSnapshot? {
        guard let workout = await loadWorkoutSample(
            id: workoutID,
            start: start,
            end: end
        ) else {
            return nil
        }

        return await loadWorkoutSupplementalMetrics(
            for: workout,
            activityType: activityType
        )
    }

    func loadWorkoutHeartRateDetails(
        start: Date,
        end: Date
    ) async -> WorkoutHealthDetailSnapshot {
        let samples = await loadHeartRateSamples(start: start, end: end)
        let values = samples.map(\.beatsPerMinute)
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)

        return WorkoutHealthDetailSnapshot(
            source: nil,
            activeCalories: nil,
            distanceKm: nil,
            averageHeartRate: average,
            maxHeartRate: values.max(),
            heartRateSamples: samples,
            routePoints: [],
            elevationGain: nil,
            steps: nil,
            cadence: nil
        )
    }

    func loadWorkoutRouteDetails(
        for workoutID: UUID,
        start: Date,
        end: Date
    ) async -> WorkoutHealthDetailSnapshot? {
        guard let workout = await loadWorkoutSample(
            id: workoutID,
            start: start,
            end: end
        ) else {
            return nil
        }

        return await loadWorkoutRouteDetails(for: workout)
    }

    private func loadWorkoutSupplementalMetrics(
        for workout: HKWorkout,
        activityType: HKWorkoutActivityType
    ) async -> WorkoutHealthDetailSnapshot {
        async let activeCalories = readQuantitySum(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            start: workout.startDate,
            end: workout.endDate
        )
        async let distanceMeters = readQuantitySum(
            .distanceWalkingRunning,
            unit: .meter(),
            start: workout.startDate,
            end: workout.endDate
        )
        async let cadence = activityType == .cycling
            ? readQuantityAverage(
                .cyclingCadence,
                unit: .count().unitDivided(by: .minute()),
                start: workout.startDate,
                end: workout.endDate
            )
            : 0

        let shouldLoadSteps: Bool = {
            switch activityType {
            case .walking, .running, .hiking:
                return true
            default:
                return false
            }
        }()

        async let steps = shouldLoadSteps
            ? readQuantitySum(
                .stepCount,
                unit: .count(),
                start: workout.startDate,
                end: workout.endDate
            )
            : 0

        let summedActiveCalories = await activeCalories
        let summedDistanceMeters = await distanceMeters
        let loadedActiveCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? summedActiveCalories
        let loadedDistanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? summedDistanceMeters
        let loadedSteps = await steps
        let loadedCadence = await cadence

        return WorkoutHealthDetailSnapshot(
            source: workout.sourceRevision.source.name,
            activeCalories: loadedActiveCalories > 0 ? loadedActiveCalories : nil,
            distanceKm: loadedDistanceMeters > 0 ? loadedDistanceMeters / 1000.0 : nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            heartRateSamples: [],
            routePoints: [],
            elevationGain: nil,
            steps: loadedSteps > 0 ? Int(loadedSteps.rounded()) : nil,
            cadence: loadedCadence > 0 ? loadedCadence : nil
        )
    }

    private func loadWorkoutRouteDetails(for workout: HKWorkout) async -> WorkoutHealthDetailSnapshot {
        let points = await loadWorkoutRoutePoints(for: workout)

        return WorkoutHealthDetailSnapshot(
            source: nil,
            activeCalories: nil,
            distanceKm: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            heartRateSamples: [],
            routePoints: points,
            elevationGain: elevationGain(from: points),
            steps: nil,
            cadence: nil
        )
    }

    private func loadWorkoutSample(
        id: UUID,
        start: Date,
        end: Date
    ) async -> HKWorkout? {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let workout = (samples as? [HKWorkout] ?? []).first { $0.uuid == id }
                continuation.resume(returning: workout)
            }

            self.healthStore.execute(query)
        }
    }

    private func readQuantitySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard error == nil else {
                    continuation.resume(returning: 0)
                    return
                }

                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }

            self.healthStore.execute(query)
        }
    }

    private func readQuantityAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                guard error == nil else {
                    continuation.resume(returning: 0)
                    return
                }

                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit) ?? 0)
            }

            self.healthStore.execute(query)
        }
    }

    private func loadWorkoutHeartRateSamples(for workout: HKWorkout) async -> [WorkoutHeartRateSample] {
        await loadHeartRateSamples(start: workout.startDate, end: workout.endDate)
    }

    private func loadHeartRateSamples(start: Date, end: Date) async -> [WorkoutHeartRateSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let heartRateSamples = (samples as? [HKQuantitySample] ?? []).map {
                    WorkoutHeartRateSample(
                        timestamp: $0.startDate,
                        beatsPerMinute: $0.quantity.doubleValue(for: unit)
                    )
                }

                continuation.resume(returning: heartRateSamples)
            }

            self.healthStore.execute(query)
        }
    }

    private func downsample(
        _ samples: [WorkoutHeartRateSample],
        maximumCount: Int
    ) -> [WorkoutHeartRateSample] {
        guard samples.count > maximumCount, maximumCount > 1 else {
            return samples
        }

        let stride = Double(samples.count - 1) / Double(maximumCount - 1)

        return (0..<maximumCount).map { index in
            let sourceIndex = min(Int((Double(index) * stride).rounded()), samples.count - 1)
            return samples[sourceIndex]
        }
    }

    private func loadWorkoutRoutePoints(for workout: HKWorkout) async -> [WorkoutRoutePoint] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        let routes = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [HKWorkoutRoute]())
                    return
                }

                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }

            self.healthStore.execute(query)
        }

        var points: [WorkoutRoutePoint] = []

        for route in routes {
            points.append(contentsOf: await loadWorkoutRoutePoints(for: route))
        }

        return points.sorted { $0.timestamp < $1.timestamp }
    }

    private func loadWorkoutRoutePoints(for route: HKWorkoutRoute) async -> [WorkoutRoutePoint] {
        await withCheckedContinuation { continuation in
            var points: [WorkoutRoutePoint] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                points.append(contentsOf: (locations ?? []).map {
                    WorkoutRoutePoint(
                        latitude: $0.coordinate.latitude,
                        longitude: $0.coordinate.longitude,
                        altitude: $0.altitude,
                        timestamp: $0.timestamp
                    )
                })

                if done {
                    continuation.resume(returning: points)
                }
            }

            self.healthStore.execute(query)
        }
    }

    private func elevationGain(from points: [WorkoutRoutePoint]) -> Double? {
        guard points.count > 1 else { return nil }

        let gain = zip(points, points.dropFirst()).reduce(0.0) { total, pair in
            let delta = pair.1.altitude - pair.0.altitude
            return delta > 0 ? total + delta : total
        }

        return gain > 0 ? gain : nil
    }
    
    func loadHourlyActiveCalories(for date: Date) async -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return Array(repeating: 0, count: 24)
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.isDateInToday(date)
            ? Date()
            : (calendar.date(byAdding: .day, value: 1, to: start) ?? date)

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        var interval = DateComponents()
        interval.hour = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, _ in
                var values = Array(repeating: 0.0, count: 24)

                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

                    if hour >= 0 && hour < 24 {
                        values[hour] = value
                    }
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }
}

private extension String {
    var normalized: String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

extension Notification.Name {
    static let healthAccessDidChange = Notification.Name("healthAccessDidChange")
}
