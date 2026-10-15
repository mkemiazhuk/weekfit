import Foundation

enum PhotoFoodNutritionCalculator {

    static func totals(for components: [PhotoFoodComponent]) -> PhotoFoodNutritionTotals {
        components.reduce(.zero) { partial, component in
            partial + PhotoFoodNutritionTotals(
                calories: component.calories,
                protein: component.protein,
                carbs: component.carbs,
                fats: component.fats,
                fiber: component.fiber
            )
        }
    }

    static func estimateKind(for components: [PhotoFoodComponent]) -> PhotoFoodEstimateKind {
        guard !components.isEmpty else { return .estimated }
        let estimatedCount = components.filter(\.isAIEstimated).count
        if estimatedCount == 0 { return .database }
        if estimatedCount == components.count { return .estimated }
        return .mixed
    }

    /// Applies a gram edit and returns a new component list with recalculated identity preserved.
    static func updatingGrams(
        in components: [PhotoFoodComponent],
        componentId: String,
        grams: Double
    ) -> [PhotoFoodComponent] {
        components.map { component in
            guard component.id == componentId else { return component }
            var updated = component
            updated.grams = max(grams, 0)
            return updated
        }
    }

    static func makeSnapshot(
        draft: PhotoFoodLogDraft,
        libraryMealId: String?
    ) -> PhotoFoodDiarySnapshot {
        let scaled = draft.scaledComponents
        let totals = totals(for: scaled)
        return PhotoFoodDiarySnapshot(
            mealName: draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines),
            mealSlotRaw: draft.mealSlot.rawValue,
            components: scaled,
            portionMultiplier: draft.portionMultiplier,
            totals: .init(totals),
            estimateKind: estimateKind(for: scaled),
            captureMethod: draft.captureMethod.rawValue,
            libraryMealId: libraryMealId,
            loggedAt: Date()
        )
    }

    static func encodeSnapshot(_ snapshot: PhotoFoodDiarySnapshot) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeSnapshot(_ json: String?) -> PhotoFoodDiarySnapshot? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PhotoFoodDiarySnapshot.self, from: data)
    }
}
