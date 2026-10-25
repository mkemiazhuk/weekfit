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

    /// Blend AI note with a client-computed comparison (max two short sentences).
    static func noteText(
        commentary: String?,
        comparison: String?,
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
            return mergeComparison(into: safeCommentary, comparison: comparison, locale: locale)
        }
        if isLoading { return nil }
        let fallback = WeekFitLocalizedString("coach.eveningRecap.forEvening.fallback")
        return mergeComparison(into: fallback, comparison: comparison, locale: locale)
    }

    private static func mergeComparison(
        into commentary: String,
        comparison: String?,
        locale: String
    ) -> String {
        let safeCommentary = CoachEveningSummaryPolicy.filteringToRequestedLocale(
            commentary,
            locale: locale
        )
        guard let comparison, !comparison.isEmpty else { return safeCommentary }
        let trimmed = safeCommentary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return comparison }
        // Avoid duplicating if the model already used the comparison.
        if trimmed.localizedCaseInsensitiveContains(comparison)
            || sharesSignificantToken(trimmed, comparison) {
            return trimmed
        }
        // Comparison first, then one short takeaway sentence from commentary.
        let takeaway = firstSentence(trimmed)
        let safeTakeaway = CoachEveningSummaryPolicy.filteringToRequestedLocale(
            takeaway,
            locale: locale
        )
        if safeTakeaway.isEmpty { return comparison }
        return "\(comparison) \(safeTakeaway)"
    }

    private static func firstSentence(_ text: String) -> String {
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return "" }
        if first.hasSuffix(".") || first.hasSuffix("!") || first.hasSuffix("?") {
            return first
        }
        return first + "."
    }

    private static func sharesSignificantToken(_ a: String, _ b: String) -> Bool {
        let tokens = b.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { $0.count >= 4 }
        return tokens.contains { a.localizedCaseInsensitiveContains($0) }
    }

    private static func cleanedName(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
