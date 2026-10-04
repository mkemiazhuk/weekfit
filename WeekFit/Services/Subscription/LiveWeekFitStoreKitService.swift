import Foundation
import StoreKit
#if DEBUG
import OSLog
#endif

@MainActor
protocol WeekFitStoreKitServicing: AnyObject {
    func loadAppTransaction() async -> WeekFitAppTransactionStatus
    func loadProducts() async throws -> WeekFitProductsLoadResult
    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot?
    /// Runs StoreKit purchase. On `.success`, the verified transaction is held unfinished
    /// until `finishVerifiedPurchaseIfNeeded()` so the caller can deliver entitlements first.
    func purchase(productID: String) async -> WeekFitPurchaseOutcome
    /// Finishes the outstanding verified purchase transaction, if any (idempotent).
    func finishVerifiedPurchaseIfNeeded() async
    func restorePurchases() async throws
    /// Drops cached `Product` instances so the next load/purchase cannot use a prior storefront.
    func invalidateCachedProducts()
    func startTransactionUpdates(_ onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never>
    /// Observes StoreKit storefront changes so paywall prices can refresh with the catalog.
    func startStorefrontUpdates(_ onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never>
}

@MainActor
final class LiveWeekFitStoreKitService: WeekFitStoreKitServicing {
    nonisolated deinit {}

    private var productsByID: [String: Product] = [:]
    /// Last successful `Product.products` mapping for the current storefront.
    /// Avoids re-hitting the network on every `SubscriptionManager.refresh()` /
    /// foreground while the catalog is unchanged.
    private var cachedProductsResult: WeekFitProductsLoadResult?
    /// Verified purchase awaiting entitlement delivery + `finish()` (Apple: unlock → finish).
    private var pendingVerifiedPurchase: Transaction?
    /// Product ids waiting for Ask to Buy / SCA to resolve via `Transaction.updates`.
    private var awaitingPendingPurchaseProductIDs: Set<String> = []
    /// Recently finished transaction ids — avoids double-finish with `Transaction.updates`.
    private var recentlyFinishedTransactionIDs: [UInt64] = []
    private let maxRecentlyFinishedTransactionIDs = 32

    func loadAppTransaction() async -> WeekFitAppTransactionStatus {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                #if DEBUG
                WeekFitStoreKitDebug.log(
                    "AppTransaction verified originalPurchaseDate=\(transaction.originalPurchaseDate) environment=\(transaction.environment)"
                )
                #endif
                return .verified(
                    originalPurchaseDate: transaction.originalPurchaseDate,
                    environment: transaction.environment.rawValue
                )
            case .unverified(let transaction, let error):
                #if DEBUG
                WeekFitStoreKitDebug.log(
                    "AppTransaction unverified environment=\(transaction.environment) error=\(error)"
                )
                #endif
                return .unverified(environment: transaction.environment.rawValue)
            }
        } catch {
            #if DEBUG
            WeekFitStoreKitDebug.log("AppTransaction unavailable error=\(error)")
            #endif
            return .unavailable
        }
    }

