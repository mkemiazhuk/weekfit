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

    /// Snapshot language (`en` / `ru` / `zh-Hans`). Widget chrome follows this, not the system locale.
    public static var languageCode = "en"

    public static var usesRussian: Bool { languageCode == "ru" }

    public static func applyLanguage(_ code: String) {
        let lower = code.lowercased()
        if lower.hasPrefix("ru") {
            languageCode = "ru"
        } else if lower.hasPrefix("zh") {
            languageCode = "zh-Hans"
        } else {
            languageCode = "en"
        }
    }

    private static func t(_ en: String, _ ru: String, _ zh: String) -> String {
        switch languageCode {
        case "ru": return ru
        case "zh-Hans": return zh
        default: return en
        }
    }

    public static func metricMoveTitle() -> String { t("Move", "Акт.", "活动") }
    public static func metricFuelTitle() -> String { t("Fuel", "Еда", "饮食") }
    public static func metricReadyTitle() -> String { t("Ready", "Форма", "状态") }

    public static func recoveryDisplay(score: Int?) -> String {
        guard let score else { return "—" }
        return "\(score)"
    }

    public static func recoveryScoreLabel(for score: Int) -> String {
        switch score {
        case 70...: return t("Ready", "Готов", "状态")
        case 55..<70: return t("Steady", "Ровно", "平稳")
        case 40..<55: return t("Protect", "Беречь", "保护")
        default: return t("Recover", "Восст.", "恢复")
        }
    }

    public static func recoveryCaption(label: String?, hasSignal: Bool) -> String {
        if let label, !label.isEmpty { return label }
        return hasSignal ? t("Ready", "Готов", "状态") : t("Recovery", "Восст.", "恢复")
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
        case .goodToGo: return t("Good to go", "Можно тренироваться", "可以训练")
        case .takeItEasy: return t("Take it easy", "Сегодня легче", "今天轻松些")
        case .recoveryFocus: return t("Recovery focus", "Фокус на восстановлении", "专注恢复")
        case .maintain: return t("Steady day", "Спокойный день", "平稳的一天")
        case .empty: return "WeekFit"
        }
    }

    public static func shortKindLabel(_ kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return t("Walk", "Прогулка", "步行")
        case .cycling: return t("Ride", "Вело", "骑行")
        case .running: return t("Run", "Бег", "跑步")
        case .swimming: return t("Swim", "Плавание", "游泳")
        case .yoga: return t("Yoga", "Йога", "瑜伽")
        case .racket: return t("Match", "Матч", "比赛")
        case .strength: return t("Strength", "Сила", "力量")
        case .recovery: return t("Recovery", "Восстановление", "恢复")
        case .sauna: return t("Sauna", "Сауна", "桑拿")
        case .meal: return t("Meal", "Еда", "用餐")
        case .hydration: return t("Hydrate", "Вода", "补水")
        case .rest: return t("Rest", "Отдых", "休息")
        case .none: return t("Open", "Открыть", "打开")
        }
    }

    /// Widget-native next label when app copy is too long for the card.
    public static func widgetNextLabel(for kind: WeekFitWidgetSnapshot.NextActionKind) -> String {
        switch kind {
        case .walk: return t("Easy walk", "Лёгкая прогулка", "轻松步行")
        case .cycling: return t("Easy ride", "Лёгкая поездка", "轻松骑行")
        case .running: return t("Easy run", "Лёгкий бег", "轻松跑步")
        case .swimming: return t("Swim", "Плавание", "游泳")
        case .yoga: return t("Yoga", "Йога", "瑜伽")
        case .racket: return t("Match", "Матч", "比赛")
        case .strength: return t("Strength", "Сила", "力量")
        case .recovery: return t("Quiet pause", "Тихая пауза", "安静休息")
        case .sauna: return t("Sauna", "Сауна", "桑拿")
        case .meal: return t("Fuel up", "Подкрепиться", "补充能量")
        case .hydration: return t("Hydrate", "Вода", "补水")
        case .rest: return t("Rest", "Отдых", "休息")
        case .none: return t("Open app", "Открыть приложение", "打开应用")
        }
    }

    public static func mediumDetailFallback(for mode: WeekFitWidgetSnapshot.DayMode) -> String {
        switch mode {
        case .goodToGo: return t("Train as planned.", "Тренируйтесь по плану.", "按计划训练。")
        case .maintain: return t("Keep the day steady.", "Держите день ровным.", "保持平稳节奏。")
        case .takeItEasy: return t("Ease intensity today.", "Сегодня без лишней интенсивности.", "今天降低强度。")
        case .recoveryFocus: return t("Protect sleep and load.", "Берегите сон и нагрузку.", "保护睡眠与负荷。")
        case .empty: return t("Prepare your day.", "Соберите день.", "安排好今天。")
        }
    }

    public static func smallHeroFallback(for mode: WeekFitWidgetSnapshot.DayMode, hasNext: Bool) -> String {
        switch mode {
        case .goodToGo, .maintain:
            return hasNext
                ? t("You're on track", "Вы в ритме", "状态不错")
                : t("Nothing urgent now", "Сейчас ничего срочного", "暂无紧急事项")
        case .takeItEasy:
            return t("Keep today light", "Сегодня легче", "今天轻松些")
        case .recoveryFocus:
            return t("Protect recovery", "Берегите восстановление", "保护恢复")
        case .empty:
            return hasNext
                ? t("Open WeekFit", "Откройте WeekFit", "打开 WeekFit")
                : t("Nothing urgent now", "Сейчас ничего срочного", "暂无紧急事项")
        }
    }

    public static func allClearLabel() -> String { t("All clear", "Всё спокойно", "一切顺利") }
    public static func openWeekFitLabel() -> String { t("Open WeekFit", "Откройте WeekFit", "打开 WeekFit") }
    public static func prepareDayLabel() -> String { t("Prepare your day.", "Соберите день.", "安排好今天。") }

    public static func duringLabel(eventTitle: String) -> String {
        t("During \(eventTitle)", "Сейчас: \(eventTitle)", "进行中：\(eventTitle)")
    }

    public static func beforeLabel(eventTitle: String) -> String {
        t("Before \(eventTitle)", "Перед: \(eventTitle)", "开始前：\(eventTitle)")
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
        case .inProgress: return t("Now", "Сейчас", "现在")
        case .due: return t("Due", "Пора", "到点了")
        case .upcoming, .none: return t("Up next", "Дальше", "接下来")
        }
    }

    public static func nextPhaseLabel(_ phase: WeekFitWidgetSnapshot.NextActionPhase) -> String {
        switch phase {
        case .inProgress: return t("Now", "Сейчас", "现在")
        case .due: return t("Due", "Пора", "到点了")
        case .upcoming, .none: return t("Next", "Дальше", "下一步")
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
