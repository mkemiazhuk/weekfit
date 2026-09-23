import Foundation
import WeekFitPlanner

struct CoachMorningBriefFacts: Equatable, Sendable {
    let recoveryDataAvailable: Bool
    let sleepHours: Double
    let recoveryPercent: Int
    let recoveryBand: CoachRecoveryBand
    let sleepIsLow: Bool
    let hadHeavyYesterday: Bool
    let nextActivity: CoachPlannedActivitySummary?
    let todayActivityCount: Int
    let seriousActivityCount: Int
    let tomorrowWorkout: CoachTomorrowWorkout?
    let minutesUntilNextActivity: Int?
    /// True when `nextActivity` is inside the Before-session prep window.
    let nextActivityIsImminent: Bool
}

enum CoachMorningBriefFactsBuilder {

    static func build(input: CoachInputSnapshot, context: CoachContext) -> CoachMorningBriefFacts {
        let calendar = Calendar.current
        let todayActivities = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.selectedDate) && !$0.isSkipped
        }

        let sessionActivities = todayActivities.filter(CoachCanonicalDayState.isCoachRelevantSnapshot)
        let nextResolution = resolveNextActivity(
            input: input,
            context: context,
            todayActivities: todayActivities,
            calendar: calendar
        )

        let seriousCount = todayActivities.filter(CoachActivityClassifier.isSeriousTraining).count
        let recoveryDataAvailable = context.dayReadiness.recoveryDataAvailable

        return CoachMorningBriefFacts(
            recoveryDataAvailable: recoveryDataAvailable,
            sleepHours: context.dayReadiness.sleepHours,
            recoveryPercent: context.dayReadiness.recoveryPercent,
            recoveryBand: context.dayReadiness.recoveryBand,
            sleepIsLow: context.dayReadiness.sleepIsLow,
            hadHeavyYesterday: context.dayReadiness.hadHeavyYesterday,
            nextActivity: nextResolution.summary,
            todayActivityCount: sessionActivities.count,
            seriousActivityCount: seriousCount,
            tomorrowWorkout: context.tomorrowWorkout,
            minutesUntilNextActivity: nextResolution.minutesUntilStart,
            nextActivityIsImminent: nextResolution.isImminent
        )
    }

    /// Test and baseline packs without a full input snapshot.
    static func synthetic(
        dayReadiness: CoachDayReadiness,
        nextActivity: CoachPlannedActivitySummary? = nil,
        tomorrowWorkout: CoachTomorrowWorkout? = nil,
        todayActivityCount: Int = 0,
        seriousActivityCount: Int = 0,
        minutesUntilNextActivity: Int? = nil,
        recoveryDataAvailable: Bool = true,
        nextActivityIsImminent: Bool? = nil
    ) -> CoachMorningBriefFacts {
        let imminent: Bool = {
            if let nextActivityIsImminent { return nextActivityIsImminent }
            guard nextActivity != nil, let minutes = minutesUntilNextActivity else { return false }
            return minutes <= CoachActivityWindowPolicy.beforeSessionCopyWindowMinutes
        }()
        return CoachMorningBriefFacts(
            recoveryDataAvailable: recoveryDataAvailable,
            sleepHours: dayReadiness.sleepHours,
            recoveryPercent: dayReadiness.recoveryPercent,
            recoveryBand: dayReadiness.recoveryBand,
            sleepIsLow: dayReadiness.sleepIsLow,
            hadHeavyYesterday: dayReadiness.hadHeavyYesterday,
            nextActivity: nextActivity,
            todayActivityCount: todayActivityCount,
            seriousActivityCount: seriousActivityCount,
            tomorrowWorkout: tomorrowWorkout,
            minutesUntilNextActivity: minutesUntilNextActivity,
            nextActivityIsImminent: imminent
        )
    }

    private struct NextActivityResolution {
        let summary: CoachPlannedActivitySummary?
        let minutesUntilStart: Int?
        let isImminent: Bool
    }

    private static func resolveNextActivity(
        input: CoachInputSnapshot,
        context: CoachContext,
        todayActivities: [CoachPlannedActivitySnapshot],
        calendar: Calendar
    ) -> NextActivityResolution {
        if let focusID = context.focusActivityID,
           let focus = todayActivities.first(where: { $0.id == focusID }),
           CoachCanonicalDayState.isSessionFocusCandidate(focus) {
            return resolution(for: focus, now: input.now, calendar: calendar)
        }

        let upcoming = todayActivities
            .filter { $0.date >= input.now }
            .filter(CoachCanonicalDayState.isSessionFocusCandidate)
            .sorted { $0.date < $1.date }

        guard let next = upcoming.first else {
            return NextActivityResolution(summary: nil, minutesUntilStart: nil, isImminent: false)
        }
        return resolution(for: next, now: input.now, calendar: calendar)
    }

    private static func resolution(
        for activity: CoachPlannedActivitySnapshot,
        now: Date,
        calendar: Calendar
    ) -> NextActivityResolution {
        let minutes = CoachActivityWindowPolicy.minutesUntilStart(activity: activity, now: now)
        return NextActivityResolution(
            summary: CoachPlannedActivitySummary.from(activity: activity, calendar: calendar),
            minutesUntilStart: minutes,
            isImminent: CoachActivityWindowPolicy.isWithinBeforeSessionWindow(
                activity: activity,
                minutesUntilStart: minutes
            )
        )
    }
}
