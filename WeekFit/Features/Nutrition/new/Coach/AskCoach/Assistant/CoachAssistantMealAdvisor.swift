import Foundation

/// Practical meal options grounded in Meal Builder ingredient macros (documented estimates).
enum CoachAssistantMealAdvisor {

    struct Option: Equatable, Sendable, Identifiable {
        let id: String
        let titleEnglish: String
        let titleRussian: String
        let portionEnglish: String
        let portionRussian: String
        let proteinGrams: Int
        let calories: Int
        let isVegetarian: Bool

        var text: CoachBilingualText {
            CoachAssistantCopy.bi(
                "Try \(titleEnglish) (\(portionEnglish)) — about \(proteinGrams) g protein and \(calories) kcal. This isn’t logged yet.",
                "Вариант: \(titleRussian) (\(portionRussian)) — около \(proteinGrams) г белка и \(calories) ккал. Это ещё не записано."
            )
        }
    }

    /// Built from `MealBuilderDemoData` per-100g values × typical portions.
    static let catalog: [Option] = {
        func macros(ingredientID: String, grams: Double) -> (protein: Int, calories: Int)? {
            guard let item = MealBuilderDemoData.ingredients.first(where: { $0.id == ingredientID }) else {
                return nil
            }
            let factor = grams / 100.0
            return (
                Int((item.proteinPer100g * factor).rounded()),
                Int((Double(item.caloriesPer100g) * factor).rounded())
            )
        }

        var options: [Option] = []

        if let yogurt = macros(ingredientID: "base_greek_yogurt", grams: 200) {
            options.append(
                Option(
                    id: "meal.greekYogurt",
                    titleEnglish: "Greek yogurt with berries",
                    titleRussian: "Греческий йогурт с ягодами",
                    portionEnglish: "200 g yogurt",
                    portionRussian: "200 г йогурта",
                    proteinGrams: yogurt.protein,
                    calories: yogurt.calories + 40,
                    isVegetarian: true
                )
            )
        }

        if let chicken = macros(ingredientID: "protein_chicken", grams: 150),
           let rice = macros(ingredientID: "base_rice", grams: 150) {
            options.append(
                Option(
                    id: "meal.chickenRice",
                    titleEnglish: "Chicken with rice",
                    titleRussian: "Курица с рисом",
                    portionEnglish: "150 g chicken + 150 g cooked rice",
                    portionRussian: "150 г курицы + 150 г варёного риса",
                    proteinGrams: chicken.protein + rice.protein,
                    calories: chicken.calories + rice.calories,
                    isVegetarian: false
                )
            )
        }

        if let cottage = macros(ingredientID: "protein_cottage_cheese", grams: 180) {
            options.append(
                Option(
                    id: "meal.cottage",
                    titleEnglish: "Cottage cheese bowl",
                    titleRussian: "Творог",
                    portionEnglish: "180 g cottage cheese",
                    portionRussian: "180 г творога",
                    proteinGrams: cottage.protein,
                    calories: cottage.calories,
                    isVegetarian: true
                )
            )
        }

        if let tofu = macros(ingredientID: "protein_tofu", grams: 180),
           let veg = macros(ingredientID: "veg_broccoli", grams: 150) {
            options.append(
                Option(
                    id: "meal.tofuVeg",
                    titleEnglish: "Tofu with vegetables",
                    titleRussian: "Тофу с овощами",
                    portionEnglish: "180 g tofu + vegetables",
                    portionRussian: "180 г тофу + овощи",
                    proteinGrams: tofu.protein + veg.protein,
                    calories: tofu.calories + veg.calories,
                    isVegetarian: true
                )
            )
        }

        if let eggs = macros(ingredientID: "protein_eggs", grams: 120),
           let toast = macros(ingredientID: "base_toast", grams: 60) {
            options.append(
                Option(
                    id: "meal.eggsToast",
                    titleEnglish: "Eggs with toast",
                    titleRussian: "Яйца с тостом",
                    portionEnglish: "2 eggs + toast",
                    portionRussian: "2 яйца + тост",
                    proteinGrams: eggs.protein + toast.protein,
                    calories: eggs.calories + toast.calories,
                    isVegetarian: true
                )
            )
        }

        // Fallback documented estimates if ingredient IDs differ in the catalog.
        if options.isEmpty {
            options = [
                Option(
                    id: "meal.fallback.yogurt",
                    titleEnglish: "Greek yogurt",
                    titleRussian: "Греческий йогурт",
                    portionEnglish: "200 g",
                    portionRussian: "200 г",
                    proteinGrams: 20,
                    calories: 130,
                    isVegetarian: true
                ),
                Option(
                    id: "meal.fallback.chicken",
                    titleEnglish: "Grilled chicken",
                    titleRussian: "Курица на гриле",
                    portionEnglish: "150 g cooked",
                    portionRussian: "150 г готовой",
                    proteinGrams: 35,
                    calories: 250,
                    isVegetarian: false
                )
            ]
        }
        return options
    }()

    static func suggest(
        preferVegetarian: Bool?,
        excludingIDs: [String],
        proteinRemaining: Int?,
        hour: Int
    ) -> Option {
        func applyDiet(_ options: [Option]) -> [Option] {
            if preferVegetarian == true {
                let veg = options.filter(\.isVegetarian)
                return veg.isEmpty ? options : veg
            }
            if preferVegetarian == false {
                let mixed = options.filter { !$0.isVegetarian }
                return mixed.isEmpty ? options : mixed
            }
            return options
        }

        var pool = applyDiet(catalog.filter { !excludingIDs.contains($0.id) })
        if pool.isEmpty {
            // All options were offered — rotate past the last one for a meaningful change.
            let rotated = applyDiet(catalog)
            if let last = excludingIDs.last,
               let index = rotated.firstIndex(where: { $0.id == last }),
               rotated.count > 1 {
                return rotated[(index + 1) % rotated.count]
            }
            pool = rotated
        }

        // Prefer a sensible portion — not the entire remaining daily protein.
        if let remaining = proteinRemaining, remaining > 0 {
            let target = min(40, max(15, remaining / 2))
            pool.sort {
                abs($0.proteinGrams - target) < abs($1.proteinGrams - target)
            }
        } else if hour < 11 {
            pool.sort { $0.calories < $1.calories }
        }

        return pool[0]
    }

    static func dietPreferenceChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "nutrition.diet.regular",
                title: CoachAssistantCopy.bi("Regular", "Обычное"),
                destination: .nutritionChooseMeal
            ),
            .init(
                id: "nutrition.diet.vegetarian",
                title: CoachAssistantCopy.bi("Vegetarian", "Вегетарианское"),
                destination: .nutritionChooseMeal
            )
        ]
    }

    static func afterSuggestionChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "nutrition.meal.another",
                title: CoachAssistantCopy.bi("Another option", "Другой вариант"),
                destination: .nutritionChooseMeal
            ),
            .init(
                id: "nutrition.openMeals",
                title: CoachAssistantCopy.openMealsChoiceTitle(),
                destination: .end,
                action: .openMealsTab
            ),
            .init(
                id: "end.done",
                title: CoachAssistantCopy.bi("Done", "Готово"),
                destination: .end
            )
        ]
    }
}
