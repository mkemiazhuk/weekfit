import Foundation

/// Seeds a starter meal library on first launch so Meals and Coach have
/// breakfast / lunch / dinner options before the user adds anything.
///
/// Meals are assembled from `MealBuilderDemoData` the same way
/// `MealBuilderView.saveMeal()` persists a user-built plate — not from
/// bundled `meals.json` hero assets.
enum DefaultMealLibrarySeeder {
    /// Bumped when starter recipe shape changes (v1 = meals.json, v2 = builder balanced,
    /// v3 = 9 builder meals, v4 = +world breakfasts).
    static let seededKey = "weekfit.defaultMealLibrary.seeded.v4"
    static let v3SeededKey = "weekfit.defaultMealLibrary.seeded.v3"

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

    private static let previousSeededKeys = [
        "weekfit.defaultMealLibrary.seeded.v1",
        "weekfit.defaultMealLibrary.seeded.v2",
        v3SeededKey,
    ]

    /// Starter IDs that existed before the v4 world-breakfast expansion.
    static let v3StarterIDs: Set<String> = [
        "custom_meal_starter_eggs_oatmeal",
        "custom_meal_starter_yogurt_berries",
        "custom_meal_starter_cottage_toast",
        "custom_meal_starter_chicken_rice",
        "custom_meal_starter_salmon_quinoa",
        "custom_meal_starter_shrimp_pasta",
        "custom_meal_starter_turkey_sweet_potato",
        "custom_meal_starter_beef_buckwheat",
        "custom_meal_starter_tofu_brown_rice",
    ]

    /// One-time content introduced by the v3 → v4 migration.
    static let worldBreakfastIDsIntroducedInV4: Set<String> = [
        "custom_meal_starter_avocado_toast",
        "custom_meal_starter_shakshuka",
        "custom_meal_starter_huevos_rancheros",
        "custom_meal_starter_english_breakfast",
        "custom_meal_starter_japanese_breakfast",
    ]

