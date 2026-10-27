import XCTest
@testable import WeekFit

/// Guards that every predefined builder ingredient and quick item has copy for every app language.
final class MealPredefinedLocalizationCoverageTests: XCTestCase {

    private let extraLanguages: [AppLanguage] = [
        .french, .polish, .spanish, .german, .japanese, .italian, .korean
    ]

    func testEveryBuilderIngredientHasLocalizedTitleForAllAppLanguages() {
        let ingredients = MealBuilderDemoData.ingredients
        XCTAssertEqual(ingredients.count, 111)

        var failures: [String] = []
        for ingredient in ingredients {
            let english = ingredient.title.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(english.isEmpty, "Empty English title for \(ingredient.id)")

            if ingredient.russianTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append("ru missing \(ingredient.id)")
            }
            if ingredient.chineseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append("zh-Hans missing \(ingredient.id)")
            }

            for language in extraLanguages {
                let table = table(for: language)
                let localized = table[ingredient.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if localized.isEmpty {
                    failures.append("\(language.rawValue) missing \(ingredient.id)")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Predefined ingredient gaps:\n" + failures.joined(separator: "\n")
        )
    }

    func testBuilderIngredientLocalizedTitleSwitchesWithAppLanguage() {
        guard let rice = MealBuilderDemoData.ingredients.first(where: { $0.id == "base_rice" }) else {
            return XCTFail("base_rice missing")
        }

        let previous = WeekFitCurrentAppLanguage()
        defer { WeekFitSetCurrentLanguage(previous) }

        WeekFitSetCurrentLanguage(.english)
        XCTAssertEqual(rice.localizedTitle, "Rice")

        WeekFitSetCurrentLanguage(.polish)
        XCTAssertEqual(rice.localizedTitle, "Ryż")

        WeekFitSetCurrentLanguage(.russian)
        XCTAssertEqual(rice.localizedTitle, "Рис")

        WeekFitSetCurrentLanguage(.french)
        XCTAssertEqual(rice.localizedTitle, MealLocalizedTitles.french["base_rice"])
    }

    func testQuickItemsFromBundleHaveExtraLanguageTitles() {
        let items = NutritionRepository().loadQuickItems()
        XCTAssertFalse(items.isEmpty, "drinks_snacks.json failed to load in test host")

        var failures: [String] = []
        let previous = WeekFitCurrentAppLanguage()
        defer { WeekFitSetCurrentLanguage(previous) }

        for language in extraLanguages {
            WeekFitSetCurrentLanguage(language)
            for item in items {
                let key = item.title.lowercased()
                if QuickItemExtraCopy.title(key, language: language) == nil,
                   !isAcceptableLoanword(item.title) {
                    failures.append("\(language.rawValue) missing quick title '\(item.title)' (\(item.id))")
                }
                let localized = item.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if localized.isEmpty {
                    failures.append("\(language.rawValue) empty localizedTitle \(item.id)")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Quick item localization gaps:\n" + failures.joined(separator: "\n")
        )
    }

    func testComposedMealTitlesLocalizeIngredientWords() {
        let previous = WeekFitCurrentAppLanguage()
        defer { WeekFitSetCurrentLanguage(previous) }

        let items = [
            MealBuilderImageItem(
                id: "protein_chicken",
                imageName: "ingredient-chicken",
                visualSize: 1,
                visualDensity: 1,
                supportsStandalonePresentation: true,
                offsetX: 0,
                offsetY: 0,
                rotation: 0,
                zIndex: 1,
                grams: 160
            ),
            MealBuilderImageItem(
                id: "base_rice",
                imageName: "ingredient-rice",
                visualSize: 1,
                visualDensity: 1,
                supportsStandalonePresentation: true,
                offsetX: 0,
                offsetY: 0,
                rotation: 0,
                zIndex: 0,
                grams: 150
            )
        ]

        WeekFitSetCurrentLanguage(.polish)
        XCTAssertEqual(MealBuilderTitleComposer.compose(from: items), "Kurczak Ryż")

        WeekFitSetCurrentLanguage(.german)
        XCTAssertEqual(MealBuilderTitleComposer.compose(from: items), "\(MealLocalizedTitles.german["protein_chicken"]!) \(MealLocalizedTitles.german["base_rice"]!)")

        WeekFitSetCurrentLanguage(.japanese)
        XCTAssertEqual(
            MealBuilderTitleComposer.compose(from: items),
            "\(MealLocalizedTitles.japanese["protein_chicken"]!) \(MealLocalizedTitles.japanese["base_rice"]!)"
        )
    }

    private func table(for language: AppLanguage) -> [String: String] {
        switch language {
        case .french: return MealLocalizedTitles.french
        case .polish: return MealLocalizedTitles.polish
        case .spanish: return MealLocalizedTitles.spanish
        case .german: return MealLocalizedTitles.german
        case .japanese: return MealLocalizedTitles.japanese
        case .italian: return MealLocalizedTitles.italian
        case .korean: return MealLocalizedTitles.korean
        default: return [:]
        }
    }

    private func isAcceptableLoanword(_ english: String) -> Bool {
        let allowed: Set<String> = [
            "Tofu", "Tempeh", "Paneer", "Edamame", "Halloumi", "Kimchi", "Okra", "Nori",
            "Tahini", "Feta", "Mozzarella", "Hummus", "Mango", "Miso", "Pita", "Bulgur",
            "Quinoa", "Couscous", "Cola", "Pepsi", "Fanta", "Espresso", "Kefir", "Toast",
            "Muffin", "Croissant"
        ]
        return allowed.contains(english)
    }
}
