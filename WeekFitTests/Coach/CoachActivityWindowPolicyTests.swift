import XCTest
@testable import WeekFit

final class CoachActivityWindowPolicyTests: XCTestCase {

    func testImmediatePostFocusWindowIsSixtyMinutes() {
        XCTAssertEqual(CoachActivityWindowPolicy.immediatePostFocusWindowMinutes, 60)
    }

    func testRecentCompletedFocusWindowDefaultsTo180Minutes() {
        let ride = makeActivity(title: "Ride", type: "workout", icon: "figure.outdoor.cycle")
        XCTAssertEqual(CoachActivityWindowPolicy.recentCompletedFocusWindowMinutes(for: ride), 180)
    }

    func testRecentCompletedFocusWindowUsesHeatRecoveryForSauna() {
        let sauna = makeActivity(title: "Sauna", type: "recovery")
        XCTAssertEqual(
            CoachActivityWindowPolicy.recentCompletedFocusWindowMinutes(for: sauna),
            CoachHeatRecoveryPolicy.focusWindowMinutes
        )
    }

    func testHeatRecoveryWindowMatchesScenarioResolverGate() {
        XCTAssertTrue(
            CoachActivityWindowPolicy.isWithinHeatRecoveryWindow(
                minutesSinceEnd: 30,
                sessionPhase: .settledPost
            )
        )
        XCTAssertFalse(
            CoachActivityWindowPolicy.isWithinHeatRecoveryWindow(
                minutesSinceEnd: 60,
                sessionPhase: .settledPost
            )
        )
    }

    func testHeatPreparationLeadIs90Minutes() {
        let sauna = makeActivity(title: "Sauna", type: "recovery", durationMinutes: 30)
        XCTAssertEqual(CoachActivityWindowPolicy.preparationLeadMinutes(for: sauna), 90)
    }

    func testEndurancePreparationLeadIs120Minutes() {
        let ride = makeActivity(title: "Long Ride", type: "workout", icon: "figure.outdoor.cycle", durationMinutes: 120)
        XCTAssertEqual(CoachActivityWindowPolicy.preparationLeadMinutes(for: ride), 120)
    }

    func testWalkRecoveryPreparationLeadIs15Minutes() {
        let walk = makeActivity(title: "Evening Walk", type: "recovery", icon: "figure.walk", durationMinutes: 30)
        XCTAssertEqual(CoachActivityWindowPolicy.preparationLeadMinutes(for: walk), 15)
    }

    func testHeatRecoveryHoldMatchesHeatRecoveryPolicy() {
        let sauna = makeActivity(title: "Sauna", type: "recovery", durationMinutes: 30)
        XCTAssertEqual(
            CoachActivityWindowPolicy.recoveryHoldMinutes(for: sauna),
            CoachHeatRecoveryPolicy.focusWindowMinutes
        )
    }

    func testHighLoadWorkoutRecoveryHoldIs120Minutes() {
        let strength = makeActivity(title: "Strength", type: "workout", durationMinutes: 90)
        strength.calories = 800
        XCTAssertEqual(CoachActivityWindowPolicy.recoveryHoldMinutes(for: strength), 120)
    }

    func testLowLoadWalkRecoveryHoldIs8Minutes() {
        let walk = makeActivity(title: "Easy Walk", type: "recovery", icon: "figure.walk", durationMinutes: 20)
        XCTAssertEqual(CoachActivityWindowPolicy.recoveryHoldMinutes(for: walk), 8)
    }

    // MARK: - Helpers

    private func makeActivity(
        title: String,
        type: String,
        icon: String = "figure.run",
        durationMinutes: Int = 60
    ) -> PlannedActivity {
        PlannedActivity(
            date: CoachTestClock.reference,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
    }
}
