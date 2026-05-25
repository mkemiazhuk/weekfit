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
        case .meal: Color(red: 0.20, green: 0.62, blue: 0.36)
        case .workout: Color(red: 0.30, green: 0.48, blue: 0.90)
        case .hydration: Color(red: 0.25, green: 0.55, blue: 0.92)
        case .recovery: Color(red: 0.95, green: 0.58, blue: 0.12)
        case .sleep: Color(red: 0.58, green: 0.40, blue: 0.78)
        case .routine: Color(red: 0.32, green: 0.64, blue: 0.58)
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
