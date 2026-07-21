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
        XCTAssertEqual(
            WeekFitLocalizedString("onboarding.v10.causality.title", locale: Locale(identifier: "en")),
            "Your body changes throughout the day."
        )
        XCTAssertEqual(
            WeekFitLocalizedString("onboarding.v10.causality.title", locale: Locale(identifier: "ru")),
            "Ваше тело меняется в течение дня."
        )
        XCTAssertEqual(
            WeekFitLocalizedString("onboarding.v10.promise.title", locale: Locale(identifier: "en")),
            "Stop guessing."
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

    func testRussianCoachProductNamingUsesTrener() {
        XCTAssertEqual(
            WeekFitLocalizedString("common.tab.coach", locale: Locale(identifier: "ru")),
            "Тренер"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("coach.section.insight.title", locale: Locale(identifier: "ru")),
            "Подсказка тренера"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("today.coachInsight.opensCoach", locale: Locale(identifier: "ru")),
            "Открывает вкладку Тренер"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("meals.coachRecommendation.accessibilityFormat", locale: Locale(identifier: "ru")),
            "Рекомендация тренера: %@"
        )

        for key in [
            "common.tab.coach",
            "coach.section.insight.title",
            "today.coachInsight.opensCoach",
            "meals.coachRecommendation.accessibilityFormat"
        ] {
            let localized = WeekFitLocalizedString(key, locale: Locale(identifier: "ru"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("коуч"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("инсайт коуча"))
        }
    }

    func testRussianCoachHeroLabelsMatchStyleGuide() {
        XCTAssertEqual(
            WeekFitLocalizedString("coach.hero.myRead", locale: Locale(identifier: "ru")),
            "Что важно сейчас"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("coach.hero.myRecommendation", locale: Locale(identifier: "ru")),
            "Что делать"
        )
    }

    func testRussianCoachMetricAcronymsUseNativeForms() {
        let snapshot = WeekFitLocalizedString(
            "coach.snapshot.recoveryHrvRhrFormat",
            locale: Locale(identifier: "ru")
        )
        let status = WeekFitLocalizedString(
            "coach.status.recovery.hrvRhrFormat",
            locale: Locale(identifier: "ru")
        )
        for localized in [snapshot, status] {
            XCTAssertTrue(localized.contains("ВСР"))
            XCTAssertTrue(localized.contains("ПП"))
            XCTAssertFalse(localized.contains("HRV"))
            XCTAssertFalse(localized.contains("RHR"))
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
            "coach.theMainWorkIsDoneEatProteinDrinkWater": "Основная тренировка завершена. Съешьте белок, выпейте воды и дайте пульсу успокоиться.",
            "coach.eveningReview.tomorrow.recoveryRecommended": "Завтра — день восстановления",
            "coach.actions.shortenIfNeeded": "Сократите, если нужно.",
            "coach.sipWaterIfNeeded": "Выпейте воды, если хочется.",
            "coach.rationale.protectMainEffort.title": "Берегите главную работу дня."
        ]

        for (key, expected) in expectedCopy {
            let localized = WeekFitLocalizedString(key, locale: Locale(identifier: "ru"))
            XCTAssertEqual(localized, expected, "Mismatch for \(key)")
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("тренеров"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("потолок"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("превращайте"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("рекомендуется"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("при необходимости"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("в приоритете"))
            XCTAssertFalse(localized.localizedCaseInsensitiveContains("жидкость"))
        }
    }

    func testRussianCoachCatalogAvoidsProhibitedEditorialPhrases() {
        let coachKeys = [
            "coach.section.insight.title",
            "today.coachInsight.opensCoach",
            "coach.eveningReview.tomorrow.recoveryRecommended",
            "coach.nothingRequiresAttentionRightNowStayActiveHydrateWell",
            "coach.humanDecision.focusOnRecoveryNormalFoodHydrationAnd.2023",
            "coach.priority.lowerTheCeiling.743",
            "coach.priority.lowerTomorrowSCeiling.741",
            "coach.actions.letRecoveryStart",
            "coach.snapshot.recoveryHrvRhrFormat"
        ]

        let prohibited = [
            "коуч",
            "инсайт коуча",
            "в приоритете",
            "потолок",
            "жидкость",
            "гидратация",
            "рекомендуется",
            "при необходимости",
            "требует внимания",
            "в рамках",
            "восстановление отстаёт"
        ]

        for key in coachKeys {
            let localized = WeekFitLocalizedString(key, locale: Locale(identifier: "ru")).lowercased()
            for phrase in prohibited {
                XCTAssertFalse(
                    localized.contains(phrase.lowercased()),
                    "Key \(key) still contains prohibited phrase: \(phrase)"
                )
            }
            XCTAssertFalse(localized.contains("сессия") && !localized.contains("велосессия"))
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

    func testRussianCoachRuntimeProtectMainEffortMapping() {
        WeekFitSetCurrentLanguage(.russian)

        let primary = WeekFitCoachRuntimeLocalizedString("Protect the main effort")
        let alias = WeekFitCoachRuntimeLocalizedString("Защитите главное усилие")

        XCTAssertEqual(primary, "Берегите главную работу дня.")
        XCTAssertEqual(alias, "Берегите главную работу дня.")
        XCTAssertNotEqual(primary, "Почему это важно")
    }

    func testRussianCoachRuntimeRecommendationAndCautionLabels() {
        WeekFitSetCurrentLanguage(.russian)

        XCTAssertEqual(WeekFitCoachRuntimeLocalizedString("My Recommendation"), "Что делать")
        XCTAssertEqual(WeekFitCoachRuntimeLocalizedString("Be Careful With"), "Чего избегать")
        XCTAssertEqual(WeekFitCoachRuntimeLocalizedString("My Assessment"), "Моя оценка")
        XCTAssertEqual(WeekFitCoachRuntimeLocalizedString("My Read"), "Моя оценка")
    }

    func testRussianOptionalIntensityCopyDoesNotInvertMeaning() {
        WeekFitSetCurrentLanguage(.russian)

        let sources: [(String, String)] = [
            (
                "Keep optional intensity off the table today.",
                "Без дополнительной интенсивности — сегодня она не нужна."
            ),
            (
                "Keep optional intensity off the table for the rest of today.",
                "Без дополнительной интенсивности до конца дня — сегодня она не нужна."
            )
        ]

        for (english, expectedRussian) in sources {
            // Live bilingual packs are the source of truth for these lines.
            XCTAssertFalse(expectedRussian.localizedCaseInsensitiveContains("оставьте необязательную"))
            XCTAssertTrue(expectedRussian.localizedCaseInsensitiveContains("без дополнительной интенсивности"))
            XCTAssertEqual(
                english.contains("optional intensity"),
                true
            )
        }

        // Spot-check that the inverted phrasing is gone from live Coach sources.
        let coachRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WeekFit/Features/Nutrition/new/Coach")
        let forbidden = "Оставьте необязательную интенсивность"
        let enumerator = FileManager.default.enumerator(at: coachRoot, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let contents = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            XCTAssertFalse(
                contents.contains(forbidden),
                "Found inverted optional-intensity Russian in \(file.lastPathComponent)"
            )
        }
    }

    func testRussianCoachLivePacksAvoidInformalTyAndPriorityCalques() throws {
        let coachRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WeekFit/Features/Nutrition/new/Coach")
        let appText = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WeekFit/Localization/AppText.swift")

        var files: [URL] = [appText]
        let enumerator = FileManager.default.enumerator(at: coachRoot, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "swift", !file.path.contains("/Docs/") {
                files.append(file)
            }
        }

        let informal = try NSRegularExpression(pattern: #"(?<![А-Яа-яЁё])(ты|тебе|тебя|твой|твоя|твоё|твои)(?![А-Яа-яЁё])"#)
        let prohibitedSubstrings = [
            "в приоритете",
            "восстановление отстаёт",
            "Оставьте необязательную интенсивность",
            "Инсайт коуча",
            "вкладка Коуч"
        ]

        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(contents.startIndex..., in: contents)
            XCTAssertEqual(
                informal.numberOfMatches(in: contents, range: range),
                0,
                "Informal ты found in \(file.lastPathComponent)"
            )
            for phrase in prohibitedSubstrings {
                XCTAssertFalse(
                    contents.contains(phrase),
                    "Prohibited phrase '\(phrase)' found in \(file.lastPathComponent)"
                )
            }
        }
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
