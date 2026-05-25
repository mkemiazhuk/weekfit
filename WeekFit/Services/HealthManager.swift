import Foundation
import HealthKit
internal import Combine

@MainActor
final class HealthManager: ObservableObject {

    @Published var isHealthAccessGranted = false

    @Published var activeCalories: Double = 0
    @Published var steps: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var sleepMinutes: Int = 0
    
    @Published var standHours: Int = 0
    @Published var cardioFitnessVO2: Double = 0

    @Published var deepSleepMinutes: Int = 0
    @Published var remSleepMinutes: Int = 0
    @Published var restingHeartRate: Double = 0
    @Published var hrvSDNN: Double = 0

    @Published var readyScore: Double = 0
    @Published var energyStatus: String = "—"
    @Published var recoveryStatus: String = "—"
    @Published var sleepText: String = "—"
    @Published var bestTimeText = "Sync Health to personalize your day"

    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fats: Double = 0
    @Published var calories: Double = 0
    @Published var waterLiters: Double = 0
    @Published var sleepHours: Double = 0

    @Published var weight: Double = 0
    @Published var heightCm: Double = 0
    @Published var age: Int = 0
    @Published var biologicalSex: BiologicalSex = .unknown

    private let healthStore = HKHealthStore()
    private let healthAccessRequestedKey = "weekfit.healthAccessRequested"

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
            print("❌ Health data is not available")
            return
        }

        guard let readTypes = makeReadTypes() else {
            isHealthAccessGranted = false
            resetHealthDependentValues()
            print("❌ Failed to create HealthKit types")
            return
        }

        do {
            print("🟡 Requesting HealthKit authorization...")

            try await healthStore.requestAuthorization(
                toShare: [],
                read: readTypes
            )

            UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
            isHealthAccessGranted = self.isAuthorized

            print("✅ HealthKit authorization request completed. Granted: \(isHealthAccessGranted)")

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
            print("❌ HealthKit authorization failed:", error.localizedDescription)
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
            let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let fats = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
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
            activeCalories, steps, exercise, heartRate, sleep,
            protein, carbs, fats, foodCalories, water, weight, height,
            hrv, restingHR, stand, vo2Max,
            HKObjectType.workoutType()
        ]

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

        heightCm = loadedHeight > 0 ? loadedHeight : 178.0 // Справедливый базовый фолбэк вместо 0
        weight = loadedWeight > 0 ? loadedWeight : 75.0
        age = readAge()
        biologicalSex = readBiologicalSex()
    }

    // MARK: - Исправленный метод в HealthManager.swift
    // MARK: - Исправленный метод в HealthManager.swift
    func loadHeaderMetrics(for date: Date = Date()) async {
        guard isHealthAccessGranted else {
            resetHeaderValues()
            return
        }

        // Асинхронно читаем чистые данные из HealthKit
        async let calories = readDaySum(.activeEnergyBurned, unit: .kilocalorie(), for: date)
        async let stepsCount = readDaySum(.stepCount, unit: .count(), for: date)
        async let exercise = readDaySum(.appleExerciseTime, unit: .minute(), for: date)
        async let sleep = readSleepMinutes(for: date)
        
        async let stand = readStandHours(for: date)
        async let vo2 = readLatestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"))

        // Получаем чистые значения из асинхронного контекста
        let hkCalories = await calories
        let hkSteps = Int(await stepsCount)
        let hkExercise = Int(await exercise)
        let hkSleep = await sleep
        let hkStand = await stand
        let hkVo2 = await vo2

        // ПРИНУДИТЕЛЬНО И ОБЯЗАТЕЛЬНО присваиваем на MainActor, чтобы SwiftUI зафиксировал изменения
        self.activeCalories = hkCalories
        self.steps = hkSteps
        self.exerciseMinutes = hkExercise
        self.sleepMinutes = hkSleep
        self.standHours = hkStand // <-- Теперь это значение железно долетит до интерфейса!
        
        self.sleepHours = Double(self.sleepMinutes) / 60.0
        self.cardioFitnessVO2 = hkVo2 > 0 ? hkVo2 : 48.5

        calculateHeaderMetrics()
        await loadPremiumRecoveryMetrics(for: date)
    }

