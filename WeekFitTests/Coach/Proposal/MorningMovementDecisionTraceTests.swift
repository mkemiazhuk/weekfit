import Foundation
import XCTest
@testable import WeekFit

#if DEBUG
final class MorningMovementDecisionTraceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        MorningProposalDebugTrace.lastMovementDecision = nil
    }

    override func tearDown() {
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        MorningProposalDebugTrace.lastMovementDecision = nil
        super.tearDown()
    }

    func testNoHistoryTraceShowsPhaseAFallback() {
        let context = makeContext(outdoor: .adverse)
        let pick = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertNotNil(pick)
        let trace = MorningProposalDebugTrace.lastMovementDecision
        XCTAssertNotNil(trace)
        XCTAssertTrue(trace!.similarDays.fallbackToPhaseA)
        XCTAssertEqual(trace!.similarDays.overallConfidence, .none)
        XCTAssertFalse(trace!.winner.historyChangedWinner)
        XCTAssertTrue(trace!.formattedSummary().contains("fallback=Phase A"))
    }

    func testWeakHistoryShowsSmallInfluence() {
        seedHistory(count: 2, family: .yoga, completed: true)
        let context = makeContext(outdoor: .adverse)
        _ = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        let yoga = MorningProposalDebugTrace.lastMovementDecision?
            .similarDays.families.first { $0.family == .yoga }
        XCTAssertEqual(yoga?.confidence, .weak)
        XCTAssertLessThanOrEqual(abs(yoga?.appliedBonus ?? 0), 3)
    }

    func testModerateYogaHistoryCanChangeWinner() {
        seedAug22History()
        let context = makeContext(outdoor: .adverse)
        let phaseAPick = RecoveryMovementProvider.finishPick(
            ranked: [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            preferHabitFamily: false
        )
        let pick = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(pick, .yoga)
        let trace = MorningProposalDebugTrace.lastMovementDecision
        XCTAssertNotNil(trace)
        if phaseAPick != .yoga {
            XCTAssertTrue(trace!.winner.historyChangedWinner)
        }
        let yogaBonus = trace!.similarDays.families.first { $0.family == .yoga }?.appliedBonus ?? 0
        XCTAssertGreaterThan(yogaBonus, 0)
        XCTAssertTrue(trace!.formattedSummary().contains("yoga"))
    }

    func testUnsafeWeatherWalkIneligibleInTrace() {
        seedHistory(count: 6, family: .walk, completed: true)
        let context = makeContext(outdoor: .unsafe)
        _ = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        let walk = MorningProposalDebugTrace.lastMovementDecision?
            .candidates.first { $0.family == .walk }
        XCTAssertEqual(walk?.eligible, false)
        XCTAssertTrue(walk?.notes.contains("weather=negative for outdoor family") ?? false)
    }

    func testNegativeAffinityFallsBackToPhaseA() {
        seedRejectedHistory(family: .yoga, days: 4)
        seedRejectedHistory(family: .mobility, days: 4, dayPrefix: "2026-07-")
        let context = makeContext(outdoor: .adverse)
        let phaseAPick = RecoveryMovementProvider.finishPick(
            ranked: [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            preferHabitFamily: false
        )
        let pick = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(pick, phaseAPick)
        XCTAssertFalse(MorningProposalDebugTrace.lastMovementDecision?.winner.historyChangedWinner ?? true)
    }

    func testAug22PersonalizedTraceContainsSimilarDayEvidence() {
        seedAug22History()
        let context = makeContext(outdoor: .adverse, recoveryPercent: 69)
        _ = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        let summary = MorningProposalDebugTrace.lastMovementDecision?.formattedSummary() ?? ""
        XCTAssertTrue(summary.contains("recordsScanned: 4"))
        XCTAssertTrue(summary.contains("yoga"))
        XCTAssertTrue(summary.contains("completedSimilarDays=3") || summary.contains("bonus=+"))
    }

    // MARK: Helpers

    private func makeContext(
        outdoor: OutdoorSuitability,
        recoveryPercent: Int = 69
    ) -> DailyContext {
        let mode = MorningProposalGenerationMode.compose
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-08-22",
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: .moderate,
            sleepPresence: .present,
            scenarioKey: "none",
            yesterdayHeavy: true,
            generationMode: mode
        )
        return DailyContext(
            now: date(2026, 8, 22, 8, 0),
            dayKey: "2026-08-22",
            isMorningEligible: true,
            hasCompletedOrPartialToday: false,
            generationMode: mode,
            contextFreshness: .high,
            recoveryBand: .moderate,
            recoveryPercent: recoveryPercent,
            recoveryAvailable: true,
            sleepPresence: .present,
            sleepHours: 7.2,
            yesterdayHeavy: true,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            scenarioKey: nil,
            todayActivities: [],
            tomorrowActivities: [],
            todayOpen: [],
            todaySeriousOpen: [],
            hasExistingMovement: false,
            completedWalkToday: false,
            totalPlannedDurationMinutes: 0,
            recentDayTemplates: [],
            historicalObservationRevision: "obs",
            behavioralGeneration: 0,
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            softDismissCount: 0,
            softNegativePenalty: 0,
            preferAvoidHardLoadOnLowRecovery: false,
            mealLibrary: [],
            mealLibraryRevision: "1",
            weatherRiskToken: .wind,
            outdoorSuitability: outdoor,
            existingPlanMovementSuitability: .none,
            canMutate: true,
            fingerprint: fingerprint
        )
    }

    private func seedHistory(count: Int, family: RecoveryMovementFamily, completed: Bool) {
        let records = (0..<count).map { index in
            var record = baseRecord(dayKey: "2026-08-\(String(format: "%02d", index + 1))")
            record.movementOutcomes[family] = MovementFamilyOutcome(
                completed: completed,
                origin: .morningAdjustment
            )
            return record
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func seedRejectedHistory(family: RecoveryMovementFamily, days: Int, dayPrefix: String = "2026-08-") {
        let records = (0..<days).map { index in
            var record = baseRecord(dayKey: "\(dayPrefix)\(String(format: "%02d", index + 1))")
            record.movementOutcomes[family] = MovementFamilyOutcome(explicitlyRejected: true)
            return record
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func seedAug22History() {
        let saturdays = ["2026-08-02", "2026-08-09", "2026-08-16", "2026-07-26"]
        let records = saturdays.enumerated().map { index, dayKey in
            var record = baseRecord(dayKey: dayKey)
            if index < 3 {
                record.movementOutcomes[.yoga] = MovementFamilyOutcome(completed: true, origin: .morningAdjustment)
            } else {
                record.movementOutcomes[.mobility] = MovementFamilyOutcome(completed: true, origin: .morningAdjustment)
            }
            return record
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func baseRecord(dayKey: String) -> MorningAdjustmentDayRecord {
        MorningAdjustmentDayRecord(
            dayKey: dayKey,
            recordedAt: date(2026, 8, 22, 8, 0),
            weekday: 7,
            isWeekend: true,
            proposalTimeBucket: .morning,
            recoveryPercent: 68,
            recoveryBand: .moderate,
            strategy: .recover,
            outdoorSuitability: .adverse,
            weatherRiskToken: .wind,
            yesterdayHeavy: true,
            previousDayLoad: .heavy,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            existingPlanSuitability: .none,
            hadMorningProposal: true
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return Calendar.current.date(from: comps) ?? Date()
    }
}

private extension MovementFamilyOutcome {
    init(completed: Bool = false, origin: MovementBehaviorOrigin? = nil) {
        self.init()
        self.completed = completed
        self.origin = origin
    }

    init(explicitlyRejected: Bool) {
        self.init()
        self.explicitlyRejected = explicitlyRejected
    }
}
#endif
