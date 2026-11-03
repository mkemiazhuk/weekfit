import StoreKit
import XCTest
@testable import WeekFit

final class StoreKitTransactionAnalyticsTests: XCTestCase {
    func testRevenueIsProductionOnly() {
        XCTAssertTrue(StoreKitTransactionAnalytics.shouldLogRevenue(for: .production))
        XCTAssertFalse(StoreKitTransactionAnalytics.shouldLogRevenue(for: .sandbox))
        XCTAssertFalse(StoreKitTransactionAnalytics.shouldLogRevenue(for: .xcode))
    }

    func testPurchaseFunnelSkipsSandboxAndXcode() {
        XCTAssertTrue(StoreKitTransactionAnalytics.shouldSharePurchaseFunnel(environmentToken: nil))
        XCTAssertTrue(StoreKitTransactionAnalytics.shouldSharePurchaseFunnel(environmentToken: "production"))
        XCTAssertFalse(StoreKitTransactionAnalytics.shouldSharePurchaseFunnel(environmentToken: "sandbox"))
        XCTAssertFalse(StoreKitTransactionAnalytics.shouldSharePurchaseFunnel(environmentToken: "xcode"))
        XCTAssertFalse(StoreKitTransactionAnalytics.shouldSharePurchaseFunnel(environmentToken: "unknown"))
    }

    func testEnvironmentTokensStayStable() {
        XCTAssertEqual(StoreKitTransactionAnalytics.environmentToken(.production), "production")
        XCTAssertEqual(StoreKitTransactionAnalytics.environmentToken(.sandbox), "sandbox")
        XCTAssertEqual(StoreKitTransactionAnalytics.environmentToken(.xcode), "xcode")
    }
}
