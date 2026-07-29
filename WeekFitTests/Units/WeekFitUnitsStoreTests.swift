import XCTest
@testable import WeekFit

@MainActor
final class WeekFitUnitsStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: WeekFitUnitsStore.storageKey)
        WeekFitUnitsStore.shared._testReloadFromUserDefaults()
    }

    func testDefaultFallsBackToAutomatic() {
        XCTAssertEqual(WeekFitUnitsStore.shared.selectedPreference, .automatic)
    }

    func testSetPreferencePersistsMetric() {
        WeekFitUnitsStore.shared.setSelectedPreference(.metric)
        XCTAssertEqual(WeekFitUnitsStore.shared.selectedPreference, .metric)

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: WeekFitUnitsStore.storageKey),
            WeekFitUnitPreference.metric.rawValue
        )
    }
}

