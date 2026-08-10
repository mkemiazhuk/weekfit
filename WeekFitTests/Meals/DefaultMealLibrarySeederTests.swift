import XCTest
@testable import WeekFit

final class DefaultMealLibrarySeederTests: XCTestCase {

    func testBuildStarterMeals_hasExpectedSlotCounts() {
        let meals = DefaultMealLibrarySeeder.buildStarterMeals()
        XCTAssertEqual(meals.count, 14)

        let breakfast = meals.filter { $0.slot == .breakfast }
        let lunch = meals.filter { $0.slot == .lunch }
        let dinner = meals.filter { $0.slot == .dinner }

        XCTAssertEqual(breakfast.count, 8)
        XCTAssertEqual(lunch.count, 3)
        XCTAssertEqual(dinner.count, 3)
    }

    func testBuildStarterMeals_matchBuilderSaveShape() {
        let meals = DefaultMealLibrarySeeder.buildStarterMeals()
        let ids = Set(meals.map(\.id))

        for id in DefaultMealLibrarySeeder.breakfastIDs
            + DefaultMealLibrarySeeder.lunchIDs
            + DefaultMealLibrarySeeder.dinnerIDs
        {
            XCTAssertTrue(ids.contains(id), "Missing starter meal \(id)")
        }

        XCTAssertTrue(meals.allSatisfy { $0.libraryKind == .meal })
        XCTAssertTrue(meals.allSatisfy { $0.creationMode == .ingredients })
        XCTAssertTrue(meals.allSatisfy { $0.imageName == "plate-dark" })
        XCTAssertTrue(meals.allSatisfy { ($0.builderImageItems?.isEmpty == false) })
        XCTAssertTrue(meals.allSatisfy { !$0.ingredients.isEmpty })
        XCTAssertTrue(meals.allSatisfy { $0.calories > 0 })
        XCTAssertFalse(meals.allSatisfy { $0.type == .balanced }, "Starters should vary meal types for coach strategy")
        XCTAssertTrue(meals.contains { $0.type == .recovery })
        XCTAssertTrue(meals.contains { $0.type == .preWorkout })
        XCTAssertTrue(meals.contains { $0.type == .highProtein })

        for id in DefaultMealLibrarySeeder.breakfastIDs {
            XCTAssertEqual(meals.first { $0.id == id }?.suggestedTime, "08:30")
        }
        for id in DefaultMealLibrarySeeder.lunchIDs {
            XCTAssertEqual(meals.first { $0.id == id }?.suggestedTime, "13:00")
        }
        for id in DefaultMealLibrarySeeder.dinnerIDs {
            XCTAssertEqual(meals.first { $0.id == id }?.suggestedTime, "19:00")
        }
    }

    func testBuildStarterMeals_builderItemsResolveToCatalogIngredients() throws {
        let meals = DefaultMealLibrarySeeder.buildStarterMeals()
        let catalogIDs = Set(MealBuilderDemoData.ingredients.map(\.id))

        for meal in meals {
            let items = try XCTUnwrap(meal.builderImageItems)
            XCTAssertEqual(items.count, meal.ingredients.count)
            for item in items {
                XCTAssertTrue(catalogIDs.contains(item.id), "Unknown ingredient \(item.id)")
                XCTAssertGreaterThan(item.grams, 0)
            }
        }
    }

    func testStarterMeals_haveUniquePreparationSteps() {
        let meals = DefaultMealLibrarySeeder.buildStarterMeals()
        var seen = Set<String>()

        for meal in meals {
            let steps = meal.generatedSteps
            XCTAssertEqual(steps.count, 4, "Expected 4 steps for \(meal.id)")
            XCTAssertFalse(
                steps.contains(where: { $0.localizedCaseInsensitiveContains("Cook or assemble") }),
                "Generic fallback steps still used for \(meal.id)"
            )
            let fingerprint = steps.joined(separator: "|")
            XCTAssertFalse(seen.contains(fingerprint), "Duplicate steps for \(meal.id)")
            seen.insert(fingerprint)
        }
    }

