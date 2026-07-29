import XCTest
@testable import WeekFit

final class StressIndexEngineTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeBaseline(
        hrv: Double? = 50,
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
        awakeningsCount: Int = 1,
        deepSleepMinutes: Int = 80,
        remSleepMinutes: Int = 100,
        hrvSDNN: Double? = 50,
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

    // MARK: - Drivers

    func testHRVBelowBaselineIncreasesStress() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let atBaseline = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 50, restingHeartRate: 52, baseline: baseline),
            at: fixedDate
        )
        let below = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 35, restingHeartRate: 52, baseline: baseline),
            at: fixedDate
        )

        XCTAssertNotNil(atBaseline.score)
        XCTAssertNotNil(below.score)
        XCTAssertGreaterThan(below.score!, atBaseline.score!)
        XCTAssertEqual(
            below.contributors.first { $0.kind == .hrv }?.tone,
            .elevating
        )
    }

    func testRestingHeartRateAboveBaselineIncreasesStress() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let normal = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 50, restingHeartRate: 52, baseline: baseline),
            at: fixedDate
        )
        let elevated = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 50, restingHeartRate: 60, baseline: baseline),
            at: fixedDate
        )

        XCTAssertGreaterThan(elevated.score!, normal.score!)
        XCTAssertEqual(
            elevated.contributors.first { $0.kind == .restingHeartRate }?.tone,
            .elevating
        )
    }

    func testSleepDeficitIncreasesStress() {
        let full = StressIndexEngine.calculate(
            makeInput(sleepMinutes: 480, timeInBedMinutes: 500),
            at: fixedDate
        )
        let short = StressIndexEngine.calculate(
            makeInput(sleepMinutes: 320, timeInBedMinutes: 360),
            at: fixedDate
        )

        XCTAssertGreaterThan(short.score!, full.score!)
        XCTAssertEqual(
            short.contributors.first { $0.kind == .sleep }?.tone,
            .elevating
        )
    }

    func testHeavyRecentTrainingIncreasesStress() {
        let light = StressIndexEngine.calculate(
            makeInput(priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 20, activeCalories: 180, workoutCount: 1)),
            at: fixedDate
        )
        let heavy = StressIndexEngine.calculate(
            makeInput(priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 110, activeCalories: 900, workoutCount: 2)),
            at: fixedDate
        )

        XCTAssertGreaterThan(heavy.score!, light.score!)
        XCTAssertEqual(
            heavy.contributors.first { $0.kind == .trainingLoad }?.strainScore,
            80
        )
    }

    func testMixedPositiveAndNegativeSignals() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let mixed = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 300,
                timeInBedMinutes: 340,
                hrvSDNN: 52,
                restingHeartRate: 50,
                baseline: baseline,
                priorDayLoad: .empty
            ),
            at: fixedDate
        )

        XCTAssertNotNil(mixed.score)
        XCTAssertEqual(mixed.confidence, .high)
        let sleep = mixed.contributors.first { $0.kind == .sleep }
        let hrv = mixed.contributors.first { $0.kind == .hrv }
        XCTAssertEqual(sleep?.tone, .elevating)
        XCTAssertEqual(hrv?.tone, .stabilizing)
    }

    // MARK: - Missing data / reweighting

    func testMissingIndividualSignalsReweightsRemaining() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let all = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 40, restingHeartRate: 58, baseline: baseline),
            at: fixedDate
        )
        let missingHRV = StressIndexEngine.calculate(
            makeInput(hrvSDNN: nil, restingHeartRate: 58, baseline: baseline),
            at: fixedDate
        )

        XCTAssertFalse(missingHRV.contributors.contains { $0.kind == .hrv })
        XCTAssertEqual(
            missingHRV.contributors.map(\.weightUsed).reduce(0, +),
            1.0,
            accuracy: 0.0001
        )
        XCTAssertNotEqual(all.score, missingHRV.score)
    }

    func testInsufficientBaselineDataIsUnavailableOrLow() {
        let weakBaseline = makeBaseline(hrv: 50, rhr: 52, samples: 3)
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 0,
                hrvSDNN: 40,
                restingHeartRate: 60,
                baseline: weakBaseline,
                priorDayLoad: .empty
            ),
            at: fixedDate
        )

        // No personalized physiology + no sleep → only training → unavailable
        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertNil(result.score)
        XCTAssertNil(result.level)
    }

    func testNoFalseZeroForMissingData() {
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 0,
                hrvSDNN: nil,
                restingHeartRate: nil,
                baseline: .empty,
                priorDayLoad: nil
            ),
            at: fixedDate
        )

        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertNil(result.score)
        XCTAssertNotEqual(result.score, 0)
    }

    func testLowConfidenceHidesPreciseScoreButKeepsLevel() {
        // Sleep + training only (no personalized physiology)
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 450,
                hrvSDNN: nil,
                restingHeartRate: nil,
                baseline: .empty,
                priorDayLoad: .empty
            ),
            at: fixedDate
        )

        XCTAssertEqual(result.confidence, .low)
        XCTAssertNil(result.score)
        XCTAssertNotNil(result.level)
        XCTAssertNotNil(result.rawScore)
        XCTAssertFalse(result.displaysPreciseScore)
    }

    // MARK: - Scale / levels / confidence

    func testScoreClampedToZeroOneHundred() {
        let baseline = makeBaseline(hrv: 60, rhr: 48)
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 240,
                timeInBedMinutes: 320,
                awakeningsCount: 8,
                hrvSDNN: 30,
                restingHeartRate: 70,
                baseline: baseline,
                priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 120, activeCalories: 950, workoutCount: 2)
            ),
            at: fixedDate
        )

        XCTAssertNotNil(result.score)
        XCTAssertGreaterThanOrEqual(result.score!, 0)
        XCTAssertLessThanOrEqual(result.score!, 100)
    }

    func testLevelBoundaries() {
        XCTAssertEqual(StressIndexLevel.from(score: 0), .low)
        XCTAssertEqual(StressIndexLevel.from(score: 24), .low)
        XCTAssertEqual(StressIndexLevel.from(score: 25), .moderate)
        XCTAssertEqual(StressIndexLevel.from(score: 49), .moderate)
        XCTAssertEqual(StressIndexLevel.from(score: 50), .elevated)
        XCTAssertEqual(StressIndexLevel.from(score: 74), .elevated)
        XCTAssertEqual(StressIndexLevel.from(score: 75), .high)
        XCTAssertEqual(StressIndexLevel.from(score: 100), .high)
    }

    func testHighConfidenceRequiresSleepAndBothPersonalizedSignals() {
        let baseline = makeBaseline()
        let result = StressIndexEngine.calculate(
            makeInput(baseline: baseline),
            at: fixedDate
        )
        XCTAssertEqual(result.confidence, .high)
        XCTAssertTrue(result.displaysPreciseScore)
    }

    func testMediumConfidenceWithSleepAndOnePhysiologySignal() {
        let baseline = RecoveryPhysiologyBaseline(
            hrvMedian: 50,
            hrvSampleCount: 14,
            restingHeartRateMedian: nil,
            restingHeartRateSampleCount: 0,
            windowDays: 21
        )
        let result = StressIndexEngine.calculate(
            makeInput(restingHeartRate: nil, baseline: baseline),
            at: fixedDate
        )
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertNotNil(result.score)
    }

    // MARK: - Independence from Recovery Score

    func testNotSimplyInverseOfRecoveryScore() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let input = makeInput(
            sleepMinutes: 480,
            hrvSDNN: 50,
            restingHeartRate: 52,
            baseline: baseline,
            priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 100, activeCalories: 850, workoutCount: 1)
        )

        let recovery = RecoveryScoreEngine.calculate(input)
        let stress = StressIndexEngine.calculate(input, at: fixedDate)

        XCTAssertNotNil(stress.score)
        XCTAssertNotEqual(stress.score, 100 - recovery.total)
    }

    // MARK: - Conflict scenarios

    func testRecoveryStressConflictScenarios() {
        let elevatedStress = StressIndexResult(
            score: 62,
            level: .elevated,
            confidence: .high,
            contributors: [],
            calculatedAt: fixedDate,
            rawScore: 62,
            baselineSampleDays: 21,
            usedSignalKinds: [.hrv, .sleep]
        )
        let lowStress = StressIndexResult(
            score: 18,
            level: .low,
            confidence: .high,
            contributors: [],
            calculatedAt: fixedDate,
            rawScore: 18,
            baselineSampleDays: 21,
            usedSignalKinds: [.hrv, .sleep]
        )

        XCTAssertEqual(
            StressIndexEngine.recoveryConflict(recoveryScore: 82, stress: elevatedStress),
            .highRecoveryElevatedStress
        )
        XCTAssertEqual(
            StressIndexEngine.recoveryConflict(recoveryScore: 48, stress: lowStress),
            .lowRecoveryLowStress
        )
        XCTAssertEqual(
            StressIndexEngine.recoveryConflict(recoveryScore: 40, stress: elevatedStress),
            .lowRecoveryHighStress
        )
        XCTAssertEqual(
            StressIndexEngine.recoveryConflict(recoveryScore: 88, stress: lowStress),
            .highRecoveryLowStress
        )
    }

    // MARK: - Localization / accessibility

    func testLevelAndAccessibilityLabelsAreLocalized() {
        let result = StressIndexEngine.calculate(makeInput(), at: fixedDate)
        XCTAssertFalse(StressIndexCopy.levelTitle(.moderate).isEmpty)
        XCTAssertFalse(StressIndexCopy.compactSummary(for: result).isEmpty)

        let label = StressIndexCopy.accessibilityLabel(for: result)
        XCTAssertTrue(label.contains(WeekFitLocalizedString("recovery.stressIndex.title")))
        if let score = result.score {
            XCTAssertTrue(label.contains("\(score)"))
        }

        let unavailableLabel = StressIndexCopy.accessibilityLabel(for: .unavailable(at: fixedDate))
        XCTAssertTrue(
            unavailableLabel.contains(WeekFitLocalizedString("recovery.stressIndex.empty.title"))
        )
    }

    func testDisclaimerCopyExists() {
        let text = WeekFitLocalizedString("recovery.stressIndex.disclaimer")
        XCTAssertTrue(text.lowercased().contains("not a medical diagnosis") || text.contains("не медицинский"))
    }

    func testElevatingSummaryNeverCallsHRVElevated() {
        let baseline = makeBaseline(hrv: 50, rhr: 52)
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 320,
                timeInBedMinutes: 380,
                hrvSDNN: 35,
                restingHeartRate: 52,
                baseline: baseline,
                priorDayLoad: .empty
            ),
            at: fixedDate
        )

        let summary = StressIndexCopy.summarySentence(for: result).lowercased()
        XCTAssertTrue(summary.contains("hrv"))
        XCTAssertTrue(summary.contains("lower") || summary.contains("ниже"))
        XCTAssertFalse(summary.contains("hrv is higher"))
        XCTAssertFalse(summary.contains("hrv appear elevated"))
        XCTAssertFalse(summary.contains("hrv and sleep appear elevated"))

        let hrv = result.contributors.first { $0.kind == .hrv }
        XCTAssertEqual(hrv?.tone, .elevating)
        XCTAssertEqual(
            StressIndexCopy.contributorHeadline(for: hrv!),
            WeekFitLocalizedString("recovery.stressIndex.row.hrv.below")
        )
    }

    func testBaselineSampleDaysExposedWhenPersonalized() {
        let result = StressIndexEngine.calculate(
            makeInput(baseline: makeBaseline(samples: 18)),
            at: fixedDate
        )
        XCTAssertEqual(result.baselineSampleDays, 18)
        XCTAssertFalse(result.usedSignalKinds.isEmpty)
    }
}
