import Foundation

/// When Coach should enter `tomorrowProtection` session phase.
enum CoachTomorrowProtectionPolicy {

    static func shouldProtect(
        timeOfDay: CoachTimeOfDay,
        tomorrowDemand: CoachTomorrowDemand,
        dayLoadBand: CoachDayLoadBand
    ) -> Bool {
        guard tomorrowDemand == .moderate || tomorrowDemand == .hard else { return false }

        switch dayLoadBand {
        case .heavy, .extreme:
            return isAfternoonOrLater(timeOfDay)
        case .moderate:
            // Moderate active days only protect tomorrow once the day is winding down.
            return timeOfDay == .evening || timeOfDay == .lateEvening
        case .fresh:
            return false
        }
    }

    private static func isAfternoonOrLater(_ timeOfDay: CoachTimeOfDay) -> Bool {
        switch timeOfDay {
        case .afternoon, .evening, .lateEvening:
            return true
        case .morning, .midday, .night:
            return false
        }
    }
}
