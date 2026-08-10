import XCTest
@testable import WeekFit

final class AppDistributionTests: XCTestCase {
    func testDebugBuildResolvesToDebug() {
        let distribution = AppDistribution.resolve(
            isDebugBuild: true,
            receiptURL: URL(fileURLWithPath: "/receipts/receipt")
        )
        XCTAssertEqual(distribution, .debug)
        XCTAssertEqual(distribution.analyticsValue, "debug")
    }

    func testSandboxReceiptResolvesToTestFlight() {
        let receipt = URL(fileURLWithPath: "/private/var/receipts/sandboxReceipt")
        let distribution = AppDistribution.resolve(
            isDebugBuild: false,
            receiptURL: receipt
        )
        XCTAssertEqual(distribution, .testFlight)
        XCTAssertEqual(distribution.analyticsValue, "testflight")
    }

    func testProductionReceiptResolvesToAppStore() {
        let receipt = URL(fileURLWithPath: "/private/var/receipts/receipt")
        let distribution = AppDistribution.resolve(
            isDebugBuild: false,
            receiptURL: receipt
        )
        XCTAssertEqual(distribution, .appStore)
        XCTAssertEqual(distribution.analyticsValue, "appstore")
    }

    func testMissingReceiptResolvesToAppStoreInRelease() {
        let distribution = AppDistribution.resolve(
            isDebugBuild: false,
            receiptURL: nil
        )
        XCTAssertEqual(distribution, .appStore)
    }

    func testCurrentMatchesCompileConfiguration() {
        #if DEBUG
        XCTAssertEqual(AppDistribution.current, .debug)
        #else
        XCTAssertTrue(
            AppDistribution.current == .testFlight || AppDistribution.current == .appStore
        )
        #endif
    }
}
