import Foundation

enum CoachDailyObservationNutritionBuilder {

    struct ResolvedDayTotals: Equatable, Sendable {
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let caloriesEaten: Double
        let hydrationLiters: Double
        let mealsLoggedCount: Int
    }

    static func build(
        totals: ResolvedDayTotals,
        calorieTarget: Int?,
        nutritionDataAvailable: Bool,
        source: CoachNutritionSource = .none,
        proteinWithinPostWorkoutWindowGrams: Int? = nil
    ) -> CoachDailyObservationNutritionSnapshot? {
        guard nutritionDataAvailable else { return nil }

        let caloriesEaten = Int(totals.caloriesEaten.rounded())
        let proteinGrams = Int(totals.proteinGrams.rounded())
        let carbsGrams = Int(totals.carbsGrams.rounded())
        let fatGrams = Int(totals.fatGrams.rounded())
        let completeness = CoachNutritionCompletenessClassifier.classify(
            mealsLoggedCount: totals.mealsLoggedCount,
            caloriesEaten: caloriesEaten,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            hydrationLiters: totals.hydrationLiters
        )

        return CoachDailyObservationNutritionSnapshot(
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            caloriesEaten: caloriesEaten,
            calorieDeficit: calorieDeficit(
                caloriesEaten: caloriesEaten,
                calorieTarget: calorieTarget,
                completeness: completeness
            ),
            hydrationLiters: totals.hydrationLiters,
            mealsLoggedCount: totals.mealsLoggedCount,
            nutritionCompleteness: completeness,
            nutritionSource: source,
            proteinWithinPostWorkoutWindowGrams: proteinWithinPostWorkoutWindowGrams
        )
    }

    /// Empty / unknown days must not invent underfueling via `target - 0`.
    static func calorieDeficit(
        caloriesEaten: Int,
        calorieTarget: Int?,
        completeness: CoachNutritionCompleteness
    ) -> Int? {
        guard completeness.isTrustworthyForBeliefs else { return nil }
        guard let calorieTarget, calorieTarget > 0 else { return nil }
        return calorieTarget - caloriesEaten
    }
}
