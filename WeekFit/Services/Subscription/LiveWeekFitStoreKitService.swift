import Foundation
import StoreKit
#if DEBUG
import OSLog
#endif

@MainActor
protocol WeekFitStoreKitServicing: AnyObject {
    func loadAppTransaction() async -> WeekFitAppTransactionStatus
    func loadProducts() async throws -> [WeekFitProductSnapshot]
    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot?
    func purchase(productID: String) async -> WeekFitPurchaseOutcome
    func restorePurchases() async throws
    func startTransactionUpdates(_ onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never>
}

@MainActor
final class LiveWeekFitStoreKitService: WeekFitStoreKitServicing {
    nonisolated deinit {}

    private var productsByID: [String: Product] = [:]

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

    func loadProducts() async throws -> [WeekFitProductSnapshot] {
        let requestedIDs = WeekFitSubscriptionProductID.allRawValues
        #if DEBUG
        await WeekFitStoreKitDebug.logProductLoadStart(requestedIDs: requestedIDs)
        #endif
        do {
            let storeProducts = try await Product.products(for: requestedIDs)
            var mapped: [String: Product] = [:]
            for product in storeProducts {
                mapped[product.id] = product
            }
            productsByID = mapped
            let snapshots = storeProducts.compactMap(Self.snapshot(from:))
            #if DEBUG
            WeekFitStoreKitDebug.logProductLoadSuccess(
                requestedIDs: requestedIDs,
                storeProducts: storeProducts,
                snapshots: snapshots
            )
            #endif
            return snapshots
        } catch {
            #if DEBUG
            WeekFitStoreKitDebug.logProductLoadFailure(requestedIDs: requestedIDs, error: error)
            #endif
            throw error
        }
    }

    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot? {
        var snapshots: [WeekFitSubscriptionSnapshot] = []

        for await result in Transaction.currentEntitlements {
            let transaction: Transaction? = {
                switch result {
                case .verified(let transaction):
                    return transaction
                case .unverified:
                    return nil
                }
            }()

            guard let transaction else { continue }
            guard WeekFitSubscriptionProductID(rawValue: transaction.productID) != nil else { continue }

            snapshots.append(
                WeekFitSubscriptionSnapshot(
                    productID: transaction.productID,
                    isIntroductoryTrial: transaction.offer?.type == .introductory,
                    expirationDate: transaction.expirationDate,
                    isExpired: transaction.expirationDate.map { $0 <= Date() } ?? false,
                    isRevoked: transaction.revocationDate != nil,
                    inGraceOrRetry: false
                )
            )
        }

        if let fromStatus = await subscriptionStatusSnapshot() {
            snapshots.append(fromStatus)
        }

        return snapshots.first { WeekFitEntitlementPolicy.isActiveSubscription($0) }
            ?? snapshots.first
    }

    func purchase(productID: String) async -> WeekFitPurchaseOutcome {
        let product: Product
        if let cached = productsByID[productID] {
            product = cached
        } else {
            do {
                _ = try await loadProducts()
            } catch {
                return .productsUnavailable
            }
            guard let loaded = productsByID[productID] else {
                return .productsUnavailable
            }
            product = loaded
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failedVerification
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restorePurchases() async throws {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw CancellationError()
        }
    }

    func startTransactionUpdates(
        _ onChange: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await onChange()
                case .unverified:
                    #if DEBUG
                    // Local StoreKit may emit unverified updates; re-evaluate without granting access.
                    await onChange()
                    #endif
                }
            }
        }
    }

    private func subscriptionStatusSnapshot() async -> WeekFitSubscriptionSnapshot? {
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
                let willAutoRenew = renewalWillAutoRenew(from: status)
                let inGraceOrRetry: Bool
                switch status.state {
                case .subscribed:
                    inGraceOrRetry = false
                case .inGracePeriod, .inBillingRetryPeriod:
                    inGraceOrRetry = true
                case .expired, .revoked:
                    candidates.append(
                        WeekFitSubscriptionSnapshot(
                            productID: transaction.productID,
                            isIntroductoryTrial: transaction.offer?.type == .introductory,
                            expirationDate: transaction.expirationDate,
                            isExpired: true,
                            isRevoked: status.state == .revoked,
                            inGraceOrRetry: false,
                            willAutoRenew: willAutoRenew
                        )
                    )
                    continue
                default:
                    continue
                }

                candidates.append(
                    WeekFitSubscriptionSnapshot(
                    productID: transaction.productID,
                    isIntroductoryTrial: transaction.offer?.type == .introductory,
                    expirationDate: transaction.expirationDate,
                    isExpired: false,
                    isRevoked: false,
                    inGraceOrRetry: inGraceOrRetry,
                    willAutoRenew: willAutoRenew
                    )
                )
            }
        }
        // Prefer active/grace subscriptions; otherwise fall back to any candidate.
        return candidates.first { WeekFitEntitlementPolicy.isActiveSubscription($0) }
            ?? candidates.first
    }

    private func renewalWillAutoRenew(from status: Product.SubscriptionInfo.Status) -> Bool {
        switch status.renewalInfo {
        case .verified(let renewalInfo):
            return renewalInfo.willAutoRenew
        case .unverified:
            return true
        @unknown default:
            return true
        }
    }

    private static func snapshot(from product: Product) -> WeekFitProductSnapshot? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        return WeekFitProductSnapshot(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            price: product.price,
            periodUnit: mapPeriodUnit(period.unit),
            monthlyEquivalentDisplay: period.unit == .year
                ? product.priceFormatStyle.format(product.price / 12)
                : nil,
            introductoryOffer: product.subscription?.introductoryOffer.map { offer in
                WeekFitIntroductoryOfferSnapshot(
                    periodValue: offer.period.value,
                    periodUnit: mapPeriodUnit(offer.period.unit)
                )
            }
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
}

#if DEBUG
private enum WeekFitStoreKitDebug {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "StoreKit")

    static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        print("[WeekFit.StoreKit] \(message)")
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
