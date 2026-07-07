import Foundation
import HealthKit
internal import Combine
import SwiftData

@MainActor
final class WeekFitActivityCoordinator: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = WeekFitActivityCoordinator()

    @Published private(set) var liveWorkout: WeekFitLiveWorkout?
    @Published private(set) var latestCompletedWorkout: HKWorkout?
    @Published private(set) var completedWorkoutsBatch: [HKWorkout] = []

    private let watchBridge = WatchLiveWorkoutBridge.shared
    private let healthSync = HealthKitWorkoutSyncService.shared

    private var cancellables = Set<AnyCancellable>()
    private var reconciledWorkoutUUIDs = Set<String>()

    /// Called before deleting or merging SwiftData `PlannedActivity` rows during HealthKit reconciliation.
    var beforePlannedActivityMutation: (() -> Void)?

    private init() {
        bind()
    }

    func start() {
        watchBridge.start()
        healthSync.start()
    }
    
    func refresh() {
        healthSync.forceRefresh()
    }

    private func bind() {
        watchBridge.$liveWorkout
            .receive(on: RunLoop.main)
            .sink { [weak self] workout in
                self?.liveWorkout = workout
            }
            .store(in: &cancellables)

        healthSync.$completedWorkoutsBatch
            .receive(on: RunLoop.main)
            .sink { [weak self] workouts in
                guard !workouts.isEmpty else { return }

                self?.completedWorkoutsBatch = workouts
            }
            .store(in: &cancellables)
    }

    func isLiveMatch(for activity: PlannedActivity) -> Bool {
        guard let liveWorkout, liveWorkout.isLive else { return false }

        let timeDistance = abs(activity.date.timeIntervalSince(liveWorkout.startedAt))
        guard timeDistance <= 2 * 60 * 60 else { return false }

        return ActivityReconciler.matches(activity: activity, workoutType: liveWorkout.workoutType)
    }

    func resolvedStatus(
        for activity: PlannedActivity,
        baseStatus: PlanActivityStatus
    ) -> PlanActivityStatus {
        if isLiveMatch(for: activity) {
            return .live
        }

        return baseStatus
    }

    func reconcileCompletedWorkouts(
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) {
        guard !completedWorkoutsBatch.isEmpty else { return }

        for workout in completedWorkoutsBatch {
            reconcileCompletedAppleWorkout(
                workout,
                with: activities,
                modelContext: modelContext
            )
        }

        try? modelContext.save()
        clearCompletedWorkoutsBatch()
    }

    func clearCompletedWorkoutsBatch() {
        completedWorkoutsBatch = []
        healthSync.clearCompletedWorkoutsBatch()
    }

    func resetReconciliationState() {
        reconciledWorkoutUUIDs.removeAll()
        clearCompletedWorkoutsBatch()
    }

    /// Pulls completed workouts already stored in Health for the given day and reconciles them
    /// with the planner. Used when there is no live Watch bridge (phone-only Health activity).
    func bootstrapHealthWorkouts(
        for date: Date,
        healthManager: HealthManager,
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) async {
        guard healthManager.isHealthAccessGranted else { return }

        let workouts = await healthManager.loadWorkoutSamples(for: date)
        guard !workouts.isEmpty else { return }

        for workout in workouts {
            reconcileCompletedAppleWorkout(
                workout,
                with: activities,
                modelContext: modelContext,
                forceRetry: true
            )
        }

        try? modelContext.save()
    }

    func reconcileCompletedAppleWorkout(
        _ workout: HKWorkout,
        with activities: [PlannedActivity],
        modelContext: ModelContext,
        forceRetry: Bool = false
    ) {
        let workoutUUID = workout.uuid.uuidString

        if DismissedHealthKitWorkoutStore.isDismissed(workoutUUID) {
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if let persisted = importedWorkoutIfExists(
            uuid: workoutUUID,
            modelContext: modelContext
        ),
           !activities.contains(where: {
               $0.id == persisted.id || $0.healthKitWorkoutUUID == workoutUUID
           }) {
            ActivityReconciler.applySyncedWorkout(workout, to: persisted)
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if let linkedPlanned = activities.first(where: {
            $0.healthKitWorkoutUUID == workoutUUID && $0.id != workoutUUID
        }) {
            ActivityReconciler.applySyncedWorkout(workout, to: linkedPlanned)
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if let standalone = activities.first(where: {
            $0.id == workoutUUID || ($0.healthKitWorkoutUUID == workoutUUID && $0.source == "appleWorkout")
        }) {
            if let planned = ActivityReconciler.bestMatch(
                for: workout,
                in: activities.filter { $0.healthKitWorkoutUUID == nil && $0.id != workoutUUID }
            ) {
                notifyPlannedActivityMutation()
                modelContext.delete(standalone)
                ActivityReconciler.applySyncedWorkout(workout, to: planned)
            } else {
                ActivityReconciler.applySyncedWorkout(workout, to: standalone)
            }

            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        guard forceRetry || !reconciledWorkoutUUIDs.contains(workoutUUID) else {
            return
        }

        if let persisted = importedWorkoutIfExists(
            uuid: workoutUUID,
            modelContext: modelContext
        ) {
            ActivityReconciler.applySyncedWorkout(workout, to: persisted)
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if let activity = ActivityReconciler.bestMatch(
            for: workout,
            in: activities
        ) {
            ActivityReconciler.applySyncedWorkout(workout, to: activity)
        } else {
            let imported = ActivityReconciler.importedActivity(for: workout)
            modelContext.insert(imported)
        }

        reconciledWorkoutUUIDs.insert(workoutUUID)
    }

    private func notifyPlannedActivityMutation() {
        beforePlannedActivityMutation?()
    }

    private func importedWorkoutIfExists(
        uuid: String,
        modelContext: ModelContext
    ) -> PlannedActivity? {
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.healthKitWorkoutUUID == uuid || activity.id == uuid
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
