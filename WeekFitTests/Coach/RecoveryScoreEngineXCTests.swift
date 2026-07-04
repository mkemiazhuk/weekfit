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
            restingHeartRate: 0,
            bedtimeDeviationMinutes: 0
        )

        XCTAssertEqual(breakdown.hrv, 0)
        XCTAssertEqual(breakdown.restingHeartRate, 0)
        XCTAssertEqual(breakdown.total, 67)
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
            restingHeartRate: 78,
            bedtimeDeviationMinutes: 90
        )

        XCTAssertLessThan(breakdown.total, 60)
    }

    func testFourHourFiftySevenMinuteSleepWithStrongSignalsStaysBelowWellRecovered() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 297,
            timeInBedMinutes: 300,
            awakeMinutes: 3,
            awakeningsCount: 1,
            deepSleepMinutes: 45,
            remSleepMinutes: 77,
            hrvSDNN: 49,
            restingHeartRate: 68,
            bedtimeDeviationMinutes: 0
        )

        XCTAssertLessThan(breakdown.total, 70)
    }

    func testFiveHourSixteenMinuteSleepWithElevatedPulseAndLowHRVReflectsStress() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 316,
            timeInBedMinutes: 318,
            awakeMinutes: 1,
            awakeningsCount: 1,
            deepSleepMinutes: 48,
            remSleepMinutes: 70,
            hrvSDNN: 26,
            restingHeartRate: 68,
            bedtimeDeviationMinutes: 277
        )

        XCTAssertLessThan(breakdown.total, 60)
        XCTAssertEqual(
            RecoveryScoreEngine.statusTier(
                score: breakdown.total,
                sleepMinutes: 316,
                restingHeartRate: 68,
                hrvSDNN: 26
            ),
            .takeItEasier
        )
    }

    func testFiveHourSleepWithGoodSignalsProducesModerateRecovery() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 300,
            timeInBedMinutes: 315,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 50,
            remSleepMinutes: 70,
            hrvSDNN: 50,
            restingHeartRate: 68,
            bedtimeDeviationMinutes: 80
        )

        XCTAssertLessThan(breakdown.total, 70)
        XCTAssertGreaterThanOrEqual(breakdown.total, 55)
    }

    func testFiveHourSleepWithPoorContinuityScoresLowerThanGoodContinuity() {
        let goodContinuity = RecoveryScoreEngine.calculate(
            sleepMinutes: 300,
            timeInBedMinutes: 315,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 50,
            remSleepMinutes: 70,
            hrvSDNN: 50,
            restingHeartRate: 68,
            bedtimeDeviationMinutes: 80
        )

        let poorContinuity = RecoveryScoreEngine.calculate(
            sleepMinutes: 300,
            timeInBedMinutes: 390,
            awakeMinutes: 75,
            awakeningsCount: 5,
            deepSleepMinutes: 50,
            remSleepMinutes: 70,
            hrvSDNN: 50,
            restingHeartRate: 68,
            bedtimeDeviationMinutes: 80
        )

        XCTAssertLessThan(poorContinuity.total, goodContinuity.total)
        XCTAssertLessThan(poorContinuity.total, 70)
    }

    func testSevenAndHalfToEightHourSleepWithGoodSignalsProducesHighRecovery() {
        let sevenHalfHours = RecoveryScoreEngine.calculate(
            sleepMinutes: 450,
            timeInBedMinutes: 460,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 80,
            remSleepMinutes: 110,
            hrvSDNN: 50,
            restingHeartRate: 54,
            bedtimeDeviationMinutes: 0
        )

        let eightHours = RecoveryScoreEngine.calculate(
            sleepMinutes: 480,
            timeInBedMinutes: 490,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 85,
            remSleepMinutes: 115,
            hrvSDNN: 50,
            restingHeartRate: 54,
            bedtimeDeviationMinutes: 0
        )

        XCTAssertGreaterThanOrEqual(sevenHalfHours.total, 85)
        XCTAssertLessThanOrEqual(sevenHalfHours.total, 98)
        XCTAssertGreaterThanOrEqual(eightHours.total, 85)
        XCTAssertLessThanOrEqual(eightHours.total, 100)
    }

    func testVeryShortSleepDoesNotExceedCapEvenWithStrongHRV() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 235,
            timeInBedMinutes: 245,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 40,
            remSleepMinutes: 55,
            hrvSDNN: 55,
            restingHeartRate: 52,
            bedtimeDeviationMinutes: 0
        )

        XCTAssertLessThanOrEqual(breakdown.total, 65)
    }

    func testSleepScoreComponentsMatchTargetExample() {
        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: 300,
            timeInBedMinutes: 315,
            awakeMinutes: 5,
            awakeningsCount: 0,
            deepSleepMinutes: 50,
            remSleepMinutes: 70,
            hrvSDNN: 0,
            restingHeartRate: 0,
            bedtimeDeviationMinutes: 80
        )

        XCTAssertEqual(breakdown.total, 45)
        XCTAssertEqual(
            breakdown.sleepDuration
                + breakdown.sleepContinuity
                + breakdown.sleepQuality
                + breakdown.hrv
                + breakdown.restingHeartRate,
            breakdown.total
        )
    }

    func testBedtimeDeviationCalculationUsesCircularAverage() {
        let calendar = Calendar.current

        func bedStart(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
            calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: hour, minute: minute))!
            )!
        }

        let historical = (1...7).map { bedStart(hour: 23, minute: 0, dayOffset: -$0) }
        let current = bedStart(hour: 0, minute: 20)

        let deviation = RecoveryScoreEngine.bedtimeDeviationMinutes(
            currentBedStart: current,
            historicalBedStarts: historical,
            calendar: calendar
        )

        XCTAssertEqual(deviation, 80)
    }
}
