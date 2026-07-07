import XCTest
@testable import WeekFit

@MainActor
final class DailyStateSnapshotBuilderXCTests: XCTestCase {

    func testBuildSeparatesSelectedDayActivitiesFromFullCoachContext() async {
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

    func testBuildPreservesHighestAvailableNutritionInputs() async {
        let today = CoachTestClock.reference
        let todayStart = Calendar.current.startOfDay(for: today)
        let healthManager = makeHealthManager(
            calories: 300,
            protein: 42,
            carbs: 30,
            fats: 10,
            fiber: 4,
            waterLiters: 1.2
        )
        healthManager.prepareForDisplayDay(todayStart)
        healthManager.calories = 300
        healthManager.protein = 42
        healthManager.carbs = 30
        healthManager.fats = 10
        healthManager.fiber = 4
        healthManager.waterLiters = 1.2
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
            referenceDate: today,
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

    func testBuildDoesNotCarryPreviousDayNutritionIntoNewDay() async {
        let today = CoachTestClock.reference
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let healthManager = makeHealthManager()
        let nutritionViewModel = NutritionViewModel()

        nutritionViewModel.updateNutrition(
            metrics: DailyNutritionMetrics(
                protein: 120,
                carbs: 180,
                fats: 55,
                fiber: 20,
                calories: 2_400,
                waterLiters: 2.5,
                activeCalories: 500,
                sleepHours: 7.5,
                weightKg: 74
            ),
            profile: CoachMetricsBuilder.standardProfile(),
            plannedActivities: [],
            referenceDate: yesterday,
            debugSource: "test.seedYesterdayNutrition"
        )

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: today,
            allPlannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: today,
            source: "test.newDayReset"
        )

        XCTAssertEqual(snapshot.nutritionMetrics.calories, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.protein, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.carbs, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.fats, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.waterLiters, 0)
    }

    func testBuildClearsStaleHealthKitTotalsWhenSelectedDayChanges() async {
        let today = CoachTestClock.reference
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        let healthManager = makeHealthManager()
        let nutritionViewModel = NutritionViewModel()

        healthManager.prepareForDisplayDay(yesterdayStart)
        healthManager.calories = 2_100
        healthManager.protein = 140
        healthManager.carbs = 210
        healthManager.fats = 65
        healthManager.waterLiters = 2.4

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: today,
            allPlannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: today,
            source: "test.staleHealthKitTotals"
        )

        XCTAssertEqual(snapshot.nutritionMetrics.calories, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.protein, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.carbs, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.fats, 0)
        XCTAssertEqual(snapshot.nutritionMetrics.waterLiters, 0)
    }

    func testBuildCreatesActualLoadFromHealthManager() async {
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
