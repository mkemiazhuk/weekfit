import XCTest
@testable import WeekFit

final class CoachEnduranceTodayTeaserCopyTests: XCTestCase {

    func testChapterTeaserMappingMatchesV5Spec() {
        WeekFitSetCurrentLanguage(.russian)

        let opening = CoachEnduranceTodayTeaserCopy.chapterTeaser(for: .opening)
        XCTAssertEqual(opening.0, "Сначала легко")

        let establish = CoachEnduranceTodayTeaserCopy.chapterTeaser(for: .establish)
        XCTAssertEqual(establish.0, "Не пропускайте следующий приём")

        let maintain = CoachEnduranceTodayTeaserCopy.chapterTeaser(for: .maintain)
        XCTAssertEqual(maintain.0, "Продолжайте по плану")

        let protect = CoachEnduranceTodayTeaserCopy.chapterTeaser(for: .protect)
        XCTAssertEqual(protect.0, "Не добавляйте усилие сейчас")

        let recovery = CoachEnduranceTodayTeaserCopy.chapterTeaser(for: .recoveryWindow)
        XCTAssertEqual(recovery.0, "Сейчас важнее восстановление")
    }

    func testNarrativeContextUsesSameChapterResolverAsCoach() {
        let duration = 240
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 120,
                remainingMinutes: 120
            ),
            .maintain
        )
        XCTAssertEqual(
            CoachEnduranceSessionChapterResolver.duringSessionChapter(
                durationMinutes: duration,
                elapsedMinutes: 210,
                remainingMinutes: 30
            ),
            .protect
        )
    }
}
