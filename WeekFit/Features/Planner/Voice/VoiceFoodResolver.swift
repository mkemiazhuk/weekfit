import Foundation

struct VoiceFoodPortion: Equatable {
    var title: String
    var activityType: String
    var imageName: String
    var icon: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int
    /// True when the numbers are an estimate, not a saved meal or catalog portion.
    var estimated: Bool
    /// Saved meal this portion came from. Nil for a quick item, catalog ingredient, or estimate.
    var libraryMealId: String? = nil
}

enum VoiceFoodDecision: Equatable {
    case water
    case needsCalories
    case ready(VoiceFoodPortion)
}

/// Resolves a spoken food or caloric drink into diary numbers.
/// Calories come from a number the person said, or from an exact saved meal, quick item, or catalog ingredient.
enum VoiceFoodResolver {

    static func resolve(
        title: String,
        kind: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        grams: Int,
        milliliters: Int,
        meals: [Meals],
        quickItems: [QuickItem]
    ) -> VoiceFoodDecision {
        let spoken = clampedTitle(title)
        guard !spoken.isEmpty else { return .needsCalories }
        if isWater(spoken) { return .water }

        let statedCalories = calories > 0 && calories <= 5_000 ? calories : 0
        if calories > 5_000 { return .needsCalories }

        let statedProtein = bounded(protein, max: 400)
        let statedCarbs = bounded(carbs, max: 400)
        let statedFat = bounded(fat, max: 400)
        let statedGrams = bounded(grams, max: 2_000)
        let statedMilliliters = bounded(milliliters, max: 2_000)
        let gaveMacros = statedProtein > 0 || statedCarbs > 0 || statedFat > 0

        let known = knownPortion(
            title: spoken,
            grams: statedGrams,
            milliliters: statedMilliliters,
            meals: meals,
            quickItems: quickItems
        )
        if let known {
            if known.unscalable {
                guard statedCalories > 0 else { return .needsCalories }
                return portion(
                    known,
                    title: spoken,
                    kind: kind,
                    calories: statedCalories,
                    protein: statedProtein,
                    carbs: statedCarbs,
                    fats: statedFat,
                    fiber: 0,
                    gaveMacros: true,
                    estimated: true
                )
            }
            // A saved or catalog portion wins over a calorie guess. A number the
            // person named, sent without invented nutrients, still replaces it.
            let personNamedCalories = statedCalories > 0 && !gaveMacros
            let resolvedCalories = personNamedCalories ? statedCalories : known.calories
            guard resolvedCalories > 0 else { return .needsCalories }
            return portion(
                known,
                title: spoken,
                kind: kind,
                calories: resolvedCalories,
                protein: personNamedCalories ? scaled(known.protein, from: known.calories, to: resolvedCalories) : known.protein,
                carbs: personNamedCalories ? scaled(known.carbs, from: known.calories, to: resolvedCalories) : known.carbs,
                fats: personNamedCalories ? scaled(known.fats, from: known.calories, to: resolvedCalories) : known.fats,
                fiber: personNamedCalories ? scaled(known.fiber, from: known.calories, to: resolvedCalories) : known.fiber,
                gaveMacros: false,
                estimated: false
            )
        }

        guard let base = statedCalories > 0 ? emptyPortion(title: spoken, kind: kind) : nil else {
            return .needsCalories
        }

        if base.unscalable {
            guard statedCalories > 0 else { return .needsCalories }
            return portion(
                base,
                title: spoken,
                kind: kind,
                calories: statedCalories,
                protein: statedProtein,
                carbs: statedCarbs,
                fats: statedFat,
                fiber: 0,
                gaveMacros: true,
                estimated: true
            )
        }

        let resolvedCalories = statedCalories > 0 ? statedCalories : base.calories
        guard resolvedCalories > 0 else { return .needsCalories }
        let usedKnownNumbers = known != nil && statedCalories == 0 && !gaveMacros

        return portion(
            base,
            title: spoken,
            kind: kind,
            calories: resolvedCalories,
            protein: gaveMacros ? statedProtein : scaled(base.protein, from: base.calories, to: resolvedCalories),
            carbs: gaveMacros ? statedCarbs : scaled(base.carbs, from: base.calories, to: resolvedCalories),
            fats: gaveMacros ? statedFat : scaled(base.fats, from: base.calories, to: resolvedCalories),
            fiber: gaveMacros ? 0 : scaled(base.fiber, from: base.calories, to: resolvedCalories),
            gaveMacros: gaveMacros,
            estimated: !usedKnownNumbers
        )
    }

    // MARK: - Known foods

