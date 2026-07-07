import UIKit
import Vision

struct FoodPhotoNutritionEstimate: Sendable {
    enum Source: Sendable {
        case barcode
        case nutritionLabel
    }

    let source: Source
    let name: String?
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fats: Int?
    let fiber: Int?
    let productImageURL: URL?

    var hasAnyNutrient: Bool {
        [calories, protein, carbs, fats, fiber].contains { ($0 ?? 0) > 0 }
    }

    var shouldReplacePhotoWithProductImage: Bool {
        source == .barcode && productImageURL != nil
    }

    @MainActor
    func applyIfPossible(
        name: inout String,
        servingGrams: inout String,
        calories: inout String,
        protein: inout String,
        carbs: inout String,
        fats: inout String,
        fiber: inout String
    ) -> Bool {
        guard hasAnyNutrient else { return false }

        var didApply = false

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let estimateName = self.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !estimateName.isEmpty {
            name = estimateName
            didApply = true
        }

        didApply = fillField(self.calories, into: &calories) || didApply
        didApply = fillField(self.protein, into: &protein) || didApply
        didApply = fillField(self.carbs, into: &carbs) || didApply
        didApply = fillField(self.fats, into: &fats) || didApply
        didApply = fillField(self.fiber, into: &fiber) || didApply

        if didApply {
            servingGrams = "100"
        }

        return didApply
    }

    private func fillField(_ value: Int?, into field: inout String) -> Bool {
        guard let value, value > 0 else { return false }
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || Int(trimmed) == 0 else { return false }
        field = "\(value)"
        return true
    }
}

enum FoodPhotoNutritionAnalyzer {
    static func analyze(_ image: UIImage) async -> FoodPhotoNutritionEstimate? {
        guard let cgImage = image.cgImage else { return nil }

        if let barcode = await detectBarcode(in: cgImage),
           let estimate = await fetchOpenFoodFacts(barcode: barcode) {
            return estimate
        }

        if let text = await recognizeText(in: cgImage),
           let estimate = NutritionLabelTextParser.parse(text) {
            return estimate
        }

        return nil
    }

    static func downloadProductImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    static func preparedMealPhoto(from image: UIImage) -> (thumbnail: UIImage, pendingFilename: String?) {
        let storageImage = MealPhotoStore.downsampledImage(from: image)
        let thumbnail = MealPhotoStore.thumbnailImage(
            from: storageImage,
            sideLength: MealPhotoStore.formPreviewPixelSize
        )
        let pendingFilename = try? MealPhotoStore.savePendingOriginal(storageImage)
        return (thumbnail, pendingFilename)
    }

    private static func detectBarcode(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let observations = request.results as? [VNBarcodeObservation] ?? []
                let payload = observations
                    .compactMap(\.payloadStringValue)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                continuation.resume(returning: payload)
            }
            request.symbologies = [.ean13, .ean8, .upce, .code128]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func recognizeText(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func fetchOpenFoodFacts(barcode: String) async -> FoodPhotoNutritionEstimate? {
        let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encodedBarcode).json?fields=product_name,nutriments,image_front_url,image_url") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return parseOpenFoodFactsResponse(data)
        } catch {
            return nil
        }
    }

    private static func parseOpenFoodFactsResponse(_ data: Data) -> FoodPhotoNutritionEstimate? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? Int,
            status == 1,
            let product = json["product"] as? [String: Any],
            let nutriments = product["nutriments"] as? [String: Any]
        else {
            return nil
        }

        let name = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let calories = intNutrient(
            from: nutriments,
            keys: ["energy-kcal_100g", "energy-kcal"]
        ) ?? kcalFromKilojoules(intNutrient(from: nutriments, keys: ["energy_100g", "energy-kj_100g", "energy-kj"]))
        let protein = intNutrient(from: nutriments, keys: ["proteins_100g", "proteins"])
        let carbs = intNutrient(from: nutriments, keys: ["carbohydrates_100g", "carbohydrates"])
        let fats = intNutrient(from: nutriments, keys: ["fat_100g", "fat"])
        let fiber = intNutrient(from: nutriments, keys: ["fiber_100g", "fiber", "fibers_100g", "fibers"])

        let estimate = FoodPhotoNutritionEstimate(
            source: .barcode,
            name: name?.isEmpty == false ? name : nil,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            productImageURL: productImageURL(from: product)
        )
        return estimate.hasAnyNutrient ? estimate : nil
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

    private static func intNutrient(from nutriments: [String: Any], keys: [String]) -> Int? {
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

    private static func kcalFromKilojoules(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return Int((Double(value) / 4.184).rounded())
    }
}

