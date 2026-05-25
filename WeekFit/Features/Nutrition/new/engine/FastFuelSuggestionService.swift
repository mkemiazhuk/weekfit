import SwiftUI
import SwiftData

struct FastFuelItem: Identifiable, Equatable {
    let id = UUID()
    let imageName: String
    let title: String
    let amount: String
    let reason: String
    var tags: Set<ProductTag> = []

    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatsPer100g: Double
    let standardWeightGrams: Double

    enum ProductTag: Hashable {
        case fastCarb
        case complexCarb
        case fastProtein
        case slowProtein
        case healthyFat
        case hydration
        case electrolytes
        case lightFiber
        case fermented
        case activeRecovery // ✅ ИСПРАВЛЕНО: Добавлен тег для активного моциона
    }
}

final class FastFuelSuggestionService {

    private let calendar = Calendar.current

    func generate(
        currentWater: Double,
        waterGoal: Double,
        currentProtein: Double,
        proteinGoal: Double,
        currentCarbs: Double,
        carbsGoal: Double,
        sleepHours: Double,
        activeCalories: Double,
        plannedActivities: [PlannedActivity],
        selectedDate: Date,
        primaryInsight: DynamicInsight?,
        brain: HumanBrain.State?,
        decision: CoachDecision?
    ) -> [FastFuelItem] {

        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // 🚨 ЭКСТРЕННЫЙ ВЫКЛЮЧАТЕЛЬ ЕДЫ ПРИ РЕАЛЬНОМ ПЕРЕЕДАНИИ ИЛИ ОВЕРЛОАДЕ
        if brain?.fuel == .overfueled || decision?.primaryStrategy == .overload {
            let isLateNight = currentHour >= 21 || currentHour < 4
            
            // Если перебор, но время детское (до 21:00) — отправляем на прогулку!
            if !isLateNight {
                return [
                    FastFuelItem(
                        imageName: "figure.walk",
                        title: "Light Walk",
                        amount: "20-30 min",
                        reason: "Utilize surplus energy & boost digestion",
                        tags: [.activeRecovery],
                        caloriesPer100g: 0.0, proteinPer100g: 0.0, carbsPer100g: 0.0, fatsPer100g: 0.0, standardWeightGrams: 0.0
                    ),
                    FastFuelItem(
                        imageName: "water-bottle",
                        title: "Water",
                        amount: "500 ml",
                        reason: "Flush surplus system",
                        tags: [.hydration],
                        caloriesPer100g: 0.0, proteinPer100g: 0.0, carbsPer100g: 0.0, fatsPer100g: 0.0, standardWeightGrams: 500.0
                    )
                ]
            } else {
                // Если перебор глубокой ночью — гулять не заставляем, даем чаек для разгрузки ЖКТ
                return [
                    FastFuelItem(
                        imageName: "tea",
                        title: "Herbal Tea",
                        amount: "1 cup",
                        reason: "Calm digestive tract before sleep",
                        tags: [.hydration],
                        caloriesPer100g: 1.0, proteinPer100g: 0.0, carbsPer100g: 0.2, fatsPer100g: 0.0, standardWeightGrams: 250.0
                    ),
                    FastFuelItem(
                        imageName: "water-bottle",
                        title: "Water",
                        amount: "300 ml",
                        reason: "Small metabolic flush",
                        tags: [.hydration],
                        caloriesPer100g: 0.0, proteinPer100g: 0.0, carbsPer100g: 0.0, fatsPer100g: 0.0, standardWeightGrams: 300.0
                    )
                ]
            }
        }

        let todayActivities = plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }

        let completedActivities = todayActivities.filter { $0.isCompleted }

        let upcomingActivities = todayActivities.filter {
            !$0.isCompleted &&
            !$0.isSkipped &&
            $0.date >= now
        }

        let lastCompletedWorkout = completedActivities
            .filter { isWorkoutActivity($0) }
            .sorted { $0.date > $1.date }
            .first

        let upcomingWorkout = upcomingActivities
            .filter { isWorkoutActivity($0) }
            .sorted { $0.date < $1.date }
            .first

