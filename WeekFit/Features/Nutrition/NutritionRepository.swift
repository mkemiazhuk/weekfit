import Foundation
import OSLog

final class NutritionRepository {

    private static let logger = Logger(subsystem: "WeekFit", category: "NutritionRepository")

    func loadMeals() -> [Meals] {
        guard let url = Bundle.main.url(forResource: "meals", withExtension: "json") else {
            Self.logger.error("Bundle resource not found resource=meals.json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Meals].self, from: data)
        } catch {
            Self.logger.error("Failed to decode bundle resource resource=meals.json error=\(String(describing: error), privacy: .public)")
            return []
        }
    }

    func loadQuickItems() -> [QuickItem] {
        guard let url = Bundle.main.url(
            forResource: "drinks_snacks",
            withExtension: "json"
        ) else {
            Self.logger.error("Bundle resource not found resource=drinks_snacks.json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [QuickItem].self,
                from: data
            )
        } catch {
            Self.logger.error("Failed to decode bundle resource resource=drinks_snacks.json error=\(String(describing: error), privacy: .public)")
            return []
        }
    }

    func loadDrinkItems() -> [QuickItem] {
        loadQuickItems().filter { $0.category == .drink }
    }

    func loadSnackItems() -> [QuickItem] {
        loadQuickItems().filter { $0.category == .snack }
    }
}
