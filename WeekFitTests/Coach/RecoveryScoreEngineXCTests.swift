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

        XCTAssertGreaterThan(
            strongArchitecture.sleepArchitectureGrade ?? -1,
            weakArchitecture.sleepArchitectureGrade ?? -1
        )
        XCTAssertGreaterThan(
            strongArchitecture.sleepArchitectureQuality ?? -1,
            weakArchitecture.sleepArchitectureQuality ?? -1
        )
        XCTAssertLessThanOrEqual(
            strongArchitecture.sleepArchitectureGrade ?? 99,
            RecoveryScoreBreakdown.maxQualityGrade
        )
        XCTAssertLessThan(
            strongArchitecture.total - weakArchitecture.total,
            12
        )
    }

    func testLongSleepLowDeepArchitectureGradeReflectsQualityNotContribution() {
        // Aug 23–equivalent: long night, low Deep %, strong REM.
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 571,
                timeInBedMinutes: 600,
                awakeMinutes: 29,
                awakeningsCount: 2,
                deepSleepMinutes: 36,
                remSleepMinutes: 159,
                hrvSDNN: 42,
                restingHeartRate: 52,
                bedtimeDeviationMinutes: 0
            )
        )

        XCTAssertEqual(breakdown.sleepArchitectureQuality ?? -1, 67.5, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepArchitectureGrade, 7)
        XCTAssertEqual(
            breakdown.sleepArchitectureGrade,
            RecoveryScoreBreakdown.grade(fromQuality: breakdown.sleepArchitectureQuality ?? 0)
        )
        XCTAssertEqual(breakdown.componentSum, breakdown.total)
    }

    func testShortSleepStrongArchitectureGradeNotCompressedByRecoveryCap() {
        // Aug 25–equivalent: short night with strong Deep/REM ratios.
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 239,
                timeInBedMinutes: 250,
                awakeMinutes: 11,
                awakeningsCount: 1,
                deepSleepMinutes: 50,
                remSleepMinutes: 45,
                hrvSDNN: 42,
                restingHeartRate: 52,
                bedtimeDeviationMinutes: 0
            )
        )

        XCTAssertEqual(breakdown.sleepArchitectureQuality ?? -1, 92.8, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepArchitectureGrade, 9)
        XCTAssertLessThanOrEqual(breakdown.total, 65)
        // Contribution may be compressed by the short-sleep total cap; grade must not.
        XCTAssertNotEqual(breakdown.sleepArchitecture, breakdown.sleepArchitectureGrade)
        XCTAssertLessThan(breakdown.sleepArchitecture, breakdown.sleepArchitectureGrade ?? 0)
        XCTAssertEqual(breakdown.componentSum, breakdown.total)
    }

    func testArchitectureGradeIndependentOfPhysiologyDrivenTotalChanges() {
        let stages = (
            sleep: 571,
            deep: 36,
            rem: 159
        )
        let strongPhysio = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: stages.sleep,
                timeInBedMinutes: 600,
                awakeMinutes: 29,
                awakeningsCount: 2,
                deepSleepMinutes: stages.deep,
                remSleepMinutes: stages.rem,
                hrvSDNN: 50,
                restingHeartRate: 48,
                bedtimeDeviationMinutes: 0,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )
        let weakPhysio = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: stages.sleep,
                timeInBedMinutes: 600,
                awakeMinutes: 29,
                awakeningsCount: 2,
                deepSleepMinutes: stages.deep,
                remSleepMinutes: stages.rem,
                hrvSDNN: 28,
                restingHeartRate: 60,
                bedtimeDeviationMinutes: 0,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )

        XCTAssertEqual(
            strongPhysio.sleepArchitectureQuality ?? -1,
            weakPhysio.sleepArchitectureQuality ?? -1,
            accuracy: 0.0001
        )
        XCTAssertEqual(strongPhysio.sleepArchitectureGrade, weakPhysio.sleepArchitectureGrade)
        XCTAssertNotEqual(strongPhysio.total, weakPhysio.total)
    }

    func testArchitectureGradeIgnoresContributionRedistribution() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 239,
                timeInBedMinutes: 250,
                awakeMinutes: 11,
                awakeningsCount: 1,
                deepSleepMinutes: 50,
                remSleepMinutes: 45
            )
        )

        let expectedGrade = RecoveryScoreBreakdown.grade(
            fromQuality: breakdown.sleepArchitectureQuality ?? 0
        )
        XCTAssertEqual(breakdown.sleepArchitectureGrade, expectedGrade)
        XCTAssertEqual(
            expectedGrade,
            RecoveryScoreBreakdown.grade(fromQuality: 92.79193609737543)
        )
    }

    func testQualityGradeRoundingRule() {
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 67.5), 7)
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 92.8), 9)
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 43.3), 4)
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 0), 0)
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 100), 10)
        XCTAssertEqual(RecoveryScoreBreakdown.grade(fromQuality: 70), 7)
    }

    func testQualityGradesIndependentOfShortSleepCap() {
        let shortCapped = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 239,
                timeInBedMinutes: 250,
                awakeMinutes: 11,
                awakeningsCount: 1,
                deepSleepMinutes: 50,
                remSleepMinutes: 45,
                hrvSDNN: 50,
                restingHeartRate: 48,
                bedtimeDeviationMinutes: 30,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )
        // Same stages/physiology qualities with a long sleep so no short-sleep cap —
        // duration quality differs, but HRV/RHR/architecture grades for identical
        // stage ratios need a same-signal comparison via missing-signal test below.
        XCTAssertLessThanOrEqual(shortCapped.total, 65)
        XCTAssertEqual(shortCapped.sleepArchitectureGrade, 9)
        XCTAssertEqual(shortCapped.hrvGrade, 10)
        XCTAssertEqual(shortCapped.restingHeartRateGrade, 10)
    }

    func testMissingHRVDoesNotChangeOtherQualityGrades() {
        let withHRV = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 480,
                timeInBedMinutes: 520,
                awakeningsCount: 2,
                deepSleepMinutes: 80,
                remSleepMinutes: 100,
                hrvSDNN: 42,
                restingHeartRate: 52,
                bedtimeDeviationMinutes: 20
            )
        )
        let withoutHRV = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 480,
                timeInBedMinutes: 520,
                awakeningsCount: 2,
                deepSleepMinutes: 80,
                remSleepMinutes: 100,
                hrvSDNN: nil,
                restingHeartRate: 52,
                bedtimeDeviationMinutes: 20
            )
        )

        XCTAssertNil(withoutHRV.hrvGrade)
        XCTAssertNil(withoutHRV.hrvQuality)
        XCTAssertEqual(withHRV.sleepDurationGrade, withoutHRV.sleepDurationGrade)
        XCTAssertEqual(withHRV.sleepConsistencyGrade, withoutHRV.sleepConsistencyGrade)
        XCTAssertEqual(withHRV.sleepContinuityGrade, withoutHRV.sleepContinuityGrade)
        XCTAssertEqual(withHRV.sleepArchitectureGrade, withoutHRV.sleepArchitectureGrade)
        XCTAssertEqual(withHRV.restingHeartRateGrade, withoutHRV.restingHeartRateGrade)
        XCTAssertNotEqual(withHRV.total, withoutHRV.total)
        XCTAssertEqual(withoutHRV.componentSum, withoutHRV.total)
        XCTAssertEqual(withHRV.componentSum, withHRV.total)
    }

    func testAug23QualityDashboardGrades() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 571,
                timeInBedMinutes: 585,
                awakeMinutes: 14,
                awakeningsCount: 4,
                deepSleepMinutes: 36,
                remSleepMinutes: 159,
                hrvSDNN: 42,
                restingHeartRate: 49,
                bedtimeDeviationMinutes: 89,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )

        XCTAssertEqual(breakdown.sleepDurationQuality, 100, accuracy: 0.01)
        XCTAssertEqual(breakdown.sleepDurationGrade, 10)
        XCTAssertEqual(breakdown.sleepConsistencyQuality ?? -1, 50.56, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepConsistencyGrade, 5)
        XCTAssertEqual(breakdown.sleepContinuityQuality ?? -1, 95.0, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepContinuityGrade, 10)
        XCTAssertEqual(breakdown.sleepArchitectureQuality ?? -1, 67.5, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepArchitectureGrade, 7)
        XCTAssertEqual(breakdown.hrvQuality ?? -1, 85, accuracy: 0.1)
        XCTAssertEqual(breakdown.hrvGrade, 9)
        XCTAssertEqual(breakdown.restingHeartRateQuality ?? -1, 96, accuracy: 0.1)
        XCTAssertEqual(breakdown.restingHeartRateGrade, 10)
        XCTAssertEqual(breakdown.componentSum, breakdown.total)
    }

    func testAug25QualityDashboardGradesRemainDespiteCap() {
        let heavyLoad = RecoveryPriorDayLoad(exerciseMinutes: 95, activeCalories: 900, workoutCount: 1)
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 239,
                timeInBedMinutes: 239,
                awakeMinutes: 0,
                awakeningsCount: 5,
                deepSleepMinutes: 50,
                remSleepMinutes: 45,
                hrvSDNN: 50,
                restingHeartRate: 48,
                bedtimeDeviationMinutes: 94,
                baseline: makeBaseline(hrv: 42, rhr: 52),
                priorDayLoad: heavyLoad
            )
        )

        XCTAssertEqual(breakdown.sleepDurationQuality, 43.3, accuracy: 0.2)
        XCTAssertEqual(breakdown.sleepDurationGrade, 4)
        XCTAssertEqual(breakdown.sleepConsistencyGrade, 5)
        XCTAssertEqual(breakdown.sleepContinuityGrade, 9)
        XCTAssertEqual(breakdown.sleepArchitectureQuality ?? -1, 92.8, accuracy: 0.1)
        XCTAssertEqual(breakdown.sleepArchitectureGrade, 9)
        XCTAssertEqual(breakdown.hrvGrade, 10)
        XCTAssertEqual(breakdown.restingHeartRateGrade, 10)
        XCTAssertEqual(breakdown.trainingLoadModifier, -3)
        XCTAssertEqual(breakdown.total, 62)
        XCTAssertEqual(breakdown.componentSum, breakdown.total)
        // Contribution points remain on the Recovery point scale; grades stay on /10.
        XCTAssertNotEqual(breakdown.hrv, breakdown.hrvGrade)
        XCTAssertEqual(breakdown.hrvGrade, 10)
        // Load modifier stays internal — quality dashboard rows exclude it.
        XCTAssertEqual(
            RecoveryBreakdownSignal.displayedQualitySignals,
            [
                .sleepDuration,
                .sleepConsistency,
                .sleepContinuity,
                .sleepArchitecture,
                .hrv,
                .restingHeartRate
            ]
        )
    }

    func testTrainingLoadModifierAffectsRecoveryWithoutChangingQualityGrades() {
        let base = makeInput(
            sleepMinutes: 239,
            timeInBedMinutes: 239,
            awakeMinutes: 0,
            awakeningsCount: 5,
            deepSleepMinutes: 50,
            remSleepMinutes: 45,
            hrvSDNN: 50,
            restingHeartRate: 48,
            bedtimeDeviationMinutes: 94,
            baseline: makeBaseline(hrv: 42, rhr: 52),
            priorDayLoad: .empty
        )
        let heavy = makeInput(
            sleepMinutes: 239,
            timeInBedMinutes: 239,
            awakeMinutes: 0,
            awakeningsCount: 5,
            deepSleepMinutes: 50,
            remSleepMinutes: 45,
            hrvSDNN: 50,
            restingHeartRate: 48,
            bedtimeDeviationMinutes: 94,
            baseline: makeBaseline(hrv: 42, rhr: 52),
            priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 95, activeCalories: 900, workoutCount: 1)
        )

        let withoutLoad = RecoveryScoreEngine.calculate(base)
        let withLoad = RecoveryScoreEngine.calculate(heavy)

        XCTAssertEqual(withoutLoad.trainingLoadModifier, 0)
        XCTAssertEqual(withLoad.trainingLoadModifier, -3)
        XCTAssertEqual(withLoad.total, withoutLoad.total - 3)
        XCTAssertEqual(withLoad.total, 62)

        XCTAssertEqual(withoutLoad.sleepDurationGrade, withLoad.sleepDurationGrade)
        XCTAssertEqual(withoutLoad.sleepConsistencyGrade, withLoad.sleepConsistencyGrade)
        XCTAssertEqual(withoutLoad.sleepContinuityGrade, withLoad.sleepContinuityGrade)
        XCTAssertEqual(withoutLoad.sleepArchitectureGrade, withLoad.sleepArchitectureGrade)
        XCTAssertEqual(withoutLoad.hrvGrade, withLoad.hrvGrade)
        XCTAssertEqual(withoutLoad.restingHeartRateGrade, withLoad.restingHeartRateGrade)
        XCTAssertEqual(withoutLoad.componentSum, withoutLoad.total)
        XCTAssertEqual(withLoad.componentSum, withLoad.total)
    }

    func testFallbackQualitiesAreNotPresentedAsMeasuredGrades() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 480,
                timeInBedMinutes: 0,
                awakeningsCount: 0,
                deepSleepMinutes: 0,
                remSleepMinutes: 0,
                hrvSDNN: nil,
                restingHeartRate: nil,
                bedtimeDeviationMinutes: nil
            )
        )

        XCTAssertNil(breakdown.sleepConsistencyGrade)
        XCTAssertNil(breakdown.sleepConsistencyQuality)
        XCTAssertNil(breakdown.sleepContinuityGrade)
        XCTAssertNil(breakdown.sleepContinuityQuality)
        XCTAssertNil(breakdown.sleepArchitectureGrade)
        XCTAssertNil(breakdown.sleepArchitectureQuality)
        XCTAssertNil(breakdown.hrvGrade)
        XCTAssertNil(breakdown.restingHeartRateGrade)
        XCTAssertTrue(breakdown.unavailableSignals.contains(.bedtimeConsistency))
        XCTAssertTrue(breakdown.unavailableSignals.contains(.sleepContinuity))
        XCTAssertTrue(breakdown.unavailableSignals.contains(.deepSleep))
        XCTAssertTrue(breakdown.unavailableSignals.contains(.remSleep))
        XCTAssertTrue(breakdown.unavailableSignals.contains(.hrv))
        XCTAssertTrue(breakdown.unavailableSignals.contains(.restingHeartRate))
        // Duration remains measured from sleep minutes.
        XCTAssertEqual(breakdown.sleepDurationGrade, 10)
        XCTAssertEqual(breakdown.componentSum, breakdown.total)
    }

    func testStrongestMeasuredSignalUsesRawQualityNotContribution() {
        let breakdown = RecoveryScoreEngine.calculate(
            makeInput(
                sleepMinutes: 239,
                timeInBedMinutes: 250,
                awakeningsCount: 1,
                deepSleepMinutes: 50,
                remSleepMinutes: 45,
                hrvSDNN: 50,
                restingHeartRate: 58,
                bedtimeDeviationMinutes: 90,
                baseline: makeBaseline(hrv: 42, rhr: 52)
            )
        )

        // Architecture ~92.8 and HRV 100 — HRV wins on raw quality.
        XCTAssertEqual(breakdown.strongestMeasuredSignal, .hrv)
        XCTAssertEqual(breakdown.hrvQuality ?? -1, 100, accuracy: 0.1)
        XCTAssertGreaterThan(breakdown.hrvQuality ?? 0, breakdown.sleepArchitectureQuality ?? 0)
        // Contribution for architecture may be compressed; strongest ignores that.
        XCTAssertLessThan(breakdown.sleepArchitecture, 10)
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
