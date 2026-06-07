import XCTest
import UIKit
@testable import WeekFit

final class CustomMealsXCTests: XCTestCase {

    func testManualMealValidation_acceptsValidInputAndPreservesValues() {
        let input = CustomMealFormInput(
            name: "Protein Bowl",
            servingGrams: 350,
            calories: 520,
            protein: 42,
            carbs: 48,
            fats: 14,
            fiber: 8
        )

        XCTAssertNil(CustomMealValidation.validationMessage(for: input, existingMeals: []))

        let meal = manualMeal(
            from: input,
            photoFilename: "photo.jpg",
            thumbnailFilename: "thumb.jpg"
        )

        XCTAssertEqual(meal.title, "Protein Bowl")
        XCTAssertEqual(meal.servingGrams, 350)
        XCTAssertEqual(meal.calories, 520)
        XCTAssertEqual(meal.protein, 42)
        XCTAssertEqual(meal.carbs, 48)
        XCTAssertEqual(meal.fats, 14)
        XCTAssertEqual(meal.fiber, 8)
        XCTAssertEqual(meal.localPhotoFilename, "photo.jpg")
        XCTAssertEqual(meal.localPhotoThumbnailFilename, "thumb.jpg")
        XCTAssertEqual(meal.displayPhotoFilename, "thumb.jpg")
        XCTAssertTrue(meal.hasCustomPhoto)
        XCTAssertEqual(meal.libraryKind, .product)
        XCTAssertEqual(meal.creationMode, .manual)
    }

    func testManualMealValidation_blocksInvalidValues() {
        let emptyName = CustomMealFormInput(
            name: "  ",
            servingGrams: 100,
            calories: 100,
            protein: 1,
            carbs: 1,
            fats: 1,
            fiber: 1
        )
        XCTAssertNotNil(CustomMealValidation.validationMessage(for: emptyName, existingMeals: []))

        let zeroNutrition = CustomMealFormInput(
            name: "Water snack",
            servingGrams: 100,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0
        )
        XCTAssertNotNil(CustomMealValidation.validationMessage(for: zeroNutrition, existingMeals: []))

        let invalidServing = CustomMealFormInput(
            name: "Huge bowl",
            servingGrams: 0,
            calories: 10,
            protein: 1,
            carbs: 1,
            fats: 1,
            fiber: 1
        )
        XCTAssertNotNil(CustomMealValidation.validationMessage(for: invalidServing, existingMeals: []))
    }

    func testDuplicateCustomMealNamesAreBlocked() {
        let existing = manualMeal(
            from: CustomMealFormInput(
                name: "Greek Yogurt",
                servingGrams: 200,
                calories: 180,
                protein: 18,
                carbs: 10,
                fats: 4,
                fiber: 0
            )
        )

        let duplicate = CustomMealFormInput(
            name: " greek   yogurt ",
            servingGrams: 150,
            calories: 120,
            protein: 12,
            carbs: 8,
            fats: 2,
            fiber: 0
        )

        XCTAssertNotNil(
            CustomMealValidation.validationMessage(for: duplicate, existingMeals: [existing])
        )
        XCTAssertNil(
            CustomMealValidation.validationMessage(
                for: duplicate,
                existingMeals: [existing],
                excludingID: existing.id
            )
        )
    }

    func testIngredientBasedMealCalculationUpdatesWhenGramsChange() throws {
        let rice = try XCTUnwrap(MealBuilderDemoData.ingredients.first { $0.id == "base_rice" })
        let chicken = try XCTUnwrap(MealBuilderDemoData.ingredients.first { $0.id == "protein_chicken" })

        let firstSelection = [
            SelectedBuilderIngredient(ingredient: rice, grams: 150),
            SelectedBuilderIngredient(ingredient: chicken, grams: 160)
        ]

        let editedSelection = [
            SelectedBuilderIngredient(ingredient: rice, grams: 200),
            SelectedBuilderIngredient(ingredient: chicken, grams: 160)
        ]

        let firstCalories = firstSelection.reduce(0) { $0 + $1.calories }
        let editedCalories = editedSelection.reduce(0) { $0 + $1.calories }

        XCTAssertEqual(firstCalories, 459)
        XCTAssertEqual(editedCalories, 524)
        XCTAssertGreaterThan(editedCalories, firstCalories)
    }

