import XCTest
@testable import WeekFit

final class QuickDrinkFrequentComposerTests: XCTestCase {

    func testMostUsedPlusHotAfternoonSuggestion() {
        let drinks = [
            makeDrink(id: "drink_water", title: "Water"),
            makeDrink(id: "drink_coffee", title: "Coffee"),
            makeDrink(id: "drink_iced_coffee", title: "Iced Coffee"),
            makeDrink(id: "drink_tonic", title: "Tonic")
        ]
        let usage: [String: QuickItemUsageStore.Entry] = [
            "drink_water": .init(count: 5, lastUsedAt: Date())
        ]
        let afternoon = calendarDate(hour: 15)

        let picks = QuickDrinkFrequentComposer.picks(
            drinks: drinks,
            usage: usage,
            now: afternoon,
            temperatureCelsius: 31
        )

        XCTAssertEqual(picks.count, 2)
        XCTAssertEqual(picks[0].item.id, "drink_water")
        XCTAssertEqual(picks[0].badge, .mostUsed)
        XCTAssertEqual(picks[1].item.id, "drink_iced_coffee")
        XCTAssertEqual(picks[1].badge, .forTheHeat)
    }

    func testMorningSuggestionWithoutHistory() {
        let drinks = [
            makeDrink(id: "drink_water", title: "Water"),
            makeDrink(id: "drink_coffee", title: "Coffee"),
            makeDrink(id: "drink_tea", title: "Tea")
        ]
        let morning = calendarDate(hour: 7)

        let picks = QuickDrinkFrequentComposer.picks(
            drinks: drinks,
            usage: [:],
            now: morning,
            temperatureCelsius: 18
        )

        XCTAssertEqual(picks.count, 1)
        XCTAssertEqual(picks[0].item.id, "drink_coffee")
        XCTAssertEqual(picks[0].badge, .morningBoost)
    }

    func testDoesNotDuplicateMostUsedAsContext() {
        let drinks = [
            makeDrink(id: "drink_iced_coffee", title: "Iced Coffee"),
            makeDrink(id: "drink_water", title: "Water"),
            makeDrink(id: "drink_tonic", title: "Tonic")
        ]
        let usage: [String: QuickItemUsageStore.Entry] = [
            "drink_iced_coffee": .init(count: 4, lastUsedAt: Date())
        ]

        let picks = QuickDrinkFrequentComposer.picks(
            drinks: drinks,
            usage: usage,
            now: calendarDate(hour: 15),
            temperatureCelsius: 32
        )

        XCTAssertEqual(picks.map(\.item.id), ["drink_iced_coffee", "drink_water"])
        XCTAssertEqual(picks[0].badge, .mostUsed)
        XCTAssertEqual(picks[1].badge, .forTheHeat)
    }

    private func makeDrink(id: String, title: String) -> QuickItem {
        QuickItem(
            id: id,
            title: title,
            subtitle: "Test",
            category: .drink,
            imageName: "",
            icon: "drop.fill",
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0
        )
    }

    private func calendarDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 1
        components.hour = hour
        return Calendar.current.date(from: components) ?? Date()
    }
}
