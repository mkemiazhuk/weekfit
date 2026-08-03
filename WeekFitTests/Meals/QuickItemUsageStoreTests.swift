import XCTest
@testable import WeekFit

final class QuickItemUsageStoreTests: XCTestCase {

    private let testKey = QuickItemUsageStore.storageKey
    private let legacyKey = "weekfit_quick_item_usage_v1"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        super.tearDown()
    }

    func testPartitionHidesEmptyPersonalizedSections() {
        let drinks = [
            makeDrink(id: "drink_water", title: "Water"),
            makeDrink(id: "drink_coffee", title: "Coffee"),
            makeDrink(id: "drink_tea", title: "Tea")
        ]

        let partition = QuickItemUsageStore.partition(drinks: drinks, usage: [:])
        XCTAssertTrue(partition.frequentlyUsed.isEmpty)
        XCTAssertTrue(partition.recent.isEmpty)
        XCTAssertEqual(partition.all.map(\.id), ["drink_coffee", "drink_tea", "drink_water"])
    }

    func testPartitionExcludesFrequentFromRecent() {
        let drinks = [
            makeDrink(id: "drink_water", title: "Water"),
            makeDrink(id: "drink_coffee", title: "Coffee"),
            makeDrink(id: "drink_tea", title: "Tea"),
            makeDrink(id: "drink_espresso", title: "Espresso")
        ]

        let now = Date()
        let usage: [String: QuickItemUsageStore.Entry] = [
            "drink_water": .init(count: 5, lastUsedAt: now.addingTimeInterval(-100)),
            "drink_coffee": .init(count: 3, lastUsedAt: now.addingTimeInterval(-50)),
            "drink_tea": .init(count: 1, lastUsedAt: now),
            "drink_espresso": .init(count: 1, lastUsedAt: now.addingTimeInterval(-10))
        ]

        let partition = QuickItemUsageStore.partition(
            drinks: drinks,
            usage: usage,
            excludingFromRecent: ["drink_water", "drink_coffee"],
            recentLimit: 8
        )

        XCTAssertEqual(partition.recent.map(\.id), ["drink_tea", "drink_espresso"])
        XCTAssertFalse(partition.recent.contains(where: { $0.id == "drink_water" }))
    }

    func testLegacyMigrationPreservesCounts() {
        UserDefaults.standard.set(["drink_water": 4, "drink_coffee": 2], forKey: legacyKey)
        let loaded = QuickItemUsageStore.load()
        XCTAssertEqual(loaded["drink_water"]?.count, 4)
        XCTAssertEqual(loaded["drink_coffee"]?.count, 2)
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
}
