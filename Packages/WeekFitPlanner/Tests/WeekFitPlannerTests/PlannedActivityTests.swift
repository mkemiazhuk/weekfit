import XCTest
@testable import WeekFitPlanner

final class PlannedActivityTests: XCTestCase {
    func testHydrationActivityIsDrinkKind() {
        let activity = PlannedActivity(
            date: Date(),
            type: "drink",
            title: "Water",
            durationMinutes: 1,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9,
            source: "hydration"
        )

        XCTAssertEqual(activity.timelineEventKind, .drink)
        XCTAssertFalse(activity.blocksPlannerTime)
    }

    func testSnackActivityIsFoodKind() {
        let activity = PlannedActivity(
            date: Date(),
            type: "snack",
            title: "Banana",
            durationMinutes: 1,
            icon: "carrot.fill",
            imageName: "ingredient-banana",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9,
            calories: 89,
            source: "today"
        )

        XCTAssertEqual(activity.timelineEventKind, .food)
        XCTAssertFalse(activity.blocksPlannerTime)
    }

    func testWorkoutTerminalStateBecomesActiveDuringWindow() {
        let start = Date()
        let activity = PlannedActivity(
            date: start,
            type: "workout",
            title: "Run",
            durationMinutes: 30,
            icon: "figure.run",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )
        let mid = start.addingTimeInterval(15 * 60)

        XCTAssertEqual(activity.terminalState(now: mid), .active)
    }
}
