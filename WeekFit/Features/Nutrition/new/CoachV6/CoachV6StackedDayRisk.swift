import Foundation

/// Active serious training stacked on an already heavy day with tomorrow demand.
enum CoachV6StackedDayRisk {

    static func isActive(context: CoachV6Context, scenario: CoachV6ScenarioKey) -> Bool {
        guard isLiveTrainingScenario(scenario) else { return false }
        guard context.sessionPhase == .during || context.sessionPhase == .pre else { return false }
        guard isHeavyDay(context.dayLoadBand) else { return false }
        guard context.tomorrowDemand == .moderate || context.tomorrowDemand == .hard else { return false }
        guard context.completedSeriousActivities != .none || context.dayLoadBand == .extreme else {
            return false
        }
        return true
    }

    private static func isLiveTrainingScenario(_ scenario: CoachV6ScenarioKey) -> Bool {
        switch scenario {
        case .activeEndurance, .duringEndurance,
             .activeStrength, .duringStrength,
             .activeRacket, .duringRacket:
            return true
        default:
            return false
        }
    }

    private static func isHeavyDay(_ band: CoachV6DayLoadBand) -> Bool {
        band == .heavy || band == .extreme
    }
}
