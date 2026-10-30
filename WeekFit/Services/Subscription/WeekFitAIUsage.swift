import Foundation
import StoreKit
internal import Combine

/// Coordinated release switch. Absent in existing builds: production behavior is unchanged.
nonisolated enum WeekFitAIBilling {
    static var enabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "WeekFitAIUsageEnabled") as? Bool == true
    }
    static let products = ["com.weekfit.topup.photos20", "com.weekfit.topup.photos50",
                           "com.weekfit.topup.voice15", "com.weekfit.topup.voice30"]
    static func isTopUp(_ id: String) -> Bool { products.contains(id) }
}

nonisolated struct WeekFitAIUsage: Decodable, Sendable {
    struct Balance: Decodable, Sendable {
        let included: Int
        let purchased: Int
        var total: Int { included + purchased }
    }
    let appAccountToken: UUID
    let active: Bool
    let productId: String
    let periodStart: Double
    let periodEnd: Double
    let grandfatheredPhotos: Bool
    let photos: Balance
    let voice: Balance
    var resetDate: Date { Date(timeIntervalSince1970: periodEnd / 1000) }
}

nonisolated enum WeekFitAIUsageError: Error, LocalizedError {
    case subscriptionRequired, quotaExhausted, unavailable, pending, verification
    var errorDescription: String? {
        switch self {
        case .subscriptionRequired: WeekFitLocalizedString("ai.usage.subscriptionRequired")
        case .quotaExhausted: WeekFitLocalizedString("ai.usage.exhausted")
        case .pending: WeekFitLocalizedString("ai.usage.pending")
        case .verification: WeekFitLocalizedString("ai.usage.verification")
        case .unavailable: WeekFitLocalizedString("ai.usage.unavailable")
        }
    }
}

/// Server looks up live subscription status (including grace) with Apple. The JWS is
/// also a durable wallet recovery proof, even when its period has expired.
nonisolated enum WeekFitAIProof {
    static func subscriptionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               WeekFitSubscriptionProductID(rawValue: tx.productID) != nil {
                return result.jwsRepresentation
            }
        }
        for await result in Transaction.all {
            if case .verified(let tx) = result,
               WeekFitSubscriptionProductID(rawValue: tx.productID) != nil {
                return result.jwsRepresentation
            }
        }
        return nil
    }
}

nonisolated struct WeekFitAIClient {
    var baseURL: URL = WeekFitCloudAPI.foodPhotoBaseURL
    var session: URLSession = .shared

    func request<Response: Decodable>(path: String, method: String = "POST", body: Data? = nil,
                                     idempotencyKey: String? = nil) async throws -> Response {
        guard let proof = await WeekFitAIProof.subscriptionJWS() else { throw WeekFitAIUsageError.subscriptionRequired }
        func perform(refresh: Bool) async throws -> (Data, URLResponse) {
            let token = try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: refresh)
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = method
            request.timeoutInterval = 180
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(proof, forHTTPHeaderField: WeekFitPaidSubscriptionProof.httpHeaderName)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
            request.httpBody = body
            return try await session.data(for: request)
        }
        var (data, response) = try await perform(refresh: false)
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            (data, response) = try await perform(refresh: true)
        }
        guard let http = response as? HTTPURLResponse else { throw WeekFitAIUsageError.unavailable }
        let code = (try? JSONDecoder().decode(WeekFitAIErrorBody.self, from: data))?.error
        if http.statusCode == 402 { throw WeekFitAIUsageError.subscriptionRequired }
        if code == "quota_exhausted" { throw WeekFitAIUsageError.quotaExhausted }
        guard (200...299).contains(http.statusCode) else { throw WeekFitAIUsageError.unavailable }
        return try JSONDecoder().decode(Response.self, from: data)
    }
    func usage() async throws -> WeekFitAIUsage {
        try await request(path: "v2/ai/usage", method: "GET")
    }
    func deliver(_ jws: String) async throws -> WeekFitAIUsage {
        try await request(path: "v2/ai/purchases", body: JSONEncoder().encode(["signedTransaction": jws]))
    }
}
private nonisolated struct WeekFitAIErrorBody: Decodable { let error: String }

@MainActor
final class WeekFitAIUsageStore: ObservableObject {
    @Published private(set) var usage: WeekFitAIUsage?
    @Published private(set) var products: [Product] = []
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    private var refreshing = false

    func refresh() async {
        guard WeekFitAIBilling.enabled, !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            // Pending consumables must be delivered after a network failure or app termination.
            for await result in Transaction.unfinished {
                if case .verified(let tx) = result, WeekFitAIBilling.isTopUp(tx.productID) {
                    _ = try await WeekFitAIClient().deliver(result.jwsRepresentation)
                    await tx.finish()
                }
            }
            usage = try await WeekFitAIClient().usage()
            products = try await Product.products(for: WeekFitAIBilling.products)
                .filter { $0.type == .consumable }.sorted { $0.price < $1.price }
            message = nil
        } catch { message = error.localizedDescription }
    }

    func buy(_ product: Product) async {
        guard !isBusy, let usage, usage.active else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase(options: [.appAccountToken(usage.appAccountToken)]) {
            case .success(let result):
                guard case .verified(let tx) = result else { throw WeekFitAIUsageError.verification }
                self.usage = try await WeekFitAIClient().deliver(result.jwsRepresentation)
                // Never finish a paid consumable until the durable server acknowledges it.
                await tx.finish()
                message = nil
            case .pending: throw WeekFitAIUsageError.pending
            case .userCancelled: break
            @unknown default: throw WeekFitAIUsageError.unavailable
            }
        } catch { message = error.localizedDescription }
    }
}
