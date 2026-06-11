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

        return matches(activity: activity, workoutType: liveWorkout.workoutType)
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

    private func matches(
        activity: PlannedActivity,
        workoutType: HKWorkoutActivityType
    ) -> Bool {
        let title = activity.title.lowercased()

        switch workoutType {
        case .cycling:
            return title.contains("cycle")
                || title.contains("cycling")
                || title.contains("bike")
                || title.contains("ride")
                || title.contains("вел")
                || title.contains("вело")

        case .running:
            return title.contains("run")
                || title.contains("running")
                || title.contains("бег")

        case .walking:
            return title.contains("walk")
                || title.contains("walking")
                || title.contains("ходь")

        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .highIntensityIntervalTraining,
             .crossTraining:
            return title.contains("workout")
                || title.contains("strength")
                || title.contains("gym")
                || title.contains("training")
                || title.contains("трен")

        case .yoga:
            return title.contains("yoga")
                || title.contains("йога")

        default:
            return false
        }
    }
    
    func reconcileCompletedWorkouts(
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) {
        guard !completedWorkoutsBatch.isEmpty else { return }

        for workout in completedWorkoutsBatch {
            guard let activity = ActivityReconciler.bestMatch(
                for: workout,
                in: activities
            ) else {
                continue
            }

            let actualMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))

            activity.isCompleted = true
            activity.isSkipped = false
            activity.actualDurationMinutes = actualMinutes

            // optional, если есть такие поля:
            // activity.syncedWorkoutID = workout.uuid.uuidString
            // activity.source = "healthkit"
        }

        try? modelContext.save()
    }
}
