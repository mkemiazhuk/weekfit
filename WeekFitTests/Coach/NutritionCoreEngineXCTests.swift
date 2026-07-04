import XCTest
@testable import WeekFit

@MainActor
final class NutritionCoreEngineXCTests: XCTestCase {

    func testCalculate_returnsFullFrontendPayload() {
        let metrics = CoachMetricsBuilder.metrics()
        let profile = CoachMetricsBuilder.standardProfile()
        let workout = PlannedActivityBuilder.upcomingWorkout(hoursFromNow: 2)

        let result = NutritionCoreEngine.calculate(
            from: metrics,
            profile: profile,
            activities: [workout]
        )

        XCTAssertGreaterThan(result.targetCalories, 0)
        XCTAssertEqual(result.consumedCalories, metrics.calories)
        XCTAssertFalse(result.status.isEmpty)
        XCTAssertFalse(result.recommendation.isEmpty)
        XCTAssertFalse(result.activeInsights.isEmpty)
        XCTAssertGreaterThanOrEqual(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 100)
        XCTAssertEqual(result.decision.primaryStrategy, result.brain.testDecision.primaryStrategy)
    }

    func testCalculate_overloadDay_statusAndInsightsAlign() {
        let metrics = CoachMetricsBuilder.metrics(
            protein: 180,
            carbs: 350,
            fats: 90,
            calories: 3000
        )
        let profile = CoachMetricsBuilder.standardProfile()

        let result = NutritionCoreEngine.calculate(
            from: metrics,
            profile: profile,
            activities: []
        )

        if result.brain.fuel == HumanBrain.FuelState.overfueled
            || result.decision.primaryStrategy == PrimaryStrategy.overload {
            XCTAssertTrue(
                result.status.contains("Overload") || result.status.contains("Strain")
            )
            XCTAssertTrue(result.activeInsights.contains { $0.actionLabel == "Stop Eating" })
        }
    }

    func testCalculate_decisionMatchesInsightFactory() {
        let metrics = CoachMetricsBuilder.metrics(protein: 20, carbs: 30, calories: 400)
        let result = NutritionCoreEngine.calculate(
            from: metrics,
            profile: CoachMetricsBuilder.standardProfile(),
            activities: [PlannedActivityBuilder.upcomingWorkout(hoursFromNow: 1)]
        )
        let regenerated = CoachInsightFactory.generateInsights(
            brain: result.brain,
            decision: result.decision
        )
        XCTAssertEqual(regenerated.first?.actionLabel, result.activeInsights.first?.actionLabel)
    }

    func testNutritionViewModelKeepsHealthKitCaloriesWithoutMealActivities() async {
        let viewModel = NutritionViewModel()
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 640,
            waterLiters: 1.2,
            activeCalories: 120,
            sleepHours: 0,
            weightKg: 74
        )

        viewModel.updateNutrition(
            metrics: metrics,
            profile: CoachMetricsBuilder.standardProfile(),
            plannedActivities: [],
            debugSource: "test.healthKitCaloriesNoMeals"
        )

        XCTAssertEqual(viewModel.currentMetrics?.calories, 640)
        XCTAssertGreaterThan(viewModel.nutritionPercent, 0)
    }

    func testNutritionViewModelKeepsIncomingWaterWhenNoHydrationActivities() async {
        let viewModel = NutritionViewModel()
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 640,
            waterLiters: 1.2,
            activeCalories: 120,
            sleepHours: 0,
            weightKg: 74
        )

        viewModel.updateNutrition(
            metrics: metrics,
            profile: CoachMetricsBuilder.standardProfile(),
            plannedActivities: [],
            debugSource: "test.healthKitWaterNoHydrationLogs"
        )

        XCTAssertEqual(viewModel.currentMetrics?.waterLiters, 1.2)
        XCTAssertEqual(viewModel.coachMetricsSnapshot?.nutritionContext.waterCurrent, 1.2)
    }

    func testCoachInputProviderPreservesHealthKitNutritionWithoutMeals() async {
        let healthManager = HealthManager()
        healthManager.weight = 74
        healthManager.heightCm = 180
        healthManager.age = 35
        healthManager.biologicalSex = .male
        healthManager.calories = 640
        healthManager.protein = 42
        healthManager.carbs = 81
        healthManager.fats = 18
        healthManager.fiber = 7
        healthManager.waterLiters = 1.2
        healthManager.activeCalories = 120
        healthManager.sleepHours = 7.1

        let nutritionViewModel = NutritionViewModel()
        let coordinator = CoachCoordinator()
        let provider = CoachInputProvider()

        provider.refreshFromCurrentState(
            selectedDate: CoachTestClock.reference,
            dayActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coordinator,
            source: "test.providerPreservesHealthKitNutrition"
        )

        XCTAssertEqual(nutritionViewModel.currentMetrics?.calories, 640)
        XCTAssertEqual(nutritionViewModel.currentMetrics?.protein, 42)
        XCTAssertEqual(nutritionViewModel.currentMetrics?.waterLiters, 1.2)
        XCTAssertEqual(provider.lastInput?.nutritionContext?.caloriesCurrent, 640)
        XCTAssertEqual(provider.lastInput?.nutritionContext?.proteinCurrent, 42)
        XCTAssertEqual(provider.lastInput?.nutritionContext?.waterCurrent, 1.2)
    }
}
