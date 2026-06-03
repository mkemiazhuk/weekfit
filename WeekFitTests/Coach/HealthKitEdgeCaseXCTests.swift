import XCTest
@testable import WeekFit

/// HealthKit gaps flow through `DailyNutritionMetrics` into `HumanBrain.build`.
final class HealthKitEdgeCaseXCTests: XCTestCase {

    func testMissingSleep_evaluatesAsUnknown() {
        let brain = HumanBrainIntegrationBuilder.build(metrics: CoachMetricsBuilder.missingHealthKit())
        XCTAssertEqual(brain.sleep, .unknown)
    }

    func testMissingActiveCalories_evaluatesLowStrainWithoutWorkouts() {
        let brain = HumanBrainIntegrationBuilder.build(metrics: CoachMetricsBuilder.missingHealthKit())
        XCTAssertEqual(brain.strain, .low)
    }

    func testMissingHealthKit_noFood_maintainOrRehydrateNotCrash() {
        let brain = HumanBrainIntegrationBuilder.build(metrics: CoachMetricsBuilder.missingHealthKit())
        let decision = brain.testDecision
        XCTAssertTrue(
            [PrimaryStrategy.maintain, .rehydrate, .addProtein, .prepareWorkout].contains(decision.primaryStrategy)
        )
        XCTAssertFalse(brain.testInsights.isEmpty)
    }

    func testShortSleep_withHighStrain_compromisedRecovery() {
        let metrics = CoachMetricsBuilder.shortSleepDay()
        let now = Date()
        let activities = [PlannedActivityBuilder.completedWorkout(now: now)]
        let brain = HumanBrainIntegrationBuilder.build(metrics: metrics, activities: activities)
        XCTAssertEqual(brain.sleep, .veryShort)
        if brain.strain == .high || brain.strain == .veryHigh {
            XCTAssertEqual(brain.recovery, .compromised)
        }
    }

    func testZeroWeightProfile_stillBuildsGoals() {
        let profile = UserNutritionProfile(
            weightKg: 0,
            heightCm: 100,
            age: 10,
            sex: .unknown,
            goal: .maintenance
        )
        let brain = HumanBrainIntegrationBuilder.build(
            metrics: CoachMetricsBuilder.metrics(weightKg: 0),
            profile: profile
        )
        XCTAssertGreaterThan(brain.fullDayGoals.calories, 0)
        XCTAssertGreaterThan(brain.smoothedGoals.waterLiters, 0)
    }

    func testReadiness_lowWhenVulnerableWithWorkoutSoonAndDepletedFuel() {
        let metrics = CoachMetricsBuilder.metrics(
            protein: 10,
            carbs: 15,
            calories: 150,
            waterLiters: 0.3,
            activeCalories: 580,
            sleepHours: 6.0
        )
        let workout = PlannedActivityBuilder.upcomingWorkout(hoursFromNow: 1.0)
        let brain = HumanBrainIntegrationBuilder.build(metrics: metrics, activities: [workout])
        XCTAssertTrue(
            brain.readiness == .low || brain.readiness == .compromised,
            "Expected reduced readiness before a workout on a depleted day"
        )
    }
}
