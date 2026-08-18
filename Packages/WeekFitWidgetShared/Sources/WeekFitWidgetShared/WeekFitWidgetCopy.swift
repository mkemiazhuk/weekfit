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

    /// Snapshot language (`ru` vs `en`). Widget chrome follows this, not the system locale.
    public static var usesRussian = false

    public static func applyLanguage(_ code: String) {
        usesRussian = code.lowercased().hasPrefix("ru")
    }

    private static func t(_ en: String, _ ru: String) -> String {
        usesRussian ? ru : en
    }

    public static func metricMoveTitle() -> String { t("Move", "Акт.") }
    public static func metricFuelTitle() -> String { t("Fuel", "Еда") }
    public static func metricReadyTitle() -> String { t("Ready", "Форма") }

    public static func recoveryDisplay(score: Int?) -> String {
        guard let score else { return "—" }
        return "\(score)"
    }

    public static func recoveryScoreLabel(for score: Int) -> String {
        switch score {
        case 70...: return t("Ready", "Готов")
        case 55..<70: return t("Steady", "Ровно")
        case 40..<55: return t("Protect", "Беречь")
        default: return t("Recover", "Восст.")
        }
    }

    public static func recoveryCaption(label: String?, hasSignal: Bool) -> String {
        if let label, !label.isEmpty { return label }
        return hasSignal ? t("Ready", "Готов") : t("Recovery", "Восст.")
    }

    public static func nextActionIcon(for kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .racket: return "figure.tennis"
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
        case .goodToGo: return t("Good to go", "Можно тренироваться")
        case .takeItEasy: return t("Take it easy", "Сегодня легче")
        case .recoveryFocus: return t("Recovery focus", "Фокус на восстановлении")
        case .maintain: return t("Steady day", "Спокойный день")
        case .empty: return "WeekFit"
        }
    }

    public static func shortKindLabel(_ kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return t("Walk", "Прогулка")
        case .cycling: return t("Ride", "Вело")
        case .running: return t("Run", "Бег")
        case .swimming: return t("Swim", "Плавание")
        case .yoga: return t("Yoga", "Йога")
        case .racket: return t("Match", "Матч")
        case .strength: return t("Strength", "Сила")
        case .recovery: return t("Recovery", "Восстановление")
        case .sauna: return t("Sauna", "Сауна")
        case .meal: return t("Meal", "Еда")
        case .hydration: return t("Hydrate", "Вода")
        case .rest: return t("Rest", "Отдых")
        case .none: return t("Open", "Открыть")
        }
    }

    /// Widget-native next label when app copy is too long for the card.
    public static func widgetNextLabel(for kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return t("Easy walk", "Лёгкая прогулка")
        case .cycling: return t("Easy ride", "Лёгкая поездка")
        case .running: return t("Easy run", "Лёгкий бег")
        case .swimming: return t("Swim", "Плавание")
        case .yoga: return t("Yoga", "Йога")
        case .racket: return t("Match", "Матч")
        case .strength: return t("Strength", "Сила")
        case .recovery: return t("Quiet pause", "Тихая пауза")
        case .sauna: return t("Sauna", "Сауна")
        case .meal: return t("Fuel up", "Подкрепиться")
        case .hydration: return t("Hydrate", "Вода")
        case .rest: return t("Rest", "Отдых")
        case .none: return t("Open app", "Открыть приложение")
        }
    }

    public static func mediumDetailFallback(for mode: WeekFitWidgetSnapshot.DayMode) -> String {
        switch mode {
        case .goodToGo: return t("Train as planned.", "Тренируйтесь по плану.")
        case .maintain: return t("Keep the day steady.", "Держите день ровным.")
        case .takeItEasy: return t("Ease intensity today.", "Сегодня без лишней интенсивности.")
        case .recoveryFocus: return t("Protect sleep and load.", "Берегите сон и нагрузку.")
        case .empty: return t("Prepare your day.", "Соберите день.")
        }
    }

    public static func smallHeroFallback(for mode: WeekFitWidgetSnapshot.DayMode, hasNext: Bool) -> String {
        switch mode {
        case .goodToGo, .maintain:
            return hasNext
                ? t("You're on track", "Вы в ритме")
                : t("Nothing urgent now", "Сейчас ничего срочного")
        case .takeItEasy:
            return t("Keep today light", "Сегодня легче")
        case .recoveryFocus:
            return t("Protect recovery", "Берегите восстановление")
        case .empty:
            return hasNext
                ? t("Open WeekFit", "Откройте WeekFit")
                : t("Nothing urgent now", "Сейчас ничего срочного")
        }
    }

    public static func allClearLabel() -> String { t("All clear", "Всё спокойно") }
    public static func openWeekFitLabel() -> String { t("Open WeekFit", "Откройте WeekFit") }
    public static func prepareDayLabel() -> String { t("Prepare your day.", "Соберите день.") }

    public static func duringLabel(eventTitle: String) -> String {
        t("During \(eventTitle)", "Сейчас: \(eventTitle)")
    }

    public static func beforeLabel(eventTitle: String) -> String {
        t("Before \(eventTitle)", "Перед: \(eventTitle)")
    }

    /// Text-agnostic fit into a character budget. Prefer `fit(_:to:fallback:)` / slots.
    public static func compactPhrase(_ raw: String, limit: Int, fallback: String) -> String {
        WeekFitWidgetTextFitting.fit(raw, limit: limit, fallback: fallback)
    }

    public static func mediumHeadline(
        raw: String,
        mode: WeekFitWidgetSnapshot.DayMode
    ) -> String {
        if mode == .empty { return openWeekFitLabel() }
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
        if mode == .empty { return prepareDayLabel() }
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
            return WeekFitWidgetTextFitting.fit(allClearLabel(), to: .smallState, fallback: modeFallback)
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
        if mode == .empty { return openWeekFitLabel() }
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
        case .inProgress: return t("Now", "Сейчас")
        case .due: return t("Due", "Пора")
        case .upcoming, .none: return t("Up next", "Дальше")
        }
    }

    public static func nextPhaseLabel(_ phase: WeekFitWidgetSnapshot.NextActionPhase) -> String {
        switch phase {
        case .inProgress: return t("Now", "Сейчас")
        case .due: return t("Due", "Пора")
        case .upcoming, .none: return t("Next", "Дальше")
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
        if hay.hasPrefix("перед: \(next)") { return true }
        if hay.hasPrefix("перед \(next)") { return true }
        if hay.hasPrefix("после \(next)") { return true }
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
