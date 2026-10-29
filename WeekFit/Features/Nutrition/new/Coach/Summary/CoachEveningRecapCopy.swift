import Foundation

/// Stable evening headlines and local feeling reactions (no AI, deterministic).
enum CoachEveningRecapCopy {

    static func headline(
        tone: CoachEveningRecapDayTone,
        givenName: String?
    ) -> String {
        let name = cleanedName(givenName)
        switch tone {
        case .active:
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.headline.active.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.headline.active")
        case .quiet:
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.headline.quiet.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.headline.quiet")
        }
    }

    /// Short local reaction after evening feeling — replaces the AI note while keeping feeling chips.
    static func feelingReaction(
        feeling: CoachFeelingKind,
        tone: CoachEveningRecapDayTone,
        givenName: String? = ProfileService.resolvedGivenName()
    ) -> String {
        let name = cleanedName(givenName)
        switch (feeling, tone) {
        case (.tired, .active), (.low, .active):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.tired.active.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.tired.active")
        case (.tired, .quiet), (.low, .quiet):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.tired.quiet.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.tired.quiet")
        case (.okay, .active):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.good.active.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.good.active")
        case (.okay, .quiet):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.good.quiet.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.good.quiet")
        case (.energized, .active):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.energized.active.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.energized.active")
        case (.energized, .quiet):
            if let name {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.energized.quiet.named"),
                    name
                )
            }
            return WeekFitLocalizedString("coach.eveningRecap.feeling.reaction.energized.quiet")
        }
    }

    /// Evening note is the recommendation itself. Distance vs usual stays in the hero, not as the opening line.
    static func noteText(
        commentary: String?,
        feelingReaction: String?,
        isLoading: Bool,
        failed: Bool,
        locale: String = WeekFitCurrentAppLanguage().rawValue
    ) -> String? {
        if let feelingReaction, !feelingReaction.isEmpty {
            return feelingReaction
        }
        let safeCommentary = commentary.flatMap { raw -> String? in
            let filtered = CoachEveningSummaryPolicy.filteringToRequestedLocale(raw, locale: locale)
            return filtered.isEmpty ? nil : filtered
        }
        if let safeCommentary {
            return safeCommentary
        }
        if isLoading { return nil }
        let fallback = CoachEveningSummaryPolicy.filteringToRequestedLocale(
            WeekFitLocalizedString("coach.eveningRecap.forEvening.fallback"),
            locale: locale
        )
        return fallback.isEmpty ? nil : fallback
    }

    private static func cleanedName(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
