import Foundation

enum QuickLogToastMessage {

    static func make(
        profile: QuickLogNutritionProfile,
        selection: QuickLogSelection
    ) -> String {
        let nutrition = QuickLogServingMath.nutrition(for: profile, selection: selection)

        if profile.isWater {
            let ml = Int(
                (
                    nutrition.milliliters
                        ?? nutrition.portions * (profile.mlPerServing ?? 250)
                ).rounded()
            )
            if ml >= 1000 {
                return String(
                    format: WeekFitLocalizedString("quickLog.toast.waterOneLiterFormat"),
                    profile.title
                )
            }
            return String(
                format: WeekFitLocalizedString("quickLog.toast.waterMillilitersFormat"),
                profile.title,
                ml
            )
        }

        let portions = nutrition.portions
        if portions > 1 {
            return String(
                format: WeekFitLocalizedString("quickLog.toast.portionsFormat"),
                profile.title,
                QuickLogServingMath.formattedQuantity(portions)
            )
        }

        if nutrition.calories > 0 {
            return String(
                format: WeekFitLocalizedString("quickLog.toast.singleCaloriesFormat"),
                profile.title,
                nutrition.calories
            )
        }

        return String(
            format: WeekFitLocalizedString("quickLog.toast.loggedFormat"),
            profile.title
        )
    }
}