    func testCustomIngredientStorageRoundTrip() {
        let ingredient = MealBuilderIngredient(
            id: "custom_ingredient_test",
            title: "Homemade Granola",
            imageName: "",
            category: .extras,
            defaultGrams: 45,
            caloriesPer100g: 410,
            proteinPer100g: 9,
            carbsPer100g: 62,
            fatsPer100g: 14,
            fiberPer100g: 7,
            visualSize: 60,
            visualDensity: 0.25,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        )

        let encoded = CustomIngredientStore.encode([ingredient])
        let decoded = CustomIngredientStore.load(from: encoded)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.title, "Homemade Granola")
        XCTAssertEqual(decoded.first?.defaultGrams, 45)
        XCTAssertEqual(decoded.first?.caloriesPer100g, 410)
        XCTAssertTrue(CustomIngredientStore.hasDuplicateTitle(" homemade granola ", in: decoded))
    }

    func testCustomMealStorageRoundTripKeepsNewMetadata() {
        let meal = manualMeal(
            from: CustomMealFormInput(
                name: "Saved Product",
                servingGrams: 90,
                calories: 210,
                protein: 12,
                carbs: 24,
                fats: 6,
                fiber: 3
            ),
            photoFilename: "custom-photo.jpg",
            thumbnailFilename: "custom-thumb.jpg"
        )

        let encoded = CustomMealStore.encode([meal])
        let decoded = CustomMealStore.load(from: encoded)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.title, "Saved Product")
        XCTAssertEqual(decoded.first?.libraryKind, .product)
        XCTAssertEqual(decoded.first?.creationMode, .manual)
        XCTAssertEqual(decoded.first?.servingGrams, 90)
        XCTAssertEqual(decoded.first?.localPhotoFilename, "custom-photo.jpg")
        XCTAssertEqual(decoded.first?.localPhotoThumbnailFilename, "custom-thumb.jpg")
        XCTAssertEqual(decoded.first?.displayPhotoFilename, "custom-thumb.jpg")
    }

    func testLegacyMealDecodeDefaultsMetadataToNil() throws {
        let legacyJSON = """
        [{
            "id": "legacy",
            "title": "Legacy Bowl",
            "subtitle": "Rice",
            "imageName": "plate-dark",
            "type": "balanced",
            "calories": 300,
            "protein": 20,
            "carbs": 35,
            "fats": 8,
            "ingredients": [{"name": "Rice", "amount": "150g"}]
        }]
        """

        let meals = try JSONDecoder().decode([Meals].self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(meals.first?.fiber, 0)
        XCTAssertNil(meals.first?.libraryKind)
        XCTAssertNil(meals.first?.creationMode)
        XCTAssertNil(meals.first?.servingGrams)
        XCTAssertNil(meals.first?.localPhotoFilename)
        XCTAssertNil(meals.first?.localPhotoThumbnailFilename)
    }

    func testLoggedCustomMealCanCarryFiberIntoPlannedActivity() {
        let meal = manualMeal(
            from: CustomMealFormInput(
                name: "Fiber Bowl",
                servingGrams: 300,
                calories: 430,
                protein: 24,
                carbs: 55,
                fats: 12,
                fiber: 11
            )
        )

        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: meal.title,
            durationMinutes: 15,
            icon: "fork.knife",
            imageName: meal.imageName,
            colorRed: 0.50,
            colorGreen: 0.74,
            colorBlue: 0.54,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            fiber: meal.fiber,
            isCompleted: true,
            source: "today"
        )

        XCTAssertEqual(activity.title, "Fiber Bowl")
        XCTAssertEqual(activity.fiber, 11)
        XCTAssertTrue(activity.isCompleted)
        XCTAssertEqual(activity.source, "today")
    }

    func testMealClassificationHelpersSeparateFoodsFromRecipes() {
        let food = manualMeal(
            from: CustomMealFormInput(
                name: "Greek Yogurt",
                servingGrams: 170,
                calories: 140,
                protein: 18,
                carbs: 8,
                fats: 3,
                fiber: 0
            )
        )

        let recipe = Meals(
            id: "custom-bowl",
            title: "Chicken Rice Bowl",
            subtitle: "Chicken • Rice",
            imageName: "",
            type: .balanced,
            calories: 520,
            protein: 42,
            carbs: 58,
            fats: 12,
            fiber: 6,
            benefits: ["Balanced"],
            ingredients: [
                MealsIngredient(name: "Chicken", amount: "160g"),
                MealsIngredient(name: "Rice", amount: "200g")
            ],
            libraryKind: .meal,
            creationMode: .ingredients,
            servingGrams: 360,
            localPhotoFilename: nil,
            localPhotoThumbnailFilename: nil
        )

        XCTAssertTrue(food.isFoodProduct)
        XCTAssertFalse(food.isRecipeMeal)
        XCTAssertEqual(food.displayCategoryTitle, "Food")
        XCTAssertEqual(food.sourceLabel, "Custom Food")

        XCTAssertFalse(recipe.isFoodProduct)
        XCTAssertTrue(recipe.isRecipeMeal)
        XCTAssertEqual(recipe.displayCategoryTitle, "Meal")
        XCTAssertEqual(recipe.sourceLabel, "Custom Meal")
    }

    func testPlaceholderInitialUsesTrimmedTitleFallback() {
        let yogurt = manualMeal(
            from: CustomMealFormInput(
                name: "  skyr cup",
                servingGrams: 150,
                calories: 100,
                protein: 16,
                carbs: 6,
                fats: 1,
                fiber: 0
            )
        )

        let untitled = Meals(
            id: "empty",
            title: "   ",
            subtitle: "",
            imageName: "",
            type: .balanced,
            calories: 1,
            protein: 1,
            carbs: 0,
            fats: 0,
            benefits: [],
            ingredients: [],
            libraryKind: .product,
            creationMode: .manual,
            servingGrams: 1,
            localPhotoFilename: nil,
            localPhotoThumbnailFilename: nil
        )

        XCTAssertEqual(yogurt.placeholderInitial, "S")
        XCTAssertEqual(untitled.placeholderInitial, "F")
    }

    func testPhotoCropRendererProducesBoundedSquareImage() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 80, y: 20, width: 160, height: 140))
        }

        let cropped = MealPhotoCropEditorView.crop(
            source,
            outputSize: 256,
            previewSize: 300,
            scale: 1.4,
            offset: CGSize(width: 12, height: -18)
        )

        XCTAssertEqual(cropped.size.width, 256)
        XCTAssertEqual(cropped.size.height, 256)
        XCTAssertEqual(cropped.scale, 1)
    }

    func testMealPhotoStoreThumbnailRendererProducesSquareImage() {
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 360)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 180, height: 360))
            UIColor.white.setFill()
            context.fill(CGRect(x: 40, y: 120, width: 100, height: 120))
        }

        let thumbnail = MealPhotoStore.thumbnailImage(from: portrait, sideLength: 256)

        XCTAssertEqual(thumbnail.size.width, 256)
        XCTAssertEqual(thumbnail.size.height, 256)
        XCTAssertEqual(thumbnail.scale, 1)
    }

    private func manualMeal(
        from input: CustomMealFormInput,
        photoFilename: String? = nil,
        thumbnailFilename: String? = nil
    ) -> Meals {
        Meals(
            id: "meal-\(CustomMealStore.normalizedTitle(input.name))",
            title: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: "\(input.servingGrams)g serving",
            imageName: "",
            type: .balanced,
            calories: input.calories,
            protein: input.protein,
            carbs: input.carbs,
            fats: input.fats,
            fiber: input.fiber,
            benefits: ["Custom meal", "Manual entry"],
            ingredients: [
                MealsIngredient(name: "Serving", amount: "\(input.servingGrams)g")
            ],
            libraryKind: .product,
            creationMode: .manual,
            servingGrams: input.servingGrams,
            localPhotoFilename: photoFilename,
            localPhotoThumbnailFilename: thumbnailFilename
        )
    }
}
