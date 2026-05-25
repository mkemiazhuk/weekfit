import Foundation
import UserNotifications

final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationActionHandler()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {

        let userInfo = response.notification.request.content.userInfo

        guard
            let activityId = userInfo[ActivityNotificationKey.activityId] as? String,
            let title = userInfo[ActivityNotificationKey.activityTitle] as? String,
            let timestamp = userInfo[ActivityNotificationKey.activityDate] as? TimeInterval
        else {
            print("Notification action missing activity data:", userInfo)
            return
        }

        let action: ActivityNotificationAction

        switch response.actionIdentifier {

        case NotificationActionID.done:
            action = .done

        case NotificationActionID.skipped:
            action = .skipped

        case NotificationActionID.later:
            action = .later

        case UNNotificationDefaultActionIdentifier:
            action = .open

        default:
            return
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .activityNotificationAction,
                object: nil,
                userInfo: [
                    ActivityNotificationKey.activityId: activityId,
                    ActivityNotificationKey.activityTitle: title,
                    ActivityNotificationKey.activityDate: timestamp,
                    "action": action.rawValue
                ]
            )
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
