import Foundation

/// Wire models for `POST /v1/food/photo-recognize` (Render / GHCR image).
/// Nutrient fields on items are for the estimated portion, not per 100 g.

struct PhotoFoodRecognizeRequest: Encodable, Sendable, Equatable {
    let imageBase64: String
    let mimeType: String
    let locale: String
    let note: String?
}

struct PhotoFoodAPIResponse: Codable, Sendable, Equatable {
    let isFood: Bool
    let name: String
    let items: [PhotoFoodAPIItem]
    let uncertainties: [String]
    let clarificationQuestion: String?
    let totals: PhotoFoodAPITotals
    let nutritionSource: String
    let estimated: Bool
    let requiresConfirmation: Bool
    let model: String?
    let requestId: String?

    struct PhotoFoodAPIItem: Codable, Sendable, Equatable {
        let name: String
        let preparation: String?
        let grams: Double
        let minGrams: Double?
        let maxGrams: Double?
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let assumptions: [String]?
    }

    struct PhotoFoodAPITotals: Codable, Sendable, Equatable {
        let grams: Double?
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}

struct PhotoFoodAPIErrorBody: Codable, Sendable, Equatable {
    let error: String?
    let requestId: String?
    /// Legacy local-proxy shape.
    let code: String?
    let message: String?
}

enum PhotoFoodAPIMapper {
    /// Converts portion nutrients → per-100g density so gram edits scale locally.
    static func components(from response: PhotoFoodAPIResponse) throws -> [PhotoFoodComponent] {
        guard response.isFood else {
            throw PhotoFoodRecognitionError.noFoodDetected
        }
        // Backend labels all nutrients `ai_estimate` — never treat as database-backed.
        _ = response.nutritionSource
        _ = response.estimated

        var built: [PhotoFoodComponent] = []
        for (index, item) in response.items.enumerated() {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            guard item.grams.isFinite, item.grams > 0, item.grams <= 5000 else {
                throw PhotoFoodRecognitionError.invalidResponse
            }
            let scale = 100.0 / item.grams
            built.append(
                PhotoFoodComponent(
                    id: "api_\(index)_\(name.hashValue)",
                    displayName: name,
                    grams: item.grams,
                    catalogIngredientId: nil,
                    preparation: item.preparation,
                    caloriesPer100g: item.calories * scale,
                    proteinPer100g: item.protein * scale,
                    carbsPer100g: item.carbs * scale,
                    fatsPer100g: item.fat * scale,
                    fiberPer100g: 0,
                    nutritionSource: .photoAIEstimate,
                    isAIEstimated: true
                )
            )
        }
        guard !built.isEmpty else {
            throw PhotoFoodRecognitionError.noFoodDetected
        }
        return built
    }

    static func mapHTTPStatus(_ status: Int, body: PhotoFoodAPIErrorBody?) -> PhotoFoodRecognitionError {
        let code = (body?.error ?? body?.code ?? "").lowercased()
        switch status {
        case 401:
            return .unauthorized
        case 402, 403:
            if code.contains("subscription") || code.contains("paid") || status == 402 {
                return .subscriptionRequired
            }
            return .unauthorized
        case 413:
            return .imageTooLarge
        case 422:
            if code.contains("no_food") || code.contains("refuse") {
                return .noFoodDetected
            }
            return .noFoodDetected
        case 429:
            return .rateLimited
        case 502:
            return .providerFailure
        case 503:
            if code.contains("not_configured") {
                return .notConfigured
            }
            // server_busy / queue full — clear UX, no automatic retry loop.
            return .unavailable
        case 504:
            return .timedOut
        case 408:
            return .timedOut
        case 409:
            // Same Idempotency-Key with a different photo payload.
            return .invalidImage
        case 400:
            if code.contains("no_food") {
                return .noFoodDetected
            }
            return .invalidImage
        default:
            return .server(code.isEmpty ? "status_\(status)" : code)
        }
    }
}
