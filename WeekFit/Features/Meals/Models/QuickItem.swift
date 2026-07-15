import Foundation
import SwiftUI

struct QuickItem: Codable, Identifiable, Equatable {

    let id: String
    let title: String
    let subtitle: String

    let category: Category

    let imageName: String
    let icon: String

    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int

    var defaultServingAmount: Double?
    var servingUnit: QuickLogServingUnit?
    var gramsPerServing: Double?
    var mlPerServing: Double?

    enum Category: String, Codable {
        case drink
        case snack
    }

    var caloriesPerServing: Int { calories }
    var proteinPerServing: Int { protein }
    var carbsPerServing: Int { carbs }
    var fatPerServing: Int { fats }
    var fiberPerServing: Int { fiber }

    var resolvedServingUnit: QuickLogServingUnit {
        if let servingUnit {
            return servingUnit
        }
        return category == .drink ? .milliliters : .portion
    }

    var defaultServingAmountValue: Double {
        if let defaultServingAmount, defaultServingAmount > 0 {
            return defaultServingAmount
        }
        if category == .drink {
            return mlPerServing ?? 250
        }
        return gramsPerServing ?? 100
    }

    init(
        id: String,
        title: String,
        subtitle: String,
        category: Category,
        imageName: String,
        icon: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int,
        fiber: Int = 0,
        defaultServingAmount: Double? = nil,
        servingUnit: QuickLogServingUnit? = nil,
        gramsPerServing: Double? = nil,
        mlPerServing: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.imageName = imageName
        self.icon = icon
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.defaultServingAmount = defaultServingAmount
        self.servingUnit = servingUnit
        self.gramsPerServing = gramsPerServing
        self.mlPerServing = mlPerServing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        category = try container.decode(Category.self, forKey: .category)
        imageName = try container.decode(String.self, forKey: .imageName)
        icon = try container.decode(String.self, forKey: .icon)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Int.self, forKey: .protein)
        carbs = try container.decode(Int.self, forKey: .carbs)
        fats = try container.decode(Int.self, forKey: .fats)
        fiber = try container.decodeIfPresent(Int.self, forKey: .fiber) ?? 0
        defaultServingAmount = try container.decodeIfPresent(Double.self, forKey: .defaultServingAmount)
        servingUnit = try container.decodeIfPresent(QuickLogServingUnit.self, forKey: .servingUnit)
        gramsPerServing = try container.decodeIfPresent(Double.self, forKey: .gramsPerServing)
        mlPerServing = try container.decodeIfPresent(Double.self, forKey: .mlPerServing)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case category
        case imageName
        case icon
        case calories
        case protein
        case carbs
        case fats
        case fiber
        case defaultServingAmount
        case servingUnit
        case gramsPerServing
        case mlPerServing
    }

    var localizedTitle: String {
        Self.localizedTitle(forStoredTitle: title)
    }

    var localizedSubtitle: String {
        Self.localizedSubtitle(for: self)
    }

    static func localizedTitle(forStoredTitle storedTitle: String) -> String {
        let trimmed = storedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return storedTitle }

        let isRussian = WeekFitCurrentLocale().identifier.hasPrefix("ru")
        let lowered = trimmed.lowercased()

        if isRussian {
            return russianTitlesByStoredTitle[lowered] ?? trimmed
        }

        // Titles previously persisted while Russian was active (e.g. "Вода").
        return englishTitlesByRussianTitle[lowered] ?? trimmed
    }

    static func localizedSubtitle(for item: QuickItem) -> String {
        let trimmed = item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return item.subtitle }

        guard WeekFitCurrentLocale().identifier.hasPrefix("ru") else {
            return trimmed
        }

        if let localized = russianSubtitlesByID[item.id] {
            return localized
        }

        return russianSubtitlesByStoredSubtitle[trimmed.lowercased()] ?? trimmed
    }

    private static let russianTitlesByStoredTitle: [String: String] = [
        "water": "Вода",
        "coffee": "Кофе",
        "iced coffee": "Холодный кофе",
        "kefir": "Кефир",
        "espresso": "Эспрессо",
        "tonic": "Тоник",
        "tea": "Чай",
        "milk": "Молоко",
        "orange juice": "Апельсиновый сок",
        "protein shake": "Протеиновый коктейль",
        "tomato juice": "Томатный сок",
        "banana": "Банан",
        "apple": "Яблоко",
        "orange": "Апельсин",
        "nectarine": "Нектарин",
        "peach": "Персик",
        "watermelon": "Арбуз",
        "strawberries": "Клубника",
        "blueberries": "Черника",
        "greek yogurt": "Греческий йогурт",
        "protein bar": "Протеиновый батончик",
        "mixed nuts": "Смесь орехов",
        "dark chocolate": "Тёмный шоколад",
        "rice cakes": "Рисовые хлебцы",
        "ice cream": "Мороженое",
        "cookies": "Печенье",
        "croissant": "Круассан",
        "muffin": "Маффин",
        "toast": "Тост"
    ]

    private static let englishTitlesByRussianTitle: [String: String] = {
        Dictionary(uniqueKeysWithValues: russianTitlesByStoredTitle.map { ($0.value.lowercased(), $0.key.capitalizedSentence) })
    }()

    private static let russianSubtitlesByID: [String: String] = [
        "drink_water": "Гидратация"
    ]

    private static let russianSubtitlesByStoredSubtitle: [String: String] = [
        "hydration support": "Гидратация",
        "quick caffeine boost": "Быстрый кофеин",
        "cold caffeine boost": "Холодный кофеин",
        "probiotic dairy drink": "Пробиотический молочный напиток",
        "strong coffee shot": "Крепкий кофе",
        "light sparkling refreshment": "Лёгкий газированный напиток",
        "light warm drink": "Лёгкий тёплый напиток",
        "simple protein drink": "Простой белковый напиток",
        "fast carbs and vitamin c": "Быстрые углеводы и витамин C",
        "fast recovery support": "Быстрое восстановление",
        "electrolyte-rich hydration": "Гидратация с электролитами",
        "quick energy": "Быстрая энергия",
        "light fruit snack": "Лёгкий фруктовый перекус",
        "fresh light snack": "Лёгкий свежий перекус",
        "high-protein snack": "Белковый перекус",
        "portable recovery snack": "Перекус для восстановления",
        "healthy fats and satiety": "Полезные жиры и сытость",
        "small sweet snack": "Небольшой сладкий перекус",
        "light carb snack": "Лёгкий углеводный перекус",
        "juicy summer fruit": "Сочный летний фрукт",
        "sweet seasonal fruit": "Сладкий сезонный фрукт",
        "refreshing summer fruit": "Освежающий летний фрукт",
        "fresh berry snack": "Свежие ягоды",
        "antioxidant-rich berries": "Ягоды с антиоксидантами",
        "classic frozen treat": "Классическое мороженое",
        "sweet baked snack": "Сладкая выпечка",
        "buttery bakery snack": "Масляная выпечка",
        "soft sweet treat": "Мягкий сладкий перекус"
    ]
}

private extension String {
    /// Title-case for reverse-mapped catalog names ("water" → "Water", "iced coffee" → "Iced Coffee").
    var capitalizedSentence: String {
        split(separator: " ")
            .map { part in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}
