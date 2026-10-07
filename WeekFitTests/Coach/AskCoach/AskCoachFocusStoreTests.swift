import XCTest
@testable import WeekFit

final class AskCoachFocusStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AskCoachFocusStoreTests.\(UUID().uuidString)")
        AskCoachFocusStore.useDefaults(defaults)
        AskCoachFocusStore.clear()
    }

    override func tearDown() {
        AskCoachFocusStore.clear()
        AskCoachFocusStore.resetDefaults()
        defaults = nil
        super.tearDown()
    }

    func testSetFocusPersistsActiveWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9))!

        let focus = AskCoachFocusStore.setFocus(
            kind: .protectRecovery,
            now: now,
            calendar: calendar,
            durationDays: 7
        )

        XCTAssertEqual(focus.startDayKey, "2026-04-01")
        XCTAssertEqual(focus.endDayKey, "2026-04-07")
        XCTAssertEqual(AskCoachFocusStore.activeFocus(on: now, calendar: calendar)?.kind, .protectRecovery)
        XCTAssertNil(AskCoachFocusStore.reviewableFocus(on: now, calendar: calendar))
    }

    func testFocusExpiresIntoReviewableState() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        _ = AskCoachFocusStore.setFocus(
            kind: .keepTrainingDays,
            now: start,
            calendar: calendar,
            durationDays: 7
        )

        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8))!
        XCTAssertNil(AskCoachFocusStore.activeFocus(on: afterEnd, calendar: calendar))
        XCTAssertEqual(
            AskCoachFocusStore.reviewableFocus(on: afterEnd, calendar: calendar)?.kind,
            .keepTrainingDays
        )
    }

    func testDismissClearsActiveAndReviewable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        _ = AskCoachFocusStore.setFocus(kind: .steadySleepDuration, now: start, calendar: calendar)

        _ = AskCoachFocusStore.dismiss()
        XCTAssertNil(AskCoachFocusStore.activeFocus(on: start, calendar: calendar))

        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        XCTAssertNil(AskCoachFocusStore.reviewableFocus(on: afterEnd, calendar: calendar))
    }

    func testFocusReviewAnswerDoesNotClaimHabitFollowed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let focus = AskCoachFocusStore.setFocus(kind: .consistentBedtime, now: start, calendar: calendar)

        let range = AskCoachPeriodCalculator.range(
            length: .last7Days,
            endingOn: calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let days = range.dayStarts.map { dayStart in
            AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: calendar),
                sleepMinutes: 400,
                recoveryPercent: 65,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [
                    AskCoachCompletedSession(
                        id: dayStart.timeIntervalSince1970.description,
                        startDate: dayStart.addingTimeInterval(3600),
                        durationMinutes: 30,
                        healthKitWorkoutUUID: UUID(),
                        source: .healthKit,
                        isPlannerSourced: false,
                        isRecoveryActivity: false
                    )
                ],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: true
            )
        }
        let bundle = AskCoachPeriodBundle(
            currentDays: days,
            previousDays: days,
            range: range,
            previousRange: AskCoachPeriodCalculator.previousRange(
                for: range,
                calendar: calendar,
                timeZone: calendar.timeZone
            ),
            healthAccessGranted: true
        )

        let review = AskCoachFocusReview.makeAnswer(focus: focus, bundle: bundle)
        XCTAssertTrue(review.explanation.english.contains("can’t confirm whether you followed"))
        XCTAssertFalse(review.headline.english.lowercased().contains("you followed the habit"))
    }
}
