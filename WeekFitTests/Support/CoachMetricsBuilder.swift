import Foundation
@testable import WeekFit

enum CoachMetricsBuilder {

    static let standardGoals = NutritionGoals(
        calories: 2400,
        protein: 160,
        carbs: 280,
        fats: 70,
        waterLiters: 2.5
    )

    static func standardProfile(goal: NutritionGoal = .maintenance) -> UserNutritionProfile {
        UserNutritionProfile(
            weightKg: 75,
            heightCm: 178,
            age: 30,
            sex: .male,
            goal: goal
        )
    }

    static func metrics(
        protein: Double = 80,
        carbs: Double = 120,
        fats: Double = 40,
        calories: Double = 1200,
        waterLiters: Double = 1.2,
        activeCalories: Double = 400,
        sleepHours: Double = 7.5,
        weightKg: Double = 75
    ) -> DailyNutritionMetrics {
        DailyNutritionMetrics(
            protein: protein,
            carbs: carbs,
            fats: fats,
            calories: calories,
            waterLiters: waterLiters,
            activeCalories: activeCalories,
            sleepHours: sleepHours,
            weightKg: weightKg
        )
    }

    /// Simulates HealthKit gaps (no sleep ring, no move calories).
    static func missingHealthKit() -> DailyNutritionMetrics {
        metrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            calories: 0,
            waterLiters: 0,
            activeCalories: 0,
            sleepHours: 0,
            weightKg: 75
        )
    }

    static func highActivityDay() -> DailyNutritionMetrics {
        metrics(protein: 60, carbs: 90, calories: 900, activeCalories: 950, sleepHours: 7.0)
    }

    static func shortSleepDay() -> DailyNutritionMetrics {
        metrics(calories: 1100, activeCalories: 600, sleepHours: 5.0)
    }
}
