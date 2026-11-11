import XCTest
@testable import WeekFit

final class ActivityInviteTimeTests: XCTestCase {
    func testSevenSixteenDoesNotInviteARun() {
        XCTAssertFalse(ActivityInviteTime.allows(imageName: "workout-running", hour: 19))
        XCTAssertFalse(ActivityInviteTime.allows(imageName: "workout-hiking", hour: 19))
        XCTAssertFalse(ActivityInviteTime.allows(imageName: "workout-cycling", hour: 19))
        XCTAssertFalse(ActivityInviteTime.allows(imageName: "workout-hiit", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "workout-swimming", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "workout-fullbody", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "workout-squash", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "recovery-walk", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "recovery-yoga", hour: 19))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "recovery-breathing", hour: 23))
        XCTAssertFalse(ActivityInviteTime.allows(imageName: "recovery-walk", hour: 23))
        XCTAssertTrue(ActivityInviteTime.allows(imageName: "workout-running", hour: 8))
    }

    func testEveningFrequentPicksSkipAMostUsedRun() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 19, minute: 16))!
        let picks = QuickActivityFrequentComposer.picks(
            options: PlannerType.workout.options,
            usage: ["workout-running": QuickActivityUsageStore.Entry(count: 8, lastUsedAt: now)],
            now: now,
            calendar: calendar,
            allowsCycling: false
        )
        XCTAssertFalse(picks.contains { $0.option.imageName == "workout-running" })
        XCTAssertEqual(picks.first?.option.imageName, "workout-swimming")
    }

    func testMorningFrequentPickCanBeARun() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 8, minute: 0))!
        let picks = QuickActivityFrequentComposer.picks(
            options: PlannerType.workout.options,
            usage: [:],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(picks.first?.option.imageName, "workout-running")
    }

    func testEveningRepeatOfARunBecomesAWalk() {
        var weather = ReturnReminderWeather()
        weather.hour = 19
        let offer = ReturnReminderPlanner.day7(
            completions: [
                ReturnReminderCompletion(
                    actionID: "activity.running",
                    completedAt: Date(),
                    opensDirectly: true
                )
            ],
            goal: .maintenance,
            weather: weather
        )
        XCTAssertEqual(offer.actionID, ReturnReminderPlanner.walkID)
    }
}
