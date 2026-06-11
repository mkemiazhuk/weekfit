import XCTest
@testable import WeekFit

final class CoachInsightFactoryXCTests: XCTestCase {

    func testPrimaryInsight_overload_hasStopEatingAction() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.25, strain: .normal)
        let insights = brain.testInsights
        XCTAssertTrue(insights.contains { $0.actionLabel == "Stop Eating" })
        XCTAssertFalse(insights.contains { $0.actionLabel == "Refuel Now" })
    }

    func testPrimaryInsight_supercompensation_protectRecovery() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.0, fuel: .light, strain: .veryHigh)
        let insights = brain.testInsights
        XCTAssertTrue(insights.contains { $0.actionLabel == "Protect Recovery" })
    }

    func testPrepareWorkoutInsight_usesNextWorkoutTitle() {
        let workout = PlannedActivityBuilder.workout(title: "Intervals", at: CoachTestClock.reference)
        let brain = HumanBrainStateBuilder.make(
            hasWorkoutSoon: true,
            nextWorkout: workout,
            hoursToNextWorkout: 1.0,
            fuel: .underfueled,
            recovery: .stable,
            readiness: .good
        )
        let decision = CoachDecisionEngine.makeDecision(from: brain)
        XCTAssertEqual(decision.primaryStrategy, PrimaryStrategy.prepareWorkout)
        let insights = CoachInsightFactory.generateInsights(brain: brain, decision: decision)
        XCTAssertTrue(insights.contains { $0.text.contains("Intervals") })
        XCTAssertTrue(insights.contains { $0.actionLabel == "Add Carbs" })
    }

    func testRehydrateInsight_suppressedWhenHydrationAdviceBlocked() {
        let brain = HumanBrainStateBuilder.make(waterProgress: 1.2, hydration: .completed)
        let decision = brain.testDecision
        XCTAssertTrue(decision.suppressHydrationAdvice)
        let insights = CoachInsightFactory.generateInsights(brain: brain, decision: decision)
        XCTAssertFalse(insights.contains { $0.actionLabel == "+500 ml" })
    }

    func testScheduleInsight_whenMissedItems() {
        var config = HumanBrainStateBuilder.Configuration()
        config.missedItemsCount = 2
        let brain = HumanBrainStateBuilder.make(config)
        let insights = brain.testInsights
        XCTAssertTrue(insights.contains { $0.actionLabel == "Update Schedule" })
        XCTAssertTrue(insights.contains { $0.tags.contains(.schedule) })
    }

    func testPostWorkoutInsight_afterHighStrainSession() {
        var config = HumanBrainStateBuilder.Configuration()
        config.completedWorkoutsCount = 1
        config.strain = .high
        config.fuel = .good
        config.protein = .good
        let brain = HumanBrainStateBuilder.make(config)
        let insights = brain.testInsights
        XCTAssertTrue(insights.contains { $0.title == "Recovery needs fuel." })
    }

    func testFatBalanceInsight_whenFatsVeryHigh() {
        let brain = HumanBrainStateBuilder.make(fatsProgress: 1.35, strain: .normal)
        let insights = brain.testInsights
        XCTAssertTrue(insights.contains { $0.actionLabel == "Balance Meals" })
    }

    func testLateNightFatLossInsight() {
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = 23
        config.isLateNight = true
        config.profile = CoachMetricsBuilder.standardProfile(goal: .fatLoss)
        config.recovery = .stable
        config.readiness = .good
        config.fuel = .good
        config.strain = .normal
        let insights = HumanBrainStateBuilder.make(config).testInsights
        XCTAssertFalse(insights.isEmpty)
    }

    func testInsights_neverEmpty_fallbackExists() {
        let brain = HumanBrainStateBuilder.make(
            waterProgress: 1.25,
            hydration: .completed,
            fuel: .good,
            protein: .good,
            strain: .normal
        )
        XCTAssertFalse(brain.testInsights.isEmpty)
    }

    func testInsights_maxFourAfterPrioritization() {
        var config = HumanBrainStateBuilder.Configuration()
        config.strain = .high
        config.completedWorkoutsCount = 1
        config.protein = .low
        config.hydration = .behind
        config.fuel = .light
        config.missedItemsCount = 1
        let insights = HumanBrainStateBuilder.make(config).testInsights
        XCTAssertLessThanOrEqual(insights.count, 4)
    }

    func testOverload_removesConflictingAddProteinAndCarbs() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.3, protein: .low, strain: .normal)
        let insights = brain.testInsights
        XCTAssertFalse(insights.contains { $0.actionLabel == "Add Protein" })
        XCTAssertFalse(insights.contains { $0.actionLabel == "Add Carbs" })
    }

    func testMaintain_withElectrolytes_showsMineralsNotWater() {
        let brain = HumanBrainStateBuilder.make(waterProgress: 1.2, hydration: .completed, fuel: .good)
        let decision = brain.testDecision
        XCTAssertEqual(decision.primaryStrategy, PrimaryStrategy.maintain)
        let insights = CoachInsightFactory.generateInsights(brain: brain, decision: decision)
        XCTAssertTrue(
            insights.contains { $0.actionLabel == "Add Minerals" || $0.actionLabel == "Stay Consistent" }
        )
    }
}
