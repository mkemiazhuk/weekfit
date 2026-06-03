import SwiftUI

struct PlannerOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let imageName: String
}

enum PlannerType: CaseIterable {
    case meal
    case workout
    case recovery
    case habit

    var title: String {
        switch self {
        case .meal: "Meal"
        case .workout: "Workout"
        case .recovery: "Recovery"
        case .habit: "Habit"
        }
    }

    var icon: String {
        switch self {
        case .meal: "fork.knife"
        case .workout: "dumbbell.fill"
        case .recovery: "leaf.fill"
        case .habit: "checkmark.square"
        }
    }

    var color: Color {
        switch self {
        case .meal: WeekFitTheme.meal
        case .workout: WeekFitTheme.workout
        case .recovery: WeekFitTheme.recovery
        case .habit: WeekFitTheme.habit
        }
    }

    var category: PlanCategory {
        switch self {
        case .meal: .meal
        case .workout: .workout
        case .recovery: .recovery
        case .habit: .routine
        }
    }

    var actionTitle: String {
        switch self {
        case .meal: "Schedule Meal"
        case .workout: "Add Workout"
        case .recovery: "Plan Recovery"
        case .habit: "Add Habit"
        }
    }

    var options: [PlannerOption] {
        switch self {
        case .meal:
            return NutritionRepository()
                .loadMeals()
                .map { meal in
                    PlannerOption(
                        title: meal.title,
                        subtitle: "\(meal.calories) kcal",
                        icon: Self.mealIcon(for: meal.type),
                        imageName: meal.imageName
                    )
                }

        case .workout:
            return [
                PlannerOption(title: "Upper Body", subtitle: "Strength", icon: "dumbbell.fill", imageName: "workout-strength"),
                PlannerOption(title: "Running", subtitle: "Cardio", icon: "figure.run", imageName: "workout-running"),
                PlannerOption(title: "Cycling", subtitle: "Endurance", icon: "figure.outdoor.cycle", imageName: "workout-cycling"),
                PlannerOption(title: "Tennis", subtitle: "Endurance", icon: "figure.tennis", imageName: "workout-tennis"),
                PlannerOption(title: "Squash", subtitle: "High Intensity", icon: "figure.tennis", imageName: "workout-squash")
            ]

        case .recovery:
            return [
                PlannerOption(title: "Stretching", subtitle: "Mobility", icon: "figure.cooldown", imageName: "recovery-stretch"),
                PlannerOption(title: "Walk", subtitle: "Light recovery", icon: "figure.walk", imageName: "recovery-walk"),
                PlannerOption(title: "Sauna", subtitle: "Relax", icon: "flame.fill", imageName: "recovery-sauna"),
                PlannerOption(title: "Yoga", subtitle: "Mobility", icon: "figure.yoga", imageName: "recovery-yoga"),
                PlannerOption(title: "Breathing", subtitle: "Calm", icon: "wind", imageName: "recovery-breathing")
            ]

        case .habit:
            return [
                PlannerOption(title: "Drink Water", subtitle: "Hydration", icon: "drop.fill", imageName: "habit-water"),
                PlannerOption(title: "Sleep Routine", subtitle: "Wind down", icon: "moon.stars.fill", imageName: "habit-sleep"),
                PlannerOption(title: "No Screens", subtitle: "Focus", icon: "iphone.slash", imageName: "habit-noscreens"),
                PlannerOption(title: "Morning Routine", subtitle: "Start day", icon: "sun.max.fill", imageName: "habit-morning")
            ]
        }
    }

    private static func mealIcon(for type: MealsType) -> String {
        switch type {
        case .preWorkout: "figure.run"
        case .recovery: "waveform.path.ecg"
        case .highProtein: "fork.knife.circle.fill"
        case .sleepSupport: "moon.zzz.fill"
        case .hydration: "drop.fill"
        case .antiInflammatory: "leaf.fill"
        case .balanced: "chart.pie.fill"
        }
    }
}

extension PlannerType {

    var colorComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .meal:
            return (0.50, 0.74, 0.54)

        case .workout:
            return (0.46, 0.72, 0.82)

        case .recovery:
            return (0.66, 0.58, 0.86)

        case .habit:
            return (0.82, 0.60, 0.36)
        }
    }
}
