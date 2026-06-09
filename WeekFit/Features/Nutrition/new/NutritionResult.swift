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

struct CoachMetricsSnapshot {
    let id: UUID
    let createdAt: Date
    let source: String
    let metrics: DailyNutritionMetrics
    let profile: UserNutritionProfile
    let result: NutritionResult
    let nutritionContext: CoachNutritionContext
    let recoveryContext: CoachRecoveryContext
    let signature: String

    var brain: HumanBrain.State {
        result.brain
    }

    var hydrationRatio: Double {
        nutritionContext.waterGoal > 0
            ? nutritionContext.waterCurrent / nutritionContext.waterGoal
            : 0
    }
}

struct CoachGuidanceSnapshot {
    let id: UUID
    let createdAt: Date
    let source: String
    let metricsSnapshotID: UUID
    let inputSignature: String
    let guidance: CoachGuidanceV3
}


// Хелпер-структуры КБЖУ
struct NutritionGoals {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double
    var waterLiters: Double
}

struct DailyNutritionMetrics {
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double
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
