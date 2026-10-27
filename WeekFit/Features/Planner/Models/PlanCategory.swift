import SwiftUI

enum PlanCategory: CaseIterable {
    case meal
    case workout
    case hydration
    case recovery
    case sleep
    case routine

    var title: String {
        switch self {
        case .meal: "Meal"
        case .workout: "Workout"
        case .hydration: "Hydration"
        case .recovery: "Recovery"
        case .sleep: "Sleep"
        case .routine: "Routine"
        }
    }

    var icon: String {
        switch self {
        case .meal: "fork.knife"
        case .workout: "dumbbell.fill"
        case .hydration: "drop.fill"
        case .recovery: "figure.cooldown"
        case .sleep: "moon.stars.fill"
        case .routine: "checklist"
        }
    }

    var color: Color {
        switch self {
        case .meal: WeekFitSemanticMetricTokens.nutrition
        case .workout: WeekFitSemanticMetricTokens.activity
        case .hydration: WeekFitLightTokens.water
        case .recovery: WeekFitSemanticMetricTokens.recovery
        case .sleep: WeekFitSemanticMetricTokens.recovery
        case .routine: WeekFitSemanticMetricTokens.activity
        }
    }

    var primaryOption: String {
        switch self {
        case .meal: "Breakfast"
        case .workout: "Strength"
        case .hydration: "Water"
        case .recovery: "Stretching"
        case .sleep: "Wind down"
        case .routine: "Morning"
        }
    }

    var secondaryOption: String {
        switch self {
        case .meal: "Lunch"
        case .workout: "Running"
        case .hydration: "Electrolytes"
        case .recovery: "Walk"
        case .sleep: "Bedtime"
        case .routine: "Focus"
        }
    }

    var thirdOption: String {
        switch self {
        case .meal: "Snack"
        case .workout: "Yoga"
        case .hydration: "Reminder"
        case .recovery: "Sauna"
        case .sleep: "No screens"
        case .routine: "Evening"
        }
    }
}
