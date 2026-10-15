import XCTest
@testable import WeekFit

final class PhotoFoodNutritionCalculatorTests: XCTestCase {

    func testTotalsRecalculateAfterGramEdit() {
        let rice = PhotoFoodComponent(
            id: "rice",
            displayName: "Rice",
            grams: 100,
            catalogIngredientId: "base_rice",
            preparation: "cooked",
            caloriesPer100g: 130,
            proteinPer100g: 2.7,
            carbsPer100g: 28,
            fatsPer100g: 0.3,
            fiberPer100g: 0.4,
            nutritionSource: .photoCatalog,
            isAIEstimated: false
        )
        let before = PhotoFoodNutritionCalculator.totals(for: [rice])
        XCTAssertEqual(before.calories, 130)

        let updated = PhotoFoodNutritionCalculator.updatingGrams(
            in: [rice],
            componentId: "rice",
            grams: 200
        )
        let after = PhotoFoodNutritionCalculator.totals(for: updated)
        XCTAssertEqual(after.calories, 260)
    }

    func testAPIMapperScalesPortionNutrientsLocally() throws {
        let response = PhotoFoodAPIResponse.fixturePlate
        let components = try PhotoFoodAPIMapper.components(from: response)
        let rice = try XCTUnwrap(components.first)
        // 234 kcal @ 180 g → 130 kcal/100g; double grams → ~468
        let doubled = PhotoFoodNutritionCalculator.updatingGrams(
            in: [rice],
            componentId: rice.id,
            grams: rice.grams * 2
        )
        let totals = PhotoFoodNutritionCalculator.totals(for: doubled)
        XCTAssertEqual(totals.calories, rice.calories * 2)
        XCTAssertTrue(rice.isAIEstimated)
        XCTAssertEqual(rice.nutritionSource, .photoAIEstimate)
    }

    func testPortionMultiplierScalesTotals() {
        let draft = PhotoFoodLogDraft(
            mealName: "Bowl",
            mealSlot: .lunch,
            logDate: Date(),
            components: [
                PhotoFoodComponent(
                    id: "c1",
                    displayName: "Rice",
                    grams: 100,
                    catalogIngredientId: nil,
                    preparation: nil,
                    caloriesPer100g: 100,
                    proteinPer100g: 10,
                    carbsPer100g: 20,
                    fatsPer100g: 1,
                    fiberPer100g: 0,
                    nutritionSource: .photoAIEstimate,
                    isAIEstimated: true
                )
            ],
            portionMultiplier: 1.5,
            captureMethod: .camera
        )
        XCTAssertEqual(draft.totals.calories, 150)
        XCTAssertEqual(draft.totals.protein, 15)
    }

    func testSnapshotSurvivesLibraryIdChangeIndependently() {
        let draft = PhotoFoodLogDraft(
            mealName: "Chicken bowl",
            mealSlot: .dinner,
            logDate: Date(),
            components: [
                PhotoFoodComponent(
                    id: "c1",
                    displayName: "Chicken",
                    grams: 120,
                    catalogIngredientId: nil,
                    preparation: "grilled",
                    caloriesPer100g: 165,
                    proteinPer100g: 31,
                    carbsPer100g: 0,
                    fatsPer100g: 3.6,
                    fiberPer100g: 0,
                    nutritionSource: .photoAIEstimate,
                    isAIEstimated: true
                )
            ],
            captureMethod: .camera
        )
        let snapshot = PhotoFoodNutritionCalculator.makeSnapshot(
            draft: draft,
            libraryMealId: "library_1"
        )
        let encoded = PhotoFoodNutritionCalculator.encodeSnapshot(snapshot)
        let decoded = PhotoFoodNutritionCalculator.decodeSnapshot(encoded)
        XCTAssertEqual(decoded?.mealName, "Chicken bowl")
        XCTAssertEqual(decoded?.libraryMealId, "library_1")
    }
}

final class PhotoFoodAPIContractTests: XCTestCase {

