import Foundation

/// Maps free-text recognition names onto `MealBuilderDemoData` ingredients (deterministic macros).
enum PhotoFoodCatalogMatcher {

    struct Match: Equatable, Sendable {
        let ingredient: MealBuilderIngredient
        let score: Int
    }

    static func match(name: String, preparation: String? = nil) -> Match? {
        let query = normalized(name)
        let prep = normalized(preparation ?? "")
        guard !query.isEmpty else { return nil }

        var best: Match?
        for ingredient in MealBuilderDemoData.ingredients {
            let candidates = [
                ingredient.title,
                ingredient.localizedTitle,
                ingredient.russianTitle,
                ingredient.chineseTitle,
                ingredient.id.replacingOccurrences(of: "_", with: " ")
            ].map(normalized)

            for candidate in candidates where !candidate.isEmpty {
                var score = 0
                if candidate == query {
                    score = 100
                } else if candidate.contains(query) || query.contains(candidate) {
                    score = 72
                } else if tokens(query).contains(where: { candidate.contains($0) && $0.count >= 3 }) {
                    score = 48
                }

                if score > 0 {
                    score += preparationBonus(prep: prep, ingredientId: ingredient.id)
                    if best == nil || score > best!.score {
                        best = Match(ingredient: ingredient, score: score)
                    }
                }
            }
        }

        guard let best, best.score >= 48 else { return nil }
        return best
    }

    /// Builds a single-component draft from barcode / label estimate (DB-backed).
    static func component(from estimate: FoodPhotoNutritionEstimate) -> PhotoFoodComponent {
        let grams = Double(max(estimate.servingGrams, 1))
        let scale = 100.0 / grams
        return PhotoFoodComponent(
            id: "barcode_\(estimate.barcode ?? UUID().uuidString)",
            displayName: estimate.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? WeekFitLocalizedString("today.photoLog.unnamedFood"),
            grams: grams,
            catalogIngredientId: nil,
            preparation: nil,
            caloriesPer100g: Double(estimate.calories ?? 0) * scale,
            proteinPer100g: Double(estimate.protein ?? 0) * scale,
            carbsPer100g: Double(estimate.carbs ?? 0) * scale,
            fatsPer100g: Double(estimate.fats ?? 0) * scale,
            fiberPer100g: Double(estimate.fiber ?? 0) * scale,
            nutritionSource: estimate.dataSource ?? .nutritionLabelOCR,
            isAIEstimated: false
        )
    }

    // MARK: - Helpers

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(_ value: String) -> [String] {
        value.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" }).map(String.init)
    }

    private static func preparationBonus(prep: String, ingredientId: String) -> Int {
        guard !prep.isEmpty else { return 0 }
        // Prefer cooked-grain style when prep mentions cook/boil/steam.
        let cookedHints = ["cook", "boil", "steam", "готов", "вар", "蒸", "煮"]
        let friedHints = ["fry", "fried", "pan", "жар", "жарен", "煎"]
        let dryHints = ["dry", "raw", "uncooked", "сырой", "сух"]
        let isCooked = cookedHints.contains { prep.contains($0) }
        let isFried = friedHints.contains { prep.contains($0) }
        let isDry = dryHints.contains { prep.contains($0) }
        if isCooked, ingredientId.contains("rice") || ingredientId.contains("pasta") || ingredientId.contains("potato") {
            return 8
        }
        if ingredientId == "protein_eggs_fried" {
            return isFried ? 12 : (isCooked ? -2 : 0)
        }
        if ingredientId == "protein_eggs" {
            if isFried { return -6 }
            if isCooked { return 8 }
        }
        if isDry {
            return -4
        }
        return 0
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
