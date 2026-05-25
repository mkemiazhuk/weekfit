import Foundation

struct MealNutritionTarget {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
}

@MainActor
final class MealsService {

    private let healthManager = HealthManager()
    private let repository = NutritionRepository()

    private var lastPlanIDs = Set<String>()

    func getMealsPlan() async -> [Meals] {
        await healthManager.loadHealthData()

        let allMeals = repository.loadMeals()
        let consumed = consumedTarget()
        let target = calculateTarget()

        let remaining = MealNutritionTarget(
            calories: max(target.calories - consumed.calories, 0),
            protein: max(target.protein - consumed.protein, 0),
            carbs: max(target.carbs - consumed.carbs, 0),
            fats: max(target.fats - consumed.fats, 0)
        )

        let plan = buildPlan(
            from: allMeals,
            remaining: remaining,
            slots: remainingSlots(),
            excluding: []
        )

        lastPlanIDs = Set(plan.map { meal in
            meal.id
        })

        return plan
    }

    func regenerateMealsPlan() async -> [Meals] {
        await healthManager.loadHealthData()

        let allMeals = repository.loadMeals()
        let consumed = consumedTarget()
        let target = calculateTarget()

        let remaining = MealNutritionTarget(
            calories: max(target.calories - consumed.calories, 0),
            protein: max(target.protein - consumed.protein, 0),
            carbs: max(target.carbs - consumed.carbs, 0),
            fats: max(target.fats - consumed.fats, 0)
        )

        let plan = buildPlan(
            from: allMeals,
            remaining: remaining,
            slots: remainingSlots(),
            excluding: lastPlanIDs
        )

        let finalPlan: [Meals]

        if plan.isEmpty {
            finalPlan = buildPlan(
                from: allMeals,
                remaining: remaining,
                slots: remainingSlots(),
                excluding: []
            )
        } else {
            finalPlan = plan
        }

        lastPlanIDs = Set(finalPlan.map { meal in
            meal.id
        })

        return finalPlan
    }

    private func consumedTarget() -> MealNutritionTarget {
        MealNutritionTarget(
            calories: Int(healthManager.calories),
            protein: Int(healthManager.protein),
            carbs: Int(healthManager.carbs),
            fats: Int(healthManager.fats)
        )
    }

    private func calculateTarget() -> MealNutritionTarget {
        let weight = healthManager.weight > 0 ? healthManager.weight : 85
        let height = healthManager.heightCm > 0 ? healthManager.heightCm : 175
        let age = healthManager.age > 0 ? healthManager.age : 40

        let bmr: Double

        switch healthManager.biologicalSex {
        case .female:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        default:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        }

        let baseCalories = bmr * 1.25
        let adjustedCalories = Int(baseCalories + healthManager.activeCalories)

        let protein = Int(weight * 1.6)
        let fats = Int(weight * 0.8)

        let proteinCalories = protein * 4
        let fatCalories = fats * 9
        let carbs = max((adjustedCalories - proteinCalories - fatCalories) / 4, 80)

        return MealNutritionTarget(
            calories: adjustedCalories,
            protein: protein,
            carbs: carbs,
            fats: fats
        )
    }

    private func remainingSlots() -> [WeekFitMealSlot] {
        return [.breakfast, .lunch, .dinner]
    }

    private func buildPlan(
        from meals: [Meals],
        remaining: MealNutritionTarget,
        slots: [WeekFitMealSlot],
        excluding excludedIDs: Set<String>
    ) -> [Meals] {
        guard !slots.isEmpty else { return [] }

        let targets = distribute(
            remaining: remaining,
            across: slots
        )

        var result: [Meals] = []
        var usedIDs = excludedIDs

        for item in targets {
            if let meal = bestMeal(
                from: meals,
                slot: item.slot,
                target: item.target,
                excluding: usedIDs
            ) {
                result.append(meal)
                usedIDs.insert(meal.id)
            }
        }

        return result.sorted { firstMeal, secondMeal in
            firstMeal.displayTime < secondMeal.displayTime
        }
    }

    private func distribute(
        remaining: MealNutritionTarget,
        across slots: [WeekFitMealSlot]
    ) -> [(slot: WeekFitMealSlot, target: MealNutritionTarget)] {

        let weights: [WeekFitMealSlot: Double] = [
            .breakfast: 0.28,
            .lunch: 0.38,
            .snack: 0.12,
            .dinner: 0.32
        ]

        let total = slots.reduce(0.0) { partialResult, slot in
            partialResult + (weights[slot] ?? 0.25)
        }

        return slots.map { slot in
            let share = (weights[slot] ?? 0.25) / total

            return (
                slot,
                MealNutritionTarget(
                    calories: Int(Double(remaining.calories) * share),
                    protein: Int(Double(remaining.protein) * share),
                    carbs: Int(Double(remaining.carbs) * share),
                    fats: Int(Double(remaining.fats) * share)
                )
            )
        }
    }

    private func bestMeal(
        from meals: [Meals],
        slot: WeekFitMealSlot,
        target: MealNutritionTarget,
        excluding excludedIDs: Set<String>
    ) -> Meals? {

        let slotMeals = meals.filter { meal in
            meal.slot == slot && !excludedIDs.contains(meal.id)
        }

        let fallbackMeals = meals.filter { meal in
            !excludedIDs.contains(meal.id)
        }

        let candidates = slotMeals.isEmpty ? fallbackMeals : slotMeals

        let sorted = candidates.sorted { firstMeal, secondMeal in
            score(firstMeal, target: target) < score(secondMeal, target: target)
        }

        let topCandidates = Array(sorted.prefix(4))

        return topCandidates.randomElement()
    }

    private func score(_ meal: Meals, target: MealNutritionTarget) -> Int {
        let caloriesScore = abs(meal.calories - target.calories) * 3
        let proteinScore = abs(meal.protein - target.protein) * 8
        let carbsScore = abs(meal.carbs - target.carbs) * 4
        let fatsScore = abs(meal.fats - target.fats) * 5

        let lowProteinPenalty = meal.protein < 20 ? 80 : 0

        return caloriesScore + proteinScore + carbsScore + fatsScore + lowProteinPenalty
    }
}
