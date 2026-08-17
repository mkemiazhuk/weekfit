import Foundation
import SwiftUI

public enum WeekFitWidgetCopy {
    /// Character budgets for Medium layout — strings must fit without UI truncation.
    public enum MediumBudget {
        public static let headline = WeekFitWidgetTextFitting.Slot.mediumHeadline.limit
        public static let detail = WeekFitWidgetTextFitting.Slot.mediumDetail.limit
        public static let nextTitle = WeekFitWidgetTextFitting.Slot.mediumNextTitle.limit
        public static let nextMeta = WeekFitWidgetTextFitting.Slot.mediumNextMeta.limit
    }

    /// Character budgets for Small layout.
    public enum SmallBudget {
        public static let state = WeekFitWidgetTextFitting.Slot.smallState.limit
        public static let hero = WeekFitWidgetTextFitting.Slot.smallHero.limit
        public static let support = 22
        public static let nextTitle = WeekFitWidgetTextFitting.Slot.smallNextTitle.limit
        public static let nextHeader = WeekFitWidgetTextFitting.Slot.smallNextHeader.limit
    }

    public static func recoveryDisplay(score: Int?) -> String {
        guard let score else { return "—" }
        return "\(score)"
    }

    public static func recoveryCaption(label: String?, hasSignal: Bool) -> String {
        if let label, !label.isEmpty { return label }
        return hasSignal ? "Ready" : "Recovery"
    }

