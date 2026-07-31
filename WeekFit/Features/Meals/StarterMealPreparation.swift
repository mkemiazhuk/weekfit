import Foundation

/// Real preparation steps for first-start builder meals (looked up by meal id).
enum StarterMealPreparation {

    static func steps(forMealID id: String) -> [String]? {
        guard let keys = stepKeys[id], !keys.isEmpty else { return nil }
        return keys.map { WeekFitLocalizedString($0) }
    }

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
