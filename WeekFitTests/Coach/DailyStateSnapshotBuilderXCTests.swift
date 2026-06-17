import XCTest
@testable import WeekFit

@MainActor
final class DailyStateSnapshotBuilderXCTests: XCTestCase {

    func testBuildSeparatesSelectedDayActivitiesFromFullCoachContext() {
        let today = CoachTestClock.reference
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let todayMeal = PlannedActivityBuilder.meal(title: "Coffee", at: today, calories: 5)
        let tomorrowWorkout = PlannedActivityBuilder.workout(title: "Run", at: tomorrow)
        let healthManager = makeHealthManager()
        let nutritionViewModel = NutritionViewModel()

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: today,
            allPlannedActivities: [todayMeal, tomorrowWorkout],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: today,
            source: "test.daySlice"
        )

        XCTAssertEqual(snapshot.dayActivities.map(\.id), [todayMeal.id])
        XCTAssertEqual(snapshot.allPlannedActivities.map(\.id), [todayMeal.id, tomorrowWorkout.id])
    }

    func testActivitiesForDayAreSortedByDate() {
        let today = CoachTestClock.reference
        let later = PlannedActivityBuilder.workout(
            title: "Later",
            at: CoachTestClock.offset(minutes: 90, from: today)
        )
        let earlier = PlannedActivityBuilder.workout(
            title: "Earlier",
            at: CoachTestClock.offset(minutes: -90, from: today)
        )

        let activities = DailyStateSnapshotBuilder.activities(
            on: today,
            from: [later, earlier]
        )

        XCTAssertEqual(activities.map(\.title), ["Earlier", "Later"])
    }

    func testBuildPreservesHighestAvailableNutritionInputs() {
        let today = CoachTestClock.reference
        let healthManager = makeHealthManager(
            calories: 300,
            protein: 42,
            carbs: 30,
            fats: 10,
            fiber: 4,
            waterLiters: 1.2
        )
        let nutritionViewModel = NutritionViewModel()
        nutritionViewModel.updateNutrition(
            metrics: DailyNutritionMetrics(
                protein: 20,
                carbs: 81,
                fats: 18,
                fiber: 7,
                calories: 640,
                waterLiters: 0.8,
                activeCalories: 120,
                sleepHours: 7.1,
                weightKg: 74
            ),
            profile: CoachMetricsBuilder.standardProfile(),
            plannedActivities: [],
            debugSource: "test.seedCurrentNutrition"
        )

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: today,
            allPlannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: today,
            source: "test.preserveNutrition"
        )

        XCTAssertEqual(snapshot.nutritionMetrics.calories, 640)
        XCTAssertEqual(snapshot.nutritionMetrics.protein, 42)
        XCTAssertEqual(snapshot.nutritionMetrics.carbs, 81)
        XCTAssertEqual(snapshot.nutritionMetrics.fats, 18)
        XCTAssertEqual(snapshot.nutritionMetrics.fiber, 7)
        XCTAssertEqual(snapshot.nutritionMetrics.waterLiters, 1.2)
    }

    func testBuildCreatesActualLoadFromHealthManager() {
        let today = CoachTestClock.reference
        let healthManager = makeHealthManager(activeCalories: 420, exerciseMinutes: 45, standHours: 8)
        let nutritionViewModel = NutritionViewModel()

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: today,
            allPlannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: today,
            source: "test.actualLoad"
        )

        XCTAssertEqual(snapshot.actualLoad.source, .healthKitSamplesWithAppGoalEstimate)
        XCTAssertEqual(snapshot.actualLoad.activeCalories, 420)
        XCTAssertEqual(snapshot.actualLoad.exerciseMinutes, 45)
        XCTAssertEqual(snapshot.actualLoad.standHours, 8)
        XCTAssertNotNil(snapshot.actualLoad.activityGoalCalories)
        XCTAssertNotNil(snapshot.actualLoad.activityProgress)
    }

    private func makeHealthManager(
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fats: Double = 0,
        fiber: Double = 0,
        waterLiters: Double = 0,
        activeCalories: Double = 120,
        exerciseMinutes: Int = 20,
        standHours: Int = 4
    ) -> HealthManager {
        let healthManager = HealthManager()
        healthManager.weight = 74
        healthManager.heightCm = 180
        healthManager.age = 35
        healthManager.biologicalSex = .male
        healthManager.calories = calories
        healthManager.protein = protein
        healthManager.carbs = carbs
        healthManager.fats = fats
        healthManager.fiber = fiber
        healthManager.waterLiters = waterLiters
        healthManager.activeCalories = activeCalories
        healthManager.exerciseMinutes = exerciseMinutes
        healthManager.standHours = standHours
        healthManager.sleepHours = 7.1
        return healthManager
    }
}
