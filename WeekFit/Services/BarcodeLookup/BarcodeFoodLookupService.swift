import Foundation

protocol BarcodeFoodLookupProviding: Sendable {
    func lookup(barcode: String) async -> BarcodeFoodLookupResult
}

struct BarcodeFoodLookupService: BarcodeFoodLookupProviding {
    private let cache: BarcodeProductCache
    private let session: URLSession

    init(
        cache: BarcodeProductCache = .shared,
        session: URLSession = BarcodeFoodLookupService.makeSession()
    ) {
        self.cache = cache
        self.session = session
    }

    func lookup(barcode: String) async -> BarcodeFoodLookupResult {
        let normalized = BarcodeNormalization.gtin13(from: barcode) ?? BarcodeNormalization.digits(from: barcode)

        if let cached = await cache.lookup(barcode: normalized) {
            return cached
        }

        var sawOffline = false

        do {
            let offResult = try await OpenFoodFactsBarcodeProvider.fetch(barcode: normalized, session: session)
            await cache.store(offResult)
            return offResult
        } catch BarcodeLookupError.offline {
            sawOffline = true
        } catch {
            sawOffline = false
        }

        do {
            let usdaResult = try await USDABarcodeProvider.fetch(barcode: normalized, session: session)
            await cache.store(usdaResult)
            return usdaResult
        } catch BarcodeLookupError.offline {
            sawOffline = true
        } catch {
            // Not found in USDA either.
        }

        if sawOffline {
            return offlineResult(barcode: normalized)
        }

        return notFoundResult(barcode: normalized)
    }

    private func offlineResult(barcode: String) -> BarcodeFoodLookupResult {
        BarcodeFoodLookupResult(
            status: .offline,
            provider: nil,
            barcode: barcode,
            name: nil,
            brand: nil,
            servingGrams: 100,
            basis: .per100g,
            packageGrams: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            fiber: nil,
            productImageURL: nil
        )
    }

    private func notFoundResult(barcode: String) -> BarcodeFoodLookupResult {
        BarcodeFoodLookupResult(
            status: .notFound,
            provider: nil,
            barcode: barcode,
            name: nil,
            brand: nil,
            servingGrams: 100,
            basis: .per100g,
            packageGrams: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            fiber: nil,
            productImageURL: nil
        )
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }
}
