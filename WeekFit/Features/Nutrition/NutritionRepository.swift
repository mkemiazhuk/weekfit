import Foundation

final class NutritionRepository {

    func loadMeals() -> [Meals] {
        guard let url = Bundle.main.url(forResource: "meals", withExtension: "json") else {
            print("meals.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Meals].self, from: data)
        } catch {
            print("Failed to decode meals.json:", error)
            return []
        }
    }
}
