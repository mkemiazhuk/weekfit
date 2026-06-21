import XCTest
@testable import WeekFit

final class NutritionBudgetCalculatorXCTests: XCTestCase {

    func testBudgetUsesFullDayTargetWithoutDoubleCountingActivity() {
        let profile = UserNutritionProfile(
            weightKg: 80,
            heightCm: 180,
            age: 35,
            sex: .male,
            goal: .maintenance
        )
        let lowActivityMetrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 1500,
            waterLiters: 0,
            activeCalories: 200,
            sleepHours: 7,
            weightKg: 80
        )
        let highActivityMetrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 1500,
            waterLiters: 0,
            activeCalories: 600,
            sleepHours: 7,
            weightKg: 80
        )

        let lowActivityGoals = NutritionGoalEngine.calculate(
            metrics: lowActivityMetrics,
            profile: profile
        )
        let highActivityGoals = NutritionGoalEngine.calculate(
            metrics: highActivityMetrics,
            profile: profile
        )

        let lowBudget = NutritionBudgetCalculator.make(
            goalSet: lowActivityGoals,
            consumed: 1500
        )
        let highBudget = NutritionBudgetCalculator.make(
            goalSet: highActivityGoals,
            consumed: 1500
        )

        XCTAssertGreaterThan(highBudget.totalCalories, lowBudget.totalCalories)
        XCTAssertLessThan(
            highBudget.totalCalories - lowBudget.totalCalories,
            highActivityMetrics.activeCalories - lowActivityMetrics.activeCalories
        )
        XCTAssertEqual(
            lowBudget.remainingCalories,
            Int((lowActivityGoals.fullDay.calories - 1500).rounded())
        )
        XCTAssertEqual(
            highBudget.remainingCalories,
            Int((highActivityGoals.fullDay.calories - 1500).rounded())
        )
    }

    func testBudgetProgressMatchesConsumedOverTotal() {
        let goals = NutritionGoals(
            calories: 2400,
            protein: 140,
            carbs: 250,
            fats: 70,
            fiber: 30,
            waterLiters: 3
        )
        let budget = NutritionBudgetCalculator.make(
            fullDayGoals: goals,
            baseDayCalories: 2000,
            consumed: 1200
        )

        XCTAssertEqual(budget.activityCredit, 400)
        XCTAssertEqual(budget.remainingCalories, 1200)
        XCTAssertEqual(budget.progressPercent, 50)
    }

    func testBudgetReportsOverWhenConsumedExceedsTotal() {
        let goals = NutritionGoals(
            calories: 2200,
            protein: 140,
            carbs: 220,
            fats: 70,
            fiber: 30,
            waterLiters: 3
        )
        let budget = NutritionBudgetCalculator.make(
            fullDayGoals: goals,
            baseDayCalories: 2000,
            consumed: 2350
        )

        XCTAssertTrue(budget.isOverBudget)
        XCTAssertEqual(budget.overCalories, 150)
        XCTAssertEqual(budget.remainingCalories, 0)
    }
}
