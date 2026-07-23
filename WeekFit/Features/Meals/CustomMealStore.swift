import Foundation
import CoreImage
import ImageIO
import OSLog
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

/// Per-gram nutrition density so changing serving size scales macros proportionally.
struct CustomMealNutritionDensity: Equatable {
    var caloriesPerGram: Double
    var proteinPerGram: Double
    var carbsPerGram: Double
    var fatsPerGram: Double
    var fiberPerGram: Double

    static func from(
        grams: Int,
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int,
        fiber: Int
    ) -> CustomMealNutritionDensity? {
        guard grams > 0 else { return nil }
        guard calories > 0 || protein > 0 || carbs > 0 || fats > 0 || fiber > 0 else { return nil }
        let g = Double(grams)
        return CustomMealNutritionDensity(
            caloriesPerGram: Double(calories) / g,
            proteinPerGram: Double(protein) / g,
            carbsPerGram: Double(carbs) / g,
            fatsPerGram: Double(fats) / g,
            fiberPerGram: Double(fiber) / g
        )
    }

    func scaled(toGrams grams: Int) -> (
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int,
        fiber: Int
    ) {
        let g = Double(max(grams, 0))
        return (
            calories: Int((caloriesPerGram * g).rounded()),
            protein: Int((proteinPerGram * g).rounded()),
            carbs: Int((carbsPerGram * g).rounded()),
            fats: Int((fatsPerGram * g).rounded()),
            fiber: Int((fiberPerGram * g).rounded())
        )
    }
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
    nonisolated static let directoryName = "MealPhotos"
    nonisolated static let thumbnailPixelSize: CGFloat = 384
    /// Display size for library rows (~66 pt plate); avoids caching 512 px thumbnails per row.
    nonisolated static let libraryRowPixelSize: CGFloat = 128
    /// Planner timeline row (~40 pt plate).
    nonisolated static let timelineRowPixelSize: CGFloat = 72
    /// In-form photo preview; smaller than library thumbnail to limit memory while editing.
    nonisolated static let formPreviewPixelSize: CGFloat = 256
    /// Max long edge stored for custom meal photos (avoids keeping 12 MP originals in RAM/disk).
    nonisolated static let originalMaxPixelSize: CGFloat = 1600
    nonisolated(unsafe) private static let imageCache = NSCache<NSString, UIImage>()
    nonisolated private static let cacheConfigured: Void = {
        imageCache.countLimit = 20
        imageCache.totalCostLimit = 8 * 1024 * 1024
    }()
    nonisolated private static let thumbnailCIContext = CIContext(options: [
        .cacheIntermediates: false
    ])
    nonisolated private static let inFlightLock = NSLock()
    nonisolated(unsafe) private static var inFlightLoads: [String: [(UIImage?) -> Void]] = [:]
    nonisolated private static let metadataPropertyDiagnosticsEnabled = false

    struct PhotoSet {
        let originalFilename: String
        let thumbnailFilename: String
    }

    nonisolated static func releaseMemoryCache() {
        _ = cacheConfigured
        imageCache.removeAllObjects()
    }

    nonisolated private static func storeInCache(_ image: UIImage, filename: String) {
        _ = cacheConfigured
        imageCache.setObject(image, forKey: filename as NSString, cost: estimatedBytes(for: image))
    }

    nonisolated private static func estimatedBytes(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return max(cgImage.width * cgImage.height * 4, 1)
    }

    nonisolated static func save(_ image: UIImage) throws -> String {
        try save(image, filenamePrefix: "photo", compressionQuality: 0.82)
    }

    /// Writes a full-resolution original to disk without retaining it in memory.
    nonisolated static func savePendingOriginal(_ image: UIImage) throws -> String {
        let storageImage = downsampledImage(from: image, maxPixelSize: originalMaxPixelSize)
        return try save(
            storageImage,
            filenamePrefix: "pending-original",
            compressionQuality: 0.88,
            cacheInMemory: false
        )
    }

