import XCTest
@testable import WeekFit

@MainActor
final class RecordingWeekFitStoreKitService: WeekFitStoreKitServicing {
    var appTransaction: WeekFitAppTransactionStatus = .unavailable
    var products: [WeekFitProductSnapshot] = []
    var storefront = WeekFitStorefrontSnapshot(countryCode: "POL", id: "143478")
    var subscription: WeekFitSubscriptionSnapshot?
    var purchaseOutcome: WeekFitPurchaseOutcome = .success
    var restoreError: Error?
    var restoreGrantsSubscription = true
    var purchaseCalls: [String] = []
    var restoreCount = 0
    var loadProductsError: Error?
    var loadProductsCallCount = 0
    var invalidateCachedProductsCount = 0
    var cachedProductIDs: Set<String> = []
    var storefrontUpdateHandler: (@Sendable () async -> Void)?

    func loadAppTransaction() async -> WeekFitAppTransactionStatus { appTransaction }

    func loadProducts() async throws -> WeekFitProductsLoadResult {
        loadProductsCallCount += 1
        if let loadProductsError { throw loadProductsError }
        cachedProductIDs = Set(products.map(\.id))
        return WeekFitProductsLoadResult(
            products: products,
            rawReturnedCount: products.count,
            storefront: storefront
        )
    }

    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot? { subscription }

    func invalidateCachedProducts() {
        invalidateCachedProductsCount += 1
        cachedProductIDs = []
    }

    func purchase(productID: String) async -> WeekFitPurchaseOutcome {
        if cachedProductIDs.contains(productID) == false {
            do {
                _ = try await loadProducts()
            } catch {
                return .productsUnavailable
            }
        }
        guard cachedProductIDs.contains(productID) else {
            return .productsUnavailable
        }
        purchaseCalls.append(productID)
        if purchaseOutcome == .success {
            subscription = WeekFitSubscriptionSnapshot(
                productID: productID,
                isIntroductoryTrial: productID == WeekFitSubscriptionProductID.annual.rawValue,
                expirationDate: Date().addingTimeInterval(86_400),
                isExpired: false,
                isRevoked: false,
                inGraceOrRetry: false
            )
        }
        return purchaseOutcome
    }

