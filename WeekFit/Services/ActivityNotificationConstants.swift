import Foundation

extension Notification.Name {
    static let activityNotificationAction =
        Notification.Name("activityNotificationAction")
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
