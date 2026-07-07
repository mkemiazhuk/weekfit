import Foundation

struct CoachNutritionContext {

    let caloriesCurrent: Double
    let caloriesGoal: Double

    let proteinCurrent: Double
    let proteinGoal: Double

    let carbsCurrent: Double
    let carbsGoal: Double

    let fatsCurrent: Double
    let fatsGoal: Double

    let waterCurrent: Double
    let waterGoal: Double

    let mealsCount: Int?
    let lastMealTime: Date?

    init(
        caloriesCurrent: Double,
        caloriesGoal: Double,
        proteinCurrent: Double,
        proteinGoal: Double,
        carbsCurrent: Double = 0,
        carbsGoal: Double = 0,
        fatsCurrent: Double = 0,
        fatsGoal: Double = 0,
        waterCurrent: Double,
        waterGoal: Double,
        mealsCount: Int? = nil,
        lastMealTime: Date? = nil
    ) {
        self.caloriesCurrent = caloriesCurrent
        self.caloriesGoal = caloriesGoal
        self.proteinCurrent = proteinCurrent
        self.proteinGoal = proteinGoal
        self.carbsCurrent = carbsCurrent
        self.carbsGoal = carbsGoal
        self.fatsCurrent = fatsCurrent
        self.fatsGoal = fatsGoal
        self.waterCurrent = waterCurrent
        self.waterGoal = waterGoal
        self.mealsCount = mealsCount
        self.lastMealTime = lastMealTime
    }

    // MARK: - Remaining

    var caloriesRemaining: Int {
        max(0, Int(caloriesGoal - caloriesCurrent))
    }

    var proteinRemaining: Int {
        max(0, Int(proteinGoal - proteinCurrent))
    }

    var waterRemainingLiters: Double {
        max(0, waterGoal - waterCurrent)
    }

    // MARK: - Recovery Signals

    var needsProteinRecovery: Bool {
        proteinRemaining >= 25
    }

    var needsHydrationRecovery: Bool {
        waterRemainingLiters >= 0.5
    }

    var proteinStatusText: String {
        if proteinRemaining <= 0 {
            return "Protein target reached"
        }

        return "\(proteinRemaining)g protein remaining"
    }

    var hydrationStatusText: String {
        if waterRemainingLiters <= 0 {
            return "Hydration target reached"
        }

        return "\(String(format: "%.1f", waterRemainingLiters))L water remaining"
    }

    // MARK: - Recovery Recommendations

    var recommendedProteinText: String? {

        guard needsProteinRecovery else {
            return nil
        }

        switch proteinRemaining {

        case 60...:
            return "Add 40g protein"

        case 35...59:
            return "Add 30–40g protein"

        case 25...34:
            return "Add 25–30g protein"

        default:
            return nil
        }
    }

    var recommendedHydrationText: String? {

        guard needsHydrationRecovery else {
            return nil
        }

        switch waterRemainingLiters {

        case 1.0...:
            return "Drink 750–1000ml water"

        default:
            return "Drink 500–750ml water"
        }
    }
}

enum CoachNutritionConsistency {
    static func assertMatchesCurrentMetrics(
        metrics: DailyNutritionMetrics?,
        coach: CoachNutritionContext,
        source: String
    ) {
        guard let metrics else { return }

        let calorieDelta = abs(metrics.calories - coach.caloriesCurrent)
        let carbDelta = abs(metrics.carbs - coach.carbsCurrent)
        let proteinDelta = abs(metrics.protein - coach.proteinCurrent)
        let fatDelta = abs(metrics.fats - coach.fatsCurrent)

        #if DEBUG
        let message = """
        source=\(source) \
        todayCalories=\(String(format: "%.1f", metrics.calories)) coachCalories=\(String(format: "%.1f", coach.caloriesCurrent)) \
        todayCarbs=\(String(format: "%.1f", metrics.carbs)) coachCarbs=\(String(format: "%.1f", coach.carbsCurrent)) \
        todayProtein=\(String(format: "%.1f", metrics.protein)) coachProtein=\(String(format: "%.1f", coach.proteinCurrent)) \
        todayFat=\(String(format: "%.1f", metrics.fats)) coachFat=\(String(format: "%.1f", coach.fatsCurrent))
        """
        CoachRefreshDebug.log("[CoachNutritionInvariant]", message)

        assert(calorieDelta < 1, "Coach nutrition calories diverged from Today metrics. \(message)")
        assert(carbDelta < 1, "Coach nutrition carbs diverged from Today metrics. \(message)")
        assert(proteinDelta < 1, "Coach nutrition protein diverged from Today metrics. \(message)")
        assert(fatDelta < 1, "Coach nutrition fat diverged from Today metrics. \(message)")
        #endif
    }
}