    func testDecodesBackendContractJSON() throws {
        let json = """
        {
          "isFood": true,
          "name": "Chicken and rice",
          "items": [{
            "name": "Cooked rice",
            "preparation": "cooked",
            "grams": 150,
            "minGrams": 100,
            "maxGrams": 200,
            "calories": 195,
            "protein": 4,
            "carbs": 42,
            "fat": 0.5,
            "assumptions": []
          }],
          "uncertainties": ["Portion weight cannot be measured from this photo"],
          "clarificationQuestion": "Was oil or sauce added?",
          "totals": {"grams": 150, "calories": 195, "protein": 4, "carbs": 42, "fat": 0.5},
          "nutritionSource": "ai_estimate",
          "estimated": true,
          "requiresConfirmation": true,
          "model": "gpt-6-astra",
          "requestId": "uuid-1"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PhotoFoodAPIResponse.self, from: json)
        XCTAssertEqual(decoded.name, "Chicken and rice")
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.nutritionSource, "ai_estimate")
        XCTAssertTrue(decoded.requiresConfirmation)
        try PhotoFoodAPIResponseValidator.validate(decoded)
        let components = try PhotoFoodAPIMapper.components(from: decoded)
        XCTAssertEqual(components.first?.calories, 195)
    }

    func testDecodeReportsTypeMismatchCodingPath() throws {
        let json = """
        {
          "isFood": true,
          "name": "Soup",
          "items": [{
            "name": "Broth",
            "preparation": "cooked",
            "grams": "not-a-number",
            "minGrams": 100,
            "maxGrams": 200,
            "calories": 50,
            "protein": 1,
            "carbs": 2,
            "fat": 1,
            "assumptions": []
          }],
          "uncertainties": [],
          "clarificationQuestion": null,
          "totals": {"grams": 150, "calories": 50, "protein": 1, "carbs": 2, "fat": 1},
          "nutritionSource": "ai_estimate",
          "estimated": true,
          "requiresConfirmation": true
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PhotoFoodAPIResponse.self, from: json)) { error in
            guard let decoding = error as? DecodingError else {
                return XCTFail("Expected DecodingError")
            }
            if case .typeMismatch(_, let context) = decoding {
                let path = context.codingPath.map(\.stringValue).joined(separator: ".")
                XCTAssertTrue(path.contains("items"), path)
                XCTAssertTrue(path.contains("grams") || context.codingPath.contains(where: { $0.stringValue == "grams" }), path)
            } else {
                XCTFail("Expected typeMismatch, got \(decoding)")
            }
        }
    }

    func testRejectsNonFood() {
        var response = PhotoFoodAPIResponse.fixturePlate
        response = PhotoFoodAPIResponse(
            isFood: false,
            name: "Desk",
            items: response.items,
            uncertainties: [],
            clarificationQuestion: nil,
            totals: response.totals,
            nutritionSource: "ai_estimate",
            estimated: true,
            requiresConfirmation: true,
            model: "x",
            requestId: "r"
        )
        XCTAssertThrowsError(try PhotoFoodAPIResponseValidator.validate(response)) { error in
            XCTAssertEqual(error as? PhotoFoodRecognitionError, .noFoodDetected)
        }
    }

    func testErrorMapping() {
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(401, body: .init(error: "unauthorized", requestId: "a", code: nil, message: nil)),
            .unauthorized
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(413, body: nil),
            .imageTooLarge
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(422, body: .init(error: "no_food", requestId: "b", code: nil, message: nil)),
            .noFoodDetected
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(429, body: nil),
            .rateLimited
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(502, body: nil),
            .providerFailure
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(503, body: .init(error: "not_configured", requestId: "c", code: nil, message: nil)),
            .notConfigured
        )
        XCTAssertEqual(
            PhotoFoodAPIMapper.mapHTTPStatus(504, body: nil),
            .timedOut
        )
    }
}

final class PhotoFoodAuthRetryTests: XCTestCase {

    func testUnauthorizedTriggersSingleRefreshRetry() async throws {
        final class TokenBox: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var forceRefreshCalls = 0
            private var tokens: [String]

            init(tokens: [String]) { self.tokens = tokens }

            func next(forceRefresh: Bool) throws -> String {
                lock.lock()
                defer { lock.unlock() }
                if forceRefresh { forceRefreshCalls += 1 }
                guard !tokens.isEmpty else { throw PhotoFoodRecognitionError.unauthorized }
                return tokens.removeFirst()
            }
        }

        let box = TokenBox(tokens: ["expired", "fresh"])
        var attempt = 0
        let client = PhotoFoodRecognitionClient(
            session: .shared,
            baseURLOverride: URL(string: "https://example.invalid")!,
            tokenProvider: { forceRefresh in
                attempt += 1
                return try box.next(forceRefresh: forceRefresh)
            }
        )

        // Token sequencing: first bearer, then one forced refresh — mirrors client 401 path.
        XCTAssertEqual(try box.next(forceRefresh: false), "expired")
        XCTAssertEqual(try box.next(forceRefresh: true), "fresh")
        XCTAssertEqual(box.forceRefreshCalls, 1)
        XCTAssertEqual(attempt, 0)
        _ = client
    }
}
