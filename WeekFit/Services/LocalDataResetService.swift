import Foundation
import SwiftData

@MainActor
final class LocalDataResetService {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    /// Called immediately before any `PlannedActivity` rows are deleted from SwiftData.
    var beforeDeletingPlannedActivities: (() -> Void)?

    private let modelContext: ModelContext
    private let defaults: UserDefaults

    init(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.defaults = defaults
    }

    func resetAllLocalData() async throws {
        print("[LocalDataReset] Starting local data reset")

        var failures: [String] = []

        do {
            try clearSwiftData()
        } catch {
            failures.append("SwiftData/CoreData/local model data: \(error.localizedDescription)")
            print("[LocalDataReset][Failure] SwiftData/CoreData/local model data: \(error)")
        }

        do {
            try clearLocalImages()
        } catch {
            failures.append("Local meal/custom food images: \(error.localizedDescription)")
            print("[LocalDataReset][Failure] Local meal/custom food images: \(error)")
        }

        clearUserDefaults()

        WeekFitActivityCoordinator.shared.resetReconciliationState()
        HealthKitWorkoutSyncService.shared.resetSyncState()

        WeekFitUserSettings.shared.refreshFromStorage()
        print("[LocalDataReset] Refreshed in-memory user settings")

        guard failures.isEmpty else {
            throw LocalDataResetError.partialFailure(failures)
        }

        print("[LocalDataReset] Finished local data reset")
    }

    private func clearSwiftData() throws {
        beforeDeletingPlannedActivities?()

        let activities = try modelContext.fetch(FetchDescriptor<PlannedActivity>())

        for activity in activities {
            modelContext.delete(activity)
        }

        try modelContext.save()
        print("[LocalDataReset] Cleared SwiftData PlannedActivity rows: \(activities.count)")
    }

    private func clearLocalImages() throws {
        try MealPhotoStore.clearAllStoredPhotos()
        print("[LocalDataReset] Cleared locally cached meal/custom food images")
    }

    private func clearUserDefaults() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
            print("[LocalDataReset] Cleared UserDefaults persistent domain: \(bundleIdentifier)")
        } else {
            let knownKeys = [
                ProfileService.Keys.fullName,
                ProfileService.Keys.name,
                ProfileService.Keys.displayName,
                ProfileService.Keys.email,
                ProfileService.Keys.initials,
                ProfileService.Keys.nutritionGoal,
                ProfileService.Keys.nutritionGoalIsManual,
                CustomMealStore.storageKey,
                CustomIngredientStore.storageKey,
                AppLanguage.storageKey,
                "coach_log_level",
                "weekfit_quick_item_usage_v1",
                "weekfit.healthAccessRequested",
                "weekfit.lastHealthReadinessSync",
                "notifications.activityReminders",
                "notifications.completionCheckIns",
                "notifications.recoverySuggestions",
                "notifications.hydrationReminders",
                "notifications.sleepWindDown",
                WellnessNotificationPreferenceKey.recoveryScheduledDay,
                "healthkit.workout.syncStartDate"
            ]

            knownKeys.forEach(defaults.removeObject(forKey:))
            print("[LocalDataReset] Cleared known UserDefaults keys: \(knownKeys.count)")
        }

        defaults.synchronize()
    }
}

enum LocalDataResetError: LocalizedError {
    case partialFailure([String])

    var errorDescription: String? {
        switch self {
        case .partialFailure(let failures):
            return "Reset completed with failures: \(failures.joined(separator: "; "))"
        }
    }
}
