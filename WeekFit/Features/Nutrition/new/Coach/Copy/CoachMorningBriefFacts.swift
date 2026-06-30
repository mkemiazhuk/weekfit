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
}

enum CoachMorningBriefFactsBuilder {

    static func build(input: CoachInputSnapshot, context: CoachContext) -> CoachMorningBriefFacts {
        let calendar = Calendar.current
        let todayActivities = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.selectedDate) && !$0.isSkipped
        }

        let nextActivity = resolveNextActivity(
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
            nextActivity: nextActivity,
            todayActivityCount: todayActivities.count,
            seriousActivityCount: seriousCount,
            tomorrowWorkout: context.tomorrowWorkout,
            minutesUntilNextActivity: context.minutesUntilStart
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
        recoveryDataAvailable: Bool = true
    ) -> CoachMorningBriefFacts {
        CoachMorningBriefFacts(
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
            minutesUntilNextActivity: minutesUntilNextActivity
        )
    }

    private static func resolveNextActivity(
        input: CoachInputSnapshot,
        context: CoachContext,
        todayActivities: [PlannedActivity],
        calendar: Calendar
    ) -> CoachPlannedActivitySummary? {
        if let focusID = context.focusActivityID,
           let focus = todayActivities.first(where: { $0.id == focusID }),
           !focus.isCompleted {
            return CoachPlannedActivitySummary.from(activity: focus, calendar: calendar)
        }

        let upcoming = todayActivities
            .filter { !$0.isCompleted && $0.date >= input.now }
            .sorted { $0.date < $1.date }

        guard let next = upcoming.first else { return nil }
        return CoachPlannedActivitySummary.from(activity: next, calendar: calendar)
    }
}
