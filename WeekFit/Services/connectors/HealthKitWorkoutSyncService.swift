import Foundation
import HealthKit
internal import Combine

@MainActor
final class HealthKitWorkoutSyncService: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = HealthKitWorkoutSyncService()
    
    let startOfDay = Calendar.current.startOfDay(for: Date())

    @Published private(set) var latestCompletedWorkout: HKWorkout?
    @Published private(set) var completedWorkoutsBatch: [HKWorkout] = []

    private let healthStore = HKHealthStore()
    private var anchor: HKQueryAnchor?
    private var seenWorkoutFingerprints: [UUID: String] = [:]
    
    private let syncStartDateKey = "healthkit.workout.syncStartDate"

    private var syncStartDate: Date {
        if let date = UserDefaults.standard.object(forKey: syncStartDateKey) as? Date {
            return date
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(startOfDay, forKey: syncStartDateKey)
        return startOfDay
    }

    private var isActive = false
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var isFetchInFlight = false
    private var pendingForceRefresh = false

    private init() {}

    /// Starts workout observers after the user has completed the main HealthKit authorization flow.
    /// Never requests HealthKit authorization on its own.
    func activateIfAuthorized() {
        guard HKHealthStore.isHealthDataAvailable() else {
            StartupDiagnostics.taskBegin("healthKitWorkoutSync.activate", detail: "unavailable")
            StartupDiagnostics.taskSuccess("healthKitWorkoutSync.activate", detail: "skipped — HK unavailable")
            return
        }
        guard !isActive else {
            StartupDiagnostics.taskBegin("healthKitWorkoutSync.activate", detail: "already active")
            StartupDiagnostics.taskSuccess("healthKitWorkoutSync.activate", detail: "noop")
            return
        }
        StartupDiagnostics.taskBegin("healthKitWorkoutSync.activate", detail: "startObserver+fetchUpdates")
        isActive = true
        startObserver()
        fetchUpdates()
        StartupDiagnostics.taskSuccess("healthKitWorkoutSync.activate")
    }

    func start() {
        activateIfAuthorized()
    }

    /// Stops HealthKit observers and background delivery. Does not revoke system permissions
    /// (iOS does not allow apps to do that) — it only stops WeekFit from using the access.
    func deactivate() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        if let anchoredQuery {
            healthStore.stop(anchoredQuery)
            self.anchoredQuery = nil
        }

        healthStore.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }

        isActive = false
        isFetchInFlight = false
        resetSyncState()
    }

    private func startObserver() {
        let type = HKObjectType.workoutType()

        let query = HKObserverQuery(
            sampleType: type,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            // Complete promptly — never wait on MainActor for HealthKit delivery.
            completionHandler()
            guard error == nil else { return }
            Task { @MainActor in
                self?.fetchUpdates()
            }
        }

        observerQuery = query
        healthStore.execute(query)

        healthStore.enableBackgroundDelivery(
            for: type,
            frequency: .immediate
        ) { _, _ in }
    }

    func forceRefresh() {
        guard isActive else { return }
        if isFetchInFlight {
            pendingForceRefresh = true
            return
        }
        fetchUpdates()
    }

    private func fetchUpdates() {
        guard isActive else { return }
        guard !isFetchInFlight else { return }
        isFetchInFlight = true

        let type = HKObjectType.workoutType()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let fromDate = max(syncStartDate, startOfDay)

        let predicate = HKQuery.predicateForSamples(
            withStart: fromDate,
            end: nil,
            options: .strictStartDate
        )

        if let anchoredQuery {
            healthStore.stop(anchoredQuery)
            self.anchoredQuery = nil
        }

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in
            Task { @MainActor in
                defer { self?.finishFetch() }
                guard error == nil else { return }
                self?.anchor = newAnchor
                self?.consume(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            Task { @MainActor in
                guard error == nil else { return }
                self?.anchor = newAnchor
                self?.consume(samples)
            }
        }

        anchoredQuery = query
        healthStore.execute(query)

        fetchRecentCompletedWorkoutsFallback()
    }

    private func consume(_ samples: [HKSample]?) {
        let workouts = samples as? [HKWorkout] ?? []

//        print("🏋️ Consuming workouts:", workouts.count)

        guard !workouts.isEmpty else {
//            print("⚠️ No workouts in payload")
            return
        }

        let freshnessCutoff = Calendar.current.startOfDay(for: Date())
        
        let candidates = workouts
            .filter { workout in
                workout.endDate >= freshnessCutoff &&
                shouldEmit(workout)
            }
            .sorted { $0.endDate > $1.endDate }

//        print("🆕 Fresh new workouts after filters:", candidates.count)

        candidates.forEach { workout in
//            print(
//                """
//                🧩 Candidate workout:
//                - uuid: \(workout.uuid)
//                - type: \(workout.workoutActivityType.rawValue)
//                - start: \(workout.startDate)
//                - end: \(workout.endDate)
//                - duration: \(Int(workout.duration / 60)) min
//                """
//            )
        }

        guard !candidates.isEmpty else {
//            print("⚠️ No fresh new workouts after filters")
            return
        }

        candidates.forEach { workout in
            seenWorkoutFingerprints[workout.uuid] = fingerprint(workout)
        }

        completedWorkoutsBatch = candidates
        latestCompletedWorkout = candidates.first

//        print("✅ completedWorkoutsBatch updated:", candidates.count)
    }

    func clearCompletedWorkoutsBatch() {
        completedWorkoutsBatch = []
    }

    func resetSyncState() {
        seenWorkoutFingerprints.removeAll()
        pendingForceRefresh = false
        anchor = nil
        latestCompletedWorkout = nil
        clearCompletedWorkoutsBatch()
    }

    private func finishFetch() {
        isFetchInFlight = false
        guard isActive, pendingForceRefresh else {
            pendingForceRefresh = false
            return
        }
        pendingForceRefresh = false
        fetchUpdates()
    }

    /// HealthKit reuses the same UUID from in-progress → completed. Re-emit
    /// when end date or duration changes so Watch completion can land.
    private func shouldEmit(_ workout: HKWorkout) -> Bool {
        seenWorkoutFingerprints[workout.uuid] != fingerprint(workout)
    }

    private func fingerprint(_ workout: HKWorkout) -> String {
        "\(workout.endDate.timeIntervalSince1970)|\(workout.duration)"
    }
    
    private func fetchRecentCompletedWorkoutsFallback() {
//        print("🛟 Running recent workout fallback fetch")

        let type = HKObjectType.workoutType()
        let fromDate = Calendar.current.startOfDay(for: Date())

        let predicate = HKQuery.predicateForSamples(
            withStart: fromDate,
            end: Date(),
            options: []
        )

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 10,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in

            if let error {
//                print("❌ Fallback sample query error:", error)
                return
            }

            let count = samples?.count ?? 0
//            print("🛟 Fallback received:", count, "samples")

            Task { @MainActor in
                self?.consume(samples)
            }
        }

        healthStore.execute(query)
    }
}
