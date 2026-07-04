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
        nutritionDataAvailable: Bool
    ) -> CoachDailyObservationNutritionSnapshot? {
        guard nutritionDataAvailable else { return nil }

        let caloriesEaten = Int(totals.caloriesEaten.rounded())
        let calorieDeficit: Int? = {
            guard let calorieTarget, calorieTarget > 0 else { return nil }
            return calorieTarget - caloriesEaten
        }()

        return CoachDailyObservationNutritionSnapshot(
            proteinGrams: Int(totals.proteinGrams.rounded()),
            carbsGrams: Int(totals.carbsGrams.rounded()),
            fatGrams: Int(totals.fatGrams.rounded()),
            caloriesEaten: caloriesEaten,
            calorieDeficit: calorieDeficit,
            hydrationLiters: totals.hydrationLiters,
            mealsLoggedCount: totals.mealsLoggedCount
        )
    }
}
