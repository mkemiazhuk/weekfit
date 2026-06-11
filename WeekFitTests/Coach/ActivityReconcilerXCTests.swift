import HealthKit
import XCTest
@testable import WeekFit

final class ActivityReconcilerXCTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testFuturePlannedWalkMustNotAutoComplete() {
        let planned = walk(at: time(hour: 9, minute: 45))
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)
        let imported = ActivityReconciler.importedActivity(for: synced)

        XCTAssertNil(match)
        XCTAssertTrue(imported.isCompleted)
        XCTAssertEqual(imported.source, "appleWorkout")
        XCTAssertFalse(planned.isCompleted)
        XCTAssertNil(planned.healthKitWorkoutUUID)
    }

    func testPastPlannedWalkCanBeReconciled() {
        let planned = walk(at: time(hour: 8, minute: 0))
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testDifferentActivityTypeDoesNotMatch() {
        let plannedCore = PlannedActivityBuilder.workout(
            title: "Core",
            at: time(hour: 8, minute: 0),
            durationMinutes: 45
        )
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [plannedCore], calendar: calendar)

        XCTAssertNil(match)
        XCTAssertFalse(plannedCore.isCompleted)
    }

    func testFutureActivityRemainsUntouchedEvenIfSameType() {
        let planned = walk(at: time(hour: 9, minute: 45))
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        _ = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertFalse(planned.isCompleted)
        XCTAssertNil(planned.healthKitWorkoutUUID)
        XCTAssertEqual(planned.date, time(hour: 9, minute: 45))
    }

    func testMultiplePastCandidatesMatchesNearestEligiblePastCandidate() {
        let earlier = walk(at: time(hour: 7, minute: 30))
        let nearest = walk(at: time(hour: 8, minute: 10))
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [earlier, nearest], calendar: calendar)

        XCTAssertEqual(match?.id, nearest.id)
    }

    func testNoEligiblePastCandidateImportsStandaloneWithoutModifyingFuturePlan() {
        let future = walk(at: time(hour: 9, minute: 45))
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [future], calendar: calendar)
        let imported = ActivityReconciler.importedActivity(for: synced)

        XCTAssertNil(match)
        XCTAssertEqual(imported.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertTrue(imported.isCompleted)
        XCTAssertFalse(future.isCompleted)
        XCTAssertNil(future.healthKitWorkoutUUID)
    }

    private func walk(at date: Date, durationMinutes: Int = 45) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: "Walk",
            at: date,
            durationMinutes: durationMinutes
        )
    }

    private func workout(
        from start: Date,
        to end: Date,
        type: HKWorkoutActivityType
    ) -> HKWorkout {
        HKWorkout(
            activityType: type,
            start: start,
            end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )
    }

    private func time(hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 10,
            hour: hour,
            minute: minute
        ).date!
    }
}
