import Foundation

/// Guards day-closure phrasing in coach copy — presentation only, no routing.
enum CoachCopyClosureTiming {

    /// «Остаток дня» / rest-of-day tone — from 18:00. Does **not** allow day-closure phrases
    /// («на сегодня достаточно», «завершить день») — use `allowsDayClosurePhrasing` for those.
    static func allowsRestOfDayPhrasing(_ timeOfDay: CoachTimeOfDay) -> Bool {
        switch timeOfDay {
        case .evening, .lateEvening, .night:
            return true
        case .morning, .midday, .afternoon:
            return false
        }
    }

    /// «На сегодня достаточно» / wind-down closure — from 21:00 or day-closing frame.
    static func allowsDayClosurePhrasing(
        timeOfDay: CoachTimeOfDay,
        conversationPhase: CoachConversationPhase = .steady
    ) -> Bool {
        CoachCopyNutritionTiming.isWindDown(timeOfDay) || conversationPhase == .dayClosing
    }
}
