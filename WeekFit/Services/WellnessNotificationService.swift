import Foundation
import UserNotifications
import WeekFitPlanner

final class WellnessNotificationService {

    nonisolated deinit {}

    static let shared = WellnessNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private var lastSyncSignature: String?

    private init() {}

    func sync(
        hydrationRemindersEnabled: Bool,
        recoverySuggestionsEnabled: Bool,
        plannedActivities: [PlannedActivity],
        recoveryPercent: Int,
        now: Date = Date()
    ) {
        let context = WellnessNotificationContext(
            now: now,
            recoveryPercent: recoveryPercent,
            plannedActivities: plannedActivities,
            recoveryScheduledDayKey: defaults.string(
                forKey: WellnessNotificationPreferenceKey.recoveryScheduledDay
            )
        )
        let recoveryDecision = WellnessNotificationPlanner.recoveryDecision(for: context)
        let signature = wellnessSyncSignature(
            hydrationRemindersEnabled: hydrationRemindersEnabled,
            recoverySuggestionsEnabled: recoverySuggestionsEnabled,
            recoveryPercent: recoveryPercent,
            recoveryDecision: recoveryDecision
        )

        guard signature != lastSyncSignature else { return }
        lastSyncSignature = signature

        syncHydrationReminders(enabled: hydrationRemindersEnabled)

        syncRecoverySuggestion(
            enabled: recoverySuggestionsEnabled,
            context: context,
            decision: recoveryDecision
        )
    }

    func cancelAll() {
        lastSyncSignature = nil
        var ids = WellnessNotificationIdentifier.allHydrationReminderIDs
        ids.append(WellnessNotificationIdentifier.recoverySuggestion)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelHydrationReminders() {
        let ids = WellnessNotificationIdentifier.allHydrationReminderIDs
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelRecoverySuggestion() {
        let id = WellnessNotificationIdentifier.recoverySuggestion
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    private func syncHydrationReminders(enabled: Bool) {
        cancelHydrationReminders()
        guard enabled else { return }

        checkPermission { [weak self] isAuthorized in
            guard let self, isAuthorized else { return }

            for hour in WellnessNotificationPlanner.hydrationReminderHours {
                self.scheduleHydrationReminder(atHour: hour)
            }
        }
    }

    private func syncRecoverySuggestion(
        enabled: Bool,
        context: WellnessNotificationContext,
        decision: WellnessRecoveryScheduleDecision
    ) {
        cancelRecoverySuggestion()

        guard enabled else {
            clearRecoveryScheduledDayIfNeeded(for: context.now)
            return
        }

        guard decision.shouldSchedule, let fireDate = decision.fireDate else {
            return
        }

        checkPermission { [weak self] isAuthorized in
            guard let self, isAuthorized else { return }

            self.scheduleRecoverySuggestion(at: fireDate)

            if let dayKey = decision.dayKeyToMark {
                self.defaults.set(dayKey, forKey: WellnessNotificationPreferenceKey.recoveryScheduledDay)
            }
        }
    }

    private func wellnessSyncSignature(
        hydrationRemindersEnabled: Bool,
        recoverySuggestionsEnabled: Bool,
        recoveryPercent: Int,
        recoveryDecision: WellnessRecoveryScheduleDecision
    ) -> String {
        [
            String(hydrationRemindersEnabled),
            String(recoverySuggestionsEnabled),
            String(recoveryPercent),
            String(recoveryDecision.shouldSchedule),
            String(recoveryDecision.fireDate?.timeIntervalSince1970 ?? -1),
            recoveryDecision.dayKeyToMark ?? "none"
        ].joined(separator: "|")
    }

    private func scheduleHydrationReminder(atHour hour: Int) {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = WeekFitLocalizedString("notifications.wellness.hydration.title")
        content.body = WeekFitLocalizedString("notifications.wellness.hydration.body")
        content.sound = .default
        content.userInfo = [
            "notificationType": "wellnessHydration",
            "hour": hour
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: WellnessNotificationIdentifier.hydrationReminder(hour: hour),
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule hydration reminder:", error)
            }
        }
    }

    private func scheduleRecoverySuggestion(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = WeekFitLocalizedString("notifications.wellness.recovery.title")
        content.body = WeekFitLocalizedString("notifications.wellness.recovery.body")
        content.sound = .default
        content.userInfo = [
            "notificationType": "wellnessRecovery"
        ]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: WellnessNotificationIdentifier.recoverySuggestion,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule recovery suggestion:", error)
            }
        }
    }

    private func clearRecoveryScheduledDayIfNeeded(for now: Date) {
        let todayKey = WellnessNotificationPlanner.dayKey(for: now, calendar: calendar)
        if defaults.string(forKey: WellnessNotificationPreferenceKey.recoveryScheduledDay) == todayKey {
            defaults.removeObject(forKey: WellnessNotificationPreferenceKey.recoveryScheduledDay)
        }
    }

    private func checkPermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
}

enum NotificationPreferencesReader {

    static var activityRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: NotificationPreferenceKey.activityReminders)
    }

    static var completionCheckInsEnabled: Bool {
        UserDefaults.standard.bool(forKey: NotificationPreferenceKey.completionCheckIns)
    }

    static var recoverySuggestionsEnabled: Bool {
        preferenceBool(
            forKey: NotificationPreferenceKey.recoverySuggestions,
            defaultValue: true
        )
    }

    static var hydrationRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: NotificationPreferenceKey.hydrationReminders)
    }

    private static func preferenceBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }
}

