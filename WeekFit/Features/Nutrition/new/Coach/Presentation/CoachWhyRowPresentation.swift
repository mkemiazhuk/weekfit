import Foundation
import SwiftUI

/// Maps supporting-signal copy to Why-row icon and color from text content — not list position.
enum CoachWhyRowPresentation {

    struct Style: Equatable {
        let icon: String
        let color: Color
    }

    static func resolve(title: String, semanticColor: Color) -> Style {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return Style(icon: "info.circle.fill", color: semanticColor.opacity(0.85))
        }

        if mentionsSleep(text) {
            return Style(icon: "moon.zzz.fill", color: CoachPalette.recovery)
        }
        if mentionsLongSession(text) || mentionsUpcomingTraining(text) {
            return Style(icon: "figure.run", color: CoachPalette.training)
        }
        if mentionsHydrationTopic(text) {
            return Style(icon: "drop.fill", color: CoachPalette.hydration)
        }
        if CoachCopyQualityAudit.mentionsFuel(text) || mentionsFirstMealAhead(text) || mentionsCalorieLag(text) {
            return Style(icon: "fork.knife", color: CoachPalette.fueling)
        }
        if mentionsStackedLoad(text) {
            return Style(icon: "exclamationmark.triangle.fill", color: CoachPalette.warning)
        }
        if mentionsDayLoad(text) {
            return Style(icon: "chart.bar.fill", color: semanticColor)
        }
        if mentionsTomorrowPlan(text) {
            return Style(icon: "calendar", color: CoachPalette.protection)
        }
        if mentionsRecoveryLag(text) {
            return Style(icon: "heart.text.clipboard.fill", color: CoachPalette.recovery)
        }
        if mentionsYesterdayLoad(text) {
            return Style(icon: "clock.arrow.circlepath", color: semanticColor.opacity(0.85))
        }

        return Style(icon: "info.circle.fill", color: semanticColor.opacity(0.85))
    }

    // MARK: - Topic detection

    private static func mentionsHydrationTopic(_ text: String) -> Bool {
        if CoachCopyQualityAudit.mentionsHydration(text) { return true }
        let lower = text.lowercased()
        return lower.contains("вод") || lower.contains("жидк") || lower.contains("пейте")
    }

    private static func mentionsSleep(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("sleep was") || lower.contains("short sleep") || lower.contains("short night") {
            return true
        }
        return text.contains("Сон был")
            || text.contains("короткая ночь")
            || text.contains("короткий сон")
    }

    private static func mentionsRecoveryLag(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("recovery is lagging") || lower.contains("recovery is low") {
            return true
        }
        return text.contains("Тело ещё не восстановилось")
            || text.contains("тело ещё не восстановилось")
            || text.contains("восстановление низкое")
    }

    private static func mentionsDayLoad(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("cumulative load")
            || lower.contains("serious work is already")
            || lower.contains("load is already high") {
            return true
        }
        return text.contains("много нагрузки")
            || text.contains("нагрузка уже")
            || text.contains("серьёзная работа")
            || text.contains("заметная нагрузка")
    }

    private static func mentionsStackedLoad(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("stacked") || lower.contains("heavy day stacked") {
            return true
        }
        return text.contains("на пределе")
            || text.contains("День на пределе")
    }

    private static func mentionsTomorrowPlan(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("tomorrow") && (lower.contains("calendar") || lower.contains("plan") || lower.contains("fresh legs")) {
            return true
        }
        return text.contains("Завтра")
    }

    private static func mentionsUpcomingTraining(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("walk is next")
            || lower.contains("match day")
            || lower.contains("training is on the plan") {
            return true
        }
        return text.contains("прогулка")
            || text.contains("Игра впереди")
            || text.contains("Тренировка в календаре")
            || text.contains("тренировка в календаре")
    }

    private static func mentionsLongSession(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("long session")
            || text.contains("Длинная тренировка")
    }

    private static func mentionsYesterdayLoad(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("yesterday still counts") || lower.contains("yesterday was heavy") {
            return true
        }
        return text.contains("Вчера ещё в теле")
            || text.contains("Вчера была нагрузка")
    }

    private static func mentionsFirstMealAhead(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("first meal is still ahead")
            || text.contains("Первая еда ещё впереди.")
    }

    private static func mentionsCalorieLag(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("calories lag") || lower.contains("fuel intake is lagging") {
            return true
        }
        return text.contains("Калорий маловато")
            || text.contains("Еды пока меньше")
    }
}
