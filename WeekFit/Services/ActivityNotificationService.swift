import Foundation
import UserNotifications

final class ActivityNotificationService {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = ActivityNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let schedulingLock = NSLock()
    private var scheduleInvalidationVersion: [String: Int] = [:]
    private var lastScheduleFingerprints: [String: String] = [:]

    private struct ActivityNotificationSchedule {
        var startReminderDate: Date?
        var completionCheckDate: Date?
    }

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
            #if DEBUG
            if let error {
                print("Notification permission error:", error)
            }
            print("Notification permission granted:", granted)
            #endif

            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    func requestPermissionIfNotDetermined() async -> Bool {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.requestPermission { granted in
                        continuation.resume(returning: granted)
                    }
                case .authorized, .provisional, .ephemeral:
                    continuation.resume(returning: true)
                case .denied:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
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
        cancelAllActivityNotifications()
        WellnessNotificationService.shared.cancelAll()
    }

    func cancelAllActivityNotifications() {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { id in
                    id.hasPrefix("start-")
                        || id.hasPrefix("completion-")
                }

            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .map { $0.request.identifier }
                .filter { id in
                    id.hasPrefix("start-")
                        || id.hasPrefix("completion-")
                }

            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }

        print("🔕 Activity notifications cancelled")
    }

    // MARK: - Main Sync API

    func syncNotifications(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int = 15
    ) {
        syncNotifications(
            for: [activity],
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled,
            minutesBefore: minutesBefore
        )
    }

    func syncNotifications(
        for activities: [PlannedActivity],
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int = 15
    ) {
        let now = Date()
        var pendingSchedules: [(PlannedActivity, ActivityNotificationSchedule, Int)] = []

        for activity in activities {
            switch syncPreparation(
                for: activity,
                activityRemindersEnabled: activityRemindersEnabled,
                completionCheckInsEnabled: completionCheckInsEnabled,
                minutesBefore: minutesBefore,
                now: now
            ) {
            case .skip:
                continue
            case .cancelOnly:
                cancelNotifications(for: activity)
            case .schedule(let schedule, let scheduleVersion):
                pendingSchedules.append((activity, schedule, scheduleVersion))
            }
        }

        guard !pendingSchedules.isEmpty else { return }

        checkPermission { [weak self] isAuthorized in
            guard let self else { return }

            guard isAuthorized else {
                print("⚠️ Notifications not authorized. Skipping scheduling.")
                return
            }

            for (activity, schedule, scheduleVersion) in pendingSchedules {
                self.applyPreparedSchedule(
                    for: activity,
                    schedule: schedule,
                    scheduleVersion: scheduleVersion,
                    minutesBefore: minutesBefore
                )
            }
        }
    }

    // MARK: - Backward-compatible APIs

    func scheduleReminder(for activity: PlannedActivity, minutesBefore: Int = 15) {
        invalidatePendingScheduling(forActivityId: activity.id)
        cancelStartReminder(for: activity)

        let reminderDate = calendar.date(
            byAdding: .minute,
            value: -minutesBefore,
            to: activity.date
        ) ?? activity.date

        guard reminderDate > Date() else { return }

        let scheduleVersion = currentScheduleVersion(forActivityId: activity.id)
        scheduleStartReminder(
            for: activity,
            at: reminderDate,
            minutesBefore: minutesBefore,
            scheduleVersion: scheduleVersion
        )
    }

    func cancelReminder(for activity: PlannedActivity) {
        cancelNotifications(for: activity)
    }

    func cancelReminders(for activities: [PlannedActivity]) {
        activities.forEach { cancelNotifications(for: $0) }
    }

    func cancelNotifications(for activity: PlannedActivity) {
        invalidatePendingScheduling(forActivityId: activity.id)
        clearScheduleFingerprint(forActivityId: activity.id)
        removeScheduledNotifications(for: activity)
    }

    private func removeScheduledNotifications(for activity: PlannedActivity) {
        let ids = notificationIds(for: activity)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        scanAndRemoveNotifications(forActivityId: activity.id, excluding: Set(ids))
    }

    func cancelNotificationsForDeletedActivity(_ activity: PlannedActivity) async {
        await cancelNotificationsForDeletedActivity(
            DeletedActivityNotificationTarget(
                id: activity.id,
                title: activity.title,
                date: activity.date
            )
        )
    }

    func cancelNotificationsForDeletedActivity(_ target: DeletedActivityNotificationTarget) async {
        let targetActivityId = target.id
        invalidatePendingScheduling(forActivityId: targetActivityId)

        let ids = notificationIds(forDeletedActivity: target)
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

    private enum SyncPreparationResult {
        case skip
        case cancelOnly
        case schedule(ActivityNotificationSchedule, Int)
    }

    private func syncPreparation(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int,
        now: Date
    ) -> SyncPreparationResult {
        let fingerprint = scheduleFingerprint(
            for: activity,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled,
            minutesBefore: minutesBefore,
            now: now
        )

        if isFingerprintCurrent(activityId: activity.id, fingerprint: fingerprint) {
            return .skip
        }

        guard !activity.isSkipped, !activity.isCompleted else {
            storeScheduleFingerprint(activityId: activity.id, fingerprint: fingerprint)
            return .cancelOnly
        }

        guard activityRemindersEnabled || completionCheckInsEnabled else {
            storeScheduleFingerprint(activityId: activity.id, fingerprint: fingerprint)
            return .cancelOnly
        }

        let schedule = notificationSchedule(
            for: activity,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled,
            minutesBefore: minutesBefore,
            now: now
        )

        guard schedule.startReminderDate != nil || schedule.completionCheckDate != nil else {
            storeScheduleFingerprint(activityId: activity.id, fingerprint: fingerprint)
            return .cancelOnly
        }

        storeScheduleFingerprint(activityId: activity.id, fingerprint: fingerprint)
        invalidatePendingScheduling(forActivityId: activity.id)
        let scheduleVersion = currentScheduleVersion(forActivityId: activity.id)
        return .schedule(schedule, scheduleVersion)
    }

    private func applyPreparedSchedule(
        for activity: PlannedActivity,
        schedule: ActivityNotificationSchedule,
        scheduleVersion: Int,
        minutesBefore: Int
    ) {
        let activityId = activity.id

        guard isScheduleVersionCurrent(activityId: activityId, version: scheduleVersion) else {
            print("Skipping stale notification schedule for deleted/edited activity:", activityId)
            return
        }

        removeScheduledNotifications(for: activity)

        if let reminderDate = schedule.startReminderDate {
            scheduleStartReminder(
                for: activity,
                at: reminderDate,
                minutesBefore: minutesBefore,
                scheduleVersion: scheduleVersion
            )
        }

        if let confirmationDate = schedule.completionCheckDate {
            scheduleCompletionCheck(
                for: activity,
                at: confirmationDate,
                scheduleVersion: scheduleVersion
            )
        }
    }

    private func notificationSchedule(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int,
        now: Date
    ) -> ActivityNotificationSchedule {
        var startReminderDate: Date?
        if activityRemindersEnabled {
            let reminderDate = calendar.date(
                byAdding: .minute,
                value: -minutesBefore,
                to: activity.date
            ) ?? activity.date
            if reminderDate > now {
                startReminderDate = reminderDate
            }
        }

        var scheduledCompletionDate: Date?
        if completionCheckInsEnabled {
            let confirmationDate = completionCheckDate(for: activity)
            if confirmationDate > now {
                scheduledCompletionDate = confirmationDate
            }
        }

        return ActivityNotificationSchedule(
            startReminderDate: startReminderDate,
            completionCheckDate: scheduledCompletionDate
        )
    }

    private func completionCheckDate(for activity: PlannedActivity) -> Date {
        if activity.type.lowercased() == "meal" {
            return calendar.date(
                byAdding: .minute,
                value: 30,
                to: activity.date
            ) ?? activity.date
        }

        let endDate = calendar.date(
            byAdding: .minute,
            value: activity.durationMinutes,
            to: activity.date
        ) ?? activity.date

        return calendar.date(
            byAdding: .minute,
            value: completionDelayMinutes(for: activity),
            to: endDate
        ) ?? endDate
    }

    private func scheduleFingerprint(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int,
        now: Date = Date()
    ) -> String {
        let schedule = notificationSchedule(
            for: activity,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled,
            minutesBefore: minutesBefore,
            now: now
        )

        return scheduleFingerprint(
            for: activity,
            schedule: schedule,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled,
            minutesBefore: minutesBefore
        )
    }

    private func scheduleFingerprint(
        for activity: PlannedActivity,
        schedule: ActivityNotificationSchedule,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool,
        minutesBefore: Int
    ) -> String {
        [
            activity.id,
            String(activity.isCompleted),
            String(activity.isSkipped),
            String(activity.date.timeIntervalSince1970),
            String(activity.durationMinutes),
            activity.type,
            String(activityRemindersEnabled),
            String(completionCheckInsEnabled),
            String(minutesBefore),
            String(schedule.startReminderDate?.timeIntervalSince1970 ?? -1),
            String(schedule.completionCheckDate?.timeIntervalSince1970 ?? -1)
        ].joined(separator: "|")
    }

    private func isFingerprintCurrent(activityId: String, fingerprint: String) -> Bool {
        schedulingLock.lock()
        defer { schedulingLock.unlock() }
        return lastScheduleFingerprints[activityId] == fingerprint
    }

    private func storeScheduleFingerprint(activityId: String, fingerprint: String) {
        schedulingLock.lock()
        lastScheduleFingerprints[activityId] = fingerprint
        schedulingLock.unlock()
    }

    private func clearScheduleFingerprint(forActivityId activityId: String) {
        schedulingLock.lock()
        lastScheduleFingerprints.removeValue(forKey: activityId)
        schedulingLock.unlock()
    }

    private func scheduleStartReminder(
        for activity: PlannedActivity,
        at reminderDate: Date,
        minutesBefore: Int,
        scheduleVersion: Int
    ) {
        let activityId = activity.id

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
        at confirmationDate: Date,
        scheduleVersion: Int
    ) {
        let activityId = activity.id

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
        notificationIds(
            forDeletedActivity: DeletedActivityNotificationTarget(
                id: activity.id,
                title: activity.title,
                date: activity.date
            )
        )
    }

    private func notificationIds(forDeletedActivity target: DeletedActivityNotificationTarget) -> [String] {
        [
            "start-\(target.id)",
            "completion-\(target.id)",
            "completion-later-\(target.id)",
            "start-\(target.date.timeIntervalSince1970)-\(target.title)",
            "completion-\(target.date.timeIntervalSince1970)-\(target.title)",
            "completion-later-\(target.date.timeIntervalSince1970)-\(target.title)"
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
