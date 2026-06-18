import SwiftUI

// MARK: - 📋 Global UI Communication Models
// Твоя новая структурированная модель (вынесена на глобальный уровень)
struct DynamicInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let color: Color
    let actionID: String
    let actionLabel: String
    let tags: Set<CoachTag>

    init(
        icon: String,
        title: String,
        text: String,
        color: Color,
        actionID: String? = nil,
        actionLabel: String,
        tags: Set<CoachTag>
    ) {
        self.icon = icon
        self.title = title
        self.text = text
        self.color = color
        self.actionLabel = actionLabel
        self.tags = tags
        self.actionID = actionID ?? Self.canonicalActionID(for: actionLabel)
    }

    private static func canonicalActionID(for label: String) -> String {
        switch label {
        case "Protect Recovery": return "protect_recovery"
        case "Log Meal": return "log_meal"
        case "Add Carbs": return "add_carbs"
        case "+500 ml": return "add_500_ml"
        case "Refuel Now": return "refuel_now"
        case "Add Protein": return "add_protein"
        case "Stop Eating": return "stop_eating"
        case "Add Minerals": return "add_minerals"
        case "Stay Consistent": return "stay_consistent"
        case "Balance Meals": return "balance_meals"
        case "Wind Down": return "wind_down"
        case "Update Schedule": return "update_schedule"
        case "Prepare Session": return "prepare_session"
        case "Hydration Done": return "hydration_done"
        case "Coach Insight": return "coach_insight"
        default:
            return label
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "_")
        }
    }
}

// Metrics-pipeline container. Do not use `status` / `recommendation` / `activeInsights`
// for user-facing coach UI — canonical coach output lives in `CoachCoordinator.state`.
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
