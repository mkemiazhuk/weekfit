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

    func testUserStartedLiveSessionIgnoresPlanWindowOnly() {
        let start = Date().addingTimeInterval(-90 * 60)
        let plannedSlot = PlannedActivity(
            date: start,
            type: "recovery",
            title: "Breath Work",
            durationMinutes: 10,
            icon: "wind",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9,
            source: "planner"
        )
        let started = PlannedActivity(
            date: start,
            type: "recovery",
            title: "Breath Work",
            durationMinutes: 10,
            icon: "wind",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9,
            source: "today"
        )
        let now = Date()

        XCTAssertFalse(plannedSlot.isUserStartedLiveSession(now: now))
        XCTAssertEqual(plannedSlot.terminalState(now: now), .planned)
        XCTAssertTrue(started.isUserStartedLiveSession(now: now))
        // Past soft duration: plan slot is not in-window; Quick Start still displays as live.
        XCTAssertFalse(plannedSlot.isTodayLiveSessionDisplay(now: now))
        XCTAssertTrue(started.isTodayLiveSessionDisplay(now: now))
    }

    func testTodayLiveSessionDisplayIncludesInWindowPlannerWorkout() {
        let start = Date().addingTimeInterval(-10 * 60)
        let planned = PlannedActivity(
            date: start,
            type: "workout",
            title: "Tempo Run",
            durationMinutes: 45,
            icon: "figure.run",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            source: "planner"
        )
        let now = Date()

        XCTAssertFalse(planned.isUserStartedLiveSession(now: now))
        XCTAssertTrue(planned.isActive(at: now))
        XCTAssertTrue(planned.isTodayLiveSessionDisplay(now: now))
    }

    func testTodayLiveSessionDisplayIgnoresInWindowMeal() {
        let start = Date().addingTimeInterval(-5 * 60)
        let meal = PlannedActivity(
            date: start,
            type: "meal",
            title: "Lunch",
            durationMinutes: 30,
            icon: "fork.knife",
            colorRed: 0.9,
            colorGreen: 0.5,
            colorBlue: 0.2,
            source: "planner"
        )
        let now = Date()

        XCTAssertTrue(meal.isActive(at: now))
        XCTAssertFalse(meal.isTodayLiveSessionDisplay(now: now))
    }
}
