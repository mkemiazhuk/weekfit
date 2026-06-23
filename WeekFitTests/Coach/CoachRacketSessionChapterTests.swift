import XCTest
@testable import WeekFit

final class CoachRacketSessionChapterTests: XCTestCase {

    func testCloseSmartStartsAtEarlierOfLastThirtyMinutesOrThreeQuartersDuration() {
        XCTAssertEqual(CoachRacketSessionChapterResolver.closeSmartStartElapsedMinutes(durationMinutes: 60), 45)
        XCTAssertEqual(CoachRacketSessionChapterResolver.closeSmartStartElapsedMinutes(durationMinutes: 90), 67)
        XCTAssertEqual(CoachRacketSessionChapterResolver.closeSmartStartElapsedMinutes(durationMinutes: 120), 90)
    }

    func testSixtyMinuteSessionSkipsFindRhythm() {
        let duration = 60

        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 10,
                remainingMinutes: 50
            ),
            .warmIn
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 30,
                remainingMinutes: 30
            ),
            .manageLoad
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 50,
                remainingMinutes: 10
            ),
            .closeSmart
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 25,
                remainingMinutes: 35
            ),
            .manageLoad
        )
    }

    func testNinetyMinuteSessionChapterProgression() {
        let duration = 90

        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 10,
                remainingMinutes: 80
            ),
            .warmIn
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 40,
                remainingMinutes: 50
            ),
            .findRhythm
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 55,
                remainingMinutes: 35
            ),
            .manageLoad
        )
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 75,
                remainingMinutes: 15
            ),
            .closeSmart
        )
    }

    func testShortSessionUsesLegacyFlatCopyPath() {
        XCTAssertNil(
            CoachRacketSessionChapterResolver.duringSessionChapter(
                durationMinutes: 45,
                elapsedMinutes: 20,
                remainingMinutes: 25
            )
        )
    }

    func testRecoveryWindowWithinFirstHourAfterEnd() {
        XCTAssertEqual(
            CoachRacketSessionChapterResolver.postChapter(durationMinutes: 90, minutesSinceEnd: 10),
            .recoveryWindow
        )
        XCTAssertNil(
            CoachRacketSessionChapterResolver.postChapter(durationMinutes: 90, minutesSinceEnd: 75)
        )
    }
}
