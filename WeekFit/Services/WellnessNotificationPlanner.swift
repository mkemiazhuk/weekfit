import Foundation
import WeekFitPlanner

enum WellnessNotificationPreferenceKey {
    static let recoveryScheduledDay = "wellness.recoverySuggestion.scheduledDay"
}

enum WellnessNotificationIdentifier {
    static let recoverySuggestion = "wellness-recovery-suggestion"

    static func hydrationReminder(hour: Int) -> String {
        "wellness-hydration-\(hour)"
    }

    static let allHydrationReminderIDs = [10, 14, 18].map(hydrationReminder(hour:))
}

struct WellnessNotificationContext: Equatable {
    let now: Date
    let recoveryPercent: Int
    let plannedActivities: [PlannedActivity]
    let recoveryScheduledDayKey: String?
}

struct WellnessRecoveryScheduleDecision: Equatable {
    let shouldSchedule: Bool
    let fireDate: Date?
    let dayKeyToMark: String?
}

enum WellnessNotificationPlanner {

    static let hydrationReminderHours = [10, 14, 18]
    static let recoverySuggestionHour = 9
    static let recoverySuggestionMinute = 30
    static let lowRecoveryThreshold = 65

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func recoveryDecision(
        for context: WellnessNotificationContext,
        calendar: Calendar = .current
    ) -> WellnessRecoveryScheduleDecision {
        let todayKey = dayKey(for: context.now, calendar: calendar)

        if context.recoveryScheduledDayKey == todayKey {
            return WellnessRecoveryScheduleDecision(
                shouldSchedule: false,
                fireDate: nil,
                dayKeyToMark: nil
            )
        }

        guard !hasRecoveryPlannedToday(
            activities: context.plannedActivities,
            now: context.now,
            calendar: calendar
        ) else {
            return WellnessRecoveryScheduleDecision(
                shouldSchedule: false,
                fireDate: nil,
                dayKeyToMark: nil
            )
        }

        let hadWorkoutYesterday = hadCompletedWorkoutYesterday(
            activities: context.plannedActivities,
            now: context.now,
            calendar: calendar
        )
        let lowRecovery = context.recoveryPercent > 0
            && context.recoveryPercent < lowRecoveryThreshold

        guard hadWorkoutYesterday || lowRecovery else {
            return WellnessRecoveryScheduleDecision(
                shouldSchedule: false,
                fireDate: nil,
                dayKeyToMark: nil
            )
        }

        guard let fireDate = nextRecoverySuggestionDate(from: context.now, calendar: calendar) else {
            return WellnessRecoveryScheduleDecision(
                shouldSchedule: false,
                fireDate: nil,
                dayKeyToMark: nil
            )
        }

        return WellnessRecoveryScheduleDecision(
            shouldSchedule: true,
            fireDate: fireDate,
            dayKeyToMark: todayKey
        )
    }

    static func hasRecoveryPlannedToday(
        activities: [PlannedActivity],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        activities.contains { activity in
            guard !activity.isSkipped else { return false }
            guard calendar.isDate(activity.date, inSameDayAs: now) else { return false }
            return activity.type.lowercased() == "recovery"
        }
    }

    static func hadCompletedWorkoutYesterday(
        activities: [PlannedActivity],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return false
        }

        return activities.contains { activity in
            guard activity.isCompleted, !activity.isSkipped else { return false }
            guard calendar.isDate(activity.date, inSameDayAs: yesterday) else { return false }
            return activity.type.lowercased() == "workout"
        }
    }

    static func nextRecoverySuggestionDate(
        from now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let dayStart = calendar.startOfDay(for: now)
        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = recoverySuggestionHour
        components.minute = recoverySuggestionMinute
        components.second = 0

        guard var scheduled = calendar.date(from: components) else { return nil }

        if scheduled <= now {
            guard let fallback = calendar.date(byAdding: .minute, value: 15, to: now) else {
                return nil
            }

            let hour = calendar.component(.hour, from: fallback)
            guard hour < 20 else { return nil }
            scheduled = fallback
        }

        return scheduled
    }
}
