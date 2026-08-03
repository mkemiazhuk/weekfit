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

    private func makeTestPhoto() throws -> MealPhotoStore.PhotoSet {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return try MealPhotoStore.savePhotoSet(image)
    }
}
