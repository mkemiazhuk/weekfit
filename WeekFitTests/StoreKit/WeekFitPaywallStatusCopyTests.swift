import XCTest
@testable import WeekFit

final class WeekFitPaywallStatusCopyTests: XCTestCase {
    func testRestoreNothingToRestoreShowsNoneFound() {
        let message = WeekFitPaywallStatusCopy.restoreMessage(
            outcome: .nothingToRestore,
            source: .restore
        )
        XCTAssertEqual(message, WeekFitLocalizedString("paywall.restore.noneFound"))
        XCTAssertNil(
            WeekFitPaywallStatusCopy.purchaseMessage(
                outcome: .nothingToRestore,
                source: .restore
            )
        )
    }

    func testRestoreFailedShowsError() {
        let message = WeekFitPaywallStatusCopy.restoreMessage(
            outcome: .failed,
            source: .restore
        )
        XCTAssertEqual(message, WeekFitLocalizedString("paywall.error.failed"))
    }

    func testRestoreCancelledShowsNoMessage() {
        XCTAssertNil(
            WeekFitPaywallStatusCopy.restoreMessage(
                outcome: .cancelled,
                source: .restore
            )
        )
    }

    func testRestoreSuccessShowsNoMessage() {
        XCTAssertNil(
            WeekFitPaywallStatusCopy.restoreMessage(
                outcome: .success,
                source: .restore
            )
        )
    }

    func testPurchaseFailedDoesNotAppearInRestoreSlot() {
        XCTAssertNil(
            WeekFitPaywallStatusCopy.restoreMessage(
                outcome: .failed,
                source: .purchase
            )
        )
        let purchase = WeekFitPaywallStatusCopy.purchaseMessage(
            outcome: .failed,
            source: .purchase
        )
        XCTAssertEqual(purchase, WeekFitLocalizedString("paywall.error.failed"))
    }

    func testPurchasePendingDoesNotAppearInRestoreSlot() {
        XCTAssertNil(
            WeekFitPaywallStatusCopy.restoreMessage(
                outcome: .pending,
                source: .purchase
            )
        )
        XCTAssertEqual(
            WeekFitPaywallStatusCopy.purchaseMessage(
                outcome: .pending,
                source: .purchase
            ),
            WeekFitLocalizedString("paywall.error.pending")
        )
    }
}