    func loadProducts() async throws -> WeekFitProductsLoadResult {
        let requestedIDs = WeekFitSubscriptionProductID.allRawValues
        let storefront = await Self.currentStorefrontSnapshot()
        if let cached = cachedProductsResult,
           !productsByID.isEmpty,
           cached.storefront.id == storefront.id,
           cached.storefront.countryCode == storefront.countryCode {
            #if DEBUG
            WeekFitStoreKitDebug.log(
                "Product.products cache hit storefront=\(storefront.countryCode ?? "?")/\(storefront.id ?? "?") count=\(cached.products.count)"
            )
            #endif
            return cached
        }
        #if DEBUG
        await WeekFitStoreKitDebug.logProductLoadStart(requestedIDs: requestedIDs)
        #endif
        do {
            await WeekFitStoreKitTimelineDiagnostics.shared.recordProductLoadBefore()
            let storeProducts = try await Product.products(for: requestedIDs)
            await WeekFitStoreKitTimelineDiagnostics.shared.recordProductLoadAfter(
                returnedCount: storeProducts.count
            )
            WeekFitStoreKitTimelineDiagnostics.shared.recordProductsReturned(storeProducts)
            var mapped: [String: Product] = [:]
            for product in storeProducts {
                mapped[product.id] = product
            }
            productsByID = mapped
            var snapshots: [WeekFitProductSnapshot] = []
            snapshots.reserveCapacity(storeProducts.count)
            for product in storeProducts {
                if let snapshot = await Self.snapshot(from: product) {
                    snapshots.append(snapshot)
                }
            }
            let result = WeekFitProductsLoadResult(
                products: snapshots,
                rawReturnedCount: storeProducts.count,
                storefront: storefront
            )
            cachedProductsResult = result
            #if DEBUG
            WeekFitStoreKitDebug.logProductLoadSuccess(
                requestedIDs: requestedIDs,
                storeProducts: storeProducts,
                snapshots: snapshots
            )
            #endif
            return result
        } catch {
            productsByID = [:]
            cachedProductsResult = nil
            #if DEBUG
            WeekFitStoreKitDebug.logProductLoadFailure(requestedIDs: requestedIDs, error: error)
            #endif
            throw error
        }
    }

    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot? {
        var snapshots: [WeekFitSubscriptionSnapshot] = []
        #if DEBUG
        var entitlementDiagLines: [String] = []
        #endif

        for await result in Transaction.currentEntitlements {
            let transaction: Transaction? = {
                switch result {
                case .verified(let transaction):
                    return transaction
                case .unverified:
                    return nil
                }
            }()

            guard let transaction else {
                #if DEBUG
                entitlementDiagLines.append("entitlements.unverified")
                #endif
                continue
            }
            guard WeekFitSubscriptionProductID(rawValue: transaction.productID) != nil else { continue }

            let now = Date()
            let snapshot = WeekFitSubscriptionSnapshot(
                productID: transaction.productID,
                isIntroductoryTrial: transaction.offer?.type == .introductory,
                expirationDate: transaction.expirationDate,
                isExpired: transaction.expirationDate.map { $0 <= now } ?? false,
                isRevoked: transaction.revocationDate != nil,
                billingState: .none
            )
            snapshots.append(snapshot)
            #if DEBUG
            entitlementDiagLines.append(
                WeekFitSubscriptionAccessDiagnostics.line(
                    source: "currentEntitlements",
                    productID: transaction.productID,
                    transactionID: transaction.id,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    environment: String(describing: transaction.environment),
                    renewalState: "n/a",
                    willAutoRenew: nil,
                    billingState: snapshot.billingState,
                    isExpiredFlag: snapshot.isExpired,
                    isActive: WeekFitEntitlementPolicy.isActiveSubscription(snapshot, now: now)
                )
            )
            #endif
        }

        if let fromStatus = await subscriptionStatusSnapshot() {
            snapshots.append(fromStatus)
        }

        let selected = snapshots.first { WeekFitEntitlementPolicy.isActiveSubscription($0) }
            ?? snapshots.first
        #if DEBUG
        WeekFitSubscriptionAccessDiagnostics.logLoad(
            entitlementLines: entitlementDiagLines,
            selected: selected
        )
        #endif
        return selected
    }

    func invalidateCachedProducts() {
        productsByID = [:]
        cachedProductsResult = nil
    }

