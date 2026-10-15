import XCTest
@testable import WeekFit

@MainActor
final class SubscriptionLifecycleAnalyticsTests: XCTestCase {
    private var recording: RecordingAnalyticsService!
    private var lifecycleSuite: String!
    private var lifecycleDefaults: UserDefaults!
    private var consentSuite: String!
    private var consentDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)

        lifecycleSuite = "weekfit.tests.lifecycle.\(UUID().uuidString)"
        lifecycleDefaults = UserDefaults(suiteName: lifecycleSuite)!
        lifecycleDefaults.removePersistentDomain(forName: lifecycleSuite)
        SubscriptionLifecycleAnalytics.setDefaultsForTests(lifecycleDefaults)
        SubscriptionLifecycleAnalytics.setAnalyticsForTests(recording)

        consentSuite = "weekfit.tests.consent.\(UUID().uuidString)"
        consentDefaults = UserDefaults(suiteName: consentSuite)!
        consentDefaults.removePersistentDomain(forName: consentSuite)
        ProductAnalyticsConsent.setDefaultsForTests(consentDefaults)
        ProductAnalyticsConsent.resetForTests()
    }

    override func tearDown() {
        SubscriptionLifecycleAnalytics.resetForTests()
        ProductAnalyticsConsent.resetForTests()
        ProductAnalyticsConsent.useStandardDefaultsForTests()
        AppAnalytics.resetSharedForTests()
        recording = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func trialActive(willAutoRenew: Bool) -> WeekFitSubscriptionSnapshot {
        WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: true,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            billingState: WeekFitSubscriptionBillingState.none,
            willAutoRenew: willAutoRenew,
            isRenewalInfoVerified: true
        )
    }

    private func paidActive(
        productID: String = WeekFitSubscriptionProductID.annual.rawValue,
        willAutoRenew: Bool
    ) -> WeekFitSubscriptionSnapshot {
        WeekFitSubscriptionSnapshot(
            productID: productID,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400 * 30),
            isExpired: false,
            isRevoked: false,
            billingState: WeekFitSubscriptionBillingState.none,
            willAutoRenew: willAutoRenew,
            isRenewalInfoVerified: true
        )
    }

    private func ordinaryExpired(
        productID: String = WeekFitSubscriptionProductID.annual.rawValue,
        wasTrial: Bool
    ) -> WeekFitSubscriptionSnapshot {
        WeekFitSubscriptionSnapshot(
            productID: productID,
            isIntroductoryTrial: wasTrial,
            expirationDate: Date().addingTimeInterval(-60),
            isExpired: true,
            isRevoked: false,
            billingState: WeekFitSubscriptionBillingState.none,
            willAutoRenew: false,
            isRenewalInfoVerified: true
        )
    }

    private func establishBaseline(_ snapshot: WeekFitSubscriptionSnapshot) {
        SubscriptionLifecycleAnalytics.observe(subscription: snapshot, refreshSource: "start")
        recording.reset()
    }

    // MARK: - Baseline

    func testFirstObservationEstablishesBaselineWithoutEvents() {
        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: true),
            refreshSource: "start"
        )
        XCTAssertTrue(recording.recordedEvents.isEmpty)
        XCTAssertEqual(
            SubscriptionLifecycleAnalytics.persistedObservationForTests()?.baselineEstablished,
            true
        )
    }

    func testRepeatedRefreshDoesNotDuplicate() {
        let active = trialActive(willAutoRenew: true)
        establishBaseline(active)

        for _ in 0..<5 {
            SubscriptionLifecycleAnalytics.observe(subscription: active, refreshSource: "foreground")
            SubscriptionLifecycleAnalytics.observe(subscription: active, refreshSource: "refresh")
        }

        XCTAssertTrue(recording.recordedEvents.isEmpty)
    }

    // MARK: - Trial → disable renew → expire → re-enable

    func testTrialSignupThenDisableRenewalKeepsAccessSeparateFromPurchaseCancel() {
        establishBaseline(trialActive(willAutoRenew: true))

        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: false),
            refreshSource: "foreground"
        )

        let disabled = recording.events(named: .subscriptionAutoRenewDisabled)
        XCTAssertEqual(disabled.count, 1)
        XCTAssertEqual(disabled.first?.parameters[AnalyticsParameterKey.subscriptionPhase], "trial")
        XCTAssertEqual(
            disabled.first?.parameters[AnalyticsParameterKey.productID],
            WeekFitSubscriptionProductID.annual.rawValue
        )
        XCTAssertEqual(disabled.first?.parameters[AnalyticsParameterKey.source], "foreground")
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionPurchaseCancelled).isEmpty)
    }

    func testTrialExpirationAfterDisabledRenewal() {
        establishBaseline(trialActive(willAutoRenew: true))
        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: false),
            refreshSource: "foreground"
        )
        recording.reset()

        SubscriptionLifecycleAnalytics.observe(
            subscription: ordinaryExpired(wasTrial: true),
            refreshSource: "transaction.updates"
        )

        let expired = recording.events(named: .subscriptionExpired)
        XCTAssertEqual(expired.count, 1)
        XCTAssertEqual(expired.first?.parameters[AnalyticsParameterKey.subscriptionPhase], "trial")
        XCTAssertEqual(expired.first?.parameters[AnalyticsParameterKey.source], "transaction_updates")
        XCTAssertTrue(recording.events(named: .subscriptionAutoRenewDisabled).isEmpty)
    }

    func testReEnableThenDisableAgainEmitsThreeAutoRenewEvents() {
        establishBaseline(trialActive(willAutoRenew: true))

        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: false),
            refreshSource: "foreground"
        )
        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: true),
            refreshSource: "foreground"
        )
        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: false),
            refreshSource: "foreground"
        )

        XCTAssertEqual(recording.events(named: .subscriptionAutoRenewDisabled).count, 2)
        XCTAssertEqual(recording.events(named: .subscriptionAutoRenewEnabled).count, 1)
    }

    // MARK: - Unknown / unverified / grace / retry

    func testUnverifiedRenewalDoesNotEmitAutoRenewTransitions() {
        let unverifiedOn = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            willAutoRenew: true,
            isRenewalInfoVerified: false
        )
        let unverifiedOff = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(86_400),
            isExpired: false,
            isRevoked: false,
            willAutoRenew: false,
            isRenewalInfoVerified: false
        )
        establishBaseline(unverifiedOn)
        SubscriptionLifecycleAnalytics.observe(subscription: unverifiedOff, refreshSource: "refresh")
        XCTAssertTrue(recording.recordedEvents.isEmpty)
    }

    func testNilSubscriptionDoesNotExpireOrMutateBaseline() {
        let active = paidActive(willAutoRenew: true)
        establishBaseline(active)
        let before = SubscriptionLifecycleAnalytics.persistedObservationForTests()

        SubscriptionLifecycleAnalytics.observe(subscription: nil, refreshSource: "foreground")

        XCTAssertTrue(recording.recordedEvents.isEmpty)
        XCTAssertEqual(SubscriptionLifecycleAnalytics.persistedObservationForTests(), before)
    }

    func testGracePeriodIsNotOrdinaryExpiration() {
        establishBaseline(paidActive(willAutoRenew: true))

        let grace = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(-60),
            isExpired: false,
            isRevoked: false,
            billingState: .inGracePeriod,
            gracePeriodExpirationDate: Date().addingTimeInterval(86_400),
            willAutoRenew: true,
            isRenewalInfoVerified: true
        )
        SubscriptionLifecycleAnalytics.observe(subscription: grace, refreshSource: "foreground")
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
    }

    func testBillingRetryIsNotOrdinaryExpiration() {
        establishBaseline(paidActive(willAutoRenew: true))

        let retry = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(-60),
            isExpired: true,
            isRevoked: false,
            billingState: .inBillingRetry,
            willAutoRenew: true,
            isRenewalInfoVerified: true
        )
        SubscriptionLifecycleAnalytics.observe(subscription: retry, refreshSource: "foreground")
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
    }

    func testRevocationIsNotOrdinaryExpiration() {
        establishBaseline(paidActive(willAutoRenew: true))

        let revoked = WeekFitSubscriptionSnapshot(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            isIntroductoryTrial: false,
            expirationDate: Date().addingTimeInterval(-60),
            isExpired: true,
            isRevoked: true,
            billingState: WeekFitSubscriptionBillingState.none,
            willAutoRenew: false,
            isRenewalInfoVerified: true
        )
        SubscriptionLifecycleAnalytics.observe(subscription: revoked, refreshSource: "foreground")
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
    }

    // MARK: - Product switch

    func testProductSwitchDoesNotRecordOldPlanAsChurn() {
        establishBaseline(paidActive(productID: WeekFitSubscriptionProductID.monthly.rawValue, willAutoRenew: true))

        SubscriptionLifecycleAnalytics.observe(
            subscription: paidActive(
                productID: WeekFitSubscriptionProductID.annual.rawValue,
                willAutoRenew: true
            ),
            refreshSource: "purchase.success"
        )

        XCTAssertTrue(recording.events(named: .subscriptionAutoRenewDisabled).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionAutoRenewEnabled).isEmpty)
    }

    // MARK: - Consent

    func testConsentDisabledSuppressesLifecycleEvents() {
        establishBaseline(trialActive(willAutoRenew: true))
        ProductAnalyticsConsent.setSharingEnabled(false)

        SubscriptionLifecycleAnalytics.observe(
            subscription: trialActive(willAutoRenew: false),
            refreshSource: "foreground"
        )
        SubscriptionLifecycleAnalytics.observe(
            subscription: ordinaryExpired(wasTrial: true),
            refreshSource: "foreground"
        )

        XCTAssertTrue(recording.recordedEvents.isEmpty)
    }

    // MARK: - Manager integration: purchase cancel unchanged

    func testPurchaseSheetDismissalStillOnlyEmitsPurchaseCancelled() async {
        let store = RecordingWeekFitStoreKitService()
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
                introductoryOffer: nil,
                introductoryOfferEligibility: .ineligible
            )
        ]
        store.appTransaction = .verified(
            originalPurchaseDate: Date().addingTimeInterval(-86_400),
            environment: "Sandbox"
        )
        store.purchaseOutcome = .cancelled

        let suite = "weekfit.tests.lifecycle.manager.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = SubscriptionManager(
            store: store,
            fallbackStore: WeekFitEntitlementFallbackStore(defaults: defaults)
        )
        await manager.start()
        recording.reset()

        manager.selectProduct(WeekFitSubscriptionProductID.annual.rawValue)
        await manager.purchaseSelected()

        XCTAssertEqual(recording.events(named: .subscriptionPurchaseCancelled).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionAutoRenewDisabled).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionExpired).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionAutoRenewEnabled).isEmpty)
    }
}
