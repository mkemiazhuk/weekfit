import Foundation

enum QuickNutritionLogTab: String, CaseIterable, Identifiable {
    case meals
    case snacks

    var id: String { rawValue }
}
