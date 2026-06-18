import HealthKit
import XCTest
@testable import WeekFitHealthKit
import WeekFitPlanner

final class ActivityReconcilerPackageTests: XCTestCase {
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

    private func walk(at date: Date, durationMinutes: Int = 45) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "workout",
            title: "Walk",
            durationMinutes: durationMinutes,
            icon: "figure.walk",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
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
