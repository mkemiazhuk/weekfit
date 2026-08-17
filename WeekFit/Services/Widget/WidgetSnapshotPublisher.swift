import Foundation
import WidgetKit
import WeekFitPlanner
import WeekFitWidgetShared

/// Persists widget snapshots and asks WidgetKit to reload timelines.
enum WidgetSnapshotPublisher {
    static let widgetKind = "WeekFitHomeWidget"

    @MainActor
    static func publish(_ snapshot: WeekFitWidgetSnapshot) {
        do {
            _ = try WidgetSnapshotStore.save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            #if DEBUG
            print("[WidgetSnapshot] save failed: \(error)")
            #endif
        }
    }

    @MainActor
    static func publishFromLiveState(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        plannedActivities: [PlannedActivity]
    ) {
        let snapshot = WidgetSnapshotBuilder.build(
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            plannedActivities: plannedActivities
        )
        publish(snapshot)
    }
}
