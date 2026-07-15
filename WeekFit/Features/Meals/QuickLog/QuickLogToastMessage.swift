import Foundation

enum QuickLogToastMessage {

    static func make(
        profile: QuickLogNutritionProfile,
        selection: QuickLogSelection
    ) -> String {
        let nutrition = QuickLogServingMath.nutrition(for: profile, selection: selection)
        let displayTitle = QuickItem.localizedTitle(forStoredTitle: profile.title)

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
                    displayTitle
                )
            }
            return String(
                format: WeekFitLocalizedString("quickLog.toast.waterMillilitersFormat"),
                displayTitle,
                ml
            )
        }

        let portions = nutrition.portions
        if portions > 1 {
            return WeekFitCountPluralization.toastPortionsPhrase(
                title: displayTitle,
                quantity: portions,
                formattedQuantity: QuickLogServingMath.formattedQuantity(portions)
            )
        }

        if nutrition.calories > 0 {
            return String(
                format: WeekFitLocalizedString("quickLog.toast.singleCaloriesFormat"),
                displayTitle,
                nutrition.calories
            )
        }

        return String(
            format: WeekFitLocalizedString("quickLog.toast.loggedFormat"),
            displayTitle
        )
    }
}
