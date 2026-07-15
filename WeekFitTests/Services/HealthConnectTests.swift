import XCTest
import HealthKit
@testable import WeekFit

@MainActor
final class HealthConnectTests: XCTestCase {

    override func tearDown() {
        AccountSessionController.shared.resetForTests()
        UserDefaults.standard.removeObject(forKey: "weekfit.healthAccessRequested")
        super.tearDown()
    }

    func testAuthorizationReadTypesExcludeWorkoutRouteSeries() {
        let healthManager = HealthManager()
        let authTypes = healthManager.buildAuthorizationReadTypes()

        XCTAssertFalse(authTypes.contains(HKSeriesType.workoutRoute()))
        XCTAssertTrue(authTypes.contains(HKObjectType.workoutType()))
        if let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            XCTAssertFalse(authTypes.contains(biologicalSex))
        }
        if let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            XCTAssertFalse(authTypes.contains(dateOfBirth))
        }
    }

    func testBuildReadTypesIncludesCoreHealthCategories() {
        let healthManager = HealthManager()
        let types = healthManager.buildReadTypes()

        XCTAssertFalse(types.isEmpty)
        XCTAssertTrue(types.contains(HKObjectType.workoutType()))
        XCTAssertTrue(types.contains(where: { $0.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue }))
        XCTAssertTrue(types.contains(where: { $0.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }))
    }

    func testRealUserConnectRequiresRealUserAccountMode() {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.unauthenticated, reason: "test")

        let action = healthManager.beginHealthAuthorizationFromUserAction(source: "test")

        XCTAssertEqual(action, .blockedByDemoMode)
    }

    func testRealUserConnectStartsAuthorizationPrompt() {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.realUser, reason: "test")

        let action = healthManager.beginHealthAuthorizationFromUserAction(source: "test")

        XCTAssertEqual(action, .startedAuthorizationPrompt)
        XCTAssertTrue(healthManager.isHealthAuthorizationInFlight)
        XCTAssertFalse(healthManager.isHealthAccessRequested)
    }

    func testStaleRequestedFlagDoesNotBlockFreshAuthorizationAttempt() {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.realUser, reason: "test")
        UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")

        let action = healthManager.beginHealthAuthorizationFromUserAction(source: "test")

        XCTAssertEqual(action, .startedAuthorizationPrompt)
    }
}