    /// Downsample picker/camera payload without decoding the full camera bitmap.
    nonisolated static func downsampledImage(
        from data: Data,
        maxPixelSize: CGFloat = originalMaxPixelSize
    ) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    nonisolated static func downsampledImage(
        from image: UIImage,
        maxPixelSize: CGFloat = originalMaxPixelSize
    ) -> UIImage {
        let normalized = image.normalizedForPhotoStorage()
        let largestSide = max(normalized.size.width, normalized.size.height)
        guard largestSide > maxPixelSize else { return normalized }

        let scale = maxPixelSize / largestSide
        let targetSize = CGSize(
            width: max(1, normalized.size.width * scale),
            height: max(1, normalized.size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Promotes a pending original file into the permanent photo set.
    nonisolated static func promotePendingOriginal(_ pendingFilename: String) throws -> PhotoSet {
        let pendingURL = url(for: pendingFilename)
        let originalFilename = "original-\(UUID().uuidString).jpg"
        let originalURL = url(for: originalFilename)

        do {
            try FileManager.default.moveItem(at: pendingURL, to: originalURL)
        } catch {
            delete(filename: pendingFilename)
            throw error
        }

        do {
            let photoSet = try makePhotoSetFromOriginalOnDisk(originalFilename: originalFilename)
            imageCache.removeObject(forKey: originalFilename as NSString)
            imageCache.removeObject(forKey: photoSet.thumbnailFilename as NSString)
            return photoSet
        } catch {
            delete(filename: originalFilename)
            throw error
        }
    }

    nonisolated static func savePhotoSet(_ image: UIImage) throws -> PhotoSet {
        let pendingFilename = try savePendingOriginal(image)
        return try promotePendingOriginal(pendingFilename)
    }

    nonisolated private static func makePhotoSetFromOriginalOnDisk(originalFilename: String) throws -> PhotoSet {
        guard let thumbnailSource = loadDecodedImageFromDisk(
            filename: originalFilename,
            targetPixelSize: thumbnailPixelSize,
            cacheDecodedImage: false
        ) else {
            throw MealPhotoStoreError.encodingFailed
        }

        let thumbnailFilename = try save(
            thumbnailSource,
            filenamePrefix: "thumb",
            compressionQuality: 0.86,
            cacheInMemory: false
        )

        return PhotoSet(
            originalFilename: originalFilename,
            thumbnailFilename: thumbnailFilename
        )
    }

    nonisolated static func thumbnailImage(from image: UIImage, sideLength: CGFloat = thumbnailPixelSize) -> UIImage {
        let normalized = image.normalizedForPhotoStorage()
        let sourceSize = normalized.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return normalized }

        let resizeStart = debugStart("thumbnail.resize side=\(Int(sideLength))")
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
        debugEnd("thumbnail.resize side=\(Int(sideLength))", start: resizeStart)

        return subtlyEnhancedThumbnail(cropped)
    }

    static func ensureThumbnail(for meal: Meals) -> Meals {
        guard meal.isFoodProduct,
              meal.localPhotoThumbnailFilename == nil,
              let originalFilename = meal.localPhotoFilename,
              let originalImage = loadDecodedImageFromDisk(
                filename: originalFilename,
                targetPixelSize: thumbnailPixelSize
              ) else {
            return meal
        }

        do {
            let thumbnail = thumbnailImage(from: originalImage, sideLength: thumbnailPixelSize)
            let thumbnailFilename = try save(
                thumbnail,
                filenamePrefix: "thumb",
                compressionQuality: 0.86,
                cacheInMemory: false
            )

            var updatedMeal = meal
            updatedMeal.localPhotoThumbnailFilename = thumbnailFilename
            imageCache.removeObject(forKey: originalFilename as NSString)
            return updatedMeal
        } catch {
            imageCache.removeObject(forKey: originalFilename as NSString)
            return meal
        }
    }

    nonisolated static func deletePhotoSet(originalFilename: String?, thumbnailFilename: String?) {
        delete(filename: originalFilename)
        if thumbnailFilename != originalFilename {
            delete(filename: thumbnailFilename)
        }
    }

    nonisolated private static func save(
        _ image: UIImage,
        filenamePrefix: String,
        compressionQuality: CGFloat,
        cacheInMemory: Bool = false
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
        if cacheInMemory {
            storeInCache(image, filename: filename)
        }
        return filename
    }

    nonisolated static func image(for filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        return cachedImage(for: filename, label: "image")
    }

    nonisolated static func timelineImage(for filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }

        let cacheKey = "timeline:\(filename)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let image = loadDecodedImageFromDisk(
            filename: filename,
            targetPixelSize: timelineRowPixelSize,
            cacheDecodedImage: false
        ) else {
            return nil
        }

        storeInCache(image, filename: "timeline:\(filename)")
        return image
    }

    nonisolated static func cachedImage(for filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        return cachedImage(for: filename, label: "cachedImage")
    }

    nonisolated private static func cachedImage(for filename: String, label: String) -> UIImage? {
        let cacheKey = filename as NSString
        let lookupStart = debugStart("\(label).cacheLookup filename=\(filename)")

        if let cachedImage = imageCache.object(forKey: cacheKey) {
            debugEnd("\(label).cacheHit filename=\(filename)", start: lookupStart)
            return cachedImage
        }
        debugEnd("\(label).cacheMiss filename=\(filename)", start: lookupStart)

        guard !Thread.isMainThread else {
            debugLog("\(label).mainThreadDiskLoadPrevented filename=\(filename)")
            return nil
        }

        return loadDecodedImageFromDisk(filename: filename, targetPixelSize: thumbnailPixelSize)
    }

