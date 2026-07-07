import XCTest
@testable import WeekFit

@MainActor
final class HealthDataConnectionStateTests: XCTestCase {

    private let healthAccessRequestedKey = "weekfit.healthAccessRequested"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: healthAccessRequestedKey)
    }

    func testConnectionStateNotRequestedByDefault() {
        let manager = HealthManager()
        XCTAssertEqual(manager.healthDataConnectionState, .notRequested)
    }

    func testConnectionStateDeniedWhenRequestedButNotGranted() {
        UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
        let manager = HealthManager()
        manager.isHealthAccessGranted = false

        XCTAssertEqual(manager.healthDataConnectionState, .denied)
    }

    func testConnectionStateWaitingForDataWhenGrantedButEmpty() {
        UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
        let manager = HealthManager()
        manager.isHealthAccessGranted = true

        XCTAssertEqual(manager.healthDataConnectionState, .connectedWaitingForData)
    }

    func testConnectionStatePartialWhenActivityExistsWithoutSleep() {
        UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
        let manager = HealthManager()
        manager.isHealthAccessGranted = true
        manager.steps = 4_200

        XCTAssertEqual(manager.healthDataConnectionState, .connectedPartial)
    }

    func testConnectionStateConnectedWhenSleepExists() {
        UserDefaults.standard.set(true, forKey: healthAccessRequestedKey)
        let manager = HealthManager()
        manager.isHealthAccessGranted = true
        manager.sleepMinutes = 420

        XCTAssertEqual(manager.healthDataConnectionState, .connected)
    }
}
