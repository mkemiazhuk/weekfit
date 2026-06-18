import Foundation
import SwiftUI
import SwiftData
internal import Combine

@MainActor
final class NutritionViewModel: ObservableObject {

    @Published var meals: [Meals] = []
    @Published var plannedMeals: [Meals] = []
    @Published var selectedCategory: MealsType?
    @Published var selectedMeal: Meals?

    @Published var nutritionResult: NutritionResult?
    @Published var currentMetrics: DailyNutritionMetrics?
    @Published var currentProfile: UserNutritionProfile?
    @Published private(set) var coachMetricsSnapshot: CoachMetricsSnapshot?
    @Published private(set) var coachGuidanceSnapshot: CoachGuidanceSnapshot?
    @Published private(set) var coachStateRefreshID = UUID()
    
    @Published var manualWaterLiters: Double = 0

    // Локальный кэш активностей для предотвращения сброса данных при трекинге воды
    private var cachedPlannedActivities: [PlannedActivity] = []
    private var lastNutritionStateSignature = ""
    private let repository = NutritionRepository()

    init() { load() }

    func load() { meals = repository.loadMeals() }

    func resetLocalState() {
        load()
        plannedMeals = []
        selectedCategory = nil
        selectedMeal = nil
        nutritionResult = nil
        currentMetrics = nil
        currentProfile = nil
        coachMetricsSnapshot = nil
        coachGuidanceSnapshot = nil
        coachStateRefreshID = UUID()
        manualWaterLiters = 0
        cachedPlannedActivities = []
        lastNutritionStateSignature = ""
    }

    /// Safe UI calculation output mapping directly to HomeView Daily Status circles
    var nutritionPercent: Int {
        if let result = nutritionResult {
            let totalConsumed = currentMetrics?.calories ?? 0.0
            let targetGoal = result.targetCalories
            return targetGoal > 0 ? Int((totalConsumed / targetGoal) * 100) : 0
        }
        return 0
    }

