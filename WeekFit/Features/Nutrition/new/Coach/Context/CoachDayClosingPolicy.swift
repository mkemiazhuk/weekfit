import Foundation

/// Evening wind-down frame — no deficit catch-up when the day is effectively done.
enum CoachDayClosingPolicy {

    static func shouldSuppressNutrition(context: CoachContext) -> Bool {
        context.conversationPhase == .dayClosing
    }
}
