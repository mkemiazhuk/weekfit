import Foundation

enum MorningProposalNotificationPreferenceKey {
    static let handledDay = "morning.proposal.notification.handledDay"
}

enum MorningProposalNotificationIdentifier {
    static func ready(dayKey: String) -> String {
        "morning-proposal-\(dayKey)"
    }
}

enum MorningProposalNotificationType {
    static let ready = "morningProposalReady"
}

struct MorningProposalNotificationContext: Equatable {
    let now: Date
    let proposal: MorningPlanProposal?
    let wakeTime: Date?
    /// True when the Today morning-proposal card can already be seen (Today tab + active scene).
    let todaySurfaceVisible: Bool
    let preferenceEnabled: Bool
    let handledDayKey: String?
}

enum MorningProposalNotificationAction: Equatable {
    case none
    case schedule(fireDate: Date, dayKey: String)
    case suppressHandled(dayKey: String)
    case cancel(dayKey: String?)
}

enum MorningProposalNotificationPlanner {

    static let defaultWakeHour = 7
    static let defaultWakeMinute = 0
    static let postWakeDelayMinutes = 20

    static func decide(
        for context: MorningProposalNotificationContext,
        calendar: Calendar = .current
    ) -> MorningProposalNotificationAction {
        guard context.preferenceEnabled else {
            return .cancel(dayKey: context.proposal?.dayKey ?? context.handledDayKey)
        }

        guard let proposal = context.proposal else {
            return .cancel(dayKey: context.handledDayKey)
        }

        let dayKey = proposal.dayKey

        switch proposal.status {
        case .applied, .dismissed, .expired, .unavailable, .failed, .stale, .noChangesNeeded, .gatheringData, .applying:
            return .cancel(dayKey: dayKey)
        case .proposalReady, .reviewing:
            break
        }

        guard MorningProposalPresenter.hasConfidentProposal(proposal) else {
            return .cancel(dayKey: dayKey)
        }

        guard CoachMorningOverviewPolicy.isBeforeLocalNoon(now: context.now, calendar: calendar) else {
            return .cancel(dayKey: dayKey)
        }

        if context.handledDayKey == dayKey {
            return .none
        }

        // Today card already visible — mark handled so we don't nag later.
        if context.todaySurfaceVisible {
            return .suppressHandled(dayKey: dayKey)
        }

        guard let fireDate = fireDate(
            now: context.now,
            wakeTime: context.wakeTime,
            calendar: calendar
        ) else {
            return .cancel(dayKey: dayKey)
        }

        return .schedule(fireDate: fireDate, dayKey: dayKey)
    }

    /// Wake-aligned fire time: `max(now, wake+20m)` with 07:00 fallback, still inside morning window.
    static func fireDate(
        now: Date,
        wakeTime: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard CoachMorningOverviewPolicy.isBeforeLocalNoon(now: now, calendar: calendar) else {
            return nil
        }

        let defaultWake = calendar.date(
            bySettingHour: defaultWakeHour,
            minute: defaultWakeMinute,
            second: 0,
            of: now
        ) ?? now

        let resolvedWake: Date = {
            guard let wakeTime, calendar.isDate(wakeTime, inSameDayAs: now) else {
                return defaultWake
            }
            return wakeTime
        }()

        let preferred = calendar.date(
            byAdding: .minute,
            value: postWakeDelayMinutes,
            to: resolvedWake
        ) ?? resolvedWake.addingTimeInterval(TimeInterval(postWakeDelayMinutes * 60))

        let candidate = max(now, preferred)
        if CoachMorningOverviewPolicy.isBeforeLocalNoon(now: candidate, calendar: calendar) {
            return candidate
        }
        // Preferred slipped past noon but we're still in-window — fire immediately.
        return now
    }
}