    // MARK: - Core Update Pipeline
    func updateNutrition(
        metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile,
        plannedActivities: [PlannedActivity] = [],
        recoveryContext: CoachRecoveryContext? = nil,
        debugSource: String = "unspecified"
    ) {
        #if DEBUG
        let uniqueActivityIDs = Set(plannedActivities.map(\.id))
        let hydrationActivitiesCount = plannedActivities.filter { $0.imageName == "hydration" && $0.isCompleted }.count
        let duplicateActivitiesCount = plannedActivities.count - uniqueActivityIDs.count
        #endif
        // Сохраняем активности в кэш, чтобы ручной трекер воды не стирал контекст дня
        self.cachedPlannedActivities = plannedActivities
        var updatedMetrics = metrics
        
        // MARK: 🌙 НОЧНОЙ ФИЛЬТР ЦИРКАДНОГО РИТМА (с 00:00 до 05:00)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isEarlyMorning = currentHour >= 0 && currentHour < 5
        
        let hasLoggedMeals = plannedActivities.contains { $0.type.lowercased() == "meal" && $0.isCompleted }
        
        let completedMeals = CoachCanonicalDayState.completedMeals(from: plannedActivities)
        let mealCalories = Double(completedMeals.reduce(0) { $0 + $1.calories })
        let mealProtein = Double(completedMeals.reduce(0) { $0 + $1.protein })
        let mealCarbs = Double(completedMeals.reduce(0) { $0 + $1.carbs })
        let mealFats = Double(completedMeals.reduce(0) { $0 + $1.fats })
        let mealFiber = Double(completedMeals.reduce(0) { $0 + $1.fiber })

        if !completedMeals.isEmpty {
            updatedMetrics.calories = max(updatedMetrics.calories, mealCalories)
            updatedMetrics.protein = max(updatedMetrics.protein, mealProtein)
            updatedMetrics.carbs = max(updatedMetrics.carbs, mealCarbs)
            updatedMetrics.fats = max(updatedMetrics.fats, mealFats)
            updatedMetrics.fiber = max(updatedMetrics.fiber, mealFiber)
        }
        
        if isEarlyMorning && !hasLoggedMeals {
            updatedMetrics.calories = 0.0
            updatedMetrics.protein = 0.0
            updatedMetrics.carbs = 0.0
            updatedMetrics.fats = 0.0
            updatedMetrics.waterLiters = 0.0
//            print("🌙 [Circadian Shield] Deep night block activated. Enforcing pristine zeros for the new calendar day.")
        } else {
            let waterLogsCount = plannedActivities.filter { $0.imageName == "hydration" && $0.isCompleted }.count
            let loggedWaterLiters = (Double(waterLogsCount) * 0.25) + manualWaterLiters
            updatedMetrics.waterLiters = max(updatedMetrics.waterLiters, loggedWaterLiters)
        }

        // Передача сквозного контекста в обновленный NutritionCoreEngine
        let nextNutritionResult = NutritionCoreEngine.calculate(
            from: updatedMetrics,
            profile: profile,
            activities: plannedActivities
        )
        let resolvedRecoveryContext = recoveryContext ??
            coachMetricsSnapshot?.recoveryContext ??
            CoachRecoveryContext(recoveryPercent: 0, sleepHours: updatedMetrics.sleepHours)
        let nextSignature = nutritionStateSignature(
            metrics: updatedMetrics,
            profile: profile,
            result: nextNutritionResult,
            plannedActivities: plannedActivities,
            recoveryContext: resolvedRecoveryContext
        )

        guard nextSignature != lastNutritionStateSignature else {
            CoachLogger.trace(
                "[CoachRefreshSkipped]",
                "Coach refresh skipped: unchanged fingerprint source=NutritionViewModel.updateNutrition.\(debugSource)"
            )
            return
        }

        lastNutritionStateSignature = nextSignature
        let nextSnapshot = makeCoachMetricsSnapshot(
            metrics: updatedMetrics,
            profile: profile,
            result: nextNutritionResult,
            plannedActivities: plannedActivities,
            completedMeals: completedMeals,
            recoveryContext: resolvedRecoveryContext,
            signature: nextSignature,
            source: debugSource
        )
        self.currentMetrics = updatedMetrics
        self.currentProfile = profile
        self.nutritionResult = nextSnapshot.result
        self.coachMetricsSnapshot = nextSnapshot
        let oldRefreshID = coachStateRefreshID
        let newRefreshID = nextSnapshot.id
        #if DEBUG
        let waterGoal = nutritionResult?.goals.waterLiters ?? 0
        let mealDebug = completedMeals
            .map { meal in
                "mealID=\(meal.id) mealName=\"\(meal.title)\" calories=\(meal.calories) protein=\(meal.protein) carbs=\(meal.carbs) fat=\(meal.fats)"
            }
            .joined(separator: " | ")
        CoachRefreshDebug.log(
            "[CoachNutritionMeals]",
            "source=NutritionViewModel.updateNutrition.\(debugSource) meals=\(completedMeals.count) \(mealDebug)"
        )
        CoachRefreshDebug.log(
            "[CoachRefreshDebug]",
            "NutritionViewModel.updateNutrition source=\(debugSource) snapshot=\(nextSnapshot.id) activities=\(plannedActivities.count) uniqueActivities=\(uniqueActivityIDs.count) duplicateActivities=\(duplicateActivitiesCount) hydrationActivities=\(hydrationActivitiesCount) meals=\(completedMeals.count) earlyMorning=\(isEarlyMorning) manualWater=\(String(format: "%.2f", manualWaterLiters)) \(CoachRefreshDebug.hydrationSummary(current: updatedMetrics.waterLiters, goal: waterGoal)) recoveryPercent=\(resolvedRecoveryContext.recoveryPercent) sleepHours=\(String(format: "%.2f", resolvedRecoveryContext.sleepHours)) coachStateRefreshID \(CoachRefreshDebug.uuidChange(oldValue: oldRefreshID, newValue: newRefreshID))"
        )
        CoachRefreshDebug.log(
            "[TodayNutritionInputs]",
            "source=NutritionViewModel.updateNutrition.\(debugSource) incomingCalories=\(String(format: "%.0f", metrics.calories)) incomingProtein=\(String(format: "%.0f", metrics.protein)) incomingCarbs=\(String(format: "%.0f", metrics.carbs)) mealCalories=\(String(format: "%.0f", mealCalories)) mealProtein=\(String(format: "%.0f", mealProtein)) mealCarbs=\(String(format: "%.0f", mealCarbs)) finalCalories=\(String(format: "%.0f", updatedMetrics.calories)) finalProtein=\(String(format: "%.0f", updatedMetrics.protein)) finalCarbs=\(String(format: "%.0f", updatedMetrics.carbs)) activeCalories=\(String(format: "%.0f", updatedMetrics.activeCalories)) sleepHours=\(String(format: "%.2f", updatedMetrics.sleepHours))"
        )
        #endif
        coachStateRefreshID = newRefreshID
    }

