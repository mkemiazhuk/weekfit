import Foundation

enum OpenFoodFactsBarcodeProvider {
    static let userAgent = "WeekFit/1.0 (iOS; https://weekfit.app)"

    static let productFields = [
        "product_name",
        "brands",
        "nutriments",
        "serving_size",
        "serving_quantity",
        "quantity",
        "image_front_url",
        "image_url"
    ].joined(separator: ",")

    static func fetch(barcode: String, session: URLSession) async throws -> BarcodeFoodLookupResult {
        let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encodedBarcode).json?fields=\(productFields)") else {
            throw BarcodeLookupError.notFound
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

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

        if http.statusCode == 503 || http.statusCode == 429 {
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
            let apiStatus = json["status"] as? Int,
            apiStatus == 1,
            let product = json["product"] as? [String: Any]
        else {
            return nil
        }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let name = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = (product["brands"] as? String)?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let calories = BarcodeNutrientParsing.intValue(from: nutriments, keys: ["energy-kcal_100g"])
            ?? BarcodeNutrientParsing.kcalFromKilojoules(
                BarcodeNutrientParsing.intValue(from: nutriments, keys: ["energy-kj_100g", "energy_100g"])
            )
        let protein = BarcodeNutrientParsing.intValue(from: nutriments, keys: ["proteins_100g"])
        let carbs = BarcodeNutrientParsing.intValue(from: nutriments, keys: ["carbohydrates_100g"])
        let fats = BarcodeNutrientParsing.intValue(from: nutriments, keys: ["fat_100g"])
        let fiber = BarcodeNutrientParsing.intValue(from: nutriments, keys: ["fiber_100g", "fibers_100g"])

        let packageGrams = resolvePackageGrams(from: product)
        let hasNutrients = [calories, protein, carbs, fats, fiber].contains { ($0 ?? 0) > 0 }

        let status: BarcodeFoodLookupResult.Status
        if hasNutrients {
            status = .found
        } else if (name?.isEmpty == false) || productImageURL(from: product) != nil {
            status = .partial
        } else {
            return nil
        }

        return BarcodeFoodLookupResult(
            status: status,
            provider: .openFoodFacts,
            barcode: barcode,
            name: name?.isEmpty == false ? name : nil,
            brand: brand?.isEmpty == false ? brand : nil,
            servingGrams: 100,
            basis: .per100g,
            packageGrams: packageGrams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            productImageURL: productImageURL(from: product)
        )
    }

    private static func resolvePackageGrams(from product: [String: Any]) -> Int? {
        if let servingQuantity = product["serving_quantity"] {
            if let value = servingQuantity as? Double {
                return max(1, Int(value.rounded()))
            }
            if let value = servingQuantity as? Int {
                return max(1, value)
            }
            if let value = servingQuantity as? String, let doubleValue = Double(value) {
                return max(1, Int(doubleValue.rounded()))
            }
        }

        if let grams = BarcodeNutrientParsing.parseGrams(from: product["serving_size"] as? String) {
            return grams
        }

        return BarcodeNutrientParsing.parseGrams(from: product["quantity"] as? String)
    }

    private static func productImageURL(from product: [String: Any]) -> URL? {
        let candidates = [
            product["image_front_url"] as? String,
            product["image_url"] as? String
        ]

        for candidate in candidates {
            guard let candidate, !candidate.isEmpty else { continue }
            let fullSizeURL = fullSizeImageURL(from: candidate)
            if let url = URL(string: fullSizeURL) {
                return url
            }
        }

        return nil
    }

    private static func fullSizeImageURL(from urlString: String) -> String {
        if urlString.contains(".full.jpg") {
            return urlString
        }

        if urlString.hasSuffix(".400.jpg") {
            return urlString.replacingOccurrences(of: ".400.jpg", with: ".full.jpg")
        }

        if urlString.hasSuffix(".200.jpg") {
            return urlString.replacingOccurrences(of: ".200.jpg", with: ".full.jpg")
        }

        return urlString
    }
}
