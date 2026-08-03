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

        guard case .assetImage(let name, _) = visual else {
            return XCTFail("Expected primary ingredient asset for matched meal, got \(visual)")
        }
        XCTAssertTrue(name.hasPrefix("ingredient-"))
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

        guard case .assetImage(let name, let kind) = visual else {
            return XCTFail("Expected inferred ingredient asset, got \(visual)")
        }
        XCTAssertTrue(
            name == "ingredient-turkey" || name == "ingredient-cucumber",
            "Unexpected primary ingredient \(name)"
        )
        XCTAssertEqual(kind, .meal)
    }

    func testNutritionVisualInfersFromRussianTitleWithGramAmounts() throws {
        let activity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: "Индейка (150 г) + Огурец (100 г)",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "",
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

        guard case .assetImage(let name, _) = visual else {
            return XCTFail("Expected inferred ingredient asset, got \(visual)")
        }
        XCTAssertTrue(
            name == "ingredient-turkey" || name == "ingredient-cucumber",
            "Unexpected primary ingredient \(name)"
        )
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

        // Older Quick Log rows may still carry a Russian short title while the
        // catalog keeps English; newer rows persist the canonical English title.
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

        guard case .assetImage(let name, _) = visual else {
            return XCTFail("Expected primary ingredient asset for localized Quick Log title, got \(visual)")
        }
        XCTAssertEqual(name, "ingredient-turkey")
    }

    func testQuickLogProfilePersistsCanonicalMealTitleNotLocalized() {
        let meal = Meals(
            id: "ql_canonical_title",
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

        let profile = QuickLogNutritionProfile.from(meal: meal)
        XCTAssertEqual(profile.title, "Turkey Cucumber")
        XCTAssertEqual(profile.imageName, "ingredient-turkey")
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

    func testQuickLogDrinkPersistsEnglishTitleAndIngredientAsset() {
        let item = QuickItem(
            id: "drink_iced_coffee",
            title: "Iced Coffee",
            subtitle: "250 ml",
            category: .drink,
            imageName: "ingredient-iced-coffee",
            icon: "cup.and.saucer.fill",
            calories: 80,
            protein: 1,
            carbs: 12,
            fats: 2,
            fiber: 0,
            defaultServingAmount: 250,
            servingUnit: .ml,
            gramsPerServing: nil,
            mlPerServing: 250
        )

        let profile = QuickLogNutritionProfile.from(item: item)
        XCTAssertEqual(profile.title, "Iced Coffee")
        XCTAssertEqual(profile.imageName, "ingredient-iced-coffee")
        XCTAssertEqual(profile.kind, .drink)

        // Russian UI maps the stored English title for display; the activity
        // itself stays English so Nutrition Details can keep the asset.
        XCTAssertEqual(
            QuickItem.localizedTitle(forStoredTitle: "Iced Coffee"),
            WeekFitUsesRussianLanguage() ? "Холодный кофе" : "Iced Coffee"
        )
    }

    func testNutritionVisualResolvesDrinkAssetFromActivityImageName() throws {
        let activity = PlannedActivity(
            date: Date(),
            type: "drink",
            title: "Iced Coffee",
            durationMinutes: 5,
            icon: "cup.and.saucer.fill",
            imageName: "ingredient-iced-coffee",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 80,
            protein: 1,
            carbs: 12,
            fats: 2,
            fiber: 0,
            source: "today"
        )

        let visual = try XCTUnwrap(
            PlanTimelineNutritionVisualResolver.resolve(
                for: activity,
                customMeals: []
            )
        )

        guard case .assetImage(let name, let kind) = visual else {
            return XCTFail("Expected drink asset visual, got \(visual)")
        }
        XCTAssertEqual(name, "ingredient-iced-coffee")
        XCTAssertEqual(kind, .drink)
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