        let minsSinceWorkout = lastCompletedWorkout.map {
            now.timeIntervalSince($0.date) / 60.0
        }

        let minsUntilWorkout = upcomingWorkout.map {
            now.timeIntervalSince($0.date) / 60.0
        }

        let waterRatio = waterGoal > 0 ? currentWater / waterGoal : 1.0
        let proteinRatio = proteinGoal > 0 ? currentProtein / proteinGoal : 1.0
        let carbsRatio = carbsGoal > 0 ? currentCarbs / carbsGoal : 1.0

        let waterDeficit = max(waterGoal - currentWater, 0.0)
        let proteinDeficit = max(proteinGoal - currentProtein, 0.0)
        let carbsDeficit = max(carbsGoal - currentCarbs, 0.0)

        let isRecentlyCompletedWorkout = minsSinceWorkout.map {
            $0 >= 0 && $0 <= 120
        } ?? false

        let isWorkoutSoon = minsUntilWorkout.map {
            $0 >= 0 && $0 <= 90
        } ?? false

        let isLateNight = currentHour >= 21 || currentHour < 4

        let isDeepNight =
            (currentHour == 22 && currentMinute >= 30) ||
            currentHour > 22 ||
            currentHour < 4

        let isRestDay = todayActivities
            .filter { isWorkoutActivity($0) }
            .isEmpty

        let masterPool = fetchMasterProductPool()

        let availablePool = filteredMasterPool(
            masterPool,
            decision: decision,
            brain: brain
        )

        if isDeepNight {
            let nightItems = buildDeepNightItems(
                waterDeficit: waterDeficit,
                proteinDeficit: proteinDeficit,
                decision: decision,
                brain: brain
            )

            let safeNightItems = filterSuppressedProducts(
                nightItems,
                decision: decision,
                brain: brain
            )

            let nightPool = filteredMasterPool(
                fetchNightBackupPool(),
                decision: decision,
                brain: brain
            )

            return ensureAtLeastOneFoodItem(
                ensureFourUniqueItems(
                    from: safeNightItems,
                    masterPool: nightPool
                ),
                masterPool: nightPool
            )
        }

        var tagScores = makeEmptyTagScores()

        applyCoachTagsBoost(
            primaryInsight?.tags ?? [],
            to: &tagScores
        )

        applyDecisionPriorityBoost(
            decision,
            to: &tagScores
        )

        applyBehavioralContextBoosts(
            to: &tagScores,
            waterRatio: waterRatio,
            proteinRatio: proteinRatio,
            carbsRatio: carbsRatio,
            proteinDeficit: proteinDeficit,
            carbsDeficit: carbsDeficit,
            sleepHours: sleepHours,
            activeCalories: activeCalories,
            isRecentlyCompletedWorkout: isRecentlyCompletedWorkout,
            isWorkoutSoon: isWorkoutSoon,
            isLateNight: isLateNight,
            isRestDay: isRestDay,
            currentHour: currentHour,
            decision: decision,
            brain: brain
        )

        applyDecisionSuppression(
            decision,
            brain: brain,
            to: &tagScores
        )

        let rankedProducts = availablePool
            .map { product -> (score: Double, item: FastFuelItem) in
                let score = product.tags.reduce(0.0) {
                    $0 + tagScores[$1, default: 0.0]
                }
                return (score, product)
            }
            .sorted { $0.score > $1.score }

        let finalItems = composeFinalItems(
            from: rankedProducts,
            masterPool: availablePool,
            primaryInsight: primaryInsight,
            decision: decision,
            brain: brain,
            waterRatio: waterRatio,
            isRecentlyCompletedWorkout: isRecentlyCompletedWorkout,
            isWorkoutSoon: isWorkoutSoon,
            isLateNight: isLateNight,
            isRestDay: isRestDay
        )

        return ensureAtLeastOneFoodItem(
            finalItems,
            masterPool: availablePool
        )
    }
}

// MARK: - Scoring Engine

