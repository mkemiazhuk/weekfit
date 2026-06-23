import XCTest
@testable import WeekFit

final class CoachEnduranceSessionChapterTests: XCTestCase {

    func testProtectStartsAtEarlierOfLastHourOrThreeQuartersDuration() {
        XCTAssertEqual(CoachEnduranceSessionChapterResolver.protectStartElapsedMinutes(durationMinutes: 120), 90)
        XCTAssertEqual(CoachEnduranceSessionChapterResolver.protectStartElapsedMinutes(durationMinutes: 240), 180)
        XCTAssertEqual(CoachEnduranceSessionChapterResolver.protectStartElapsedMinutes(durationMinutes: 300), 240)
    }

    func testFourHourRideChapterProgression() {
        let duration = 240

        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 20,
                remainingMinutes: 220
            ),
            .opening
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 45,
                remainingMinutes: 195
            ),
            .establish
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 90,
                remainingMinutes: 150
            ),
            .maintain
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 195,
                remainingMinutes: 45
            ),
            .protect
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 180,
                remainingMinutes: 60
            ),
            .protect
        )
    }

    func testTwoHourRideProtectStartsAtNinetyMinutesNotSixtyRemaining() {
        let duration = 120

        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 75,
                remainingMinutes: 45
            ),
            .maintain
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 90,
                remainingMinutes: 30
            ),
            .protect
        )
    }

    func testShortRideUsesLegacyFlatCopyPath() {
        XCTAssertNil(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: 45,
                elapsedMinutes: 20,
                remainingMinutes: 25
            )
        )
    }

    func testRecoveryWindowWithinFirstHourAfterEnd() {
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.postChapter(durationMinutes: 240, minutesSinceEnd: 10),
            .recoveryWindow
        )
        XCTAssertNil(
            CoachEnduranceSessionChapterResolver.postChapter(durationMinutes: 240, minutesSinceEnd: 75)
        )
    }
}