    func purchase(productID: String) async -> WeekFitPurchaseOutcome {
        // After storefront invalidation the cache is empty — reload before purchase so
        // we never call purchase() on a Product retained from a prior storefront.
        if productsByID[productID] == nil {
            do {
                _ = try await loadProducts()
            } catch {
                return .productsUnavailable
            }
        }
        guard let product = productsByID[productID] else {
            return .productsUnavailable
        }

        do {
            await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseBefore(product: product)
            // StoreKit 2: `Product.purchase()` presents the system sheet and returns
            // the transaction for this attempt. Do not call `AppStore.sync()` here.
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Firebase StoreKit 2: log before finish (finish happens after entitlement unlock).
                    StoreKitTransactionAnalytics.logVerifiedPurchaseTransactionIfNeeded(transaction)
                    // Hold finish until the caller refreshes entitlements (unlock → finish).
                    pendingVerifiedPurchase = transaction
                    awaitingPendingPurchaseProductIDs.remove(productID)
                    WeekFitDeferredPurchaseStore.clear()
                    await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "success")
                    return .success
                case .unverified:
                    // Never finish or unlock unverified transactions.
                    pendingVerifiedPurchase = nil
                    await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "failedVerification")
                    return .failedVerification
                }
            case .userCancelled:
                pendingVerifiedPurchase = nil
                awaitingPendingPurchaseProductIDs.remove(productID)
                WeekFitDeferredPurchaseStore.clear()
                await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "userCancelled")
                return .cancelled
            case .pending:
                // Ask to Buy / SCA — keep unfinished; Transaction.updates delivers later.
                // Persist so a process kill before approval still logs revenue + funnel success.
                pendingVerifiedPurchase = nil
                awaitingPendingPurchaseProductIDs.insert(productID)
                WeekFitDeferredPurchaseStore.markPending(productID: productID, requestedTab: nil)
                await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "pending")
                return .pending
            @unknown default:
                pendingVerifiedPurchase = nil
                await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "failed")
                return .failed
            }
        } catch {
            pendingVerifiedPurchase = nil
            await WeekFitStoreKitTimelineDiagnostics.shared.recordPurchaseAfter(result: "threw")
            return .failed
        }
    }

    func finishVerifiedPurchaseIfNeeded() async {
        guard let transaction = pendingVerifiedPurchase else { return }
        pendingVerifiedPurchase = nil
        await finishTransactionIfNeeded(transaction)
    }

    func restorePurchases() async throws {
        do {
            // Apple: call only from an explicit Restore action. Forces App Store
            // re-auth and refreshes transaction / subscription status on device.
            // Callers must race this against a timeout (Sandbox auth can hang).
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw CancellationError()
        }
    }

    func startTransactionUpdates(
        _ onChange: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Same strategy as direct purchase: deliver entitlements, then finish.
                    await onChange()
                    await self?.completeVerifiedTransactionUpdate(transaction)
                case .unverified:
                    #if DEBUG
                    // Local StoreKit may emit unverified updates; re-evaluate without granting access.
                    await onChange()
                    #endif
                }
            }
        }
    }

    private func completeVerifiedTransactionUpdate(_ transaction: Transaction) async {
        // Revenue only for Ask-to-Buy / deferred completions we initiated — never restore,
        // unverified, or ordinary renewals (Firebase SK1 observer / server-side renewals).
        let isDeferred =
            awaitingPendingPurchaseProductIDs.contains(transaction.productID)
            || WeekFitDeferredPurchaseStore.pendingProductID() == transaction.productID
        if isDeferred {
            StoreKitTransactionAnalytics.logVerifiedPurchaseTransactionIfNeeded(transaction)
            awaitingPendingPurchaseProductIDs.remove(transaction.productID)
            // Funnel consume happens in SubscriptionManager after entitlement refresh.
        }
        await finishTransactionIfNeeded(transaction)
        if pendingVerifiedPurchase?.id == transaction.id {
            pendingVerifiedPurchase = nil
        }
    }

    private func finishTransactionIfNeeded(_ transaction: Transaction) async {
        if recentlyFinishedTransactionIDs.contains(transaction.id) { return }
        await transaction.finish()
        rememberFinishedTransactionID(transaction.id)
    }

    private func rememberFinishedTransactionID(_ id: UInt64) {
        if recentlyFinishedTransactionIDs.contains(id) { return }
        recentlyFinishedTransactionIDs.append(id)
        if recentlyFinishedTransactionIDs.count > maxRecentlyFinishedTransactionIDs {
            recentlyFinishedTransactionIDs.removeFirst(
                recentlyFinishedTransactionIDs.count - maxRecentlyFinishedTransactionIDs
            )
        }
    }

    func startStorefrontUpdates(
        _ onChange: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await storefront in Storefront.updates {
                await MainActor.run {
                    self?.invalidateCachedProducts()
                    WeekFitStoreKitTimelineDiagnostics.shared.recordStorefrontUpdate(storefront)
                }
                await onChange()
            }
        }
    }

    private static func currentStorefrontSnapshot() async -> WeekFitStorefrontSnapshot {
        guard let storefront = await Storefront.current else {
            return .unknown
        }
        return WeekFitStorefrontSnapshot(
            countryCode: storefront.countryCode,
            id: storefront.id
        )
    }

    private func subscriptionStatusSnapshot() async -> WeekFitSubscriptionSnapshot? {
        // Grace / billing-retry state comes from Product.SubscriptionInfo.status.
        // Ensure products are loaded — an empty cache would miss `.inGracePeriod` and
        // incorrectly treat a still-entitled subscriber as expired.
        if productsByID.isEmpty {
            _ = try? await loadProducts()
        }
        var candidates: [WeekFitSubscriptionSnapshot] = []
        for product in productsByID.values {
            guard let subscription = product.subscription else { continue }
            let statuses: [Product.SubscriptionInfo.Status]
            do {
                statuses = try await subscription.status
            } catch {
                continue
            }
            for status in statuses {
                let transaction: Transaction? = {
                    switch status.transaction {
                    case .verified(let transaction):
                        return transaction
                    case .unverified:
                        return nil
                    }
                }()
                guard let transaction else { continue }
                let renewal = verifiedRenewalInfo(from: status)
                let willAutoRenew = renewal?.willAutoRenew ?? true
                let graceEnd = renewal?.gracePeriodExpirationDate
                let renewalStateLabel = String(describing: status.state)
                let billingState: WeekFitSubscriptionBillingState
                let isExpired: Bool
                let snapshot: WeekFitSubscriptionSnapshot
                switch status.state {
                case .subscribed:
                    billingState = .none
                    isExpired = false
                    snapshot = WeekFitSubscriptionSnapshot(
                        productID: transaction.productID,
                        isIntroductoryTrial: transaction.offer?.type == .introductory,
                        expirationDate: transaction.expirationDate,
                        isExpired: isExpired,
                        isRevoked: false,
                        billingState: billingState,
                        gracePeriodExpirationDate: graceEnd,
                        willAutoRenew: willAutoRenew
                    )
                case .inGracePeriod:
                    billingState = .inGracePeriod
                    // Period may look expired on the transaction; grace still entitles.
                    isExpired = false
                    snapshot = WeekFitSubscriptionSnapshot(
                        productID: transaction.productID,
                        isIntroductoryTrial: transaction.offer?.type == .introductory,
                        expirationDate: transaction.expirationDate,
                        isExpired: isExpired,
                        isRevoked: false,
                        billingState: billingState,
                        gracePeriodExpirationDate: graceEnd,
                        willAutoRenew: willAutoRenew
                    )
                case .inBillingRetryPeriod:
                    billingState = .inBillingRetry
                    isExpired = true
                    snapshot = WeekFitSubscriptionSnapshot(
                        productID: transaction.productID,
                        isIntroductoryTrial: transaction.offer?.type == .introductory,
                        expirationDate: transaction.expirationDate,
                        isExpired: isExpired,
                        isRevoked: false,
                        billingState: billingState,
                        gracePeriodExpirationDate: graceEnd,
                        willAutoRenew: willAutoRenew
                    )
                case .expired, .revoked:
                    snapshot = WeekFitSubscriptionSnapshot(
                        productID: transaction.productID,
                        isIntroductoryTrial: transaction.offer?.type == .introductory,
                        expirationDate: transaction.expirationDate,
                        isExpired: true,
                        isRevoked: status.state == .revoked,
                        billingState: .none,
                        willAutoRenew: willAutoRenew
                    )
                default:
                    continue
                }
                candidates.append(snapshot)
                #if DEBUG
                WeekFitSubscriptionAccessDiagnostics.log(
                    WeekFitSubscriptionAccessDiagnostics.line(
                        source: "subscription.status",
                        productID: transaction.productID,
                        transactionID: transaction.id,
                        expirationDate: transaction.expirationDate,
                        revocationDate: transaction.revocationDate,
                        environment: String(describing: transaction.environment),
                        renewalState: renewalStateLabel,
                        willAutoRenew: willAutoRenew,
                        billingState: snapshot.billingState,
                        isExpiredFlag: snapshot.isExpired,
                        isActive: WeekFitEntitlementPolicy.isActiveSubscription(snapshot)
                    )
                )
                #endif
            }
        }
        // Prefer entitled (active / grace); never prefer bare billing-retry over an active peer.
        return candidates.first { WeekFitEntitlementPolicy.isActiveSubscription($0) }
            ?? candidates.first
    }

    private func verifiedRenewalInfo(
        from status: Product.SubscriptionInfo.Status
    ) -> Product.SubscriptionInfo.RenewalInfo? {
        switch status.renewalInfo {
        case .verified(let renewalInfo):
            return renewalInfo
        case .unverified:
            return nil
        @unknown default:
            return nil
        }
    }

    private func renewalWillAutoRenew(from status: Product.SubscriptionInfo.Status) -> Bool {
        verifiedRenewalInfo(from: status)?.willAutoRenew ?? true
    }

    private static func snapshot(from product: Product) async -> WeekFitProductSnapshot? {
        guard let subscription = product.subscription else { return nil }
        let period = subscription.subscriptionPeriod

        let introductoryOffer: WeekFitIntroductoryOfferSnapshot?
        let eligibility: WeekFitIntroEligibility
        if let offer = subscription.introductoryOffer {
            introductoryOffer = WeekFitIntroductoryOfferSnapshot(
                periodValue: offer.period.value,
                periodUnit: mapPeriodUnit(offer.period.unit),
                paymentMode: mapPaymentMode(offer.paymentMode)
            )
            let eligible = await subscription.isEligibleForIntroOffer
            eligibility = eligible ? .eligible : .ineligible
        } else {
            introductoryOffer = nil
            // Do not call isEligibleForIntroOffer when there is no offer to evaluate.
            eligibility = .unknown
        }

        return WeekFitProductSnapshot(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            price: product.price,
            periodUnit: mapPeriodUnit(period.unit),
            periodValue: period.value,
            currencyCode: product.priceFormatStyle.currencyCode,
            monthlyEquivalentDisplay: period.unit == .year
                ? product.priceFormatStyle.format(product.price / 12)
                : nil,
            introductoryOffer: introductoryOffer,
            introductoryOfferEligibility: eligibility
        )
    }

    private static func mapPeriodUnit(_ unit: Product.SubscriptionPeriod.Unit) -> WeekFitSubscriptionPeriodUnit {
        switch unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .month
        }
    }

    private static func mapPaymentMode(
        _ mode: Product.SubscriptionOffer.PaymentMode
    ) -> WeekFitIntroductoryPaymentMode {
        switch mode {
        case .freeTrial: return .free
        case .payAsYouGo: return .payAsYouGo
        case .payUpFront: return .payUpFront
        default: return .payUpFront
        }
    }
}

