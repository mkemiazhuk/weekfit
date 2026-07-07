import XCTest
@testable import WeekFit

final class CoachTomorrowProtectionPolicyTests: XCTestCase {

    func testHeavyDayAfternoonStillProtects() {
        XCTAssertTrue(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .afternoon,
                tomorrowDemand: .hard,
                dayLoadBand: .heavy
            )
        )
    }

    func testModerateDayAfternoonDoesNotProtect() {
        XCTAssertFalse(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .afternoon,
                tomorrowDemand: .hard,
                dayLoadBand: .moderate
            )
        )
    }

    func testModerateDayEveningProtectsForTomorrowTraining() {
        XCTAssertTrue(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .evening,
                tomorrowDemand: .moderate,
                dayLoadBand: .moderate
            )
        )
    }

    func testFreshDayEveningDoesNotProtect() {
        XCTAssertFalse(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .evening,
                tomorrowDemand: .hard,
                dayLoadBand: .fresh
            )
        )
    }

    func testEasyTomorrowDemandDoesNotProtect() {
        XCTAssertFalse(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .evening,
                tomorrowDemand: .easy,
                dayLoadBand: .heavy
            )
        )
    }

    func testNoTomorrowDemandDoesNotProtect() {
        XCTAssertFalse(
            CoachTomorrowProtectionPolicy.shouldProtect(
                timeOfDay: .evening,
                tomorrowDemand: .none,
                dayLoadBand: .heavy
            )
        )
    }
}
