import Foundation

/// Presentation-layer morning brief — turns a mutation inventory into a coach narrative.
struct MorningProposalBrief: Equatable, Sendable {
    let eyebrow: String
    /// Optional first name for soft address — never mashed into `headline` with an em dash.
    let addressName: String?
    /// Strategy / cold-start line only (no name prefix).
    let headline: String
    /// Up to three concrete actions in plain language.
    let actionLines: [String]
    /// Quieter secondary line (tips / weather), never inventory counts as the hero.
    let metaLine: String?
    let ctaTitle: String
    let recommendedCount: Int
    let tipCount: Int
    /// Chronologic day beats for premium Today / review surfaces.
    let dayMoments: [MorningProposalDayMoment]
    /// Soft body-state framing (strategy), optional.
    let contextLine: String?
}

enum MorningProposalBriefComposer {

    static func compose(
        proposal: MorningPlanProposal,
        givenName: String? = nil,
        weatherLine: String? = nil
    ) -> MorningProposalBrief {
        let mutations = proposal.changes
            .filter { $0.kind != .guidanceOnly }
            .sorted { lhs, rhs in
                if lhs.isSelected != rhs.isSelected { return lhs.isSelected && !rhs.isSelected }
                if (lhs.scoreTotal ?? 0) != (rhs.scoreTotal ?? 0) {
                    return (lhs.scoreTotal ?? 0) > (rhs.scoreTotal ?? 0)
                }
                return lhs.sortTime < rhs.sortTime
            }
        let tips = proposal.changes.filter { $0.kind == .guidanceOnly }
        let selected = mutations.filter(\.isSelected)

        let actionSource = selected.isEmpty ? Array(mutations.prefix(3)) : Array(selected.prefix(3))
        let actionLines: [String]
        if actionSource.isEmpty, isColdStart(proposal) {
            // Guidance-only first morning: surface the curated tip(s) as the brief actions.
            actionLines = tips.prefix(2).map(actionLine(for:))
        } else {
            actionLines = actionSource.map(actionLine(for:))
        }

        // Weather only in meta — tip counts read as inventory, not coaching.
        let metaParts: [String] = [
            weatherLine.flatMap { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : line
            },
        ].compactMap { $0 }

        return MorningProposalBrief(
            eyebrow: WeekFitLocalizedString("coach.proposal.brief.eyebrow"),
            addressName: resolvedAddressName(givenName),
            headline: headline(
                for: proposal.strategy,
                isColdStart: isColdStart(proposal)
            ),
            actionLines: actionLines,
            metaLine: metaParts.isEmpty ? nil : metaParts.joined(separator: " · "),
            ctaTitle: WeekFitLocalizedString("coach.proposal.chrome.reviewCTA.short"),
            recommendedCount: mutations.count,
            tipCount: tips.count,
            dayMoments: dayMoments(for: proposal),
            contextLine: isColdStart(proposal) ? nil : contextLine(for: proposal)
        )
    }

    static func isColdStart(_ proposal: MorningPlanProposal) -> Bool {
        proposal.fingerprint.observationContextRevision == "none"
    }

