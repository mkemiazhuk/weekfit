import Foundation

/// Presentation-only meal-window guard — no scenario routing.
enum CoachCopyMealWindowPolicy {

    /// False when the user is likely still in a normal pre-first-meal / fasting window.
    /// After serious training today, fuel lag is a real catch-up need — not fasting softness.
    static func isOpen(context: CoachContext, fuelState: CoachFuelState) -> Bool {
        guard fuelState.isBehind else { return true }
        if context.completedSeriousActivities != .none {
            return true
        }
        switch context.timeOfDay {
        case .morning, .midday:
            return false
        default:
            return true
        }
    }
}
