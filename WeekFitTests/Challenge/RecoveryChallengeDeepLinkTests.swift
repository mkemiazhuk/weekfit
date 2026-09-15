import XCTest
@testable import WeekFit
import WeekFitWidgetShared

final class RecoveryChallengeDeepLinkTests: XCTestCase {

    func testRecoveryChallengeURLParsing() {
        let url = WeekFitWidgetDeepLink.recoveryChallengeURL
        XCTAssertEqual(url.absoluteString, "weekfit://challenge/recovery7")
        XCTAssertTrue(WeekFitWidgetDeepLink.isRecoveryChallengeURL(url))
        XCTAssertTrue(
            WeekFitWidgetDeepLink.isRecoveryChallengeURL(
                URL(string: "weekfit://challenge/recovery7/")!
            )
        )
        XCTAssertTrue(
            WeekFitWidgetDeepLink.isRecoveryChallengeURL(
                URL(string: "weekfit://recovery7")!
            )
        )
        XCTAssertFalse(WeekFitWidgetDeepLink.isRecoveryChallengeURL(WeekFitWidgetDeepLink.todayURL))
        XCTAssertFalse(
            WeekFitWidgetDeepLink.isRecoveryChallengeURL(URL(string: "https://weekfit.app/challenge")!)
        )
    }

    @MainActor
    func testPendingOpenSurvivesUntilConsumed() {
        PendingRecoveryChallengeOpen.shared.resetForTests()
        PendingRecoveryChallengeOpen.shared.requestOpen()
        XCTAssertTrue(PendingRecoveryChallengeOpen.shared.shouldOpen)

        let session = AppSessionState()
        session.requestRootTab(.coach)
        XCTAssertEqual(session.consumePendingRootTab(), .coach)

        // Pending challenge flag remains until Coach consumes it after onboarding.
        XCTAssertTrue(PendingRecoveryChallengeOpen.shared.shouldOpen)
        XCTAssertTrue(PendingRecoveryChallengeOpen.shared.consume())
        XCTAssertFalse(PendingRecoveryChallengeOpen.shared.shouldOpen)
        XCTAssertFalse(PendingRecoveryChallengeOpen.shared.consume())
    }
}
