import Foundation
import OSLog
import SwiftData

@MainActor
final class LocalDataResetService {

    private static let logger = Logger(subsystem: "WeekFit", category: "LocalDataReset")

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
        #if DEBUG
        Self.logger.debug("Starting local data reset")
        #endif

        var failures: [String] = []

        do {
            try clearSwiftData()
        } catch {
            failures.append("SwiftData/CoreData/local model data: \(error.localizedDescription)")
            Self.logger.error("Local data reset failed step=SwiftData error=\(String(describing: error), privacy: .public)")
        }

        do {
            try clearLocalImages()
        } catch {
            failures.append("Local meal/custom food images: \(error.localizedDescription)")
            Self.logger.error("Local data reset failed step=localImages error=\(String(describing: error), privacy: .public)")
        }

        clearUserDefaults()

        WeekFitActivityCoordinator.shared.resetReconciliationState()
        HealthKitWorkoutSyncService.shared.resetSyncState()

        WeekFitUserSettings.shared.refreshFromStorage()
        #if DEBUG
        Self.logger.debug("Refreshed in-memory user settings")
        #endif

        guard failures.isEmpty else {
            throw LocalDataResetError.partialFailure(failures)
        }

        #if DEBUG
        Self.logger.debug("Finished local data reset")
        #endif
    }

    private func clearSwiftData() throws {
        let activities = try modelContext.fetch(FetchDescriptor<PlannedActivity>())

        for activity in activities {
            modelContext.delete(activity)
        }

        try modelContext.save()
        #if DEBUG
        Self.logger.debug("Cleared SwiftData PlannedActivity rows count=\(activities.count, privacy: .public)")
        #endif
    }

    private func clearLocalImages() throws {
        try MealPhotoStore.clearAllStoredPhotos()
        #if DEBUG
        Self.logger.debug("Cleared locally cached meal/custom food images")
        #endif
    }

    private func clearUserDefaults() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
            #if DEBUG
            Self.logger.debug("Cleared UserDefaults persistent domain")
            #endif
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
                "healthkit.workout.syncStartDate"
            ]

            knownKeys.forEach(defaults.removeObject(forKey:))
            #if DEBUG
            Self.logger.debug("Cleared known UserDefaults keys count=\(knownKeys.count, privacy: .public)")
            #endif
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
