import Foundation
import UserNotifications

enum ActivityBadgeNotificationKey {
    static let type = "activityBadgeSuggestion"
    static let badgeID = "badgeID"
    static let identifier = "activity-badge-suggestion"
}

@MainActor
final class ActivitySuggestionNotificationService {
    static let shared = ActivitySuggestionNotificationService()

    private let center = UNUserNotificationCenter.current()

    func noteOpenedAndReschedule(now: Date = Date(), store: ActivityBadgeStore = .shared) {
        Task {
            let settings = await center.notificationSettings()
            let authorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
            var ledger = store.ledger
            let enabled = NotificationPreferencesReader.activitySuggestionsEnabled
            let decision = ActivitySuggestionPlanner.decide(
                now: now,
                suggestionID: ledger.suggestedBadgeID,
                enabled: enabled,
                notificationsAuthorized: authorized,
                lastInviteAt: ledger.lastInviteAt,
                scheduledFireAt: ledger.scheduledFireAt
            )
            ledger.lastInviteAt = decision?.lastInviteAt ?? ledger.lastInviteAt
            if let decision {
                ledger.scheduledFireAt = decision.fireAt
                store.replace(ledger)
                await schedule(decision, ledger: ledger)
            } else {
                ledger.scheduledFireAt = nil
                store.replace(ledger)
                center.removePendingNotificationRequests(withIdentifiers: [ActivityBadgeNotificationKey.identifier])
            }
        }
    }

    func cancel(store: ActivityBadgeStore = .shared) {
        var ledger = store.ledger
        ledger.scheduledFireAt = nil
        store.replace(ledger)
        center.removePendingNotificationRequests(withIdentifiers: [ActivityBadgeNotificationKey.identifier])
    }

    private func schedule(_ decision: ActivitySuggestionPlanner.Decision, ledger: ActivityBadgeLedger) async {
        let content = UNMutableNotificationContent()
        content.title = ActivityBadgeCopy.actionTitle(id: decision.badgeID, ledger: ledger)
        content.body = ActivityBadgeCopy.unlockLine(
            minutes: ActivityBadgeCatalog.definition(id: decision.badgeID)?.actionMinutes,
            badgeName: ActivityBadgeCopy.badgeName(id: decision.badgeID, ledger: ledger)
        )
        content.sound = .default
        content.userInfo = [
            "notificationType": ActivityBadgeNotificationKey.type,
            ActivityBadgeNotificationKey.badgeID: decision.badgeID
        ]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: decision.fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: ActivityBadgeNotificationKey.identifier,
            content: content,
            trigger: trigger
        )
        center.removePendingNotificationRequests(withIdentifiers: [ActivityBadgeNotificationKey.identifier])
        try? await center.add(request)
    }
}

extension NotificationPreferenceKey {
    static let activitySuggestions = "notifications.activitySuggestions"
}

extension NotificationPreferencesReader {
    static var activitySuggestionsEnabled: Bool {
        guard UserDefaults.standard.object(forKey: NotificationPreferenceKey.activitySuggestions) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: NotificationPreferenceKey.activitySuggestions)
    }
}
