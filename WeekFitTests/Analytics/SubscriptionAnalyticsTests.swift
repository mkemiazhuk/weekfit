import XCTest
@testable import WeekFit

@MainActor
final class SubscriptionAnalyticsTests: XCTestCase {
    private var recording: RecordingAnalyticsService!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        SubscriptionAnalytics.resetPaywallViewDedupForTests()
    }

    override func tearDown() {
        SubscriptionAnalytics.resetPaywallViewDedupForTests()
        AppAnalytics.resetSharedForTests()
        recording = nil
        super.tearDown()
    }

    func testPaywallViewedFiresOncePerInstanceID() {
        let instanceID = "paywall-instance-1"
        SubscriptionAnalytics.paywallViewed(
            source: .tab,
            requestedTab: "coach",
            currentTab: "today",
            hasFullAccess: false,
            paywallInstanceID: instanceID
        )
        SubscriptionAnalytics.paywallViewed(
            source: .tab,
            requestedTab: "coach",
            currentTab: "today",
            hasFullAccess: false,
            paywallInstanceID: instanceID
        )

        XCTAssertEqual(recording.events(named: .paywallViewed).count, 1)
        let event = try! XCTUnwrap(recording.events(named: .paywallViewed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "tab")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.requestedTab], "coach")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.currentTab], "today")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.hasFullAccess], "false")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.paywallInstanceID], instanceID)
    }

    func testPaywallViewedAllowsDistinctPresentations() {
        SubscriptionAnalytics.paywallViewed(
            source: .tab,
            requestedTab: "meals",
            currentTab: "today",
            hasFullAccess: false,
            paywallInstanceID: "a"
        )
        SubscriptionAnalytics.paywallViewed(
            source: .settings,
            currentTab: "settings",
            hasFullAccess: false,
            paywallInstanceID: "b"
        )

        XCTAssertEqual(recording.events(named: .paywallViewed).count, 2)
    }

    func testPaywallViewDedupRingStaysBoundedAndAllowsLaterPresentations() {
        for index in 0..<12 {
            SubscriptionAnalytics.paywallViewed(
                source: .tab,
                requestedTab: "coach",
                currentTab: "today",
                hasFullAccess: false,
                paywallInstanceID: "id-\(index)"
            )
        }
        XCTAssertEqual(recording.events(named: .paywallViewed).count, 12)

        // Early IDs fall out of the ring; a later distinct presentation still fires.
        SubscriptionAnalytics.paywallViewed(
            source: .tab,
            requestedTab: "plan",
            currentTab: "today",
            hasFullAccess: false,
            paywallInstanceID: "id-later"
        )
        XCTAssertEqual(recording.events(named: .paywallViewed).count, 13)

        // Remount of the latest presentation stays deduped.
        SubscriptionAnalytics.paywallViewed(
            source: .tab,
            requestedTab: "plan",
            currentTab: "today",
            hasFullAccess: false,
            paywallInstanceID: "id-later"
        )
        XCTAssertEqual(recording.events(named: .paywallViewed).count, 13)
    }

    func testRestoreFailedParametersDistinguishTimeout() {
        SubscriptionAnalytics.restoreFinished(
            source: .tab,
            requestedTab: "meals",
            result: .timeout,
            hasEntitlementBefore: false,
            hasEntitlementAfter: false,
            error: WeekFitStoreKitRestoreTimeoutError()
        )
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreFailed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.failureReason], "timeout")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.result], "timeout")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "tab")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.requestedTab], "meals")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.errorCode], "timeout")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.errorDomain], "weekfit.storekit.restore")
        XCTAssertTrue(recording.events(named: .subscriptionRestoreCompleted).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
    }

    func testRestoreSuccessNoPurchasesIsNotFailedOrSuccess() {
        SubscriptionAnalytics.restoreFinished(
            source: .settings,
            result: .noPurchases,
            hasEntitlementBefore: false,
            hasEntitlementAfter: false
        )
        XCTAssertEqual(recording.events(named: .subscriptionRestoreCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreFailed).isEmpty)
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreCompleted).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.result], "no_purchases")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.hasEntitlementAfter], "false")
    }

    func testRestoreCancelledIsNeutralCompleted() {
        SubscriptionAnalytics.restoreFinished(
            source: .tab,
            result: .cancelled,
            hasEntitlementBefore: false,
            hasEntitlementAfter: false,
            error: CancellationError()
        )
        XCTAssertEqual(recording.events(named: .subscriptionRestoreCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreFailed).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreSuccess).isEmpty)
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreCompleted).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.result], "cancelled")
    }

    func testRestoreAccessConfirmedUsesSuccessEvent() {
        SubscriptionAnalytics.restoreFinished(
            source: .settings,
            result: .alreadyEntitled,
            hasEntitlementBefore: true,
            hasEntitlementAfter: true,
            restoredProductID: WeekFitSubscriptionProductID.annual.rawValue
        )
        XCTAssertEqual(recording.events(named: .subscriptionRestoreSuccess).count, 1)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreCompleted).isEmpty)
        XCTAssertTrue(recording.events(named: .subscriptionRestoreFailed).isEmpty)
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreSuccess).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.result], "already_entitled")
    }

    func testSanitizedErrorFieldsStripUnsafeCharacters() {
        let error = NSError(domain: "StoreKit.Evil Domain!🎉", code: 7)
        let fields = SubscriptionAnalytics.sanitizedErrorFields(from: error)
        XCTAssertEqual(fields.code, "7")
        XCTAssertEqual(fields.domain, "StoreKit.EvilDomain")
        XCTAssertFalse(fields.domain.contains(" "))
        XCTAssertFalse(fields.domain.contains("🎉"))
    }

    func testPurchaseFailedParametersDistinguishEntitlementNotPropagated() {
        SubscriptionAnalytics.purchaseFailed(
            productID: WeekFitSubscriptionProductID.annual.rawValue,
            requestedTab: "coach",
            failureReason: .entitlementNotPropagated
        )
        let event = try! XCTUnwrap(recording.events(named: .subscriptionPurchaseFailed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.failureReason], "entitlement_not_propagated")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.productID], WeekFitSubscriptionProductID.annual.rawValue)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.requestedTab], "coach")
    }

    func testPurchaseFailedParametersDistinguishVerificationFailed() {
        SubscriptionAnalytics.purchaseFailed(
            productID: WeekFitSubscriptionProductID.monthly.rawValue,
            failureReason: .verificationFailed
        )
        let event = try! XCTUnwrap(recording.events(named: .subscriptionPurchaseFailed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.failureReason], "verification_failed")
    }
}
