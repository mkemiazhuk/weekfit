import XCTest
@testable import WeekFit

final class PlanDayKindResolverTests: XCTestCase {

    func testWalkRecoveryPlusCoreWorkoutIsMixedEvenWithLongCore() {
        let activities = [
            makeActivity(type: "recovery", title: "Walk", duration: 30),
            makeActivity(type: "workout", title: "Core", duration: 60)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .mixed)
    }

    func testWalkWorkoutPlusCoreWorkoutIsMixed() {
        let activities = [
            makeActivity(type: "workout", title: "Walk", duration: 30),
            makeActivity(type: "workout", title: "Core", duration: 45)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .mixed)
    }

    func testRunPlusCoreIsMixedNotEndurance() {
        let activities = [
            makeActivity(type: "workout", title: "Running", duration: 60),
            makeActivity(type: "workout", title: "Core", duration: 30)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .mixed)
    }

    func testLongSingleRunRemainsEndurance() {
        let activities = [
            makeActivity(type: "workout", title: "Running", duration: 60)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .endurance)
    }

    func testTwoStrengthSessionsStayLoad() {
        let activities = [
            makeActivity(type: "workout", title: "Core", duration: 20),
            makeActivity(type: "workout", title: "Upper Body", duration: 20)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .load)
    }

    func testRecoveryOnlyDay() {
        let activities = [
            makeActivity(type: "recovery", title: "Walk", duration: 30)
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .recovery)
    }

    private func makeActivity(
        type: String,
        title: String,
        duration: Int
    ) -> PlannedActivity {
        PlannedActivity(
            date: Date(),
            type: type,
            title: title,
            durationMinutes: duration,
            icon: "figure.run",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )
    }
}
