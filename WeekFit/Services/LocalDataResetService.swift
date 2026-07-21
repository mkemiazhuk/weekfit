import Foundation
import OSLog
import SwiftData

@MainActor
final class LocalDataResetService {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    /// Called immediately before any `PlannedActivity` rows are deleted from SwiftData.
    var beforeDeletingPlannedActivities: (() -> Void)?

    private let modelContext: ModelContext
    private let defaults: UserDefaults
    private static let logger = Logger(subsystem: "WeekFit", category: "LocalDataReset")

    init(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.defaults = defaults
    }

    func resetAllLocalData() async throws {
        debugLog("Starting local data reset")

        var failures: [String] = []

        do {
            try clearSwiftData()
        } catch {
            failures.append("SwiftData/CoreData/local model data: \(error.localizedDescription)")
            Self.logger.error("SwiftData reset failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try clearLocalImages()
        } catch {
            failures.append("Local meal/custom food images: \(error.localizedDescription)")
            Self.logger.error("Image reset failed: \(error.localizedDescription, privacy: .public)")
        }

        clearUserDefaults()

        WeekFitActivityCoordinator.shared.resetReconciliationState()
        HealthKitWorkoutSyncService.shared.resetSyncState()

        WeekFitUserSettings.shared.refreshFromStorage()
        debugLog("Refreshed in-memory user settings")

        guard failures.isEmpty else {
            throw LocalDataResetError.partialFailure(failures)
        }

        debugLog("Finished local data reset")
    }

    private func clearSwiftData() throws {
        beforeDeletingPlannedActivities?()

        // Always wipe both stores. Account deletion / fresh-account prep can run while
        // the environment context points at review-demo, leaving production orphaned.
        try wipeAllActivities(in: WeekFitModelContainer.productionContext())
        try wipeAllActivities(in: WeekFitModelContainer.reviewDemoContext())

        // Keep the caller's context coherent if it is a separate ModelContext instance.
        try wipeAllActivities(in: modelContext)
    }

    private func wipeAllActivities(in context: ModelContext) throws {
        let activities = try context.fetch(FetchDescriptor<PlannedActivity>())
        guard !activities.isEmpty else { return }

        for activity in activities {
            context.delete(activity)
        }
        try context.save()
        debugLog("Cleared SwiftData PlannedActivity rows: \(activities.count)")
    }

    private func clearLocalImages() throws {
        try MealPhotoStore.clearAllStoredPhotos()
        debugLog("Cleared locally cached meal/custom food images")
    }

    private func clearUserDefaults() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
            debugLog("Cleared UserDefaults persistent domain: \(bundleIdentifier)")
        } else {
            let knownKeys = [
                ProfileService.Keys.fullName,
                ProfileService.Keys.name,
                ProfileService.Keys.displayName,
                ProfileService.Keys.email,
                ProfileService.Keys.initials,
                ProfileService.Keys.nutritionGoal,
                ProfileService.Keys.nutritionGoalIsManual,
                OnboardingStore.Keys.completed,
                OnboardingStore.Keys.step,
                OnboardingStore.Keys.flowVersion,
                OnboardingStore.Keys.introToday,
                OnboardingStore.Keys.introCoach,
                OnboardingStore.Keys.introPlan,
                OnboardingStore.Keys.introMeals,
                CustomMealStore.storageKey,
                CustomIngredientStore.storageKey,
                AppLanguage.storageKey,
                "coach_log_level",
                "weekfit_quick_item_usage_v1",
                "weekfit.healthAccessRequested",
                "weekfit.lastHealthReadinessSync",
                AppReviewDemoStore.enabledKey,
                AppReviewDemoStore.scenarioKey,
                AppReviewDemoStore.sessionActiveKey,
                "notifications.activityReminders",
                "notifications.completionCheckIns",
                "notifications.recoverySuggestions",
                "notifications.hydrationReminders",
                "notifications.sleepWindDown",
                WellnessNotificationPreferenceKey.recoveryScheduledDay,
                "healthkit.workout.syncStartDate",
                "weekfit.debug.auth.email",
                "weekfit.debug.auth.password"
            ]

            knownKeys.forEach(defaults.removeObject(forKey:))
            debugLog("Cleared known UserDefaults keys: \(knownKeys.count)")
        }

        defaults.synchronize()
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        Self.logger.debug("\(message, privacy: .public)")
        #endif
    }
}

enum LocalDataResetError: LocalizedError {
    case partialFailure([String])

    var errorDescription: String? {
        switch self {
        case .partialFailure(let failures):
            return failures.joined(separator: "\n")
        }
    }
}
