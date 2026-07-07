import XCTest
@testable import WeekFit

/// Debug printer for manual RU copy QA — safe to run locally, always passes.
final class CoachCopySnapshotPrinterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachCopySnapshotPrinter.resetLogFile()
    }

    func testPrintAllRussianCopySnapshots() {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let report = CoachCopySnapshotPrinter.renderFullReport()
        print(report)
        CoachCopySnapshotPrinter.writeToLogFile(report)

        print("\n--- Saved to \(CoachCopySnapshotPrinter.logFileURL.path) ---\n")

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("SCENARIO: morningReadiness"))
        XCTAssertTrue(report.contains("SCENARIO: saunaRecovery"))
        XCTAssertTrue(report.contains("HYDRATION CRITICAL VARIANTS"))
        XCTAssertTrue(report.contains("STACKED DAY ACTIVE RISK OVERLAY"))
        XCTAssertTrue(report.contains("[hydrationCritical]"))
        XCTAssertTrue(report.contains("Badge:"))
        XCTAssertTrue(report.contains("Today title:"))
        XCTAssertTrue(report.contains("Coach hero:"))
    }
}
