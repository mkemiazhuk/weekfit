import Foundation

enum USDAFoodDataCentralConfiguration {
    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "USDAFDCApiKey") as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        return "DEMO_KEY"
    }
}

enum USDABarcodeProvider {
    static func fetch(barcode: String, session: URLSession) async throws -> BarcodeFoodLookupResult {
        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(USDAFoodDataCentralConfiguration.apiKey)") else {
            throw BarcodeLookupError.notFound
        }

        let payload: [String: Any] = [
            "query": BarcodeNormalization.gtin13(from: barcode) ?? BarcodeNormalization.digits(from: barcode),
            "dataType": ["Branded"],
            "pageSize": 5
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as? URLError)?.code == .notConnectedToInternet {
                throw BarcodeLookupError.offline
            }
            throw BarcodeLookupError.offline
        }

        guard let http = response as? HTTPURLResponse else {
            throw BarcodeLookupError.notFound
        }

        if http.statusCode == 429 {
            throw BarcodeLookupError.offline
        }

        guard http.statusCode == 200 else {
            throw BarcodeLookupError.notFound
        }

        guard let parsed = parseResponse(data, barcode: barcode) else {
            throw BarcodeLookupError.notFound
        }
        return parsed
    }

    static func parseResponse(_ data: Data, barcode: String) -> BarcodeFoodLookupResult? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let foods = json["foods"] as? [[String: Any]]
        else {
            return nil
        }

        guard let food = foods.first(where: { matchesBarcode($0, barcode: barcode) }) ?? foods.first else {
            return nil
        }

        let nutrients = food["foodNutrients"] as? [[String: Any]] ?? []
        let calories = nutrientAmount(in: nutrients, ids: [1008], names: ["energy", "calories"])
        let protein = nutrientAmount(in: nutrients, ids: [1003], names: ["protein"])
        let carbs = nutrientAmount(in: nutrients, ids: [1005], names: ["carbohydrate"])
        let fats = nutrientAmount(in: nutrients, ids: [1004], names: ["total lipid", "fat"])
        let fiber = nutrientAmount(in: nutrients, ids: [1079], names: ["fiber"])

        guard [calories, protein, carbs, fats, fiber].contains(where: { ($0 ?? 0) > 0 }) else {
            return nil
        }

        let servingGrams = resolveServingGrams(from: food) ?? 100
        let description = (food["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = (food["brandOwner"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return BarcodeFoodLookupResult(
            status: .found,
            provider: .usda,
            barcode: barcode,
            name: description?.isEmpty == false ? description : nil,
            brand: brand?.isEmpty == false ? brand : nil,
            servingGrams: servingGrams,
            basis: .perServing,
            packageGrams: servingGrams == 100 ? nil : servingGrams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            productImageURL: nil
        )
    }

    private static func matchesBarcode(_ food: [String: Any], barcode: String) -> Bool {
        guard let gtin = food["gtinUpc"] as? String else { return false }
        return BarcodeNormalization.matches(gtin, barcode)
    }

    private static func resolveServingGrams(from food: [String: Any]) -> Int? {
        let unit = (food["servingSizeUnit"] as? String)?.lowercased() ?? ""
        guard unit.contains("g") else { return nil }

        if let servingSize = food["servingSize"] as? Double {
            return max(1, Int(servingSize.rounded()))
        }
        if let servingSize = food["servingSize"] as? Int {
            return max(1, servingSize)
        }
        if let servingSize = food["servingSize"] as? String, let value = Double(servingSize) {
            return max(1, Int(value.rounded()))
        }
        return nil
    }

    private static func nutrientAmount(
        in nutrients: [[String: Any]],
        ids: [Int],
        names: [String]
    ) -> Int? {
        for nutrient in nutrients {
            if let number = nutrient["nutrientNumber"] as? String,
               let id = Int(number),
               ids.contains(id),
               let amount = doubleValue(nutrient["value"] ?? nutrient["amount"]) {
                return Int(amount.rounded())
            }

            if let id = nutrient["nutrientId"] as? Int,
               ids.contains(id),
               let amount = doubleValue(nutrient["value"] ?? nutrient["amount"]) {
                return Int(amount.rounded())
            }

            let nutrientName = ((nutrient["nutrientName"] as? String) ?? (nutrient["name"] as? String))?
                .lowercased() ?? ""
            if names.contains(where: { nutrientName.contains($0) }),
               let amount = doubleValue(nutrient["value"] ?? nutrient["amount"]) {
                return Int(amount.rounded())
            }
        }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }
}
