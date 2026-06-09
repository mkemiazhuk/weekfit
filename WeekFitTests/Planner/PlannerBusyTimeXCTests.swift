import XCTest
@testable import WeekFit

final class PlannerBusyTimeXCTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    func testFoodLogDoesNotBlockPlannerAvailability() {
        let slot = date(hour: 17, minute: 45)
        let foodLog = PlannedActivityBuilder.meal(
            title: "Bun",
            at: slot,
            completed: true
        )

        XCTAssertFalse(foodLog.blocksPlannerTime)
        XCTAssertFalse(
            TimelineLayoutEngine.hasTimeConflict(
                newStart: slot,
                durationMinutes: 45,
                activities: [foodLog],
                excluding: nil,
                calendar: calendar
            )
        )
    }

    func testDrinkLogDoesNotBlockPlannerAvailability() {
        let slot = date(hour: 17, minute: 45)
        let drinkLog = PlannedActivityBuilder.hydrationLog(at: slot)

        XCTAssertFalse(drinkLog.blocksPlannerTime)
        XCTAssertFalse(
            TimelineLayoutEngine.hasTimeConflict(
                newStart: slot,
                durationMinutes: 45,
                activities: [drinkLog],
                excluding: nil,
                calendar: calendar
            )
        )
    }

    func testWorkoutBlocksPlannerAvailability() {
        let slot = date(hour: 17, minute: 45)
        let workout = PlannedActivityBuilder.workout(
            title: "Run",
            at: slot,
            durationMinutes: 45
        )

        XCTAssertTrue(workout.blocksPlannerTime)
        XCTAssertTrue(
            TimelineLayoutEngine.hasTimeConflict(
                newStart: slot,
                durationMinutes: 45,
                activities: [workout],
                excluding: nil,
                calendar: calendar
            )
        )
    }

    func testNewFoodEventDoesNotNeedFreeSlot() {
        let slot = date(hour: 17, minute: 45)
        let workout = PlannedActivityBuilder.workout(
            title: "Run",
            at: slot,
            durationMinutes: 45
        )

        XCTAssertFalse(
            TimelineLayoutEngine.hasTimeConflict(
                newStart: slot,
                durationMinutes: 15,
                activities: [workout],
                excluding: nil,
                calendar: calendar,
                newEventBlocksPlannerTime: false
            )
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 9,
            hour: hour,
            minute: minute
        ).date!
    }
}
