import Foundation

/// Seeds a starter meal library on first launch so Meals and Coach have
/// breakfast / lunch / dinner options before the user adds anything.
///
/// Meals are assembled from `MealBuilderDemoData` the same way
/// `MealBuilderView.saveMeal()` persists a user-built plate — not from
/// bundled `meals.json` hero assets.
enum DefaultMealLibrarySeeder {
    /// Bumped when starter recipe shape changes (v1 = meals.json, v2 = builder balanced).
    static let seededKey = "weekfit.defaultMealLibrary.seeded.v3"

    /// Previous seeder copied these catalog IDs; replace them with builder meals.
    private static let legacyCatalogMealIDs: Set<String> = [
        "meal_fried_eggs_spinach_hollandaise",
        "meal_apple_coconut_millet_porridge",
        "meal_milk_sponge_protein_sandwich",
        "meal_chicken_rice_bowl",
        "meal_bangkok_chicken_quinoa",
        "meal_cavatappi_chicken_meatballs",
        "meal_salmon_quinoa",
        "meal_braised_chicken_drumsticks_asparagus",
        "meal_turkey_mushroom_potato",
    ]

    /// Stable starter IDs (look like builder saves, but deterministic).
    static let breakfastIDs = [
        "custom_meal_starter_eggs_oatmeal",
        "custom_meal_starter_yogurt_berries",
        "custom_meal_starter_cottage_toast",
    ]

    static let lunchIDs = [
        "custom_meal_starter_chicken_rice",
        "custom_meal_starter_salmon_quinoa",
        "custom_meal_starter_shrimp_pasta",
    ]

    static let dinnerIDs = [
        "custom_meal_starter_turkey_sweet_potato",
        "custom_meal_starter_beef_buckwheat",
        "custom_meal_starter_tofu_brown_rice",
    ]

    private static var allStarterIDs: Set<String> {
        Set(breakfastIDs + lunchIDs + dinnerIDs)
    }

    private struct Recipe {
        let id: String
        let suggestedTime: String
        let mealsType: MealsType
        /// Ingredient catalog id → grams.
        let selections: [(id: String, grams: Int)]
    }

    private static let recipes: [Recipe] = [
        // Breakfast — recovery / high-protein morning fuel
        Recipe(
            id: breakfastIDs[0],
            suggestedTime: "08:30",
            mealsType: .recovery,
            selections: [
                ("base_oatmeal", 80),
                ("protein_eggs", 120),
                ("extra_blueberries", 60),
            ]
        ),
        Recipe(
            id: breakfastIDs[1],
            suggestedTime: "08:30",
            mealsType: .highProtein,
            selections: [
                ("base_greek_yogurt", 180),
                ("extra_strawberries", 80),
                ("extra_honey", 15),
            ]
        ),
        Recipe(
            id: breakfastIDs[2],
            suggestedTime: "08:30",
            mealsType: .preWorkout,
            selections: [
                ("base_toast", 70),
                ("protein_cottage_cheese", 150),
                ("extra_avocado", 70),
            ]
        ),
        // Lunch
        Recipe(
            id: lunchIDs[0],
            suggestedTime: "13:00",
            mealsType: .preWorkout,
            selections: [
                ("base_rice", 150),
                ("protein_chicken", 160),
                ("veg_broccoli", 100),
                ("extra_olive_oil", 10),
            ]
        ),
        Recipe(
            id: lunchIDs[1],
            suggestedTime: "13:00",
            mealsType: .antiInflammatory,
            selections: [
                ("base_quinoa", 150),
                ("protein_salmon", 150),
                ("veg_spinach", 70),
            ]
        ),
        Recipe(
            id: lunchIDs[2],
            suggestedTime: "13:00",
            mealsType: .highProtein,
            selections: [
                ("base_pasta", 160),
                ("protein_shrimp", 140),
                ("veg_tomatoes", 100),
            ]
        ),
        // Dinner — recovery-leaning evening plates
        Recipe(
            id: dinnerIDs[0],
            suggestedTime: "19:00",
            mealsType: .recovery,
            selections: [
                ("base_sweet_potato", 150),
                ("protein_turkey", 160),
                ("veg_green_beans", 100),
            ]
        ),
        Recipe(
            id: dinnerIDs[1],
            suggestedTime: "19:00",
            mealsType: .highProtein,
            selections: [
                ("base_buckwheat", 150),
                ("protein_beef", 150),
                ("veg_mushrooms", 90),
            ]
        ),
        Recipe(
            id: dinnerIDs[2],
            suggestedTime: "19:00",
            mealsType: .antiInflammatory,
            selections: [
                ("base_brown_rice", 150),
                ("protein_tofu", 150),
                ("veg_bok_choy", 100),
                ("extra_soy_sauce", 15),
            ]
        ),
    ]

    /// Builds starter meals as if saved from the ingredient meal builder.
    static func buildStarterMeals(
        from ingredients: [MealBuilderIngredient] = MealBuilderDemoData.ingredients
    ) -> [Meals] {
        let catalog = Dictionary(uniqueKeysWithValues: ingredients.map { ($0.id, $0) })
        return recipes.compactMap { buildMeal(from: $0, catalog: catalog) }
    }

