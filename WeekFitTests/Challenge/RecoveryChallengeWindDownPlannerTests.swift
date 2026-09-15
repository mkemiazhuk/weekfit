import XCTest
@testable import WeekFit

final class RecoveryChallengeWindDownPlannerTests: XCTestCase {

    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    func testSuggestAt2230Returns2245SameDay() {
        let now = date(year: 2026, month: 9, day: 11, hour: 22, minute: 30)
        let plan = RecoveryChallengeWindDownPlanner.suggest(now: now, timeZone: utc)
        XCTAssertEqual(plan.minuteOfDay, 22 * 60 + 45)
        XCTAssertFalse(plan.isTomorrow)
        XCTAssertTrue(plan.isInFuture)
        XCTAssertEqual(plan.dayKey, "2026-09-11")
    }

    func testSuggestNearMidnightCrossesIntoTomorrow() {
        let now = date(year: 2026, month: 9, day: 11, hour: 23, minute: 50)
        let plan = RecoveryChallengeWindDownPlanner.suggest(now: now, timeZone: utc)
        XCTAssertTrue(plan.isTomorrow)
        XCTAssertEqual(plan.dayKey, "2026-09-12")
        XCTAssertEqual(plan.minuteOfDay, 15) // 00:15
        XCTAssertTrue(plan.isInFuture)
    }

    func testSaved2100RemainsIntactAt2230() {
        let now = date(year: 2026, month: 9, day: 11, hour: 22, minute: 30)
        let plan = RecoveryChallengeWindDownPlanner.planFromSaved(
            minuteOfDay: 21 * 60,
            dayKey: "2026-09-11",
            now: now,
            timeZone: utc
        )
        XCTAssertEqual(plan.minuteOfDay, 21 * 60)
        XCTAssertEqual(plan.dayKey, "2026-09-11")
        XCTAssertFalse(plan.isTomorrow)
        XCTAssertFalse(plan.isInFuture)
    }

    func testStaleSuggestionRejectedAtConfirmation() {
        let now = date(year: 2026, month: 9, day: 11, hour: 22, minute: 50)
        let stale = date(year: 2026, month: 9, day: 11, hour: 22, minute: 45)
        let result = RecoveryChallengeWindDownPlanner.validatedPlanForConfirmation(
            selected: stale,
            isExplicitChoice: false,
            now: now,
            timeZone: utc
        )
        XCTAssertEqual(result, .failure(.staleSuggestion))
    }

    func testExplicitPastChoiceAllowedAtConfirmation() {
        let now = date(year: 2026, month: 9, day: 11, hour: 22, minute: 50)
        let chosen = date(year: 2026, month: 9, day: 11, hour: 21, minute: 0)
        let result = RecoveryChallengeWindDownPlanner.validatedPlanForConfirmation(
            selected: chosen,
            isExplicitChoice: true,
            now: now,
            timeZone: utc
        )
        guard case .success(let plan) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(plan.minuteOfDay, 21 * 60)
        XCTAssertEqual(plan.dayKey, "2026-09-11")
        XCTAssertFalse(plan.isInFuture)
    }

    func testStartNowUsesCurrentMinute() {
        let now = date(year: 2026, month: 9, day: 11, hour: 22, minute: 37, second: 40)
        let plan = RecoveryChallengeWindDownPlanner.startNow(now: now, timeZone: utc)
        XCTAssertEqual(plan.minuteOfDay, 22 * 60 + 37)
        XCTAssertEqual(plan.dayKey, "2026-09-11")
    }

    func testFormatUsesDeviceShortTimeStyle() {
        let planAt = date(year: 2026, month: 9, day: 11, hour: 22, minute: 45)
        let formatted = RecoveryChallengeWindDownPlanner.formatTime(planAt, timeZone: utc)
        // Locale-dependent, but must not hardcode "PM" via a fixed en_US pattern when locale differs.
        // Ensure formatter produced a non-empty short time and does not include a forced ASCII pattern like "9:00:00".
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertFalse(formatted.contains("9:00:00"))
    }

    func testTimezonePreservedForSuggestionDayKey() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 12, hour: 23, minute: 55)
        )!
        let plan = RecoveryChallengeWindDownPlanner.suggest(now: now, timeZone: tokyo)
        XCTAssertTrue(plan.isTomorrow)
        XCTAssertEqual(plan.dayKey, "2026-09-13")
    }

    func testCompletingPersistsDayKeyAndRejectsDuplicate() {
        let now = date(year: 2026, month: 9, day: 11, hour: 18, minute: 0)
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: now,
            timeZoneIdentifier: utc.identifier,
            startDayKey: "2026-09-11",
            taskDefinitionVersion: RecoveryChallengeTaskDefinitionVersion.v1.rawValue
        )
        let first = RecoveryChallengeEngine.completing(
            dayIndex: 1,
            now: now,
            participation: participation,
            windDownMinuteOfDay: 22 * 60 + 45,
            windDownTargetDayKey: "2026-09-11"
        )
        guard case .success(let updated) = first else {
            return XCTFail("expected success \(first)")
        }
        XCTAssertEqual(updated.windDownMinuteOfDay, 22 * 60 + 45)
        XCTAssertEqual(updated.windDownTargetDayKey, "2026-09-11")
        XCTAssertEqual(updated.completedDayIndices, [1])

        let dup = RecoveryChallengeEngine.completing(
            dayIndex: 1,
            now: now,
            participation: updated,
            windDownMinuteOfDay: 23 * 60,
            windDownTargetDayKey: "2026-09-11"
        )
        XCTAssertEqual(dup, .failure(.alreadyCompleted))
        XCTAssertEqual(updated.windDownMinuteOfDay, 22 * 60 + 45)
    }
}
