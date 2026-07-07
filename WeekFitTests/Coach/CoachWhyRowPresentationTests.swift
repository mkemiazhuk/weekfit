import SwiftUI
import XCTest
@testable import WeekFit

final class CoachWhyRowPresentationTests: XCTestCase {

    private let semantic = Color.green

    func testShortSleepSignalUsesSleepIcon() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Сон был коротким — начните легче обычного.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "moon.zzz.fill")
    }

    func testShortSleepEnglishUsesSleepIcon() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Sleep was short — start easier than usual.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "moon.zzz.fill")
    }

    func testHydrationSignalUsesDropIcon() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Воды за день пока маловато.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "drop.fill")
    }

    func testFuelSignalUsesForkKnifeIcon() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Еды пока меньше, чем требует день.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "fork.knife")
    }

    func testRecoveryLagUsesRecoveryIconNotFood() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Восстановление отстаёт — берегите тренировку.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "heart.text.clipboard.fill")
    }

    func testTomorrowWorkoutUsesCalendarIcon() {
        let style = CoachWhyRowPresentation.resolve(
            title: "Завтра в плане — велосессия.",
            semanticColor: semantic
        )
        XCTAssertEqual(style.icon, "calendar")
    }
}
