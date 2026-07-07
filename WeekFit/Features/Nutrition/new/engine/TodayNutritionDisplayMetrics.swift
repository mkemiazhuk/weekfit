import Foundation

/// Canonical Today-screen nutrition display values derived from `NutritionBudget`.
/// Active Energy is already partially credited inside the nutrition engine target.
/// Do not add Active Energy again at the display layer.
enum TodayNutritionDisplayMetrics {

    static func remainingCalories(from budget: NutritionBudget) -> Int {
        budget.isOverBudget ? budget.overCalories : budget.remainingCalories
    }

    static func isOverBudget(_ budget: NutritionBudget) -> Bool {
        budget.isOverBudget
    }

    static func progressPercent(from budget: NutritionBudget) -> Int {
        budget.progressPercent
    }

    static func totalCalories(from budget: NutritionBudget) -> Double {
        budget.totalCalories
    }

    static func consumedCalories(from budget: NutritionBudget) -> Double {
        budget.consumed
    }

    /// Legacy Today formula kept only for regression tests proving double-count behavior.
    static func legacyDoubleCountRemaining(
        targetCalories: Double,
        activeCalories: Double,
        consumed: Double
    ) -> Double {
        targetCalories + activeCalories - consumed
    }
}