    func committedCoachGuidance(
        metricsSnapshotID: UUID,
        inputSignature: String
    ) -> CoachGuidanceV3? {
        guard let snapshot = coachGuidanceSnapshot,
              snapshot.metricsSnapshotID == metricsSnapshotID,
              snapshot.inputSignature == inputSignature else {
            return nil
        }

        return snapshot.guidance
    }

    func commitCoachGuidance(
        _ guidance: CoachGuidanceV3,
        metricsSnapshotID: UUID,
        inputSignature: String,
        source: String
    ) {
        if let existing = coachGuidanceSnapshot,
           existing.metricsSnapshotID == metricsSnapshotID,
           existing.inputSignature == inputSignature {
            return
        }

        coachGuidanceSnapshot = CoachGuidanceSnapshot(
            id: UUID(),
            createdAt: Date(),
            source: source,
            metricsSnapshotID: metricsSnapshotID,
            inputSignature: inputSignature,
            guidance: guidance
        )
    }

    private func nutritionStateSignature(
        metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile,
        result: NutritionResult,
        plannedActivities: [PlannedActivity],
        recoveryContext: CoachRecoveryContext
    ) -> String {
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let activitySignature = plannedActivities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(activity.timelineEventKind)",
                    terminalStateSignature(for: activity),
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    "\(activity.durationMinutes)",
                    "\(activity.actualDurationMinutes ?? -1)",
                    activity.imageName,
                    "\(activity.calories)",
                    "\(activity.protein)",
                    "\(activity.carbs)",
                    "\(activity.fats)",
                    "\(activity.fiber)",
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    activity.source
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return [
            "day=\(Int(day / 86_400))",
            rounded(metrics.calories),
            rounded(metrics.protein),
            rounded(metrics.carbs),
            rounded(metrics.fats),
            rounded(metrics.fiber),
            rounded(metrics.waterLiters),
            rounded(metrics.activeCalories),
            rounded(metrics.sleepHours),
            rounded(metrics.weightKg),
            rounded(profile.weightKg),
            rounded(profile.heightCm),
            "\(profile.age)",
            "\(profile.sex)",
            "\(profile.goal)",
            rounded(result.goals.calories),
            rounded(result.goals.protein),
            rounded(result.goals.carbs),
            rounded(result.goals.fats),
            rounded(result.goals.fiber),
            rounded(result.goals.waterLiters),
            rounded(result.targetCalories),
            "\(recoveryContext.recoveryPercent)",
            rounded(recoveryContext.sleepHours),
            activitySignature
        ].joined(separator: "#")
    }

