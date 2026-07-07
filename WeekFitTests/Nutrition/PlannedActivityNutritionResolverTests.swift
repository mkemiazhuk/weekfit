import XCTest
@testable import WeekFit

final class PlannedActivityNutritionResolverTests: XCTestCase {

    func testResolvedFiberUsesActivityValueWhenPresent() {
        let meal = sampleMeal(fiber: 9)
        let activity = sampleActivity(title: meal.title, fiber: 6)

        XCTAssertEqual(
            PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: [meal]),
            6
        )
    }

    func testResolvedFiberFallsBackToCatalogMealWhenActivityFiberMissing() {
        let meal = sampleMeal(fiber: 11)
        let activity = sampleActivity(title: meal.title, fiber: 0)

        XCTAssertEqual(
            PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: [meal]),
            11
        )
    }

    func testResolvedFiberMatchesNormalizedCustomMealTitle() {
        let meal = sampleMeal(title: "Chicken Bowl", fiber: 7)
        let activity = sampleActivity(title: "  chicken   bowl ", fiber: 0)

        XCTAssertEqual(
            PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: [meal]),
            7
        )
    }

    private func sampleMeal(title: String = "Oatmeal Bowl", fiber: Int) -> Meals {
        Meals(
            id: "meal_test",
            title: title,
            subtitle: "Test meal",
            imageName: "plate-dark",
            type: .balanced,
            calories: 400,
            protein: 20,
            carbs: 45,
            fats: 12,
            fiber: fiber,
            benefits: [],
            ingredients: []
        )
    }

    private func sampleActivity(title: String, fiber: Int) -> PlannedActivity {
        PlannedActivity(
            date: Date(),
            type: "meal",
            title: title,
            durationMinutes: 15,
            icon: "fork.knife",
            imageName: "plate-dark",
            colorRed: 0.5,
            colorGreen: 0.74,
            colorBlue: 0.54,
            calories: 400,
            protein: 20,
            carbs: 45,
            fats: 12,
            fiber: fiber,
            isCompleted: true,
            source: "planner"
        )
    }
}
