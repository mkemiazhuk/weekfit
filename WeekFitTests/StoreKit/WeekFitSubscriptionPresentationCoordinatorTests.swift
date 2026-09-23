import XCTest
@testable import WeekFit

final class WeekFitSubscriptionPresentationCoordinatorTests: XCTestCase {

    func testCanPresentOnlyWhenNoModalOwnsTheSlot() {
        XCTAssertTrue(
            WeekFitSubscriptionPresentationCoordinator.canPresentRootSubscriptionUI(
                isSettingsPresented: false,
                isOnboardingPresented: false,
                isHealthAccessPresented: false,
                isFeaturePaywallPresented: false,
                isLegacyThanksPresented: false
            )
        )

        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.canPresentRootSubscriptionUI(
                isSettingsPresented: true,
                isOnboardingPresented: false,
                isHealthAccessPresented: false,
                isFeaturePaywallPresented: false,
                isLegacyThanksPresented: false
            )
        )

        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.canPresentRootSubscriptionUI(
                isSettingsPresented: false,
                isOnboardingPresented: false,
                isHealthAccessPresented: false,
                isFeaturePaywallPresented: true,
                isLegacyThanksPresented: false
            )
        )

        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.canPresentRootSubscriptionUI(
                isSettingsPresented: false,
                isOnboardingPresented: false,
                isHealthAccessPresented: false,
                isFeaturePaywallPresented: false,
                isLegacyThanksPresented: true
            )
        )
    }

    func testLegacyThanksIsIdempotentWhileAlreadyPresented() {
        // Re-requesting while the binding is already true is what spam-logs
        // "only presenting a single sheet is supported" on every refresh.
        XCTAssertEqual(
            WeekFitSubscriptionPresentationCoordinator.legacyThanksAction(
                isEligible: true,
                isAlreadyPresented: true,
                canPresent: true
            ),
            .idle
        )
    }

    func testLegacyThanksDefersWhileSettingsOccupiesSheetSlot() {
        XCTAssertEqual(
            WeekFitSubscriptionPresentationCoordinator.legacyThanksAction(
                isEligible: true,
                isAlreadyPresented: false,
                canPresent: false
            ),
            .deferUntilClear
        )
    }

    func testLegacyThanksPresentsWhenEligibleAndSlotIsFree() {
        XCTAssertEqual(
            WeekFitSubscriptionPresentationCoordinator.legacyThanksAction(
                isEligible: true,
                isAlreadyPresented: false,
                canPresent: true
            ),
            .present
        )
    }

    func testLegacyThanksIdleWhenNotEligible() {
        XCTAssertEqual(
            WeekFitSubscriptionPresentationCoordinator.legacyThanksAction(
                isEligible: false,
                isAlreadyPresented: false,
                canPresent: true
            ),
            .idle
        )
    }

    func testFeaturePaywallDoesNotOpenOverSettingsOrLegacyThanks() {
        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
                desired: true,
                isSettingsPresented: true,
                isLegacyThanksPresented: false
            )
        )
        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
                desired: true,
                isSettingsPresented: false,
                isLegacyThanksPresented: true
            )
        )
        XCTAssertTrue(
            WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
                desired: true,
                isSettingsPresented: false,
                isLegacyThanksPresented: false
            )
        )
        XCTAssertFalse(
            WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
                desired: false,
                isSettingsPresented: false,
                isLegacyThanksPresented: false
            )
        )
    }

    func testDeferredFeaturePaywallStillReconcilesAfterSettingsClears() {
        // Gate suppresses presentation while Settings is open…
        let whileSettings = WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
            desired: true,
            isSettingsPresented: true,
            isLegacyThanksPresented: false
        )
        XCTAssertFalse(whileSettings)

        // …but premium-tab reconcile still keeps the pending tab so purchase /
        // dismiss of Settings can open the paywall or destination afterward.
        let afterSettings = WeekFitPremiumTabGate.reconcile(
            selectedTab: .today,
            pendingTab: .coach,
            hasResolved: true,
            hasFullAccess: false,
            isPaywallPresented: false
        )
        XCTAssertEqual(afterSettings.pendingTab, .coach)
        XCTAssertTrue(afterSettings.presentPaywall)
        XCTAssertTrue(
            WeekFitSubscriptionPresentationCoordinator.shouldPresentFeaturePaywall(
                desired: afterSettings.presentPaywall,
                isSettingsPresented: false,
                isLegacyThanksPresented: false
            )
        )
    }
}
