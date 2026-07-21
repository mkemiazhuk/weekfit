import XCTest
@testable import WeekFit

@MainActor
final class OnboardingCoachPreviewTests: XCTestCase {

    private func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 21
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    func testLocalDayPeriodWindowsMatchDesignTable() {
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 5)), .morning)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 10, minute: 59)), .morning)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 11)), .afternoon)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 16, minute: 59)), .afternoon)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 17)), .evening)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 20, minute: 59)), .evening)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 21)), .night)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 23, minute: 48)), .night)
        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: date(hour: 4, minute: 59)), .night)
    }

    func testNightNeverSuggestsDaytimeTrainingOrBreakfast() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 23, minute: 48),
                goal: .fatLoss,
                recoveryPercent: 90,
                sleepHours: 7.2,
                health: .connected
            )
        )

        XCTAssertEqual(preview.greetingTitle, WeekFitLocalizedString("onboarding.v12.ready.title.night"))
        XCTAssertFalse(preview.primaryAction.lowercased().contains("train before"))
        XCTAssertFalse(preview.primaryAction.lowercased().contains("run"))
        XCTAssertFalse(preview.secondaryAction.lowercased().contains("breakfast"))
        XCTAssertFalse(preview.secondaryAction.lowercased().contains("lunch"))
        XCTAssertTrue(preview.primaryAction.lowercased().contains("sleep") || preview.primaryAction.lowercased().contains("late"))
    }

    func testMorningHighRecoveryFeelsLikeTrainDay() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 8),
                goal: .fatLoss,
                recoveryPercent: 90,
                sleepHours: 7.5,
                health: .connected
            )
        )

        XCTAssertEqual(preview.greetingTitle, WeekFitLocalizedString("onboarding.v12.ready.title.morning"))
        XCTAssertEqual(
            preview.supportingMessage,
            WeekFitLocalizedString("onboarding.coachPreview.support.morning.good")
        )
        XCTAssertEqual(
            preview.primaryAction,
            WeekFitLocalizedString("onboarding.coachPreview.action.train.day.good")
        )
    }

    func testEveningFatLossProtectsTomorrow() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 19),
                goal: .fatLoss,
                recoveryPercent: 72,
                health: .limited
            )
        )

        XCTAssertEqual(preview.greetingTitle, WeekFitLocalizedString("onboarding.v12.ready.title.evening"))
        XCTAssertEqual(
            preview.supportingMessage,
            WeekFitLocalizedString("onboarding.coachPreview.support.evening.recoveredWell")
        )
        XCTAssertEqual(
            preview.primaryAction,
            WeekFitLocalizedString("onboarding.coachPreview.action.train.evening.fatLoss")
        )
    }

    func testShortSleepAtNightPrioritizesRecovery() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 22, minute: 30),
                goal: .muscleGain,
                recoveryPercent: 48,
                sleepHours: 4.5,
                health: .connected
            )
        )

        XCTAssertEqual(
            preview.supportingMessage,
            WeekFitLocalizedString("onboarding.coachPreview.support.windDown.shortSleep")
        )
        XCTAssertEqual(
            preview.recoveryAction,
            WeekFitLocalizedString("onboarding.coachPreview.action.recovery.night.low")
        )
    }

    func testUsesDeviceCalendarTimezone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // 2026-07-21 03:00 UTC = 23:00 previous evening in New York (EDT, UTC-4)
        var utc = DateComponents()
        utc.year = 2026
        utc.month = 7
        utc.day = 21
        utc.hour = 3
        utc.minute = 0
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        let instant = Calendar(identifier: .gregorian).date(from: utc)!

        XCTAssertEqual(WeekFitLocalDayPeriod.from(now: instant, calendar: calendar), .night)

        let preview = OnboardingCoachPreview.build(
            .init(
                now: instant,
                calendar: calendar,
                goal: .maintenance,
                health: .unavailable
            )
        )
        XCTAssertEqual(preview.greetingTitle, WeekFitLocalizedString("onboarding.v12.ready.title.night"))
    }
}
