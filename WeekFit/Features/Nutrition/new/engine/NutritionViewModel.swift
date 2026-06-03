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
    
    @Published var manualWaterLiters: Double = 0

    // Локальный кэш активностей для предотвращения сброса данных при трекинге воды
    private var cachedPlannedActivities: [PlannedActivity] = []
    private let repository = NutritionRepository()

    init() { load() }

    func load() { meals = repository.loadMeals() }

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
        plannedActivities: [PlannedActivity] = []
    ) {
        // Сохраняем активности в кэш, чтобы ручной трекер воды не стирал контекст дня
        self.cachedPlannedActivities = plannedActivities
        var updatedMetrics = metrics
        
        // MARK: 🌙 НОЧНОЙ ФИЛЬТР ЦИРКАДНОГО РИТМА (с 00:00 до 05:00)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isEarlyMorning = currentHour >= 0 && currentHour < 5
        
        let hasLoggedMeals = plannedActivities.contains { $0.type.lowercased() == "meal" && $0.isCompleted }
        
        let completedMeals = plannedActivities.filter {
            $0.type.lowercased() == "meal" &&
            $0.isCompleted && !$0.isSkipped && $0.imageName != "hydration"
        }

        updatedMetrics.calories = Double(completedMeals.reduce(0) { $0 + $1.calories })
        updatedMetrics.protein = Double(completedMeals.reduce(0) { $0 + $1.protein })
        updatedMetrics.carbs = Double(completedMeals.reduce(0) { $0 + $1.carbs })
        updatedMetrics.fats = Double(completedMeals.reduce(0) { $0 + $1.fats })
        
        if isEarlyMorning && !hasLoggedMeals {
            updatedMetrics.calories = 0.0
            updatedMetrics.protein = 0.0
            updatedMetrics.carbs = 0.0
            updatedMetrics.fats = 0.0
            updatedMetrics.waterLiters = 0.0
//            print("🌙 [Circadian Shield] Deep night block activated. Enforcing pristine zeros for the new calendar day.")
        } else {
            let waterLogsCount = plannedActivities.filter { $0.imageName == "hydration" && $0.isCompleted }.count
            updatedMetrics.waterLiters = (Double(waterLogsCount) * 0.25) + manualWaterLiters
        }

        let automaticProfile = UserNutritionProfile.createAutomatic(
            weightKg: profile.weightKg, heightCm: profile.heightCm, age: profile.age, sex: profile.sex
        )

        self.currentMetrics = updatedMetrics
        self.currentProfile = automaticProfile
        
        // Передача сквозного контекста в обновленный NutritionCoreEngine
        self.nutritionResult = NutritionCoreEngine.calculate(from: updatedMetrics, profile: automaticProfile, activities: plannedActivities)
    }

    // MARK: - Manual Fluid Tracker Pipeline Interfaces
    
    var totalWaterLiters: Double { (currentMetrics?.waterLiters ?? 0) + manualWaterLiters }

    func addWater(_ amount: Double = 0.25) {
        manualWaterLiters = min(manualWaterLiters + amount, 5.0)
        recalculateNutritionWithManualWater()
    }

    func removeWater(_ amount: Double = 0.25) {
        manualWaterLiters = max(manualWaterLiters - amount, 0.0)
        recalculateNutritionWithManualWater()
    }

    private func recalculateNutritionWithManualWater() {
        guard let metrics = currentMetrics, let profile = currentProfile else { return }
        
        // ✅ ИСПРАВЛЕНО: Прогоняем воду через полноценную функцию updateNutrition,
        // чтобы не сломать кэш макросов и калорий тренировок!
        updateNutrition(
            metrics: metrics,
            profile: profile,
            plannedActivities: cachedPlannedActivities
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
            isSkipped: false
        )
        
        context.insert(newActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities)
        
        print("💾 [SwiftData] Custom Protein Shake added & UI Live re-calibrated.")
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
            title: "Clean Energy Snack",
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
            isSkipped: false
        )
        
        context.insert(newActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities)
        
        print("💾 [SwiftData] Custom Carb Snack added & UI Live re-calibrated.")
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
            isSkipped: false
        )
        
        context.insert(newMealActivity)
        try? context.save()
        
        var updatedActivities = cachedPlannedActivities
        updatedActivities.append(newMealActivity)
        updateNutrition(metrics: metrics, profile: profile, plannedActivities: updatedActivities)
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        print("💾 [SwiftData] Verified food logger injected: \(item.title) (\(finalCalories) kcal, P: \(finalProtein)g, C: \(finalCarbs)g, F: \(finalFats)g)")
    }
}
