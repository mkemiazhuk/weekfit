import XCTest
@testable import WeekFit

final class CoachCopyXCTests: XCTestCase {

    func testHeadline_fastingMorningBaseline() {
        let brain = HumanBrainStateBuilder.make(currentHour: 8, hasAnyFoodLogged: false)
        let decision = brain.testDecision
        XCTAssertEqual(CoachCopy.headline(brain: brain, decision: decision), "Morning Baseline")
    }

    func testHeadline_overload() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.3, strain: .normal)
        let decision = brain.testDecision
        XCTAssertEqual(CoachCopy.headline(brain: brain, decision: decision), "Extreme Energy Overload")
    }

    func testHeadline_supercompensation() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.0, strain: .veryHigh)
        let decision = brain.testDecision
        XCTAssertEqual(CoachCopy.headline(brain: brain, decision: decision), "High Metabolic Strain")
    }

    func testSummary_overloadWithHydrationSolved_mentionsNoMoreFood() {
        let brain = HumanBrainStateBuilder.make(
            energyCoverage: 1.45,
            waterProgress: 1.1,
            hydration: .completed,
            strain: .high
        )
        let decision = brain.testDecision
        XCTAssertEqual(decision.primaryStrategy, PrimaryStrategy.overload)
        let summary = CoachCopy.summary(brain: brain, decision: decision, complianceScore: 90)
        XCTAssertTrue(summary.contains("avoid more food") || summary.contains("Keep the evening light"))
    }

    func testShortInsight_prepareWorkout() {
        let brain = HumanBrainStateBuilder.make(hasWorkoutSoon: true, fuel: .underfueled)
        let decision = brain.testDecision
        XCTAssertEqual(decision.primaryStrategy, .prepareWorkout)
        let text = CoachCopy.shortInsight(brain: brain, decision: decision)
        XCTAssertTrue(text.contains("activity ahead") || text.contains("Upcoming"))
    }

    func testFastingSummary_workoutSoonMorning() {
        let brain = HumanBrainStateBuilder.make(currentHour: 9, hasAnyFoodLogged: false, hasWorkoutSoon: true)
        let summary = CoachCopy.summary(brain: brain, decision: brain.testDecision, complianceScore: 0)
        XCTAssertTrue(summary.contains("train") || summary.contains("activity"))
    }
}
