import Foundation
import os
import StoreKit
internal import Combine

/// Coordinated release switch. Absent in existing builds: production behavior is unchanged.
nonisolated enum WeekFitAIBilling {
    static var enabled: Bool { WeekFitCloudAPI.billingDecision.billingEnabled }
    /// Sandbox was requested, but this build must not call Production.
    static var refused: Bool { WeekFitCloudAPI.sandboxRefused }
    static var environment: String { WeekFitCloudAPI.billingDecision.environmentHeader }
    static let products = ["com.weekfit.topup.photos20", "com.weekfit.topup.photos50",
                           "com.weekfit.topup.voice15", "com.weekfit.topup.voice30"]
    static func isTopUp(_ id: String) -> Bool { products.contains(id) }
}

nonisolated struct WeekFitAIUsage: Decodable, Sendable {
    struct Balance: Decodable, Sendable {
        let included: Int
        let purchased: Int
        let reserved: Int
        let used: Int
        var total: Int { included + purchased }

        private enum CodingKeys: String, CodingKey {
            case included, purchased, reserved, used
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            included = try container.decode(Int.self, forKey: .included)
            purchased = try container.decode(Int.self, forKey: .purchased)
            reserved = try container.decodeIfPresent(Int.self, forKey: .reserved) ?? 0
            used = try container.decodeIfPresent(Int.self, forKey: .used) ?? 0
        }
    }
    let appAccountToken: UUID
    let active: Bool
    let productId: String
    let periodStart: Double
    let periodEnd: Double
    let grandfatheredPhotos: Bool
    let photos: Balance
    let voice: Balance
    let voiceFinalizing: Bool
    var resetDate: Date { Date(timeIntervalSince1970: periodEnd / 1000) }

    private enum CodingKeys: String, CodingKey {
        case appAccountToken, active, productId, periodStart, periodEnd
        case grandfatheredPhotos, photos, voice, voiceFinalizing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appAccountToken = try container.decode(UUID.self, forKey: .appAccountToken)
        active = try container.decode(Bool.self, forKey: .active)
        productId = try container.decode(String.self, forKey: .productId)
        periodStart = try container.decode(Double.self, forKey: .periodStart)
        periodEnd = try container.decode(Double.self, forKey: .periodEnd)
        grandfatheredPhotos = try container.decode(Bool.self, forKey: .grandfatheredPhotos)
        photos = try container.decode(Balance.self, forKey: .photos)
        voice = try container.decode(Balance.self, forKey: .voice)
        voiceFinalizing = try container.decodeIfPresent(Bool.self, forKey: .voiceFinalizing) ?? false
    }
}