private extension FastFuelSuggestionService {

    func makeEmptyTagScores() -> [FastFuelItem.ProductTag: Double] {
        [
            .fastCarb: 0,
            .complexCarb: 0,
            .fastProtein: 0,
            .slowProtein: 0,
            .healthyFat: 0,
            .hydration: 0,
            .electrolytes: 0,
            .fermented: 0,
            .activeRecovery: 0 // ✅ ДОБАВИЛИ В СЛОВАРЬ ВЕСОВ
        ]
    }

    func applyCoachTagsBoost(
        _ coachTags: Set<CoachTag>,
        to tagScores: inout [FastFuelItem.ProductTag: Double]
    ) {
        if coachTags.contains(.hydration) {
            tagScores[.hydration, default: 0] += 90
        }

        if coachTags.contains(.minerals) {
            tagScores[.electrolytes, default: 0] += 100
            tagScores[.hydration, default: 0] -= 80
        }

        if coachTags.contains(.protein) {
            tagScores[.fastProtein, default: 0] += 85
            tagScores[.slowProtein, default: 0] += 65
        }

        if coachTags.contains(.carbs) {
            tagScores[.fastCarb, default: 0] += 75
            tagScores[.complexCarb, default: 0] += 50
        }

        if coachTags.contains(.recovery) {
            tagScores[.slowProtein, default: 0] += 80
            tagScores[.fermented, default: 0] += 35
        }

        if coachTags.contains(.sleep) {
            tagScores[.slowProtein, default: 0] += 65
            tagScores[.fermented, default: 0] += 30
        }
    }

    func applyDecisionPriorityBoost(
        _ decision: CoachDecision?,
        to tagScores: inout [FastFuelItem.ProductTag: Double]
    ) {
        guard let decision else { return }

        switch decision.primaryStrategy {
        case .prepareWorkout:
            if !decision.suppressedActions.contains(.fastCarbs) {
                tagScores[.fastCarb, default: 0] += 95
            }
            tagScores[.hydration, default: 0] += 45
            tagScores[.healthyFat, default: 0] -= 50
            tagScores[.slowProtein, default: 0] -= 20

        case .rehydrate:
            if decision.needsElectrolytesInsteadOfWater {
                tagScores[.electrolytes, default: 0] += 110
                tagScores[.fermented, default: 0] += 35
                tagScores[.hydration, default: 0] -= 80
            } else if !decision.suppressHydrationAdvice {
                tagScores[.hydration, default: 0] += 120
            }
            tagScores[.fastCarb, default: 0] -= 20

        case .refuel:
            if !decision.suppressedActions.contains(.fastCarbs) {
                tagScores[.fastCarb, default: 0] += 75
            }
            tagScores[.fastProtein, default: 0] += 85
            tagScores[.slowProtein, default: 0] += 40

        case .addProtein:
            tagScores[.fastProtein, default: 0] += 105
            tagScores[.slowProtein, default: 0] += 85

        case .protectRecovery:
            tagScores[.slowProtein, default: 0] += 85
            tagScores[.fermented, default: 0] += 40
            tagScores[.fastCarb, default: 0] -= 45
            tagScores[.healthyFat, default: 0] -= 25

        case .logFood:
            tagScores[.complexCarb, default: 0] += 30
            tagScores[.slowProtein, default: 0] += 30
            tagScores[.lightFiber, default: 0] += 15

        case .maintain:
            tagScores[.complexCarb, default: 0] += 25
            tagScores[.slowProtein, default: 0] += 25
            tagScores[.healthyFat, default: 0] += 10

        case .overload, .supercompensation:
            // При суперкомпенсации/оверлоаде выключаем тяжелую еду и бустим прогулку/воду
            tagScores[.slowProtein, default: 0] -= 500
            tagScores[.fermented, default: 0] -= 500
            tagScores[.fastCarb, default: 0] -= 999
            tagScores[.complexCarb, default: 0] -= 999
            tagScores[.healthyFat, default: 0] -= 999
            tagScores[.hydration, default: 0] += 150
            tagScores[.activeRecovery, default: 0] += 250 // 🔥 Бустим прогулку
        }
    }