private enum NutritionLabelTextParser {
    static func parse(_ rawText: String) -> FoodPhotoNutritionEstimate? {
        let normalized = normalize(rawText)
        guard looksLikeNutritionLabel(normalized) else { return nil }

        let per100g = containsPer100gIndicator(normalized)
        let servingGrams = extractServingGrams(from: normalized)
        let scaleFactor: Double
        if per100g {
            scaleFactor = 1
        } else if let servingGrams, servingGrams > 0 {
            scaleFactor = 100.0 / Double(servingGrams)
        } else {
            return nil
        }

        var calories = extractCalories(from: normalized)
        var protein = extractGramValue(from: normalized, keywords: ["protein", "proteins", "белки", "білки"])
        var carbs = extractGramValue(
            from: normalized,
            keywords: ["carbohydrate", "carbohydrates", "carbs", "углевод", "вуглевод"]
        )
        var fats = extractGramValue(from: normalized, keywords: ["fat", "fats", "жир", "lipides"])
        var fiber = extractGramValue(from: normalized, keywords: ["fiber", "fibre", "fibers", "клетчат", "волокн"])

        if scaleFactor != 1 {
            calories = scaleInt(calories, factor: scaleFactor)
            protein = scaleInt(protein, factor: scaleFactor)
            carbs = scaleInt(carbs, factor: scaleFactor)
            fats = scaleInt(fats, factor: scaleFactor)
            fiber = scaleInt(fiber, factor: scaleFactor)
        }

        let estimate = FoodPhotoNutritionEstimate(
            source: .nutritionLabel,
            name: nil,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            productImageURL: nil
        )
        return estimate.hasAnyNutrient ? estimate : nil
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .lowercased()
    }

    private static func looksLikeNutritionLabel(_ text: String) -> Bool {
        let hints = [
            "nutrition", "nutrient", "calor", "kcal", "ккал", "energy", "энерг",
            "protein", "белк", "carb", "углев", "вуглев", "fat", "жир"
        ]
        let matches = hints.filter { text.contains($0) }.count
        return matches >= 2
    }

    private static func containsPer100gIndicator(_ text: String) -> Bool {
        text.range(
            of: #"(?:per|на|pour|pro)\s*100\s*(?:g|gr|gram|grams|г|гр|ml|мл)"#,
            options: .regularExpression
        ) != nil
            || text.range(of: #"100\s*(?:g|gr|gram|grams|г|гр|ml|мл)"#, options: .regularExpression) != nil
    }

    private static func extractServingGrams(from text: String) -> Int? {
        let patterns = [
            #"serving(?:\s*size)?[^0-9]{0,24}(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|г|гр)"#,
            #"portion[^0-9]{0,24}(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|г|гр)"#,
            #"на\s*порцию[^0-9]{0,24}(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|г|гр)"#
        ]

        for pattern in patterns {
            if let value = firstNumber(in: text, pattern: pattern) {
                return max(1, Int(value.rounded()))
            }
        }
        return nil
    }

    private static func extractCalories(from text: String) -> Int? {
        let patterns = [
            #"(?:energy|calories|calorie|kcal|ккал|энерг)[^0-9]{0,20}(\d+(?:[.,]\d+)?)"#,
            #"(\d+(?:[.,]\d+)?)\s*(?:kcal|ккал)"#
        ]

        for pattern in patterns {
            if let value = firstNumber(in: text, pattern: pattern) {
                return Int(value.rounded())
            }
        }

        if let kilojoules = firstNumber(in: text, pattern: #"(?:kj|кдж|kilojoule)[^0-9]{0,20}(\d+(?:[.,]\d+)?)"#) {
            return Int((kilojoules / 4.184).rounded())
        }

        return nil
    }

    private static func extractGramValue(from text: String, keywords: [String]) -> Int? {
        for keyword in keywords {
            let escaped = NSRegularExpression.escapedPattern(for: keyword)
            let pattern = escaped + #"[^0-9]{0,20}(\d+(?:[.,]\d+)?)"#
            if let value = firstNumber(in: text, pattern: pattern) {
                return Int(value.rounded())
            }

            let reversePattern = #"(\d+(?:[.,]\d+)?)\s*(?:g|г|grams?|гр)[^a-zа-я]{0,12}"# + escaped
            if let value = firstNumber(in: text, pattern: reversePattern) {
                return Int(value.rounded())
            }
        }
        return nil
    }

    private static func firstNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let numberRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let token = text[numberRange].replacingOccurrences(of: ",", with: ".")
        return Double(token)
    }

    private static func scaleInt(_ value: Int?, factor: Double) -> Int? {
        guard let value else { return nil }
        return Int((Double(value) * factor).rounded())
    }
}