    func restorePurchases() async throws {
        restoreCount += 1
        if let restoreError { throw restoreError }
        guard restoreGrantsSubscription else { return }
        subscription = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            inGraceOrRetry: false
        )
    }

    func startTransactionUpdates(_ onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        Task { }
    }

    func startStorefrontUpdates(_ onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        storefrontUpdateHandler = onChange
        return Task { }
    }

    func emitStorefrontUpdate() async {
        invalidateCachedProducts()
        if let storefrontUpdateHandler {
            await storefrontUpdateHandler()
        }
    }
}

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private var store: RecordingWeekFitStoreKitService!
    private var manager: SubscriptionManager!
    private var recording: RecordingAnalyticsService!
    private var fallbackSuite: String!
    private var fallbackDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        SubscriptionAnalytics.resetPaywallViewDedupForTests()
        fallbackSuite = "weekfit.tests.entitlement.\(UUID().uuidString)"
        fallbackDefaults = UserDefaults(suiteName: fallbackSuite)
        fallbackDefaults.removePersistentDomain(forName: fallbackSuite)
        store = RecordingWeekFitStoreKitService()
        store.products = [
            WeekFitProductSnapshot(
                id: WeekFitSubscriptionProductID.annual.rawValue,
                displayName: "Annual",
                displayPrice: "€34.99",
                price: Decimal(string: "34.99")!,
                periodUnit: .year,
                periodValue: 1,
                currencyCode: "EUR",
                monthlyEquivalentDisplay: "€2.92",
                introductoryOffer: WeekFitIntroductoryOfferSnapshot(
                    periodValue: 1,
                    periodUnit: .week,
                    paymentMode: .free
                ),
                introductoryOfferEligibility: .eligible
            ),
            WeekFitProductSnapshot(
                id: WeekFitSubscriptionProductID.monthly.rawValue,
                displayName: "Monthly",
                displayPrice: "€4.99",
                price: Decimal(string: "4.99")!,
                periodUnit: .month,
                periodValue: 1,
                currencyCode: "EUR",
                monthlyEquivalentDisplay: nil,
                introductoryOffer: nil,
                introductoryOfferEligibility: .ineligible
            )
        ]
        manager = SubscriptionManager(
            store: store,
            bypassProvider: { .none },
            fallbackStore: WeekFitEntitlementFallbackStore(defaults: fallbackDefaults)
        )
    }

    override func tearDown() {
        SubscriptionAnalytics.resetPaywallViewDedupForTests()
        AppAnalytics.resetSharedForTests()
        if let fallbackSuite {
            fallbackDefaults?.removePersistentDomain(forName: fallbackSuite)
        }
        fallbackDefaults = nil
        fallbackSuite = nil
        recording = nil
        manager = nil
        store = nil
        super.tearDown()
    }

    func testNewUserWithoutSubscriptionIsBlockedAfterRefresh() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertTrue(manager.shouldBlockAccess)
        XCTAssertTrue(manager.canAccess(.today))
        XCTAssertFalse(manager.canAccess(.coach))
        XCTAssertFalse(manager.canAccess(.meals))
        XCTAssertFalse(manager.canAccess(.calendar))
    }

    func testLegacyUserIsNeverBlocked() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(-86_400),
            environment: "test"
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .legacy)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertFalse(manager.shouldBlockAccess)
        XCTAssertTrue(manager.canAccess(.today))
        XCTAssertTrue(manager.canAccess(.coach))
        XCTAssertTrue(manager.canAccess(.meals))
        XCTAssertTrue(manager.canAccess(.calendar))
    }

    func testUnresolvedEntitlementDoesNotOpenPremiumTabs() {
        XCTAssertEqual(manager.accessState, .loading)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertTrue(manager.canAccess(.today))
        XCTAssertFalse(manager.canAccess(.coach))
        XCTAssertFalse(manager.canAccess(.meals))
        XCTAssertFalse(manager.canAccess(.calendar))
    }

    func testActiveSubscriberCanAccessPremiumTabs() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.subscription = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.monthly.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            inGraceOrRetry: false
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .subscribed)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertTrue(manager.canAccess(.today))
        XCTAssertTrue(manager.canAccess(.coach))
        XCTAssertTrue(manager.canAccess(.meals))
        XCTAssertTrue(manager.canAccess(.calendar))
    }

    func testAnnualTrialPurchaseUnlocksOnlyAfterVerifiedEntitlement() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        XCTAssertTrue(manager.shouldBlockAccess)

        manager.selectProduct(WeekFitSubscriptionProductID.annual.rawValue)
        await manager.purchaseSelected()

        XCTAssertEqual(store.purchaseCalls, [WeekFitSubscriptionProductID.annual.rawValue])
        XCTAssertEqual(manager.accessState, .trial)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertEqual(manager.lastOutcome, .success)
        XCTAssertEqual(recording.events(named: .subscriptionPurchaseStarted).count, 1)
        XCTAssertEqual(recording.events(named: .subscriptionPurchaseSuccess).count, 1)
    }

    func testCancelledPurchaseStaysOnPaywall() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.purchaseOutcome = .cancelled
        await manager.start()
        await manager.purchaseSelected()
        XCTAssertEqual(manager.lastOutcome, .cancelled)
        XCTAssertTrue(manager.shouldBlockAccess)
        XCTAssertEqual(recording.events(named: .subscriptionPurchaseCancelled).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionPurchaseSuccess).isEmpty)
    }

    func testPendingPurchaseDoesNotUnlock() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.purchaseOutcome = .pending
        await manager.start()
        await manager.purchaseSelected()
        XCTAssertEqual(manager.lastOutcome, .pending)
        XCTAssertTrue(manager.shouldBlockAccess)
    }

    func testRestoreActiveSubscriptionGrantsAccess() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        await manager.restorePurchases(source: .tab)
        XCTAssertEqual(store.restoreCount, 1)
        XCTAssertEqual(manager.accessState, .subscribed)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreStarted).count, 1)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreSuccess).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreFailed).isEmpty)
        let success = try! XCTUnwrap(recording.events(named: .subscriptionRestoreSuccess).first)
        XCTAssertEqual(success.parameters[AnalyticsParameterKey.source], "tab")
        XCTAssertEqual(success.parameters[AnalyticsParameterKey.hasEntitlementBefore], "false")
        XCTAssertEqual(success.parameters[AnalyticsParameterKey.hasEntitlementAfter], "true")
        XCTAssertEqual(
            success.parameters[AnalyticsParameterKey.restoredProductID],
            WeekFitSubscriptionProductID.annual.rawValue
        )
    }

    func testRestoreWithNoPurchasesEmitsFailedNoPurchases() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.restoreGrantsSubscription = false
        await manager.start()
        XCTAssertFalse(manager.hasFullAccess)
        await manager.restorePurchases(source: .settings)
        XCTAssertEqual(store.restoreCount, 1)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreStarted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
        let failed = try! XCTUnwrap(recording.events(named: .subscriptionRestoreFailed).first)
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.source], "settings")
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.failureReason], "no_purchases")
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.hasEntitlementAfter], "false")
    }

    func testRestoreStoreKitErrorEmitsFailedStorekitError() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.restoreError = NSError(domain: "test.restore", code: 42)
        await manager.start()
        await manager.restorePurchases(source: .settings)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreStarted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
        let failed = try! XCTUnwrap(recording.events(named: .subscriptionRestoreFailed).first)
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.failureReason], "storekit_error")
    }

    func testStartAndRefreshDoNotEmitRestoreAnalytics() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        await manager.refresh()
        XCTAssertEqual(store.restoreCount, 0)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreStarted).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreFailed).isEmpty)
    }

    func testPurchaseFailureEmitsPurchaseFailed() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.purchaseOutcome = .failed
        await manager.start()
        await manager.purchaseSelected()
        XCTAssertEqual(recording.events(named: .subscriptionPurchaseStarted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionPurchaseSuccess).isEmpty)
        let failed = try! XCTUnwrap(recording.events(named: .subscriptionPurchaseFailed).first)
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.failureReason], "storekit_error")
    }

    func testPendingPurchaseEmitsTerminalPurchaseFailedPending() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.purchaseOutcome = .pending
        await manager.start()
        await manager.purchaseSelected()
        XCTAssertEqual(manager.lastOutcome, .pending)
        XCTAssertTrue(manager.shouldBlockAccess)
        XCTAssertEqual(recording.events(named: .subscriptionPurchaseStarted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionPurchaseSuccess).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionPurchaseCancelled).isEmpty)
        let failed = try! XCTUnwrap(recording.events(named: .subscriptionPurchaseFailed).first)
        XCTAssertEqual(failed.parameters[AnalyticsParameterKey.failureReason], "pending")
    }

    func testExpiredSubscriptionStaysGatedAfterRefresh() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.subscription = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.monthly.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(-3_600),
            isExpired: true,
            isRevoked: false,
            inGraceOrRetry: false
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .expired)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertTrue(manager.shouldBlockAccess)
    }

    func testUnavailableStoreKitFailsOpenWhenNeverResolved() async {
        store.appTransaction = .unavailable
        store.loadProductsError = NSError(domain: "test", code: 1)
        store.products = []
        await manager.start()
        XCTAssertEqual(manager.accessState, .loading)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertFalse(manager.shouldBlockAccess)
    }

    func testPreviouslyVerifiedUnsubscribedStaysGatedWhenStoreKitIsDown() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertEqual(fallbackDefaults.string(forKey: WeekFitEntitlementFallbackStore.key), "unsubscribed")

        store.appTransaction = .unavailable
        store.subscription = nil
        await manager.refresh()
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertTrue(manager.shouldBlockAccess)
    }

    func testReviewDemoDoesNotGrantAccessByItself() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertTrue(manager.shouldBlockAccess)
        XCTAssertFalse(WeekFitEntitlementBypass.none.grantsAccess)
    }

    func testPreviouslyVerifiedSubscribedKeepsAccessWhenStoreKitIsDown() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        store.subscription = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.monthly.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            inGraceOrRetry: false
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .subscribed)
        XCTAssertEqual(fallbackDefaults.string(forKey: WeekFitEntitlementFallbackStore.key), "subscribed")

        store.appTransaction = .unavailable
        store.subscription = nil
        await manager.refresh()
        XCTAssertEqual(manager.accessState, .subscribed)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertFalse(manager.shouldBlockAccess)
    }

    func testLoadingFailOpenTimesOutToPaywallForNeverVerifiedInstall() async {
        store.appTransaction = .unavailable
        manager = SubscriptionManager(
            store: store,
            bypassProvider: { .none },
            fallbackStore: WeekFitEntitlementFallbackStore(defaults: fallbackDefaults),
            failOpenTimeout: .milliseconds(80)
        )
        await manager.start()
        XCTAssertEqual(manager.accessState, .loading)
        XCTAssertTrue(manager.hasFullAccess)

        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertTrue(manager.shouldBlockAccess)
    }

    func testRefreshCapturesStorefrontFromSameProductLoad() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "Sandbox"
        )
        store.storefront = WeekFitStorefrontSnapshot(countryCode: "USA", id: "143441")
        await manager.start()
        XCTAssertEqual(manager.storefrontCountryCode, "USA")
        XCTAssertEqual(manager.storefrontID, "143441")
        XCTAssertEqual(manager.lastStoreProductsReturnedCount, 2)
        XCTAssertEqual(manager.annualProduct?.currencyCode, "EUR")
        XCTAssertEqual(manager.annualProduct?.displayPrice, "€34.99")
    }

    func testMonthlyPurchaseUsesMonthlyProductID() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "test"
        )
        await manager.start()
        manager.selectProduct(WeekFitSubscriptionProductID.monthly.rawValue)
        await manager.purchaseSelected()
        XCTAssertEqual(store.purchaseCalls, [WeekFitSubscriptionProductID.monthly.rawValue])
    }

    func testStorefrontChangeReloadsProductsAndKeepsSelection() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "Sandbox"
        )
        store.storefront = WeekFitStorefrontSnapshot(countryCode: "USA", id: "143441")
        store.products = [
            makeSnapshot(
                id: .annual,
                displayPrice: "$34.99",
                price: "34.99",
                currency: "USD"
            ),
            makeSnapshot(
                id: .monthly,
                displayPrice: "$4.99",
                price: "4.99",
                currency: "USD",
                periodUnit: .month
            )
        ]
        await manager.start()
        manager.selectProduct(WeekFitSubscriptionProductID.monthly.rawValue)
        XCTAssertEqual(manager.selectedProductID, WeekFitSubscriptionProductID.monthly.rawValue)
        XCTAssertEqual(manager.annualProduct?.displayPrice, "$34.99")

        store.storefront = WeekFitStorefrontSnapshot(countryCode: "POL", id: "143478")
        store.products = [
            makeSnapshot(
                id: .annual,
                displayPrice: "149,99 zł",
                price: "149.99",
                currency: "PLN"
            ),
            makeSnapshot(
                id: .monthly,
                displayPrice: "19,99 zł",
                price: "19.99",
                currency: "PLN",
                periodUnit: .month
            )
        ]
        await store.emitStorefrontUpdate()

        XCTAssertEqual(manager.annualProduct?.displayPrice, "149,99 zł")
        XCTAssertEqual(manager.monthlyProduct?.displayPrice, "19,99 zł")
        XCTAssertEqual(manager.annualProduct?.currencyCode, "PLN")
        XCTAssertEqual(manager.selectedProductID, WeekFitSubscriptionProductID.monthly.rawValue)
        XCTAssertFalse(manager.productsFailedToLoad)
        XCTAssertGreaterThanOrEqual(store.invalidateCachedProductsCount, 1)
    }

    func testFailedStorefrontReloadClearsStaleUSDPrices() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "Sandbox"
        )
        store.storefront = WeekFitStorefrontSnapshot(countryCode: "USA", id: "143441")
        store.products = [
            makeSnapshot(
                id: .annual,
                displayPrice: "$34.99",
                price: "34.99",
                currency: "USD"
            ),
            makeSnapshot(
                id: .monthly,
                displayPrice: "$4.99",
                price: "4.99",
                currency: "USD",
                periodUnit: .month
            )
        ]
        await manager.start()
        XCTAssertEqual(manager.annualProduct?.displayPrice, "$34.99")

        store.loadProductsError = NSError(domain: "test", code: 42)
        await store.emitStorefrontUpdate()

        XCTAssertTrue(manager.products.isEmpty)
        XCTAssertNil(manager.annualProduct)
        XCTAssertNil(manager.monthlyProduct)
        XCTAssertTrue(manager.productsFailedToLoad)
        XCTAssertEqual(manager.lastStoreProductsReturnedCount, 0)
        XCTAssertNil(manager.selectedProduct)
    }

    func testProductLoadingFailureDoesNotInventFallbackPrices() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "Sandbox"
        )
        store.products = []
        store.loadProductsError = NSError(domain: "test", code: 7)
        await manager.start()

        XCTAssertTrue(manager.products.isEmpty)
        XCTAssertTrue(manager.productsFailedToLoad)
        XCTAssertNil(manager.annualProduct?.displayPrice)
        XCTAssertNil(manager.monthlyProduct?.displayPrice)
    }

    func testPurchaseAfterCacheInvalidationReloadsBeforePurchase() async {
        store.appTransaction = .verified(
            originalPurchaseDate: WeekFitMonetizationCutoff.date.addingTimeInterval(86_400),
            environment: "Sandbox"
        )
        await manager.start()
        let loadsAfterStart = store.loadProductsCallCount
        store.invalidateCachedProducts()
        manager.selectProduct(WeekFitSubscriptionProductID.annual.rawValue)
        await manager.purchaseSelected()
        XCTAssertEqual(store.purchaseCalls, [WeekFitSubscriptionProductID.annual.rawValue])
        XCTAssertGreaterThan(store.loadProductsCallCount, loadsAfterStart)
    }

    func testLoadingFailOpenGateStaysGatedOnLaterRefresh() async {
        store.appTransaction = .unavailable
        manager = SubscriptionManager(
            store: store,
            bypassProvider: { .none },
            fallbackStore: WeekFitEntitlementFallbackStore(defaults: fallbackDefaults),
            failOpenTimeout: .milliseconds(80)
        )
        await manager.start()
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(manager.accessState, .unsubscribed)

        await manager.refresh()
        XCTAssertEqual(manager.accessState, .unsubscribed)
        XCTAssertFalse(manager.hasFullAccess)
        XCTAssertTrue(manager.shouldBlockAccess)
    }

    private func makeSnapshot(
        id: WeekFitSubscriptionProductID,
        displayPrice: String,
        price: String,
        currency: String,
        periodUnit: WeekFitSubscriptionPeriodUnit = .year
    ) -> WeekFitProductSnapshot {
        WeekFitProductSnapshot(
            id: id.rawValue,
            displayName: id.rawValue,
            displayPrice: displayPrice,
            price: Decimal(string: price)!,
            periodUnit: periodUnit,
            periodValue: 1,
            currencyCode: currency,
            monthlyEquivalentDisplay: periodUnit == .year ? "eq" : nil,
            introductoryOffer: periodUnit == .year
                ? WeekFitIntroductoryOfferSnapshot(
                    periodValue: 1,
                    periodUnit: .week,
                    paymentMode: .free
                )
                : nil,
            introductoryOfferEligibility: periodUnit == .year ? .eligible : .ineligible
        )
    }
}
