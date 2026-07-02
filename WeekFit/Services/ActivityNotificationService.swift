import Foundation
import UserNotifications

final class ActivityNotificationService {

    static let shared = ActivityNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let schedulingLock = NSLock()
    private var scheduleInvalidationVersion: [String: Int] = [:]

    private init() {
        registerActivityCompletionActions()
    }

    func refreshLocalizedCategories() {
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

        let activityId = activity.id
        let scheduleVersion = currentScheduleVersion(forActivityId: activityId)

        checkPermission { [weak self] isAuthorized in
            guard let self else { return }
            guard self.isScheduleVersionCurrent(activityId: activityId, version: scheduleVersion) else {
                print("Skipping stale notification schedule for deleted/edited activity:", activityId)
                return
            }

            guard isAuthorized else {
                print("⚠️ Notifications not authorized. Skipping scheduling.")
                return
            }

            if activityRemindersEnabled {
                self.scheduleStartReminder(
                    for: activity,
                    minutesBefore: minutesBefore,
                    scheduleVersion: scheduleVersion
                )
            }

            if completionCheckInsEnabled {
                self.scheduleCompletionCheck(
                    for: activity,
                    scheduleVersion: scheduleVersion
                )
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
        let scheduleVersion = currentScheduleVersion(forActivityId: activity.id)
        scheduleStartReminder(for: activity, minutesBefore: minutesBefore, scheduleVersion: scheduleVersion)
    }

    func cancelReminder(for activity: PlannedActivity) {
        cancelNotifications(for: activity)
    }

    func cancelReminders(for activities: [PlannedActivity]) {
        activities.forEach { cancelNotifications(for: $0) }
    }

    func cancelNotifications(for activity: PlannedActivity) {
        invalidatePendingScheduling(forActivityId: activity.id)

        let ids = notificationIds(for: activity)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        scanAndRemoveNotifications(forActivityId: activity.id, excluding: Set(ids))
    }

    func cancelNotificationsForDeletedActivity(_ activity: PlannedActivity) async {
        let targetActivityId = activity.id
        invalidatePendingScheduling(forActivityId: targetActivityId)

        let ids = notificationIds(for: activity)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        await scanAndRemoveNotificationsAwaiting(forActivityId: targetActivityId, excluding: Set(ids))
    }

    func cancelCompletionCheck(for activity: PlannedActivity) {
        invalidatePendingScheduling(forActivityId: activity.id)

        let ids = [
            completionNotificationId(for: activity),
            completionNotificationIdLegacy(for: activity),
            completionLaterNotificationId(for: activity),
            completionLaterNotificationIdLegacy(for: activity)
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        scanAndRemoveNotifications(forActivityId: activity.id, excluding: Set(ids))
    }

    func scheduleCompletionCheckLater(
        for activity: PlannedActivity,
        minutesLater: Int = 15
    ) {
        let activityId = activity.id
        let scheduleVersion = currentScheduleVersion(forActivityId: activityId)

        let laterDate = calendar.date(
            byAdding: .minute,
            value: minutesLater,
            to: Date()
        ) ?? Date()

        let content = UNMutableNotificationContent()
        content.title = completionTitle(for: activity)
        content.body = durationBody(for: activity)
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_COMPLETION"
        content.userInfo = userInfo(for: activity, notificationType: "completionLater")

        let request = notificationRequest(
            id: completionLaterNotificationId(for: activity),
            content: content,
            date: laterDate
        )

        center.add(request) { [weak self] error in
            guard let self else { return }
            guard self.isScheduleVersionCurrent(activityId: activityId, version: scheduleVersion) else {
                self.center.removePendingNotificationRequests(
                    withIdentifiers: [request.identifier]
                )
                return
            }

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
        minutesBefore: Int,
        scheduleVersion: Int
    ) {
        let activityId = activity.id
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
        content.title = WeekFitLocalizedString("notifications.activity.upcoming.title")
        content.body = String(
            format: WeekFitLocalizedString("notifications.activity.upcoming.bodyFormat"),
            activity.title,
            minutesBefore
        )
        content.sound = .default
        content.userInfo = userInfo(for: activity, notificationType: "start")

        let request = notificationRequest(
            id: startNotificationId(for: activity),
            content: content,
            date: reminderDate
        )

        center.add(request) { [weak self] error in
            guard let self else { return }
            guard self.isScheduleVersionCurrent(activityId: activityId, version: scheduleVersion) else {
                self.center.removePendingNotificationRequests(
                    withIdentifiers: [request.identifier]
                )
                return
            }

            if let error {
                print("Failed to schedule start reminder:", error)
            } else {
                print("Start reminder scheduled:", activity.title, reminderDate)
            }
        }
    }

    private func scheduleCompletionCheck(
        for activity: PlannedActivity,
        scheduleVersion: Int
    ) {
        let activityId = activity.id
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
        content.body = durationBody(for: activity)
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_COMPLETION"
        content.userInfo = userInfo(for: activity, notificationType: "completion")

        let request = notificationRequest(
            id: completionNotificationId(for: activity),
            content: content,
            date: confirmationDate
        )

        center.add(request) { [weak self] error in
            guard let self else { return }
            guard self.isScheduleVersionCurrent(activityId: activityId, version: scheduleVersion) else {
                self.center.removePendingNotificationRequests(
                    withIdentifiers: [request.identifier]
                )
                return
            }

            if let error {
                print("Failed to schedule completion check:", error)
            } else {
                print("Completion check scheduled:", activity.title, confirmationDate)
            }
        }
    }

    private func cancelStartReminder(for activity: PlannedActivity) {
        let ids = [
            startNotificationId(for: activity),
            startNotificationIdLegacy(for: activity)
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func invalidatePendingScheduling(forActivityId activityId: String) {
        schedulingLock.lock()
        scheduleInvalidationVersion[activityId, default: 0] += 1
        schedulingLock.unlock()
    }

    private func currentScheduleVersion(forActivityId activityId: String) -> Int {
        schedulingLock.lock()
        defer { schedulingLock.unlock() }
        return scheduleInvalidationVersion[activityId, default: 0]
    }

    private func isScheduleVersionCurrent(activityId: String, version: Int) -> Bool {
        schedulingLock.lock()
        defer { schedulingLock.unlock() }
        return scheduleInvalidationVersion[activityId, default: 0] == version
    }

    private func scanAndRemoveNotifications(
        forActivityId activityId: String,
        excluding excluded: Set<String>
    ) {
        Task {
            await scanAndRemoveNotificationsAwaiting(forActivityId: activityId, excluding: excluded)
        }
    }

    private func scanAndRemoveNotificationsAwaiting(
        forActivityId targetActivityId: String,
        excluding excluded: Set<String>
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var pendingIDs: [String] = []
            var deliveredIDs: [String] = []
            var pendingDone = false
            var deliveredDone = false

            func finishIfReady() {
                guard pendingDone, deliveredDone else { return }

                let ids = pendingIDs + deliveredIDs
                if !ids.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: ids)
                    center.removeDeliveredNotifications(withIdentifiers: ids)
                }

                continuation.resume()
            }

            center.getPendingNotificationRequests { [self] requests in
                pendingIDs = requests.compactMap { request in
                    guard !excluded.contains(request.identifier) else { return nil }
                    guard activityId(from: request.content.userInfo) == targetActivityId else { return nil }
                    return request.identifier
                }
                pendingDone = true
                finishIfReady()
            }

            center.getDeliveredNotifications { [self] notifications in
                deliveredIDs = notifications.compactMap { notification in
                    let identifier = notification.request.identifier
                    guard !excluded.contains(identifier) else { return nil }
                    guard activityId(from: notification.request.content.userInfo) == targetActivityId else { return nil }
                    return identifier
                }
                deliveredDone = true
                finishIfReady()
            }
        }
    }

    // MARK: - Helpers

    private func notificationIds(for activity: PlannedActivity) -> [String] {
        [
            startNotificationId(for: activity),
            startNotificationIdLegacy(for: activity),
            completionNotificationId(for: activity),
            completionNotificationIdLegacy(for: activity),
            completionLaterNotificationId(for: activity),
            completionLaterNotificationIdLegacy(for: activity)
        ]
    }

    private func activityId(from userInfo: [AnyHashable: Any]) -> String? {
        if let id = userInfo[ActivityNotificationKey.activityId] as? String {
            return id
        }

        if let id = userInfo[ActivityNotificationKey.activityId] as? NSString {
            return id as String
        }

        return nil
    }

    private func registerActivityCompletionActions() {
        let doneAction = UNNotificationAction(
            identifier: NotificationActionID.done,
            title: WeekFitLocalizedString("common.action.done"),
            options: []
        )

        let skipAction = UNNotificationAction(
            identifier: NotificationActionID.skipped,
            title: WeekFitLocalizedString("notifications.activity.action.skip"),
            options: []
        )

        let laterAction = UNNotificationAction(
            identifier: NotificationActionID.later,
            title: WeekFitLocalizedString("notifications.activity.action.remindLater"),
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
            return WeekFitLocalizedString("notifications.activity.completion.meal")
        case "workout":
            return WeekFitLocalizedString("notifications.activity.completion.workout")
        case "recovery":
            return WeekFitLocalizedString("notifications.activity.completion.recovery")
        case "habit":
            return WeekFitLocalizedString("notifications.activity.completion.generic")
        default:
            return WeekFitLocalizedString("notifications.activity.completion.generic")
        }
    }

    private func durationBody(for activity: PlannedActivity) -> String {
        String(
            format: WeekFitLocalizedString("notifications.activity.durationBodyFormat"),
            activity.title,
            activity.durationMinutes
        )
    }

    private func startNotificationId(for activity: PlannedActivity) -> String {
        "start-\(activity.id)"
    }

    private func completionNotificationId(for activity: PlannedActivity) -> String {
        "completion-\(activity.id)"
    }

    private func completionLaterNotificationId(for activity: PlannedActivity) -> String {
        "completion-later-\(activity.id)"
    }

    private func startNotificationIdLegacy(for activity: PlannedActivity) -> String {
        "start-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }

    private func completionNotificationIdLegacy(for activity: PlannedActivity) -> String {
        "completion-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }

    private func completionLaterNotificationIdLegacy(for activity: PlannedActivity) -> String {
        "completion-later-\(activity.date.timeIntervalSince1970)-\(activity.title)"
    }
}
