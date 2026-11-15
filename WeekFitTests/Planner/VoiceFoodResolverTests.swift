import XCTest
@testable import WeekFit

final class VoiceFoodResolverTests: XCTestCase {

    func testKnownIngredientUsesItsDefaultPortion() {
        let ingredient = MealBuilderDemoData.ingredients.first { $0.id == "base_buckwheat" }
        let decision = VoiceFoodResolver.resolve(
            title: "Гречка",
            kind: "meal",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 0,
            meals: [],
            quickItems: []
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected a known portion")
        }
        let expectedCalories = Int((ingredient!.caloriesPer100g * Double(ingredient!.defaultGrams) / 100).rounded())
        XCTAssertEqual(portion.calories, expectedCalories)
        XCTAssertEqual(portion.title, "Гречка")
        XCTAssertGreaterThan(portion.calories, 0)
    }

    func testStatedGramsScaleTheKnownIngredient() {
        let ingredient = MealBuilderDemoData.ingredients.first { $0.id == "base_buckwheat" }!
        let decision = VoiceFoodResolver.resolve(
            title: "Гречка",
            kind: "meal",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 200,
            milliliters: 0,
            meals: [],
            quickItems: []
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected a scaled portion")
        }
        XCTAssertEqual(portion.calories, Int((ingredient.caloriesPer100g * 2).rounded()))
    }

    func testUnknownFoodAsksForCalories() {
        let decision = VoiceFoodResolver.resolve(
            title: "Пицца",
            kind: "meal",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 0,
            meals: [],
            quickItems: []
        )
        XCTAssertEqual(decision, .needsCalories)
    }

    func testStatedCaloriesAreKeptWhenTheFoodIsUnknown() {
        let decision = VoiceFoodResolver.resolve(
            title: "Пицца",
            kind: "meal",
            calories: 450,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 0,
            meals: [],
            quickItems: []
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected the stated calories")
        }
        XCTAssertEqual(portion.calories, 450)
        XCTAssertEqual(portion.protein, 0)
        XCTAssertEqual(portion.carbs, 0)
        XCTAssertEqual(portion.fats, 0)
    }

    func testSavedMealBeatsTheGenericIngredient() {
        let meal = Meals(
            id: "custom-buckwheat",
            title: "Гречка",
            subtitle: "",
            imageName: "meal",
            type: .balanced,
            calories: 320,
            protein: 12,
            carbs: 40,
            fats: 8,
            benefits: [],
            ingredients: []
        )
        let decision = VoiceFoodResolver.resolve(
            title: "гречка",
            kind: "meal",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 0,
            meals: [meal],
            quickItems: []
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected the saved meal")
        }
        XCTAssertEqual(portion.calories, 320)
        XCTAssertEqual(portion.protein, 12)
    }

    func testSavedCoffeeKeepsItsNumbersWhenTheModelGuesses() {
        let coffee = QuickItem(
            id: "drink_coffee",
            title: "coffee",
            subtitle: "",
            category: .drink,
            imageName: "drink-coffee",
            icon: "cup.and.saucer.fill",
            calories: 40,
            protein: 2,
            carbs: 4,
            fats: 1,
            mlPerServing: 200
        )
        let decision = VoiceFoodResolver.resolve(
            title: "чашка кофе",
            kind: "drink",
            calories: 90,
            protein: 3,
            carbs: 8,
            fat: 3,
            grams: 0,
            milliliters: 0,
            meals: [],
            quickItems: [coffee]
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected the saved coffee")
        }
        XCTAssertEqual(portion.calories, 40)
        XCTAssertEqual(portion.protein, 2)
        XCTAssertEqual(portion.carbs, 4)
        XCTAssertEqual(portion.fats, 1)
        XCTAssertFalse(portion.estimated)
    }

    func testNamedCaloriesStillReplaceASavedMeal() {
        let meal = Meals(
            id: "custom-buckwheat",
            title: "Гречка",
            subtitle: "",
            imageName: "meal",
            type: .balanced,
            calories: 320,
            protein: 12,
            carbs: 40,
            fats: 8,
            benefits: [],
            ingredients: []
        )
        let decision = VoiceFoodResolver.resolve(
            title: "гречка",
            kind: "meal",
            calories: 200,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 0,
            meals: [meal],
            quickItems: []
        )
        guard case .ready(let portion) = decision else {
            return XCTFail("expected the named calories")
        }
        XCTAssertEqual(portion.calories, 200)
        XCTAssertEqual(portion.protein, 8)
        XCTAssertEqual(portion.libraryMealId, "custom-buckwheat")
        XCTAssertFalse(portion.estimated)
    }

    func testWaterStaysOnTheWaterLog() {
        let decision = VoiceFoodResolver.resolve(
            title: "стакан воды",
            kind: "drink",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            grams: 0,
            milliliters: 250,
            meals: [],
            quickItems: []
        )
        XCTAssertEqual(decision, .water)
    }
}
