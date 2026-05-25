import Foundation

enum MealIngredientCategory: String, Codable, CaseIterable, Identifiable {
    case base
    case protein
    case vegetables
    case extras

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base:
            return "Base"
        case .protein:
            return "Protein"
        case .vegetables:
            return "Vegetables"
        case .extras:
            return "Add-ons"
        }
    }
}

struct MealBuilderIngredient: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let imageName: String
    let category: MealIngredientCategory

    let defaultGrams: Int

    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatsPer100g: Double

    let visualSize: Int
    let offsetX: Int
    let offsetY: Int
    let rotation: Int
    let zIndex: Int
}

struct SelectedBuilderIngredient: Identifiable, Equatable {
    let ingredient: MealBuilderIngredient
    var grams: Int

    var id: String {
        ingredient.id
    }

    var caloriesValue: Double {
        ingredient.caloriesPer100g * Double(grams) / 100
    }

    var proteinValue: Double {
        ingredient.proteinPer100g * Double(grams) / 100
    }

    var carbsValue: Double {
        ingredient.carbsPer100g * Double(grams) / 100
    }

    var fatsValue: Double {
        ingredient.fatsPer100g * Double(grams) / 100
    }

    var calories: Int {
        Int(caloriesValue.rounded())
    }

    var protein: Int {
        Int(proteinValue.rounded())
    }

    var carbs: Int {
        Int(carbsValue.rounded())
    }

    var fats: Int {
        Int(fatsValue.rounded())
    }
}

enum MealBuilderDemoData {

