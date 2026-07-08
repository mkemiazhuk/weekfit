import Foundation

enum NutritionCatalogError: Equatable, Error {
    case mealsFileMissing
    case mealsDecodeFailed
    case quickItemsFileMissing
    case quickItemsDecodeFailed
}

final class NutritionRepository {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    func loadMealsResult() -> Result<[Meals], NutritionCatalogError> {
        guard let url = Bundle.main.url(forResource: "meals", withExtension: "json") else {
            return .failure(.mealsFileMissing)
        }

        do {
            let data = try Data(contentsOf: url)
            return .success(try JSONDecoder().decode([Meals].self, from: data))
        } catch {
            return .failure(.mealsDecodeFailed)
        }
    }

    func loadMeals() -> [Meals] {
        switch loadMealsResult() {
        case .success(let meals):
            return meals
        case .failure:
            return []
        }
    }

    func loadQuickItemsResult() -> Result<[QuickItem], NutritionCatalogError> {
        guard let url = Bundle.main.url(
            forResource: "drinks_snacks",
            withExtension: "json"
        ) else {
            return .failure(.quickItemsFileMissing)
        }

        do {
            let data = try Data(contentsOf: url)
            return .success(try JSONDecoder().decode([QuickItem].self, from: data))
        } catch {
            return .failure(.quickItemsDecodeFailed)
        }
    }

    func loadQuickItems() -> [QuickItem] {
        switch loadQuickItemsResult() {
        case .success(let items):
            return items
        case .failure:
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
