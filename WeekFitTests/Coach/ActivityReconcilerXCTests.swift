import HealthKit
import SwiftData
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

    func testPlannedCyclingMatchesWatchWorkoutStartedEarly() {
        let planned = cycling(at: time(hour: 10, minute: 0), durationMinutes: 60)
        let synced = workout(from: time(hour: 9, minute: 30), to: time(hour: 10, minute: 20), type: .cycling)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testPlannedCyclingMatchesWatchWorkoutStartedLateWithinTolerance() {
        let planned = cycling(at: time(hour: 10, minute: 0), durationMinutes: 60)
        let synced = workout(from: time(hour: 10, minute: 20), to: time(hour: 11, minute: 20), type: .cycling)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testStandaloneRunDoesNotCompleteFuturePlannedRide() {
        let plannedRide = cycling(at: time(hour: 12, minute: 0), durationMinutes: 90)
        let syncedRun = workout(from: time(hour: 9, minute: 30), to: time(hour: 10, minute: 15), type: .running)

        let match = ActivityReconciler.bestMatch(for: syncedRun, in: [plannedRide], calendar: calendar)
        let imported = ActivityReconciler.importedActivity(for: syncedRun)

        XCTAssertNil(match)
        XCTAssertEqual(imported.source, "appleWorkout")
        XCTAssertEqual(imported.title, "Running")
        XCTAssertFalse(plannedRide.isCompleted)
        XCTAssertNil(plannedRide.healthKitWorkoutUUID)
    }

    func testPlannedCoreMatchesFunctionalStrengthWorkout() {
        let planned = PlannedActivityBuilder.workout(
            title: "Core",
            at: time(hour: 8, minute: 0),
            durationMinutes: 45
        )
        let synced = workout(from: time(hour: 8, minute: 5), to: time(hour: 8, minute: 45), type: .functionalStrengthTraining)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testPlannedFullBodyMatchesTraditionalStrengthWorkout() {
        let planned = PlannedActivityBuilder.workout(
            title: "Full Body",
            at: time(hour: 18, minute: 0),
            durationMinutes: 60
        )
        let synced = workout(from: time(hour: 18, minute: 10), to: time(hour: 19, minute: 5), type: .traditionalStrengthTraining)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testFutureUnrelatedPlannedActivityIsNotAutoCompleted() {
        let plannedYoga = PlannedActivityBuilder.workout(
            title: "Yoga",
            at: time(hour: 11, minute: 0),
            durationMinutes: 45
        )
        let syncedStrength = workout(from: time(hour: 10, minute: 40), to: time(hour: 11, minute: 20), type: .functionalStrengthTraining)

        let match = ActivityReconciler.bestMatch(for: syncedStrength, in: [plannedYoga], calendar: calendar)

        XCTAssertNil(match)
        XCTAssertFalse(plannedYoga.isCompleted)
        XCTAssertNil(plannedYoga.healthKitWorkoutUUID)
    }

    @MainActor
    func testSameHealthKitWorkoutReconciledTwiceImportsOnlyOnce() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [],
            modelContext: context
        )
        try context.save()
        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [],
            modelContext: context
        )
        try context.save()

        let importedActivities = try context.fetch(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(importedActivities.count, 1)
        XCTAssertEqual(importedActivities.first?.healthKitWorkoutUUID, synced.uuid.uuidString)
    }

    @MainActor
    func testCoordinatorPreservesPlannedSlotWhenCompletingMatchedWorkout() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let plannedDate = time(hour: 10, minute: 0)
        let planned = cycling(at: plannedDate, durationMinutes: 60)
        let synced = workout(from: time(hour: 9, minute: 30), to: time(hour: 10, minute: 20), type: .cycling)

        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [planned],
            modelContext: context
        )

        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.source, "appleWorkout")
        XCTAssertEqual(planned.date, synced.startDate)
        XCTAssertEqual(planned.durationMinutes, 50)
        XCTAssertEqual(planned.actualDurationMinutes, 50)
        XCTAssertEqual(planned.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertEqual(planned.title, "Cycling")
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

    private func cycling(at date: Date, durationMinutes: Int = 60) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: "Cycling",
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
