import XCTest
@testable import WeekFit

final class WidgetDeepLinkTests: XCTestCase {
    @MainActor
    func testRequestRootTabSetsPendingToday() {
        let session = AppSessionState()
        session.requestRootTab(.today)
        XCTAssertEqual(session.consumePendingRootTab(), .today)
        XCTAssertNil(session.consumePendingRootTab())
    }

    func testWidgetPublisherKind() {
        XCTAssertEqual(WidgetSnapshotPublisher.widgetKind, "WeekFitHomeWidget")
    }
}