    private struct Base {
        var activityType: String
        var imageName: String
        var icon: String
        var calories: Int
        var protein: Int
        var carbs: Int
        var fats: Int
        var fiber: Int
        var unscalable: Bool = false
        var libraryMealId: String? = nil
    }

    private static func knownPortion(
        title: String,
        grams: Int,
        milliliters: Int,
        meals: [Meals],
        quickItems: [QuickItem]
    ) -> Base? {
        let query = normalized(title)
        if let match = lookup(query, grams: grams, milliliters: milliliters, meals: meals, quickItems: quickItems, folded: title) {
            return match
        }
        let stripped = withoutQuantityWords(query)
        guard stripped != query, !stripped.isEmpty else { return nil }
        return lookup(stripped, grams: grams, milliliters: milliliters, meals: meals, quickItems: quickItems, folded: stripped)
    }

    private static func lookup(
        _ query: String,
        grams: Int,
        milliliters: Int,
        meals: [Meals],
        quickItems: [QuickItem],
        folded: String
    ) -> Base? {
        if let meal = meals.first(where: { normalized($0.title) == query || normalized($0.localizedShortTitle) == query }) {
            return mealPortion(meal, grams: grams, milliliters: milliliters)
        }
        if let item = quickItems.first(where: { normalized($0.title) == query || normalized($0.localizedTitle) == query }) {
            return quickPortion(item, grams: grams, milliliters: milliliters)
        }
        let name = folded.replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "Ё", with: "Е")
        if let match = PhotoFoodCatalogMatcher.match(name: name), match.score == 100 {
            return ingredientPortion(match.ingredient, grams: grams, milliliters: milliliters)
        }
        return nil
    }

    private static func withoutQuantityWords(_ query: String) -> String {
        let fillers: Set<String> = [
            "cup", "cups", "mug", "mugs", "glass", "glasses",
            "чашка", "чашку", "чашки", "кружка", "кружку", "кружки",
            "стакан", "стакана", "стаканчик"
        ]
        return query.split(separator: " ").map(String.init).filter { !fillers.contains($0) }.joined(separator: " ")
    }

    private static func mealPortion(_ meal: Meals, grams: Int, milliliters: Int) -> Base {
        if milliliters > 0 {
            return Base(activityType: "meal", imageName: meal.imageName, icon: "fork.knife", calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, unscalable: true)
        }
        let factor: Double
        if grams > 0 {
            guard let serving = meal.servingGrams, serving > 0 else {
                return Base(activityType: "meal", imageName: meal.imageName, icon: "fork.knife", calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, unscalable: true)
            }
            factor = Double(grams) / Double(serving)
        } else {
            factor = 1
        }
        return Base(
            activityType: "meal",
            imageName: meal.imageName,
            icon: "fork.knife",
            calories: scaledDouble(Double(meal.calories), factor),
            protein: scaledDouble(Double(meal.protein), factor),
            carbs: scaledDouble(Double(meal.carbs), factor),
            fats: scaledDouble(Double(meal.fats), factor),
            fiber: scaledDouble(Double(meal.fiber), factor),
            libraryMealId: meal.id
        )
    }

    private static func quickPortion(_ item: QuickItem, grams: Int, milliliters: Int) -> Base {
        let type = item.category == .drink ? "drink" : "snack"
        let icon = type == "drink" ? "cup.and.saucer.fill" : "leaf.fill"
        let factor: Double
        if milliliters > 0 {
            guard let serving = item.mlPerServing, serving > 0 else {
                return Base(activityType: type, imageName: item.imageName, icon: icon, calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, unscalable: true)
            }
            factor = Double(milliliters) / serving
        } else if grams > 0 {
            guard let serving = item.gramsPerServing, serving > 0 else {
                return Base(activityType: type, imageName: item.imageName, icon: icon, calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, unscalable: true)
            }
            factor = Double(grams) / serving
        } else {
            factor = 1
        }
        return Base(
            activityType: type,
            imageName: item.imageName,
            icon: icon,
            calories: scaledDouble(Double(item.calories), factor),
            protein: scaledDouble(Double(item.protein), factor),
            carbs: scaledDouble(Double(item.carbs), factor),
            fats: scaledDouble(Double(item.fats), factor),
            fiber: scaledDouble(Double(item.fiber), factor)
        )
    }

    private static func ingredientPortion(_ ingredient: MealBuilderIngredient, grams: Int, milliliters: Int) -> Base {
        if milliliters > 0 {
            return Base(activityType: "meal", imageName: ingredient.imageName, icon: "fork.knife", calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, unscalable: true)
        }
        let used = grams > 0 ? grams : ingredient.defaultGrams
        let factor = Double(used) / 100
        return Base(
            activityType: "meal",
            imageName: ingredient.imageName,
            icon: "fork.knife",
            calories: scaledDouble(ingredient.caloriesPer100g, factor),
            protein: scaledDouble(ingredient.proteinPer100g, factor),
            carbs: scaledDouble(ingredient.carbsPer100g, factor),
            fats: scaledDouble(ingredient.fatsPer100g, factor),
            fiber: scaledDouble(ingredient.fiberPer100g, factor)
        )
    }

    private static func emptyPortion(title: String, kind: String) -> Base {
        Base(
            activityType: activityType(kind: kind, fallback: "meal"),
            imageName: "",
            icon: icon(for: activityType(kind: kind, fallback: "meal")),
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0
        )
    }

    private static func portion(
        _ base: Base,
        title: String,
        kind: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int,
        fiber: Int,
        gaveMacros: Bool,
        estimated: Bool
    ) -> VoiceFoodDecision {
        let type = activityType(kind: kind, fallback: base.activityType)
        return .ready(VoiceFoodPortion(
            title: title,
            activityType: type,
            imageName: base.imageName,
            icon: icon(for: type),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: gaveMacros ? 0 : fiber,
            estimated: estimated,
            libraryMealId: base.libraryMealId
        ))
    }

    // MARK: - Text

    private static func isWater(_ title: String) -> Bool {
        let water: Set<String> = ["water", "вода", "воды", "воде", "воду", "водичка", "водички", "водичку", "h2o"]
        let fillers: Set<String> = [
            "a", "an", "the", "of", "glass", "glasses", "cup", "cups", "bottle",
            "стакан", "стакана", "стаканчик", "чашка", "чашку", "чашки", "бутылка", "бутылку", "мл", "ml"
        ]
        let tokens = normalized(title).split(separator: " ").map(String.init)
        guard tokens.contains(where: { water.contains($0) }) else { return false }
        return tokens.allSatisfy { water.contains($0) || fillers.contains($0) }
    }

    private static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "Ё", with: "Е")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ru"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func clampedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let cleaned = dropConflictingPreparation(String(collapsed))
        return String(cleaned.prefix(80))
    }

    /// «два жареных Яйца варёные» keeps the preparation the person said.
    private static func dropConflictingPreparation(_ title: String) -> String {
        let tokens = title.split(separator: " ").map(String.init)
        guard tokens.count > 2 else { return title }
        func preparation(_ word: String) -> String? {
            let token = normalized(word)
            if token.contains("жарен") || token.contains("fried") { return "fried" }
            if token.contains("варен") || token.contains("boiled") { return "boiled" }
            return nil
        }
        func isEgg(_ word: String) -> Bool {
            let token = normalized(word)
            return token.hasPrefix("яйц") || token.hasPrefix("egg")
        }
        guard Set(tokens.compactMap(preparation)).count > 1 else { return title }
        var drop = Set<Int>()
        for index in tokens.indices where isEgg(tokens[index]) {
            let next = tokens.index(after: index)
            if next < tokens.endIndex, preparation(tokens[next]) != nil {
                drop.insert(next)
            }
            if index > tokens.startIndex {
                let previous = tokens.index(before: index)
                guard let attached = preparation(tokens[previous]) else { continue }
                let earlierDiffers = tokens[..<previous].contains { word in
                    guard let kind = preparation(word) else { return false }
                    return kind != attached
                }
                if earlierDiffers { drop.insert(previous) }
            }
        }
        guard !drop.isEmpty else { return title }
        return tokens.enumerated().filter { !drop.contains($0.offset) }.map(\.element).joined(separator: " ")
    }

    private static func activityType(kind: String, fallback: String) -> String {
        switch kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "snack": return "snack"
        case "drink": return "drink"
        case "meal": return "meal"
        default: return fallback
        }
    }

    private static func icon(for type: String) -> String {
        switch type {
        case "drink": return "cup.and.saucer.fill"
        case "snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }

    private static func bounded(_ value: Int, max: Int) -> Int {
        guard value > 0 else { return 0 }
        return value > max ? 0 : value
    }

    private static func scaled(_ value: Int, from baseCalories: Int, to calories: Int) -> Int {
        guard baseCalories > 0 else { return 0 }
        return Int((Double(value) * Double(calories) / Double(baseCalories)).rounded())
    }

    private static func scaledDouble(_ value: Double, _ factor: Double) -> Int {
        Int((value * factor).rounded())
    }
}
