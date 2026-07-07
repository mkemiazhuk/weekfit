import Foundation
import WeekFitPlanner

/// Workout UUIDs the user removed from the plan — HealthKit reconcile must not re-import them.
enum DismissedHealthKitWorkoutStore {
    private static let storageKey = "weekfit.dismissedHealthKitWorkoutUUIDs"

    static func recordDeletion(of activity: PlannedActivity) {
        if let uuid = activity.healthKitWorkoutUUID, !uuid.isEmpty {
            dismiss(uuid)
        }

        let normalizedSource = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedSource == "appleworkout" || normalizedSource == "healthkit" || normalizedSource == "applewatch" {
            dismiss(activity.id)
        }
    }

    static func isDismissed(_ workoutUUID: String) -> Bool {
        dismissed.contains(workoutUUID)
    }

    static func dismiss(_ workoutUUID: String) {
        guard !workoutUUID.isEmpty else { return }
        var stored = dismissed
        guard stored.insert(workoutUUID).inserted else { return }
        UserDefaults.standard.set(Array(stored), forKey: storageKey)
    }

    private static var dismissed: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }
}
