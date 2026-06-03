import Foundation

struct CoachNutritionContext {

    let caloriesCurrent: Double
    let caloriesGoal: Double

    let proteinCurrent: Double
    let proteinGoal: Double

    let waterCurrent: Double
    let waterGoal: Double

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
