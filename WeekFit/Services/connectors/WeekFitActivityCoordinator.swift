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
    /// Phone-side live HR while a planned session window is active (or Watch live workout).
    @Published private(set) var liveHeartRateBPM: Int?
    @Published private(set) var liveHeartRateZone: Int?

    private let watchBridge = WatchLiveWorkoutBridge.shared
    private let healthSync = HealthKitWorkoutSyncService.shared
    private let heartRateMonitor = LiveHeartRateMonitor.shared

    private var cancellables = Set<AnyCancellable>()
    private var reconciledWorkoutUUIDs = Set<String>()
    private var hasStartedWatchBridge = false
    private var hasActivatedHealthSync = false
    private var heartRateMonitoringEnabled = false

    /// Called before deleting or merging SwiftData `PlannedActivity` rows during HealthKit reconciliation.
    var beforePlannedActivityMutation: (() -> Void)?

    private init() {
        StartupDiagnostics.step(
            6,
            "HealthKit service created",
            detail: "WeekFitActivityCoordinator.init (Watch bridge + LiveHeartRateMonitor bound)"
        )
        bind()
    }

    /// Called at app launch. Starts non-HealthKit services only.
    func prepareLaunchServices() {
        guard !hasStartedWatchBridge else { return }
        hasStartedWatchBridge = true
        StartupDiagnostics.step(
            10,
            "watch connectivity",
            detail: "prepareLaunchServices activate=\(WatchConnectivitySupport.shouldActivateSession)"
        )
        watchBridge.start()
    }

    func start() {
        guard AccountSessionController.shared.mode != .reviewDemo else { return }
        prepareLaunchServices()
    }

    /// Called after the user grants HealthKit read access through the main connect flow.
    func activateHealthKitSync() {
        guard AccountSessionController.shared.mode != .reviewDemo else { return }
        prepareLaunchServices()
        guard !hasActivatedHealthSync else { return }
        hasActivatedHealthSync = true
        healthSync.activateIfAuthorized()
    }

    /// Stops HealthKit workout sync after account deletion. System permissions remain until
    /// the user revokes them in iOS Settings / Apple Health.
    func deactivateHealthKitSync() {
        hasActivatedHealthSync = false
        healthSync.deactivate()
        setHeartRateMonitoringEnabled(false)
        resetReconciliationState()
    }
    
    func refresh() {
        guard AccountSessionController.shared.mode != .reviewDemo else { return }
        guard hasActivatedHealthSync else { return }
        healthSync.forceRefresh()
    }

    func restartForRealUser() {
        hasActivatedHealthSync = false
        start()
    }

    /// Start/stop phone-side HR streaming for in-session coach chrome.
    /// Call when a planned activity enters/leaves its live time window.
    func setHeartRateMonitoringEnabled(_ enabled: Bool, sessionStartedAt: Date = Date()) {
        guard AccountSessionController.shared.mode != .reviewDemo else {
            heartRateMonitor.stop()
            liveHeartRateBPM = nil
            liveHeartRateZone = nil
            heartRateMonitoringEnabled = false
            return
        }

        heartRateMonitoringEnabled = enabled
        if enabled {
            heartRateMonitor.start(sessionStartedAt: sessionStartedAt)
        } else {
            heartRateMonitor.stop()
            liveHeartRateBPM = nil
            liveHeartRateZone = nil
            if var liveWorkout {
                liveWorkout.currentHeartRateBPM = nil
                liveWorkout.heartRateZone = nil
                self.liveWorkout = liveWorkout
            }
        }
    }

    /// Convenience: enable monitoring when any of today's activities is currently active.
    func syncHeartRateMonitoring(with activities: [PlannedActivity], now: Date = Date()) {
        let active = activities.first { activity in
            guard !activity.isSkipped else { return false }
            if activity.isActive(at: now) { return true }
            // Keep streaming through the planned window even if HK flips completed early.
            guard activity.isCompleted || activity.isPartialCompletion else { return false }
            let plannedEnd = Calendar.current.date(
                byAdding: .minute,
                value: max(activity.effectiveDurationMinutes, activity.durationMinutes, 1),
                to: activity.date
            ) ?? activity.date
            let graceEnd = plannedEnd.addingTimeInterval(5 * 60)
            return activity.date <= now && now <= graceEnd
        }

        if let active {
            setHeartRateMonitoringEnabled(true, sessionStartedAt: active.date)
        } else if liveWorkout?.isLive == true {
            setHeartRateMonitoringEnabled(true, sessionStartedAt: liveWorkout?.startedAt ?? now)
        } else {
            setHeartRateMonitoringEnabled(false)
        }
    }

    private func bind() {
        watchBridge.$liveWorkout
            .receive(on: RunLoop.main)
            .sink { [weak self] workout in
                guard let self else { return }
                var next = workout
                if heartRateMonitoringEnabled, var live = next {
                    live.currentHeartRateBPM = liveHeartRateBPM
                    live.heartRateZone = liveHeartRateZone
                    next = live
                }
                let previous = self.liveWorkout
                self.liveWorkout = next
                if let live = next, live.isLive {
                    setHeartRateMonitoringEnabled(true, sessionStartedAt: live.startedAt)
                } else if previous?.isLive == true || previous?.state == .ended {
                    healthSync.forceRefresh()
                }
            }
            .store(in: &cancellables)

        heartRateMonitor.$currentBPM
            .combineLatest(heartRateMonitor.$currentZone)
            .receive(on: RunLoop.main)
            .sink { [weak self] bpm, zone in
                guard let self else { return }
                self.liveHeartRateBPM = bpm
                self.liveHeartRateZone = zone
                if var liveWorkout, liveWorkout.isLive {
                    liveWorkout.currentHeartRateBPM = bpm
                    liveWorkout.heartRateZone = zone
                    self.liveWorkout = liveWorkout
                }
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

    func isLiveMatch(for activity: PlannedActivity, among activities: [PlannedActivity] = []) -> Bool {
        guard let best = bestLiveMatch(in: activities.isEmpty ? [activity] : activities) else {
            return false
        }
        return best.id == activity.id
    }

    func resolvedStatus(
        for activity: PlannedActivity,
        among activities: [PlannedActivity] = [],
        baseStatus: PlanActivityStatus
    ) -> PlanActivityStatus {
        if isLiveMatch(for: activity, among: activities) {
            return .live
        }

        return baseStatus
    }

    func bestLiveMatch(in activities: [PlannedActivity]) -> PlannedActivity? {
        guard let liveWorkout, liveWorkout.isLive else { return nil }

        let candidates = activities.filter { activity in
            guard !activity.isSkipped else { return false }
            let timeDistance = abs(activity.date.timeIntervalSince(liveWorkout.startedAt))
            guard timeDistance <= 2 * 60 * 60 else { return false }
            return ActivityReconciler.matches(activity: activity, workoutType: liveWorkout.workoutType)
        }

        return candidates.min { lhs, rhs in
            liveMatchScore(lhs, startedAt: liveWorkout.startedAt) < liveMatchScore(rhs, startedAt: liveWorkout.startedAt)
        }
    }

    /// Link an in-progress Watch/HealthKit session to the overlapping planned slot
    /// and hide the imported duplicate if both exist.
    func reconcileLiveWorkout(
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) {
        guard AccountSessionController.shared.mode != .reviewDemo else { return }
        guard let liveWorkout, liveWorkout.isLive else { return }
        guard let planned = bestLiveMatch(in: activities.filter { $0.healthKitWorkoutUUID == nil && !$0.isCompleted })
                ?? bestLiveMatch(in: activities.filter { !$0.isCompleted }) else {
            return
        }

        var didMutate = false
        if planned.date > liveWorkout.startedAt {
            planned.date = liveWorkout.startedAt
            planned.isSkipped = false
            didMutate = true
        }

        let duplicates = activities.filter { activity in
            activity.id != planned.id
                && !activity.isSkipped
                && ActivityReconciler.matches(activity: activity, workoutType: liveWorkout.workoutType)
                && sessionsOverlap(activity, planned)
                && isImportedSessionStub(activity)
                && !activity.isCompleted
        }

        if !duplicates.isEmpty {
            notifyPlannedActivityMutation()
            for duplicate in duplicates {
                modelContext.delete(duplicate)
            }
            didMutate = true
        }

        if didMutate {
            try? modelContext.save()
        }
    }

    func reconcileCompletedWorkouts(
        with activities: [PlannedActivity],
        modelContext: ModelContext
    ) {
        guard !completedWorkoutsBatch.isEmpty else { return }
        guard AccountSessionController.shared.mode != .reviewDemo else { return }

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
        let taskName = "activity.bootstrapHealthWorkouts"
        StartupDiagnostics.taskBegin(
            taskName,
            detail: "granted=\(healthManager.isHealthAccessGranted) planned=\(activities.count)"
        )
        guard healthManager.isHealthAccessGranted else {
            StartupDiagnostics.taskSuccess(taskName, detail: "skipped — not granted")
            return
        }

        let workouts = await healthManager.loadWorkoutSamples(for: date)
        guard !workouts.isEmpty else {
            StartupDiagnostics.taskSuccess(taskName, detail: "no workouts")
            return
        }

        for workout in workouts {
            reconcileCompletedAppleWorkout(
                workout,
                with: activities,
                modelContext: modelContext,
                forceRetry: true
            )
        }

        do {
            try modelContext.save()
            StartupDiagnostics.taskSuccess(taskName, detail: "workouts=\(workouts.count) saved")
        } catch {
            StartupDiagnostics.taskError(taskName, error: error, detail: "workouts=\(workouts.count)")
        }
    }

    func reconcileCompletedAppleWorkout(
        _ workout: HKWorkout,
        with activities: [PlannedActivity],
        modelContext: ModelContext,
        forceRetry: Bool = false,
        now: Date = Date()
    ) {
        let workoutUUID = workout.uuid.uuidString
        let liveSessionActive = isMatchingLiveWatchSession(workout)
        let inProgress = ActivityReconciler.isLikelyInProgress(
            workout,
            now: now,
            liveSessionActive: liveSessionActive
        )

        if DismissedHealthKitWorkoutStore.isDismissed(workoutUUID) {
            reconciledWorkoutUUIDs.insert(workoutUUID)
            return
        }

        if mergeStandaloneImportIfNeeded(
            workout,
            with: activities,
            modelContext: modelContext,
            inProgress: inProgress,
            liveSessionActive: liveSessionActive,
            now: now
        ) {
            markReconciledIfFinished(workoutUUID, inProgress: inProgress)
            return
        }

        if let persisted = importedWorkoutIfExists(
            uuid: workoutUUID,
            modelContext: modelContext
        ),
           !activities.contains(where: {
               $0.id == persisted.id || $0.healthKitWorkoutUUID == workoutUUID
           }) {
            applyWorkout(workout, to: persisted, inProgress: inProgress)
            markReconciledIfFinished(workoutUUID, inProgress: inProgress)
            return
        }

        if let linkedPlanned = activities.first(where: {
            $0.healthKitWorkoutUUID == workoutUUID && $0.id != workoutUUID
        }) {
            applyWorkout(workout, to: linkedPlanned, inProgress: inProgress)
            markReconciledIfFinished(workoutUUID, inProgress: inProgress)
            return
        }

        if let standalone = activities.first(where: {
            $0.id == workoutUUID || ($0.healthKitWorkoutUUID == workoutUUID && $0.source == "appleWorkout")
        }) {
            if let planned = ActivityReconciler.bestMatch(
                for: workout,
                in: activities.filter { $0.healthKitWorkoutUUID == nil && $0.id != workoutUUID },
                now: now,
                liveSessionActive: liveSessionActive
            ) {
                notifyPlannedActivityMutation()
                modelContext.delete(standalone)
                applyWorkout(workout, to: planned, inProgress: inProgress)
            } else {
                applyWorkout(workout, to: standalone, inProgress: inProgress)
            }

            markReconciledIfFinished(workoutUUID, inProgress: inProgress)
            return
        }

        guard forceRetry || !reconciledWorkoutUUIDs.contains(workoutUUID) else {
            return
        }

        if let persisted = importedWorkoutIfExists(
            uuid: workoutUUID,
            modelContext: modelContext
        ) {
            applyWorkout(workout, to: persisted, inProgress: inProgress)
            markReconciledIfFinished(workoutUUID, inProgress: inProgress)
            return
        }

        if let activity = ActivityReconciler.bestMatch(
            for: workout,
            in: activities,
            now: now,
            liveSessionActive: liveSessionActive
        ) {
            applyWorkout(workout, to: activity, inProgress: inProgress)
        } else {
            let imported = inProgress
                ? ActivityReconciler.importedLiveActivity(for: workout)
                : ActivityReconciler.importedActivity(for: workout)
            modelContext.insert(imported)
        }

        markReconciledIfFinished(workoutUUID, inProgress: inProgress)
    }

    private func mergeStandaloneImportIfNeeded(
        _ workout: HKWorkout,
        with activities: [PlannedActivity],
        modelContext: ModelContext,
        inProgress: Bool,
        liveSessionActive: Bool,
        now: Date
    ) -> Bool {
        let workoutUUID = workout.uuid.uuidString
        guard let standalone = activities.first(where: {
            $0.id == workoutUUID || ($0.healthKitWorkoutUUID == workoutUUID && $0.source == "appleWorkout")
        }) else {
            return false
        }

        guard let planned = ActivityReconciler.bestMatch(
            for: workout,
            in: activities.filter { $0.healthKitWorkoutUUID == nil && $0.id != workoutUUID },
            now: now,
            liveSessionActive: liveSessionActive
        ) else {
            return false
        }

        notifyPlannedActivityMutation()
        modelContext.delete(standalone)
        applyWorkout(workout, to: planned, inProgress: inProgress)
        return true
    }

    private func applyWorkout(
        _ workout: HKWorkout,
        to activity: PlannedActivity,
        inProgress: Bool
    ) {
        if inProgress {
            ActivityReconciler.applyLiveWorkout(workout, to: activity)
        } else {
            ActivityReconciler.applySyncedWorkout(workout, to: activity)
        }
    }

    /// A just-finished Watch workout has `endDate ≈ now`. Treat it as live only
    /// while Watch Connectivity still reports an active matching session.
    private func isMatchingLiveWatchSession(_ workout: HKWorkout) -> Bool {
        guard let liveWorkout, liveWorkout.isLive else { return false }
        guard liveWorkout.workoutType == workout.workoutActivityType else { return false }
        return abs(liveWorkout.startedAt.timeIntervalSince(workout.startDate)) <= 15 * 60
    }

    /// Live HealthKit samples keep the same UUID when they complete. Do not
    /// freeze that UUID until the finished sample has been applied.
    private func markReconciledIfFinished(_ workoutUUID: String, inProgress: Bool) {
        guard !inProgress else { return }
        reconciledWorkoutUUIDs.insert(workoutUUID)
    }

#if DEBUG
    func replaceLiveWorkoutForTesting(_ workout: WeekFitLiveWorkout?) {
        liveWorkout = workout
    }
#endif

    private func liveMatchScore(_ activity: PlannedActivity, startedAt: Date) -> Double {
        let startDelta = abs(activity.date.timeIntervalSince(startedAt)) / 60
        let importedPenalty = isImportedSessionStub(activity) ? 20.0 : 0
        let completedPenalty = activity.isCompleted ? 40.0 : 0
        return startDelta + importedPenalty + completedPenalty
    }

    private func isImportedSessionStub(_ activity: PlannedActivity) -> Bool {
        let source = activity.source.lowercased()
        return source == "appleworkout"
            || source == "healthkit"
            || source == "applewatch"
    }

    private func sessionsOverlap(_ lhs: PlannedActivity, _ rhs: PlannedActivity) -> Bool {
        let leftEnd = lhs.date.addingTimeInterval(TimeInterval(max(lhs.effectiveDurationMinutes, lhs.durationMinutes, 1) * 60))
        let rightEnd = rhs.date.addingTimeInterval(TimeInterval(max(rhs.effectiveDurationMinutes, rhs.durationMinutes, 1) * 60))
        return lhs.date < rightEnd && rhs.date < leftEnd
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