    public static func nextActionIcon(for kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return "figure.walk"
        case .strength: return "dumbbell.fill"
        case .recovery: return "heart.fill"
        case .sauna: return "flame.fill"
        case .meal: return "fork.knife"
        case .hydration: return "drop.fill"
        case .rest: return "moon.fill"
        case .none: return "sparkles"
        }
    }

    public static func dayModeTitle(_ mode: WeekFitWidgetSnapshot.DayMode) -> String {
        switch mode {
        case .goodToGo: return "Good to go"
        case .takeItEasy: return "Take it easy"
        case .recoveryFocus: return "Recovery focus"
        case .maintain: return "Steady day"
        case .empty: return "WeekFit"
        }
    }

    public static func shortKindLabel(_ kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return "Walk"
        case .strength: return "Strength"
        case .recovery: return "Recovery"
        case .sauna: return "Sauna"
        case .meal: return "Meal"
        case .hydration: return "Hydrate"
        case .rest: return "Rest"
        case .none: return "Open"
        }
    }

    /// Widget-native next label when app copy is too long for the card.
    public static func widgetNextLabel(for kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return "Easy walk"
        case .strength: return "Strength"
        case .recovery: return "Quiet pause"
        case .sauna: return "Sauna"
        case .meal: return "Fuel up"
        case .hydration: return "Hydrate"
        case .rest: return "Rest"
        case .none: return "Open app"
        }
    }

    public static func mediumDetailFallback(for mode: WeekFitWidgetSnapshot.DayMode) -> String {
        switch mode {
        case .goodToGo: return "Train as planned."
        case .maintain: return "Keep the day steady."
        case .takeItEasy: return "Ease intensity today."
        case .recoveryFocus: return "Protect sleep and load."
        case .empty: return "Prepare your day."
        }
    }

    public static func smallHeroFallback(for mode: WeekFitWidgetSnapshot.DayMode, hasNext: Bool) -> String {
        switch mode {
        case .goodToGo, .maintain:
            return hasNext ? "You're on track" : "Nothing urgent now"
        case .takeItEasy:
            return "Keep today light"
        case .recoveryFocus:
            return "Protect recovery"
        case .empty:
            return hasNext ? "Open WeekFit" : "Nothing urgent now"
        }
    }

    /// Text-agnostic fit into a character budget. Prefer `fit(_:to:fallback:)` / slots.
    public static func compactPhrase(_ raw: String, limit: Int, fallback: String) -> String {
        WeekFitWidgetTextFitting.fit(raw, limit: limit, fallback: fallback)
    }

    public static func mediumHeadline(
        raw: String,
        mode: WeekFitWidgetSnapshot.DayMode
    ) -> String {
        if mode == .empty { return "Open WeekFit" }
        return WeekFitWidgetTextFitting.fit(
            raw,
            to: .mediumHeadline,
            fallback: dayModeTitle(mode)
        )
    }

    public static func mediumDetail(
        raw: String,
        mode: WeekFitWidgetSnapshot.DayMode
    ) -> String {
        if mode == .empty { return "Prepare your day." }
        return WeekFitWidgetTextFitting.fit(
            raw,
            to: .mediumDetail,
            fallback: mediumDetailFallback(for: mode)
        )
    }

    public static func mediumNextTitle(
        raw: String,
        kind: WeekFitWidgetSnapshot.NextActionKind
    ) -> String {
        nextTitle(raw: raw, kind: kind, slot: .mediumNextTitle)
    }

    public static func smallStateLabel(from snapshot: WeekFitWidgetSnapshot) -> String {
        let modeFallback = dayModeTitle(snapshot.dayMode)
        let explicit = snapshot.dayStateLabel
        if !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return WeekFitWidgetTextFitting.fit(explicit, to: .smallState, fallback: modeFallback)
        }
        if !snapshot.hasNextAction, snapshot.dayMode == .goodToGo || snapshot.dayMode == .maintain || snapshot.dayMode == .empty {
            return WeekFitWidgetTextFitting.fit("All clear", to: .smallState, fallback: modeFallback)
        }
        return WeekFitWidgetTextFitting.fit(modeFallback, to: .smallState, fallback: "WeekFit")
    }

    public static func smallHero(from snapshot: WeekFitWidgetSnapshot) -> String {
        let fallback = smallHeroFallback(for: snapshot.dayMode, hasNext: snapshot.hasNextAction)
        let raw = snapshot.dayGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return WeekFitWidgetTextFitting.fit(fallback, to: .smallHero, fallback: fallback)
        }

        if isEventEcho(raw, nextTitle: snapshot.nextActionTitle) {
            return WeekFitWidgetTextFitting.fit(fallback, to: .smallHero, fallback: fallback)
        }

        return WeekFitWidgetTextFitting.fit(raw, to: .smallHero, fallback: fallback)
    }

    public static func smallSupport(from snapshot: WeekFitWidgetSnapshot) -> String {
        let raw = snapshot.dayGuidanceDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if isEventEcho(raw, nextTitle: snapshot.nextActionTitle) { return "" }
        return WeekFitWidgetTextFitting.fit(raw, limit: SmallBudget.support, fallback: "")
    }

    public static func smallHeadline(
        raw: String,
        mode: WeekFitWidgetSnapshot.DayMode
    ) -> String {
        if mode == .empty { return "Open WeekFit" }
        return WeekFitWidgetTextFitting.fit(raw, to: .smallHero, fallback: dayModeTitle(mode))
    }

    public static func smallNextTitle(
        raw: String,
        kind: WeekFitWidgetSnapshot.NextActionKind
    ) -> String {
        nextTitle(raw: raw, kind: kind, slot: .smallNextTitle)
    }

    public static func smallNextHeader(
        time: String?,
        phase: WeekFitWidgetSnapshot.NextActionPhase = .upcoming
    ) -> String {
        let label = nextPhaseLabel(phase)
        if let time {
            let stamp = time.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stamp.isEmpty {
                let header = "\(label) · \(stamp)"
                return WeekFitWidgetTextFitting.fit(header, to: .smallNextHeader, fallback: label)
            }
        }
        return label
    }

    public static func mediumNextSectionTitle(
        phase: WeekFitWidgetSnapshot.NextActionPhase
    ) -> String {
        switch phase {
        case .inProgress: return "Now"
        case .due: return "Due"
        case .upcoming, .none: return "Up next"
        }
    }

    public static func nextPhaseLabel(_ phase: WeekFitWidgetSnapshot.NextActionPhase) -> String {
        switch phase {
        case .inProgress: return "Now"
        case .due: return "Due"
        case .upcoming, .none: return "Next"
        }
    }

    public static func mediumNextMeta(subtitle: String?, time: String?) -> String {
        let parts = [subtitle, time]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

        guard !parts.isEmpty else { return "" }
        let joined = parts.joined(separator: " · ")
        if let time, !time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return WeekFitWidgetTextFitting.fit(
                joined,
                to: .mediumNextMeta,
                fallback: time.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return WeekFitWidgetTextFitting.fit(joined, to: .mediumNextMeta, fallback: "")
    }

    /// True when copy merely restates the upcoming event instead of interpreting it.
    public static func isEventEcho(_ text: String, nextTitle: String) -> Bool {
        let hay = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let next = nextTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !hay.isEmpty, !next.isEmpty else { return false }
        if hay == next { return true }
        if hay == "before \(next)" { return true }
        if hay.hasPrefix("before \(next)") { return true }
        if hay.hasPrefix("after \(next)") { return true }
        return false
    }

    private static func nextTitle(
        raw: String,
        kind: WeekFitWidgetSnapshot.NextActionKind,
        slot: WeekFitWidgetTextFitting.Slot
    ) -> String {
        let kindFallback = WeekFitWidgetTextFitting.fit(
            widgetNextLabel(for: kind),
            to: slot,
            fallback: shortKindLabel(kind)
        )
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return kindFallback }

        // Sentence-like coach copy → semantic label, not a chopped sentence.
        if trimmed.split(whereSeparator: \.isWhitespace).count > 3 {
            return kindFallback
        }

        return WeekFitWidgetTextFitting.fit(trimmed, to: slot, fallback: kindFallback)
    }

    public static func compactNextTitle(
        _ raw: String,
        fallback: String,
        limit: Int = MediumBudget.nextTitle
    ) -> String {
        WeekFitWidgetTextFitting.fit(raw, limit: limit, fallback: fallback)
    }

    public static func percentLabel(_ progress: Double, enabled: Bool) -> String {
        guard enabled else { return "—" }
        return "\(Int((WeekFitWidgetSnapshot.clamp01(progress) * 100).rounded()))%"
    }

    public static func containsEllipsis(_ text: String) -> Bool {
        WeekFitWidgetTextFitting.containsEllipsis(text)
    }
}
