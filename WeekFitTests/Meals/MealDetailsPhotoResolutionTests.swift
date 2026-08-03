import XCTest
import UIKit
@testable import WeekFit
import WeekFitPlanner

final class MealDetailsPhotoResolutionTests: XCTestCase {

    func testNutritionVisualResolvesLocalPhotoForLoggedCustomFood() throws {
        let photo = try makeTestPhoto()
        defer {
            MealPhotoStore.deletePhotoSet(
                originalFilename: photo.originalFilename,
                thumbnailFilename: photo.thumbnailFilename
            )
            MealPhotoStore.releaseMemoryCache()
        }

        let catalogMeal = Meals(
            id: "custom_meal_photo_test",
            title: "Barcode Yogurt",
            subtitle: "150g serving",
            imageName: "",
            type: .balanced,
            calories: 120,
            protein: 10,
            carbs: 12,
            fats: 3,
            fiber: 0,
            benefits: ["Custom meal"],
            ingredients: [MealsIngredient(name: "Serving", amount: "150g")],
            libraryKind: .product,
            creationMode: .manual,
            servingGrams: 150,
            localPhotoFilename: photo.originalFilename,
            localPhotoThumbnailFilename: photo.thumbnailFilename
        )

        let activity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: "Barcode Yogurt",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 120,
            protein: 10,
            carbs: 12,
            fats: 3,
            fiber: 0,
            source: "nutritionLog"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: [catalogMeal]
            )
        )

        guard case .localPhoto = visual else {
            return XCTFail("Expected local photo visual, got \(visual)")
        }
    }

    func testNutritionVisualMatchesFoodTypeAlias() throws {
        let catalogMeal = Meals(
            id: "custom_meal_food_type",
            title: "Overnight Oats",
            subtitle: "Custom",
            imageName: "",
            type: .balanced,
            calories: 400,
            protein: 20,
            carbs: 45,
            fats: 12,
            fiber: 6,
            benefits: [],
            ingredients: [],
            builderImageItems: [
                MealBuilderImageItem(
                    id: "oats",
                    imageName: "ingredient-oatmeal",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 1,
                    grams: 80
                )
            ],
            libraryKind: .meal,
            creationMode: .ingredients
        )

        let activity = PlannedActivity(
            date: Date(),
            type: "food",
            title: "Overnight Oats",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 400,
            source: "nutritionLog"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: [catalogMeal]
            )
        )

        guard case .builderPlate = visual else {
            return XCTFail("Expected builder plate visual for matched meal, got \(visual)")
        }
    }

    func testNutritionVisualResolvesLocalPhotoFromActivityImageNameWithoutCatalog() throws {
        let photo = try makeTestPhoto()
        defer {
            MealPhotoStore.deletePhotoSet(
                originalFilename: photo.originalFilename,
                thumbnailFilename: photo.thumbnailFilename
            )
            MealPhotoStore.releaseMemoryCache()
        }

        let activity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: "Unmatched New Dish",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: photo.thumbnailFilename,
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 180,
            source: "nutritionLog"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: []
            )
        )

        guard case .localPhoto = visual else {
            return XCTFail("Expected local photo from activity.imageName, got \(visual)")
        }
    }

    func testMealActivityImageNamePrefersCustomPhotoFilename() {
        let meal = Meals(
            id: "activity_image_name",
            title: "Photo Meal",
            subtitle: "Custom",
            imageName: "meal-chicken",
            type: .balanced,
            calories: 400,
            protein: 30,
            carbs: 20,
            fats: 10,
            fiber: 2,
            benefits: [],
            ingredients: [],
            localPhotoFilename: "original-abc.jpg",
            localPhotoThumbnailFilename: "thumbnail-abc.jpg"
        )

        XCTAssertEqual(meal.activityImageName, "thumbnail-abc.jpg")
    }

    func testMealActivityImageNameSkipsPlaceholderPlateAsset() {
        let meal = Meals(
            id: "builder_plate_dark",
            title: "Turkey Cucumber",
            subtitle: "Custom",
            imageName: "plate-dark",
            type: .balanced,
            calories: 320,
            protein: 35,
            carbs: 12,
            fats: 8,
            fiber: 2,
            benefits: [],
            ingredients: []
        )

        XCTAssertEqual(meal.activityImageName, "")
    }

    func testMealActivityImageNameUsesPrimaryBuilderIngredient() {
        let meal = Meals(
            id: "builder_primary_ingredient",
            title: "Turkey Cucumber",
            subtitle: "Custom",
            imageName: "plate-dark",
            type: .balanced,
            calories: 250,
            protein: 40,
            carbs: 8,
            fats: 5,
            fiber: 2,
            benefits: [],
            ingredients: [],
            builderImageItems: [
                MealBuilderImageItem(
                    id: "veg_cucumber",
                    imageName: "ingredient-cucumber",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 1,
                    grams: 100
                ),
                MealBuilderImageItem(
                    id: "protein_turkey",
                    imageName: "ingredient-turkey",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 5,
                    grams: 150
                )
            ]
        )

        XCTAssertEqual(meal.activityImageName, "ingredient-turkey")
    }

    func testNutritionVisualInfersBuilderPlateFromRussianTitleWithoutCatalog() throws {
        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Индейка Огурец",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "plate-dark",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 250,
            source: "today"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: []
            )
        )

        guard case .builderPlate(let items, _) = visual else {
            return XCTFail("Expected inferred builder plate, got \(visual)")
        }

        let names = Set(items.map(\.imageName))
        XCTAssertTrue(names.contains("ingredient-turkey"))
        XCTAssertTrue(names.contains("ingredient-cucumber"))
    }

    func testNutritionVisualMatchesLocalizedBuilderTitleToEnglishCatalogMeal() throws {
        let catalogMeal = Meals(
            id: "custom_turkey_cucumber",
            title: "Turkey Cucumber",
            subtitle: "Turkey (150 g) + Cucumber (100 g)",
            imageName: "plate-dark",
            type: .balanced,
            calories: 250,
            protein: 40,
            carbs: 8,
            fats: 5,
            fiber: 2,
            benefits: [],
            ingredients: [
                MealsIngredient(name: "Turkey", amount: "150 g"),
                MealsIngredient(name: "Cucumber", amount: "100 g")
            ],
            builderImageItems: [
                MealBuilderImageItem(
                    id: "protein_turkey",
                    imageName: "ingredient-turkey",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 2,
                    grams: 150
                ),
                MealBuilderImageItem(
                    id: "veg_cucumber",
                    imageName: "ingredient-cucumber",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 1,
                    grams: 100
                )
            ],
            libraryKind: .meal,
            creationMode: .ingredients
        )

        // Quick Log persists the Russian short title while catalog keeps English.
        let activity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: "Индейка Огурец",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "plate-dark",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 250,
            protein: 40,
            carbs: 8,
            fats: 5,
            fiber: 2,
            source: "today"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: [catalogMeal]
            )
        )

        guard case .builderPlate(let items, _) = visual else {
            return XCTFail("Expected builder plate for localized Quick Log title, got \(visual)")
        }
        XCTAssertEqual(Set(items.map(\.imageName)), ["ingredient-turkey", "ingredient-cucumber"])
    }

    func testCustomMealStoreMatchesRussianActivityTitleToEnglishBuilderMeal() {
        let catalogMeal = Meals(
            id: "custom_turkey_sweet_potato",
            title: "Turkey Sweet Potato",
            subtitle: "Custom",
            imageName: "plate-dark",
            type: .balanced,
            calories: 400,
            protein: 35,
            carbs: 40,
            fats: 8,
            fiber: 6,
            benefits: [],
            ingredients: [],
            builderImageItems: [
                MealBuilderImageItem(
                    id: "protein_turkey",
                    imageName: "ingredient-turkey",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 2,
                    grams: 150
                ),
                MealBuilderImageItem(
                    id: "base_sweet_potato",
                    imageName: "ingredient-sweet-potato",
                    visualSize: 1,
                    visualDensity: 1,
                    supportsStandalonePresentation: true,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0,
                    zIndex: 1,
                    grams: 180
                )
            ],
            libraryKind: .meal,
            creationMode: .ingredients
        )

        let matched = CustomMealStore.meal(
            matchingActivityTitle: "Индейка Батат",
            in: [catalogMeal]
        )

        XCTAssertEqual(matched?.id, catalogMeal.id)
    }

    private func makeTestPhoto() throws -> MealPhotoStore.PhotoSet {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return try MealPhotoStore.savePhotoSet(image)
    }
}
