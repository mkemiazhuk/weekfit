import XCTest
@testable import WeekFit

final class RecoveryScoreEngineXCTests: XCTestCase {

    private func makeBaseline(
        hrv: Double? = 42,
        rhr: Double? = 52,
        samples: Int = 14
    ) -> RecoveryPhysiologyBaseline {
        RecoveryPhysiologyBaseline(
            hrvMedian: hrv,
            hrvSampleCount: samples,
            restingHeartRateMedian: rhr,
            restingHeartRateSampleCount: samples,
            windowDays: RecoveryPhysiologyBaseline.preferredWindowDays
        )
    }

    private func makeInput(
        sleepMinutes: Int = 480,
        timeInBedMinutes: Int = 500,
        awakeMinutes: Int = 20,
        awakeningsCount: Int = 2,
        deepSleepMinutes: Int = 80,
        remSleepMinutes: Int = 110,
        hrvSDNN: Double? = 42,
        restingHeartRate: Double? = 52,
        bedtimeDeviationMinutes: Int? = 0,
        baseline: RecoveryPhysiologyBaseline? = nil,
        priorDayLoad: RecoveryPriorDayLoad? = .empty
    ) -> RecoveryScoreInput {
        RecoveryScoreInput(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            hrvSDNN: hrvSDNN,
            restingHeartRate: restingHeartRate,
            bedtimeDeviationMinutes: bedtimeDeviationMinutes,
            baseline: baseline ?? makeBaseline(),
            priorDayLoad: priorDayLoad
        )
    }

