import Foundation

struct NutritionBudget: Equatable {
    let baseCalories: Double
    let activityCredit: Double
    let totalCalories: Double
    let consumed: Double

    var remaining: Double {
        totalCalories - consumed
    }

    var remainingCalories: Int {
        max(0, Int(remaining.rounded()))
    }

    var overCalories: Int {
        max(0, Int((-remaining).rounded()))
    }

    var progressRatio: Double {
        guard totalCalories > 0 else { return 0 }
        return consumed / totalCalories
    }

    var progressPercent: Int {
        guard totalCalories > 0 else { return 0 }
        return Int((progressRatio * 100).rounded())
    }

    var isOverBudget: Bool {
        remaining < 0
    }
}

enum NutritionBudgetCalculator {

    /// Single source of truth for user-facing calorie budget displays.
    static func canonicalBudget(from viewModel: NutritionViewModel) -> NutritionBudget {
        viewModel.nutritionBudget
    }

    static func make(
        goalSet: NutritionGoalSet,
        consumed: Double
    ) -> NutritionBudget {
        let base = goalSet.baseDay.calories
        let total = goalSet.fullDay.calories
        return NutritionBudget(
            baseCalories: base,
            activityCredit: max(0, total - base),
            totalCalories: total,
            consumed: consumed
        )
    }

    static func make(
        fullDayGoals: NutritionGoals,
        baseDayCalories: Double,
        consumed: Double
    ) -> NutritionBudget {
        NutritionBudget(
            baseCalories: baseDayCalories,
            activityCredit: max(0, fullDayGoals.calories - baseDayCalories),
            totalCalories: fullDayGoals.calories,
            consumed: consumed
        )
    }

    static func make(
        from result: NutritionResult?,
        consumed: Double,
        fallbackTotalCalories: Double = 2200
    ) -> NutritionBudget {
        guard let result else {
            return NutritionBudget(
                baseCalories: fallbackTotalCalories,
                activityCredit: 0,
                totalCalories: fallbackTotalCalories,
                consumed: consumed
            )
        }

        return make(
            fullDayGoals: result.goals,
            baseDayCalories: result.baseDayGoals.calories,
            consumed: consumed
        )
    }
}
