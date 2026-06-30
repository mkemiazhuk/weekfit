import Foundation

enum CoachAthleteStateResolver {

    /// Derives body state from recovery, sleep, and yesterday load. Never changes scenario.
    static func resolve(dayReadiness: CoachDayReadiness) -> CoachAthleteState {
        let bodyState = resolveBodyState(dayReadiness: dayReadiness)
        return CoachAthleteState(bodyState: bodyState)
    }

    static func resolve(context: CoachContext) -> CoachAthleteState {
        resolve(dayReadiness: context.dayReadiness)
    }

    private static func resolveBodyState(dayReadiness: CoachDayReadiness) -> CoachBodyState {
        guard dayReadiness.recoveryDataAvailable else {
            if dayReadiness.hadHeavyYesterday {
                return .fatigued
            }
            return .normal
        }

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
