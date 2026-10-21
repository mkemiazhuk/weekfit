import Foundation
import SwiftData

@MainActor
enum PlannedActivityNotificationConfirmationService {

    static func markCompleted(
        _ activity: PlannedActivity,
        modelContext: ModelContext
    ) throws {
        activity.isCompleted = true
        activity.isSkipped = false

        if activity.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activity.source = "planner"
        }

        try modelContext.save()
        ActivityNotificationService.shared.cancelNotifications(for: activity)
        ReviewEngagement.record(.activityLoggedOrCompleted)
        ProductAnalytics.activityCompleted(source: .plan)
        ProductAnalytics.planItemCompleted(itemType: PlanItemAnalyticsType(plannedActivityType: activity.type))
        
        if let adjustment = CoachAdjustmentProvenanceStore.adjustment(forActivityId: activity.id) {
            CoachAdjustmentProvenanceStore.markTerminalOutcome(activityId: activity.id, outcome: "completed")
            ProductAnalytics.morningProposalAdjustedItemCompleted(changeKind: adjustment.kind)
        }
    }

    static func markSkipped(
        _ activity: PlannedActivity,
        modelContext: ModelContext
    ) throws {
        activity.isSkipped = true
        activity.isCompleted = false

        if activity.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activity.source = "planner"
        }

        try modelContext.save()
        ActivityNotificationService.shared.cancelNotifications(for: activity)
    }

    /// Reopens a user-planned activity that was marked completed from Plan.
    /// Does not alter HealthKit imports — callers must only pass toggleable rows.
    static func markIncomplete(
        _ activity: PlannedActivity,
        modelContext: ModelContext
    ) throws {
        activity.isCompleted = false
        activity.isSkipped = false

        try modelContext.save()
    }
}
