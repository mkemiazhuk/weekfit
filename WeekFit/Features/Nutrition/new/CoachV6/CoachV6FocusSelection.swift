import Foundation
import WeekFitPlanner

// MARK: - Focus selection

enum CoachV6FocusSource: String, Equatable, Sendable {
    case active
    case upcoming
    case recentCompleted
    case idle
}

/// Single coherent focus — activity, taxonomy, state, and phase from the same source.
struct CoachV6FocusSelection: Equatable, Sendable {
    let activity: PlannedActivity?
    let family: CoachV6ActivityFamily
    let type: CoachV6ActivityType
    let state: CoachV6ActivityState
    let phase: CoachV6SessionPhase
    let source: CoachV6FocusSource
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?

    static let idle = CoachV6FocusSelection(
        activity: nil,
        family: .none,
        type: .none,
        state: .none,
        phase: .idle,
        source: .idle,
        minutesUntilStart: nil,
        minutesSinceEnd: nil
    )
}

enum CoachV6FocusResolver {

    private static let recentCompletedWindowMinutes = 180
    private static let immediatePostWindowMinutes = 60

    static func resolve(
        input: CoachInputSnapshot,
        explicitFocus: PlannedActivity? = nil
    ) -> CoachV6FocusSelection {
        if let explicitFocus {
            return selection(
                for: explicitFocus,
                source: source(for: explicitFocus, now: input.now),
                now: input.now,
                timeOfDay: CoachV6TimeOfDay.from(hour: Calendar.current.component(.hour, from: input.now))
            )
        }

        let calendar = Calendar.current
        let dayActivities = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.selectedDate) && !$0.isSkipped
        }
        let timeOfDay = CoachV6TimeOfDay.from(hour: calendar.component(.hour, from: input.now))

        if let active = dayActivities.first(where: { $0.isActive(at: input.now) }) {
            return selection(for: active, source: .active, now: input.now, timeOfDay: timeOfDay)
        }

        let upcoming = dayActivities
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= input.now }
            .sorted { $0.date < $1.date }

        if let nextSerious = upcoming.first(where: CoachV6ActivityClassifier.isSeriousTraining) {
            return selection(for: nextSerious, source: .upcoming, now: input.now, timeOfDay: timeOfDay)
        }

        if let lastCompleted = input.dayContext.lastCompletedActivity {
            let minutesSinceEnd = minutesSinceActivityEnd(lastCompleted, now: input.now)
            if minutesSinceEnd <= recentCompletedWindowMinutes,
               CoachV6ActivityClassifier.isSeriousTraining(lastCompleted) {
                return selection(
                    for: lastCompleted,
                    source: .recentCompleted,
                    now: input.now,
                    timeOfDay: timeOfDay
                )
            }
        }

        if let next = upcoming.first {
            return selection(for: next, source: .upcoming, now: input.now, timeOfDay: timeOfDay)
        }

        if let lastCompleted = input.dayContext.lastCompletedActivity {
            let minutesSinceEnd = minutesSinceActivityEnd(lastCompleted, now: input.now)
            if minutesSinceEnd <= recentCompletedWindowMinutes {
                return selection(
                    for: lastCompleted,
                    source: .recentCompleted,
                    now: input.now,
                    timeOfDay: timeOfDay
                )
            }
        }

        return .idle
    }

    // MARK: - Private

    private static func source(for activity: PlannedActivity, now: Date) -> CoachV6FocusSource {
        if activity.isActive(at: now) {
            return .active
        }
        if activity.isCompleted || activity.isPartialCompletion {
            return .recentCompleted
        }
        return .upcoming
    }

    private static func selection(
        for activity: PlannedActivity,
        source: CoachV6FocusSource,
        now: Date,
        timeOfDay: CoachV6TimeOfDay
    ) -> CoachV6FocusSelection {
        let family = CoachV6ActivityClassifier.family(for: activity)
        let type = CoachV6ActivityClassifier.type(for: activity)
        let timing = resolveTiming(for: activity, now: now)
        let state = resolveActivityState(activity: activity, now: now, minutesSinceEnd: timing.minutesSinceEnd)
        let phase = resolveSessionPhase(
            activityState: state,
            timeOfDay: timeOfDay,
            family: family
        )

        return CoachV6FocusSelection(
            activity: activity,
            family: family,
            type: type,
            state: state,
            phase: phase,
            source: source,
            minutesUntilStart: timing.minutesUntilStart,
            minutesSinceEnd: timing.minutesSinceEnd
        )
    }

    private struct ResolvedTiming {
        let minutesUntilStart: Int?
        let minutesSinceEnd: Int?
    }

    private static func resolveTiming(for activity: PlannedActivity, now: Date) -> ResolvedTiming {
        if activity.isActive(at: now) {
            return ResolvedTiming(minutesUntilStart: nil, minutesSinceEnd: nil)
        }

        if activity.isCompleted || activity.isPartialCompletion {
            return ResolvedTiming(
                minutesUntilStart: nil,
                minutesSinceEnd: minutesSinceActivityEnd(activity, now: now)
            )
        }

        let minutesUntil = max(0, Int(activity.date.timeIntervalSince(now) / 60))
        return ResolvedTiming(minutesUntilStart: minutesUntil, minutesSinceEnd: nil)
    }

    private static func resolveActivityState(
        activity: PlannedActivity,
        now: Date,
        minutesSinceEnd: Int?
    ) -> CoachV6ActivityState {
        if activity.isActive(at: now) {
            return .active
        }
        if activity.isCompleted || activity.isPartialCompletion {
            let minutesSince = minutesSinceEnd ?? 0
            return minutesSince <= immediatePostWindowMinutes ? .justFinished : .finished
        }
        return .upcoming
    }

    private static func resolveSessionPhase(
        activityState: CoachV6ActivityState,
        timeOfDay: CoachV6TimeOfDay,
        family: CoachV6ActivityFamily
    ) -> CoachV6SessionPhase {
        switch activityState {
        case .upcoming:
            return .pre
        case .active:
            return .during
        case .justFinished:
            return .immediatePost
        case .finished:
            if isEveningPhase(timeOfDay), family != .none {
                return .evening
            }
            return .settledPost
        case .none:
            return .idle
        }
    }

    private static func minutesSinceActivityEnd(_ activity: PlannedActivity, now: Date) -> Int {
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return max(0, Int(now.timeIntervalSince(end) / 60))
    }

    private static func isEveningPhase(_ timeOfDay: CoachV6TimeOfDay) -> Bool {
        timeOfDay == .evening || timeOfDay == .lateEvening
    }
}
