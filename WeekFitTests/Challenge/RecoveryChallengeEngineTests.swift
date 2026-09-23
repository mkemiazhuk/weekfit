import Foundation
import XCTest
@testable import WeekFit

final class RecoveryChallengeEngineTests: XCTestCase {

    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }

    private func date(
        _ y: Int, _ m: Int, _ d: Int,
        _ h: Int = 12, _ min: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return calendar.date(from: comps)!
    }

    private func participation(
        enrolled: Date,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!,
        version: RecoveryChallengeTaskDefinitionVersion = .v2,
        completed: [Int] = [],
        day5: Int = 0,
        favorite: Int? = nil,
        declined: [Int] = []
    ) -> RecoveryChallengeParticipation {
        RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: timeZone.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: timeZone),
            completedDayIndices: completed,
            taskDefinitionVersion: version.rawValue,
            day5BreakCount: day5,
            day7SelectedFavoriteDayIndex: favorite,
            declinedMorningConfirmDayIndices: declined
        )
    }

    func testEnrollmentRequiresSevenDaysInsideWindow() {
        let start = date(2026, 10, 1, timeZone: utc)
        let end = date(2026, 10, 6, timeZone: utc)
        let now = date(2026, 10, 1, timeZone: utc)
        XCTAssertFalse(
            RecoveryChallengeEngine.canEnroll(
                now: now,
                eventStart: start,
                eventEnd: end,
                timeZone: utc
            )
        )

        let longEnd = date(2026, 10, 20, timeZone: utc)
        XCTAssertTrue(
            RecoveryChallengeEngine.canEnroll(
                now: now,
                eventStart: start,
                eventEnd: longEnd,
                timeZone: utc
            )
        )
    }

    func testEnrollmentCutoffWhenDaySevenWouldExceedEventEnd() {
        let start = date(2026, 10, 1, timeZone: utc)
        let end = date(2026, 10, 10, 0, 0, timeZone: utc)
        XCTAssertTrue(
            RecoveryChallengeEngine.canEnroll(
                now: date(2026, 10, 3, timeZone: utc),
                eventStart: start,
                eventEnd: end,
                timeZone: utc
            )
        )
        XCTAssertFalse(
            RecoveryChallengeEngine.canEnroll(
                now: date(2026, 10, 4, timeZone: utc),
                eventStart: start,
                eventEnd: end,
                timeZone: utc
            )
        )
    }

    func testChallengeDayIndexAcrossCalendarDays() {
        let enrolled = date(2026, 3, 8, 9, 0, timeZone: utc)
        let p = participation(enrolled: enrolled)
        XCTAssertEqual(RecoveryChallengeEngine.challengeDayIndex(for: enrolled, participation: p), 1)
        XCTAssertEqual(
            RecoveryChallengeEngine.challengeDayIndex(
                for: date(2026, 3, 10, 23, 0, timeZone: utc),
                participation: p
            ),
            3
        )
        XCTAssertNil(
            RecoveryChallengeEngine.challengeDayIndex(
                for: date(2026, 3, 15, timeZone: utc),
                participation: p
            )
        )
    }

    func testDSTSpringForwardKeepsConsecutiveChallengeDays() {
        let ny = TimeZone(identifier: "America/New_York")!
        let enrolled = date(2026, 3, 7, 20, 0, timeZone: ny)
        let p = participation(enrolled: enrolled, timeZone: ny)
        XCTAssertEqual(
            RecoveryChallengeEngine.challengeDayIndex(
                for: date(2026, 3, 8, 12, 0, timeZone: ny),
                participation: p
            ),
            2
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.challengeDayIndex(
                for: date(2026, 3, 9, 12, 0, timeZone: ny),
                participation: p
            ),
            3
        )
    }

    func testMissedDayCannotBeBackfilled() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        var p = participation(enrolled: enrolled)
        let day3 = date(2026, 5, 3, timeZone: utc)
        XCTAssertEqual(
            RecoveryChallengeEngine.completing(dayIndex: 1, now: day3, participation: p),
            .failure(.notCurrentDay)
        )
        let ok = RecoveryChallengeEngine.completing(dayIndex: 3, now: day3, participation: p)
        guard case .success(let updated) = ok else {
            return XCTFail("expected success")
        }
        p = updated
        XCTAssertEqual(p.completedDayIndices, [3])
        XCTAssertFalse(p.hasCompleted(dayIndex: 1))
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 1, now: day3, participation: p),
            .missed
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 2, now: day3, participation: p),
            .missed
        )
    }

    func testPlanningDoesNotCompleteV2Day() {
        let enrolled = date(2026, 5, 1, 18, 0, timeZone: utc)
        var p = participation(enrolled: enrolled, version: .v2)
        p = RecoveryChallengeEngine.savingPlan(
            minuteOfDay: 22 * 60,
            targetDayKey: "2026-05-01",
            to: p
        )
        XCTAssertEqual(p.plannedMinuteOfDay, 22 * 60)
        XCTAssertTrue(p.completedDayIndices.isEmpty)
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 1, now: enrolled, participation: p),
            .current
        )
    }

    func testExplicitAndDuplicateCompletion() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        var p = participation(enrolled: enrolled, version: .v2)
        let first = RecoveryChallengeEngine.completing(dayIndex: 1, now: enrolled, participation: p)
        guard case .success(let updated) = first else {
            return XCTFail("expected success")
        }
        p = updated
        XCTAssertEqual(p.completedDayIndices, [1])
        XCTAssertEqual(
            RecoveryChallengeEngine.completing(dayIndex: 1, now: enrolled, participation: p),
            .failure(.alreadyCompleted)
        )
    }

    func testDay5PartialProgressDoesNotComplete() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        var p = participation(enrolled: enrolled, version: .v2)
        let day5 = date(2026, 5, 5, timeZone: utc)
        p = RecoveryChallengeEngine.togglingDay5Break(breakIndex: 0, enabled: true, on: p)
        p = RecoveryChallengeEngine.togglingDay5Break(breakIndex: 1, enabled: true, on: p)
        XCTAssertEqual(RecoveryChallengeEngine.day5MarkedBreakCount(p), 2)
        switch RecoveryChallengeEngine.canComplete(dayIndex: 5, now: day5, participation: p) {
        case .failure(.day5BreaksIncomplete): break
        default: XCTFail("expected day5BreaksIncomplete")
        }
        p = RecoveryChallengeEngine.togglingDay5Break(breakIndex: 2, enabled: true, on: p)
        switch RecoveryChallengeEngine.canComplete(dayIndex: 5, now: day5, participation: p) {
        case .success: break
        default: XCTFail("expected success after 3 breaks")
        }
        let done = RecoveryChallengeEngine.completing(dayIndex: 5, now: day5, participation: p)
        guard case .success(let updated) = done else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(updated.hasCompleted(dayIndex: 5))
    }

    func testDay7SelectionIsNotCompletion() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        var p = participation(enrolled: enrolled, version: .v2)
        let day7 = date(2026, 5, 7, timeZone: utc)
        p = RecoveryChallengeEngine.selectingDay7Favorite(dayIndex: 3, on: p)
        XCTAssertEqual(p.day7SelectedFavoriteDayIndex, 3)
        XCTAssertTrue(p.completedDayIndices.isEmpty)
        switch RecoveryChallengeEngine.canComplete(dayIndex: 7, now: day7, participation: p) {
        case .success: break
        default: XCTFail("expected success with favorite selected")
        }
        let withoutPick = participation(enrolled: enrolled, version: .v2)
        switch RecoveryChallengeEngine.canComplete(dayIndex: 7, now: day7, participation: withoutPick) {
        case .failure(.day7FavoriteMissing): break
        default: XCTFail("expected day7FavoriteMissing")
        }
    }

    func testFutureTaskPreviewRemainsNonActionable() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let p = participation(enrolled: enrolled, version: .v2)
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 4, now: enrolled, participation: p),
            .future
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 4, now: enrolled, participation: p) {
        case .failure(.futureDayLocked): break
        default: XCTFail("expected futureDayLocked")
        }
    }

    func testBedtimeMorningConfirmBeforeAndAfterCutoff() {
        let enrolled = date(2026, 5, 1, 20, 0, timeZone: utc)
        let p = participation(enrolled: enrolled, version: .v2)

        let nextMorningEarly = date(2026, 5, 2, 9, 0, timeZone: utc)
        XCTAssertEqual(
            RecoveryChallengeEngine.morningConfirmableDayIndex(now: nextMorningEarly, participation: p),
            1
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 1, now: nextMorningEarly, participation: p),
            .awaitingMorningConfirm
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 1, now: nextMorningEarly, participation: p) {
        case .success: break
        default: XCTFail("expected morning confirm success")
        }
        XCTAssertEqual(
            RecoveryChallengeEngine.challengeDayIndex(for: nextMorningEarly, participation: p),
            2
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 2, now: nextMorningEarly, participation: p) {
        case .success: break
        default: XCTFail("expected day 2 still completable")
        }

        let afterNoon = date(2026, 5, 2, 12, 0, timeZone: utc)
        XCTAssertNil(
            RecoveryChallengeEngine.morningConfirmableDayIndex(now: afterNoon, participation: p)
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 1, now: afterNoon, participation: p),
            .missed
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 1, now: afterNoon, participation: p) {
        case .failure(.notCurrentDay): break
        default: XCTFail("expected notCurrentDay after noon")
        }
    }

    func testMorningDeclineLocksBedtimeDayWithoutAffectingToday() {
        let enrolled = date(2026, 5, 1, 20, 0, timeZone: utc)
        var p = participation(enrolled: enrolled, version: .v2)
        let morning = date(2026, 5, 2, 8, 0, timeZone: utc)
        p = RecoveryChallengeEngine.decliningMorningConfirm(dayIndex: 1, on: p)
        XCTAssertNil(
            RecoveryChallengeEngine.morningConfirmableDayIndex(now: morning, participation: p)
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.journeyState(dayIndex: 1, now: morning, participation: p),
            .missed
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 2, now: morning, participation: p) {
        case .success: break
        default: XCTFail("expected day 2 still completable")
        }
    }

    func testCompletionRejectedOutsideEventWindow() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let p = participation(enrolled: enrolled, version: .v2)
        let window = (start: date(2026, 5, 1, timeZone: utc), end: date(2026, 5, 2, timeZone: utc))
        let afterEnd = date(2026, 5, 3, timeZone: utc)
        switch RecoveryChallengeEngine.canComplete(
            dayIndex: 1,
            now: afterEnd,
            participation: p,
            window: window
        ) {
        case .failure(.outsideEventWindow): break
        default: XCTFail("expected outsideEventWindow")
        }
    }

    func testLegacyParticipantPreservesV1SemanticsAndVersion() throws {
        // Simulate persisted payload without taskDefinitionVersion → decode as v1.
        let enrolled = date(2026, 5, 1, 18, 0, timeZone: utc)
        let legacy = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: "2026-05-01",
            completedDayIndices: [],
            taskDefinitionVersion: RecoveryChallengeTaskDefinitionVersion.v1.rawValue
        )
        let encoded = try JSONEncoder().encode(legacy)
        // Strip version key to mimic older installs.
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object.removeValue(forKey: "taskDefinitionVersion")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(RecoveryChallengeParticipation.self, from: stripped)
        XCTAssertEqual(decoded.taskDefinitionVersion, 1)
        XCTAssertEqual(decoded.resolvedTaskVersion, .v1)

        // v1 Day 1 still requires wind-down time to complete.
        XCTAssertEqual(
            RecoveryChallengeEngine.completing(dayIndex: 1, now: enrolled, participation: decoded),
            .failure(.missingRequiredInput)
        )
        let ok = RecoveryChallengeEngine.completing(
            dayIndex: 1,
            now: enrolled,
            participation: decoded,
            windDownMinuteOfDay: 21 * 60,
            windDownTargetDayKey: "2026-05-01"
        )
        guard case .success(let updated) = ok else {
            return XCTFail("expected v1 completion")
        }
        XCTAssertEqual(updated.completedDayIndices, [1])
        XCTAssertEqual(updated.windDownMinuteOfDay, 21 * 60)
        // Must not reinterpret as phone-free v2 task catalog for this participant.
        XCTAssertEqual(updated.resolvedTaskVersion, .v1)
        XCTAssertEqual(
            RecoveryChallengeTaskCatalog.definition(dayIndex: 1, version: .v1)?.titleKey,
            "challenge.recovery7.task.1.title"
        )
    }

    func testNewEnrollmentUsesV2Definition() {
        let now = date(2026, 5, 1, timeZone: utc)
        let window = (start: date(2026, 4, 1, timeZone: utc), end: date(2026, 6, 1, timeZone: utc))
        let result = RecoveryChallengeEngine.enroll(
            now: now,
            timeZone: utc,
            window: window,
            taskDefinitionVersion: .v2
        )
        guard case .success(let p) = result else {
            return XCTFail("enroll failed")
        }
        XCTAssertEqual(p.resolvedTaskVersion, .v2)
        XCTAssertEqual(
            RecoveryChallengeTaskCatalog.definition(dayIndex: 1, version: p.resolvedTaskVersion)?.titleKey,
            "challenge.recovery7.v2.task.1.title"
        )
    }

    func testFinalPerfectVersusPartialSummaryPhase() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let after = date(2026, 5, 10, timeZone: utc)
        let perfect = participation(
            enrolled: enrolled,
            version: .v2,
            completed: [1, 2, 3, 4, 5, 6, 7]
        )
        let partial = participation(
            enrolled: enrolled,
            version: .v2,
            completed: [1, 3, 5]
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.screenPhase(now: after, participation: perfect),
            .summary(completedCount: 7)
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.screenPhase(now: after, participation: partial),
            .summary(completedCount: 3)
        )
    }

    func testTodayCardHiddenWhenFeatureDisabledWithoutParticipation() {
        let kind = RecoveryChallengeEngine.todayCardKind(
            now: date(2026, 5, 1, timeZone: utc),
            participation: nil,
            window: nil,
            timeZone: utc,
            featureAvailable: false
        )
        XCTAssertEqual(kind, .hidden)
    }

    func testFinishedCardCanBeDismissedFromToday() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: utc),
            completedDayIndices: [1, 2, 3],
            todaySummaryCardDismissed: true
        )
        let after = date(2026, 5, 10, timeZone: utc)
        let kind = RecoveryChallengeEngine.todayCardKind(
            now: after,
            participation: participation,
            window: (enrolled, date(2026, 6, 1, timeZone: utc)),
            timeZone: utc,
            featureAvailable: true
        )
        XCTAssertEqual(kind, .hidden)
    }

    func testPerfectFinishHidesTodayCardWithoutManualDismiss() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: utc),
            completedDayIndices: [1, 2, 3, 4, 5, 6, 7],
            todaySummaryCardDismissed: false
        )
        let after = date(2026, 5, 10, timeZone: utc)
        let kind = RecoveryChallengeEngine.todayCardKind(
            now: after,
            participation: participation,
            window: (enrolled, date(2026, 6, 1, timeZone: utc)),
            timeZone: utc,
            featureAvailable: true
        )
        XCTAssertEqual(kind, .hidden)
    }

    func testPartialFinishKeepsDismissibleTodayCard() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: utc),
            completedDayIndices: [1, 3, 5],
            todaySummaryCardDismissed: false
        )
        let after = date(2026, 5, 10, timeZone: utc)
        let kind = RecoveryChallengeEngine.todayCardKind(
            now: after,
            participation: participation,
            window: (enrolled, date(2026, 6, 1, timeZone: utc)),
            timeZone: utc,
            featureAvailable: true
        )
        XCTAssertEqual(kind, .finished(completedCount: 3))
    }

    func testMidnightBoundaryStartsNextChallengeDay() {
        let enrolled = date(2026, 5, 1, 23, 30, timeZone: utc)
        let p = participation(enrolled: enrolled)
        let justBefore = date(2026, 5, 1, 23, 59, timeZone: utc)
        let justAfter = date(2026, 5, 2, 0, 0, timeZone: utc)
        XCTAssertEqual(RecoveryChallengeEngine.challengeDayIndex(for: justBefore, participation: p), 1)
        XCTAssertEqual(RecoveryChallengeEngine.challengeDayIndex(for: justAfter, participation: p), 2)
    }

    func testSanitizedParticipationDropsInvalidIndices() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let dirty = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: "2026-05-01",
            completedDayIndices: [1, 1, 0, 8, 3],
            taskDefinitionVersion: 99,
            day5BreakCount: 0b1111,
            day7SelectedFavoriteDayIndex: 99,
            declinedMorningConfirmDayIndices: [2, 2, -1]
        )
        let clean = dirty.sanitized()
        XCTAssertEqual(clean.completedDayIndices, [1, 3])
        XCTAssertEqual(clean.resolvedTaskVersion, .v1)
        XCTAssertEqual(clean.day5BreakCount, 0b111)
        XCTAssertNil(clean.day7SelectedFavoriteDayIndex)
        XCTAssertEqual(clean.declinedMorningConfirmDayIndices, [2])
    }

    func testClockRollbackKeepsDayOneVisibleButNotCompletable() {
        let enrolled = date(2026, 5, 3, timeZone: utc)
        let p = participation(enrolled: enrolled, version: .v2)
        let beforeStart = date(2026, 5, 1, timeZone: utc)
        XCTAssertTrue(RecoveryChallengeEngine.isBeforePersonalStart(now: beforeStart, participation: p))
        XCTAssertEqual(
            RecoveryChallengeEngine.screenPhase(now: beforeStart, participation: p),
            .active(dayIndex: 1, todayCompleted: false)
        )
        switch RecoveryChallengeEngine.canComplete(dayIndex: 1, now: beforeStart, participation: p) {
        case .failure(.futureDayLocked):
            break
        default:
            XCTFail("expected futureDayLocked when clock is before start")
        }
    }

    func testEnrollmentTimezoneFreezeIgnoresDeviceTimezoneChange() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let enrolled = date(2026, 5, 1, 10, 0, timeZone: tokyo)
        let p = participation(enrolled: enrolled, timeZone: tokyo, version: .v2)
        // Instant that is still May 1 in Tokyo but already May 1 evening / May 2 depending —
        // use a UTC noon May 1 which is evening in Tokyo (May 1 21:00) → still day 1.
        let utcNoonMay1 = date(2026, 5, 1, 12, 0, timeZone: utc)
        XCTAssertEqual(
            RecoveryChallengeEngine.challengeDayIndex(for: utcNoonMay1, participation: p),
            1
        )
    }

    func testDaySevenCompletionStaysActiveUntilCalendarEnds() {
        let enrolled = date(2026, 5, 1, timeZone: utc)
        let day7 = date(2026, 5, 7, 18, 0, timeZone: utc)
        let p = participation(
            enrolled: enrolled,
            version: .v2,
            completed: [1, 2, 3, 4, 5, 6, 7],
            favorite: 2
        )
        XCTAssertEqual(
            RecoveryChallengeEngine.screenPhase(now: day7, participation: p),
            .active(dayIndex: 7, todayCompleted: true)
        )
        let day8 = date(2026, 5, 8, 0, 0, timeZone: utc)
        XCTAssertEqual(
            RecoveryChallengeEngine.screenPhase(now: day8, participation: p),
            .summary(completedCount: 7)
        )
    }
}
