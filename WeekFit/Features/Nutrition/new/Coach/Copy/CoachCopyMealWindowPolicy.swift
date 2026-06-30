import Foundation

/// Presentation-only meal-window guard — no scenario routing.
enum CoachCopyMealWindowPolicy {

    /// False when the user is likely still in a normal pre-first-meal / fasting window.
    static func isOpen(context: CoachContext, fuelState: CoachFuelState) -> Bool {
        guard fuelState.isBehind else { return true }
        switch context.timeOfDay {
        case .morning, .midday:
            return false
        default:
            return true
        }
    }
}
