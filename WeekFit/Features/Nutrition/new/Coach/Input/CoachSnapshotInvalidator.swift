import Foundation

/// Clears coach caches that retain live SwiftData `PlannedActivity` @Model references.
@MainActor
enum CoachSnapshotInvalidator {

    private static weak var registeredInputProvider: CoachInputProvider?

    static func register(inputProvider: CoachInputProvider) {
        registeredInputProvider = inputProvider
    }

    static func invalidate(
        coordinator: CoachCoordinator,
        nutritionViewModel: NutritionViewModel,
        inputProvider: CoachInputProvider? = nil,
        reason: String
    ) {
        (inputProvider ?? registeredInputProvider)?.invalidateCachedSnapshots()
        coordinator.invalidateCachedSnapshots(reason: reason)
        nutritionViewModel.invalidateCoachActivityReferences()
    }
}
