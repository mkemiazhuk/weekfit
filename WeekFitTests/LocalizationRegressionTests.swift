import SwiftUI
import XCTest
@testable import WeekFit

final class LocalizationRegressionTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        WeekFitWarmLocalizationCache()
        super.tearDown()
    }

    func testExplicitEnglishAndRussianLookup() {
        XCTAssertEqual(
            WeekFitLocalizedString("settings.language.title", locale: Locale(identifier: "en")),
            "Language"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.language.title", locale: Locale(identifier: "ru")),
            "Язык"
        )
    }

    func testMissingLocalizationFallsBackToKey() {
        XCTAssertEqual(
            WeekFitLocalizedString("localization.test.missing.key", locale: Locale(identifier: "ru")),
            "localization.test.missing.key"
        )
    }

    func testDynamicInsightActionIDRemainsStableWhenLabelIsDisplayCopy() {
        let insight = DynamicInsight(
            icon: "bolt.fill",
            title: "Protein is behind.",
            text: "Add protein to support repair.",
            color: .purple,
            actionLabel: "Add Protein",
            tags: [.protein]
        )
        let localizedInsight = DynamicInsight(
            icon: "bolt.fill",
            title: "Белок отстает.",
            text: "Добавьте белок для восстановления.",
            color: .purple,
            actionID: "add_protein",
            actionLabel: "Добавить белок",
            tags: [.protein]
        )

        XCTAssertEqual(insight.actionID, "add_protein")
        XCTAssertEqual(localizedInsight.actionID, "add_protein")
        XCTAssertNotEqual(localizedInsight.actionLabel, insight.actionLabel)
    }
}
