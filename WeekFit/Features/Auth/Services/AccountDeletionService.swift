import Foundation
import SwiftData

protocol AccountDeletionServicing: AnyObject {
    func deleteAccount(
        modelContext: ModelContext,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator
    ) async throws
}

/// Permanently deletes the WeekFit account and all associated app data.
///
/// Order of operations (fail closed on remote errors):
/// 1. Delete the account on the WeekFit backend (when configured)
/// 2. Cancel local notifications / background reminder work
/// 3. Clear SwiftData, image caches, and preferences
/// 4. Clear authentication tokens / review-demo session flags
///
/// Callers must keep the user signed in until this method succeeds, then show
/// a success confirmation before signing out.
@MainActor
final class AccountDeletionService: AccountDeletionServicing {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    private let remoteClient: any AccountRemoteDeleting
    private let defaults: UserDefaults

    init(
        remoteClient: (any AccountRemoteDeleting)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.remoteClient = remoteClient ?? AccountRemoteDeletionClient()
        self.defaults = defaults
    }

    func deleteAccount(
        modelContext: ModelContext,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator
    ) async throws {
        // 1. Backend account + cloud data. Failures leave the user signed in.
        try await remoteClient.deleteRemoteAccount()

        // 2. Stop reminder / wellness notification schedules.
        ActivityNotificationService.shared.cancelAllNotifications()
        WellnessNotificationService.shared.cancelAll()

        // 3. Wipe local WeekFit data (SwiftData, photos, caches, preferences).
        let resetService = LocalDataResetService(
            modelContext: modelContext,
            defaults: defaults
        )
        resetService.beforeDeletingPlannedActivities = {
            CoachSnapshotInvalidator.invalidate(
                coordinator: coachCoordinator,
                nutritionViewModel: nutritionViewModel,
                reason: "accountDeletion"
            )
        }
        try await resetService.resetAllLocalData()

        nutritionViewModel.resetLocalState()
        CoachObservationStore.clearAll()
        ActivityConfirmationState.shared.pendingActivity = nil
        WeekFitActivityCoordinator.shared.deactivateHealthKitSync()
        NightComfortLocationService.clearCachedLocation()

        // 4. Remove auth tokens / demo session / DEBUG email registration.
        // System permissions (Apple Health, Location, Notifications) cannot be revoked by the
        // app — iOS keeps them until the user changes Settings. We only stop local use above.
        AuthSessionStore.clear()
        AppReviewDemoCredentials.clearSession()
        AppReviewDemoSettings.shared.setEnabled(false)
        #if DEBUG
        AuthService.DebugEmailAuthStorage.clear(in: defaults)
        AuthService.DebugEmailAuthStorage.clear()
        #endif

        NotificationCenter.default.post(name: .weekfitDidCompleteAccountDeletion, object: nil)
    }
}
