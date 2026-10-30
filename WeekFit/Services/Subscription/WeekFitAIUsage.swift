import Foundation
import StoreKit
internal import Combine

/// Coordinated release switch. Absent in existing builds: production behavior is unchanged.
nonisolated enum WeekFitAIBilling {
    static var enabled: Bool {
        if WeekFitCloudAPI.sandboxBillingRequested && WeekFitCloudAPI.sandboxBillingBaseURL == nil {
            return false
        }
        return Bundle.main.object(forInfoDictionaryKey: "WeekFitAIUsageEnabled") as? Bool == true
    }
    static var environment: String { WeekFitCloudAPI.sandboxBillingRequested ? "Sandbox" : "Production" }
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

nonisolated enum WeekFitAIUsageError: Error, Equatable {
    case subscriptionRequired, quotaExhausted, unavailable, pending, verification
    var localizationKey: String {
        switch self {
        case .subscriptionRequired: "ai.usage.subscriptionRequired"
        case .quotaExhausted: "ai.usage.exhausted"
        case .pending: "ai.usage.pending"
        case .verification: "ai.usage.verification"
        case .unavailable: "ai.usage.unavailable"
        }
    }
}

@MainActor
func WeekFitAIErrorMessage(_ error: Error) -> String {
    if let error = error as? WeekFitAIUsageError { return WeekFitLocalizedString(error.localizationKey) }
    return WeekFitLocalizedString("ai.usage.unavailable")
}

/// Server looks up live subscription status (including grace) with Apple. The JWS is
/// also a durable wallet recovery proof, even when its period has expired.
nonisolated enum WeekFitAIProof {
    static func subscriptionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               ["com.weekfit.subscription.monthly", "com.weekfit.subscription.annual"].contains(tx.productID) {
                return result.jwsRepresentation
            }
        }
        for await result in Transaction.all {
            if case .verified(let tx) = result,
               ["com.weekfit.subscription.monthly", "com.weekfit.subscription.annual"].contains(tx.productID) {
                return result.jwsRepresentation
            }
        }
        return nil
    }
}

nonisolated struct WeekFitAIClient: Sendable {
    var baseURL: URL? = nil
    var session: URLSession = .shared

    func request<Response: Decodable>(path: String, method: String = "POST", body: Data? = nil,
                                     idempotencyKey: String? = nil, requiresProof: Bool = true) async throws -> Response {
        let origin = await MainActor.run { baseURL ?? WeekFitCloudAPI.foodPhotoBaseURL }
        let proof = await WeekFitAIProof.subscriptionJWS()
        if requiresProof && proof == nil { throw WeekFitAIUsageError.subscriptionRequired }
        func perform(refresh: Bool) async throws -> (Data, URLResponse) {
            let token = try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: refresh)
            var request = URLRequest(url: origin.appending(path: path))
            request.setValue(WeekFitAIBilling.environment, forHTTPHeaderField: "X-WeekFit-Billing-Environment")
            request.httpMethod = method
            request.timeoutInterval = 180
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let proof { request.setValue(proof, forHTTPHeaderField: "X-WeekFit-Subscription-JWS") }
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
    func checkoutAccountToken() async throws -> UUID {
        struct Account: Decodable { let appAccountToken: UUID }
        let account: Account = try await request(path: "v2/ai/account", method: "GET", requiresProof: false)
        return account.appAccountToken
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
    @Published private(set) var requiresSubscription = false
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
            requiresSubscription = false
        } catch {
            requiresSubscription = (error as? WeekFitAIUsageError) == .subscriptionRequired
            if requiresSubscription { usage = nil }
            message = WeekFitAIErrorMessage(error)
        }
    }

    func buy(_ product: Product) async {
        guard !isBusy, usage?.active == true else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let latest = try await WeekFitAIClient().usage()
            self.usage = latest
            guard latest.active else { throw WeekFitAIUsageError.subscriptionRequired }
            switch try await product.purchase(options: [.appAccountToken(latest.appAccountToken)]) {
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
        } catch { message = WeekFitAIErrorMessage(error) }
    }
}
