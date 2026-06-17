import Foundation
import HealthKit
internal import Combine
import SwiftData

@MainActor
final class WeekFitActivityCoordinator: ObservableObject {

    static let shared = WeekFitActivityCoordinator()

    @Published private(set) var liveWorkout: WeekFitLiveWorkout?
    @Published private(set) var latestCompletedWorkout: HKWorkout?
    @Published private(set) var completedWorkoutsBatch: [HKWorkout] = []

    private let watchBridge = WatchLiveWorkoutBridge.shared
    private let healthSync = HealthKitWorkoutSyncService.shared

    private var cancellables = Set<AnyCancellable>()
    private var reconciledWorkoutUUIDs = Set<String>()

    private init() {
        bind()
    }

    func start() {
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

//                print("📦 Coordinator received workouts batch:", workouts.count)
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

    private func matchesCurrentLiveWorkout(_ workout: HKWorkout) -> Bool {
        guard let liveWorkout else { return false }

        let sameType = liveWorkout.workoutType == workout.workoutActivityType
        let closeStart = abs(workout.startDate.timeIntervalSince(liveWorkout.startedAt)) <= 10 * 60

        return sameType && closeStart
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
    }

    func reconcileCompletedAppleWorkout(
        _ workout: HKWorkout,
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) {
        let workoutUUID = workout.uuid.uuidString

        guard !reconciledWorkoutUUIDs.contains(workoutUUID) else {
            return
        }

        guard !activities.contains(where: {
            $0.healthKitWorkoutUUID == workoutUUID || $0.id == workoutUUID
        }) else {
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if let activity = ActivityReconciler.bestMatch(
            for: workout,
            in: activities
        ) {
            let actualMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))

            activity.isCompleted = true
            activity.isSkipped = false
            activity.healthKitWorkoutUUID = workoutUUID
            activity.actualDurationMinutes = actualMinutes
        } else {
            let imported = ActivityReconciler.importedActivity(for: workout)
            modelContext.insert(imported)
        }

        reconciledWorkoutUUIDs.insert(workoutUUID)
    }
}
