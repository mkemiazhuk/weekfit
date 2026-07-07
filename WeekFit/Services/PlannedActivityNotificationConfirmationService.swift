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
}
