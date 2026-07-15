import Foundation

actor BarcodeProductCache {
    static let shared = BarcodeProductCache()

    private let fileURL: URL
    private var entries: [String: CachedBarcodeProduct] = [:]
    private var didLoad = false

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = directory.appendingPathComponent("BarcodeLookup", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("products.json")
    }

    func lookup(barcode: String) -> BarcodeFoodLookupResult? {
        loadIfNeeded()
        guard let normalized = BarcodeNormalization.gtin13(from: barcode) else { return nil }
        return entries[normalized]?.asLookupResult()
    }

    func store(_ result: BarcodeFoodLookupResult) {
        guard let barcode = result.barcode, let normalized = BarcodeNormalization.gtin13(from: barcode) else {
            return
        }

        guard result.status == .found || result.status == .partial else { return }

        loadIfNeeded()

        var cached = CachedBarcodeProduct(from: result)
        if result.provider == .openFoodFacts {
            cached = CachedBarcodeProduct(
                barcode: normalized,
                source: .openFoodFactsCache,
                name: result.name,
                brand: result.brand,
                servingGrams: result.servingGrams,
                basis: result.basis,
                packageGrams: result.packageGrams,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fats: result.fats,
                fiber: result.fiber,
                productImageURLString: result.productImageURL?.absoluteString,
                fetchedAt: Date()
            )
        }

        entries[normalized] = cached
        persist()
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([String: CachedBarcodeProduct].self, from: data)
        else {
            entries = [:]
            return
        }

        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

private extension CachedBarcodeProduct {
    init(
        barcode: String,
        source: NutritionDataSource,
        name: String?,
        brand: String?,
        servingGrams: Int,
        basis: BarcodeNutritionBasis,
        packageGrams: Int?,
        calories: Int?,
        protein: Int?,
        carbs: Int?,
        fats: Int?,
        fiber: Int?,
        productImageURLString: String?,
        fetchedAt: Date
    ) {
        self.barcode = barcode
        self.source = source
        self.name = name
        self.brand = brand
        self.servingGrams = servingGrams
        self.basis = basis
        self.packageGrams = packageGrams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.productImageURLString = productImageURLString
        self.fetchedAt = fetchedAt
    }
}
