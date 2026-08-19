import XCTest
@testable import WeekFit

@MainActor
final class RecordingWeekFitStoreKitService: WeekFitStoreKitServicing {
    var appTransaction: WeekFitAppTransactionStatus = .unavailable
    var products: [WeekFitProductSnapshot] = []
    var subscription: WeekFitSubscriptionSnapshot?
    var purchaseOutcome: WeekFitPurchaseOutcome = .success
    var restoreError: Error?
    var purchaseCalls: [String] = []
    var restoreCount = 0
    var loadProductsError: Error?

    func loadAppTransaction() async -> WeekFitAppTransactionStatus { appTransaction }

    func loadProducts() async throws -> [WeekFitProductSnapshot] {
        if let loadProductsError { throw loadProductsError }
        return products
    }

    func loadCurrentSubscription() async -> WeekFitSubscriptionSnapshot? { subscription }

    func purchase(productID: String) async -> WeekFitPurchaseOutcome {
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
                monthlyEquivalentDisplay: "€2.92",
                introductoryOffer: WeekFitIntroductoryOfferSnapshot(periodValue: 1, periodUnit: .week)
            ),
            WeekFitProductSnapshot(
                id: WeekFitSubscriptionProductID.monthly.rawValue,
                displayName: "Monthly",
                displayPrice: "€4.99",
                price: Decimal(string: "4.99")!,
                periodUnit: .month,
                monthlyEquivalentDisplay: nil,
                introductoryOffer: nil
            )
        ]
        manager = SubscriptionManager(
            store: store,
            bypassProvider: { .none },
            fallbackStore: WeekFitEntitlementFallbackStore(defaults: fallbackDefaults)
        )
    }

    override func tearDown() {
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
        await manager.restorePurchases()
        XCTAssertEqual(store.restoreCount, 1)
        XCTAssertEqual(manager.accessState, .subscribed)
        XCTAssertTrue(manager.hasFullAccess)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreStarted).count, 1)
        XCTAssertEqual(recording.events(named: .subscriptionRestoreSuccess).count, 1)
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
}
