import Foundation
import WeekFitPlanner

// MARK: - Focus selection (production scenario routing)
//
// Ownership: `CoachFocusResolver` is the sole owner of which activity Coach focuses on
// and the derived session phase/state. Output feeds `CoachEngine.buildContext` → `CoachContext`.
// See: Coach/Docs/CoachContextLayerAudit.md

// MARK: - Focus selection

enum CoachFocusSource: String, Equatable, Sendable {
    case active
    case upcoming
    case recentCompleted
    case idle
}

/// Single coherent focus — activity, taxonomy, state, and phase from the same source.
struct CoachFocusSelection: Equatable, Sendable {
    let activity: CoachPlannedActivitySnapshot?
    let family: CoachActivityFamily
    let type: CoachActivityType
    let state: CoachActivityState
    let phase: CoachSessionPhase
    let source: CoachFocusSource
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?

    static let idle = CoachFocusSelection(
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

enum CoachFocusResolver {

    static func resolve(
        input: CoachInputSnapshot,
        explicitFocus: CoachPlannedActivitySnapshot? = nil
    ) -> CoachFocusSelection {
        if let explicitFocus {
            return selection(
                for: explicitFocus,
                source: source(for: explicitFocus, now: input.now),
                now: input.now,
                timeOfDay: CoachTimeOfDay.from(hour: Calendar.current.component(.hour, from: input.now))
            )
        }

        let calendar = Calendar.current
        let dayActivities = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.selectedDate) && !$0.isSkipped
        }
        let timeOfDay = CoachTimeOfDay.from(hour: calendar.component(.hour, from: input.now))

        if let active = dayActivities
            .filter({ CoachSessionPhaseStability.isCoachLiveSession($0, now: input.now) })
            .max(by: { $0.date < $1.date }) {
            return selection(for: active, source: .active, now: input.now, timeOfDay: timeOfDay)
        }

        let upcoming = dayActivities
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= input.now }
            .sorted { $0.date < $1.date }

        if let nextSerious = upcoming.first(where: CoachActivityClassifier.isSeriousTraining) {
            return selection(for: nextSerious, source: .upcoming, now: input.now, timeOfDay: timeOfDay)
        }

        if let lastCompleted = input.dayContext.lastCompletedActivity {
            let minutesSinceEnd = minutesSinceActivityEnd(lastCompleted, now: input.now)
            if shouldKeepRecentCompletedFocus(
                activity: lastCompleted,
                minutesSinceEnd: minutesSinceEnd,
                timeOfDay: timeOfDay
            ),
               CoachActivityClassifier.isSeriousTraining(lastCompleted) {
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
            if shouldKeepRecentCompletedFocus(
                activity: lastCompleted,
                minutesSinceEnd: minutesSinceEnd,
                timeOfDay: timeOfDay
            ) {
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

    private static func source(for activity: CoachPlannedActivitySnapshot, now: Date) -> CoachFocusSource {
        if CoachSessionPhaseStability.isCoachLiveSession(activity, now: now) {
            return .active
        }
        if activity.isCompleted || activity.isPartialCompletion {
            return .recentCompleted
        }
        return .upcoming
    }

    private static func selection(
        for activity: CoachPlannedActivitySnapshot,
        source: CoachFocusSource,
        now: Date,
        timeOfDay: CoachTimeOfDay
    ) -> CoachFocusSelection {
        let family = CoachActivityClassifier.family(for: activity)
        let type = CoachActivityClassifier.type(for: activity)
        let timing = resolveTiming(for: activity, now: now)
        let state = resolveActivityState(activity: activity, now: now, minutesSinceEnd: timing.minutesSinceEnd)
        let phase = resolveSessionPhase(
            activityState: state,
            timeOfDay: timeOfDay,
            family: family
        )

        return CoachFocusSelection(
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

    private static func resolveTiming(for activity: CoachPlannedActivitySnapshot, now: Date) -> ResolvedTiming {
        if CoachSessionPhaseStability.isCoachLiveSession(activity, now: now) {
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
        activity: CoachPlannedActivitySnapshot,
        now: Date,
        minutesSinceEnd: Int?
    ) -> CoachActivityState {
        if CoachSessionPhaseStability.isCoachLiveSession(activity, now: now) {
            return .active
        }
        if activity.isCompleted || activity.isPartialCompletion {
            let minutesSince = minutesSinceEnd ?? 0
            return CoachActivityWindowPolicy.isWithinImmediatePostFocusWindow(minutesSinceEnd: minutesSince)
                ? .justFinished : .finished
        }
        return .upcoming
    }

    private static func resolveSessionPhase(
        activityState: CoachActivityState,
        timeOfDay: CoachTimeOfDay,
        family: CoachActivityFamily
    ) -> CoachSessionPhase {
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

    private static func minutesSinceActivityEnd(_ activity: CoachPlannedActivitySnapshot, now: Date) -> Int {
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return max(0, Int(now.timeIntervalSince(end) / 60))
    }

    private static func isEveningPhase(_ timeOfDay: CoachTimeOfDay) -> Bool {
        timeOfDay == .evening || timeOfDay == .lateEvening
    }

    private static func shouldKeepRecentCompletedFocus(
        activity: CoachPlannedActivitySnapshot,
        minutesSinceEnd: Int,
        timeOfDay: CoachTimeOfDay
    ) -> Bool {
        let window = CoachActivityWindowPolicy.recentCompletedFocusWindowMinutes(for: activity)
        guard minutesSinceEnd <= window else { return false }

        if CoachCopyNutritionTiming.isWindDown(timeOfDay),
           CoachActivityClassifier.type(for: activity) == .walk {
            return minutesSinceEnd <= CoachActivityWindowPolicy.immediatePostFocusWindowMinutes
        }

        return true
    }
}
