import XCTest
@testable import WeekFit

final class NutritionQualityPresenterTests: XCTestCase {

    func testQualityScoreUsesAverageMacroProgressOnly() {
        let input = Input(
            protein: 80, carbs: 160, fats: 45, fiber: 20,
            calories: 2500,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2800,
            mealsLogged: true
        )

        XCTAssertEqual(NutritionQualityPresenter.qualityScore(for: input), 52)
    }

    func testPrimaryInsightExplainsLowProteinScore() {
        let input = Input(
            protein: 40, carbs: 200, fats: 70, fiber: 30,
            calories: 1800,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2200,
            mealsLogged: true
        )

        XCTAssertEqual(
            NutritionQualityPresenter.primaryInsight(for: input),
            .proteinWellBelowTarget
        )
    }

    func testPrimaryInsightCallsOutCaloriesWithoutProtein() {
        let input = Input(
            protein: 90, carbs: 220, fats: 70, fiber: 28,
            calories: 1900,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2200,
            mealsLogged: true
        )

        XCTAssertEqual(
            NutritionQualityPresenter.primaryInsight(for: input),
            .sufficientCaloriesLowProtein
        )
    }

    func testPrimaryInsightRecognizesWellBalancedMacros() {
        let input = Input(
            protein: 150, carbs: 300, fats: 80, fiber: 32,
            calories: 2100,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2200,
            mealsLogged: true
        )

        XCTAssertEqual(
            NutritionQualityPresenter.primaryInsight(for: input),
            .macrosWellBalanced
        )
    }

    func testPrimaryInsightHighlightsFiberWhenItDragsScoreDown() {
        let input = Input(
            protein: 130, carbs: 250, fats: 80, fiber: 10,
            calories: 1900,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2200,
            mealsLogged: true
        )

        XCTAssertEqual(
            NutritionQualityPresenter.primaryInsight(for: input),
            .fiberLow
        )
    }

    func testPrimaryInsightUsesNoMealsStateWhenTimelineIsEmpty() {
        let input = Input(
            protein: 0, carbs: 0, fats: 0, fiber: 0,
            calories: 0,
            proteinGoal: 160, carbsGoal: 320, fatsGoal: 90, fiberGoal: 35,
            caloriesGoal: 2200,
            mealsLogged: false,
            isToday: true
        )

        XCTAssertEqual(
            NutritionQualityPresenter.primaryInsight(for: input),
            .noMealsLogged
        )
    }

    private func Input(
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        calories: Double,
        proteinGoal: Double,
        carbsGoal: Double,
        fatsGoal: Double,
        fiberGoal: Double,
        caloriesGoal: Double,
        mealsLogged: Bool,
        isToday: Bool = true
    ) -> NutritionQualityPresenter.Input {
        NutritionQualityPresenter.Input(
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            calories: calories,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatsGoal: fatsGoal,
            fiberGoal: fiberGoal,
            caloriesGoal: caloriesGoal,
            mealsLogged: mealsLogged,
            isToday: isToday
        )
    }
}
