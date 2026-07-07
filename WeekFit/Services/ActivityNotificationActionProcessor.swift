import Foundation
import SwiftData

@MainActor
enum ActivityNotificationActionProcessor {

    static func handle(
        userInfo: [AnyHashable: Any]?,
        modelContext: ModelContext,
        onActivityStateChanged: (() -> Void)? = nil
    ) {
        guard let userInfo else { return }

        guard
            let activityId = userInfo[ActivityNotificationKey.activityId] as? String,
            let actionRaw = userInfo["action"] as? String,
            let action = ActivityNotificationAction(rawValue: actionRaw)
        else {
            return
        }

        guard let activity = try? PlannedActivityPersistenceService.fetchActivity(
            id: activityId,
            in: modelContext
        ) else {
            return
        }

        switch action {
        case .done:
            try? PlannedActivityNotificationConfirmationService.markCompleted(
                activity,
                modelContext: modelContext
            )
            onActivityStateChanged?()

        case .skipped:
            try? PlannedActivityNotificationConfirmationService.markSkipped(
                activity,
                modelContext: modelContext
            )
            onActivityStateChanged?()

        case .later:
            ActivityNotificationService.shared.cancelCompletionCheck(for: activity)
            ActivityNotificationService.shared.scheduleCompletionCheckLater(for: activity)

        case .open:
            ActivityConfirmationState.shared.pendingActivity = activity
            onActivityStateChanged?()
        }
    }
}
