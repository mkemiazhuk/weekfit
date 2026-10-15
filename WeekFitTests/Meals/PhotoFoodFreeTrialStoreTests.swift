import XCTest
@testable import WeekFit

final class PhotoFoodFreeTrialStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhotoFoodFreeTrialStore.resetForTesting()
    }

    override func tearDown() {
        PhotoFoodFreeTrialStore.resetForTesting()
        super.tearDown()
    }

    func testStartsWithFreeTrialRemaining() {
        XCTAssertTrue(PhotoFoodFreeTrialStore.hasRemaining)
        XCTAssertFalse(PhotoFoodFreeTrialStore.isConsumed)
    }

    func testMarkConsumedEndsFreeTrial() {
        PhotoFoodFreeTrialStore.markConsumed()
        XCTAssertFalse(PhotoFoodFreeTrialStore.hasRemaining)
        XCTAssertTrue(PhotoFoodFreeTrialStore.isConsumed)
    }

    func testPaidSubscriptionPolicyStillRequiresSubscribed() {
        // Coarse policy hint: only `.subscribed`. Runtime also requires a no-offer paid JWS.
        XCTAssertFalse(WeekFitEntitlementPolicy.canUseCloudPhotoNutritionAnalysis(for: .trial))
        XCTAssertFalse(WeekFitEntitlementPolicy.canUseCloudPhotoNutritionAnalysis(for: .legacy))
        XCTAssertFalse(WeekFitEntitlementPolicy.canUseCloudPhotoNutritionAnalysis(for: .unsubscribed))
        XCTAssertTrue(WeekFitEntitlementPolicy.canUseCloudPhotoNutritionAnalysis(for: .subscribed))
    }
}
