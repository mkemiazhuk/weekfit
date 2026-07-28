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
            ProductAnalytics.notificationOpened(category: .activity)
            try? PlannedActivityNotificationConfirmationService.markCompleted(
                activity,
                modelContext: modelContext
            )
            onActivityStateChanged?()

        case .skipped:
            ProductAnalytics.notificationOpened(category: .activity)
            try? PlannedActivityNotificationConfirmationService.markSkipped(
                activity,
                modelContext: modelContext
            )
            onActivityStateChanged?()

        case .later:
            ProductAnalytics.notificationOpened(category: .activity)
            ActivityNotificationService.shared.cancelCompletionCheck(for: activity)
            ActivityNotificationService.shared.scheduleCompletionCheckLater(for: activity)

        case .open:
            ProductAnalytics.notificationOpened(category: .activity)
            ActivityConfirmationState.shared.pendingActivity = activity
            onActivityStateChanged?()
        }
    }
}