    func applyBehavioralContextBoosts(
        to tagScores: inout [FastFuelItem.ProductTag: Double],
        waterRatio: Double,
        proteinRatio: Double,
        carbsRatio: Double,
        proteinDeficit: Double,
        carbsDeficit: Double,
        sleepHours: Double,
        activeCalories: Double,
        isRecentlyCompletedWorkout: Bool,
        isWorkoutSoon: Bool,
        isLateNight: Bool,
        isRestDay: Bool,
        currentHour: Int,
        decision: CoachDecision?,
        brain: HumanBrain.State?
    ) {
        // ✅ ИСПРАВЛЕНО: Если у нас статус overfueled или overload, полностью обнуляем всю еду
        if brain?.fuel == .overfueled || decision?.primaryStrategy == .overload {
            tagScores[.fastCarb] = -999
            tagScores[.complexCarb] = -999
            tagScores[.healthyFat] = -999
            tagScores[.fastProtein] = -999
            tagScores[.slowProtein] = -999
            tagScores[.fermented] = -999
            tagScores[.hydration, default: 0] += 200
            tagScores[.activeRecovery, default: 0] += 300 // 🔥 Выводим прогулку на первое место
            return
        }

        if brain?.hydration == .optimal || brain?.hydration == .completed || brain?.hydration == .excessive {
            tagScores[.hydration] = -999
        }
        
        if currentHour >= 18 && proteinDeficit > 50 {
            tagScores[.fastProtein, default: 0] += 130
            tagScores[.slowProtein, default: 0] += 115
            tagScores[.fastCarb, default: 0] -= 80
            tagScores[.complexCarb, default: 0] -= 40
            tagScores[.healthyFat, default: 0] -= 35
            return
        }

        if waterRatio < 0.75, decision?.suppressHydrationAdvice != true, brain?.hydration != .completed {
            tagScores[.hydration, default: 0] += 65
        }

        if isWorkoutSoon {
            tagScores[.fastCarb, default: 0] += 75
            tagScores[.hydration, default: 0] += 40
            tagScores[.healthyFat, default: 0] -= 60
        }

        if isRecentlyCompletedWorkout {
            tagScores[.fastProtein, default: 0] += 85
            tagScores[.slowProtein, default: 0] += 45
        }
    }

    func applyDecisionSuppression(
        _ decision: CoachDecision?,
        brain: HumanBrain.State?,
        to tagScores: inout [FastFuelItem.ProductTag: Double]
    ) {
        guard let decision else { return }
        if decision.suppressHydrationAdvice { tagScores[.hydration] = -999 }
        if decision.suppressHeavyFoodAdvice { tagScores[.healthyFat] = -999 }
    }
}

// MARK: - Safety Filters

private extension FastFuelSuggestionService {

    func filteredMasterPool(_ pool: [FastFuelItem], decision: CoachDecision?, brain: HumanBrain.State?) -> [FastFuelItem] {
        if brain?.fuel == .overfueled || decision?.primaryStrategy == .overload {
            // Если перебор, разрешаем только воду, чай и прогулку!
            return pool.filter { $0.tags.contains(.hydration) || $0.tags.contains(.activeRecovery) }
        }
        return pool.filter { !isSuppressedProduct($0, decision: decision, brain: brain) }
    }

    func filterSuppressedProducts(_ items: [FastFuelItem], decision: CoachDecision?, brain: HumanBrain.State?) -> [FastFuelItem] {
        return items.filter { !isSuppressedProduct($0, decision: decision, brain: brain) }
    }

    func isSuppressedProduct(_ item: FastFuelItem, decision: CoachDecision?, brain: HumanBrain.State?) -> Bool {
        if brain?.fuel == .overfueled { return !item.tags.contains(.hydration) && !item.tags.contains(.activeRecovery) }
        return false
    }
}

// MARK: - Core Logic & Master Pools

private extension FastFuelSuggestionService {

