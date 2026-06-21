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
        case defaultServingAmount
        case servingUnit
        case gramsPerServing
        case mlPerServing
    }
}
