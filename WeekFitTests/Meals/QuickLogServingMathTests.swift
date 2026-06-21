import XCTest
@testable import WeekFit

final class QuickLogServingMathTests: XCTestCase {

    private let bananaProfile = QuickLogNutritionProfile.from(
        item: QuickItem(
            id: "snack_banana",
            title: "Banana",
            subtitle: "Quick energy",
            category: .snack,
            imageName: "ingredient-banana",
            icon: "leaf.fill",
            calories: 105,
            protein: 1,
            carbs: 27,
            fats: 0,
            defaultServingAmount: 1,
            servingUnit: .portion,
            gramsPerServing: 118
        )
    )

    private let waterProfile = QuickLogNutritionProfile.from(
        item: QuickItem(
            id: "drink_water",
            title: "Water",
            subtitle: "Hydration support",
            category: .drink,
            imageName: "ingredient-water",
            icon: "drop.fill",
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            defaultServingAmount: 250,
            servingUnit: .milliliters,
            mlPerServing: 250
        )
    )

    private let mealProfile = QuickLogNutritionProfile.from(
        meal: Meals(
            id: "meal_test",
            title: "Chicken Bowl",
            subtitle: "High protein",
            imageName: "meal-chicken",
            type: .highProtein,
            calories: 520,
            protein: 42,
            carbs: 38,
            fats: 18,
            benefits: [],
            ingredients: [],
            servingGrams: 350
        )
    )

    func testPortionNutritionScalesLinearly() {
        let selection = QuickLogSelection(portions: 2)
        let nutrition = QuickLogServingMath.nutrition(for: mealProfile, selection: selection)

        XCTAssertEqual(nutrition.calories, 1040)
        XCTAssertEqual(nutrition.protein, 84)
        XCTAssertEqual(nutrition.carbs, 76)
        XCTAssertEqual(nutrition.fats, 36)
        XCTAssertEqual(nutrition.portions, 2)
    }

    func testGramModeRecalculatesFromEnteredAmount() {
        let selection = QuickLogSelection(
            portions: 1,
            mode: .grams,
            alternateAmount: 175
        )

        let nutrition = QuickLogServingMath.nutrition(for: mealProfile, selection: selection)

        XCTAssertEqual(nutrition.calories, 260)
        XCTAssertEqual(nutrition.protein, 21)
        XCTAssertEqual(nutrition.grams, 175)
    }

    func testMilliliterModeUsesServingSize() {
        let selection = QuickLogSelection(
            portions: 1,
            mode: .milliliters,
            alternateAmount: 500
        )

        let nutrition = QuickLogServingMath.nutrition(for: waterProfile, selection: selection)

        XCTAssertEqual(nutrition.portions, 2, accuracy: 0.001)
        XCTAssertEqual(nutrition.milliliters, 500)
        XCTAssertEqual(nutrition.calories, 0)
    }

    func testZeroQuantityProducesZeroNutrition() {
        let selection = QuickLogSelection(portions: 0)
        let nutrition = QuickLogServingMath.nutrition(for: bananaProfile, selection: selection)

        XCTAssertEqual(nutrition.calories, 0)
        XCTAssertEqual(nutrition.protein, 0)
        XCTAssertEqual(nutrition.portions, 0)
    }

    func testSelectionBadgeOnlyShowsAboveOne() {
        XCTAssertNil(QuickLogSelection(portions: 1).badgeQuantity)
        XCTAssertEqual(QuickLogSelection(portions: 2).badgeQuantity, 2)
        XCTAssertNil(QuickLogSelection(portions: 0).badgeQuantity)
    }

    func testDefaultSelectionUsesDrinkServingSize() {
        let selection = QuickLogServingMath.defaultSelection(for: waterProfile)

        XCTAssertEqual(selection.portions, 1)
        XCTAssertEqual(selection.alternateAmount, 250)
    }

    func testFormattedQuantityRendersHalfPortions() {
        XCTAssertEqual(QuickLogServingMath.formattedQuantity(1.5), "1.5")
        XCTAssertEqual(QuickLogServingMath.formattedQuantity(2), "2")
    }

    func testToastMessageForMultiplePortions() {
        let message = QuickLogToastMessage.make(
            profile: bananaProfile,
            selection: QuickLogSelection(portions: 2)
        )
        XCTAssertTrue(message.contains("Banana"))
        XCTAssertTrue(message.contains("2"))
    }

    func testToastMessageForWaterVolume() {
        let message = QuickLogToastMessage.make(
            profile: waterProfile,
            selection: QuickLogSelection(portions: 3, alternateAmount: 750)
        )
        XCTAssertTrue(message.contains("750"))
    }
}

final class QuickLogSessionStoreTests: XCTestCase {

    private let profile = QuickLogNutritionProfile.from(
        item: QuickItem(
            id: "snack_banana",
            title: "Banana",
            subtitle: "Quick energy",
            category: .snack,
            imageName: "ingredient-banana",
            icon: "leaf.fill",
            calories: 105,
            protein: 1,
            carbs: 27,
            fats: 0,
            gramsPerServing: 118
        )
    )

    @MainActor
    func testQuickAddStartsAtOneAndExpands() {
        let store = QuickLogSessionStore()
        let selection = store.quickAdd(profile: profile)

        XCTAssertEqual(selection.portions, 1)
        XCTAssertTrue(store.isExpanded(itemID: profile.id))
    }

    @MainActor
    func testDecrementToZeroClearsSelection() {
        let store = QuickLogSessionStore()
        _ = store.quickAdd(profile: profile)
        store.decrement(profile: profile)

        XCTAssertFalse(store.selection(for: profile.id).isSelected)
        XCTAssertFalse(store.isExpanded(itemID: profile.id))
    }

