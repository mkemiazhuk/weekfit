import XCTest
@testable import WeekFit

final class AskCoachSessionAggregatorTests: XCTestCase {

    func testLinkedLocalSessionIsNotDoubleCounted() {
        let uuid = UUID()
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        let sessions = AskCoachSessionAggregator.aggregate(
            healthKit: [
                .init(uuid: uuid, startDate: day, durationMinutes: 40, isRecoveryActivity: false)
            ],
            local: [
                .init(
                    id: "local-1",
                    startDate: day,
                    durationMinutes: 40,
                    healthKitWorkoutUUID: uuid,
                    isCompleted: true,
                    isSkipped: false,
                    source: "today",
                    type: "workout"
                )
            ]
        )

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.source, .healthKit)
        XCTAssertEqual(sessions.first?.healthKitWorkoutUUID, uuid)
    }

    func testUnlinkedCompletedLocalSessionCountsOnce() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = AskCoachSessionAggregator.aggregate(
            healthKit: [],
            local: [
                .init(
                    id: "local-2",
                    startDate: day,
                    durationMinutes: 25,
                    healthKitWorkoutUUID: nil,
                    isCompleted: true,
                    isSkipped: false,
                    source: "today",
                    type: "workout"
                )
            ]
        )

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.source, .localCompleted)
        XCTAssertEqual(sessions.first?.durationMinutes, 25)
    }

    func testIncompleteAndSkippedLocalSessionsAreExcluded() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = AskCoachSessionAggregator.aggregate(
            healthKit: [],
            local: [
                .init(
                    id: "live",
                    startDate: day,
                    durationMinutes: 10,
                    healthKitWorkoutUUID: nil,
                    isCompleted: false,
                    isSkipped: false,
                    source: "today",
                    type: "workout"
                ),
                .init(
                    id: "skipped",
                    startDate: day,
                    durationMinutes: 30,
                    healthKitWorkoutUUID: nil,
                    isCompleted: true,
                    isSkipped: true,
                    source: "planner",
                    type: "workout"
                ),
                .init(
                    id: "meal",
                    startDate: day,
                    durationMinutes: 5,
                    healthKitWorkoutUUID: nil,
                    isCompleted: true,
                    isSkipped: false,
                    source: "today",
                    type: "meal"
                )
            ]
        )

        XCTAssertTrue(sessions.isEmpty)
    }

    func testLinkedUUIDAbsentFromBatchStillExcludesLocalMirror() {
        let uuid = UUID()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = AskCoachSessionAggregator.aggregate(
            healthKit: [],
            local: [
                .init(
                    id: "linked-local",
                    startDate: day,
                    durationMinutes: 45,
                    healthKitWorkoutUUID: uuid,
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner",
                    type: "workout"
                )
            ]
        )
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPlannerSlotsDistinguishPlannedVersusCompleted() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let slots = AskCoachSessionAggregator.plannerSlots(
            from: [
                .init(
                    id: "p1",
                    startDate: day,
                    durationMinutes: 40,
                    healthKitWorkoutUUID: nil,
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner",
                    type: "workout"
                ),
                .init(
                    id: "p2",
                    startDate: day,
                    durationMinutes: 30,
                    healthKitWorkoutUUID: nil,
                    isCompleted: false,
                    isSkipped: false,
                    source: "planner",
                    type: "workout"
                ),
                .init(
                    id: "quick",
                    startDate: day,
                    durationMinutes: 20,
                    healthKitWorkoutUUID: nil,
                    isCompleted: true,
                    isSkipped: false,
                    source: "today",
                    type: "workout"
                )
            ]
        )

        XCTAssertEqual(slots.planned, 2)
        XCTAssertEqual(slots.completed, 1)
    }
}