    private func makeCoachMetricsSnapshot(
        metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile,
        result: NutritionResult,
        plannedActivities: [PlannedActivity],
        completedMeals: [PlannedActivity],
        recoveryContext: CoachRecoveryContext,
        signature: String,
        source: String
    ) -> CoachMetricsSnapshot {
        let adjustedResult = adjustedNutritionResult(
            from: result,
            recoveryContext: recoveryContext,
            plannedActivities: plannedActivities
        )

        return CoachMetricsSnapshot(
            id: UUID(),
            createdAt: Date(),
            source: source,
            metrics: metrics,
            profile: profile,
            result: adjustedResult,
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: metrics.calories,
                caloriesGoal: adjustedResult.goals.calories,
                proteinCurrent: metrics.protein,
                proteinGoal: adjustedResult.goals.protein,
                carbsCurrent: metrics.carbs,
                carbsGoal: adjustedResult.goals.carbs,
                fatsCurrent: metrics.fats,
                fatsGoal: adjustedResult.goals.fats,
                waterCurrent: metrics.waterLiters,
                waterGoal: adjustedResult.goals.waterLiters,
                mealsCount: completedMeals.count,
                lastMealTime: completedMeals.last?.date
            ),
            recoveryContext: recoveryContext,
            signature: signature
        )
    }

    private func rounded(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func terminalStateSignature(for activity: PlannedActivity) -> String {
        if activity.isCompleted { return PlannedActivityTerminalState.completed.rawValue }
        if activity.isSkipped { return PlannedActivityTerminalState.cancelled.rawValue }
        if activity.actualDurationMinutes != nil { return PlannedActivityTerminalState.partial.rawValue }
        return PlannedActivityTerminalState.planned.rawValue
    }

    private struct BrainStateMapping {
        let sleep: HumanBrain.SleepState
        let recovery: HumanBrain.RecoveryState
        let readiness: HumanBrain.ReadinessState
        let fatigueScore: Double
        let completedTrainingStress: Int
        let recent7DayTrainingLoad: Int
        let reasons: [String]
    }

    private func adjustedNutritionResult(
        from result: NutritionResult,
        recoveryContext: CoachRecoveryContext,
        plannedActivities: [PlannedActivity]
    ) -> NutritionResult {
        let mapping = brainStateMapping(
            brain: result.brain,
            recoveryContext: recoveryContext,
            plannedActivities: plannedActivities
        )
        let adjustedBrain = result.brain.replacingBrainStates(
            sleep: mapping.sleep,
            recovery: mapping.recovery,
            readiness: mapping.readiness
        )
        let adjustedDecision = CoachDecisionEngine.makeDecision(from: adjustedBrain)
        let adjustedInsights = CoachInsightFactory.generateInsights(
            brain: adjustedBrain,
            decision: adjustedDecision
        )

        CoachLogger.trace(
            "[BrainStateMappingDebug]",
            """
            rawRecovery=\(recoveryContext.recoveryPercent) sleepHours=\(String(format: "%.2f", recoveryContext.sleepHours)) fatigueScore=\(String(format: "%.1f", mapping.fatigueScore)) completedTrainingStress=\(mapping.completedTrainingStress) recent7DayTrainingLoad=\(mapping.recent7DayTrainingLoad) mappedBrainSleep=\(mapping.sleep) mappedBrainRecovery=\(mapping.recovery) mappedBrainReadiness=\(mapping.readiness) mappingReasons=\(mapping.reasons)
            """
        )

        return NutritionResult(
            score: result.score,
            status: CoachCopy.headline(
                brain: adjustedBrain,
                decision: adjustedDecision
            ),
            goals: result.goals,
            targetCalories: result.targetCalories,
            consumedCalories: result.consumedCalories,
            recommendation: CoachCopy.summary(
                brain: adjustedBrain,
                decision: adjustedDecision,
                complianceScore: result.score
            ),
            activeInsights: adjustedInsights,
            brain: adjustedBrain,
            decision: adjustedDecision
        )
    }

    private func brainStateMapping(
        brain: HumanBrain.State,
        recoveryContext: CoachRecoveryContext,
        plannedActivities: [PlannedActivity]
    ) -> BrainStateMapping {
        let now = Date()
        let completedTrainingStress = trainingStress(
            plannedActivities.filter { $0.isCompleted && isTrainingActivity($0) }
        )
        let recent7DayTrainingLoad = trainingStress(
            plannedActivities.filter {
                $0.isCompleted &&
                    isTrainingActivity($0) &&
                    $0.date >= now.addingTimeInterval(-7 * 24 * 60 * 60)
            }
        )
        let rawRecovery = recoveryContext.recoveryPercent
        let sleepHours = recoveryContext.sleepHours > 0 ? recoveryContext.sleepHours : brain.metrics.sleepHours
        let fatigueScore = max(
            0,
            Double(recent7DayTrainingLoad) +
                Double(completedTrainingStress * 2) +
                (brain.current.activeCalories >= 750 ? 3 : 0) -
                (rawRecovery >= 85 && sleepHours >= 7 ? 3 : 0)
        )

        let mappedSleep: HumanBrain.SleepState
        if sleepHours <= 0 {
            mappedSleep = brain.sleep
        } else if sleepHours < 5.5 {
            mappedSleep = .veryShort
        } else if sleepHours < 6.4 {
            mappedSleep = .short
        } else if sleepHours < 7.0 {
            mappedSleep = .okay
        } else {
            mappedSleep = .strong
        }

        var reasons: [String] = []
        let mappedRecovery: HumanBrain.RecoveryState
        if rawRecovery >= 85 && sleepHours >= 7 && fatigueScore <= 4 && completedTrainingStress <= 1 {
            mappedRecovery = .strong
            reasons.append("raw recovery, sleep, fatigue, and training stress support strong recovery")
        } else if rawRecovery >= 75 && sleepHours >= 6.5 && fatigueScore <= 8 {
            mappedRecovery = .stable
            reasons.append("raw recovery and sleep support stable recovery")
        } else if rawRecovery > 0 && rawRecovery < 55 {
            mappedRecovery = .compromised
            reasons.append("raw recovery is below 55")
        } else if rawRecovery > 0 && rawRecovery < 70 {
            mappedRecovery = .vulnerable
            reasons.append("raw recovery is below 70")
        } else {
            mappedRecovery = brain.recovery
            reasons.append("kept computed recovery state")
        }

        let mappedReadiness: HumanBrain.ReadinessState
        if mappedRecovery == .strong && mappedSleep == .strong && fatigueScore <= 4 {
            mappedReadiness = .good
            reasons.append("strong recovery plus 7h+ sleep maps to ready/good")
        } else if mappedRecovery == .stable && mappedSleep != .veryShort && fatigueScore <= 8 {
            mappedReadiness = .moderate
            reasons.append("stable recovery maps to moderate readiness")
        } else if mappedRecovery == .compromised {
            mappedReadiness = .compromised
        } else if mappedRecovery == .vulnerable {
            mappedReadiness = .low
        } else {
            mappedReadiness = brain.readiness
        }

        return BrainStateMapping(
            sleep: mappedSleep,
            recovery: mappedRecovery,
            readiness: mappedReadiness,
            fatigueScore: fatigueScore,
            completedTrainingStress: completedTrainingStress,
            recent7DayTrainingLoad: recent7DayTrainingLoad,
            reasons: reasons
        )
    }

    private func isTrainingActivity(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .workout || kind == .endurance
    }

    private func trainingStress(_ activities: [PlannedActivity]) -> Int {
        activities.reduce(0) { total, activity in
            switch CoachActivityContextResolverV3.load(for: activity) {
            case .low:
                return total + 1
            case .moderate:
                return total + 2
            case .high:
                return total + 3
            case .extreme:
                return total + 4
            }
        }
    }

    // MARK: - Manual Fluid Tracker Pipeline Interfaces
    
    var totalWaterLiters: Double { currentMetrics?.waterLiters ?? manualWaterLiters }

    func addWater(_ amount: Double = 0.25) {
        #if DEBUG
        let oldManualWater = manualWaterLiters
        #endif
        manualWaterLiters = min(manualWaterLiters + amount, 5.0)
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "NutritionViewModel.addWater amount=\(String(format: "%.2f", amount)) manualWaterOld=\(String(format: "%.2f", oldManualWater)) manualWaterNew=\(String(format: "%.2f", manualWaterLiters)) cachedActivities=\(cachedPlannedActivities.count)"
        )
        #endif
        recalculateNutritionWithManualWater()
    }

    func removeWater(_ amount: Double = 0.25) {
        #if DEBUG
        let oldManualWater = manualWaterLiters
        #endif
        manualWaterLiters = max(manualWaterLiters - amount, 0.0)
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "NutritionViewModel.removeWater amount=\(String(format: "%.2f", amount)) manualWaterOld=\(String(format: "%.2f", oldManualWater)) manualWaterNew=\(String(format: "%.2f", manualWaterLiters)) cachedActivities=\(cachedPlannedActivities.count)"
        )
        #endif
        recalculateNutritionWithManualWater()
    }

    private func recalculateNutritionWithManualWater() {
        guard let metrics = currentMetrics, let profile = currentProfile else {
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachRefreshTrigger]",
                "NutritionViewModel.recalculateNutritionWithManualWater skipped missingMetrics=\(currentMetrics == nil) missingProfile=\(currentProfile == nil)"
            )
            #endif
            return
        }
        
        // ✅ ИСПРАВЛЕНО: Прогоняем воду через полноценную функцию updateNutrition,
        // чтобы не сломать кэш макросов и калорий тренировок!
        updateNutrition(
            metrics: metrics,
            profile: profile,
            plannedActivities: cachedPlannedActivities,
            debugSource: "manualWater.recalculate"
        )
    }

    var recommendedMeals: [Meals] {
        if let selectedCategory { return meals.filter { $0.type == selectedCategory } }
        return meals
    }

    func selectMeal(_ meal: Meals) { selectedMeal = meal }
    func selectCategory(_ category: MealsType?) { selectedCategory = category }
    func addToPlan(_ meal: Meals) {
        guard !plannedMeals.contains(where: { $0.id == meal.id }) else { return }
        plannedMeals.append(meal)
    }
    
    // MARK: - 🧬 Быстрый ИИ-Логгер Белкового Коктейля
    func addCustomProteinShake(context: ModelContext) {
        guard let metrics = currentMetrics, let profile = currentProfile else { return }
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isLateNight = currentHour >= 21 || currentHour < 4
        
        let protein: Double = isLateNight ? 20.0 : 25.0
        let fats: Double = isLateNight ? 1.0 : 1.5
        let carbs: Double = isLateNight ? 3.0 : 4.0
        let calories: Double = isLateNight ? 100.0 : 130.0
        let mealName = isLateNight ? "Overnight Protein Base" : "Active Whey Protein"
        
        let finalCalories = Int(calories)
        let finalProtein = Int(protein)
        let finalCarbs = Int(carbs)
        let finalFats = Int(fats)
        let stringID = UUID().uuidString
        let now = Date()
        
        let newActivity = PlannedActivity(
            id: stringID,
            date: now,
            type: "meal",
            title: mealName,
            durationMinutes: 15,
            icon: "fork.knife",
            imageName: "fork.knife",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43,
            calories: finalCalories,
            protein: finalProtein,
            carbs: finalCarbs,
            fats: finalFats,
            isCompleted: true,
            isSkipped: false,
            source: "nutritionLog"
        )
        
        context.insert(newActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities, debugSource: "coachQuickProteinShake")
        
        CoachLogger.verbose("[SwiftData]", "Custom Protein Shake added & UI Live re-calibrated.")
    }
    
    // MARK: - 🍌 Быстрый ИИ-Логгер Углеводного Перекуса
    func addCustomCarbSnack(context: ModelContext) {
        guard let metrics = currentMetrics, let profile = currentProfile else { return }
        
        let stringID = UUID().uuidString
        let now = Date()
        
        let newActivity = PlannedActivity(
            id: stringID,
            date: now,
            type: "meal",
            title: "nutrition.quickSnack.cleanEnergy.title",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "fork.knife",
            colorRed: 0.92,
            colorGreen: 0.78,
            colorBlue: 0.50,
            calories: 110,
            protein: 1,
            carbs: 25,
            fats: 0,
            isCompleted: true,
            isSkipped: false,
            source: "nutritionLog"
        )
        
        context.insert(newActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities, debugSource: "coachQuickCarbSnack")
        
        CoachLogger.verbose("[SwiftData]", "Custom Carb Snack added & UI Live re-calibrated.")
    }
}

