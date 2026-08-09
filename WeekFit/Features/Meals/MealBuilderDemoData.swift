import Foundation
import SwiftUI

enum MealIngredientCategory: String, Codable, CaseIterable, Identifiable {
    case base
    case protein
    case vegetables
    case extras
    case drinks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base:
            return WeekFitLocalizedString("meals.ingredient.category.base")
        case .protein:
            return WeekFitLocalizedString("meals.ingredient.category.protein")
        case .vegetables:
            return WeekFitLocalizedString("meals.ingredient.category.vegetables")
        case .drinks:
            return WeekFitLocalizedString("meals.ingredient.category.drinks")
        case .extras:
            return WeekFitLocalizedString("meals.ingredient.category.extras")
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
    let fiberPer100g: Double

    let visualSize: Int
    let visualDensity: CGFloat
    let supportsStandalonePresentation: Bool

    let offsetX: Int
    let offsetY: Int
    let rotation: Int
    let zIndex: Int

    var localizedTitle: String {
        guard WeekFitUsesRussianLanguage() else { return title }

        return russianTitle
    }

    /// Stable Russian label for catalog matching (independent of current UI language).
    var russianTitle: String {
        Self.russianTitles[id] ?? title
    }

    private static let russianTitles: [String: String] = [
        "base_rice": "Рис",
        "base_pasta": "Паста",
        "base_buckwheat": "Гречка",
        "base_potatoes": "Картофель",
        "base_oatmeal": "Овсянка",
        "base_muesli": "Мюсли",
        "base_greek_yogurt": "Греческий йогурт",
        "base_toast": "Тост",
        "base_quinoa": "Киноа",
        "base_couscous": "Кускус",
        "base_sweet_potato": "Батат",
        "base_lentils": "Чечевица",
        "base_chickpeas": "Нут",
        "base_black_beans": "Чёрная фасоль",
        "base_soba_noodles": "Соба",
        "base_corn_tortilla": "Тортилья",
        "base_pita": "Пита",
        "base_brown_rice": "Коричневый рис",
        "base_bulgur": "Булгур",
        "base_plantain": "Плантайн",
        "base_corn": "Кукуруза консервированная",
        "protein_chicken": "Курица",
        "protein_turkey": "Индейка",
        "protein_pork": "Свинина",
        "protein_lamb": "Баранина",
        "protein_veal": "Телятина",
        "protein_duck": "Утка",
        "protein_beef": "Говядина",
        "protein_salmon": "Лосось",
        "protein_white_fish": "Белая рыба",
        "protein_shrimp": "Креветки",
        "protein_eggs": "Яйца",
        "protein_cottage_cheese": "Творог",
        "protein_tofu": "Тофу",
        "protein_tempeh": "Темпе",
        "protein_paneer": "Панир",
        "protein_tuna": "Тунец консервированный",
        "protein_edamame": "Эдамаме",
        "protein_halloumi": "Халлуми",
        "protein_scallops": "Гребешки",
        "protein_sardines": "Сардины",
        "protein_mussels": "Мидии",
        "protein_quail_egg": "Перепелиное яйцо",
        "veg_broccoli": "Брокколи",
        "veg_spinach": "Шпинат",
        "veg_tomatoes": "Помидоры",
        "veg_cucumber": "Огурец",
        "veg_bell_pepper": "Болгарский перец",
        "veg_lettuce": "Айсберг салат",
        "veg_arugula": "Руккола",
        "veg_celery": "Сельдерей",
        "veg_carrot": "Морковь",
        "veg_red_onion": "Красный лук",
        "veg_mushrooms": "Грибы",
        "veg_asparagus": "Спаржа",
        "veg_zucchini": "Кабачок",
        "veg_eggplant": "Баклажан",
        "veg_cauliflower": "Цветная капуста",
        "veg_cabbage": "Капуста",
        "veg_bok_choy": "Пак-чой",
        "veg_kale": "Кейл",
        "veg_kimchi": "Кимчи",
        "veg_olives": "Оливки",
        "veg_garlic": "Чеснок",
        "veg_green_beans": "Стручковая фасоль",
        "veg_peas": "Горошек",
        "veg_beetroot": "Свёкла",
        "veg_pumpkin": "Тыква",
        "veg_ginger": "Имбирь",
        "veg_okra": "Окра",
        "veg_nori": "Нори",
        "extra_olive_oil": "Оливковое масло",
        "extra_butter": "Сливочное масло",
        "extra_avocado": "Авокадо",
        "extra_banana": "Банан",
        "extra_blueberries": "Голубика",
        "extra_strawberries": "Клубника",
        "extra_apple": "Яблоко",
        "extra_peanut_butter": "Арахисовая паста",
        "extra_almonds": "Миндаль",
        "extra_walnuts": "Грецкие орехи",
        "extra_honey": "Мед",
        "extra_cheese": "Сыр",
        "extra_chia_seeds": "Семена чиа",
        "extra_sesame_oil": "Кунжутное масло",
        "extra_soy_sauce": "Соевый соус",
        "extra_tahini": "Тахини",
        "extra_coconut_milk": "Кокосовое молоко",
        "extra_feta": "Фета",
        "extra_mozzarella": "Моцарелла",
        "extra_hummus": "Хумус",
        "extra_mango": "Манго",
        "extra_dates": "Финики",
        "extra_pineapple": "Ананас",
        "extra_sesame_seeds": "Кунжут",
        "extra_cashews": "Кешью",
        "extra_pistachios": "Фисташки",
        "extra_maple_syrup": "Кленовый сироп",
        "extra_lime": "Лайм",
        "extra_miso": "Мисо",
        "extra_sour_cream": "Сметана",
        "extra_pomegranate": "Гранат",
        "extra_coconut_oil": "Кокосовое масло",
        "extra_orange": "Апельсин",
        "extra_peach": "Персик",
        "extra_nectarine": "Нектарин",
        "extra_watermelon": "Арбуз",
        "extra_mixed_nuts": "Смесь орехов",
        "extra_pork_ham": "Ветчина свиная",
        "extra_chicken_ham": "Ветчина куриная"
    ]
}

