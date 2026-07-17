import XCTest
@testable import WeekFit

final class MealCatalogMatcherTests: XCTestCase {

    private let catalog: [Meals] = [
        Meals(
            id: "meal_pork",
            title: "Pork Steaks",
            subtitle: "BBQ",
            imageName: "meal-pork-bbq",
            type: .highProtein,
            calories: 670,
            protein: 50,
            carbs: 10,
            fats: 40,
            benefits: [],
            ingredients: []
        ),
        Meals(
            id: "meal_banana_oats",
            title: "Banana Oats Bowl",
            subtitle: "Pre-workout",
            imageName: "meal-oatmeal",
            type: .preWorkout,
            calories: 430,
            protein: 15,
            carbs: 60,
            fats: 10,
            benefits: [],
            ingredients: []
        ),
        Meals(
            id: "meal_chicken",
            title: "Chicken Rice Bowl",
            subtitle: "Balanced",
            imageName: "meal-chicken",
            type: .highProtein,
            calories: 550,
            protein: 40,
            carbs: 52,
            fats: 16,
            benefits: [],
            ingredients: []
        )
    ]

    func testTeaDoesNotMatchPorkSteaks() {
        let match = MealCatalogMatcher.match(
            title: "Tea",
            imageName: "ingredient-tea",
            in: catalog
        )
        XCTAssertNil(match)
    }

    func testBananaSnackDoesNotMatchBananaOatsBowl() {
        let match = MealCatalogMatcher.match(
            title: "Banana",
            imageName: "ingredient-banana",
            in: catalog
        )
        XCTAssertNil(match)
    }

    func testExactMealTitleStillMatches() {
        let match = MealCatalogMatcher.match(
            title: "Chicken Rice Bowl",
            imageName: "ingredient-chicken",
            in: catalog
        )
        XCTAssertEqual(match?.id, "meal_chicken")
        XCTAssertEqual(match?.calories, 550)
    }

    func testMealImagePrefixStillMatches() {
        let match = MealCatalogMatcher.match(
            title: "Custom",
            imageName: "meal-chicken",
            in: catalog
        )
        XCTAssertEqual(match?.id, "meal_chicken")
    }

    func testIngredientImageDoesNotMatchMealArtwork() {
        let match = MealCatalogMatcher.match(
            title: "Mystery Drink",
            imageName: "ingredient-tea",
            in: catalog
        )
        XCTAssertNil(match)
    }

    func testQuickLogSourceIsAuthoritative() {
        XCTAssertTrue(MealCatalogMatcher.hasAuthoritativeNutrition(source: "today"))
        XCTAssertTrue(MealCatalogMatcher.hasAuthoritativeNutrition(source: "nutritionLog"))
        XCTAssertTrue(MealCatalogMatcher.hasAuthoritativeNutrition(source: "appReviewDemo"))
        XCTAssertFalse(MealCatalogMatcher.hasAuthoritativeNutrition(source: "planner"))
    }

    func testIngredientArtworkPrefersStoredNutritionEvenWithoutQuickLogSource() {
        XCTAssertTrue(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "meal",
                imageName: "ingredient-tea"
            )
        )
        XCTAssertTrue(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "drink",
                imageName: "anything"
            )
        )
        XCTAssertTrue(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "snack",
                imageName: "anything"
            )
        )
        XCTAssertTrue(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "meal",
                imageName: "protein-bar"
            )
        )
        XCTAssertTrue(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "meal",
                imageName: "rice-cakes"
            )
        )
        XCTAssertFalse(
            MealCatalogMatcher.prefersStoredNutrition(
                source: "planner",
                type: "meal",
                imageName: "meal-chicken"
            )
        )
    }

    func testSnackTypeSkipsMealRemapEvenWithoutAuthoritativeSource() {
        let activity = PlannedActivity(
            date: Date(),
            type: "snack",
            title: "Banana",
            durationMinutes: 10,
            icon: "carrot.fill",
            imageName: "ingredient-banana",
            colorRed: 0.2,
            colorGreen: 0.3,
            colorBlue: 0.9,
            calories: 89,
            source: "planner"
        )

        XCTAssertNil(MealCatalogMatcher.match(activity: activity, in: catalog))
        XCTAssertTrue(MealCatalogMatcher.prefersStoredNutrition(activity: activity))
    }

    func testActivityMatchSkipsRemapForTeaQuickLog() {
        let activity = PlannedActivity(
            date: Date(),
            type: "drink",
            title: "Tea",
            durationMinutes: 10,
            icon: "mug.fill",
            imageName: "ingredient-tea",
            colorRed: 0.2,
            colorGreen: 0.3,
            colorBlue: 0.9,
            calories: 2,
            source: "today"
        )

        XCTAssertNil(MealCatalogMatcher.match(activity: activity, in: catalog))
    }

    /// Guardrail: documents known substring traps in shipping catalogs.
    /// Safe matching must not rematch these; do not reintroduce contains()-based matching.
    func testShippingCatalogsStillHaveSubstringTrapsThatMustStayBlocked() throws {
        let meals = try loadJSON([Meals].self, resource: "meals")
        let quickItems = try loadJSON([QuickItem].self, resource: "drinks_snacks")

        let collisions = MealCatalogMatcher.substringCollisions(
            quickItems: quickItems,
            meals: meals
        )

        // These collisions are why we removed fuzzy matching — keep the list intentional.
        let pairs = Set(collisions.map { "\($0.quickTitle)|\($0.mealTitle)" })
        XCTAssertTrue(pairs.contains("Tea|Pork Steaks"))
        XCTAssertTrue(pairs.contains("Banana|Banana Oats Bowl"))

        for item in quickItems {
            let activityType: String = {
                switch item.category {
                case .drink: return "drink"
                case .snack: return "snack"
                }
            }()

            // Bare title/image matching may still hit identical meal titles
            // (e.g. Protein Shake). Runtime rematch is blocked by type/source.
            let activity = PlannedActivity(
                date: Date(),
                type: activityType,
                title: item.title,
                durationMinutes: 1,
                icon: item.icon,
                imageName: item.imageName,
                colorRed: 0.2,
                colorGreen: 0.3,
                colorBlue: 0.9,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fats: item.fats,
                fiber: item.fiber,
                source: "today"
            )
            XCTAssertNil(
                MealCatalogMatcher.match(activity: activity, in: meals),
                "Quick item \(item.id) (\(item.title)) remapped to a meal"
            )

            XCTAssertTrue(
                MealCatalogMatcher.prefersStoredNutrition(
                    source: "today",
                    type: activityType,
                    imageName: item.imageName
                ),
                "Quick item \(item.id) must prefer stored nutrition"
            )

            // Even without Quick Log source, snacks/drinks must keep catalog macros.
            XCTAssertTrue(
                MealCatalogMatcher.prefersStoredNutrition(
                    source: "planner",
                    type: activityType,
                    imageName: item.imageName
                ),
                "Quick item \(item.id) must prefer stored nutrition without today source"
            )
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: resource, withExtension: "json"),
            "Missing \(resource).json in app bundle"
        )
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
