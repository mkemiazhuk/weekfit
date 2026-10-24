import XCTest
@testable import WeekFit

final class PhotoFoodDiaryLoggerTests: XCTestCase {

    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar
    }

    func testActivityDateUsesExactLoggedClockOnSelectedDay() {
        let calendar = berlin
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let loggedAt = calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 15, hour: 14, minute: 37, second: 12)
        )!

        let result = PhotoFoodDiaryLogger.activityDate(
            forSelectedDay: selectedDay,
            loggedAt: loggedAt,
            calendar: calendar
        )
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: result
        )

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 10)
        XCTAssertEqual(parts.day, 15)
        XCTAssertEqual(parts.hour, 14)
        XCTAssertEqual(parts.minute, 37)
        XCTAssertEqual(parts.second, 12)
    }

    func testActivityDateKeepsSelectedDayWhenLoggedWithLaterClockDay() {
        let calendar = berlin
        // Viewing yesterday, logging "now" at 09:05 → stamp 09:05 on yesterday.
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14))!
        let loggedAt = calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 15, hour: 9, minute: 5, second: 0)
        )!

        let result = PhotoFoodDiaryLogger.activityDate(
            forSelectedDay: selectedDay,
            loggedAt: loggedAt,
            calendar: calendar
        )
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(parts.day, 14)
        XCTAssertEqual(parts.hour, 9)
        XCTAssertEqual(parts.minute, 5)
    }

    func testClockTimeStringIsHourMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 1, day: 1, hour: 14, minute: 7)
        )!
        XCTAssertEqual(
            PhotoFoodDiaryLogger.clockTimeString(from: date, timeZone: calendar.timeZone),
            "14:07"
        )
    }

    @MainActor
    func testPromoteToLibraryCreatesMealAndLinksActivity() throws {
        let component = PhotoFoodComponent(
            id: "c1",
            displayName: "Eggs",
            grams: 100,
            catalogIngredientId: nil,
            preparation: "boiled",
            caloriesPer100g: 155,
            proteinPer100g: 13,
            carbsPer100g: 1.1,
            fatsPer100g: 11,
            fiberPer100g: 0,
            nutritionSource: .photoAIEstimate,
            isAIEstimated: true
        )
        let snapshot = PhotoFoodDiarySnapshot(
            mealName: "Boiled eggs",
            mealSlotRaw: WeekFitMealSlot.breakfast.rawValue,
            components: [component],
            portionMultiplier: 1,
            totals: .init(
                PhotoFoodNutritionTotals(
                    calories: 155,
                    protein: 13,
                    carbs: 1,
                    fats: 11,
                    fiber: 0
                )
            ),
            estimateKind: .estimated,
            captureMethod: PhotoFoodCaptureMethod.camera.rawValue,
            libraryMealId: nil,
            loggedAt: Date()
        )
        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Boiled eggs",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "diary_thumb.jpg",
            colorRed: 0.9,
            colorGreen: 0.5,
            colorBlue: 0.2,
            calories: 155,
            protein: 13,
            carbs: 1,
            fats: 11,
            fiber: 0,
            isCompleted: true,
            source: "today",
            nutritionSnapshotJSON: PhotoFoodNutritionCalculator.encodeSnapshot(snapshot),
            nutritionEstimateKind: PhotoFoodEstimateKind.estimated.rawValue,
            mealSlotRaw: WeekFitMealSlot.breakfast.rawValue,
            diaryPhotoFilename: "diary_thumb.jpg"
        )

        let meal = try PhotoFoodDiaryLogger.promoteToLibrary(
            activity: activity,
            existingMeals: []
        )

        XCTAssertEqual(meal.title, "Boiled eggs")
        XCTAssertEqual(meal.calories, 155)
        XCTAssertEqual(meal.ingredients.count, 1)
        XCTAssertEqual(meal.ingredients.first?.name, "Eggs")
        XCTAssertEqual(meal.ingredients.first?.grams, 100)
        XCTAssertEqual(meal.ingredients.first?.preparation, "boiled")
        XCTAssertEqual(meal.ingredients.first?.calories, 155)
        XCTAssertEqual(meal.ingredients.first?.protein, 13)
        XCTAssertEqual(meal.localPhotoThumbnailFilename, "diary_thumb.jpg")

        let lines = MealIngredientBreakdown.lines(from: meal.ingredients)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.grams, 100)
        let halved = lines[0].scaled(by: 0.5)
        XCTAssertEqual(Int(halved.grams.rounded()), 50)
        XCTAssertEqual(halved.calories, 78)
        XCTAssertEqual(activity.libraryMealId, meal.id)
        let linked = PhotoFoodNutritionCalculator.decodeSnapshot(activity.nutritionSnapshotJSON)
        XCTAssertEqual(linked?.libraryMealId, meal.id)
    }

    func testIngredientBreakdownKeepsRecognizedGramsAndSkipsServingPlaceholder() {
        let ingredients = [
            MealsIngredient(name: "Buckwheat", amount: "200 g"),
            MealsIngredient(name: "Meat patties", amount: "120г", grams: 120),
            MealsIngredient(name: "Serving", amount: "360g"),
            MealsIngredient(name: "Порция", amount: "100г")
        ]

        let lines = MealIngredientBreakdown.lines(from: ingredients)
        XCTAssertEqual(lines.map(\.name), ["Buckwheat", "Meat patties"])
        XCTAssertEqual(lines.map { Int($0.grams.rounded()) }, [200, 120])
        XCTAssertNil(MealsIngredient(name: "Banana", amount: "1").resolvedGrams)
    }
}