nonisolated enum WeekFitAIUsageError: Error, Equatable {
    case subscriptionRequired, quotaExhausted, unavailable, pending, verification, misconfigured
    var localizationKey: String {
        switch self {
        case .subscriptionRequired: "ai.usage.subscriptionRequired"
        case .quotaExhausted: "ai.usage.exhausted"
        case .pending: "ai.usage.pending"
        case .verification: "ai.usage.verification"
        case .unavailable: "ai.usage.unavailable"
        case .misconfigured: "ai.usage.sandboxMisconfigured"
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
        if WeekFitCloudAPI.sandboxRefused { throw WeekFitAIUsageError.misconfigured }
        let origin = await MainActor.run { baseURL ?? WeekFitCloudAPI.foodPhotoBaseURL }
        if origin.host == WeekFitAISandboxDecision.refusedBaseURL.host {
            throw WeekFitAIUsageError.misconfigured
        }
        let proof = await WeekFitAIProof.subscriptionJWS()
        if requiresProof && proof == nil { throw WeekFitAIUsageError.subscriptionRequired }
        func perform(refresh: Bool) async throws -> (Data, URLResponse) {
            let token = try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: refresh)
            var request = URLRequest(url: origin.appending(path: path))
            request.setValue(WeekFitAIBilling.environment, forHTTPHeaderField: "X-WeekFit-Billing-Environment")
            request.httpMethod = method
            request.timeoutInterval = path == "v2/ai/usage" ? 20 : 180
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
        if !(200...299).contains(http.statusCode) {
            Logger(subsystem: "com.weekfit.app", category: "AIUsage").error(
                "ai_request_failed path=\(path, privacy: .public) status=\(http.statusCode) code=\(code ?? "unknown", privacy: .public)")
        }
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

extension Notification.Name {
    static let weekfitVoiceStopFinished = Notification.Name("weekfit.voice.stop.finished")
}

/// Durable session ids for a voice stop that has not been acknowledged yet.
/// A retry posts stop only. It never opens another call.
enum WeekFitVoiceStopLedger {
    static var defaults = UserDefaults.standard
    private static let storageKey = "weekfit.ai.voice.pendingStops"

    static func remember(_ sessionId: String) {
        guard isOperationID(sessionId) else { return }
        var ids = pending()
        guard !ids.contains(sessionId) else { return }
        ids.append(sessionId)
        defaults.set(ids, forKey: storageKey)
    }

    static func forget(_ sessionId: String) {
        defaults.set(pending().filter { $0 != sessionId }, forKey: storageKey)
    }

    static func pending() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    static func isOperationID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{8,100}$", options: .regularExpression) != nil
    }
}

actor WeekFitVoiceStopQueue {
    static let shared = WeekFitVoiceStopQueue()
    private var transport: @Sendable (String) async throws -> Void = WeekFitVoiceStopQueue.liveStop
    private let log = Logger(subsystem: "com.weekfit.app", category: "AIVoice")

    func setTransport(_ transport: @escaping @Sendable (String) async throws -> Void) {
        self.transport = transport
    }

    func resetTransport() {
        transport = Self.liveStop
    }

    func enqueue(_ sessionId: String) async {
        WeekFitVoiceStopLedger.remember(sessionId)
        log.notice("voice_stop_requested operation=\(sessionId, privacy: .public)")
        await flush()
    }

    func flush() async {
        let send = transport
        for sessionId in WeekFitVoiceStopLedger.pending() {
            do {
                try await send(sessionId)
                WeekFitVoiceStopLedger.forget(sessionId)
                log.notice("voice_stop_finished operation=\(sessionId, privacy: .public)")
                NotificationCenter.default.post(name: .weekfitVoiceStopFinished, object: sessionId)
            } catch {
                log.error("voice_stop_failed operation=\(sessionId, privacy: .public) kind=\(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    private static func liveStop(_ sessionId: String) async throws {
        let body = try JSONEncoder().encode(["sessionId": sessionId])
        let _: WeekFitAIUsage = try await WeekFitAIClient().request(path: "v2/ai/voice/stop", body: body)
    }
}

@MainActor
final class WeekFitAIUsageStore: ObservableObject {
    @Published private(set) var usage: WeekFitAIUsage?
    @Published private(set) var products: [Product] = []
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var requiresSubscription = false
    @Published private(set) var isRefreshing = false
    private let loadUsage: () async throws -> WeekFitAIUsage
    private let loadProducts: () async throws -> [Product]
    private let recoverPurchases: () async throws -> WeekFitAIUsage?
    private let flushStops: () async -> Void
    private let isEnabled: () -> Bool
    private let isRefused: () -> Bool
    private let retryPause: () async throws -> Void
    private let log = Logger(subsystem: "com.weekfit.app", category: "AIUsage")

    init(loadUsage: @escaping () async throws -> WeekFitAIUsage = { try await WeekFitAIClient().usage() },
         loadProducts: @escaping () async throws -> [Product] = {
             try await Product.products(for: WeekFitAIBilling.products)
                 .filter { $0.type == .consumable }.sorted { $0.price < $1.price }
         },
         recoverPurchases: @escaping () async throws -> WeekFitAIUsage? = {
             var latest: WeekFitAIUsage?
             for await result in Transaction.unfinished {
                 if case .verified(let tx) = result, WeekFitAIBilling.isTopUp(tx.productID) {
                     latest = try await WeekFitAIClient().deliver(result.jwsRepresentation)
                     await tx.finish()
                 }
             }
             return latest
         },
         flushStops: @escaping () async -> Void = { await WeekFitVoiceStopQueue.shared.flush() },
         isEnabled: @escaping () -> Bool = { WeekFitAIBilling.enabled },
         isRefused: @escaping () -> Bool = { WeekFitAIBilling.refused },
         retryPause: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(400)) }) {
        self.loadUsage = loadUsage
        self.loadProducts = loadProducts
        self.recoverPurchases = recoverPurchases
        self.flushStops = flushStops
        self.isEnabled = isEnabled
        self.isRefused = isRefused
        self.retryPause = retryPause
    }

    private func readUsage() async throws -> WeekFitAIUsage {
        do { return try await loadUsage() }
        catch {
            // Retry a read only. Never automatically repeat a purchase or provider call.
            let transient = (error as? WeekFitAIUsageError) == .unavailable
                || ((error as? URLError).map { $0.code != .cancelled } ?? false)
            guard transient, !Task.isCancelled else { throw error }
            try await retryPause()
            try Task.checkCancellation()
            return try await loadUsage()
        }
    }

    private func report(_ error: Error, stage: String) {
        log.error("ai_usage_refresh_failed stage=\(stage, privacy: .public) kind=\(String(describing: type(of: error)), privacy: .public)")
    }

    func refresh() async {
        if isRefused() {
            usage = nil
            products = []
            requiresSubscription = false
            message = WeekFitLocalizedString("ai.usage.sandboxMisconfigured")
            return
        }
        guard isEnabled(), !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        message = nil

        // Publish the balance first: stop recovery, unfinished deliveries and StoreKit
        // product availability must not prevent opening the balance screen.
        do {
            usage = try await readUsage()
            requiresSubscription = false
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            requiresSubscription = (error as? WeekFitAIUsageError) == .subscriptionRequired
            if requiresSubscription { usage = nil }
            message = WeekFitAIErrorMessage(error)
            report(error, stage: "balance")
        }
        guard !Task.isCancelled else { return }
        do {
            products = try await loadProducts()
        } catch {
            if Task.isCancelled { return }
            // Keep a loaded balance and any previously loaded product list.
            report(error, stage: "products")
        }
        guard !Task.isCancelled else { return }
        do {
            if let delivered = try await recoverPurchases() {
                usage = delivered
                requiresSubscription = false
                message = nil
            }
        } catch {
            if Task.isCancelled { return }
            message = WeekFitAIErrorMessage(error)
            report(error, stage: "purchase_delivery")
        }
        // Flush after the independent read; a slow provider hangup must not hide the page.
        let hadPendingStops = !WeekFitVoiceStopLedger.pending().isEmpty
        await flushStops()
        if hadPendingStops && WeekFitVoiceStopLedger.pending().isEmpty && !Task.isCancelled {
            do {
                usage = try await readUsage()
                requiresSubscription = false
            } catch {
                report(error, stage: "balance_after_stop")
            }
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
