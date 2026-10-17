import XCTest
import WeekFitPlanner
@testable import WeekFit

final class CoachEveningRecapEligibilityTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testBefore20DoesNotShowRecap() {
        let now = date(hour: 19, minute: 59)
        XCTAssertFalse(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [],
                calendar: calendar
            )
        )
    }

    func testAfter20WithEmptyPlanShowsRecap() {
        let now = date(hour: 20, minute: 0)
        XCTAssertTrue(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [],
                calendar: calendar
            )
        )
    }

    func testUpcomingWorkoutBlocksRecap() {
        let now = date(hour: 20, minute: 30)
        let ride = PlannedActivity(
            date: date(hour: 21, minute: 0),
            type: "workout",
            title: "Evening Ride",
            durationMinutes: 60,
            icon: "bicycle",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            source: "planner"
        )
        XCTAssertFalse(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [ride],
                calendar: calendar
            )
        )
    }

    func testLiveTodaySessionBlocksRecap() {
        let now = date(hour: 20, minute: 30)
        let walk = PlannedActivity(
            date: date(hour: 20, minute: 0),
            type: "recovery",
            title: "Walk",
            durationMinutes: 20,
            icon: "figure.walk",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            source: "today"
        )
        XCTAssertTrue(walk.isUserStartedLiveSession(now: now))
        XCTAssertFalse(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [walk],
                calendar: calendar
            )
        )
    }

    func testCompletedAndSkippedDoNotBlock() {
        let now = date(hour: 21, minute: 0)
        let done = PlannedActivity(
            date: date(hour: 18, minute: 0),
            type: "workout",
            title: "Ride",
            durationMinutes: 60,
            icon: "bicycle",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isCompleted: true,
            source: "planner"
        )
        done.actualDurationMinutes = 55
        let skipped = PlannedActivity(
            date: date(hour: 19, minute: 0),
            type: "workout",
            title: "Gym",
            durationMinutes: 45,
            icon: "dumbbell.fill",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isSkipped: true,
            source: "planner"
        )
        let meal = PlannedActivity(
            date: date(hour: 22, minute: 0),
            type: "meal",
            title: "Dinner",
            durationMinutes: 20,
            icon: "fork.knife",
            colorRed: 0.9,
            colorGreen: 0.5,
            colorBlue: 0.2,
            source: "today"
        )
        XCTAssertTrue(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [done, skipped, meal],
                calendar: calendar
            )
        )
    }

    func testOverdueUnresolvedWorkoutBlocksRecap() {
        let now = date(hour: 21, minute: 0)
        let overdue = PlannedActivity(
            date: date(hour: 18, minute: 0),
            type: "workout",
            title: "Tempo Run",
            durationMinutes: 45,
            icon: "figure.run",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            source: "planner"
        )
        XCTAssertFalse(
            CoachEveningRecapEligibility.shouldShowEveningRecap(
                now: now,
                plannedActivities: [overdue],
                calendar: calendar
            )
        )
    }

    func testNextRecheckIsLocal20BeforeEvening() {
        let now = date(hour: 19, minute: 30)
        let next = CoachEveningRecapEligibility.nextRecheckDate(after: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: next), 20)
        XCTAssertEqual(calendar.component(.minute, from: next), 0)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: now))
    }

    func testNextRecheckIsNextDayAfterEvening() {
        let now = date(hour: 21, minute: 15)
        let next = CoachEveningRecapEligibility.nextRecheckDate(after: now, calendar: calendar)
        XCTAssertFalse(calendar.isDate(next, inSameDayAs: now))
        XCTAssertGreaterThan(next, now)
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 16
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