    func testIsLegacyCatalogOnly_detectsOldJSONSeed() {
        XCTAssertTrue(
            DefaultMealLibrarySeeder.isLegacyCatalogOnly([
                Meals(
                    id: "meal_chicken_rice_bowl",
                    title: "Chicken",
                    subtitle: "",
                    imageName: "meal-chicken",
                    type: .balanced,
                    calories: 1,
                    protein: 1,
                    carbs: 1,
                    fats: 1,
                    fiber: 0,
                    benefits: [],
                    ingredients: []
                )
            ])
        )
        XCTAssertFalse(
            DefaultMealLibrarySeeder.isLegacyCatalogOnly([
                Meals(
                    id: "custom_meal_user_own",
                    title: "Mine",
                    subtitle: "",
                    imageName: "plate-dark",
                    type: .balanced,
                    calories: 1,
                    protein: 1,
                    carbs: 1,
                    fats: 1,
                    fiber: 0,
                    benefits: [],
                    ingredients: [],
                    creationMode: .ingredients
                )
            ])
        )
    }

    func testWorldBreakfasts_useCuratedTitlesAndUniqueSteps() {
        let curatedIDs = [
            "custom_meal_starter_avocado_toast",
            "custom_meal_starter_shakshuka",
            "custom_meal_starter_huevos_rancheros",
            "custom_meal_starter_english_breakfast",
            "custom_meal_starter_japanese_breakfast",
        ]
        let meals = DefaultMealLibrarySeeder.buildStarterMeals()

        for id in curatedIDs {
            let meal = meals.first { $0.id == id }
            XCTAssertNotNil(meal, "Missing world breakfast \(id)")
            XCTAssertEqual(meal?.suggestedTime, "08:30")
            XCTAssertEqual(meal?.slot, .breakfast)
            XCTAssertEqual(
                meal?.localizedDisplayTitle,
                StarterMealPreparation.title(forMealID: id)
            )
            XCTAssertEqual(meal?.title, StarterMealPreparation.storedEnglishTitle(forMealID: id))
        }
    }

    @MainActor
    func testV3ToV4Migration_addsWorldBreakfastsOnceAndDoesNotRestoreDeletes() {
        let suiteName = "weekfit.tests.meals.seed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let v3Meals = DefaultMealLibrarySeeder.buildStarterMeals().filter {
            DefaultMealLibrarySeeder.v3StarterIDs.contains($0.id)
        }
        XCTAssertEqual(v3Meals.count, 9)

        defaults.set(true, forKey: DefaultMealLibrarySeeder.v3SeededKey)
        defaults.set(false, forKey: DefaultMealLibrarySeeder.seededKey)

        let settings = WeekFitUserSettings.shared
        settings.replaceCustomMealsCatalog(v3Meals)

        // First seed after upgrade: append world breakfasts + set v4.
        XCTAssertTrue(
            DefaultMealLibrarySeeder.seedIfNeeded(settings: settings, defaults: defaults)
        )
        XCTAssertTrue(defaults.bool(forKey: DefaultMealLibrarySeeder.seededKey))
        let afterUpgrade = settings.customMealsCatalog
        XCTAssertEqual(afterUpgrade.count, 14)

        // User deletes a world breakfast.
        let pruned = afterUpgrade.filter { $0.id != "custom_meal_starter_shakshuka" }
        settings.replaceCustomMealsCatalog(pruned)
        settings.setCustomMealsStorage(CustomMealStore.encode(pruned))

        // Subsequent launches must NOT restore the deleted starter.
        XCTAssertFalse(
            DefaultMealLibrarySeeder.seedIfNeeded(settings: settings, defaults: defaults)
        )
        XCTAssertFalse(settings.customMealsCatalog.contains { $0.id == "custom_meal_starter_shakshuka" })
        XCTAssertEqual(settings.customMealsCatalog.count, 13)
    }

    func testCurrentStarterCatalog_isNotTreatedAsReplaceableLegacy() {
        let starters = DefaultMealLibrarySeeder.buildStarterMeals()
        XCTAssertTrue(DefaultMealLibrarySeeder.isCurrentStarterCatalogOnly(starters))
        XCTAssertFalse(DefaultMealLibrarySeeder.isLegacyCatalogOnly(starters))

        let legacySubset = starters.filter {
            DefaultMealLibrarySeeder.v3StarterIDs.contains($0.id)
        }
        XCTAssertEqual(legacySubset.count, 9)
        XCTAssertTrue(DefaultMealLibrarySeeder.isCurrentStarterCatalogOnly(legacySubset))
    }
}
