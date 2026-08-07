import Foundation
import UserNotifications

final class MorningProposalNotificationService {

    nonisolated deinit {}

    static let shared = MorningProposalNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard

    private init() {}

    @MainActor
    func sync(
        proposal: MorningPlanProposal?,
        wakeTime: Date?,
        todaySurfaceVisible: Bool,
        givenName: String? = nil,
        now: Date = Date()
    ) {
        let handledDayKey = defaults.string(forKey: MorningProposalNotificationPreferenceKey.handledDay)
        let context = MorningProposalNotificationContext(
            now: now,
            proposal: proposal,
            wakeTime: wakeTime,
            todaySurfaceVisible: todaySurfaceVisible,
            preferenceEnabled: NotificationPreferencesReader.morningPlanCheckEnabled,
            handledDayKey: handledDayKey
        )

        switch MorningProposalNotificationPlanner.decide(for: context, calendar: calendar) {
        case .none:
            break

        case .suppressHandled(let dayKey):
            markHandled(dayKey: dayKey)
            cancel(dayKey: dayKey)

        case .cancel(let dayKey):
            cancel(dayKey: dayKey)

        case .schedule(let fireDate, let dayKey):
            guard let proposal else { return }
            scheduleReadyNotification(
                proposal: proposal,
                dayKey: dayKey,
                fireDate: fireDate,
                givenName: givenName
            )
        }
    }

    func cancel(dayKey: String?) {
        var ids: [String] = []
        if let dayKey {
            ids.append(MorningProposalNotificationIdentifier.ready(dayKey: dayKey))
        }
        // Also clear any delivered/pending from a prior day key stored as handled.
        if let handled = defaults.string(forKey: MorningProposalNotificationPreferenceKey.handledDay),
           handled != dayKey {
            ids.append(MorningProposalNotificationIdentifier.ready(dayKey: handled))
        }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() {
        if let handled = defaults.string(forKey: MorningProposalNotificationPreferenceKey.handledDay) {
            cancel(dayKey: handled)
        }
        // Best-effort: clear today's id even if not marked handled.
        let todayKey = ProposalInputFingerprintBuilder.dayKey(for: Date(), calendar: calendar)
        cancel(dayKey: todayKey)
        defaults.removeObject(forKey: MorningProposalNotificationPreferenceKey.handledDay)
    }

    func markHandled(dayKey: String) {
        defaults.set(dayKey, forKey: MorningProposalNotificationPreferenceKey.handledDay)
    }

    func resetHandledForTests() {
        defaults.removeObject(forKey: MorningProposalNotificationPreferenceKey.handledDay)
    }

    private func scheduleReadyNotification(
        proposal: MorningPlanProposal,
        dayKey: String,
        fireDate: Date,
        givenName: String?
    ) {
        cancel(dayKey: dayKey)

        checkPermission { [weak self] isAuthorized in
            guard let self, isAuthorized else { return }

            let brief = MorningProposalBriefComposer.compose(
                proposal: proposal,
                givenName: givenName
            )
            let content = UNMutableNotificationContent()
            content.title = WeekFitLocalizedString("notifications.morningPlanCheck.title")
            let bodySeed = brief.actionLines.first ?? brief.headline
            content.body = String(
                format: WeekFitLocalizedString("notifications.morningPlanCheck.body"),
                bodySeed
            )
            content.sound = .default
            content.userInfo = [
                "notificationType": MorningProposalNotificationType.ready,
                "dayKey": dayKey,
                "proposalId": proposal.id
            ]

            let trigger: UNNotificationTrigger
            let delay = fireDate.timeIntervalSinceNow
            if delay <= 1 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            } else {
                let components = self.calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

            let request = UNNotificationRequest(
                identifier: MorningProposalNotificationIdentifier.ready(dayKey: dayKey),
                content: content,
                trigger: trigger
            )

            self.center.add(request) { error in
                if let error {
                    print("Failed to schedule morning plan check:", error)
                    return
                }
                DispatchQueue.main.async {
                    self.markHandled(dayKey: dayKey)
                    MorningProposalAnalytics.notificationScheduled(dayKey: dayKey)
                }
            }
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
