import XCTest
import StoreKit
@testable import WeekFit

@MainActor
final class WeekFitAIUsageRefreshTests: XCTestCase {
    private func snapshot(_ seconds: Int = 260) throws -> WeekFitAIUsage {
        let json = """
        {"appAccountToken":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","active":true,
         "productId":"com.weekfit.subscription.annual","periodStart":1,"periodEnd":2,
         "grandfatheredPhotos":false,"photos":{"included":30,"purchased":0},
         "voice":{"included":0,"purchased":\(seconds)}}
        """
        return try JSONDecoder().decode(WeekFitAIUsage.self, from: Data(json.utf8))
    }

    func testFailedUnfinishedDeliveryDoesNotHidePurchasedBalance() async throws {
        let value = try snapshot()
        var productLoads = 0
        let store = WeekFitAIUsageStore(loadUsage: { value }, loadProducts: {
            productLoads += 1
            return []
        }, recoverPurchases: { throw WeekFitAIUsageError.unavailable }, flushStops: {},
           isEnabled: { true }, isRefused: { false }, retryPause: {})
        await store.refresh()
        XCTAssertEqual(store.usage?.voice.purchased, 260)
        XCTAssertEqual(productLoads, 1)
        XCTAssertFalse(store.requiresSubscription)
        XCTAssertNotNil(store.message)
    }

    func testProductFailureDoesNotReportBalanceUnavailable() async throws {
        let value = try snapshot()
        let store = WeekFitAIUsageStore(loadUsage: { value },
            loadProducts: { throw URLError(.networkConnectionLost) }, recoverPurchases: { nil },
            flushStops: {}, isEnabled: { true }, isRefused: { false }, retryPause: {})
        await store.refresh()
        XCTAssertEqual(store.usage?.voice.purchased, 260)
        XCTAssertNil(store.message)
        XCTAssertFalse(store.isRefreshing)
    }

    func testTransientReadRetriesOnceAndPreservesLastBalanceOnLaterFailure() async throws {
        let value = try snapshot()
        var reads = 0
        var failAll = false
        let store = WeekFitAIUsageStore(loadUsage: {
            reads += 1
            if reads == 1 || failAll { throw URLError(.timedOut) }
            return value
        }, loadProducts: { [] }, recoverPurchases: { nil }, flushStops: {},
           isEnabled: { true }, isRefused: { false }, retryPause: {})
        await store.refresh()
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(store.usage?.voice.purchased, 260)
        XCTAssertNil(store.message)
        failAll = true
        await store.refresh()
        XCTAssertEqual(reads, 4)
        XCTAssertEqual(store.usage?.voice.purchased, 260)
        XCTAssertNotNil(store.message)
    }

    func testMissingSubscriptionIsNotRetriedAndDoesNotBlockPurchaseRecovery() async {
        var reads = 0
        var deliveries = 0
        let store = WeekFitAIUsageStore(loadUsage: {
            reads += 1
            throw WeekFitAIUsageError.subscriptionRequired
        }, loadProducts: { [] }, recoverPurchases: {
            deliveries += 1
            return nil
        }, flushStops: {}, isEnabled: { true }, isRefused: { false }, retryPause: {})
        await store.refresh()
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(deliveries, 1)
        XCTAssertTrue(store.requiresSubscription)
    }

    func testBalanceIsPublishedBeforeSlowStopRecovery() async throws {
        let value = try snapshot()
        var store: WeekFitAIUsageStore!
        store = WeekFitAIUsageStore(loadUsage: { value }, loadProducts: { [] },
            recoverPurchases: { nil }, flushStops: {
                XCTAssertEqual(store.usage?.voice.purchased, 260)
            }, isEnabled: { true }, isRefused: { false }, retryPause: {})
        await store.refresh()
    }
}
