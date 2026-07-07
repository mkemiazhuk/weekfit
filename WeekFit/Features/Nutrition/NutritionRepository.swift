import Foundation

final class NutritionRepository {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

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
    
    func loadQuickItems() -> [QuickItem] {

        guard let url = Bundle.main.url(
            forResource: "drinks_snacks",
            withExtension: "json"
        ) else {
            print("drinks_snacks.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [QuickItem].self,
                from: data
            )
        } catch {
            print("Failed to decode drinks_snacks.json:", error)
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
