import Foundation

/// Local stand-in for the evening coach summary. The cloud service stays in the app and is not called.
enum CoachEveningLocalSummary {
    static func make(_ input: CoachEveningSummaryInput) -> CoachEveningSummaryGenerationResult {
        let locale = Locale(identifier: input.locale)
        let sessions = input.facts["activity"]?.filter { $0.id.hasPrefix("activity.item.") } ?? []
        let completed = sessions.filter { $0.text.contains("status completed") }.count
        let today: String
        if sessions.isEmpty {
            today = WeekFitLocalizedString("coach.eveningRecap.local.rest", locale: locale)
        } else {
            today = String(
                format: WeekFitLocalizedString("coach.eveningRecap.local.progress", locale: locale),
                locale: locale,
                completed,
                sessions.count
            )
        }
        let summary = CoachEveningSummary(
            headline: WeekFitLocalizedString("coach.eveningRecap.local.headline", locale: locale),
            today: .init(text: today, evidenceIds: []),
            now: .init(text: WeekFitLocalizedString("coach.eveningRecap.local.now", locale: locale), evidenceIds: []),
            tomorrow: .init(text: WeekFitLocalizedString("coach.eveningRecap.local.tomorrow", locale: locale), evidenceIds: []),
            limitations: [],
            day: input.day,
            locale: input.locale,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: "fallback"
        )
        return CoachEveningSummaryGenerationResult(summary: summary, requestId: "local")
    }
}