#if DEBUG
private enum WeekFitStoreKitDebug {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "StoreKit")

    static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    static func logProductLoadStart(requestedIDs: [String]) async {
        let storefront = await Storefront.current?.countryCode ?? "none"
        let environment = await environmentDescription()
        log(
            "Product.products request ids=\(requestedIDs) storefront=\(storefront) environment=\(environment) canMakePayments=\(AppStore.canMakePayments)"
        )
    }

    static func logProductLoadSuccess(
        requestedIDs: [String],
        storeProducts: [Product],
        snapshots: [WeekFitProductSnapshot]
    ) {
        let returnedIDs = storeProducts.map(\.id).sorted()
        let missingIDs = requestedIDs.filter { requested in
            storeProducts.contains(where: { $0.id == requested }) == false
        }
        let droppedIDs = storeProducts.compactMap { product -> String? in
            snapshots.contains(where: { $0.id == product.id }) ? nil : "\(product.id) type=\(String(describing: product.type))"
        }
        log(
            "Product.products returned count=\(storeProducts.count) ids=\(returnedIDs) missingRequested=\(missingIDs) snapshotCount=\(snapshots.count) droppedNonSubscription=\(droppedIDs)"
        )
        for product in storeProducts {
            let period = product.subscription?.subscriptionPeriod
            let intro = product.subscription?.introductoryOffer?.period
            log(
                "product id=\(product.id) display=\(product.displayName) price=\(product.displayPrice) type=\(product.type) period=\(String(describing: period)) intro=\(String(describing: intro))"
            )
        }
    }

    static func logProductLoadFailure(requestedIDs: [String], error: Error) {
        log(
            "Product.products threw ids=\(requestedIDs) errorType=\(String(describing: type(of: error))) error=\(error) storeKit=\(storeKitErrorDescription(error))"
        )
    }

    private static func environmentDescription() async -> String {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                return String(describing: transaction.environment)
            case .unverified(let transaction, let error):
                return "unverified(\(transaction.environment), \(error))"
            }
        } catch {
            return "unavailable(\(error.localizedDescription))"
        }
    }

    private static func storeKitErrorDescription(_ error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            return String(describing: storeKitError)
        }
        return "not StoreKitError"
    }
}
#endif