final class PlanTimelineLoggedMealRouterTests: XCTestCase {

    func testShouldOpenLoggedMealDetailWhenSnapshotAndNoLibraryLink() {
        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Chicken bowl",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "photo.jpg",
            colorRed: 0.9,
            colorGreen: 0.5,
            colorBlue: 0.2,
            calories: 400,
            isCompleted: true,
            source: "today",
            nutritionSnapshotJSON: #"{"mealName":"Chicken bowl"}"#,
            diaryPhotoFilename: "photo.jpg"
        )

        let libraryMeal = Meals(
            id: "lib_1",
            title: "Chicken bowl",
            subtitle: "",
            imageName: "ingredient-chicken",
            type: .balanced,
            calories: 400,
            protein: 30,
            carbs: 40,
            fats: 10,
            fiber: 2,
            benefits: [],
            ingredients: []
        )

        XCTAssertTrue(
            PlanTimelineRouter.shouldOpenLoggedMealDetail(
                for: activity,
                customMeals: [libraryMeal]
            )
        )
    }

    func testShouldNotOpenLoggedMealDetailWhenLibraryMealLinked() {
        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Chicken bowl",
            durationMinutes: 10,
            icon: "fork.knife",
            imageName: "photo.jpg",
            colorRed: 0.9,
            colorGreen: 0.5,
            colorBlue: 0.2,
            calories: 400,
            isCompleted: true,
            source: "today",
            nutritionSnapshotJSON: #"{"mealName":"Chicken bowl"}"#,
            libraryMealId: "lib_1",
            diaryPhotoFilename: "photo.jpg"
        )
        let libraryMeal = Meals(
            id: "lib_1",
            title: "Chicken bowl",
            subtitle: "",
            imageName: "ingredient-chicken",
            type: .balanced,
            calories: 400,
            protein: 30,
            carbs: 40,
            fats: 10,
            fiber: 2,
            benefits: [],
            ingredients: []
        )

        XCTAssertFalse(
            PlanTimelineRouter.shouldOpenLoggedMealDetail(
                for: activity,
                customMeals: [libraryMeal]
            )
        )
        XCTAssertEqual(
            PlanTimelineRouter.meal(for: activity, customMeals: [libraryMeal]).id,
            "lib_1"
        )
    }
}