    func testNaturallyLowHRVUserIsNotPenalizedWhenStable() {
        let baseline = makeBaseline(hrv: 28, rhr: 54)
        let stableLowHRV = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 28, restingHeartRate: 54, baseline: baseline)
        )
        let suppressedLowHRV = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 22, restingHeartRate: 54, baseline: baseline)
        )

        XCTAssertGreaterThan(stableLowHRV.total, suppressedLowHRV.total)
        XCTAssertGreaterThanOrEqual(stableLowHRV.total, 80)
        XCTAssertEqual(stableLowHRV.componentSum, stableLowHRV.total)
    }

    func testHighAbsoluteHRVBelowPersonalBaselineIsPenalized() {
        let baseline = makeBaseline(hrv: 68, rhr: 50)
        let belowBaseline = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 52, restingHeartRate: 50, baseline: baseline)
        )
        let atBaseline = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 68, restingHeartRate: 50, baseline: baseline)
        )

        XCTAssertLessThan(belowBaseline.total, atBaseline.total)
        XCTAssertLessThan(belowBaseline.hrv, atBaseline.hrv)
    }

    func testElevatedRestingHeartRateVsBaselineReducesRecovery() {
        let baseline = makeBaseline(hrv: 45, rhr: 50)
        let elevated = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 45, restingHeartRate: 58, baseline: baseline)
        )
        let normal = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: 45, restingHeartRate: 50, baseline: baseline)
        )

        XCTAssertLessThan(elevated.total, normal.total)
        XCTAssertLessThan(elevated.restingHeartRate, normal.restingHeartRate)
    }

    func testMissingHRVRenormalizesWeightsInsteadOfScoringZero() {
        let withHRV = RecoveryScoreEngine.calculate(makeInput(hrvSDNN: 42, restingHeartRate: 52))
        let missingHRV = RecoveryScoreEngine.calculate(
            makeInput(hrvSDNN: nil, restingHeartRate: 52)
        )

        XCTAssertEqual(missingHRV.hrv, 0)
        XCTAssertGreaterThan(missingHRV.total, 0)
        XCTAssertGreaterThanOrEqual(missingHRV.total, withHRV.total - 20)
        XCTAssertEqual(missingHRV.confidence, .low)
        XCTAssertTrue(missingHRV.unavailableSignals.contains(.hrv))
        XCTAssertEqual(missingHRV.componentSum, missingHRV.total)
    }

    func testNinetyOnePercentEfficiencyIsNotHarshlyPenalized() {
        let continuityNight = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 488,
                timeInBedMinutes: 533,
                awakeMinutes: 45,
                awakeningsCount: 4,
                hrvSDNN: 28,
                restingHeartRate: 54,
                bedtimeDeviationMinutes: 49,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )

        XCTAssertGreaterThan(continuityNight.sleepContinuity, 10)
        XCTAssertGreaterThanOrEqual(continuityNight.total, 75)
        XCTAssertEqual(continuityNight.componentSum, continuityNight.total)
    }

    func testDeepAndRemAffectSleepArchitectureModestly() {
        let strongArchitecture = RecoveryScoreEngine.calculate(
            makeInput(deepSleepMinutes: 90, remSleepMinutes: 120)
        )
        let weakArchitecture = RecoveryScoreEngine.calculate(
            makeInput(deepSleepMinutes: 20, remSleepMinutes: 30)
        )

        XCTAssertGreaterThan(strongArchitecture.sleepArchitecture, weakArchitecture.sleepArchitecture)
        XCTAssertLessThanOrEqual(strongArchitecture.sleepArchitecture, RecoveryScoreBreakdown.maxSleepArchitectureContribution)
        XCTAssertLessThan(
            strongArchitecture.total - weakArchitecture.total,
            12
        )
    }

    func testHeavyPriorDayTrainingLoadOnlyReducesScoreWhenPhysiologyStressed() {
        let baseline = makeBaseline(hrv: 42, rhr: 52)
        let heavyLoad = RecoveryPriorDayLoad(exerciseMinutes: 95, activeCalories: 900, workoutCount: 1)

        let goodPhysiology = RecoveryScoreEngine.calculate(
            makeInput(
                hrvSDNN: 44,
                restingHeartRate: 51,
                baseline: baseline,
                priorDayLoad: heavyLoad
            )
        )
        let stressedPhysiology = RecoveryScoreEngine.calculate(
            makeInput(
                hrvSDNN: 30,
                restingHeartRate: 58,
                baseline: baseline,
                priorDayLoad: heavyLoad
            )
        )

        XCTAssertEqual(goodPhysiology.trainingLoadModifier, 0)
        XCTAssertLessThan(stressedPhysiology.trainingLoadModifier, 0)
        XCTAssertLessThan(stressedPhysiology.total, goodPhysiology.total)
    }

    func testBreakdownRowsSumToFinalScore() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 488,
                timeInBedMinutes: 533,
                awakeMinutes: 45,
                awakeningsCount: 4,
                deepSleepMinutes: 32,
                remSleepMinutes: 146,
                hrvSDNN: 28,
                restingHeartRate: 54,
                bedtimeDeviationMinutes: 49,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )

        XCTAssertEqual(breakdown.componentSum, breakdown.total)
    }

    func testVeryShortSleepDoesNotExceedCapEvenWithStrongHRV() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 235,
                timeInBedMinutes: 245,
                awakeMinutes: 5,
                awakeningsCount: 0,
                deepSleepMinutes: 40,
                remSleepMinutes: 55,
                hrvSDNN: 55,
                restingHeartRate: 50,
                bedtimeDeviationMinutes: 0,
                baseline: makeBaseline(hrv: 50, rhr: 50)
            )
        )

        XCTAssertLessThanOrEqual(breakdown.total, 65)
    }

    func testSixHourSleepWithMissingPhysiologyDoesNotReachWellRecovered() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 360,
                timeInBedMinutes: 420,
                awakeMinutes: 60,
                awakeningsCount: 3,
                deepSleepMinutes: 60,
                remSleepMinutes: 85,
                hrvSDNN: nil,
                restingHeartRate: nil,
                bedtimeDeviationMinutes: 80,
                baseline: .empty
            )
        )

        XCTAssertLessThan(breakdown.total, 85)
    }

    func testStatusTierCapsWellRecoveredWhenPhysiologyIsStressed() {
        let input = makeInput(
            sleepMinutes: 480,
            hrvSDNN: 30,
            restingHeartRate: 58,
            baseline: makeBaseline(hrv: 42, rhr: 52)
        )
        let breakdown = RecoveryScoreEngine.calculate(input)

        let tier = RecoveryScoreEngine.statusTier(
            score: breakdown.total,
            input: input,
            breakdown: breakdown
        )

        XCTAssertNotEqual(tier, .wellRecovered)
    }

    func testMedianBaselineUsesMedianNotMean() {
        let median = RecoveryScoreEngine.medianBaseline([20, 30, 100])
        XCTAssertEqual(median, 30)
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