    static let ingredients: [MealBuilderIngredient] = [

        // MARK: - Base

        .init(
            id: "base_rice",
            title: "Rice",
            imageName: "ingredient-rice",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 130,
            proteinPer100g: 2.4,
            carbsPer100g: 28.7,
            fatsPer100g: 0.3,
            visualSize: 150,
            offsetX: -34,
            offsetY: 20,
            rotation: -6,
            zIndex: 1
        ),

        .init(
            id: "base_pasta",
            title: "Pasta",
            imageName: "ingredient-pasta",
            category: .base,
            defaultGrams: 160,
            caloriesPer100g: 158,
            proteinPer100g: 5.8,
            carbsPer100g: 30.9,
            fatsPer100g: 0.9,
            visualSize: 152,
            offsetX: -34,
            offsetY: 18,
            rotation: -7,
            zIndex: 1
        ),

        .init(
            id: "base_buckwheat",
            title: "Buckwheat",
            imageName: "ingredient-buckwheat",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 92,
            proteinPer100g: 3.4,
            carbsPer100g: 19.9,
            fatsPer100g: 0.6,
            visualSize: 146,
            offsetX: -35,
            offsetY: 20,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_potatoes",
            title: "Potatoes",
            imageName: "ingredient-potatoes",
            category: .base,
            defaultGrams: 180,
            caloriesPer100g: 87,
            proteinPer100g: 1.9,
            carbsPer100g: 20.1,
            fatsPer100g: 0.1,
            visualSize: 145,
            offsetX: -33,
            offsetY: 18,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_oatmeal",
            title: "Oatmeal",
            imageName: "ingredient-oatmeal",
            category: .base,
            defaultGrams: 80,
            caloriesPer100g: 389,
            proteinPer100g: 16.9,
            carbsPer100g: 66.3,
            fatsPer100g: 6.9,
            visualSize: 148,
            offsetX: -34,
            offsetY: 18,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_muesli",
            title: "Muesli",
            imageName: "ingredient-muesli",
            category: .base,
            defaultGrams: 70,
            caloriesPer100g: 372,
            proteinPer100g: 11.0,
            carbsPer100g: 64.0,
            fatsPer100g: 7.5,
            visualSize: 145,
            offsetX: -34,
            offsetY: 18,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_greek_yogurt",
            title: "Greek Yogurt",
            imageName: "ingredient-greek-yogurt",
            category: .base,
            defaultGrams: 180,
            caloriesPer100g: 97,
            proteinPer100g: 9.0,
            carbsPer100g: 3.9,
            fatsPer100g: 5.0,
            visualSize: 132,
            offsetX: -24,
            offsetY: 12,
            rotation: -3,
            zIndex: 1
        ),

        .init(
            id: "base_toast",
            title: "Toast",
            imageName: "ingredient-toast",
            category: .base,
            defaultGrams: 70,
            caloriesPer100g: 265,
            proteinPer100g: 8.8,
            carbsPer100g: 49.0,
            fatsPer100g: 3.2,
            visualSize: 135,
            offsetX: -30,
            offsetY: 18,
            rotation: -6,
            zIndex: 1
        ),

        // MARK: - Protein

        .init(
            id: "protein_chicken",
            title: "Chicken",
            imageName: "ingredient-chicken",
            category: .protein,
            defaultGrams: 160,
            caloriesPer100g: 165,
            proteinPer100g: 31.0,
            carbsPer100g: 0,
            fatsPer100g: 3.6,
            visualSize: 118,
            offsetX: 36,
            offsetY: 7,
            rotation: 8,
            zIndex: 3
        ),

        .init(
            id: "protein_turkey",
            title: "Turkey",
            imageName: "ingredient-turkey",
            category: .protein,
            defaultGrams: 160,
            caloriesPer100g: 135,
            proteinPer100g: 29.0,
            carbsPer100g: 0,
            fatsPer100g: 1.6,
            visualSize: 118,
            offsetX: 36,
            offsetY: 7,
            rotation: 7,
            zIndex: 3
        ),

        .init(
            id: "protein_beef",
            title: "Beef",
            imageName: "ingredient-beef",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 250,
            proteinPer100g: 26.0,
            carbsPer100g: 0,
            fatsPer100g: 15.0,
            visualSize: 118,
            offsetX: 36,
            offsetY: 8,
            rotation: 8,
            zIndex: 3
        ),

        .init(
            id: "protein_salmon",
            title: "Salmon",
            imageName: "ingredient-salmon",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 208,
            proteinPer100g: 20.4,
            carbsPer100g: 0,
            fatsPer100g: 13.0,
            visualSize: 120,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_white_fish",
            title: "White Fish",
            imageName: "ingredient-white-fish",
            category: .protein,
            defaultGrams: 170,
            caloriesPer100g: 105,
            proteinPer100g: 23.0,
            carbsPer100g: 0,
            fatsPer100g: 1.0,
            visualSize: 120,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_shrimp",
            title: "Shrimp",
            imageName: "ingredient-shrimp",
            category: .protein,
            defaultGrams: 140,
            caloriesPer100g: 99,
            proteinPer100g: 24.0,
            carbsPer100g: 0.2,
            fatsPer100g: 0.3,
            visualSize: 112,
            offsetX: 38,
            offsetY: 12,
            rotation: 10,
            zIndex: 4
        ),

        .init(
            id: "protein_eggs",
            title: "Eggs",
            imageName: "ingredient-eggs",
            category: .protein,
            defaultGrams: 120,
            caloriesPer100g: 143,
            proteinPer100g: 12.6,
            carbsPer100g: 0.7,
            fatsPer100g: 9.5,
            visualSize: 112,
            offsetX: 34,
            offsetY: 10,
            rotation: 7,
            zIndex: 3
        ),

        .init(
            id: "protein_cottage_cheese",
            title: "Cottage Cheese",
            imageName: "ingredient-cottage-cheese",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 98,
            proteinPer100g: 11.1,
            carbsPer100g: 3.4,
            fatsPer100g: 4.3,
            visualSize: 116,
            offsetX: 35,
            offsetY: 10,
            rotation: 5,
            zIndex: 3
        ),

        // MARK: - Vegetables

        .init(
            id: "veg_broccoli",
            title: "Broccoli",
            imageName: "ingredient-broccoli",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 35,
            proteinPer100g: 2.4,
            carbsPer100g: 7.2,
            fatsPer100g: 0.4,
            visualSize: 95,
            offsetX: 25,
            offsetY: -45,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_spinach",
            title: "Spinach",
            imageName: "ingredient-spinach",
            category: .vegetables,
            defaultGrams: 70,
            caloriesPer100g: 23,
            proteinPer100g: 2.9,
            carbsPer100g: 3.6,
            fatsPer100g: 0.4,
            visualSize: 92,
            offsetX: 28,
            offsetY: -44,
            rotation: -4,
            zIndex: 2
        ),

        .init(
            id: "veg_tomatoes",
            title: "Tomatoes",
            imageName: "ingredient-tomatoes",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 18,
            proteinPer100g: 0.9,
            carbsPer100g: 3.9,
            fatsPer100g: 0.2,
            visualSize: 82,
            offsetX: 4,
            offsetY: -55,
            rotation: 0,
            zIndex: 2
        ),

        .init(
            id: "veg_cucumber",
            title: "Cucumber",
            imageName: "ingredient-cucumber",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 15,
            proteinPer100g: 0.7,
            carbsPer100g: 3.6,
            fatsPer100g: 0.1,
            visualSize: 86,
            offsetX: 12,
            offsetY: -56,
            rotation: -4,
            zIndex: 2
        ),

        .init(
            id: "veg_bell_pepper",
            title: "Bell Pepper",
            imageName: "ingredient-bell-pepper",
            category: .vegetables,
            defaultGrams: 90,
            caloriesPer100g: 31,
            proteinPer100g: 1.0,
            carbsPer100g: 6.0,
            fatsPer100g: 0.3,
            visualSize: 88,
            offsetX: 18,
            offsetY: -54,
            rotation: 5,
            zIndex: 2
        ),

        .init(
            id: "veg_lettuce",
            title: "Lettuce",
            imageName: "ingredient-lettuce",
            category: .vegetables,
            defaultGrams: 70,
            caloriesPer100g: 15,
            proteinPer100g: 1.4,
            carbsPer100g: 2.9,
            fatsPer100g: 0.2,
            visualSize: 92,
            offsetX: 0,
            offsetY: -60,
            rotation: -8,
            zIndex: 2
        ),

        .init(
            id: "veg_carrot",
            title: "Carrot",
            imageName: "ingredient-carrot",
            category: .vegetables,
            defaultGrams: 80,
            caloriesPer100g: 41,
            proteinPer100g: 0.9,
            carbsPer100g: 10.0,
            fatsPer100g: 0.2,
            visualSize: 84,
            offsetX: 8,
            offsetY: -54,
            rotation: 6,
            zIndex: 2
        ),

        .init(
            id: "veg_red_onion",
            title: "Red Onion",
            imageName: "ingredient-red-onion",
            category: .vegetables,
            defaultGrams: 40,
            caloriesPer100g: 40,
            proteinPer100g: 1.1,
            carbsPer100g: 9.3,
            fatsPer100g: 0.1,
            visualSize: 72,
            offsetX: 26,
            offsetY: -52,
            rotation: -6,
            zIndex: 2
        ),

        .init(
            id: "veg_mushrooms",
            title: "Mushrooms",
            imageName: "ingredient-mushrooms",
            category: .vegetables,
            defaultGrams: 90,
            caloriesPer100g: 22,
            proteinPer100g: 3.1,
            carbsPer100g: 3.3,
            fatsPer100g: 0.3,
            visualSize: 84,
            offsetX: 18,
            offsetY: -48,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_asparagus",
            title: "Asparagus",
            imageName: "ingredient-asparagus",
            category: .vegetables,
            defaultGrams: 90,
            caloriesPer100g: 20,
            proteinPer100g: 2.2,
            carbsPer100g: 3.9,
            fatsPer100g: 0.1,
            visualSize: 94,
            offsetX: 22,
            offsetY: -58,
            rotation: 8,
            zIndex: 2
        ),

        .init(
            id: "veg_zucchini",
            title: "Zucchini",
            imageName: "ingredient-zucchini",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 17,
            proteinPer100g: 1.2,
            carbsPer100g: 3.1,
            fatsPer100g: 0.3,
            visualSize: 92,
            offsetX: 15,
            offsetY: -52,
            rotation: -5,
            zIndex: 2
        ),

        // MARK: - Extras / Add-ons

        .init(
            id: "extra_olive_oil",
            title: "Olive Oil",
            imageName: "ingredient-olive-oil",
            category: .extras,
            defaultGrams: 10,
            caloriesPer100g: 884,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatsPer100g: 100,
            visualSize: 55,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),
        
        .init(
            id: "extra_butter",
            title: "Butter",
            imageName: "ingredient-butter",
            category: .extras,
            defaultGrams: 10,
            caloriesPer100g: 717,
            proteinPer100g: 0.9,
            carbsPer100g: 0.1,
            fatsPer100g: 81.1,
            visualSize: 52,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_avocado",
            title: "Avocado",
            imageName: "ingredient-avocado",
            category: .extras,
            defaultGrams: 70,
            caloriesPer100g: 160,
            proteinPer100g: 2.0,
            carbsPer100g: 8.5,
            fatsPer100g: 14.7,
            visualSize: 70,
            offsetX: -3,
            offsetY: -58,
            rotation: -8,
            zIndex: 5
        ),

        .init(
            id: "extra_banana",
            title: "Banana",
            imageName: "ingredient-banana",
            category: .extras,
            defaultGrams: 100,
            caloriesPer100g: 89,
            proteinPer100g: 1.1,
            carbsPer100g: 22.8,
            fatsPer100g: 0.3,
            visualSize: 72,
            offsetX: -5,
            offsetY: -56,
            rotation: -7,
            zIndex: 5
        ),

        .init(
            id: "extra_blueberries",
            title: "Blueberries",
            imageName: "ingredient-blueberries",
            category: .extras,
            defaultGrams: 60,
            caloriesPer100g: 57,
            proteinPer100g: 0.7,
            carbsPer100g: 14.5,
            fatsPer100g: 0.3,
            visualSize: 62,
            offsetX: 10,
            offsetY: -54,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_strawberries",
            title: "Strawberries",
            imageName: "ingredient-strawberries",
            category: .extras,
            defaultGrams: 80,
            caloriesPer100g: 32,
            proteinPer100g: 0.7,
            carbsPer100g: 7.7,
            fatsPer100g: 0.3,
            visualSize: 66,
            offsetX: 12,
            offsetY: -54,
            rotation: -3,
            zIndex: 5
        ),

        .init(
            id: "extra_apple",
            title: "Apple",
            imageName: "ingredient-apple",
            category: .extras,
            defaultGrams: 120,
            caloriesPer100g: 52,
            proteinPer100g: 0.3,
            carbsPer100g: 13.8,
            fatsPer100g: 0.2,
            visualSize: 68,
            offsetX: -6,
            offsetY: -55,
            rotation: 5,
            zIndex: 5
        ),

        .init(
            id: "extra_peanut_butter",
            title: "Peanut Butter",
            imageName: "ingredient-peanut-butter",
            category: .extras,
            defaultGrams: 20,
            caloriesPer100g: 588,
            proteinPer100g: 25.0,
            carbsPer100g: 20.0,
            fatsPer100g: 50.0,
            visualSize: 58,
            offsetX: 52,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_almonds",
            title: "Almonds",
            imageName: "ingredient-almonds",
            category: .extras,
            defaultGrams: 25,
            caloriesPer100g: 579,
            proteinPer100g: 21.2,
            carbsPer100g: 21.6,
            fatsPer100g: 49.9,
            visualSize: 55,
            offsetX: 50,
            offsetY: -20,
            rotation: 8,
            zIndex: 5
        ),

        .init(
            id: "extra_walnuts",
            title: "Walnuts",
            imageName: "ingredient-walnuts",
            category: .extras,
            defaultGrams: 25,
            caloriesPer100g: 654,
            proteinPer100g: 15.2,
            carbsPer100g: 13.7,
            fatsPer100g: 65.2,
            visualSize: 55,
            offsetX: 50,
            offsetY: -20,
            rotation: -6,
            zIndex: 5
        ),

        .init(
            id: "extra_honey",
            title: "Honey",
            imageName: "ingredient-honey",
            category: .extras,
            defaultGrams: 15,
            caloriesPer100g: 304,
            proteinPer100g: 0.3,
            carbsPer100g: 82.4,
            fatsPer100g: 0,
            visualSize: 52,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_chia_seeds",
            title: "Chia Seeds",
            imageName: "ingredient-chia-seeds",
            category: .extras,
            defaultGrams: 15,
            caloriesPer100g: 486,
            proteinPer100g: 16.5,
            carbsPer100g: 42.1,
            fatsPer100g: 30.7,
            visualSize: 48,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        )
    ]
}