    /// First token of a display name suitable for soft address (“Max”).
    static func resolvedAddressName(_ givenName: String?) -> String? {
        let name = givenName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init)
        guard let name, !name.isEmpty else { return nil }
        return name
    }

    static func headline(
        for strategy: DailyStrategy?,
        isColdStart: Bool = false
    ) -> String {
        if isColdStart {
            return WeekFitLocalizedString("coach.proposal.brief.coldStart.headline")
        }
        return MorningProposalStrategyCopy.localizedSummary(for: strategy)
            ?? WeekFitLocalizedString("coach.proposal.chrome.readyTitle")
    }

    static func actionLine(for change: CoachProposedChange) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        switch change.payload {
        case .modifyDuration(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.shorten"),
                activityLabel(payload.activityTitle),
                payload.originalDurationMinutes,
                payload.proposedDurationMinutes
            )
        case .moveActivity(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.move"),
                activityLabel(payload.activityTitle),
                formatter.string(from: payload.originalDate),
                formatter.string(from: payload.proposedDate)
            )
        case .skipActivity(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.skip"),
                activityLabel(payload.activityTitle)
            )
        case .createRecoveryWalk(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.walk"),
                payload.durationMinutes,
                formatter.string(from: payload.proposedDate)
            )
        case .createPlannedActivity(let payload):
            if isHabitBacked(change) {
                return String(
                    format: WeekFitLocalizedString("coach.proposal.brief.action.habitActivity"),
                    payload.title,
                    weekdayLabel(for: payload.proposedDate),
                    formatter.string(from: payload.proposedDate)
                )
            }
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.activity"),
                payload.title,
                formatter.string(from: payload.proposedDate)
            )
        case .createMealFromLibrary(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.brief.action.meal"),
                payload.title,
                formatter.string(from: payload.proposedDate)
            )
        case .guidanceOnly(let payload):
            return CoachProposalReasonCopy.localizedGuidance(payload.guidanceCode)
        }
    }

    static func isHabitBacked(_ change: CoachProposedChange) -> Bool {
        if change.candidateSource == .historicalActivity { return true }
        return change.reasonCode == .similarDaySupport
    }

    private static func weekdayLabel(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private static func activityLabel(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return WeekFitLocalizedString("coach.proposal.brief.action.sessionFallback")
        }
        return trimmed
    }

    /// Adverse / actionable weather line for the brief meta row (nil when calm).
    static func weatherMetaLine(from summary: WeekFitWeatherSummary?) -> String? {
        switch ProposalWeatherRisk.resolve(from: summary) {
        case .precip, .storm:
            return WeekFitLocalizedString("coach.proposal.brief.weather.precip")
        case .heat:
            return WeekFitLocalizedString("coach.proposal.brief.weather.heat")
        case .wind:
            return WeekFitLocalizedString("coach.proposal.brief.weather.wind")
        case .cold:
            return WeekFitLocalizedString("coach.proposal.brief.weather.cold")
        case .calm, .unavailable:
            return nil
        }
    }

    // MARK: - Day picture

    /// Chronologic day moments for Today card + review timeline (mutations only).
    static func dayMoments(
        for proposal: MorningPlanProposal,
        limit: Int = 5
    ) -> [MorningProposalDayMoment] {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let mutations = proposal.changes
            .filter { $0.kind != .guidanceOnly }
            .sorted { lhs, rhs in
                if lhs.sortTime != rhs.sortTime { return lhs.sortTime < rhs.sortTime }
                if lhs.isSelected != rhs.isSelected { return lhs.isSelected && !rhs.isSelected }
                return (lhs.scoreTotal ?? 0) > (rhs.scoreTotal ?? 0)
            }

        let selected = mutations.filter(\.isSelected)
        let source = Array((selected.isEmpty ? mutations : selected).prefix(limit))

        return source.map { change in
            MorningProposalDayMoment(
                id: change.id,
                timeLabel: formatter.string(from: change.sortTime),
                title: momentTitle(for: change),
                systemImage: momentSymbol(for: change),
                isRecommended: change.defaultSelected || change.isSelected
            )
        }
    }

    /// Soft body-state framing under the headline — not technical inventory.
    static func contextLine(for proposal: MorningPlanProposal) -> String? {
        MorningProposalStrategyCopy.localizedSummary(for: proposal.strategy)
    }

    private static func momentTitle(for change: CoachProposedChange) -> String {
        switch change.payload {
        case .modifyDuration(let payload):
            return activityLabel(payload.activityTitle)
        case .moveActivity(let payload):
            return activityLabel(payload.activityTitle)
        case .skipActivity(let payload):
            return activityLabel(payload.activityTitle)
        case .createRecoveryWalk:
            return WeekFitLocalizedString("coach.proposal.moment.walk")
        case .createPlannedActivity(let payload):
            return payload.title
        case .createMealFromLibrary(let payload):
            return payload.title
        case .guidanceOnly(let payload):
            return CoachProposalReasonCopy.localizedGuidance(payload.guidanceCode)
        }
    }

    private static func momentSymbol(for change: CoachProposedChange) -> String {
        switch change.kind {
        case .modifyDuration: return "timer"
        case .moveActivity: return "arrow.right.circle"
        case .skipActivity: return "minus.circle"
        case .createRecoveryWalk: return "figure.walk"
        case .createPlannedActivity: return "figure.run"
        case .createMealFromLibrary: return "fork.knife"
        case .guidanceOnly: return "lightbulb.fill"
        }
    }
}
