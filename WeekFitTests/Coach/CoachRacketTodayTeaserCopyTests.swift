import XCTest
@testable import WeekFit

final class CoachRacketTodayTeaserCopyTests: XCTestCase {

    func testChapterTeaserMappingUsesCourtVoice() {
        WeekFitSetCurrentLanguage(.russian)

        let warmIn = CoachRacketTodayTeaserCopy.chapterTeaser(for: .warmIn)
        XCTAssertEqual(warmIn.0, "Сначала разомнитесь")

        let rhythm = CoachRacketTodayTeaserCopy.chapterTeaser(for: .findRhythm)
        XCTAssertEqual(rhythm.0, "Держите ритм розыгрыша")

        let load = CoachRacketTodayTeaserCopy.chapterTeaser(for: .manageLoad)
        XCTAssertEqual(load.0, "Выбирайте рывки")

        let close = CoachRacketTodayTeaserCopy.chapterTeaser(for: .closeSmart)
        XCTAssertEqual(close.0, "Закройте без перегиба")
    }
}
