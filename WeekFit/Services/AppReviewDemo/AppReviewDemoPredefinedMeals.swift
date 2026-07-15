import Foundation

enum AppReviewDemoPredefinedMeals {

    struct ScheduledMeal: Equatable {
        let meal: Meals
        let hour: Int
        let minute: Int
        let durationMinutes: Int

        init(
            meal: Meals,
            hour: Int,
            minute: Int = 0,
            durationMinutes: Int = 15
        ) {
            self.meal = meal
            self.hour = hour
            self.minute = minute
            self.durationMinutes = durationMinutes
        }
    }

    private static let catalogByID: [String: Meals] = {
        let meals = NutritionRepository().loadMeals()
        return Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })
    }()

    private static let breakfastIDs = [
        "meal_fried_eggs_spinach_hollandaise",
        "meal_oatmeal_berries",
        "meal_apple_coconut_millet_porridge",
        "meal_milk_sponge_protein_sandwich",
    ]

    private static let lunchIDs = [
        "meal_chicken_rice_bowl",
        "meal_bangkok_chicken_quinoa",
        "meal_cavatappi_chicken_meatballs",
        "meal_turkey_mushroom_potato",
    ]

    private static let dinnerIDs = [
        "meal_salmon_quinoa",
        "meal_braised_chicken_drumsticks_asparagus",
        "meal_beef_cutlets_turmeric_rice",
        "meal_soba_duck_blackbean",
    ]

    private static let snackIDs = [
        "meal_protein_shake",
        "meal_savory_granola_cottage_cheese",
        "meal_goat_cheese_sundried_tomato_paste",
    ]

    static func todaySchedule() -> [ScheduledMeal] {
        [
            scheduledMeal(id: breakfastIDs[0], hour: 8, minute: 10, durationMinutes: 15),
            scheduledMeal(id: lunchIDs[0], hour: 13, minute: 5, durationMinutes: 20),
            scheduledMeal(id: snackIDs[0], hour: 16, minute: 20, durationMinutes: 5),
        ].compactMap { $0 }
    }

    static func schedule(forDayOffset offset: Int) -> [ScheduledMeal] {
        [
            scheduledMeal(
                id: breakfastIDs[offset % breakfastIDs.count],
                hour: 8,
                durationMinutes: 15
            ),
            scheduledMeal(
                id: lunchIDs[offset % lunchIDs.count],
                hour: 13,
                durationMinutes: 20
            ),
            scheduledMeal(
                id: dinnerIDs[offset % dinnerIDs.count],
                hour: 19,
                durationMinutes: 25
            ),
            scheduledMeal(
                id: snackIDs[offset % snackIDs.count],
                hour: 16,
                durationMinutes: 5
            ),
        ].compactMap { $0 }
    }

    static func meal(withID id: String) -> Meals? {
        catalogByID[id]
    }

    private static func scheduledMeal(
        id: String,
        hour: Int,
        minute: Int = 0,
        durationMinutes: Int
    ) -> ScheduledMeal? {
        guard let meal = catalogByID[id] else { return nil }
        return ScheduledMeal(
            meal: meal,
            hour: hour,
            minute: minute,
            durationMinutes: durationMinutes
        )
    }
}
