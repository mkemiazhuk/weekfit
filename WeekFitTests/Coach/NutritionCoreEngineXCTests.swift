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
}
