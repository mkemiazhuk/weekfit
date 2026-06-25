import Foundation

/// Suppresses nutrition catch-up urgency during conversational opening/closing frames.
enum CoachConversationNutritionPolicy {

    static func shouldSuppress(context: CoachContext) -> Bool {
        switch context.conversationPhase {
        case .morningOverview:
            return CoachMorningOverviewPolicy.shouldSuppressNutrition(context: context)
        case .dayClosing:
            return CoachDayClosingPolicy.shouldSuppressNutrition(context: context)
        case .steady:
            return false
        }
    }
}