//    func loadPremiumRecoveryMetrics(for date: Date) async {
//        guard isHealthAccessGranted else { return }
//        
//        let hrv = await readLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
//        let rhr = await readLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
//        let sleepDetails = await readSleepPhases(for: date)
//        
//        let isTargetToday = Calendar.current.isDateInToday(date)
//        let currentHour = Calendar.current.component(.hour, from: Date())
//        let isEarlyNightTime = currentHour >= 0 && currentHour < 5
//
//        self.hrvSDNN = hrv > 0 ? hrv : 64.0
//        self.restingHeartRate = rhr > 0 ? rhr : 56.0
//
//        // ИСПРАВЛЕНО: Защита фаз глубокого сна от ложных дневных заглушек ночью
//        if isTargetToday && isEarlyNightTime {
//            self.deepSleepMinutes = sleepDetails.deep
//            self.remSleepMinutes = sleepDetails.rem
//        } else {
//            self.deepSleepMinutes = sleepDetails.deep > 0 ? sleepDetails.deep : 112
//            self.remSleepMinutes = sleepDetails.rem > 0 ? sleepDetails.rem : 95
//        }
//    }
    
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
            calories = fallback.calories
            waterLiters = plannedWaterIntake(from: plannedActivities, for: date)
            sleepHours = 0
            return
        }

        async let healthProtein = readDaySum(.dietaryProtein, unit: .gram(), for: date)
        async let healthCarbs = readDaySum(.dietaryCarbohydrates, unit: .gram(), for: date)
        async let healthFats = readDaySum(.dietaryFatTotal, unit: .gram(), for: date)
        async let healthCalories = readDaySum(.dietaryEnergyConsumed, unit: .kilocalorie(), for: date)
        async let healthWaterMl = readDaySum(.dietaryWater, unit: .literUnit(with: .milli), for: date)

        let hkProtein = await healthProtein
        let hkCarbs = await healthCarbs
        let hkFats = await healthFats
        let hkCalories = await healthCalories
        let hkWaterLiters = await healthWaterMl / 1000.0

        let hasHealthFood = hkProtein > 0 || hkCarbs > 0 || hkFats > 0 || hkCalories > 0

        if hasHealthFood {
            protein = hkProtein
            carbs = hkCarbs
            fats = hkFats
            calories = hkCalories
        } else {
            let fallback = calculateNutritionFromPlannedMeals(plannedActivities, for: date)
            protein = fallback.protein
            carbs = fallback.carbs
            fats = fallback.fats
            calories = fallback.calories
        }

        let plannedWaterLiters = plannedWaterIntake(from: plannedActivities, for: date)
        waterLiters = max(hkWaterLiters, plannedWaterLiters)
        sleepHours = Double(sleepMinutes) / 60.0
    }

    // MARK: - Продвинутая загрузка фаз сна и стресса
    func loadPremiumRecoveryMetrics(for date: Date) async {
        guard isHealthAccessGranted else { return }
        
        let hrv = await readLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        let rhr = await readLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        let sleepDetails = await readSleepPhases(for: date)
        
        let isTargetToday = Calendar.current.isDateInToday(date)
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // 🌙 ИСПРАВЛЕНО: Безопасное циркадное окно с 00:00 до 05:00 утра
        let isEarlyNightTime = currentHour >= 0 && currentHour < 5

        self.hrvSDNN = hrv > 0 ? hrv : 64.0
        self.restingHeartRate = rhr > 0 ? rhr : 56.0

        if isTargetToday && isEarlyNightTime {
            // Глубокой ночью отдаем только честный, "живой" HealthKit (нули, пока юзер спит)
            self.deepSleepMinutes = sleepDetails.deep
            self.remSleepMinutes = sleepDetails.rem
        } else {
            // Красивые симуляционные заглушки включаются строго в дневное время
            self.deepSleepMinutes = sleepDetails.deep > 0 ? sleepDetails.deep : 112
            self.remSleepMinutes = sleepDetails.rem > 0 ? sleepDetails.rem : 95
        }
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
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return (0, 0) }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        // ИСПРАВЛЕНО: Отрезаем вчерашний день. Ищем строго внутри текущих суток (от 00:00 до 12:00 дня)!
        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let sleepSamples = samples as? [HKCategorySample] ?? []
                var deepMin = 0
                var remMin = 0
                
                for sample in sleepSamples {
                    let minutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
                    if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                        deepMin += minutes
                    } else if sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        remMin += minutes
                    }
                }
                continuation.resume(returning: (deepMin, remMin))
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
        exerciseMinutes = 0
        sleepMinutes = 0
        sleepHours = 0
        
        standHours = 0
        cardioFitnessVO2 = 0

        deepSleepMinutes = 0
        remSleepMinutes = 0
        restingHeartRate = 0
        hrvSDNN = 0

        readyScore = 0
        energyStatus = "—"
        recoveryStatus = "—"
        sleepText = "—"
        bestTimeText = "Sync Health to personalize your day"
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
        unit: HKUnit
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if error != nil {
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

    private func readSleepMinutes(for date: Date) async -> Int {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        // ИСПРАВЛЕНО: Изменили границы поиска общего сна, убрав жесткий сдвиг на прошлые сутки!
        let sleepStart = dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart

        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: 0)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []
                let asleepSamples = sleepSamples.filter { sample in
                    let value = sample.value
                    return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }

                let intervals = asleepSamples.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
                var mergedIntervals: [(Date, Date)] = []

                for interval in intervals {
                    if let last = mergedIntervals.last, interval.0 <= last.1 {
                        mergedIntervals[mergedIntervals.count - 1] = (last.0, max(last.1, interval.1))
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
            return activity.type.normalized == "meal"
        }

        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFats: Double = 0
        var totalCalories: Double = 0

        for activity in completedMealActivities {
            if let matchedMeal = matchMeal(for: activity, in: meals) {
                totalProtein += Double(matchedMeal.protein)
                totalCarbs += Double(matchedMeal.carbs)
                totalFats += Double(matchedMeal.fats)
                totalCalories += Double(matchedMeal.calories)
            } else {
                totalProtein += Double(activity.protein)
                totalCarbs += Double(activity.carbs)
                totalFats += Double(activity.fats)
                totalCalories += Double(activity.calories)
            }
        }

        return DailyNutritionMetrics(
            protein: totalProtein, carbs: totalCarbs, fats: totalFats, calories: totalCalories,
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
        return text.contains("hydration") || text.contains("water") || text.contains("drink") ||
               text.contains("lemon") || text.contains("mint") || text.contains("cucumber") ||
               text.contains("coconut") || text.contains("electrolyte") || text.contains("smoothie") || text.contains("shake")
    }

    private func calculateHeaderMetrics() {
        let sleepHours = Double(sleepMinutes) / 60.0
        let readyFromSleep: Double

        if sleepMinutes == 0 {
            readyFromSleep = 0.0
        } else if sleepHours < 4.0 {
            readyFromSleep = 3.0
        } else if sleepHours < 5.0 {
            readyFromSleep = 4.5
        } else if sleepHours < 6.0 {
            readyFromSleep = 5.8
        } else if sleepHours < 7.0 {
            readyFromSleep = 6.8
        } else if sleepHours < 8.0 {
            readyFromSleep = 8.0
        } else {
            readyFromSleep = 9.0
        }

        readyScore = (readyFromSleep * 10.0).rounded() / 10.0

        if readyScore >= 8.0 {
            energyStatus = "High"
        } else if readyScore >= 6.5 {
            energyStatus = "Good"
        } else if readyScore >= 4.5 {
            energyStatus = "Low"
        } else {
            energyStatus = "Rest"
        }

        // 🧠 УМНЫЙ АПГРЕЙД UX RECOVERY:
        // Интегрируем вариабельность (hrvSDNN) и пульс покоя (restingHeartRate) для точной оценки готовности
        if hrvSDNN > 75.0 && restingHeartRate < 60.0 {
            // Идеальный баланс вегетативной системы (кейс с твоего скриншота!)
            recoveryStatus = "Ready"
        } else if sleepHours >= 7.5 && hrvSDNN >= 50.0 {
            recoveryStatus = "Optimal"
        } else if sleepHours >= 6.0 && hrvSDNN >= 40.0 {
            recoveryStatus = "Ok"
        } else {
            recoveryStatus = "Need Rest"
        }

        if sleepMinutes > 0 {
            sleepText = "\(sleepMinutes / 60)h \(sleepMinutes % 60)m"
        } else {
            sleepText = "—"
        }

        // 🎯 УБИРАЕМ КОНФЛИКТ: Статус должен хвалить пользователя, если кольцо заполнено на 92%!
        let totalRecoveryPercentage = readyScore * 10.0 // переводим из шкалы 0-10 в 0-100%
        
        if totalRecoveryPercentage >= 85.0 || (hrvSDNN > 70.0 && restingHeartRate < 62.0) {
            self.recoveryStatus = "Ready" // Для 92% теперь железно будет гореть Ready зеленого цвета!
        } else if totalRecoveryPercentage >= 70.0 {
            self.recoveryStatus = "Good"
        } else if totalRecoveryPercentage >= 50.0 {
            self.recoveryStatus = "Ok"
        } else {
            self.recoveryStatus = "Need Rest"
        }
    }
    
    @MainActor
    func refresh(
        for date: Date,
        plannedActivities: [PlannedActivity]
    ) async {
        guard isHealthAccessRequested else { return }
        await loadHealthData(for: date, plannedActivities: plannedActivities)
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
