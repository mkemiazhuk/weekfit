import HealthKit
import SwiftData
import XCTest
@testable import WeekFit

@MainActor
final class CoachSnapshotInvalidationTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        WeekFitActivityCoordinator.shared.beforePlannedActivityMutation = nil
        super.tearDown()
    }

    func testInvalidateClearsCoachSnapshotHolders() async {
        let coordinator = CoachCoordinator()
        let provider = CoachInputProvider()
        let nutrition = NutritionViewModel()
        let health = HealthManager()
        let activity = PlannedActivityBuilder.workout(
            title: "Core",
            at: Date(),
            durationMinutes: 45
        )

        await provider.refresh(
            selectedDate: Date(),
            plannedActivities: [activity],
            healthManager: health,
            nutritionViewModel: nutrition,
            coachCoordinator: coordinator,
            source: "invalidationTest",
            refreshHealth: false
        )

        XCTAssertNotNil(provider.lastInput)
        XCTAssertNotNil(nutrition.coachMetricsSnapshot)

        CoachSnapshotInvalidator.invalidate(
            coordinator: coordinator,
            nutritionViewModel: nutrition,
            inputProvider: provider,
            reason: "testInvalidate"
        )

        XCTAssertNil(provider.lastInput)
        XCTAssertNil(coordinator.state.input)
        XCTAssertNil(nutrition.coachMetricsSnapshot)

        if coordinator.state.canRenderTodayCoachInsight {
            XCTAssertEqual(coordinator.state.status, .refreshingPrevious)
            XCTAssertNotNil(coordinator.state.coachUIPresentation)
        } else if case .unavailable = coordinator.state.status {
            // expected settling/unavailable state without cached input
        } else {
            XCTFail("Expected unavailable or preserved coach state after invalidation, got \(coordinator.state.status)")
        }
    }

    func testInvalidatePreservesPreviousPresentationWhenGuidanceExists() async {
        let coordinator = CoachCoordinator()
        let provider = CoachInputProvider()
        let nutrition = NutritionViewModel()
        let health = HealthManager()
        let activity = PlannedActivityBuilder.workout(
            title: "Ride",
            at: Date(),
            durationMinutes: 60
        )

        await provider.refresh(
            selectedDate: Date(),
            plannedActivities: [activity],
            healthManager: health,
            nutritionViewModel: nutrition,
            coachCoordinator: coordinator,
            source: "preserveInvalidationTest",
            refreshHealth: false
        )

        guard coordinator.state.canRenderTodayCoachInsight else {
            return
        }
        let previousTitle = coordinator.state.coachUIPresentation?.todayTitle

        CoachSnapshotInvalidator.invalidate(
            coordinator: coordinator,
            nutritionViewModel: nutrition,
            inputProvider: provider,
            reason: "preserveInvalidationTest"
        )

        XCTAssertEqual(coordinator.state.status, .refreshingPrevious)
        XCTAssertEqual(coordinator.state.coachUIPresentation?.todayTitle, previousTitle)
        XCTAssertTrue(coordinator.state.canRenderTodayCoachInsight)
    }

    func testCoachInputNotRetainedAcrossInvalidation() async {
        let coordinator = CoachCoordinator()
        let provider = CoachInputProvider()
        let nutrition = NutritionViewModel()
        let health = HealthManager()
        let activity = PlannedActivityBuilder.workout(
            title: "Walk",
            at: Date(),
            durationMinutes: 30
        )

        await provider.refresh(
            selectedDate: Date(),
            plannedActivities: [activity],
            healthManager: health,
            nutritionViewModel: nutrition,
            coachCoordinator: coordinator,
            source: "retentionTest",
            refreshHealth: false
        )

        weak var weakActivity = activity
        CoachSnapshotInvalidator.invalidate(
            coordinator: coordinator,
            nutritionViewModel: nutrition,
            inputProvider: provider,
            reason: "retentionTest"
        )

        XCTAssertNil(provider.lastInput)
        XCTAssertNil(coordinator.state.input)
        _ = weakActivity
    }

    func testLocalResetClearsCoachSnapshotsBeforeDeletingPlannedActivities() async throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let coordinator = CoachCoordinator()
        let provider = CoachInputProvider()
        let nutrition = NutritionViewModel()
        let health = HealthManager()
        let activity = PlannedActivityBuilder.workout(
            title: "Ride",
            at: Date(),
            durationMinutes: 60
        )
        context.insert(activity)
        try context.save()

        await provider.refresh(
            selectedDate: Date(),
            plannedActivities: [activity],
            healthManager: health,
            nutritionViewModel: nutrition,
            coachCoordinator: coordinator,
            source: "localResetTest",
            refreshHealth: false
        )
        XCTAssertNotNil(provider.lastInput)

        var invalidationCalled = false
        let resetService = LocalDataResetService(modelContext: context)
        resetService.beforeDeletingPlannedActivities = {
            invalidationCalled = true
            CoachSnapshotInvalidator.invalidate(
                coordinator: coordinator,
                nutritionViewModel: nutrition,
                inputProvider: provider,
                reason: "localDataReset.test"
            )
            XCTAssertNil(provider.lastInput)
            XCTAssertNil(coordinator.state.input)
        }

        try await resetService.resetAllLocalData()

        XCTAssertTrue(invalidationCalled)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedActivity>()).count, 0)
        XCTAssertNil(provider.lastInput)
        XCTAssertNil(coordinator.state.input)
        XCTAssertNil(nutrition.coachMetricsSnapshot)
    }

    func testHealthReconcileInvokesInvalidationBeforeDeletingStandaloneActivity() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let synced = workout(
            from: time(hour: 9, minute: 30),
            to: time(hour: 10, minute: 20),
            type: .cycling
        )
        let workoutUUID = synced.uuid.uuidString
        let planned = cycling(at: time(hour: 10, minute: 0), durationMinutes: 60)
        let standalone = PlannedActivity(
            id: workoutUUID,
            healthKitWorkoutUUID: workoutUUID,
            date: synced.startDate,
            type: "workout",
            title: "Cycling",
            durationMinutes: 50,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            isCompleted: true,
            source: "appleWorkout"
        )

        context.insert(planned)
        context.insert(standalone)
        try context.save()

        var invalidationCalledBeforeDelete = false
        WeekFitActivityCoordinator.shared.beforePlannedActivityMutation = {
            invalidationCalledBeforeDelete = true
        }

        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            synced,
            with: [standalone, planned],
            modelContext: context
        )
        try context.save()

        XCTAssertTrue(invalidationCalledBeforeDelete)

        let remaining = try context.fetch(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, planned.id)
        XCTAssertTrue(remaining.first?.isCompleted == true)
        XCTAssertEqual(remaining.first?.healthKitWorkoutUUID, workoutUUID)
    }

    private func time(hour: Int, minute: Int) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 12, hour: hour, minute: minute)
        )!
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
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 320),
            totalDistance: nil,
            metadata: nil
        )
    }
}
