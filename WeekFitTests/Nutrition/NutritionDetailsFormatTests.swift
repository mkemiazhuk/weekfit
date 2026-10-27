import XCTest
@testable import WeekFit

final class NutritionDetailsFormatTests: XCTestCase {

    private let english = Locale(identifier: "en")
    private let russian = Locale(identifier: "ru")

    func testMissingWaterIsNotBehindAndNotAZeroRatio() {
        let readout = NutritionDetailsFormat.water(liters: 0, goal: 3.7, locale: english)
        guard case .noneLogged = readout else {
            return XCTFail("expected no water logged, got \(readout)")
        }

        let copy = WeekFitLocalizedString("nutrition.details.hydration.none", locale: english)
        XCTAssertEqual(copy, "No water logged")
        XCTAssertNotEqual(copy, WeekFitLocalizedString("nutrition.details.hydration.status.behind", locale: english))

        let russianCopy = WeekFitLocalizedString("nutrition.details.hydration.none", locale: russian)
        XCTAssertEqual(russianCopy, "Вода не записана")
        XCTAssertFalse(russianCopy.isEmpty)
    }

    func testZeroGoalDoesNotInventProgress() {
        let calories = NutritionDetailsFormat.calories(current: 445, goal: 0, locale: english)
        guard case .amount(let text) = calories else {
            return XCTFail("expected amount without a goal, got \(calories)")
        }
        XCTAssertTrue(text.contains("445"))
        XCTAssertNil(NutritionDetailsFormat.progressFraction(current: 445, goal: 0))
        XCTAssertNil(NutritionDetailsFormat.goalCaption(for: calories, locale: english))

        let missing = NutritionDetailsFormat.macro(current: .nan, goal: 137, locale: english)
        guard case .unknown = missing else {
            return XCTFail("expected unknown for non-finite data, got \(missing)")
        }
    }

    func testOverageFillsTheBarAndKeepsTheRealAmount() {
        let protein = NutritionDetailsFormat.macro(current: 152, goal: 137, locale: english)
        guard case .ratio(let text, _, let progress, let overage) = protein else {
            return XCTFail("expected ratio, got \(protein)")
        }
        XCTAssertEqual(progress, 1, accuracy: 0.001)
        XCTAssertTrue(text.contains("152"))
        XCTAssertTrue(text.contains("137"))
        XCTAssertEqual(overage, "+15 g")
        XCTAssertNotEqual(overage, "")
    }

    func testRussianMacroUsesLocalizedUnitWithoutDividingByZero() {
        let protein = NutritionDetailsFormat.macro(current: 24, goal: 153, locale: russian)
        guard case .ratio(let text, _, let progress, let overage) = protein else {
            return XCTFail("expected ratio, got \(protein)")
        }
        XCTAssertNil(overage)
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1)
        XCTAssertTrue(text.contains("24"))
        XCTAssertTrue(text.contains("153"))
        XCTAssertTrue(text.contains("г"))
    }

    func testGoalCaptionUsesTheGoalNotTheEatenAmount() {
        let calories = NutritionDetailsFormat.calories(current: 1840, goal: 2100, locale: english)
        let caption = NutritionDetailsFormat.goalCaption(for: calories, locale: english)
        let eaten = NutritionDetailsFormat.integer(1840, locale: english)
        let goal = NutritionDetailsFormat.integer(2100, locale: english)
        XCTAssertEqual(caption, "Goal \(goal) kcal")
        if case .ratio(_, let currentAmount, _, _) = calories {
            XCTAssertTrue(currentAmount.contains(eaten))
            XCTAssertFalse(currentAmount.contains(goal))
        } else {
            XCTFail("expected calorie ratio")
        }
    }
}
