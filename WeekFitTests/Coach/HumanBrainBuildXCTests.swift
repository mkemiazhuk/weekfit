import XCTest
@testable import WeekFit

final class HumanBrainBuildXCTests: XCTestCase {

    // MARK: - Timeline / future events

    func testFuture_hasWorkoutSoon_whenWorkoutWithinTwoAndHalfHours() {
        let now = Date()
        let activities = [
            PlannedActivityBuilder.upcomingWorkout(title: "Tempo", hoursFromNow: 1.5, now: now)
        ]
        let brain = HumanBrainIntegrationBuilder.build(activities: activities)
        XCTAssertTrue(brain.future.hasWorkoutSoon)
        XCTAssertEqual(brain.future.nextWorkout?.title, "Tempo")
        XCTAssertLessThanOrEqual(brain.future.hoursToNextWorkout ?? 99, 2.5)
    }

    func testFuture_hasWorkoutSoon_false_whenWorkoutFarAway() {
        let now = Date()
        let activities = [
            PlannedActivityBuilder.upcomingWorkout(hoursFromNow: 5, now: now)
        ]
        let brain = HumanBrainIntegrationBuilder.build(activities: activities)
        XCTAssertFalse(brain.future.hasWorkoutSoon)
        XCTAssertTrue(brain.future.hasUpcomingWorkout)
    }

    func testFuture_ignoresCompletedOrSkippedWorkouts() {
        let now = Date()
        var completed = PlannedActivityBuilder.upcomingWorkout(title: "Done", hoursFromNow: 1, now: now)
        completed.isCompleted = true
        let skipped = PlannedActivityBuilder.workout(
            title: "Skipped",
            at: now.addingTimeInterval(3600),
            skipped: true
        )
        let brain = HumanBrainIntegrationBuilder.build(activities: [completed, skipped])
        XCTAssertFalse(brain.future.hasUpcomingWorkout)
    }

    func testPast_missedItemsCount_whenEventEndedWithoutStatus() {
        let now = Date()
        let activities = [PlannedActivityBuilder.missedEvent(endedHoursAgo: 1, now: now)]
        let brain = HumanBrainIntegrationBuilder.build(activities: activities)
        XCTAssertEqual(brain.past.missedItemsCount, 1)
    }

    func testPast_completedWorkoutsIncreaseStrain() {
        let now = Date()
        let activities = [
            PlannedActivityBuilder.completedWorkout(completedHoursAgo: 2, now: now),
            PlannedActivityBuilder.completedWorkout(title: "Lift", completedHoursAgo: 4, now: now)
        ]
        let metrics = CoachMetricsBuilder.metrics(activeCalories: 300)
        let brain = HumanBrainIntegrationBuilder.build(metrics: metrics, activities: activities)
        XCTAssertEqual(brain.past.completedWorkoutsCount, 2)
        XCTAssertEqual(brain.strain, .veryHigh)
    }

    func testHasAnyFoodLogged_fromMacros() {
        let withFood = HumanBrainIntegrationBuilder.build(
            metrics: CoachMetricsBuilder.metrics(protein: 30, carbs: 40, calories: 400)
        )
        let empty = HumanBrainIntegrationBuilder.build(
            metrics: CoachMetricsBuilder.metrics(protein: 0, carbs: 0, calories: 0)
        )
        XCTAssertTrue(withFood.hasAnyFoodLogged)
        XCTAssertFalse(empty.hasAnyFoodLogged)
    }

    func testIntegration_prepareWorkoutDecision_withUpcomingWorkoutAndLowFuel() {
        let now = Date()
        let workout = PlannedActivityBuilder.upcomingWorkout(hoursFromNow: 1.2, now: now)
        let metrics = CoachMetricsBuilder.metrics(protein: 10, carbs: 20, calories: 200, activeCalories: 100)
        let brain = HumanBrainIntegrationBuilder.build(metrics: metrics, activities: [workout])
        XCTAssertEqual(brain.testDecision.primaryStrategy, PrimaryStrategy.prepareWorkout)
    }
}
