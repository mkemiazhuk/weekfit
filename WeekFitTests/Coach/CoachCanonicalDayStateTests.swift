import XCTest
@testable import WeekFit

final class CoachCanonicalDayStateTests: XCTestCase {

    private let now = CoachTestClock.reference

    func testHydrationLogsAreNotCoachRelevant() {
        let completedWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: -10, from: now)
        )
        let futureWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: 30, from: now)
        )
        futureWater.isCompleted = false

        XCTAssertFalse(CoachCanonicalDayState.isCoachRelevantActivity(completedWater))
        XCTAssertFalse(CoachCanonicalDayState.isCoachRelevantActivity(futureWater))
        XCTAssertTrue(CoachCanonicalDayState.coachRelevantActivities(from: [completedWater, futureWater]).isEmpty)
    }

    func testNutritionLogsAreNotCoachRelevant() {
        let plannedMeal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: 30, from: now),
            completed: false
        )
        let coffee = PlannedActivityBuilder.meal(
            title: "Coffee",
            at: CoachTestClock.offset(minutes: -10, from: now),
            calories: 5,
            protein: 0,
            carbs: 0,
            fats: 0,
            completed: true
        )
        let futureWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: 10, from: now)
        )
        futureWater.isCompleted = false

        let activities = [coffee, futureWater, plannedMeal]
        XCTAssertTrue(CoachCanonicalDayState.coachRelevantActivities(from: activities).isEmpty)
    }

    func testWorkoutIsCoachRelevant() {
        let strength = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: 60, from: now),
            durationMinutes: 60
        )
        XCTAssertTrue(CoachCanonicalDayState.isCoachRelevantActivity(strength))
    }
}
