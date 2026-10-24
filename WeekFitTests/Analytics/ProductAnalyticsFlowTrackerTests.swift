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
        PhotoFoodAnalytics.resetForTests()
    }

    override func tearDown() {
        ProductAnalyticsFlowTracker.shared.resetForTests()
        ProductScreenTracker.shared.reset()
        PhotoFoodAnalytics.resetForTests()
        AppAnalytics.resetSharedForTests()
        recording = nil
        super.tearDown()
    }

    func testFoodCancellationEmittedOnceOnDismissBeforeSave() {
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today, operation: .diary)
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
        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals, operation: .library)
        ProductAnalytics.foodLoggingCompleted(method: .manual, source: .meals, operation: .library)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())

        XCTAssertEqual(recording.events(named: .foodLoggingCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingCancelled).isEmpty)
    }

    func testFoodCancellationNotEmittedAfterFailure() {
        ProductAnalytics.foodLoggingStarted(method: .barcode, source: .meals, operation: .library)
        ProductAnalytics.foodLoggingFailed(method: .barcode, source: .meals, operation: .library, reason: .saveFailed)
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
        ProductAnalytics.activityStarted(source: .today)
        XCTAssertFalse(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertTrue(recording.events(named: .activityCancelled).isEmpty)
    }

    func testActivitySheetCancelEmittedOnceWhenDismissedBeforeStart() {
        ProductAnalytics.activityLoggingStarted(source: .today)
        XCTAssertTrue(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertFalse(ProductAnalytics.activityLoggingCancelIfNeeded())
        XCTAssertEqual(recording.events(named: .activityCancelled).count, 1)
    }

    func testPhotoScanInsideOpenFoodFlowDoesNotStartAnotherFlow() {
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today, operation: .diary)
        PhotoFoodAnalytics.scanStarted(method: .camera)
        PhotoFoodAnalytics.scanFailed(method: .camera, reason: .unknown)

        XCTAssertEqual(recording.events(named: .foodLoggingStarted).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingFailed).isEmpty)
        XCTAssertEqual(recording.events(named: .foodPhotoScanStarted).count, 1)
        XCTAssertEqual(recording.events(named: .foodPhotoScanFailed).count, 1)
        XCTAssertTrue(ProductAnalytics.foodLoggingCancelIfNeeded())
    }

    func testDiaryAndLibraryBarcodeCompletionsStayDistinct() {
        ProductAnalytics.foodLoggingCompleted(method: .barcode, source: .meals, operation: .library)
        ProductAnalytics.foodLoggingCompleted(method: .barcode, source: .today, operation: .diary)

        XCTAssertEqual(
            recording.parameterValues(for: .foodLoggingCompleted, key: AnalyticsParameterKey.operation),
            ["library", "diary"]
        )
    }

    func testFoodSaveFailureThenRetryEmitsFailureAndCompletion() {
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today, operation: .diary)
        ProductAnalytics.foodLoggingFailed(
            method: .quickLog,
            source: .today,
            operation: .diary,
            reason: .saveFailed
        )
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today, operation: .diary)
        ProductAnalytics.foodLoggingCompleted(method: .quickLog, source: .today, operation: .diary)

        XCTAssertEqual(recording.events(named: .foodLoggingStarted).count, 2)
        XCTAssertEqual(recording.events(named: .foodLoggingFailed).count, 1)
        XCTAssertEqual(recording.events(named: .foodLoggingCompleted).count, 1)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())
        XCTAssertEqual(
            recording.parameterValues(for: .foodLoggingCompleted, key: AnalyticsParameterKey.operation),
            ["diary"]
        )
    }

    func testPhotoScanWithoutOpenFlowStartsAndFailsFoodLogging() {
        PhotoFoodAnalytics.scanStarted(method: .camera)
        PhotoFoodAnalytics.scanFailed(method: .camera, reason: .unavailable)

        XCTAssertEqual(recording.events(named: .foodLoggingStarted).count, 1)
        XCTAssertEqual(recording.events(named: .foodLoggingFailed).count, 1)
        XCTAssertEqual(
            recording.parameterValues(for: .foodLoggingFailed, key: AnalyticsParameterKey.method),
            ["photo"]
        )
    }

    func testNoDuplicateTerminalWhenExplicitCancelThenDismiss() {
        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals, operation: .library)
        ProductAnalytics.foodLoggingCancelled(method: .manual, source: .meals, operation: .library)
        XCTAssertFalse(ProductAnalytics.foodLoggingCancelIfNeeded())
        XCTAssertEqual(recording.events(named: .foodLoggingCancelled).count, 1)
    }
}