enum NotificationSyncCoordinator {

    private struct SyncRequest: Equatable {
        var includeActivities: Bool
        var includeWellness: Bool
        var plannedActivitiesSignature: String
        var recoveryPercent: Int
        var source: String
    }

    @MainActor
    private static var debounceTask: Task<Void, Never>?
    @MainActor
    private static var pendingRequest: SyncRequest?
    @MainActor
    private static var lastAppliedRequest: SyncRequest?
    @MainActor
    private static var latestPlannedActivities: [PlannedActivity] = []
    @MainActor
    private static var latestRecoveryPercent: Int = 0
    @MainActor
    private static var latestNow: Date = Date()

    @MainActor
    static func syncAll(
        plannedActivities: [PlannedActivity],
        recoveryPercent: Int,
        source: String = "unspecified",
        now: Date = Date()
    ) {
        enqueueSync(
            includeActivities: true,
            includeWellness: true,
            plannedActivities: plannedActivities,
            recoveryPercent: recoveryPercent,
            source: source,
            now: now
        )
    }

    @MainActor
    static func syncWellness(
        plannedActivities: [PlannedActivity],
        recoveryPercent: Int,
        source: String = "unspecified",
        now: Date = Date()
    ) {
        enqueueSync(
            includeActivities: false,
            includeWellness: true,
            plannedActivities: plannedActivities,
            recoveryPercent: recoveryPercent,
            source: source,
            now: now
        )
    }

    @MainActor
    static func syncActivities(
        plannedActivities: [PlannedActivity],
        source: String = "unspecified"
    ) {
        enqueueSync(
            includeActivities: true,
            includeWellness: false,
            plannedActivities: plannedActivities,
            recoveryPercent: 0,
            source: source
        )
    }

    @MainActor
    private static func enqueueSync(
        includeActivities: Bool,
        includeWellness: Bool,
        plannedActivities: [PlannedActivity],
        recoveryPercent: Int,
        source: String,
        now: Date = Date()
    ) {
        latestPlannedActivities = plannedActivities
        latestRecoveryPercent = recoveryPercent
        latestNow = now

        let request = SyncRequest(
            includeActivities: includeActivities,
            includeWellness: includeWellness,
            plannedActivitiesSignature: plannedActivitiesSyncSignature(
                plannedActivities,
                now: now
            ),
            recoveryPercent: recoveryPercent,
            source: source
        )

        pendingRequest = mergedRequest(pendingRequest, request)

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let request = pendingRequest else { return }
            pendingRequest = nil
            performSync(
                request,
                plannedActivities: latestPlannedActivities,
                recoveryPercent: latestRecoveryPercent,
                now: latestNow
            )
        }
    }

    @MainActor
    private static func performSync(
        _ request: SyncRequest,
        plannedActivities: [PlannedActivity],
        recoveryPercent: Int,
        now: Date
    ) {
        let appliedRequest = SyncRequest(
            includeActivities: request.includeActivities,
            includeWellness: request.includeWellness,
            plannedActivitiesSignature: plannedActivitiesSyncSignature(
                plannedActivities,
                now: now
            ),
            recoveryPercent: recoveryPercent,
            source: request.source
        )

        if appliedRequest == lastAppliedRequest {
            #if DEBUG
            print("[NotificationSync] skipped duplicate source=\(request.source)")
            #endif
            return
        }

        lastAppliedRequest = appliedRequest

        #if DEBUG
        print("[NotificationSync] source=\(appliedRequest.source) recovery=\(recoveryPercent)")
        #endif

        if request.includeActivities {
            ActivityNotificationService.shared.syncNotifications(
                for: plannedActivities,
                activityRemindersEnabled: NotificationPreferencesReader.activityRemindersEnabled,
                completionCheckInsEnabled: NotificationPreferencesReader.completionCheckInsEnabled
            )
        }

        if request.includeWellness {
            WellnessNotificationService.shared.sync(
                hydrationRemindersEnabled: NotificationPreferencesReader.hydrationRemindersEnabled,
                recoverySuggestionsEnabled: NotificationPreferencesReader.recoverySuggestionsEnabled,
                plannedActivities: plannedActivities,
                recoveryPercent: recoveryPercent,
                now: now
            )
        }
    }

    @MainActor
    private static func mergedRequest(_ existing: SyncRequest?, _ incoming: SyncRequest) -> SyncRequest {
        guard let existing else { return incoming }

        return SyncRequest(
            includeActivities: existing.includeActivities || incoming.includeActivities,
            includeWellness: existing.includeWellness || incoming.includeWellness,
            plannedActivitiesSignature: incoming.plannedActivitiesSignature,
            recoveryPercent: max(existing.recoveryPercent, incoming.recoveryPercent),
            source: "\(existing.source)+\(incoming.source)"
        )
    }

    private static func plannedActivitiesSyncSignature(
        _ activities: [PlannedActivity],
        now: Date
    ) -> String {
        activities.map { activity in
            [
                activity.id,
                String(activity.isCompleted),
                String(activity.isSkipped),
                String(activity.date.timeIntervalSince1970),
                String(activity.durationMinutes),
                activity.type
            ].joined(separator: ":")
        }.joined(separator: ";")
    }
}
