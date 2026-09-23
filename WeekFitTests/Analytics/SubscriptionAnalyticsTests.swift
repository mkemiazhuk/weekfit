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

    func testRestoreFailedParametersDistinguishNoPurchases() {
        SubscriptionAnalytics.restoreFailed(
            source: .settings,
            requestedTab: nil,
            failureReason: .noPurchases,
            hasEntitlementAfter: false
        )
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreFailed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.failureReason], "no_purchases")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.hasEntitlementAfter], "false")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "settings")
    }

    func testRestoreFailedParametersDistinguishTimeout() {
        SubscriptionAnalytics.restoreFailed(
            source: .tab,
            requestedTab: "meals",
            failureReason: .timeout,
            hasEntitlementAfter: false
        )
        let event = try! XCTUnwrap(recording.events(named: .subscriptionRestoreFailed).first)
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.failureReason], "timeout")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "tab")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.requestedTab], "meals")
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