    func isWorkoutActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        return type == "workout" || type == "run" || type == "running"
    }

    func isDairy(_ item: FastFuelItem) -> Bool {
        let title = item.title.lowercased()
        return title.contains("yogurt") || title.contains("kefir") || title.contains("curd")
    }

    func composeFinalItems(from rankedProducts: [(score: Double, item: FastFuelItem)], masterPool: [FastFuelItem], primaryInsight: DynamicInsight?, decision: CoachDecision?, brain: HumanBrain.State?, waterRatio: Double, isRecentlyCompletedWorkout: Bool, isWorkoutSoon: Bool, isLateNight: Bool, isRestDay: Bool) -> [FastFuelItem] {
        var result: [FastFuelItem] = []
        var addedTitles = Set<String>()

        for candidate in rankedProducts {
            let item = candidate.item
            let key = item.title.lowercased()
            if result.count < 4 && !addedTitles.contains(key) {
                result.append(item)
                addedTitles.insert(key)
            }
        }
        return result
    }

    func fetchMasterProductPool() -> [FastFuelItem] {
        return [
            // ✅ ДОБАВЛЕНА ПРОГУЛКА В ОБЩИЙ ПУЛ РЕКОМЕНДАЦИЙ
            FastFuelItem(imageName: "figure.walk", title: "Light Walk", amount: "20-30 min", reason: "Utilize carbs & burn active calories", tags: [.activeRecovery], caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatsPer100g: 0, standardWeightGrams: 0),
            
            FastFuelItem(imageName: "water-bottle", title: "Water", amount: "500 ml", reason: "Hydrate system", tags: [.hydration], caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatsPer100g: 0, standardWeightGrams: 500),
            FastFuelItem(imageName: "protein-bar", title: "Protein Bar", amount: "1 bar", reason: "Quick protein input", tags: [.fastProtein], caloriesPer100g: 380, proteinPer100g: 30, carbsPer100g: 25, fatsPer100g: 10, standardWeightGrams: 60),
            FastFuelItem(imageName: "greek-yogurt", title: "Greek Yogurt", amount: "200 g", reason: "Muscle building", tags: [.slowProtein, .fermented], caloriesPer100g: 73, proteinPer100g: 10, carbsPer100g: 4, fatsPer100g: 2, standardWeightGrams: 200),
            FastFuelItem(imageName: "kefir", title: "Kefir 1%", amount: "1 glass", reason: "Smooth digestion", tags: [.electrolytes, .fermented, .slowProtein], caloriesPer100g: 40, proteinPer100g: 3, carbsPer100g: 4, fatsPer100g: 1, standardWeightGrams: 250),
            FastFuelItem(imageName: "tea", title: "Herbal Tea", amount: "1 cup", reason: "Calm down baseline", tags: [.hydration], caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.2, fatsPer100g: 0, standardWeightGrams: 250)
        ]
    }
}

// MARK: - Night Engine Extensions

private extension FastFuelSuggestionService {

