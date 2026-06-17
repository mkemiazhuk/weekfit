import XCTest
@testable import WeekFit

final class RecoveryScoreEngineXCTests: XCTestCase {

    func testMissingPhysiologyDoesNotAddRecoveryPoints() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 450,
            timeInBedMinutes: 450,
            awakeMinutes: 0,
            awakeningsCount: 0,
            deepSleepMinutes: 75,
            remSleepMinutes: 105,
            hrvSDNN: 0,
            restingHeartRate: 0
        )

        XCTAssertEqual(breakdown.hrv, 0)
        XCTAssertEqual(breakdown.restingHeartRate, 0)
        XCTAssertEqual(breakdown.total, 80)
    }

    func testSixHourSleepWithMissingPhysiologyDoesNotReachGoodRecovery() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 360,
            timeInBedMinutes: 420,
            awakeMinutes: 60,
            awakeningsCount: 3,
            deepSleepMinutes: 60,
            remSleepMinutes: 85,
            hrvSDNN: 0,
            restingHeartRate: 0
        )

        XCTAssertLessThan(breakdown.total, 70)
    }

    func testLowHrvAndElevatedRestingHeartRateLimitRecovery() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 330,
            timeInBedMinutes: 420,
            awakeMinutes: 90,
            awakeningsCount: 4,
            deepSleepMinutes: 45,
            remSleepMinutes: 70,
            hrvSDNN: 20,
            restingHeartRate: 78
        )

        XCTAssertLessThan(breakdown.total, 60)
    }
}