    /// Stable starter IDs (look like builder saves, but deterministic).
    static let breakfastIDs = [
        "custom_meal_starter_eggs_oatmeal",
        "custom_meal_starter_yogurt_berries",
        "custom_meal_starter_cottage_toast",
        "custom_meal_starter_avocado_toast",
        "custom_meal_starter_shakshuka",
        "custom_meal_starter_huevos_rancheros",
        "custom_meal_starter_english_breakfast",
        "custom_meal_starter_japanese_breakfast",
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
        // World breakfasts — iconic plates assembled from the builder catalog
        Recipe(
            id: breakfastIDs[3],
            suggestedTime: "08:30",
            mealsType: .balanced,
            selections: [
                ("base_toast", 70),
                ("extra_avocado", 90),
                ("protein_eggs", 100),
                ("veg_tomatoes", 60),
            ]
        ),
        Recipe(
            id: breakfastIDs[4],
            suggestedTime: "08:30",
            mealsType: .highProtein,
            selections: [
                ("protein_eggs", 120),
                ("veg_tomatoes", 150),
                ("veg_bell_pepper", 80),
                ("veg_red_onion", 40),
                ("extra_olive_oil", 10),
            ]
        ),
        Recipe(
            id: breakfastIDs[5],
            suggestedTime: "08:30",
            mealsType: .preWorkout,
            selections: [
                ("base_corn_tortilla", 60),
                ("protein_eggs", 120),
                ("base_black_beans", 100),
                ("veg_tomatoes", 80),
            ]
        ),
        Recipe(
            id: breakfastIDs[6],
            suggestedTime: "08:30",
            mealsType: .highProtein,
            selections: [
                ("protein_eggs", 120),
                ("base_toast", 70),
                ("extra_pork_ham", 60),
                ("veg_mushrooms", 80),
                ("veg_tomatoes", 70),
            ]
        ),
        Recipe(
            id: breakfastIDs[7],
            suggestedTime: "08:30",
            mealsType: .antiInflammatory,
            selections: [
                ("base_brown_rice", 120),
                ("protein_eggs", 100),
                ("veg_spinach", 60),
                ("veg_nori", 5),
                ("extra_soy_sauce", 10),
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

    /// Single-flight gate — `seedIfNeeded` is `@MainActor` but can still be re-entered
    /// from nested sync calls (`init` → `refreshFromStorage`) before returning.
    @MainActor private static var isSeeding = false

    /// Seeds when the custom catalog is empty (or only has obsolete JSON-catalog copies).
    ///
    /// Persistence is **UserDefaults** (`CustomMealStore.storageKey`), not SwiftData.
    /// The `seededKey` flag prevents re-seeding a non-empty user library. If the flag is
    /// set but the catalog is empty (partial wipe / stuck flag), we recover starters once.
    ///
    /// When the catalog already participates in the starter library, missing recipes
    /// (e.g. new world breakfasts after a version bump) are appended without wiping
    /// user-created meals.
    ///
    /// Important: a catalog that already contains the **current** starter IDs must NOT be
    /// treated as replaceable — that caused every startup to wipe+reinsert the same meals.
    @MainActor
    @discardableResult
    static func seedIfNeeded(
        settings: WeekFitUserSettings,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let run = UUID()
        let accountMode = String(describing: AccountSessionController.shared.mode)

        if isSeeding {
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "singleFlightInProgress",
                detail: "account=\(accountMode)"
            )
            return false
        }

        isSeeding = true
        defer { isSeeding = false }

        MealsSeedDiagnostics.begin(
            run: run,
            detail: "account=\(accountMode) storage=\(CustomMealStore.storageKey) seededKey=\(seededKey)"
        )

        let existing = settings.customMealsCatalog
        MealsSeedDiagnostics.info("MEALS SEED preexistingCount=\(existing.count)", run: run)

        let flagSet = defaults.bool(forKey: seededKey)
        let isCurrentStarterCatalog = isCurrentStarterCatalogOnly(existing)
        let shouldReplace = existing.isEmpty || isLegacyCatalogOnly(existing)

        if migrateV3ToV4WorldBreakfastsIfNeeded(
            into: existing,
            settings: settings,
            defaults: defaults,
            run: run,
            accountMode: accountMode
        ) {
            return true
        }

        if flagSet, !existing.isEmpty, !shouldReplace {
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "alreadySeededNonEmptyCatalog",
                detail: "preexistingCount=\(existing.count) currentStarters=\(isCurrentStarterCatalog) account=\(accountMode)"
            )
            return false
        }

        if isCurrentStarterCatalog {
            // Starters already present; just ensure the version flag is set.
            defaults.set(true, forKey: seededKey)
            clearPreviousSeededKeys(in: defaults)
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "currentStarterCatalogPresent",
                detail: "preexistingCount=\(existing.count) account=\(accountMode)"
            )
            return false
        }

        if flagSet, !existing.isEmpty, shouldReplace {
            MealsSeedDiagnostics.info(
                "MEALS SEED replacing obsolete legacy count=\(existing.count)",
                run: run
            )
        }

        if flagSet, existing.isEmpty {
            MealsSeedDiagnostics.info(
                "MEALS SEED RECOVER emptyCatalogDespiteFlag — restoring starter library",
                run: run
            )
        }

        guard shouldReplace else {
            defaults.set(true, forKey: seededKey)
            clearPreviousSeededKeys(in: defaults)
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "userLibraryPresent",
                detail: "preexistingCount=\(existing.count) flagSet=true account=\(accountMode)"
            )
            return false
        }