    /// Seeds once when the custom catalog is empty (or only has the old
    /// meals.json starter copies). Does not re-seed after the user clears a
    /// real library (flag stays set until local data reset).
    @MainActor
    static func seedIfNeeded(
        settings: WeekFitUserSettings,
        defaults: UserDefaults = .standard
    ) {
        if defaults.bool(forKey: seededKey) { return }

        let existing = settings.customMealsCatalog
        let shouldReplace = existing.isEmpty
            || isLegacyCatalogOnly(existing)
            || isPreviousStarterOnly(existing)

        guard shouldReplace else {
            defaults.set(true, forKey: seededKey)
            return
        }

        let starter = buildStarterMeals()
        guard !starter.isEmpty else { return }

        settings.replaceCustomMealsCatalog(starter)
        defaults.set(true, forKey: seededKey)
        // Drop obsolete flags if present.
        defaults.removeObject(forKey: "weekfit.defaultMealLibrary.seeded.v1")
        defaults.removeObject(forKey: "weekfit.defaultMealLibrary.seeded.v2")
    }

    static func isLegacyCatalogOnly(_ meals: [Meals]) -> Bool {
        !meals.isEmpty && meals.allSatisfy { legacyCatalogMealIDs.contains($0.id) }
    }

    static func isPreviousStarterOnly(_ meals: [Meals]) -> Bool {
        !meals.isEmpty && meals.allSatisfy { allStarterIDs.contains($0.id) }
    }

    private static func buildMeal(
        from recipe: Recipe,
        catalog: [String: MealBuilderIngredient]
    ) -> Meals? {
        let selected: [SelectedBuilderIngredient] = recipe.selections.compactMap { entry in
            guard let ingredient = catalog[entry.id] else { return nil }
            return SelectedBuilderIngredient(ingredient: ingredient, grams: entry.grams)
        }
        guard selected.count == recipe.selections.count, !selected.isEmpty else {
            return nil
        }

        let builderImageItems = selected.map { item in
            MealBuilderImageItem(
                id: item.ingredient.id,
                imageName: item.ingredient.imageName,
                visualSize: item.ingredient.visualSize,
                visualDensity: item.ingredient.visualDensity,
                supportsStandalonePresentation: item.ingredient.supportsStandalonePresentation,
                offsetX: item.ingredient.offsetX,
                offsetY: item.ingredient.offsetY,
                rotation: item.ingredient.rotation,
                zIndex: item.ingredient.zIndex,
                grams: item.grams
            )
        }

        return Meals(
            id: recipe.id,
            title: storedTitle(from: selected),
            subtitle: storedSubtitle(from: selected),
            imageName: "plate-dark",
            type: recipe.mealsType,
            calories: selected.reduce(0) { $0 + $1.calories },
            protein: selected.reduce(0) { $0 + $1.protein },
            carbs: selected.reduce(0) { $0 + $1.carbs },
            fats: selected.reduce(0) { $0 + $1.fats },
            fiber: selected.reduce(0) { $0 + $1.fiber },
            benefits: [
                WeekFitLocalizedString("meals.builder.benefit.customMeal"),
                WeekFitLocalizedString("meals.builder.benefit.profile"),
                WeekFitLocalizedString("meals.builder.benefit.balancedIngredients"),
            ],
            ingredients: selected.map {
                MealsIngredient(
                    name: $0.ingredient.title,
                    amount: MealBuilderTitleComposer.amountText(
                        for: $0.ingredient,
                        grams: $0.grams
                    )
                )
            },
            suggestedTime: recipe.suggestedTime,
            builderImageItems: builderImageItems,
            libraryKind: .meal,
            creationMode: .ingredients
        )
    }

    /// Mirrors `MealBuilderView.mealTitle` (English stored titles).
    private static func storedTitle(from selected: [SelectedBuilderIngredient]) -> String {
        let protein = selected.first { $0.ingredient.category == .protein }?.ingredient.title
        let base = selected.first { $0.ingredient.category == .base }?.ingredient.title
        let vegetable = selected.first { $0.ingredient.category == .vegetables }?.ingredient.title
        let extra = selected.first { $0.ingredient.category == .extras }?.ingredient.title

        if let protein, let base { return "\(protein) \(base)" }
        if let base, let extra { return "\(extra) \(base)" }
        if let vegetable, let protein { return "\(protein) \(vegetable)" }
        if let base { return base }
        if let protein { return protein }
        if let vegetable { return vegetable }
        if let extra { return extra }
        return WeekFitLocalizedString("meals.builder.defaultMealTitle")
    }

    /// Mirrors `MealBuilderView.makeSubtitle` (English names + localized amounts).
    private static func storedSubtitle(from selected: [SelectedBuilderIngredient]) -> String {
        selected
            .map {
                "\($0.ingredient.title) (\(MealBuilderTitleComposer.amountText(for: $0.ingredient, grams: $0.grams)))"
            }
            .joined(separator: " + ")
    }
}
