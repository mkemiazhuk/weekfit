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
        XCTAssertEqual(
            WeekFitLocalizedString("settings.editName.title", locale: Locale(identifier: "en")),
            "Edit Name"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.editName.title", locale: Locale(identifier: "ru")),
            "Изменить имя"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.nutritionGoal.title", locale: Locale(identifier: "en")),
            "Nutrition Goal"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.nutritionGoal.title", locale: Locale(identifier: "ru")),
            "Цель питания"
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

    func testQuickItemSubtitleRespectsSelectedLanguage() {
        let water = QuickItem(
            id: "drink_water",
            title: "Water",
            subtitle: "Hydration support",
            category: .drink,
            imageName: "ingredient-water",
            icon: "drop.fill",
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            defaultServingAmount: 250,
            servingUnit: .milliliters,
            gramsPerServing: nil,
            mlPerServing: 250
        )

        WeekFitSetCurrentLanguage(.english)
        XCTAssertEqual(QuickItem.localizedSubtitle(for: water), "Hydration support")

        WeekFitSetCurrentLanguage(.russian)
        XCTAssertEqual(QuickItem.localizedSubtitle(for: water), "Гидратация")
    }

    func testBuilderMealDisplayLocalizationFollowsSelectedLanguage() {
        let builderItems = [
            MealBuilderImageItem(
                id: "protein_beef",
                imageName: "ingredient-beef",
                visualSize: 80,
                visualDensity: 0.55,
                supportsStandalonePresentation: true,
                offsetX: 36,
                offsetY: 8,
                rotation: 8,
                zIndex: 3,
                grams: 150
            ),
            MealBuilderImageItem(
                id: "veg_cucumber",
                imageName: "ingredient-cucumber",
                visualSize: 70,
                visualDensity: 0.45,
                supportsStandalonePresentation: true,
                offsetX: -20,
                offsetY: 10,
                rotation: -4,
                zIndex: 2,
                grams: 100
            )
        ]

        let meal = Meals(
            id: "localization_test_meal",
            title: "Говядина Огурец",
            subtitle: "Говядина (150 г) + Огурец (100 г)",
            imageName: "plate-dark",
            type: .balanced,
            calories: 500,
            protein: 40,
            carbs: 10,
            fats: 30,
            benefits: [],
            ingredients: [
                MealsIngredient(name: "Говядина", amount: "150 г"),
                MealsIngredient(name: "Огурец", amount: "100 г")
            ],
            builderImageItems: builderItems,
            creationMode: .ingredients
        )

        WeekFitSetCurrentLanguage(.english)
        XCTAssertEqual(meal.localizedDisplayTitle, "Beef Cucumber")
        XCTAssertTrue(meal.localizedDisplayIngredients.allSatisfy { !$0.name.contains("Говядина") })
        XCTAssertTrue(meal.localizedDisplayIngredients.allSatisfy { !$0.name.contains("Огурец") })

        WeekFitSetCurrentLanguage(.russian)
        XCTAssertEqual(meal.localizedDisplayTitle, "Говядина Огурец")
        XCTAssertTrue(meal.localizedDisplayIngredients.contains { $0.name == "Говядина" })
        XCTAssertTrue(meal.localizedDisplayIngredients.contains { $0.name == "Огурец" })
    }
}
