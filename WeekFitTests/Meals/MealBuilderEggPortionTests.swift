import XCTest
@testable import WeekFit

final class MealBuilderEggPortionTests: XCTestCase {

    func testBoiledEggsUsePiecePortionsAndCookedDensity() {
        let eggs = MealBuilderDemoData.ingredients.first { $0.id == "protein_eggs" }
        XCTAssertNotNil(eggs)
        guard let eggs else { return }

        XCTAssertTrue(eggs.usesPiecePortions)
        XCTAssertEqual(eggs.gramsPerPiece, 50)
        XCTAssertEqual(eggs.defaultPortionCount, 2)
        XCTAssertEqual(eggs.caloriesPer100g, 155, accuracy: 0.01)

        let selected = SelectedBuilderIngredient(ingredient: eggs, grams: eggs.defaultGrams)
        XCTAssertEqual(selected.portionCount, 2)
        // 100 g × 155 kcal/100 g
        XCTAssertEqual(selected.calories, 155)
    }

    func testFriedEggsHigherThanBoiledForSameCount() {
        let boiled = MealBuilderDemoData.ingredients.first { $0.id == "protein_eggs" }
        let fried = MealBuilderDemoData.ingredients.first { $0.id == "protein_eggs_fried" }
        XCTAssertNotNil(boiled)
        XCTAssertNotNil(fried)
        guard let boiled, let fried else { return }

        XCTAssertTrue(fried.usesPiecePortions)
        XCTAssertEqual(fried.gramsPerPiece, 50)

        let boiledTwo = SelectedBuilderIngredient(ingredient: boiled, grams: 100)
        let friedTwo = SelectedBuilderIngredient(ingredient: fried, grams: 100)
        XCTAssertEqual(boiledTwo.portionCount, 2)
        XCTAssertEqual(friedTwo.portionCount, 2)
        XCTAssertGreaterThan(friedTwo.calories, boiledTwo.calories)
        // USDA-style fried density includes pan oil absorption.
        XCTAssertEqual(friedTwo.calories, 196)
    }

    func testPieceAmountText() {
        let eggs = MealBuilderDemoData.ingredients.first { $0.id == "protein_eggs" }
        XCTAssertNotNil(eggs)
        guard let eggs else { return }
        let text = MealBuilderTitleComposer.amountText(for: eggs, grams: 150)
        XCTAssertTrue(text.contains("3"))
    }
}
