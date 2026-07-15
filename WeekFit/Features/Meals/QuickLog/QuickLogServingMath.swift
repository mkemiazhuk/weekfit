import Foundation

enum QuickLogItemKind: Equatable {
    case meal
    case snack
    case drink
}

enum QuickLogServingUnit: String, Codable, CaseIterable {
    case portion
    case grams
    case milliliters
}

enum QuickLogQuantityMode: String, CaseIterable, Identifiable {
    case portions
    case grams
    case milliliters

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .portions:
            return "quickLog.quantity.mode.portions"
        case .grams:
            return "quickLog.quantity.mode.grams"
        case .milliliters:
            return "quickLog.quantity.mode.milliliters"
        }
    }

    static func availableModes(for kind: QuickLogItemKind) -> [QuickLogQuantityMode] {
        switch kind {
        case .meal, .snack:
            return [.portions, .grams]
        case .drink:
            return [.portions, .milliliters]
        }
    }
}

struct QuickLogNutritionValues: Equatable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let portions: Double
    let grams: Double?
    let milliliters: Double?
}

struct QuickLogNutritionProfile: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    let icon: String
    let kind: QuickLogItemKind

    let caloriesPerServing: Int
    let proteinPerServing: Int
    let carbsPerServing: Int
    let fatPerServing: Int
    let fiberPerServing: Int

    let defaultServingAmount: Double
    let servingUnit: QuickLogServingUnit
    let gramsPerServing: Double?
    let mlPerServing: Double?

    var isWater: Bool {
        id == "drink_water"
    }

    var supportsWaterPresets: Bool {
        isWater && kind == .drink
    }

    static func from(meal: Meals) -> QuickLogNutritionProfile {
        let grams = Double(meal.servingGrams ?? 100)
        return QuickLogNutritionProfile(
            id: meal.id,
            title: meal.isFoodProduct ? meal.title : meal.localizedShortTitle,
            subtitle: meal.isFoodProduct ? meal.servingDescription : meal.localizedDisplaySubtitle,
            imageName: meal.imageName,
            icon: "fork.knife",
            kind: .meal,
            caloriesPerServing: meal.calories,
            proteinPerServing: meal.protein,
            carbsPerServing: meal.carbs,
            fatPerServing: meal.fats,
            fiberPerServing: meal.fiber,
            defaultServingAmount: 1,
            servingUnit: .portion,
            gramsPerServing: grams,
            mlPerServing: nil
        )
    }

    static func from(item: QuickItem) -> QuickLogNutritionProfile {
        // Persist canonical English catalog titles. Localize only at display time —
        // storing localized titles (e.g. "Вода") leaks into English UI later.
        QuickLogNutritionProfile(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            imageName: item.imageName,
            icon: item.icon,
            kind: item.category == .drink ? .drink : .snack,
            caloriesPerServing: item.caloriesPerServing,
            proteinPerServing: item.proteinPerServing,
            carbsPerServing: item.carbsPerServing,
            fatPerServing: item.fatPerServing,
            fiberPerServing: item.fiberPerServing,
            defaultServingAmount: item.defaultServingAmountValue,
            servingUnit: item.resolvedServingUnit,
            gramsPerServing: item.gramsPerServing,
            mlPerServing: item.mlPerServing
        )
    }
}

struct QuickLogSelection: Equatable {
    var portions: Double
    var mode: QuickLogQuantityMode
    var alternateAmount: Double?
    var isExpanded: Bool
    var loggedActivityID: String?

    static let portionPresets: [Double] = [0.5, 1, 1.5, 2, 3]
    static let waterPresetsML: [Double] = [250, 500, 750, 1000]

    init(
        portions: Double = 0,
        mode: QuickLogQuantityMode = .portions,
        alternateAmount: Double? = nil,
        isExpanded: Bool = false,
        loggedActivityID: String? = nil
    ) {
        self.portions = portions
        self.mode = mode
        self.alternateAmount = alternateAmount
        self.isExpanded = isExpanded
        self.loggedActivityID = loggedActivityID
    }

    var isSelected: Bool {
        portions > 0
    }

    var badgeQuantity: Int? {
        guard isSelected else { return nil }
        let value = QuickLogServingMath.effectivePortions(
            portions: portions,
            mode: mode,
            alternateAmount: alternateAmount,
            profile: nil
        )
        let rounded = Int(value.rounded())
        return rounded > 1 ? rounded : nil
    }

    func effectivePortions(for profile: QuickLogNutritionProfile) -> Double {
        QuickLogServingMath.effectivePortions(
            portions: portions,
            mode: mode,
            alternateAmount: alternateAmount,
            profile: profile
        )
    }
}

enum QuickLogServingMath {

    static func effectivePortions(
        portions: Double,
        mode: QuickLogQuantityMode,
        alternateAmount: Double?,
        profile: QuickLogNutritionProfile?
    ) -> Double {
        guard let profile else { return max(portions, 0) }

        switch mode {
        case .portions:
            return max(portions, 0)
        case .grams:
            guard let grams = alternateAmount, let gramsPerServing = profile.gramsPerServing, gramsPerServing > 0 else {
                return max(portions, 0)
            }
            return grams / gramsPerServing
        case .milliliters:
            guard let milliliters = alternateAmount, let mlPerServing = profile.mlPerServing, mlPerServing > 0 else {
                return max(portions, 0)
            }
            return milliliters / mlPerServing
        }
    }

    static func nutrition(
        for profile: QuickLogNutritionProfile,
        selection: QuickLogSelection
    ) -> QuickLogNutritionValues {
        let effective = selection.effectivePortions(for: profile)
        let clamped = max(effective, 0)

        let grams: Double?
        let milliliters: Double?

        switch selection.mode {
        case .portions:
            grams = profile.gramsPerServing.map { $0 * clamped }
            milliliters = profile.mlPerServing.map { $0 * clamped }
        case .grams:
            grams = selection.alternateAmount
            milliliters = nil
        case .milliliters:
            grams = nil
            milliliters = selection.alternateAmount
        }

        return QuickLogNutritionValues(
            calories: scaledInt(profile.caloriesPerServing, by: clamped),
            protein: scaledInt(profile.proteinPerServing, by: clamped),
            carbs: scaledInt(profile.carbsPerServing, by: clamped),
            fats: scaledInt(profile.fatPerServing, by: clamped),
            fiber: scaledInt(profile.fiberPerServing, by: clamped),
            portions: clamped,
            grams: grams,
            milliliters: milliliters
        )
    }

    static func defaultSelection(for profile: QuickLogNutritionProfile) -> QuickLogSelection {
        switch profile.kind {
        case .drink:
            let ml = profile.mlPerServing ?? profile.defaultServingAmount
            return QuickLogSelection(
                portions: 1,
                mode: .portions,
                alternateAmount: ml,
                isExpanded: false
            )
        case .meal, .snack:
            return QuickLogSelection(portions: 1, mode: .portions, isExpanded: false)
        }
    }

    static func formattedQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func scaledInt(_ base: Int, by multiplier: Double) -> Int {
        Int((Double(base) * multiplier).rounded())
    }
}
