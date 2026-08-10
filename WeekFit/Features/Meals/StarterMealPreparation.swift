import Foundation

/// Curated titles and prep steps for first-start builder meals (looked up by meal id).
enum StarterMealPreparation {

    static func title(forMealID id: String) -> String? {
        guard let key = titleKeys[id] else { return nil }
        return WeekFitLocalizedString(key)
    }

    static func steps(forMealID id: String) -> [String]? {
        guard let keys = stepKeys[id], !keys.isEmpty else { return nil }
        return keys.map { WeekFitLocalizedString($0) }
    }

    /// English stored titles for recipes that use a curated world-breakfast name
    /// instead of the protein+base composer (e.g. "Shakshuka" vs "Eggs Tomatoes").
    static func storedEnglishTitle(forMealID id: String) -> String? {
        storedEnglishTitles[id]
    }

    private static let titleKeys: [String: String] = [
        "custom_meal_starter_avocado_toast": "meals.starter.avocadoToast.title",
        "custom_meal_starter_shakshuka": "meals.starter.shakshuka.title",
        "custom_meal_starter_huevos_rancheros": "meals.starter.huevosRancheros.title",
        "custom_meal_starter_english_breakfast": "meals.starter.englishBreakfast.title",
        "custom_meal_starter_japanese_breakfast": "meals.starter.japaneseBreakfast.title",
    ]

    private static let storedEnglishTitles: [String: String] = [
        "custom_meal_starter_avocado_toast": "Avocado Toast",
        "custom_meal_starter_shakshuka": "Shakshuka",
        "custom_meal_starter_huevos_rancheros": "Huevos Rancheros",
        "custom_meal_starter_english_breakfast": "English Breakfast",
        "custom_meal_starter_japanese_breakfast": "Japanese Breakfast",
    ]

    private static let stepKeys: [String: [String]] = [
        "custom_meal_starter_eggs_oatmeal": [
            "meals.starter.eggsOatmeal.step1",
            "meals.starter.eggsOatmeal.step2",
            "meals.starter.eggsOatmeal.step3",
            "meals.starter.eggsOatmeal.step4",
        ],
        "custom_meal_starter_yogurt_berries": [
            "meals.starter.yogurtBerries.step1",
            "meals.starter.yogurtBerries.step2",
            "meals.starter.yogurtBerries.step3",
            "meals.starter.yogurtBerries.step4",
        ],
        "custom_meal_starter_cottage_toast": [
            "meals.starter.cottageToast.step1",
            "meals.starter.cottageToast.step2",
            "meals.starter.cottageToast.step3",
            "meals.starter.cottageToast.step4",
        ],
        "custom_meal_starter_avocado_toast": [
            "meals.starter.avocadoToast.step1",
            "meals.starter.avocadoToast.step2",
            "meals.starter.avocadoToast.step3",
            "meals.starter.avocadoToast.step4",
        ],
        "custom_meal_starter_shakshuka": [
            "meals.starter.shakshuka.step1",
            "meals.starter.shakshuka.step2",
            "meals.starter.shakshuka.step3",
            "meals.starter.shakshuka.step4",
        ],
        "custom_meal_starter_huevos_rancheros": [
            "meals.starter.huevosRancheros.step1",
            "meals.starter.huevosRancheros.step2",
            "meals.starter.huevosRancheros.step3",
            "meals.starter.huevosRancheros.step4",
        ],
        "custom_meal_starter_english_breakfast": [
            "meals.starter.englishBreakfast.step1",
            "meals.starter.englishBreakfast.step2",
            "meals.starter.englishBreakfast.step3",
            "meals.starter.englishBreakfast.step4",
        ],
        "custom_meal_starter_japanese_breakfast": [
            "meals.starter.japaneseBreakfast.step1",
            "meals.starter.japaneseBreakfast.step2",
            "meals.starter.japaneseBreakfast.step3",
            "meals.starter.japaneseBreakfast.step4",
        ],
        "custom_meal_starter_chicken_rice": [
            "meals.starter.chickenRice.step1",
            "meals.starter.chickenRice.step2",
            "meals.starter.chickenRice.step3",
            "meals.starter.chickenRice.step4",
        ],
        "custom_meal_starter_salmon_quinoa": [
            "meals.starter.salmonQuinoa.step1",
            "meals.starter.salmonQuinoa.step2",
            "meals.starter.salmonQuinoa.step3",
            "meals.starter.salmonQuinoa.step4",
        ],
        "custom_meal_starter_shrimp_pasta": [
            "meals.starter.shrimpPasta.step1",
            "meals.starter.shrimpPasta.step2",
            "meals.starter.shrimpPasta.step3",
            "meals.starter.shrimpPasta.step4",
        ],
        "custom_meal_starter_turkey_sweet_potato": [
            "meals.starter.turkeySweetPotato.step1",
            "meals.starter.turkeySweetPotato.step2",
            "meals.starter.turkeySweetPotato.step3",
            "meals.starter.turkeySweetPotato.step4",
        ],
        "custom_meal_starter_beef_buckwheat": [
            "meals.starter.beefBuckwheat.step1",
            "meals.starter.beefBuckwheat.step2",
            "meals.starter.beefBuckwheat.step3",
            "meals.starter.beefBuckwheat.step4",
        ],
        "custom_meal_starter_tofu_brown_rice": [
            "meals.starter.tofuBrownRice.step1",
            "meals.starter.tofuBrownRice.step2",
            "meals.starter.tofuBrownRice.step3",
            "meals.starter.tofuBrownRice.step4",
        ],
    ]
}