    nonisolated static func loadImage(
        for filename: String?,
        targetPixelSize: CGFloat = thumbnailPixelSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let filename, !filename.isEmpty else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        if let cachedImage = cachedImage(for: filename, label: "asyncImage") {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        inFlightLock.lock()
        if inFlightLoads[filename] != nil {
            inFlightLoads[filename]?.append(completion)
            inFlightLock.unlock()
            debugLog("asyncImage.coalesced filename=\(filename)")
            return
        }
        inFlightLoads[filename] = [completion]
        inFlightLock.unlock()

        DispatchQueue.global(qos: .utility).async {
            let image = loadDecodedImageFromDisk(filename: filename, targetPixelSize: targetPixelSize)
            let handoffStart = debugStart("asyncImage.mainActorHandoff filename=\(filename)")
            DispatchQueue.main.async {
                debugEnd("asyncImage.mainActorHandoff filename=\(filename)", start: handoffStart)

                let callbacks: [(UIImage?) -> Void]
                inFlightLock.lock()
                callbacks = inFlightLoads.removeValue(forKey: filename) ?? []
                inFlightLock.unlock()

                let completionStart = debugStart("asyncImage.completionStateUpdate filename=\(filename) callbacks=\(callbacks.count)")
                callbacks.forEach { $0(image) }
                debugEnd("asyncImage.completionStateUpdate filename=\(filename) callbacks=\(callbacks.count)", start: completionStart)
            }
        }
    }

    nonisolated static func preloadImage(
        for filename: String?,
        targetPixelSize: CGFloat = thumbnailPixelSize,
        completion: (() -> Void)? = nil
    ) {
        loadImage(for: filename, targetPixelSize: targetPixelSize) { _ in
            completion?()
        }
    }

    nonisolated static func delete(filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        imageCache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    nonisolated static func clearAllStoredPhotos() throws {
        imageCache.removeAllObjects()

        let directory = photosDirectory
        guard FileManager.default.fileExists(atPath: directory.path) else {
            #if DEBUG
            Logger(subsystem: "WeekFit", category: "LocalDataReset")
                .debug("Meal photo directory did not exist: \(directory.path, privacy: .public)")
            #endif
            return
        }

        try FileManager.default.removeItem(at: directory)
        #if DEBUG
        Logger(subsystem: "WeekFit", category: "LocalDataReset")
            .debug("Cleared meal photo directory: \(directory.path, privacy: .public)")
        #endif
    }

    nonisolated static func url(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    nonisolated private static var photosDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return base
            .appendingPathComponent("WeekFit", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    nonisolated private static func subtlyEnhancedThumbnail(_ image: UIImage) -> UIImage {
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

    nonisolated private static func loadDecodedImageFromDisk(
        filename: String,
        targetPixelSize: CGFloat,
        cacheDecodedImage: Bool = true
    ) -> UIImage? {
        let fileURL = url(for: filename)

        let attributesStart = debugStart("image.fileAttributes filename=\(filename)")
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        debugEnd("image.fileAttributes filename=\(filename) bytes=\(fileSize)", start: attributesStart)

        let readStart = debugStart("image.diskRead filename=\(filename)")
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        let sourceCreateStart = debugStart("image.metadata.sourceCreate filename=\(filename)")
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions as CFDictionary) else {
            debugEnd("image.diskRead.miss filename=\(filename)", start: readStart)
            debugEnd("image.metadata.sourceCreate.failed filename=\(filename)", start: sourceCreateStart)
            return nil
        }
        debugEnd("image.diskRead filename=\(filename)", start: readStart)
        debugEnd("image.metadata.sourceCreate filename=\(filename)", start: sourceCreateStart)

        logImageMetadataDiagnostics(
            source: source,
            filename: filename,
            fileSize: fileSize
        )

        let decodeStart = debugStart("image.downsampleDecode filename=\(filename) target=\(Int(targetPixelSize))")
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Int(targetPixelSize)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            debugEnd("image.downsampleDecode.failed filename=\(filename)", start: decodeStart)
            return nil
        }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        let outputBytes = Int64(cgImage.width * cgImage.height * 4)
        debugEnd("image.downsampleDecode filename=\(filename) width=\(cgImage.width) height=\(cgImage.height) decodedBytes=\(outputBytes)", start: decodeStart)

        let cacheInsertStart = debugStart("image.cacheInsert filename=\(filename)")
        if cacheDecodedImage && shouldCacheDecodedImage(targetPixelSize: targetPixelSize) {
            storeInCache(image, filename: filename)
        }
        debugEnd("image.cacheInsert filename=\(filename)", start: cacheInsertStart)
        return image
    }

    /// Photo persistence for meal forms — runs off the main actor to avoid UI memory spikes.
    nonisolated static func persistSavedPhotoFilenames(
        pendingOriginalFilename: String?,
        selectedImage: UIImage?,
        didRemovePhoto: Bool,
        existingOriginalFilename: String?,
        existingThumbnailFilename: String?
    ) throws -> (originalFilename: String?, thumbnailFilename: String?) {
        #if DEBUG
        MealMemoryAudit.checkpoint("photo.persist.begin")
        #endif
        defer {
            #if DEBUG
            MealMemoryAudit.checkpoint("photo.persist.end")
            #endif
        }

        if let pendingOriginalFilename {
            let photoSet = try promotePendingOriginal(pendingOriginalFilename)
            deletePhotoSet(
                originalFilename: existingOriginalFilename,
                thumbnailFilename: existingThumbnailFilename
            )
            releaseMemoryCache()
            return (photoSet.originalFilename, photoSet.thumbnailFilename)
        }

        if let selectedImage {
            let photoSet = try savePhotoSet(selectedImage)
            deletePhotoSet(
                originalFilename: existingOriginalFilename,
                thumbnailFilename: existingThumbnailFilename
            )
            releaseMemoryCache()
            return (photoSet.originalFilename, photoSet.thumbnailFilename)
        }

        if didRemovePhoto {
            deletePhotoSet(
                originalFilename: existingOriginalFilename,
                thumbnailFilename: existingThumbnailFilename
            )
            releaseMemoryCache()
            return (nil, nil)
        }

        return (existingOriginalFilename, existingThumbnailFilename)
    }

    nonisolated private static func shouldCacheDecodedImage(targetPixelSize: CGFloat) -> Bool {
        targetPixelSize >= thumbnailPixelSize
    }

    nonisolated private static func logImageMetadataDiagnostics(
        source: CGImageSource,
        filename: String,
        fileSize: Int64
    ) {
        guard metadataPropertyDiagnosticsEnabled else {
            let skippedStart = debugStart("image.metadata.propertiesSkipped filename=\(filename)")
            debugEnd("image.metadata.propertiesSkipped filename=\(filename)", start: skippedStart)
            return
        }

        let propertiesOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]

        let propertiesStart = debugStart("image.metadata.copyProperties filename=\(filename)")
        let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            propertiesOptions as CFDictionary
        ) as? [CFString: Any]
        debugEnd("image.metadata.copyProperties filename=\(filename)", start: propertiesStart)

        let exifStart = debugStart("image.metadata.exifExtraction filename=\(filename)")
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        debugEnd("image.metadata.exifExtraction filename=\(filename) hasExif=\(exif != nil)", start: exifStart)

        let orientationStart = debugStart("image.metadata.orientationExtraction filename=\(filename)")
        let orientation = properties?[kCGImagePropertyOrientation] as? Int ?? 1
        debugEnd("image.metadata.orientationExtraction filename=\(filename) orientation=\(orientation)", start: orientationStart)

        let dimensionsStart = debugStart("image.metadata.dimensionExtraction filename=\(filename)")
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        debugEnd("image.metadata.dimensionExtraction filename=\(filename) width=\(width) height=\(height)", start: dimensionsStart)

        let decodedBytesStart = debugStart("image.metadata.decodedBytesCalculation filename=\(filename)")
        let decodedBytes = Int64(width * height * 4)
        debugEnd("image.metadata.decodedBytesCalculation filename=\(filename) decodedBytes=\(decodedBytes)", start: decodedBytesStart)

        let loggingStart = debugStart("image.metadata.summaryLogging filename=\(filename)")
        debugLog("image.metadata.summary filename=\(filename) width=\(width) height=\(height) fileBytes=\(fileSize) decodedBytes=\(decodedBytes)")
        debugEnd("image.metadata.summaryLogging filename=\(filename)", start: loggingStart)
    }

    nonisolated private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        _ = label
        return CFAbsoluteTimeGetCurrent()
        #else
        return 0
        #endif
    }

    nonisolated private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        _ = label
        _ = start
        #endif
    }

    nonisolated private static func debugLog(_ message: String) {
        #if DEBUG
        _ = message
        #endif
    }

    nonisolated private static var threadLabel: String {
        Thread.isMainThread ? "main" : "background"
    }
}

enum MealPhotoStoreError: Error {
    case encodingFailed
}

extension UIImage {
    nonisolated func normalizedForPhotoStorage() -> UIImage {
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

    nonisolated func predecodedForDisplay() -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }

        let normalized = normalizedForPhotoStorage()
        let format = UIGraphicsImageRendererFormat()
        format.scale = normalized.scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: normalized.size, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: normalized.size))
        }
    }
}
