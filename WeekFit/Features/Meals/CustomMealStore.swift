import Foundation
import CoreImage
import UIKit

enum CustomMealStore {
    static let storageKey = "weekfit_custom_meals_v1"

    static func load(from storage: String) -> [Meals] {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Meals].self, from: data) else {
            return []
        }

        return decoded
    }

    static func encode(_ meals: [Meals]) -> String {
        guard let data = try? JSONEncoder().encode(meals) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func hasDuplicateTitle(
        _ title: String,
        in meals: [Meals],
        excludingID: String? = nil
    ) -> Bool {
        let normalized = normalizedTitle(title)
        guard !normalized.isEmpty else { return false }

        return meals.contains { meal in
            meal.id != excludingID && normalizedTitle(meal.title) == normalized
        }
    }

    static func upsert(_ meal: Meals, into meals: [Meals]) -> [Meals] {
        var updated = meals

        if let index = updated.firstIndex(where: { $0.id == meal.id }) {
            updated[index] = meal
        } else {
            updated.append(meal)
        }

        return updated
    }

    static func remove(_ meal: Meals, from meals: [Meals]) -> [Meals] {
        meals.filter { $0.id != meal.id }
    }

    static func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

enum CustomIngredientStore {
    static let storageKey = "weekfit_custom_ingredients_v1"

    static func load(from storage: String) -> [MealBuilderIngredient] {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([MealBuilderIngredient].self, from: data) else {
            return []
        }

        return decoded
    }

    static func encode(_ ingredients: [MealBuilderIngredient]) -> String {
        guard let data = try? JSONEncoder().encode(ingredients) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func hasDuplicateTitle(
        _ title: String,
        in ingredients: [MealBuilderIngredient]
    ) -> Bool {
        let normalized = CustomMealStore.normalizedTitle(title)
        guard !normalized.isEmpty else { return false }

        return ingredients.contains {
            CustomMealStore.normalizedTitle($0.title) == normalized
        }
    }
}

struct CustomMealFormInput {
    var name: String
    var servingGrams: Int
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int
}

enum CustomMealValidation {
    static let maximumServingGrams = 5_000
    static let maximumNutritionValue = 20_000

    static func validationMessage(
        for input: CustomMealFormInput,
        existingMeals: [Meals],
        excludingID: String? = nil
    ) -> String? {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty {
            return WeekFitLocalizedString("meals.addANameBeforeSaving")
        }

        if input.servingGrams <= 0 || input.servingGrams > maximumServingGrams {
            return String(
                format: WeekFitLocalizedString("meals.servingSizeMustBeBetween1gAndLldg"),
                maximumServingGrams
            )
        }

        let values = [
            input.calories,
            input.protein,
            input.carbs,
            input.fats,
            input.fiber
        ]

        if values.contains(where: { $0 < 0 }) {
            return WeekFitLocalizedString("meals.nutritionValuesCannotBeNegative")
        }

        if values.contains(where: { $0 > maximumNutritionValue }) {
            return WeekFitLocalizedString("meals.nutritionValuesAreTooHigh")
        }

        if values.allSatisfy({ $0 == 0 }) {
            return WeekFitLocalizedString("meals.addAtLeastOneNutritionValue")
        }

        if CustomMealStore.hasDuplicateTitle(name, in: existingMeals, excludingID: excludingID) {
            return WeekFitLocalizedString("meals.aSavedItemWithThisNameAlreadyExists")
        }

        return nil
    }
}

enum MealPhotoStore {
    static let directoryName = "MealPhotos"
    static let thumbnailPixelSize: CGFloat = 512
    private static let imageCache = NSCache<NSString, UIImage>()
    private static let thumbnailCIContext = CIContext(options: nil)

    struct PhotoSet {
        let originalFilename: String
        let thumbnailFilename: String
    }

    static func save(_ image: UIImage) throws -> String {
        try save(image, filenamePrefix: "photo", compressionQuality: 0.82)
    }

    static func savePhotoSet(_ image: UIImage) throws -> PhotoSet {
        let normalized = image.normalizedForPhotoStorage()
        let originalFilename = try save(
            normalized,
            filenamePrefix: "original",
            compressionQuality: 0.88
        )

        do {
            let thumbnail = thumbnailImage(from: normalized, sideLength: thumbnailPixelSize)
            let thumbnailFilename = try save(
                thumbnail,
                filenamePrefix: "thumb",
                compressionQuality: 0.86
            )

            return PhotoSet(
                originalFilename: originalFilename,
                thumbnailFilename: thumbnailFilename
            )
        } catch {
            delete(filename: originalFilename)
            throw error
        }
    }

    static func thumbnailImage(from image: UIImage, sideLength: CGFloat = thumbnailPixelSize) -> UIImage {
        let normalized = image.normalizedForPhotoStorage()
        let sourceSize = normalized.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return normalized }

        let scale = max(sideLength / sourceSize.width, sideLength / sourceSize.height)
        let drawSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let drawOrigin = CGPoint(
            x: (sideLength - drawSize.width) / 2,
            y: (sideLength - drawSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let cropped = UIGraphicsImageRenderer(
            size: CGSize(width: sideLength, height: sideLength),
            format: format
        ).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: sideLength, height: sideLength))
            normalized.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }

        return subtlyEnhancedThumbnail(cropped)
    }

    static func ensureThumbnail(for meal: Meals) -> Meals {
        guard meal.isFoodProduct,
              meal.localPhotoThumbnailFilename == nil,
              let originalFilename = meal.localPhotoFilename,
              let originalImage = image(for: originalFilename) else {
            return meal
        }

        do {
            let thumbnail = thumbnailImage(from: originalImage)
            let thumbnailFilename = try save(
                thumbnail,
                filenamePrefix: "thumb",
                compressionQuality: 0.86
            )

            var updatedMeal = meal
            updatedMeal.localPhotoThumbnailFilename = thumbnailFilename
            return updatedMeal
        } catch {
            return meal
        }
    }

    static func deletePhotoSet(originalFilename: String?, thumbnailFilename: String?) {
        delete(filename: originalFilename)
        if thumbnailFilename != originalFilename {
            delete(filename: thumbnailFilename)
        }
    }

    private static func save(
        _ image: UIImage,
        filenamePrefix: String,
        compressionQuality: CGFloat
    ) throws -> String {
        try FileManager.default.createDirectory(
            at: photosDirectory,
            withIntermediateDirectories: true
        )

        let filename = "\(filenamePrefix)-\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw MealPhotoStoreError.encodingFailed
        }

        try data.write(to: url, options: [.atomic])
        imageCache.setObject(image, forKey: filename as NSString)
        return filename
    }

    static func image(for filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        let cacheKey = filename as NSString
        let start = debugStart("image filename=\(filename)")

        if let cachedImage = imageCache.object(forKey: cacheKey) {
            debugEnd("image.cacheHit filename=\(filename)", start: start)
            return cachedImage
        }

        guard let image = UIImage(contentsOfFile: url(for: filename).path) else {
            debugEnd("image.miss filename=\(filename)", start: start)
            return nil
        }

        imageCache.setObject(image, forKey: cacheKey)
        debugEnd("image.diskDecode filename=\(filename)", start: start)
        return image
    }

    static func delete(filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        imageCache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func url(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    private static var photosDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return base
            .appendingPathComponent("WeekFit", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func subtlyEnhancedThumbnail(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(input, forKey: kCIInputImageKey)
        colorControls?.setValue(1.035, forKey: kCIInputSaturationKey)
        colorControls?.setValue(1.035, forKey: kCIInputContrastKey)

        let colorOutput = colorControls?.outputImage ?? input
        let sharpen = CIFilter(name: "CISharpenLuminance")
        sharpen?.setValue(colorOutput, forKey: kCIInputImageKey)
        sharpen?.setValue(0.18, forKey: kCIInputSharpnessKey)

        let output = sharpen?.outputImage ?? colorOutput
        guard let cgImage = thumbnailCIContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        print("[MealPhotoStoreTiming] \(label) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print(String(format: "[MealPhotoStoreTiming] %@ end %.1fms", label, elapsed))
        #endif
    }
}

enum MealPhotoStoreError: Error {
    case encodingFailed
}

extension UIImage {
    func normalizedForPhotoStorage() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
