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

    func testInProgressShortWalkMatchesOverlappingPlannedWalk() {
        let now = time(hour: 13, minute: 4)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let synced = workout(from: time(hour: 12, minute: 50), to: now, type: .walking)

        let match = ActivityReconciler.bestMatch(
            for: synced,
            in: [planned],
            calendar: calendar,
            now: now,
            liveSessionActive: true
        )

        XCTAssertEqual(match?.id, planned.id)
        XCTAssertFalse(planned.isCompleted)
    }

    func testJustFinishedWalkIsNotTreatedAsInProgressWithoutLiveSession() {
        let now = time(hour: 13, minute: 20)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let synced = workout(from: time(hour: 12, minute: 50), to: now, type: .walking)

        XCTAssertFalse(
            ActivityReconciler.isLikelyInProgress(synced, now: now, liveSessionActive: false)
        )

        let match = ActivityReconciler.bestMatch(
            for: synced,
            in: [planned],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(match?.id, planned.id)
        ActivityReconciler.applySyncedWorkout(synced, to: planned)
        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.durationMinutes, 30)
    }

    func testShortInProgressWalkDoesNotMatchWithoutLiveSession() {
        let now = time(hour: 12, minute: 57)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let synced = workout(from: time(hour: 12, minute: 50), to: now, type: .walking)

        let match = ActivityReconciler.bestMatch(
            for: synced,
            in: [planned],
            calendar: calendar,
            now: now
        )

        XCTAssertNil(match)
        XCTAssertFalse(planned.isCompleted)
    }

    func testApplyLiveWorkoutDoesNotCompletePlannedSlot() {
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let synced = workout(from: time(hour: 12, minute: 50), to: time(hour: 13, minute: 4), type: .walking)

        ActivityReconciler.applyLiveWorkout(synced, to: planned)

        XCTAssertFalse(planned.isCompleted)
        XCTAssertEqual(planned.date, synced.startDate)
        XCTAssertEqual(planned.durationMinutes, 30)
        XCTAssertEqual(planned.actualDurationMinutes, 14)
        XCTAssertEqual(planned.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertEqual(planned.title, "Walk")
    }

    @MainActor
    func testCoordinatorMergesInProgressImportIntoPlannedWalk() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = time(hour: 12, minute: 57)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        context.insert(planned)

        let synced = workout(from: time(hour: 12, minute: 50), to: now, type: .walking)
        let imported = ActivityReconciler.importedLiveActivity(for: synced)
        context.insert(imported)
        try context.save()

        let coordinator = WeekFitActivityCoordinator.shared
        coordinator.resetReconciliationState()
        coordinator.replaceLiveWorkoutForTesting(
            WeekFitLiveWorkout(
                id: UUID(),
                workoutType: .walking,
                startedAt: synced.startDate,
                endedAt: nil,
                state: .active,
                source: .appleWatch
            )
        )
        defer { coordinator.replaceLiveWorkoutForTesting(nil) }

        coordinator.reconcileCompletedAppleWorkout(
            synced,
            with: [planned, imported],
            modelContext: context,
            now: now
        )
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, planned.id)
        XCTAssertEqual(remaining.first?.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertFalse(remaining.first?.isCompleted ?? true)
        XCTAssertEqual(remaining.first?.date, synced.startDate)
    }

    @MainActor
    func testLiveApplyDoesNotBlockLaterWatchCompletion() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let liveNow = time(hour: 13, minute: 4)
        let finishedAt = time(hour: 13, minute: 20)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        context.insert(planned)
        try context.save()

        let liveSample = workout(from: time(hour: 12, minute: 50), to: liveNow, type: .walking)
        let coordinator = WeekFitActivityCoordinator.shared
        coordinator.resetReconciliationState()
        coordinator.replaceLiveWorkoutForTesting(
            WeekFitLiveWorkout(
                id: UUID(),
                workoutType: .walking,
                startedAt: liveSample.startDate,
                endedAt: nil,
                state: .active,
                source: .appleWatch
            )
        )

        coordinator.reconcileCompletedAppleWorkout(
            liveSample,
            with: [planned],
            modelContext: context,
            now: liveNow
        )
        try context.save()
        XCTAssertFalse(planned.isCompleted)
        XCTAssertEqual(planned.healthKitWorkoutUUID, liveSample.uuid.uuidString)

        coordinator.replaceLiveWorkoutForTesting(nil)

        coordinator.reconcileCompletedAppleWorkout(
            liveSample,
            with: [planned],
            modelContext: context,
            now: finishedAt
        )
        try context.save()

        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.actualDurationMinutes, 14)
    }

    @MainActor
    func testJustFinishedWatchWalkCompletesPlannedSlot() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = time(hour: 13, minute: 20)
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        context.insert(planned)
        try context.save()

        let synced = workout(from: time(hour: 12, minute: 50), to: now, type: .walking)
        let coordinator = WeekFitActivityCoordinator.shared
        coordinator.resetReconciliationState()
        coordinator.replaceLiveWorkoutForTesting(nil)

        coordinator.reconcileCompletedAppleWorkout(
            synced,
            with: [planned],
            modelContext: context,
            now: now
        )
        try context.save()

        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertEqual(planned.durationMinutes, 30)
    }

    func testCompletedImportStaysVisibleWhenPlannedWalkDidNotComplete() {
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let imported = ActivityReconciler.importedActivity(
            for: workout(from: time(hour: 12, minute: 43), to: time(hour: 14, minute: 27), type: .walking)
        )

        let visible = PlanTimelineItemGrouper.collapseOverlappingSessionDuplicates([planned, imported])

        XCTAssertEqual(Set(visible.map(\.id)), Set([planned.id, imported.id]))
    }

    func testCompletedImportStaysVisibleEvenIfPlannedWalkWasTappedComplete() {
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        planned.isCompleted = true
        let imported = ActivityReconciler.importedActivity(
            for: workout(from: time(hour: 12, minute: 43), to: time(hour: 14, minute: 27), type: .walking)
        )

        let visible = PlanTimelineItemGrouper.collapseOverlappingSessionDuplicates([planned, imported])

        XCTAssertEqual(Set(visible.map(\.id)), Set([planned.id, imported.id]))
    }

    func testLiveImportHidesBehindOverlappingPlannedWalk() {
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let imported = ActivityReconciler.importedLiveActivity(
            for: workout(from: time(hour: 12, minute: 50), to: time(hour: 13, minute: 4), type: .walking)
        )

        let visible = PlanTimelineItemGrouper.collapseOverlappingSessionDuplicates([planned, imported])

        XCTAssertEqual(visible.map(\.id), [planned.id])
    }

    @MainActor
    func testCoordinatorMergesLongWatchWalkIntoShortPlannedSlot() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        context.insert(planned)
        try context.save()

        let synced = workout(from: time(hour: 12, minute: 43), to: time(hour: 14, minute: 27), type: .walking)
        let coordinator = WeekFitActivityCoordinator.shared
        coordinator.resetReconciliationState()
        coordinator.replaceLiveWorkoutForTesting(nil)

        coordinator.reconcileCompletedAppleWorkout(
            synced,
            with: [planned],
            modelContext: context,
            now: time(hour: 15, minute: 59)
        )
        try context.save()

        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.date, synced.startDate)
        XCTAssertEqual(planned.durationMinutes, 104)
        XCTAssertEqual(planned.healthKitWorkoutUUID, synced.uuid.uuidString)
    }

    @MainActor
    func testCoordinatorMergesExistingLongImportIntoShortPlannedWalk() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        planned.isCompleted = true
        context.insert(planned)

        let synced = workout(from: time(hour: 12, minute: 43), to: time(hour: 14, minute: 27), type: .walking)
        let imported = ActivityReconciler.importedActivity(for: synced)
        context.insert(imported)
        try context.save()

        let coordinator = WeekFitActivityCoordinator.shared
        coordinator.resetReconciliationState()
        coordinator.replaceLiveWorkoutForTesting(nil)

        coordinator.reconcileCompletedAppleWorkout(
            synced,
            with: [planned, imported],
            modelContext: context,
            now: time(hour: 15, minute: 59)
        )
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, planned.id)
        XCTAssertEqual(remaining.first?.date, synced.startDate)
        XCTAssertEqual(remaining.first?.durationMinutes, 104)
        XCTAssertEqual(remaining.first?.healthKitWorkoutUUID, synced.uuid.uuidString)
        XCTAssertTrue(remaining.first?.isCompleted ?? false)
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

    func testLongerWatchWalkMergesIntoShorterPlannedWalk() {
        // Real Watch outdoor walk 12:43–14:27 vs a 13:00 30-min planned slot.
        let planned = walk(at: time(hour: 13, minute: 0), durationMinutes: 30)
        let synced = workout(from: time(hour: 12, minute: 43), to: time(hour: 14, minute: 27), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)
        XCTAssertEqual(match?.id, planned.id)

        ActivityReconciler.applySyncedWorkout(synced, to: planned)
        XCTAssertTrue(planned.isCompleted)
        XCTAssertEqual(planned.date, synced.startDate)
        XCTAssertEqual(planned.durationMinutes, 104)
        XCTAssertEqual(planned.healthKitWorkoutUUID, synced.uuid.uuidString)
    }

    func testShortAutoDetectedWalkDoesNotCompleteLongPlannedWalk() {
        // Adversarial: 10-minute walk within 30 minutes of a 90-minute planned walk.
        let planned = walk(at: time(hour: 8, minute: 0), durationMinutes: 90)
        let synced = workout(from: time(hour: 8, minute: 10), to: time(hour: 8, minute: 20), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertNil(match)
        XCTAssertFalse(planned.isCompleted)
    }

    func testCompletedPlannedWalkWithoutHealthKitCanStillSyncFromWatch() {
        let planned = walk(at: time(hour: 8, minute: 0), durationMinutes: 30)
        planned.isCompleted = true
        let synced = workout(from: time(hour: 8, minute: 5), to: time(hour: 8, minute: 35), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertEqual(match?.id, planned.id)
    }

    func testPlannedWalkAlreadyLinkedToHealthKitIsNotMatchedAgain() {
        let planned = walk(at: time(hour: 8, minute: 0), durationMinutes: 30)
        planned.isCompleted = true
        planned.healthKitWorkoutUUID = UUID().uuidString
        let synced = workout(from: time(hour: 8, minute: 5), to: time(hour: 8, minute: 35), type: .walking)

        let match = ActivityReconciler.bestMatch(for: synced, in: [planned], calendar: calendar)

        XCTAssertNil(match)
    }

    func testTwoCloseWalksPreferDurationCompatibleSlot() {
        let shortPlanned = walk(at: time(hour: 8, minute: 0), durationMinutes: 20)
        let longPlanned = walk(at: time(hour: 8, minute: 15), durationMinutes: 90)
        let synced = workout(from: time(hour: 8, minute: 5), to: time(hour: 8, minute: 25), type: .walking)

        let match = ActivityReconciler.bestMatch(
            for: synced,
            in: [shortPlanned, longPlanned],
            calendar: calendar
        )

        XCTAssertEqual(match?.id, shortPlanned.id)
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
    func testPersistedWorkoutSurvivesStaleActivitiesArrayOnReconcile() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let synced = workout(from: time(hour: 8, minute: 13), to: time(hour: 8, minute: 45), type: .walking)

        WeekFitActivityCoordinator.shared.resetReconciliationState()
        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [],
            modelContext: context
        )
        try context.save()

        WeekFitActivityCoordinator.shared.resetReconciliationState()
        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [],
            modelContext: context,
            forceRetry: true
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

    func testResolvedActiveCaloriesUsesMovementEstimateWhenHealthKitIsLow() {
        let resolved = HealthActivityMetricsResolver.resolvedActiveCalories(
            healthKitActiveCalories: 40,
            steps: 8_124,
            distanceKm: 0,
            weightKg: 70
        )

        XCTAssertEqual(resolved, 255.9, accuracy: 0.1)
    }

    func testResolvedActiveCaloriesPrefersHealthKitWhenHigher() {
        let resolved = HealthActivityMetricsResolver.resolvedActiveCalories(
            healthKitActiveCalories: 420,
            steps: 8_124,
            distanceKm: 0,
            weightKg: 70
        )

        XCTAssertEqual(resolved, 420)
    }

    func testResolvedActiveCaloriesUsesDistanceWhenAvailable() {
        let resolved = HealthActivityMetricsResolver.resolvedActiveCalories(
            healthKitActiveCalories: 0,
            steps: 8_124,
            distanceKm: 6.2,
            weightKg: 70
        )

        XCTAssertEqual(resolved, 325.5, accuracy: 0.1)
    }

    func testResolvedExerciseMinutesUsesWorkoutDurationWhenAppleExerciseTimeIsZero() {
        let workout = workout(from: time(hour: 8, minute: 0), to: time(hour: 8, minute: 35), type: .walking)

        let resolved = HealthActivityMetricsResolver.resolvedExerciseMinutes(
            appleExerciseMinutes: 0,
            workouts: [workout]
        )

        XCTAssertEqual(resolved, 35)
    }

    func testResolvedExerciseMinutesPrefersAppleExerciseTimeWhenHigher() {
        let workout = workout(from: time(hour: 8, minute: 0), to: time(hour: 8, minute: 20), type: .walking)

        let resolved = HealthActivityMetricsResolver.resolvedExerciseMinutes(
            appleExerciseMinutes: 42,
            workouts: [workout]
        )

        XCTAssertEqual(resolved, 42)
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