        let starter = buildStarterMeals()
        MealsSeedDiagnostics.info("MEALS SEED sourceItems=\(starter.count)", run: run)
        guard !starter.isEmpty else {
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "starterBuildReturnedEmpty",
                detail: "ingredient catalog likely missing recipe IDs account=\(accountMode)"
            )
            return false
        }

        for meal in starter {
            MealsSeedDiagnostics.info(
                "MEALS SEED inserting item id=\(meal.id) title=\(meal.title)",
                run: run
            )
        }
        MealsSeedDiagnostics.info("MEALS SEED insertedCount=\(starter.count)", run: run)

        return persistCatalog(
            starter,
            settings: settings,
            defaults: defaults,
            run: run,
            accountMode: accountMode
        )
    }

    /// One-time v3 → v4 content migration: append world breakfasts once, then never
    /// restore starters the user later deletes.
    @MainActor
    private static func migrateV3ToV4WorldBreakfastsIfNeeded(
        into existing: [Meals],
        settings: WeekFitUserSettings,
        defaults: UserDefaults,
        run: UUID,
        accountMode: String
    ) -> Bool {
        // v4 marker already set — migration finished; never re-insert missing starters.
        if defaults.bool(forKey: seededKey) {
            return false
        }

        guard !existing.isEmpty, !isLegacyCatalogOnly(existing) else { return false }

        let hadV3Marker = defaults.bool(forKey: v3SeededKey)
        let hasV3Starter = existing.contains { v3StarterIDs.contains($0.id) }
        guard hadV3Marker || hasV3Starter else { return false }

        let existingIDs = Set(existing.map(\.id))
        let missingWorldBreakfasts = buildStarterMeals().filter {
            worldBreakfastIDsIntroducedInV4.contains($0.id) && !existingIDs.contains($0.id)
        }

        if missingWorldBreakfasts.isEmpty {
            defaults.set(true, forKey: seededKey)
            clearPreviousSeededKeys(in: defaults)
            MealsSeedDiagnostics.skipped(
                run: run,
                reason: "v3ToV4AlreadyComplete",
                detail: "account=\(accountMode)"
            )
            return false
        }

        MealsSeedDiagnostics.info(
            "MEALS SEED v3→v4 world breakfasts count=\(missingWorldBreakfasts.count) ids=\(missingWorldBreakfasts.map(\.id).joined(separator: ","))",
            run: run
        )

        let merged = existing + missingWorldBreakfasts
        return persistCatalog(
            merged,
            settings: settings,
            defaults: defaults,
            run: run,
            accountMode: accountMode
        )
    }

    @MainActor
    private static func persistCatalog(
        _ meals: [Meals],
        settings: WeekFitUserSettings,
        defaults: UserDefaults,
        run: UUID,
        accountMode: String
    ) -> Bool {
        MealsSeedDiagnostics.info("MEALS SEED save BEGIN", run: run)
        let encoded = CustomMealStore.encode(meals)
        defaults.set(encoded, forKey: CustomMealStore.storageKey)
        settings.replaceCustomMealsCatalog(meals)
        settings.setCustomMealsStorage(encoded)

        let verified = CustomMealStore.load(
            from: defaults.string(forKey: CustomMealStore.storageKey) ?? ""
        )
        let postSaveCount = verified.count
        MealsSeedDiagnostics.info("MEALS SEED postSaveFetchCount=\(postSaveCount)", run: run)

        guard postSaveCount == meals.count, postSaveCount > 0 else {
            MealsSeedDiagnostics.error(
                run: run,
                operation: "verifyPersistedCatalog",
                error: NSError(
                    domain: "com.weekfit.app.mealsSeed",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Expected \(meals.count) persisted meals, found \(postSaveCount)."
                    ]
                )
            )
            return false
        }

        defaults.set(true, forKey: seededKey)
        clearPreviousSeededKeys(in: defaults)
        MealsSeedDiagnostics.info("MEALS SEED save SUCCESS", run: run)
        MealsSeedDiagnostics.info("MEALS SEED account=\(accountMode)", run: run)
        MealsSeedDiagnostics.complete(
            run: run,
            detail: "persistedCount=\(postSaveCount) account=\(accountMode)"
        )
        return true
    }

    private static func clearPreviousSeededKeys(in defaults: UserDefaults) {
        for key in previousSeededKeys {
            defaults.removeObject(forKey: key)
        }
    }

    static func isLegacyCatalogOnly(_ meals: [Meals]) -> Bool {
        !meals.isEmpty && meals.allSatisfy { legacyCatalogMealIDs.contains($0.id) }
    }

    /// True when every meal is one of the **current** starter IDs (healthy post-seed state).
    static func isCurrentStarterCatalogOnly(_ meals: [Meals]) -> Bool {
        !meals.isEmpty && meals.allSatisfy { allStarterIDs.contains($0.id) }
    }

    /// Obsolete helper name kept for tests / call sites that meant "starter IDs only".
    static func isPreviousStarterOnly(_ meals: [Meals]) -> Bool {
        isCurrentStarterCatalogOnly(meals)
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

        let title = StarterMealPreparation.storedEnglishTitle(forMealID: recipe.id)
            ?? storedTitle(from: selected)

        return Meals(
            id: recipe.id,
            title: title,
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
