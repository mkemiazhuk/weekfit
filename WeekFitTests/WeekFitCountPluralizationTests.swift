import XCTest
@testable import WeekFit

final class WeekFitCountPluralizationTests: XCTestCase {

    private let ru = Locale(identifier: "ru")
    private let en = Locale(identifier: "en")

    func testRussianWorkoutPluralizationExamples() {
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 1, category: .workout, locale: ru),
            "1 тренировка"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 2, category: .workout, locale: ru),
            "2 тренировки"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 5, category: .workout, locale: ru),
            "5 тренировок"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 11, category: .workout, locale: ru),
            "11 тренировок"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 21, category: .workout, locale: ru),
            "21 тренировка"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 22, category: .workout, locale: ru),
            "22 тренировки"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 25, category: .workout, locale: ru),
            "25 тренировок"
        )
    }

    func testRussianMealPluralizationExamples() {
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 1, category: .meal, locale: ru),
            "1 прием пищи"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 2, category: .meal, locale: ru),
            "2 приема пищи"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 5, category: .meal, locale: ru),
            "5 приемов пищи"
        )
    }

    func testRussianHabitPluralizationExamples() {
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 1, category: .habit, locale: ru),
            "1 привычка"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 2, category: .habit, locale: ru),
            "2 привычки"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 5, category: .habit, locale: ru),
            "5 привычек"
        )
    }

    func testEnglishWorkoutPluralization() {
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 1, category: .workout, locale: en),
            "1 workout"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.phrase(count: 2, category: .workout, locale: en),
            "2 workouts"
        )
    }

    func testEveningPlannedCompletedRussianForms() {
        XCTAssertEqual(
            WeekFitCountPluralization.eveningPlannedCompletedPhrase(count: 1, locale: ru),
            "Вы всё равно выполнили 1 запланированный пункт."
        )
        XCTAssertEqual(
            WeekFitCountPluralization.eveningPlannedCompletedPhrase(count: 2, locale: ru),
            "Вы всё равно выполнили 2 запланированных пункта."
        )
        XCTAssertEqual(
            WeekFitCountPluralization.eveningPlannedCompletedPhrase(count: 5, locale: ru),
            "Вы всё равно выполнили 5 запланированных пунктов."
        )
    }

    func testPortionsPhraseRussianForms() {
        XCTAssertEqual(
            WeekFitCountPluralization.portionsPhrase(quantity: 1, formattedQuantity: "1", locale: ru),
            "1 порция"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.portionsPhrase(quantity: 2, formattedQuantity: "2", locale: ru),
            "2 порции"
        )
        XCTAssertEqual(
            WeekFitCountPluralization.portionsPhrase(quantity: 5, formattedQuantity: "5", locale: ru),
            "5 порций"
        )
    }
}
