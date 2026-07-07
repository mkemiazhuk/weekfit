import XCTest
@testable import WeekFit

final class CoachIntegrationMetricsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachIntegrationMetrics.resetForTests()
    }

    override func tearDown() {
        CoachIntegrationMetrics.resetForTests()
        super.tearDown()
    }

    func testCoachActiveIncrementsV6Counter() {
        record(usingCoach: true, scenario: .stableDay)

        let snapshot = CoachIntegrationMetrics.snapshot
        XCTAssertEqual(snapshot.totalReadyEvaluations, 1)
        XCTAssertEqual(snapshot.activeCount, 1)
        XCTAssertEqual(snapshot.fallbackCount, 0)
        XCTAssertEqual(snapshot.activeRate, 1.0, accuracy: 0.001)
    }

    func testRegistryGapIncrementsFallbackCounters() {
        record(
            usingCoach: false,
            scenario: .duringStrength,
            copyPackExists: false,
            fallbackReason: "copyRegistryMissing:duringStrength"
        )

        let snapshot = CoachIntegrationMetrics.snapshot
        XCTAssertEqual(snapshot.totalReadyEvaluations, 1)
        XCTAssertEqual(snapshot.activeCount, 0)
        XCTAssertEqual(snapshot.fallbackCount, 1)
        XCTAssertEqual(snapshot.fallbackCountsByScenario["duringStrength"], 1)
        XCTAssertEqual(snapshot.fallbackCountsByReason["copyRegistryMissing:duringStrength"], 1)
        XCTAssertEqual(snapshot.lastFallbackScenario, "duringStrength")
        XCTAssertEqual(snapshot.lastFallbackReason, "copyRegistryMissing:duringStrength")
    }

    func testMetricsPersistAcrossRestore() {
        record(usingCoach: false, scenario: .walkAfterHeavyLoad, copyPackExists: true, fallbackReason: "bridgeBuildFailed")
        record(usingCoach: true, scenario: .stableDay)

        CoachIntegrationMetrics.resetMemoryForTests()
        CoachIntegrationMetrics.restoreFromStorageIfNeeded()

        let restored = CoachIntegrationMetrics.snapshot
        XCTAssertEqual(restored.totalReadyEvaluations, 2)
        XCTAssertEqual(restored.activeCount, 1)
        XCTAssertEqual(restored.fallbackCount, 1)
        XCTAssertEqual(restored.fallbackCountsByScenario["walkAfterHeavyLoad"], 1)
    }

    func testReadyStateRecordsMetricsThroughEngine() {
        let input = CoachInputSnapshot(
            selectedDate: CoachTestClock.reference,
            now: CoachTestClock.reference,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: 14)),
            plannedActivities: [],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 400,
                exerciseMinutes: 45,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.7
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachIntegrationMetricsTests"
        )
        _ = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "metrics-test"
        )

        let snapshot = CoachIntegrationMetrics.snapshot
        XCTAssertEqual(snapshot.totalReadyEvaluations, 1)
        XCTAssertEqual(snapshot.activeCount, 1)
        XCTAssertEqual(snapshot.fallbackCount, 0)
    }

    // MARK: - Helpers

    private func record(
        usingCoach: Bool,
        scenario: CoachScenarioKey,
        copyPackExists: Bool = true,
        fallbackReason: String? = nil
    ) {
        let debug = CoachIntegrationDebug(
            scenario: scenario,
            copyPackExists: copyPackExists,
            usingCoach: usingCoach,
            fallbackReason: usingCoach ? nil : fallbackReason
        )
        CoachIntegrationMetrics.record(debug: debug, recomputeReason: "test")
    }
}
