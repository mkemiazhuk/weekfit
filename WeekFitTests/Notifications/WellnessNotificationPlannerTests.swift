import XCTest
@testable import WeekFit
import WeekFitPlanner

final class WellnessNotificationPlannerTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    func testRecoveryDecisionSchedulesAfterWorkoutYesterday() {
        let now = makeDate(year: 2026, month: 7, day: 7, hour: 8, minute: 0)
        let yesterdayWorkout = makeActivity(
            id: "workout-1",
            type: "workout",
            date: makeDate(year: 2026, month: 7, day: 6, hour: 10, minute: 0),
            isCompleted: true
        )

        let decision = WellnessNotificationPlanner.recoveryDecision(
            for: WellnessNotificationContext(
                now: now,
                recoveryPercent: 80,
                plannedActivities: [yesterdayWorkout],
                recoveryScheduledDayKey: nil
            ),
            calendar: calendar
        )

        XCTAssertTrue(decision.shouldSchedule)
        XCTAssertNotNil(decision.fireDate)
        XCTAssertEqual(decision.dayKeyToMark, "2026-07-07")
    }

    func testRecoveryDecisionSkipsWhenRecoveryAlreadyPlannedToday() {
        let now = makeDate(year: 2026, month: 7, day: 7, hour: 8, minute: 0)
        let recovery = makeActivity(
            id: "recovery-1",
            type: "recovery",
            date: makeDate(year: 2026, month: 7, day: 7, hour: 20, minute: 0)
        )

        let decision = WellnessNotificationPlanner.recoveryDecision(
            for: WellnessNotificationContext(
                now: now,
                recoveryPercent: 40,
                plannedActivities: [recovery],
                recoveryScheduledDayKey: nil
            ),
            calendar: calendar
        )

        XCTAssertFalse(decision.shouldSchedule)
    }

    func testRecoveryDecisionSkipsWhenAlreadyScheduledToday() {
        let now = makeDate(year: 2026, month: 7, day: 7, hour: 8, minute: 0)

        let decision = WellnessNotificationPlanner.recoveryDecision(
            for: WellnessNotificationContext(
                now: now,
                recoveryPercent: 40,
                plannedActivities: [],
                recoveryScheduledDayKey: "2026-07-07"
            ),
            calendar: calendar
        )

        XCTAssertFalse(decision.shouldSchedule)
    }

    func testRecoveryDecisionUsesLowRecoveryWithoutWorkoutYesterday() {
        let now = makeDate(year: 2026, month: 7, day: 7, hour: 10, minute: 0)

        let decision = WellnessNotificationPlanner.recoveryDecision(
            for: WellnessNotificationContext(
                now: now,
                recoveryPercent: 52,
                plannedActivities: [],
                recoveryScheduledDayKey: nil
            ),
            calendar: calendar
        )

        XCTAssertTrue(decision.shouldSchedule)
    }

    private func makeActivity(
        id: String,
        type: String,
        date: Date,
        isCompleted: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            id: id,
            date: date,
            type: type,
            title: "Test",
            durationMinutes: 30,
            icon: "leaf",
            imageName: "recovery-breathing",
            colorRed: 1,
            colorGreen: 1,
            colorBlue: 1,
            isCompleted: isCompleted
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
