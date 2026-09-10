import XCTest
@testable import WeekFit

final class WeekFitPremiumTabGateTests: XCTestCase {

    func testTodayNeverRequiresPremium() {
        XCTAssertFalse(WeekFitTab.today.requiresPremium)
        XCTAssertEqual(
            WeekFitPremiumTabGate.decision(for: .today, hasResolved: true, hasFullAccess: false),
            .allow
        )
        XCTAssertEqual(
            WeekFitPremiumTabGate.decision(for: .today, hasResolved: false, hasFullAccess: false),
            .allow
        )
    }

    func testFreeUserCannotAccessPremiumTabs() {
        for tab in [WeekFitTab.coach, .meals, .calendar] {
            XCTAssertTrue(tab.requiresPremium)
            XCTAssertEqual(
                WeekFitPremiumTabGate.decision(for: tab, hasResolved: true, hasFullAccess: false),
                .presentPaywall
            )
        }
    }

    func testLegacyAndSubscriberCanAccessAllPremiumTabs() {
        for tab in [WeekFitTab.coach, .meals, .calendar] {
            XCTAssertEqual(
                WeekFitPremiumTabGate.decision(for: tab, hasResolved: true, hasFullAccess: true),
                .allow
            )
        }
    }

    func testUnresolvedEntitlementDoesNotOpenPremiumTab() {
        XCTAssertEqual(
            WeekFitPremiumTabGate.decision(for: .coach, hasResolved: false, hasFullAccess: true),
            .deferUntilResolved
        )
        XCTAssertEqual(
            WeekFitPremiumTabGate.decision(for: .meals, hasResolved: false, hasFullAccess: false),
            .deferUntilResolved
        )
    }

    func testFreeUserTapKeepsTodaySelectedAndPresentsPaywall() {
        let result = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .coach,
            hasResolved: true,
            hasFullAccess: false,
            isPaywallPresented: false
        )
        XCTAssertEqual(result.selectedTab, .today)
        XCTAssertEqual(result.pendingTab, .coach)
        XCTAssertTrue(result.presentPaywall)
    }

    func testPaywallDismissalClearsPendingViaReconcileWithoutPending() {
        let result = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: nil,
            hasResolved: true,
            hasFullAccess: false,
            isPaywallPresented: false
        )
        XCTAssertEqual(result.selectedTab, .today)
        XCTAssertNil(result.pendingTab)
        XCTAssertFalse(result.presentPaywall)
    }

    func testSuccessfulPurchaseOpensPendingTab() {
        let result = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .meals,
            hasResolved: true,
            hasFullAccess: true,
            isPaywallPresented: true
        )
        XCTAssertEqual(result.selectedTab, .meals)
        XCTAssertNil(result.pendingTab)
        XCTAssertFalse(result.presentPaywall)
    }

    func testRestoreOpensPendingPlanTab() {
        let result = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .calendar,
            hasResolved: true,
            hasFullAccess: true,
            isPaywallPresented: true
        )
        XCTAssertEqual(result.selectedTab, .calendar)
        XCTAssertNil(result.pendingTab)
        XCTAssertFalse(result.presentPaywall)
    }

    func testEntitlementLossOnPremiumTabReturnsToTodayWithoutPaywallLoop() {
        let result = WeekFitPremiumTabGate.reconcile(
            selectedTab: .coach,
            pendingTab: nil,
            hasResolved: true,
            hasFullAccess: false,
            isPaywallPresented: false
        )
        XCTAssertEqual(result.selectedTab, .today)
        XCTAssertNil(result.pendingTab)
        XCTAssertFalse(result.presentPaywall)
    }

    func testDeferredTapOpensAfterLegacyResolves() {
        let whileLoading = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .coach,
            hasResolved: false,
            hasFullAccess: true,
            isPaywallPresented: false
        )
        XCTAssertEqual(whileLoading.selectedTab, .today)
        XCTAssertEqual(whileLoading.pendingTab, .coach)
        XCTAssertFalse(whileLoading.presentPaywall)

        let afterLegacy = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .coach,
            hasResolved: true,
            hasFullAccess: true,
            isPaywallPresented: false
        )
        XCTAssertEqual(afterLegacy.selectedTab, .coach)
        XCTAssertNil(afterLegacy.pendingTab)
        XCTAssertFalse(afterLegacy.presentPaywall)
    }

    func testDeferredTapPresentsPaywallAfterFreeResolves() {
        let afterFree = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .calendar,
            hasResolved: true,
            hasFullAccess: false,
            isPaywallPresented: false
        )
        XCTAssertEqual(afterFree.selectedTab, .today)
        XCTAssertEqual(afterFree.pendingTab, .calendar)
        XCTAssertTrue(afterFree.presentPaywall)
    }

    func testRequestedTabAnalyticsIDs() {
        XCTAssertNil(WeekFitTab.today.paywallRequestedTabID)
        XCTAssertEqual(WeekFitTab.coach.paywallRequestedTabID, "coach")
        XCTAssertEqual(WeekFitTab.meals.paywallRequestedTabID, "meals")
        XCTAssertEqual(WeekFitTab.calendar.paywallRequestedTabID, "plan")
    }

    func testShippedTabsDoNotIncludeInsights() {
        XCTAssertEqual(
            WeekFitTab.allCases.map(\.paywallRequestedTabID),
            [nil, "coach", "meals", "plan"]
        )
    }
}