extension MealBuilderIngredient {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageName
        case category
        case defaultGrams
        case caloriesPer100g
        case proteinPer100g
        case carbsPer100g
        case fatsPer100g
        case fiberPer100g
        case visualSize
        case visualDensity
        case supportsStandalonePresentation
        case offsetX
        case offsetY
        case rotation
        case zIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        imageName = try container.decode(String.self, forKey: .imageName)
        category = try container.decode(MealIngredientCategory.self, forKey: .category)
        defaultGrams = try container.decode(Int.self, forKey: .defaultGrams)
        caloriesPer100g = try container.decode(Double.self, forKey: .caloriesPer100g)
        proteinPer100g = try container.decode(Double.self, forKey: .proteinPer100g)
        carbsPer100g = try container.decode(Double.self, forKey: .carbsPer100g)
        fatsPer100g = try container.decode(Double.self, forKey: .fatsPer100g)
        fiberPer100g = try container.decodeIfPresent(Double.self, forKey: .fiberPer100g) ?? 0
        visualSize = try container.decode(Int.self, forKey: .visualSize)
        visualDensity = try container.decode(CGFloat.self, forKey: .visualDensity)
        supportsStandalonePresentation = try container.decode(Bool.self, forKey: .supportsStandalonePresentation)
        offsetX = try container.decode(Int.self, forKey: .offsetX)
        offsetY = try container.decode(Int.self, forKey: .offsetY)
        rotation = try container.decode(Int.self, forKey: .rotation)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(imageName, forKey: .imageName)
        try container.encode(category, forKey: .category)
        try container.encode(defaultGrams, forKey: .defaultGrams)
        try container.encode(caloriesPer100g, forKey: .caloriesPer100g)
        try container.encode(proteinPer100g, forKey: .proteinPer100g)
        try container.encode(carbsPer100g, forKey: .carbsPer100g)
        try container.encode(fatsPer100g, forKey: .fatsPer100g)
        try container.encode(fiberPer100g, forKey: .fiberPer100g)
        try container.encode(visualSize, forKey: .visualSize)
        try container.encode(visualDensity, forKey: .visualDensity)
        try container.encode(supportsStandalonePresentation, forKey: .supportsStandalonePresentation)
        try container.encode(offsetX, forKey: .offsetX)
        try container.encode(offsetY, forKey: .offsetY)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(zIndex, forKey: .zIndex)
    }
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
    
    var fiberValue: Double {
        ingredient.fiberPer100g * Double(grams) / 100
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
    
    var fiber: Int {
        Int(fiberValue.rounded())
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
            fiberPer100g: 0.4,
            visualSize: 100,
            visualDensity: 1.15,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 1.8,
            visualSize: 80,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.7,
            visualSize: 95,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 1.8,
            visualSize: 95,
            visualDensity: 0.85,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 10.6,
            visualSize: 95,
            visualDensity: 1.20,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 7.0,
            visualSize: 95,
            visualDensity: 1.15,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 95,
            visualDensity: 0.75,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.7,
            visualSize: 90,
            visualDensity: 0.35,
            supportsStandalonePresentation: true,
            offsetX: -30,
            offsetY: 18,
            rotation: -6,
            zIndex: 1
        ),

        .init(
            id: "base_quinoa",
            title: "Quinoa",
            imageName: "ingredient-quinoa",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 120,
            proteinPer100g: 4.4,
            carbsPer100g: 21.3,
            fatsPer100g: 1.9,
            fiberPer100g: 2.8,
            visualSize: 95,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 20,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_couscous",
            title: "Couscous",
            imageName: "ingredient-couscous",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 112,
            proteinPer100g: 3.8,
            carbsPer100g: 23.2,
            fatsPer100g: 0.2,
            fiberPer100g: 1.4,
            visualSize: 95,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
            offsetX: -33,
            offsetY: 18,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_sweet_potato",
            title: "Sweet Potato",
            imageName: "ingredient-sweet-potato",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 90,
            proteinPer100g: 2.0,
            carbsPer100g: 20.7,
            fatsPer100g: 0.2,
            fiberPer100g: 3.3,
            visualSize: 95,
            visualDensity: 0.85,
            supportsStandalonePresentation: true,
            offsetX: -32,
            offsetY: 16,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_lentils",
            title: "Lentils",
            imageName: "ingredient-lentils",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 116,
            proteinPer100g: 9.0,
            carbsPer100g: 20.1,
            fatsPer100g: 0.4,
            fiberPer100g: 7.9,
            visualSize: 95,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 20,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_chickpeas",
            title: "Chickpeas",
            imageName: "ingredient-chickpeas",
            category: .base,
            defaultGrams: 140,
            caloriesPer100g: 164,
            proteinPer100g: 8.9,
            carbsPer100g: 27.4,
            fatsPer100g: 2.6,
            fiberPer100g: 7.6,
            visualSize: 95,
            visualDensity: 1.05,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 18,
            rotation: -6,
            zIndex: 1
        ),

        .init(
            id: "base_black_beans",
            title: "Black Beans",
            imageName: "ingredient-black-beans",
            category: .base,
            defaultGrams: 140,
            caloriesPer100g: 132,
            proteinPer100g: 8.9,
            carbsPer100g: 23.7,
            fatsPer100g: 0.5,
            fiberPer100g: 8.7,
            visualSize: 95,
            visualDensity: 1.05,
            supportsStandalonePresentation: true,
            offsetX: -33,
            offsetY: 18,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_soba_noodles",
            title: "Soba Noodles",
            imageName: "ingredient-soba-noodles",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 99,
            proteinPer100g: 5.1,
            carbsPer100g: 21.4,
            fatsPer100g: 0.1,
            fiberPer100g: 2.7,
            visualSize: 90,
            visualDensity: 1.05,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 16,
            rotation: -7,
            zIndex: 1
        ),

        .init(
            id: "base_corn_tortilla",
            title: "Tortilla",
            imageName: "ingredient-corn-tortilla",
            category: .base,
            defaultGrams: 50,
            caloriesPer100g: 218,
            proteinPer100g: 5.7,
            carbsPer100g: 44.6,
            fatsPer100g: 2.9,
            fiberPer100g: 6.3,
            visualSize: 90,
            visualDensity: 0.40,
            supportsStandalonePresentation: true,
            offsetX: -30,
            offsetY: 16,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_pita",
            title: "Pita",
            imageName: "ingredient-pita",
            category: .base,
            defaultGrams: 60,
            caloriesPer100g: 275,
            proteinPer100g: 9.1,
            carbsPer100g: 55.7,
            fatsPer100g: 1.2,
            fiberPer100g: 2.2,
            visualSize: 90,
            visualDensity: 0.40,
            supportsStandalonePresentation: true,
            offsetX: -30,
            offsetY: 18,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_brown_rice",
            title: "Brown Rice",
            imageName: "ingredient-brown-rice",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 123,
            proteinPer100g: 2.7,
            carbsPer100g: 25.6,
            fatsPer100g: 1.0,
            fiberPer100g: 1.6,
            visualSize: 100,
            visualDensity: 1.15,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 20,
            rotation: -6,
            zIndex: 1
        ),

        .init(
            id: "base_bulgur",
            title: "Bulgur",
            imageName: "ingredient-bulgur",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 83,
            proteinPer100g: 3.1,
            carbsPer100g: 18.6,
            fatsPer100g: 0.2,
            fiberPer100g: 4.5,
            visualSize: 95,
            visualDensity: 1.10,
            supportsStandalonePresentation: true,
            offsetX: -34,
            offsetY: 18,
            rotation: -4,
            zIndex: 1
        ),

        .init(
            id: "base_plantain",
            title: "Plantain",
            imageName: "ingredient-plantain",
            category: .base,
            defaultGrams: 150,
            caloriesPer100g: 122,
            proteinPer100g: 1.3,
            carbsPer100g: 31.9,
            fatsPer100g: 0.4,
            fiberPer100g: 2.3,
            visualSize: 90,
            visualDensity: 0.70,
            supportsStandalonePresentation: true,
            offsetX: -30,
            offsetY: 16,
            rotation: -5,
            zIndex: 1
        ),

        .init(
            id: "base_corn",
            title: "Canned Corn",
            imageName: "ingredient-corn",
            category: .base,
            defaultGrams: 120,
            caloriesPer100g: 96,
            proteinPer100g: 3.4,
            carbsPer100g: 21.0,
            fatsPer100g: 1.5,
            fiberPer100g: 2.4,
            visualSize: 90,
            visualDensity: 0.95,
            supportsStandalonePresentation: true,
            offsetX: -32,
            offsetY: 16,
            rotation: -4,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 7,
            rotation: 7,
            zIndex: 3
        ),
        
        .init(
            id: "protein_pork",
            title: "Pork",
            imageName: "ingredient-pork",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 242,
            proteinPer100g: 27,
            carbsPer100g: 0,
            fatsPer100g: 14,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_lamb",
            title: "Lamb",
            imageName: "ingredient-lamb",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 294,
            proteinPer100g: 25,
            carbsPer100g: 0,
            fatsPer100g: 21,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.52,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_veal",
            title: "Veal",
            imageName: "ingredient-veal",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 172,
            proteinPer100g: 24,
            carbsPer100g: 0,
            fatsPer100g: 8,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.48,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_duck",
            title: "Duck",
            imageName: "ingredient-duck",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 337,
            proteinPer100g: 19,
            carbsPer100g: 0,
            fatsPer100g: 28,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.35,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 34,
            offsetY: 10,
            rotation: 7,
            zIndex: 3
        ),

        .init(
            id: "protein_quail_egg",
            title: "Quail Egg",
            imageName: "ingredient-quail-egg",
            category: .protein,
            defaultGrams: 48,
            caloriesPer100g: 158,
            proteinPer100g: 13.0,
            carbsPer100g: 0.4,
            fatsPer100g: 11.1,
            fiberPer100g: 0,
            visualSize: 55,
            visualDensity: 0.18,
            supportsStandalonePresentation: true,
            offsetX: 34,
            offsetY: 10,
            rotation: 6,
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
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.65,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 10,
            rotation: 5,
            zIndex: 3
        ),

        .init(
            id: "protein_tofu",
            title: "Tofu",
            imageName: "ingredient-tofu",
            category: .protein,
            defaultGrams: 150,
            caloriesPer100g: 76,
            proteinPer100g: 8.1,
            carbsPer100g: 1.9,
            fatsPer100g: 4.8,
            fiberPer100g: 0.3,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_tempeh",
            title: "Tempeh",
            imageName: "ingredient-tempeh",
            category: .protein,
            defaultGrams: 120,
            caloriesPer100g: 193,
            proteinPer100g: 20.3,
            carbsPer100g: 7.6,
            fatsPer100g: 10.8,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 7,
            zIndex: 3
        ),

        .init(
            id: "protein_paneer",
            title: "Paneer",
            imageName: "ingredient-paneer",
            category: .protein,
            defaultGrams: 100,
            caloriesPer100g: 265,
            proteinPer100g: 18.3,
            carbsPer100g: 1.2,
            fatsPer100g: 20.8,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 7,
            rotation: 5,
            zIndex: 3
        ),

        .init(
            id: "protein_tuna",
            title: "Canned Tuna",
            imageName: "ingredient-tuna",
            category: .protein,
            defaultGrams: 120,
            caloriesPer100g: 132,
            proteinPer100g: 28.2,
            carbsPer100g: 0,
            fatsPer100g: 1.3,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 7,
            rotation: 8,
            zIndex: 3
        ),

        .init(
            id: "protein_edamame",
            title: "Edamame",
            imageName: "ingredient-edamame",
            category: .protein,
            defaultGrams: 100,
            caloriesPer100g: 121,
            proteinPer100g: 11.9,
            carbsPer100g: 8.9,
            fatsPer100g: 5.2,
            fiberPer100g: 5.2,
            visualSize: 75,
            visualDensity: 0.70,
            supportsStandalonePresentation: true,
            offsetX: 34,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_halloumi",
            title: "Halloumi",
            imageName: "ingredient-halloumi",
            category: .protein,
            defaultGrams: 80,
            caloriesPer100g: 321,
            proteinPer100g: 21.0,
            carbsPer100g: 2.0,
            fatsPer100g: 25.0,
            fiberPer100g: 0,
            visualSize: 75,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 8,
            rotation: 7,
            zIndex: 3
        ),

        .init(
            id: "protein_scallops",
            title: "Scallops",
            imageName: "ingredient-scallops",
            category: .protein,
            defaultGrams: 120,
            caloriesPer100g: 111,
            proteinPer100g: 20.5,
            carbsPer100g: 5.4,
            fatsPer100g: 0.8,
            fiberPer100g: 0,
            visualSize: 75,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
            rotation: 6,
            zIndex: 3
        ),

        .init(
            id: "protein_sardines",
            title: "Sardines",
            imageName: "ingredient-sardines",
            category: .protein,
            defaultGrams: 100,
            caloriesPer100g: 208,
            proteinPer100g: 24.6,
            carbsPer100g: 0,
            fatsPer100g: 11.5,
            fiberPer100g: 0,
            visualSize: 80,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 36,
            offsetY: 7,
            rotation: 8,
            zIndex: 3
        ),

        .init(
            id: "protein_mussels",
            title: "Mussels",
            imageName: "ingredient-mussels",
            category: .protein,
            defaultGrams: 120,
            caloriesPer100g: 86,
            proteinPer100g: 11.9,
            carbsPer100g: 3.7,
            fatsPer100g: 2.2,
            fiberPer100g: 0,
            visualSize: 75,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 35,
            offsetY: 8,
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
            fiberPer100g: 3.3,
            visualSize: 70,
            visualDensity: 0.95,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.2,
            visualSize: 70,
            visualDensity: 1.35,
            supportsStandalonePresentation: true,
            offsetX: 28,
            offsetY: -44,
            rotation: -4,
            zIndex: 2
        ),

        .init(
            id: "veg_arugula",
            title: "Arugula",
            imageName: "ingredient-arugula",
            category: .vegetables,
            defaultGrams: 50,
            caloriesPer100g: 25,
            proteinPer100g: 2.6,
            carbsPer100g: 3.7,
            fatsPer100g: 0.7,
            fiberPer100g: 1.6,
            visualSize: 68,
            visualDensity: 1.40,
            supportsStandalonePresentation: true,
            offsetX: 26,
            offsetY: -46,
            rotation: -3,
            zIndex: 2
        ),

        .init(
            id: "veg_celery",
            title: "Celery",
            imageName: "ingredient-celery",
            category: .vegetables,
            defaultGrams: 80,
            caloriesPer100g: 16,
            proteinPer100g: 0.7,
            carbsPer100g: 3.0,
            fatsPer100g: 0.2,
            fiberPer100g: 1.6,
            visualSize: 72,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 22,
            offsetY: -48,
            rotation: 8,
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
            fiberPer100g: 1.2,
            visualSize: 82,
            visualDensity: 0.70,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 0.5,
            visualSize: 70,
            visualDensity: 0.75,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.1,
            visualSize: 70,
            visualDensity: 0.75,
            supportsStandalonePresentation: true,
            offsetX: 18,
            offsetY: -54,
            rotation: 5,
            zIndex: 2
        ),

        .init(
            id: "veg_lettuce",
            title: "Iceberg Lettuce",
            imageName: "ingredient-lettuce",
            category: .vegetables,
            defaultGrams: 70,
            caloriesPer100g: 15,
            proteinPer100g: 1.4,
            carbsPer100g: 2.9,
            fatsPer100g: 0.2,
            fiberPer100g: 1.3,
            visualSize: 70,
            visualDensity: 1.45,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.8,
            visualSize: 70,
            visualDensity: 0.65,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 1.7,
            visualSize: 75,
            visualDensity: 0.45,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 1.0,
            visualSize: 70,
            visualDensity: 0.75,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.1,
            visualSize: 70,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 1.0,
            visualSize: 70,
            visualDensity: 0.75,
            supportsStandalonePresentation: true,
            offsetX: 15,
            offsetY: -52,
            rotation: -5,
            zIndex: 2
        ),

        .init(
            id: "veg_eggplant",
            title: "Eggplant",
            imageName: "ingredient-eggplant",
            category: .vegetables,
            defaultGrams: 120,
            caloriesPer100g: 25,
            proteinPer100g: 1.0,
            carbsPer100g: 5.9,
            fatsPer100g: 0.2,
            fiberPer100g: 3.0,
            visualSize: 70,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
            offsetX: 22,
            offsetY: -50,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_cauliflower",
            title: "Cauliflower",
            imageName: "ingredient-cauliflower",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 25,
            proteinPer100g: 1.9,
            carbsPer100g: 5.0,
            fatsPer100g: 0.3,
            fiberPer100g: 2.0,
            visualSize: 70,
            visualDensity: 0.90,
            supportsStandalonePresentation: true,
            offsetX: 24,
            offsetY: -48,
            rotation: 3,
            zIndex: 2
        ),

        .init(
            id: "veg_cabbage",
            title: "Cabbage",
            imageName: "ingredient-cabbage",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 25,
            proteinPer100g: 1.3,
            carbsPer100g: 5.8,
            fatsPer100g: 0.1,
            fiberPer100g: 2.5,
            visualSize: 70,
            visualDensity: 0.85,
            supportsStandalonePresentation: true,
            offsetX: 20,
            offsetY: -50,
            rotation: 5,
            zIndex: 2
        ),

        .init(
            id: "veg_bok_choy",
            title: "Bok Choy",
            imageName: "ingredient-bok-choy",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 13,
            proteinPer100g: 1.5,
            carbsPer100g: 2.2,
            fatsPer100g: 0.2,
            fiberPer100g: 1.0,
            visualSize: 70,
            visualDensity: 0.85,
            supportsStandalonePresentation: true,
            offsetX: 22,
            offsetY: -52,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_kale",
            title: "Kale",
            imageName: "ingredient-kale",
            category: .vegetables,
            defaultGrams: 80,
            caloriesPer100g: 49,
            proteinPer100g: 4.3,
            carbsPer100g: 8.8,
            fatsPer100g: 0.9,
            fiberPer100g: 3.6,
            visualSize: 70,
            visualDensity: 0.90,
            supportsStandalonePresentation: true,
            offsetX: 24,
            offsetY: -55,
            rotation: 6,
            zIndex: 2
        ),

        .init(
            id: "veg_kimchi",
            title: "Kimchi",
            imageName: "ingredient-kimchi",
            category: .vegetables,
            defaultGrams: 80,
            caloriesPer100g: 15,
            proteinPer100g: 1.1,
            carbsPer100g: 2.4,
            fatsPer100g: 0.5,
            fiberPer100g: 1.6,
            visualSize: 68,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
            offsetX: 25,
            offsetY: -48,
            rotation: 5,
            zIndex: 2
        ),

        .init(
            id: "veg_olives",
            title: "Olives",
            imageName: "ingredient-olives",
            category: .vegetables,
            defaultGrams: 30,
            caloriesPer100g: 115,
            proteinPer100g: 0.8,
            carbsPer100g: 6.3,
            fatsPer100g: 10.7,
            fiberPer100g: 3.2,
            visualSize: 60,
            visualDensity: 0.40,
            supportsStandalonePresentation: true,
            offsetX: 28,
            offsetY: -45,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_garlic",
            title: "Garlic",
            imageName: "ingredient-garlic",
            category: .vegetables,
            defaultGrams: 10,
            caloriesPer100g: 149,
            proteinPer100g: 6.4,
            carbsPer100g: 33.1,
            fatsPer100g: 0.5,
            fiberPer100g: 2.1,
            visualSize: 55,
            visualDensity: 0.25,
            supportsStandalonePresentation: false,
            offsetX: 40,
            offsetY: -40,
            rotation: 8,
            zIndex: 2
        ),

        .init(
            id: "veg_green_beans",
            title: "Green Beans",
            imageName: "ingredient-green-beans",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 31,
            proteinPer100g: 1.8,
            carbsPer100g: 7.0,
            fatsPer100g: 0.2,
            fiberPer100g: 2.7,
            visualSize: 70,
            visualDensity: 0.85,
            supportsStandalonePresentation: true,
            offsetX: 20,
            offsetY: -52,
            rotation: 3,
            zIndex: 2
        ),

        .init(
            id: "veg_peas",
            title: "Peas",
            imageName: "ingredient-peas",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 81,
            proteinPer100g: 5.4,
            carbsPer100g: 14.5,
            fatsPer100g: 0.4,
            fiberPer100g: 5.1,
            visualSize: 68,
            visualDensity: 0.95,
            supportsStandalonePresentation: true,
            offsetX: 24,
            offsetY: -48,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_beetroot",
            title: "Beetroot",
            imageName: "ingredient-beetroot",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 43,
            proteinPer100g: 1.6,
            carbsPer100g: 9.6,
            fatsPer100g: 0.2,
            fiberPer100g: 2.8,
            visualSize: 70,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
            offsetX: 22,
            offsetY: -50,
            rotation: 5,
            zIndex: 2
        ),

        .init(
            id: "veg_pumpkin",
            title: "Pumpkin",
            imageName: "ingredient-pumpkin",
            category: .vegetables,
            defaultGrams: 120,
            caloriesPer100g: 26,
            proteinPer100g: 1.0,
            carbsPer100g: 6.5,
            fatsPer100g: 0.1,
            fiberPer100g: 0.5,
            visualSize: 70,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
            offsetX: 20,
            offsetY: -48,
            rotation: -4,
            zIndex: 2
        ),

        .init(
            id: "veg_ginger",
            title: "Ginger",
            imageName: "ingredient-ginger",
            category: .vegetables,
            defaultGrams: 15,
            caloriesPer100g: 80,
            proteinPer100g: 1.8,
            carbsPer100g: 17.8,
            fatsPer100g: 0.8,
            fiberPer100g: 2.0,
            visualSize: 55,
            visualDensity: 0.25,
            supportsStandalonePresentation: false,
            offsetX: 38,
            offsetY: -42,
            rotation: 6,
            zIndex: 2
        ),

        .init(
            id: "veg_okra",
            title: "Okra",
            imageName: "ingredient-okra",
            category: .vegetables,
            defaultGrams: 100,
            caloriesPer100g: 33,
            proteinPer100g: 1.9,
            carbsPer100g: 7.5,
            fatsPer100g: 0.2,
            fiberPer100g: 3.2,
            visualSize: 68,
            visualDensity: 0.80,
            supportsStandalonePresentation: true,
            offsetX: 22,
            offsetY: -50,
            rotation: 4,
            zIndex: 2
        ),

        .init(
            id: "veg_nori",
            title: "Nori",
            imageName: "ingredient-nori",
            category: .vegetables,
            defaultGrams: 5,
            caloriesPer100g: 280,
            proteinPer100g: 40.0,
            carbsPer100g: 40.0,
            fatsPer100g: 0.5,
            fiberPer100g: 7.0,
            visualSize: 55,
            visualDensity: 0.12,
            supportsStandalonePresentation: false,
            offsetX: 42,
            offsetY: -40,
            rotation: 8,
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
            fiberPer100g: 0,
            visualSize: 55,
            visualDensity: 0.08,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 0,
            visualSize: 52,
            visualDensity: 0.12,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 6.7,
            visualSize: 60,
            visualDensity: 0.40,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.6,
            visualSize: 60,
            visualDensity: 0.22,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.4,
            visualSize: 60,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.0,
            visualSize: 60,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 2.4,
            visualSize: 68,
            visualDensity: 0.18,
            supportsStandalonePresentation: true,
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
            fiberPer100g: 6.0,
            visualSize: 60,
            visualDensity: 0.12,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 12.5,
            visualSize: 60,
            visualDensity: 0.20,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 6.7,
            visualSize: 60,
            visualDensity: 0.20,
            supportsStandalonePresentation: false,
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
            fiberPer100g: 0.2,
            visualSize: 60,
            visualDensity: 0.10,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),
        
        .init(
            id: "extra_cheese",
            title: "Cheese",
            imageName: "ingredient-cheese",
            category: .extras,
            defaultGrams: 30,
            caloriesPer100g: 356,
            proteinPer100g: 25.0,
            carbsPer100g: 2.0,
            fatsPer100g: 27.0,
            fiberPer100g: 0,
            visualSize: 58,
            visualDensity: 0.18,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: -4,
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
            fiberPer100g: 34.4,
            visualSize: 60,
            visualDensity: 0.10,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_sesame_oil",
            title: "Sesame Oil",
            imageName: "ingredient-sesame-oil",
            category: .extras,
            defaultGrams: 10,
            caloriesPer100g: 884,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatsPer100g: 100,
            fiberPer100g: 0,
            visualSize: 55,
            visualDensity: 0.08,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_soy_sauce",
            title: "Soy Sauce",
            imageName: "ingredient-soy-sauce",
            category: .extras,
            defaultGrams: 15,
            caloriesPer100g: 53,
            proteinPer100g: 8.1,
            carbsPer100g: 4.9,
            fatsPer100g: 0.1,
            fiberPer100g: 0.8,
            visualSize: 55,
            visualDensity: 0.08,
            supportsStandalonePresentation: false,
            offsetX: 52,
            offsetY: -16,
            rotation: 2,
            zIndex: 5
        ),

        .init(
            id: "extra_tahini",
            title: "Tahini",
            imageName: "ingredient-tahini",
            category: .extras,
            defaultGrams: 20,
            caloriesPer100g: 595,
            proteinPer100g: 17.0,
            carbsPer100g: 21.2,
            fatsPer100g: 53.8,
            fiberPer100g: 9.3,
            visualSize: 58,
            visualDensity: 0.15,
            supportsStandalonePresentation: false,
            offsetX: 50,
            offsetY: -18,
            rotation: -2,
            zIndex: 5
        ),

        .init(
            id: "extra_coconut_milk",
            title: "Coconut Milk",
            imageName: "ingredient-coconut-milk",
            category: .extras,
            defaultGrams: 60,
            caloriesPer100g: 230,
            proteinPer100g: 2.3,
            carbsPer100g: 5.5,
            fatsPer100g: 23.8,
            fiberPer100g: 2.2,
            visualSize: 60,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -16,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_feta",
            title: "Feta",
            imageName: "ingredient-feta",
            category: .extras,
            defaultGrams: 40,
            caloriesPer100g: 264,
            proteinPer100g: 14.2,
            carbsPer100g: 4.1,
            fatsPer100g: 21.3,
            fiberPer100g: 0,
            visualSize: 58,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: -4,
            zIndex: 5
        ),

        .init(
            id: "extra_mozzarella",
            title: "Mozzarella",
            imageName: "ingredient-mozzarella",
            category: .extras,
            defaultGrams: 50,
            caloriesPer100g: 280,
            proteinPer100g: 22.2,
            carbsPer100g: 2.2,
            fatsPer100g: 22.4,
            fiberPer100g: 0,
            visualSize: 58,
            visualDensity: 0.22,
            supportsStandalonePresentation: true,
            offsetX: 46,
            offsetY: -16,
            rotation: 3,
            zIndex: 5
        ),

        .init(
            id: "extra_hummus",
            title: "Hummus",
            imageName: "ingredient-hummus",
            category: .extras,
            defaultGrams: 60,
            caloriesPer100g: 166,
            proteinPer100g: 7.9,
            carbsPer100g: 14.3,
            fatsPer100g: 9.6,
            fiberPer100g: 6.0,
            visualSize: 62,
            visualDensity: 0.35,
            supportsStandalonePresentation: true,
            offsetX: 44,
            offsetY: -16,
            rotation: -3,
            zIndex: 5
        ),

        .init(
            id: "extra_mango",
            title: "Mango",
            imageName: "ingredient-mango",
            category: .extras,
            defaultGrams: 120,
            caloriesPer100g: 60,
            proteinPer100g: 0.8,
            carbsPer100g: 15.0,
            fatsPer100g: 0.4,
            fiberPer100g: 1.6,
            visualSize: 65,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 40,
            offsetY: -20,
            rotation: 4,
            zIndex: 5
        ),

        .init(
            id: "extra_dates",
            title: "Dates",
            imageName: "ingredient-dates",
            category: .extras,
            defaultGrams: 40,
            caloriesPer100g: 282,
            proteinPer100g: 2.5,
            carbsPer100g: 75.0,
            fatsPer100g: 0.4,
            fiberPer100g: 8.0,
            visualSize: 58,
            visualDensity: 0.25,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: -2,
            zIndex: 5
        ),

        .init(
            id: "extra_pineapple",
            title: "Pineapple",
            imageName: "ingredient-pineapple",
            category: .extras,
            defaultGrams: 120,
            caloriesPer100g: 50,
            proteinPer100g: 0.5,
            carbsPer100g: 13.1,
            fatsPer100g: 0.1,
            fiberPer100g: 1.4,
            visualSize: 65,
            visualDensity: 0.50,
            supportsStandalonePresentation: true,
            offsetX: 40,
            offsetY: -20,
            rotation: 5,
            zIndex: 5
        ),

        .init(
            id: "extra_sesame_seeds",
            title: "Sesame Seeds",
            imageName: "ingredient-sesame-seeds",
            category: .extras,
            defaultGrams: 15,
            caloriesPer100g: 573,
            proteinPer100g: 17.7,
            carbsPer100g: 23.5,
            fatsPer100g: 49.7,
            fiberPer100g: 11.8,
            visualSize: 55,
            visualDensity: 0.10,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_cashews",
            title: "Cashews",
            imageName: "ingredient-cashews",
            category: .extras,
            defaultGrams: 25,
            caloriesPer100g: 553,
            proteinPer100g: 18.2,
            carbsPer100g: 30.2,
            fatsPer100g: 43.9,
            fiberPer100g: 3.3,
            visualSize: 58,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: -3,
            zIndex: 5
        ),

        .init(
            id: "extra_pistachios",
            title: "Pistachios",
            imageName: "ingredient-pistachios",
            category: .extras,
            defaultGrams: 25,
            caloriesPer100g: 560,
            proteinPer100g: 20.2,
            carbsPer100g: 27.2,
            fatsPer100g: 45.3,
            fiberPer100g: 10.6,
            visualSize: 58,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -16,
            rotation: 2,
            zIndex: 5
        ),

        .init(
            id: "extra_maple_syrup",
            title: "Maple Syrup",
            imageName: "ingredient-maple-syrup",
            category: .extras,
            defaultGrams: 20,
            caloriesPer100g: 260,
            proteinPer100g: 0,
            carbsPer100g: 67.0,
            fatsPer100g: 0.1,
            fiberPer100g: 0,
            visualSize: 55,
            visualDensity: 0.08,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_lime",
            title: "Lime",
            imageName: "ingredient-lime",
            category: .extras,
            defaultGrams: 40,
            caloriesPer100g: 30,
            proteinPer100g: 0.7,
            carbsPer100g: 10.5,
            fatsPer100g: 0.2,
            fiberPer100g: 2.8,
            visualSize: 58,
            visualDensity: 0.30,
            supportsStandalonePresentation: true,
            offsetX: 46,
            offsetY: -20,
            rotation: 4,
            zIndex: 5
        ),

        .init(
            id: "extra_miso",
            title: "Miso",
            imageName: "ingredient-miso",
            category: .extras,
            defaultGrams: 20,
            caloriesPer100g: 198,
            proteinPer100g: 12.8,
            carbsPer100g: 26.5,
            fatsPer100g: 6.0,
            fiberPer100g: 5.4,
            visualSize: 55,
            visualDensity: 0.15,
            supportsStandalonePresentation: false,
            offsetX: 52,
            offsetY: -16,
            rotation: -2,
            zIndex: 5
        ),

        .init(
            id: "extra_sour_cream",
            title: "Sour Cream",
            imageName: "ingredient-sour-cream",
            category: .extras,
            defaultGrams: 30,
            caloriesPer100g: 198,
            proteinPer100g: 2.4,
            carbsPer100g: 4.6,
            fatsPer100g: 19.4,
            fiberPer100g: 0,
            visualSize: 58,
            visualDensity: 0.18,
            supportsStandalonePresentation: false,
            offsetX: 50,
            offsetY: -16,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_pomegranate",
            title: "Pomegranate",
            imageName: "ingredient-pomegranate",
            category: .extras,
            defaultGrams: 80,
            caloriesPer100g: 83,
            proteinPer100g: 1.7,
            carbsPer100g: 18.7,
            fatsPer100g: 1.2,
            fiberPer100g: 4.0,
            visualSize: 60,
            visualDensity: 0.40,
            supportsStandalonePresentation: true,
            offsetX: 44,
            offsetY: -20,
            rotation: 3,
            zIndex: 5
        ),

        .init(
            id: "extra_coconut_oil",
            title: "Coconut Oil",
            imageName: "ingredient-coconut-oil",
            category: .extras,
            defaultGrams: 10,
            caloriesPer100g: 862,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatsPer100g: 100,
            fiberPer100g: 0,
            visualSize: 55,
            visualDensity: 0.08,
            supportsStandalonePresentation: false,
            offsetX: 54,
            offsetY: -18,
            rotation: 0,
            zIndex: 5
        ),

        .init(
            id: "extra_orange",
            title: "Orange",
            imageName: "ingredient-orange",
            category: .extras,
            defaultGrams: 130,
            caloriesPer100g: 47,
            proteinPer100g: 0.9,
            carbsPer100g: 11.8,
            fatsPer100g: 0.1,
            fiberPer100g: 2.4,
            visualSize: 65,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 40,
            offsetY: -20,
            rotation: 4,
            zIndex: 5
        ),

        .init(
            id: "extra_peach",
            title: "Peach",
            imageName: "ingredient-peach",
            category: .extras,
            defaultGrams: 130,
            caloriesPer100g: 39,
            proteinPer100g: 0.9,
            carbsPer100g: 9.5,
            fatsPer100g: 0.3,
            fiberPer100g: 1.5,
            visualSize: 65,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 40,
            offsetY: -18,
            rotation: -3,
            zIndex: 5
        ),

        .init(
            id: "extra_nectarine",
            title: "Nectarine",
            imageName: "ingredient-nectarine",
            category: .extras,
            defaultGrams: 130,
            caloriesPer100g: 44,
            proteinPer100g: 1.1,
            carbsPer100g: 10.6,
            fatsPer100g: 0.3,
            fiberPer100g: 1.7,
            visualSize: 65,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 42,
            offsetY: -20,
            rotation: 2,
            zIndex: 5
        ),

        .init(
            id: "extra_watermelon",
            title: "Watermelon",
            imageName: "ingredient-watermelon",
            category: .extras,
            defaultGrams: 150,
            caloriesPer100g: 30,
            proteinPer100g: 0.6,
            carbsPer100g: 7.6,
            fatsPer100g: 0.2,
            fiberPer100g: 0.4,
            visualSize: 68,
            visualDensity: 0.55,
            supportsStandalonePresentation: true,
            offsetX: 38,
            offsetY: -18,
            rotation: 5,
            zIndex: 5
        ),

        .init(
            id: "extra_mixed_nuts",
            title: "Mixed Nuts",
            imageName: "ingredient-nuts",
            category: .extras,
            defaultGrams: 25,
            caloriesPer100g: 607,
            proteinPer100g: 20.0,
            carbsPer100g: 21.0,
            fatsPer100g: 54.0,
            fiberPer100g: 7.0,
            visualSize: 58,
            visualDensity: 0.20,
            supportsStandalonePresentation: true,
            offsetX: 48,
            offsetY: -18,
            rotation: -4,
            zIndex: 5
        ),

        .init(
            id: "extra_pork_ham",
            title: "Pork Ham",
            imageName: "ingredient-pork-ham",
            category: .extras,
            defaultGrams: 40,
            caloriesPer100g: 145,
            proteinPer100g: 21.0,
            carbsPer100g: 1.5,
            fatsPer100g: 5.5,
            fiberPer100g: 0,
            visualSize: 56,
            visualDensity: 0.22,
            supportsStandalonePresentation: true,
            offsetX: 42,
            offsetY: -18,
            rotation: 6,
            zIndex: 5
        ),

        .init(
            id: "extra_chicken_ham",
            title: "Chicken Ham",
            imageName: "ingredient-chicken-ham",
            category: .extras,
            defaultGrams: 40,
            caloriesPer100g: 110,
            proteinPer100g: 20.0,
            carbsPer100g: 1.0,
            fatsPer100g: 2.5,
            fiberPer100g: 0,
            visualSize: 56,
            visualDensity: 0.22,
            supportsStandalonePresentation: true,
            offsetX: 44,
            offsetY: -16,
            rotation: -5,
            zIndex: 5
        )
    ]
}
