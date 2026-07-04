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
    private var seenWorkoutIDs = Set<UUID>()
    
    private let syncStartDateKey = "healthkit.workout.syncStartDate"

    private var syncStartDate: Date {
        if let date = UserDefaults.standard.object(forKey: syncStartDateKey) as? Date {
            return date
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(startOfDay, forKey: syncStartDateKey)
        return startOfDay
    }

    private init() {}

    func start() {
//        print("🚀 HealthKitWorkoutSyncService.start()")

        guard HKHealthStore.isHealthDataAvailable() else {
//            print("❌ Health data not available")
            return
        }

        let workoutType = HKObjectType.workoutType()

        healthStore.requestAuthorization(
            toShare: [],
            read: [workoutType]
        ) { [weak self] success, error in

            if let error {
//                print("❌ HealthKit authorization error:", error)
            }

//            print("🔐 HealthKit authorization success:", success)

            guard success, error == nil else {
//                print("❌ HealthKit authorization failed")
                return
            }

            Task { @MainActor in
//                print("✅ Starting observer + initial fetch")

                self?.startObserver()
                self?.fetchUpdates()
            }
        }
    }

    private func startObserver() {
//        print("👀 Starting HKObserverQuery")

        let type = HKObjectType.workoutType()

        let query = HKObserverQuery(
            sampleType: type,
            predicate: nil
        ) { [weak self] _, completionHandler, error in

            if let error {
//                print("❌ HKObserverQuery error:", error)
                completionHandler()
                return
            }

//            print("📡 HKObserverQuery fired")

            Task { @MainActor in
                self?.fetchUpdates()
                completionHandler()
            }
        }

        healthStore.execute(query)

        healthStore.enableBackgroundDelivery(
            for: type,
            frequency: .immediate
        ) { success, error in

            if let error {
//                print("❌ Background delivery error:", error)
            }

//            print("📬 Background delivery enabled:", success)
        }
    }

    func forceRefresh() {
//        print("🔄 Manual forceRefresh()")
        fetchUpdates()
    }

    private func fetchUpdates() {
//        print("⬇️ Fetching workout updates")

        let type = HKObjectType.workoutType()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let fromDate = max(syncStartDate, startOfDay)

//        print("🕒 Workout sync from:", fromDate)

        let predicate = HKQuery.predicateForSamples(
            withStart: fromDate,
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in

            if let error {
//                print("❌ Initial anchored query error:", error)
                return
            }

            let count = samples?.count ?? 0
//            print("📥 Initial anchored fetch received:", count, "samples")

            Task { @MainActor in
                self?.anchor = newAnchor
                self?.consume(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in

            if let error {
//                print("❌ Update handler error:", error)
                return
            }

            let count = samples?.count ?? 0
//            print("🔄 Anchored update received:", count, "samples")

            Task { @MainActor in
                self?.anchor = newAnchor
                self?.consume(samples)
            }
        }

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
                !seenWorkoutIDs.contains(workout.uuid)
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
            seenWorkoutIDs.insert(workout.uuid)
        }

        completedWorkoutsBatch = candidates
        latestCompletedWorkout = candidates.first

//        print("✅ completedWorkoutsBatch updated:", candidates.count)
    }

    func clearCompletedWorkoutsBatch() {
        completedWorkoutsBatch = []
    }

    func resetSyncState() {
        seenWorkoutIDs.removeAll()
        anchor = nil
        latestCompletedWorkout = nil
        clearCompletedWorkoutsBatch()
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
