import Foundation

enum CoachV6AthleteStateResolver {

    /// Derives body state from recovery, sleep, and yesterday load. Never changes scenario.
    static func resolve(dayReadiness: CoachV6DayReadiness) -> CoachV6AthleteState {
        let bodyState = resolveBodyState(dayReadiness: dayReadiness)
        return CoachV6AthleteState(bodyState: bodyState)
    }

    static func resolve(context: CoachV6Context) -> CoachV6AthleteState {
        resolve(dayReadiness: context.dayReadiness)
    }

    private static func resolveBodyState(dayReadiness: CoachV6DayReadiness) -> CoachV6BodyState {
        if dayReadiness.recoveryBand == .low,
           dayReadiness.sleepIsLow || dayReadiness.recoveryPercent < 40 {
            return .veryFatigued
        }

        if dayReadiness.recoveryBand == .low ||
            dayReadiness.sleepIsLow ||
            (dayReadiness.hadHeavyYesterday && dayReadiness.recoveryBand == .moderate) {
            return .fatigued
        }

        if dayReadiness.recoveryBand == .good,
           !dayReadiness.sleepIsLow,
           !dayReadiness.hadHeavyYesterday {
            return .fresh
        }

        return .normal
    }
}
