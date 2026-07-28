import XCTest
@testable import WeekFit

final class ProductAnalyticsFlowTrackerTests: XCTestCase {

    private var recording: RecordingAnalyticsService!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        ProductAnalyticsFlowTracker.shared.resetForTests()
        ProductScreenTracker.shared.reset()
    }

    override func tearDown() {
        ProductAnalyticsFlowTracker.shared.resetForTests()
        ProductScreenTracker.shared.reset()
        AppAnalytics.resetSharedForTests()
        recording = nil
        super.tearDown()
    }

    func testFoodCancellationEmittedOnceOnDismissBeforeSave() {
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today)
        XCTAssertTrue(ProductAnalytics.foodLoggingCancelIfNeeded())
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())

        XCTAssertEqual(recording.events(named: .foodLoggingCancelled).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingCompleted).isEmpty)
        XCTAssertEqual(
            recording.parameterValues(for: .foodLoggingCancelled, key: AnalyticsParameterKey.method),
            ["quick_log"]
        )
    }

    func testFoodCancellationNotEmittedAfterCompletion() {
        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals)
        ProductAnalytics.foodLoggingCompleted(method: .manual, source: .meals)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())

        XCTAssertEqual(recording.events(named: .foodLoggingCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingCancelled).isEmpty)
    }

    func testFoodCancellationNotEmittedAfterFailure() {
        ProductAnalytics.foodLoggingStarted(method: .barcode, source: .meals)
        ProductAnalytics.foodLoggingFailed(method: .barcode, source: .meals, reason: .saveFailed)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())

        XCTAssertEqual(recording.events(named: .foodLoggingFailed).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingCancelled).isEmpty)
    }

    func testHydrationCancellationEmittedOnce() {
        ProductAnalytics.hydrationLoggingStarted(method: .quickLog, source: .today)
        XCTAssertTrue(ProductAnalytics.hydrationLoggingCancelIfNeeded())
        XCTAssertFalse(ProductAnalytics.hydrationLoggingCancelIfNeeded())

        XCTAssertEqual(recording.events(named: .hydrationLoggingCancelled).count, 1)
    }

    func testHydrationCancellationNotEmittedAfterCompletion() {
        ProductAnalytics.hydrationLoggingStarted(method: .quickLog, source: .today)
        ProductAnalytics.hydrationLoggingCompleted(method: .quickLog, source: .today)
        XCTAssertFalse(ProductAnalytics.hydrationLoggingCancelIfNeeded())
        XCTAssertTrue(recording.events(named: .hydrationLoggingCancelled).isEmpty)
    }

    func testHydrationCancellationNotEmittedAfterFailure() {
        ProductAnalytics.hydrationLoggingStarted(method: .manual, source: .today)
        ProductAnalytics.hydrationLoggingFailed(method: .manual, source: .today, reason: .saveFailed)
        XCTAssertFalse(ProductAnalytics.hydrationLoggingCancelIfNeeded())
        XCTAssertTrue(recording.events(named: .hydrationLoggingCancelled).isEmpty)
    }

    func testActivitySheetCancelNotEmittedAfterStart() {
        ProductAnalytics.activityLoggingStarted(source: .today)
        ProductAnalytics.activityStarted(category: .running, source: .today)
        XCTAssertFalse(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertTrue(recording.events(named: .activityCancelled).isEmpty)
    }

    func testActivitySheetCancelEmittedOnceWhenDismissedBeforeStart() {
        ProductAnalytics.activityLoggingStarted(source: .today)
        XCTAssertTrue(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertFalse(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertEqual(recording.events(named: .activityCancelled).count, 1)
    }

    func testNoDuplicateTerminalWhenExplicitCancelThenDismiss() {
        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals)
        ProductAnalytics.foodLoggingCancelled(method: .manual, source: .meals)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())
        XCTAssertEqual(recording.events(named: .foodLoggingCancelled).count, 1)
    }
}
