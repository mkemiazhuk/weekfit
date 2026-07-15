import Foundation

enum NutritionDataSource: String, Codable, Sendable, Equatable {
    case openFoodFacts
    case openFoodFactsCache
    case usda
    case nutritionLabelOCR
    case manual
}

enum BarcodeNutritionBasis: String, Codable, Sendable, Equatable {
    case per100g
    case perServing
}

struct BarcodeFoodLookupResult: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        case found
        case partial
        case notFound
        case offline
    }

    let status: Status
    let provider: NutritionDataSource?
    let barcode: String?
    let name: String?
    let brand: String?
    let servingGrams: Int
    let basis: BarcodeNutritionBasis
    let packageGrams: Int?
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fats: Int?
    let fiber: Int?
    let productImageURL: URL?

    var hasAnyNutrient: Bool {
        [calories, protein, carbs, fats, fiber].contains { ($0 ?? 0) > 0 }
    }

    var displayName: String? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (trimmedBrand?.isEmpty == false, trimmedName?.isEmpty == false) {
        case (true, true):
            return "\(trimmedBrand!) — \(trimmedName!)"
        case (false, true):
            return trimmedName
        case (true, false):
            return trimmedBrand
        default:
            return nil
        }
    }
}

enum BarcodeLookupError: Error, Sendable, Equatable {
    case notFound
    case offline
    case incompleteNutrition
}

struct CachedBarcodeProduct: Codable, Sendable, Equatable {
    let barcode: String
    let source: NutritionDataSource
    let name: String?
    let brand: String?
    let servingGrams: Int
    let basis: BarcodeNutritionBasis
    let packageGrams: Int?
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fats: Int?
    let fiber: Int?
    let productImageURLString: String?
    let fetchedAt: Date

    init(from result: BarcodeFoodLookupResult, fetchedAt: Date = Date()) {
        barcode = result.barcode ?? ""
        source = result.provider ?? .openFoodFacts
        name = result.name
        brand = result.brand
        servingGrams = result.servingGrams
        basis = result.basis
        packageGrams = result.packageGrams
        calories = result.calories
        protein = result.protein
        carbs = result.carbs
        fats = result.fats
        fiber = result.fiber
        productImageURLString = result.productImageURL?.absoluteString
        self.fetchedAt = fetchedAt
    }

    func asLookupResult() -> BarcodeFoodLookupResult {
        BarcodeFoodLookupResult(
            status: hasAnyNutrient ? .found : .partial,
            provider: source == .openFoodFactsCache ? .openFoodFactsCache : source,
            barcode: barcode,
            name: name,
            brand: brand,
            servingGrams: servingGrams,
            basis: basis,
            packageGrams: packageGrams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            productImageURL: productImageURLString.flatMap(URL.init(string:))
        )
    }

    private var hasAnyNutrient: Bool {
        [calories, protein, carbs, fats, fiber].contains { ($0 ?? 0) > 0 }
    }
}

enum BarcodeNormalization {
    static func digits(from raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func gtin13(from raw: String) -> String? {
        let digits = digits(from: raw)
        guard !digits.isEmpty else { return nil }

        switch digits.count {
        case ...8:
            return String(repeating: "0", count: 13 - digits.count) + digits
        case 9...12:
            return String(repeating: "0", count: 13 - digits.count) + digits
        case 13:
            return digits
        case 14 where digits.hasPrefix("0"):
            return String(digits.dropFirst())
        default:
            return digits.count > 13 ? String(digits.suffix(13)) : digits
        }
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = gtin13(from: lhs), let right = gtin13(from: rhs) else {
            return digits(from: lhs) == digits(from: rhs)
        }
        return left == right
    }
}

enum BarcodeNutrientParsing {
    static func intValue(from nutriments: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = nutriments[key] as? Double {
                return Int(value.rounded())
            }
            if let value = nutriments[key] as? Int {
                return value
            }
            if let value = nutriments[key] as? String, let doubleValue = Double(value) {
                return Int(doubleValue.rounded())
            }
        }
        return nil
    }

    static func kcalFromKilojoules(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return Int((Double(value) / 4.184).rounded())
    }

    static func parseGrams(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|г|гр)\b"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(
                in: raw,
                options: [],
                range: NSRange(raw.startIndex..<raw.endIndex, in: raw)
            ),
            match.numberOfRanges > 1,
            let numberRange = Range(match.range(at: 1), in: raw)
        else {
            return nil
        }

        let token = raw[numberRange].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(token) else { return nil }
        return max(1, Int(value.rounded()))
    }
}
