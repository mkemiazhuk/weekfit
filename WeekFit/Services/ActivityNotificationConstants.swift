import Foundation

extension Notification.Name {
    static let activityNotificationAction =
        Notification.Name("activityNotificationAction")
    static let morningProposalNotificationAction =
        Notification.Name("morningProposalNotificationAction")
}

enum MorningProposalNotificationKey {
    static let dayKey = "dayKey"
    static let proposalId = "proposalId"
    static let notificationType = "notificationType"
}

enum ActivityNotificationAction: String {
    case done
    case skipped
    case later
    case open
}

enum NotificationActionID {
    static let done = "ACTIVITY_DONE"
    static let skipped = "ACTIVITY_SKIPPED"
    static let later = "ACTIVITY_LATER"
}

enum ActivityNotificationKey {
    static let activityId = "activityId"
    static let activityTitle = "activityTitle"
    static let activityDate = "activityDate"
}
