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

    func testTemporaryStoreKitPaywallDiagnosticsHiddenOnAppStore() {
        XCTAssertFalse(AppDistribution.appStore.showsTemporaryStoreKitPaywallDiagnostics)
        XCTAssertTrue(AppDistribution.testFlight.showsTemporaryStoreKitPaywallDiagnostics)
        XCTAssertTrue(AppDistribution.debug.showsTemporaryStoreKitPaywallDiagnostics)
    }

    func testDiagnosticsFormatterUsesPaywallSnapshotsNotFallbackPrices() {
        let annual = WeekFitProductSnapshot(
            id: WeekFitSubscriptionProductID.annual.rawValue,
            displayName: "Annual",
            displayPrice: "149,99 zł",
            price: Decimal(string: "149.99")!,
            periodUnit: .year,
            periodValue: 1,
            currencyCode: "PLN",
            monthlyEquivalentDisplay: "12,50 zł",
            introductoryOffer: nil
        )
        let text = WeekFitStoreKitPaywallDiagnosticsFormatter.text(
            distribution: .testFlight,
            appVersion: "1.3",
            appBuild: "42",
            storefrontCountryCode: "POL",
            storefrontID: "143478",
            rawReturnedCount: 2,
            products: [annual],
            productsFailedToLoad: false
        )
        XCTAssertTrue(text.contains("Country: POL"))
        XCTAssertTrue(text.contains("ID: 143478"))
        XCTAssertTrue(text.contains("Display price: 149,99 zł"))
        XCTAssertTrue(text.contains("Currency: PLN"))
        XCTAssertTrue(text.contains("Numeric price: 149.99"))
        XCTAssertTrue(text.contains("Period: 1 year"))
        XCTAssertTrue(text.contains("Price source: StoreKit Product snapshots"))
        XCTAssertFalse(text.contains("$34.99"))
        XCTAssertFalse(text.contains("4.99"))
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