    func buildDeepNightItems(
        waterDeficit: Double,
        proteinDeficit: Double,
        decision: CoachDecision?,
        brain: HumanBrain.State?
    ) -> [FastFuelItem] {
        var nightItems: [FastFuelItem] = []

        if brain?.fuel == .overfueled || decision?.primaryStrategy == .overload {
            return [
                FastFuelItem(
                    imageName: "tea", title: "Herbal Tea", amount: "1 cup", reason: "Calm digestive tract", tags: [.hydration],
                    caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.2, fatsPer100g: 0, standardWeightGrams: 250
                )
            ]
        }

        if decision?.needsElectrolytesInsteadOfWater == true {
            nightItems.append(FastFuelItem(imageName: "kefir", title: "Kefir 1%", amount: "200 ml", reason: "Mineral support", tags: [.electrolytes, .fermented, .slowProtein], caloriesPer100g: 40, proteinPer100g: 3, carbsPer100g: 4, fatsPer100g: 1, standardWeightGrams: 200))
        }

        if decision?.suppressHydrationAdvice != true && decision?.needsElectrolytesInsteadOfWater != true && brain?.hydration != .completed && brain?.hydration != .excessive {
            nightItems.append(FastFuelItem(imageName: "tea", title: "Herbal Tea", amount: "1 cup", reason: "Sleep ready", tags: [.hydration], caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.2, fatsPer100g: 0, standardWeightGrams: 250))
        }

        if waterDeficit > 0.3 && decision?.suppressHydrationAdvice != true && decision?.needsElectrolytesInsteadOfWater != true && brain?.hydration != .completed && brain?.hydration != .excessive {
            nightItems.append(FastFuelItem(imageName: "water-bottle", title: "Water", amount: "300 ml", reason: "Small hydration", tags: [.hydration], caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatsPer100g: 0, standardWeightGrams: 300))
        }

        if proteinDeficit > 20 {
            nightItems.append(FastFuelItem(imageName: "kefir", title: "Kefir 1%", amount: "200 ml", reason: "Light night protein", tags: [.fermented, .slowProtein], caloriesPer100g: 40, proteinPer100g: 3, carbsPer100g: 4, fatsPer100g: 1, standardWeightGrams: 200))
        }

        nightItems.append(FastFuelItem(imageName: "greek-yogurt", title: "Curd 5%", amount: "100 g", reason: "Overnight repair", tags: [.slowProtein], caloriesPer100g: 121, proteinPer100g: 16, carbsPer100g: 3, fatsPer100g: 5, standardWeightGrams: 100))

        return nightItems
    }

    func fetchNightBackupPool() -> [FastFuelItem] {
        return [
            FastFuelItem(imageName: "tea", title: "Herbal Tea", amount: "1 cup", reason: "Sleep ready", tags: [.hydration], caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.2, fatsPer100g: 0, standardWeightGrams: 250),
            FastFuelItem(imageName: "kefir", title: "Kefir 1%", amount: "200 ml", reason: "Light night protein", tags: [.electrolytes, .fermented, .slowProtein], caloriesPer100g: 40, proteinPer100g: 3, carbsPer100g: 4, fatsPer100g: 1, standardWeightGrams: 200),
            FastFuelItem(imageName: "greek-yogurt", title: "Curd 5%", amount: "100 g", reason: "Overnight repair", tags: [.slowProtein], caloriesPer100g: 121, proteinPer100g: 16, carbsPer100g: 3, fatsPer100g: 5, standardWeightGrams: 100)
        ]
    }

    func ensureFourUniqueItems(
        from currentList: [FastFuelItem],
        masterPool: [FastFuelItem]
    ) -> [FastFuelItem] {
        var uniqueItems: [FastFuelItem] = []
        var addedTitles = Set<String>()

        for item in currentList {
            let key = item.title.lowercased()
            if !addedTitles.contains(key) {
                uniqueItems.append(item)
                addedTitles.insert(key)
            }
        }

        for backupItem in masterPool {
            if uniqueItems.count >= 4 { break }
            
            let key = backupItem.title.lowercased()
            if !addedTitles.contains(key) {
                uniqueItems.append(backupItem)
                addedTitles.insert(key)
            }
        }
        
        return Array(uniqueItems.prefix(4))
    }

    func ensureAtLeastOneFoodItem(_ items: [FastFuelItem], masterPool: [FastFuelItem]) -> [FastFuelItem] {
        if masterPool.isEmpty || masterPool.first(where: { $0.caloriesPer100g > 0 }) == nil {
            return items
        }
        
        // Позволяем выводить рекомендации без еды (только прогулка + вода), если активен режим переедания
        if items.contains(where: { $0.tags.contains(.activeRecovery) }) {
            return items
        }
        
        if items.contains(where: { !$0.tags.isSubset(of: [.hydration]) }) {
            return items
        }

        guard let food = masterPool.first(where: { !$0.tags.isSubset(of: [.hydration]) }) else {
            return items
        }

        var updated = items
        if updated.count >= 4 {
            updated[3] = food
        } else {
            updated.append(food)
        }
        return updated
    }
}