// MARK: - 🧠 СИНХРОНИЗИРОВАННЫЙ ИИ-ЛОГГЕР РЕКОМЕНДАЦИЙ
extension NutritionViewModel {
    
    func addCoachRecommendationToPlan(item: FastFuelItem, context: ModelContext) {
        guard let metrics = currentMetrics, let profile = currentProfile else { return }
        
        let multiplier = item.standardWeightGrams / 100.0
        
        let finalCalories = Int(round(item.caloriesPer100g * multiplier))
        let finalProtein = Int(round(item.proteinPer100g * multiplier))
        let finalCarbs = Int(round(item.carbsPer100g * multiplier))
        let finalFats = Int(round(item.fatsPer100g * multiplier))
        
        let stringID = UUID().uuidString
        let now = Date()
        
        let newMealActivity = PlannedActivity(
            id: stringID,
            date: now,
            type: "meal",
            title: item.title,
            durationMinutes: 15,
            icon: "",
            imageName: item.imageName,
            colorRed: 0.58,
            colorGreen: 0.47,
            colorBlue: 0.82,
            calories: finalCalories,
            protein: finalProtein,
            carbs: finalCarbs,
            fats: finalFats,
            isCompleted: true,
            isSkipped: false,
            source: "nutritionLog"
        )
        
        context.insert(newMealActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newMealActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities, debugSource: "coachRecommendationToPlan")
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        CoachLogger.verbose("[SwiftData]", "Verified food logger injected: \(item.title) (\(finalCalories) kcal, P: \(finalProtein)g, C: \(finalCarbs)g, F: \(finalFats)g)")
    }
}
