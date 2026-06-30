import SwiftUI
import XCTest
@testable import WeekFit

final class LocalizationRegressionTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        WeekFitSetCurrentLanguage(.english)
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
        XCTAssertEqual(
            WeekFitLocalizedString("settings.nightComfort.title", locale: Locale(identifier: "en")),
            "Night Comfort"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.nightComfort.title", locale: Locale(identifier: "ru")),
            "Ночной комфорт"
        )
    }

    func testMissingLocalizationFallsBackToKey() {
        XCTAssertEqual(
            WeekFitLocalizedString("localization.test.missing.key", locale: Locale(identifier: "ru")),
            "localization.test.missing.key"
        )
    }

    func testRussianCoachCautionLabelUsesNaturalWording() {
        for key in ["coach.card.watchOutFor", "coach.hero.beCarefulWith"] {
            XCTAssertEqual(
                WeekFitLocalizedString(key, locale: Locale(identifier: "ru")),
                "Чего избегать"
            )
            XCTAssertNotEqual(
                WeekFitLocalizedString(key, locale: Locale(identifier: "ru")),
                "Осторожнее с"
            )
        }
    }

    func testRussianCoachCopyAvoidsKnownLiteralPhrasesAndTypos() {
        let expectedCopy = [
            "coach.actions.doNotStartLaterWorkDry": "Не начинайте позднюю тренировку без воды",
            "coach.actions.lowerTheLaterCeiling": "Сделайте вечер легче",
            "coach.engineV3.letTheWarmUpSetTheCeiling.2213": "Пусть разминка задаст темп",
            "coach.engineV3.lowerTheCeiling.2476": "Сделайте план легче",
            "coach.engineV3.tonightSetsUpTomorrowSCeiling.2395": "Сон сегодня влияет на завтрашний темп",
            "coach.fallback.holdThePlannedCeiling": "Держите запланированный темп",
            "coach.final.recommendation.readiness": "Выберите один лёгкий блок и не добавляйте лишнюю нагрузку.",
            "coach.theMainWorkIsDoneEatProteinDrinkWater": "Основная тренировка завершена. Съешьте белок, выпейте воды и дайте пульсу успокоиться."
        ]

        for (key, expected) in expectedCopy {
            let localized = WeekFitLocalizedString(key, locale: Locale(identifier: "ru"))
            XCTAssertEqual(localized, expected)
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("тренеров"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("потолок"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("превращайте"))
        }
    }

    func testRussianCoachRuntimeCopyAvoidsLiteralCeilingPhrase() {
        WeekFitSetCurrentLanguage(.russian)

        let liveRun = WeekFitCoachRuntimeLocalizedString(
            "The run is already live. Recovery is shaping the effort ceiling, so easy pacing and reserve matter most now."
        )
        let accumulatedLoad = WeekFitCoachRuntimeLocalizedString(
            "Load has already accumulated today, so recovery affects the effort ceiling but does not replace the current workout."
        )

        XCTAssertFalse(liveRun.localizedCaseInsensitiveContains("потолок"))
        XCTAssertFalse(accumulatedLoad.localizedCaseInsensitiveContains("потолок"))
        XCTAssertTrue(liveRun.localizedCaseInsensitiveContains("темп"))
        XCTAssertTrue(accumulatedLoad.localizedCaseInsensitiveContains("темп"))
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