    @MainActor
    func testIncrementIncreasesPortionCount() {
        let store = QuickLogSessionStore()
        _ = store.quickAdd(profile: profile)
        store.increment(profile: profile)

        XCTAssertEqual(store.selection(for: profile.id).portions, 2)
    }

    @MainActor
    func testDismissesSheetAfterSingleTapWhenStepperVisible() async {
        let store = QuickLogSessionStore()
        var dismissedItemID: String?
        store.onSheetDismissRequest = { dismissedItemID = $0 }

        _ = store.quickAdd(profile: profile)
        try? await Task.sleep(for: .milliseconds(1200))
        XCTAssertNil(dismissedItemID)

        try? await Task.sleep(for: .milliseconds(1200))
        XCTAssertEqual(dismissedItemID, profile.id)
    }

    @MainActor
    func testDismissesSheetAfterStepperAdjustments() async {
        let store = QuickLogSessionStore()
        var dismissedItemID: String?
        store.onSheetDismissRequest = { dismissedItemID = $0 }

        _ = store.quickAdd(profile: profile)
        try? await Task.sleep(for: .milliseconds(800))
        XCTAssertNil(dismissedItemID)

        store.increment(profile: profile)
        store.increment(profile: profile)
        try? await Task.sleep(for: .milliseconds(1500))
        XCTAssertNil(dismissedItemID)

        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(dismissedItemID, profile.id)
        XCTAssertEqual(store.selection(for: profile.id).portions, 3)
    }
}

final class QuickLogActivityPortionsTests: XCTestCase {

    func testEncodesPortionsInDurationMinutes() {
        let profile = QuickLogNutritionProfile.from(
            item: QuickItem(
                id: "snack_banana",
                title: "Banana",
                subtitle: "Quick energy",
                category: .snack,
                imageName: "ingredient-banana",
                icon: "leaf.fill",
                calories: 105,
                protein: 1,
                carbs: 27,
                fats: 0,
                gramsPerServing: 118
            )
        )

        let nutrition = QuickLogNutritionValues(
            calories: 210,
            protein: 2,
            carbs: 54,
            fats: 0,
            portions: 2,
            grams: 236,
            milliliters: nil
        )

        XCTAssertEqual(
            QuickLogActivityPortions.encodeDurationMinutes(profile: profile, nutrition: nutrition),
            20
        )
    }

    func testPlannerMetadataShowsMultiplePortions() {
        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Banana",
            durationMinutes: 20,
            icon: "leaf.fill",
            colorRed: 0.5,
            colorGreen: 0.74,
            colorBlue: 0.54,
            calories: 210,
            isCompleted: true,
            source: "today"
        )

        let metadata = QuickLogActivityPortions.metadataPrimary(for: activity)
        XCTAssertTrue(metadata?.contains("2") == true)
    }

    func testPlannerMetadataShowsWaterVolume() {
        let activity = PlannedActivity(
            date: Date(),
            type: "drink",
            title: "Water",
            durationMinutes: 500,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.25,
            colorGreen: 0.55,
            colorBlue: 0.95,
            isCompleted: true,
            source: "today"
        )

        let metadata = QuickLogActivityPortions.metadataPrimary(for: activity)
        XCTAssertTrue(metadata?.contains("500") == true)
    }

    func testWaterThreePortionsEncodes750Milliliters() {
        let profile = QuickLogNutritionProfile.from(
            item: QuickItem(
                id: "drink_water",
                title: "Water",
                subtitle: "Hydration support",
                category: .drink,
                imageName: "ingredient-water",
                icon: "drop.fill",
                calories: 0,
                protein: 0,
                carbs: 0,
                fats: 0,
                defaultServingAmount: 250,
                servingUnit: .milliliters,
                mlPerServing: 250
            )
        )

        let selection = QuickLogSelection(portions: 3)
        let nutrition = QuickLogServingMath.nutrition(for: profile, selection: selection)

        XCTAssertEqual(nutrition.milliliters, 750)
        XCTAssertEqual(nutrition.portions, 3)

        XCTAssertEqual(
            QuickLogActivityPortions.encodeDurationMinutes(profile: profile, nutrition: nutrition),
            750
        )
    }

    func testTotalWaterLitersUsesStoredMilliliters() {
        let activity = PlannedActivity(
            date: Date(),
            type: "drink",
            title: "Water",
            durationMinutes: 750,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.25,
            colorGreen: 0.55,
            colorBlue: 0.95,
            isCompleted: true,
            source: "today"
        )

        XCTAssertEqual(QuickLogActivityPortions.waterMilliliters(for: activity), 750)
        XCTAssertEqual(QuickLogActivityPortions.totalWaterLiters(from: [activity]), 0.75, accuracy: 0.001)
    }

    func testWaterToastShows750MillilitersForThreePortions() {
        let profile = QuickLogNutritionProfile.from(
            item: QuickItem(
                id: "drink_water",
                title: "Water",
                subtitle: "Hydration support",
                category: .drink,
                imageName: "ingredient-water",
                icon: "drop.fill",
                calories: 0,
                protein: 0,
                carbs: 0,
                fats: 0,
                defaultServingAmount: 250,
                servingUnit: .milliliters,
                mlPerServing: 250
            )
        )

        let toast = QuickLogToastMessage.make(
            profile: profile,
            selection: QuickLogSelection(portions: 3)
        )

        XCTAssertTrue(toast.contains("750"))
    }
}
