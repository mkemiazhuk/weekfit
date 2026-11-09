import XCTest
import SwiftUI
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
        XCTAssertTrue(
            summary.contains("lower") || summary.contains("below") || summary.contains("ниже")
        )
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

    func testShortSleepIsNotLabeledAsLateBedtime() {
        let contributor = StressIndexContributor(
            kind: .sleep,
            strainScore: 75,
            weightUsed: 0.2,
            tone: .elevating,
            baselineNote: .sleepMinutes(340)
        )
        let label = StressIndexCopy.compactContributorLabel(for: contributor)
        XCTAssertEqual(label, WeekFitLocalizedString("recovery.stressIndex.chip.sleep.short"))
        XCTAssertNotEqual(label, WeekFitLocalizedString("recovery.stressIndex.chip.sleep.late"))

        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 340,
                timeInBedMinutes: 400,
                bedtimeDeviationMinutes: 120,
                baseline: makeBaseline(),
                priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 20, activeCalories: 180, workoutCount: 0)
            ),
            at: fixedDate
        )
        let chips = StressIndexCopy.compactContributorLabels(for: result)
        XCTAssertFalse(chips.contains(WeekFitLocalizedString("recovery.stressIndex.chip.sleep.late")))
        if result.contributors.contains(where: { $0.kind == .sleep && $0.tone == .elevating }) {
            XCTAssertTrue(chips.contains(WeekFitLocalizedString("recovery.stressIndex.chip.sleep.short")))
        }
    }

    func testScreenshotModerateLoadUsesMedianSleepGoalAndMeasuredDays() {
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 450,
                timeInBedMinutes: 520,
                hrvSDNN: 45,
                restingHeartRate: 49,
                baseline: makeBaseline(hrv: 50, rhr: 52, samples: 21),
                priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 20, activeCalories: 180, workoutCount: 0)
            ),
            at: fixedDate
        )

        XCTAssertEqual(result.score, 32)
        XCTAssertEqual(result.level, .moderate)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.baselineSampleDays, 21)
        XCTAssertEqual(result.contributors.first { $0.kind == .hrv }?.tone, .elevating)
        XCTAssertEqual(result.contributors.first { $0.kind == .sleep }?.tone, .neutral)

        let hrv = result.contributors.first { $0.kind == .hrv }!
        let sleep = result.contributors.first { $0.kind == .sleep }!
        XCTAssertEqual(
            StressIndexCopy.summarySentence(for: result),
            StressIndexCopy.directionClause(for: hrv)
        )
        XCTAssertEqual(
            StressIndexCopy.meaning(for: result),
            WeekFitLocalizedString("recovery.stressIndex.means.level.moderate")
        )
        XCTAssertEqual(
            StressIndexCopy.todayAdvice(for: result),
            WeekFitLocalizedString("recovery.stressIndex.today.restIfTired")
        )
        XCTAssertEqual(
            StressIndexCopy.factorCount(result.contributors.count),
            WeekFitLocalizedQuantityFormat("recovery.stressIndex.factorCount", count: result.contributors.count)
        )
        XCTAssertEqual(
            StressIndexCopy.contributionTitle(hrv.tone),
            WeekFitLocalizedString("recovery.stressIndex.contribution.raised")
        )
        XCTAssertEqual(
            StressIndexCopy.contributionTitle(sleep.tone),
            WeekFitLocalizedString("recovery.stressIndex.contribution.neutral")
        )
        XCTAssertEqual(
            StressIndexCopy.levelPhrase(.moderate),
            WeekFitLocalizedString("recovery.stressIndex.levelPhrase.moderate")
        )
        XCTAssertEqual(
            StressIndexCopy.scoreOutOf(32),
            String(format: WeekFitLocalizedString("recovery.stressIndex.scoreOutOf"), 32)
        )
        XCTAssertNotEqual(
            StressIndexCopy.summarySentence(for: result),
            WeekFitLocalizedString("recovery.stressIndex.meaning.moderate")
        )
        XCTAssertEqual(
            StressIndexCopy.confidenceExplanation(.high, baselineSampleDays: 21),
            String(
                format: WeekFitLocalizedString("recovery.stressIndex.confidence.measurementsFormat"),
                WeekFitCountPluralization.phrase(count: 21, category: .day)
            )
        )

        let met = StressIndexEngine.calculate(makeInput(sleepMinutes: 480, timeInBedMinutes: 520), at: fixedDate)
        XCTAssertEqual(met.contributors.first { $0.kind == .sleep }?.tone, .stabilizing)
        let short = StressIndexEngine.calculate(makeInput(sleepMinutes: 300, timeInBedMinutes: 340), at: fixedDate)
        XCTAssertEqual(short.contributors.first { $0.kind == .sleep }?.tone, .elevating)
        let noSleep = StressIndexEngine.calculate(makeInput(sleepMinutes: 0, timeInBedMinutes: 0), at: fixedDate)
        XCTAssertNil(noSleep.contributors.first { $0.kind == .sleep })
        let noHRV = StressIndexEngine.calculate(
            makeInput(hrvSDNN: nil, baseline: makeBaseline(hrv: nil, samples: 0)),
            at: fixedDate
        )
        XCTAssertNil(noHRV.contributors.first { $0.kind == .hrv })

        let limited = StressIndexEngine.calculate(
            makeInput(
                hrvSDNN: nil,
                restingHeartRate: nil,
                baseline: makeBaseline(hrv: nil, rhr: nil, samples: 0),
                priorDayLoad: .empty
            ),
            at: fixedDate
        )
        XCTAssertEqual(limited.confidence, .low)
        XCTAssertNil(limited.score)
        XCTAssertEqual(
            StressIndexCopy.meaning(for: limited),
            WeekFitLocalizedString("recovery.stressIndex.means.lowConfidence")
        )
        XCTAssertEqual(
            StressIndexCopy.meaning(for: .unavailable(at: fixedDate)),
            WeekFitLocalizedString("recovery.stressIndex.means.unavailable")
        )
        XCTAssertEqual(
            StressIndexCopy.todayAdvice(for: limited),
            WeekFitLocalizedString("recovery.stressIndex.today.limited")
        )
        XCTAssertEqual(
            StressIndexCopy.todayAdvice(for: .unavailable(at: fixedDate)),
            WeekFitLocalizedString("recovery.stressIndex.today.limited")
        )

        let shortLead = StressIndexEngine.calculate(
            makeInput(sleepMinutes: 300, timeInBedMinutes: 340, hrvSDNN: 48, restingHeartRate: 52),
            at: fixedDate
        )
        XCTAssertEqual(shortLead.contributors.first?.kind, .sleep)
        let calm = StressIndexEngine.calculate(
            makeInput(hrvSDNN: 50, restingHeartRate: 52, baseline: makeBaseline(hrv: 50, rhr: 52)),
            at: fixedDate
        )
        XCTAssertEqual(calm.level, .low)
        XCTAssertEqual(
            StressIndexCopy.meaning(for: calm),
            WeekFitLocalizedString("recovery.stressIndex.means.level.low")
        )
        XCTAssertNotEqual(
            StressIndexCopy.meaning(for: calm),
            StressIndexCopy.meaning(for: result)
        )
        XCTAssertEqual(
            StressIndexCopy.todayAdvice(for: shortLead),
            WeekFitLocalizedString("recovery.stressIndex.today.restIfShortSleep")
        )
    }

    func testStressSheetRendersFactorsOpen() {
        let result = StressIndexEngine.calculate(
            makeInput(
                sleepMinutes: 450,
                timeInBedMinutes: 520,
                hrvSDNN: 45,
                restingHeartRate: 49,
                baseline: makeBaseline(hrv: 50, rhr: 52, samples: 21),
                priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 20, activeCalories: 180, workoutCount: 0)
            ),
            at: fixedDate
        )
        let previousLanguage = WeekFitCurrentAppLanguage()
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(previousLanguage) }

        let image = renderSheet(result: result, typeSize: .large)
        let attachment = XCTAttachment(image: image)
        attachment.name = "stress-index-factors-open"
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(attachment)
        XCTAssertGreaterThan(image.size.width, 300)
        XCTAssertGreaterThan(image.size.height, 700)

        let largeType = renderSheet(result: result, typeSize: .accessibility3)
        let largeAttachment = XCTAttachment(image: largeType)
        largeAttachment.name = "stress-index-factors-open-large-type"
        largeAttachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(largeAttachment)
        XCTAssertGreaterThan(largeType.size.height, 700)
    }

    private func renderSheet(result: StressIndexResult, typeSize: DynamicTypeSize) -> UIImage {
        let sheet = StressIndexDetailSheet(result: result, morningHint: nil)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.weekFitPalette, .light)
        let size = CGSize(width: 390, height: 844)
        let host = UIHostingController(rootView: sheet)
        host.view.bounds = CGRect(origin: .zero, size: size)
        host.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}
