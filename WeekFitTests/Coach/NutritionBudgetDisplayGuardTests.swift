import XCTest
@testable import WeekFit

@MainActor
final class NutritionBudgetDisplayGuardTests: XCTestCase {

    private let profile = UserNutritionProfile(
        weightKg: 78,
        heightCm: 180,
        age: 35,
        sex: .male,
        goal: .fatLoss
    )

    func testTodayDisplayedRemainingMatchesNutritionBudgetRemaining() {
        let budget = makeBudget(activeCalories: 965, consumed: 1500)

        let displayedRemaining = TodayNutritionDisplayMetrics.remainingCalories(from: budget)

        XCTAssertFalse(budget.isOverBudget)
        XCTAssertEqual(displayedRemaining, budget.remainingCalories)
        XCTAssertEqual(displayedRemaining, Int(budget.remaining.rounded()))
    }

    func testTodayDisplayedOverBudgetUsesCanonicalOverCalories() {
        let budget = makeBudget(activeCalories: 965, consumed: 2364)

        XCTAssertTrue(budget.isOverBudget)
        XCTAssertEqual(budget.remainingCalories, 0)
        XCTAssertEqual(
            TodayNutritionDisplayMetrics.remainingCalories(from: budget),
            budget.overCalories
        )
    }

    func testTodayDisplayDoesNotUseLegacyDoubleCountFormula() {
        let budget = makeBudget(activeCalories: 965, consumed: 2364)
        let targetCalories = budget.totalCalories

        let legacyRemaining = TodayNutritionDisplayMetrics.legacyDoubleCountRemaining(
            targetCalories: targetCalories,
            activeCalories: 965,
            consumed: 2364
        )

        XCTAssertNotEqual(
            Double(TodayNutritionDisplayMetrics.remainingCalories(from: budget)),
            legacyRemaining
        )
        XCTAssertGreaterThan(legacyRemaining, budget.remaining)
    }

    func testIncreasingActiveEnergyOnlyAffectsBudgetThroughEngineGoalFactor() {
        let consumed = 1500.0
        let lowActivityBudget = makeBudget(activeCalories: 200, consumed: consumed)
        let highActivityBudget = makeBudget(activeCalories: 600, consumed: consumed)

        let budgetDelta = highActivityBudget.totalCalories - lowActivityBudget.totalCalories
        let activeDelta = 600.0 - 200.0

        XCTAssertGreaterThan(highActivityBudget.totalCalories, lowActivityBudget.totalCalories)
        XCTAssertLessThan(budgetDelta, activeDelta)

        let legacyLowRemaining = TodayNutritionDisplayMetrics.legacyDoubleCountRemaining(
            targetCalories: lowActivityBudget.totalCalories,
            activeCalories: 200,
            consumed: consumed
        )
        let legacyHighRemaining = TodayNutritionDisplayMetrics.legacyDoubleCountRemaining(
            targetCalories: highActivityBudget.totalCalories,
            activeCalories: 600,
            consumed: consumed
        )
        let legacyDelta = legacyHighRemaining - legacyLowRemaining

        XCTAssertLessThan(budgetDelta, legacyDelta)
        XCTAssertEqual(
            highActivityBudget.remainingCalories - lowActivityBudget.remainingCalories,
            Int(budgetDelta.rounded())
        )
    }

    func testCanonicalBudgetSourceMatchesNutritionViewModelAndCoachContext() async {
        let viewModel = NutritionViewModel()
        var calendar = Calendar.current
        calendar.timeZone = .current
        var noonComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        noonComponents.hour = 12
        let referenceDate = calendar.date(from: noonComponents) ?? Date()

        let metrics = DailyNutritionMetrics(
            protein: 140,
            carbs: 220,
            fats: 70,
            fiber: 25,
            calories: 1500,
            waterLiters: 2.5,
            activeCalories: 965,
            sleepHours: 7,
            weightKg: 78
        )

        viewModel.updateNutrition(
            metrics: metrics,
            profile: profile,
            plannedActivities: [],
            recoveryContext: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 7),
            referenceDate: referenceDate
        )

        let budget = NutritionBudgetCalculator.canonicalBudget(from: viewModel)
        guard let result = viewModel.nutritionResult else {
            XCTFail("Expected nutrition result after updateNutrition")
            return
        }
        guard let snapshot = viewModel.coachMetricsSnapshot else {
            XCTFail("Expected coach metrics snapshot after updateNutrition")
            return
        }

        XCTAssertEqual(budget.totalCalories, result.targetCalories, accuracy: 0.01)
        XCTAssertEqual(budget.totalCalories, snapshot.nutritionContext.caloriesGoal, accuracy: 0.01)
        XCTAssertEqual(budget.consumed, metrics.calories, accuracy: 0.01)
        XCTAssertEqual(
            TodayNutritionDisplayMetrics.progressPercent(from: budget),
            viewModel.nutritionPercent
        )
        XCTAssertEqual(
            TodayNutritionDisplayMetrics.remainingCalories(from: budget),
            budget.remainingCalories
        )
    }

    func testMaintenanceGoalCreditsEightyPercentOfActiveEnergyInBudgetOnly() {
        let maintenanceProfile = UserNutritionProfile(
            weightKg: 80,
            heightCm: 180,
            age: 35,
            sex: .male,
            goal: .maintenance
        )
        let activeCalories = 500.0
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 1200,
            waterLiters: 0,
            activeCalories: activeCalories,
            sleepHours: 7,
            weightKg: 80
        )

        let goalSet = NutritionGoalEngine.calculate(metrics: metrics, profile: maintenanceProfile)
        let budget = NutritionBudgetCalculator.make(goalSet: goalSet, consumed: 1200)

        let activityCredit = budget.totalCalories - goalSet.baseDay.calories
        XCTAssertEqual(activityCredit, activeCalories * 0.8, accuracy: 0.01)

        let legacyRemaining = TodayNutritionDisplayMetrics.legacyDoubleCountRemaining(
            targetCalories: budget.totalCalories,
            activeCalories: activeCalories,
            consumed: 1200
        )
        XCTAssertGreaterThan(legacyRemaining, budget.remaining)
    }

    func testAuditExampleNoLongerShowsInflatedRemainingCalories() {
        let budget = makeBudget(activeCalories: 965, consumed: 2364)

        XCTAssertLessThan(budget.remainingCalories, 492)
        XCTAssertGreaterThan(budget.totalCalories, 1800)
        XCTAssertLessThan(budget.totalCalories, 2400)
    }

    private func makeBudget(activeCalories: Double, consumed: Double) -> NutritionBudget {
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: consumed,
            waterLiters: 0,
            activeCalories: activeCalories,
            sleepHours: 7,
            weightKg: profile.weightKg
        )
        let goalSet = NutritionGoalEngine.calculate(metrics: metrics, profile: profile)
        return NutritionBudgetCalculator.make(goalSet: goalSet, consumed: consumed)
    }
}
