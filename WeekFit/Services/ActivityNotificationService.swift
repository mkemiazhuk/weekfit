import Foundation
import UserNotifications

final class ActivityNotificationService {

    static let shared = ActivityNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private init() {
        registerActivityCompletionActions()
    }

    func requestPermission(
        completion: ((Bool) -> Void)? = nil
    ) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error:", error)
            }

            print("Notification permission granted:", granted)

            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    func checkPermission(
        completion: @escaping (Bool) -> Void
    ) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()

        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        print("🔕 All notifications cancelled")
    }

    // MARK: - Main Sync API

    func syncNotifications(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int = 15
    ) {
        cancelNotifications(for: activity)

        guard !activity.isSkipped else { return }
        guard activityRemindersEnabled || completionCheckInsEnabled else { return }

        checkPermission { [weak self] isAuthorized in
            guard let self else { return }

            guard isAuthorized else {
                print("⚠️ Notifications not authorized. Skipping scheduling.")
                return
            }

            if activityRemindersEnabled {
                self.scheduleStartReminder(for: activity, minutesBefore: minutesBefore)
            }

            if completionCheckInsEnabled {
                self.scheduleCompletionCheck(for: activity)
            }
        }
    }

    func syncNotifications(
        for activities: [PlannedActivity],
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int = 15
    ) {
        activities.forEach {
            syncNotifications(
                for: $0,
                activityRemindersEnabled: activityRemindersEnabled,
                completionCheckInsEnabled: completionCheckInsEnabled,
                minutesBefore: minutesBefore
            )
        }
    }

    // MARK: - Backward-compatible APIs

    func scheduleReminder(for activity: PlannedActivity, minutesBefore: Int = 15) {
        cancelStartReminder(for: activity)
        scheduleStartReminder(for: activity, minutesBefore: minutesBefore)
    }

    func cancelReminder(for activity: PlannedActivity) {
        cancelNotifications(for: activity)
    }

    func cancelReminders(for activities: [PlannedActivity]) {
        let ids = activities.flatMap { notificationIds(for: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelNotifications(for activity: PlannedActivity) {
        center.removePendingNotificationRequests(
            withIdentifiers: notificationIds(for: activity)
        )
    }

    func cancelCompletionCheck(for activity: PlannedActivity) {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                completionNotificationId(for: activity),
                completionLaterNotificationId(for: activity)
            ]
        )
    }

    func scheduleCompletionCheckLater(
        for activity: PlannedActivity,
        minutesLater: Int = 15
    ) {
        let laterDate = calendar.date(
            byAdding: .minute,
            value: minutesLater,
            to: Date()
        ) ?? Date()

        let content = UNMutableNotificationContent()
        content.title = completionTitle(for: activity)
        content.body = "\(activity.title) • \(activity.durationMinutes) min"
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_COMPLETION"
        content.userInfo = userInfo(for: activity, notificationType: "completionLater")

        let request = notificationRequest(
            id: completionLaterNotificationId(for: activity),
            content: content,
            date: laterDate
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule later completion check:", error)
            } else {
                print("Later completion check scheduled:", activity.title, laterDate)
            }
        }
    }

    // MARK: - Private Scheduling

    private func scheduleStartReminder(
        for activity: PlannedActivity,
        minutesBefore: Int
    ) {
        let reminderDate = calendar.date(
            byAdding: .minute,
            value: -minutesBefore,
            to: activity.date
        ) ?? activity.date

        guard reminderDate > Date() else {
            print("Start reminder date is in the past. Notification skipped.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming activity"
        content.body = "\(activity.title) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.userInfo = userInfo(for: activity, notificationType: "start")

        let request = notificationRequest(
            id: startNotificationId(for: activity),
            content: content,
            date: reminderDate
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule start reminder:", error)
            } else {
                print("Start reminder scheduled:", activity.title, reminderDate)
            }
        }
    }

    private func scheduleCompletionCheck(for activity: PlannedActivity) {
        let confirmationDate: Date

        if activity.type.lowercased() == "meal" {
            confirmationDate = calendar.date(
                byAdding: .minute,
                value: 30,
                to: activity.date
            ) ?? activity.date
        } else {
            let endDate = calendar.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date

            confirmationDate = calendar.date(
                byAdding: .minute,
                value: completionDelayMinutes(for: activity),
                to: endDate
            ) ?? endDate
        }

        guard confirmationDate > Date() else {
            print("Completion check date is in the past. Notification skipped.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = completionTitle(for: activity)
        content.body = "\(activity.title) • \(activity.durationMinutes) min"
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_COMPLETION"
        content.userInfo = userInfo(for: activity, notificationType: "completion")

        let request = notificationRequest(
            id: completionNotificationId(for: activity),
            content: content,
            date: confirmationDate
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule completion check:", error)
            } else {
                print("Completion check scheduled:", activity.title, confirmationDate)
            }
        }
    }

    private func cancelStartReminder(for activity: PlannedActivity) {
        center.removePendingNotificationRequests(
            withIdentifiers: [startNotificationId(for: activity)]
        )
    }

    // MARK: - Helpers

    private func notificationIds(for activity: PlannedActivity) -> [String] {
        [
            startNotificationId(for: activity),
            completionNotificationId(for: activity),
            completionLaterNotificationId(for: activity)
        ]
    }

    private func registerActivityCompletionActions() {
        let doneAction = UNNotificationAction(
            identifier: NotificationActionID.done,
            title: "Done",
            options: []
        )

        let skipAction = UNNotificationAction(
            identifier: NotificationActionID.skipped,
            title: "Skip",
            options: []
        )

        let laterAction = UNNotificationAction(
            identifier: NotificationActionID.later,
            title: "Remind later",
            options: []
        )

        let completionCategory = UNNotificationCategory(
            identifier: "ACTIVITY_COMPLETION",
            actions: [doneAction, skipAction, laterAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([completionCategory])
    }

    private func notificationRequest(
        id: String,
        content: UNMutableNotificationContent,
        date: Date
    ) -> UNNotificationRequest {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
    }

    private func userInfo(
        for activity: PlannedActivity,
        notificationType: String
    ) -> [String: Any] {
        [
            ActivityNotificationKey.activityId: activity.id,
            ActivityNotificationKey.activityTitle: activity.title,
            ActivityNotificationKey.activityDate: activity.date.timeIntervalSince1970,
            "activityType": activity.type,
            "notificationType": notificationType
        ]
    }

    private func completionDelayMinutes(for activity: PlannedActivity) -> Int {
        switch activity.type.lowercased() {
        case "meal":
            return 10
        case "workout", "recovery":
            return 15
        case "habit":
            return 5
        default:
            return 5
        }
    }

    private func completionTitle(for activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {
        case "meal":
            return "Meal completed?"
        case "workout":
            return "Workout completed?"
        case "recovery":
            return "Recovery session finished?"
        case "habit":
            return "Did you complete this?"
        default:
            return "Did you complete this?"
        }
    }

    private func startNotificationId(for activity: PlannedActivity) -> String {
        "start-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }

    private func completionNotificationId(for activity: PlannedActivity) -> String {
        "completion-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }

    private func completionLaterNotificationId(for activity: PlannedActivity) -> String {
        "completion-later-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }
}
