import SwiftUI

// MARK: - 📋 Global UI Communication Models
// Твоя новая структурированная модель (вынесена на глобальный уровень)
struct DynamicInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let color: Color
    let actionLabel: String
    let tags: Set<CoachTag>
}

// Твой обновленный результирующий контейнер
struct NutritionResult {
    let score: Double
    let status: String
    let goals: NutritionGoals
    let targetCalories: Double
    let consumedCalories: Double
    let recommendation: String
    let activeInsights: [DynamicInsight]
    
    let brain: HumanBrain.State
    let decision: CoachDecision
}


// Хелпер-структуры КБЖУ
struct NutritionGoals {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var waterLiters: Double
}

struct DailyNutritionMetrics {
    var protein: Double
    var carbs: Double
    var fats: Double
    var calories: Double
    var waterLiters: Double
    var activeCalories: Double
    var sleepHours: Double
    var weightKg: Double
}

enum CoachTag: String, Hashable {
    case hydration
    case protein
    case recovery
    case carbs
    case sleep
    case digestion
    case schedule
    case minerals
    case consistency
}
