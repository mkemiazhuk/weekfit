import Foundation

/// Summarizes what the day already carried and what is still ahead in the plan.
enum CoachDayPlanReadBuilder {

    struct ActivityLabel: Equatable {
        let english: String
        let russian: String
    }

    struct DayPlanSummary: Equatable {
        let completedLabels: [ActivityLabel]
        let remainingLabels: [ActivityLabel]
        let completedMinutes: Int
        let remainingMinutes: Int

        var hasRemainingToday: Bool { !remainingLabels.isEmpty }
        var hasMultipleCompleted: Bool { completedLabels.count >= 2 }
    }

    static func build(input: CoachInputSnapshot) -> DayPlanSummary? {
        let completed = (input.dayContext.completedActivities + input.dayContext.partialActivities)
            .filter { CoachLightRecoveryStableDayPolicy.isActuallyCompleted($0, now: input.now) }
            .sorted { $0.date < $1.date }
        let remaining = input.dayContext.upcomingActivities
            .filter { !CoachLightRecoveryStableDayPolicy.isActuallyCompleted($0, now: input.now) }
            .sorted { $0.date < $1.date }

        let completedLabels = deduplicatedLabels(from: completed)
        let remainingLabels = deduplicatedLabels(from: remaining)

        guard !completedLabels.isEmpty || !remainingLabels.isEmpty else { return nil }

        return DayPlanSummary(
            completedLabels: completedLabels,
            remainingLabels: remainingLabels,
            completedMinutes: input.dayContext.completedActivityVolumeMinutes,
            remainingMinutes: input.dayContext.upcomingActivityVolumeMinutes
        )
    }

    static func completedDayClause(_ summary: DayPlanSummary) -> (english: String, russian: String)? {
        guard !summary.completedLabels.isEmpty else { return nil }
        let english = joinedList(summary.completedLabels.map(\.english), conjunction: "and")
        let russian = joinedList(summary.completedLabels.map(\.russian), conjunction: "и")
        return (
            "So far today: \(english).",
            "Сегодня уже были: \(russian)."
        )
    }

    static func remainingDayClause(_ summary: DayPlanSummary) -> (english: String, russian: String)? {
        guard let first = summary.remainingLabels.first else { return nil }
        if summary.remainingLabels.count == 1 {
            return (
                "Still on today's plan: \(first.english).",
                "Ещё в плане на сегодня: \(first.russian)."
            )
        }
        let english = joinedList(summary.remainingLabels.map(\.english), conjunction: "and")
        let russian = joinedList(summary.remainingLabels.map(\.russian), conjunction: "и")
        return (
            "Still on today's plan: \(english).",
            "Ещё в плане на сегодня: \(russian)."
        )
    }

    static func postSessionBalanceClause(
        summary: DayPlanSummary,
        isPostHeat: Bool
    ) -> (english: String, russian: String)? {
        if let remaining = remainingDayClause(summary) {
            if isPostHeat {
                return (
                    "Sauna's done — take it easy and stick to what's left in your plan.",
                    "Сауна закончена — берегите силы и держитесь того, что ещё в плане."
                )
            }
            return (
                "You've already done a fair bit today — save your energy for what's left.",
                "Сегодня уже было немало — берегите силы на то, что ещё впереди."
            )
        }
        if summary.completedLabels.count >= 2 || summary.completedMinutes >= 90 {
            return (
                "You've moved enough today — take it easy for the rest of the day.",
                "Сегодня уже достаточно движения — остаток дня держите лёгким."
            )
        }
        return nil
    }

    static func postHeatHero(summary: DayPlanSummary?) -> (english: String, russian: String)? {
        guard let summary else { return nil }
        guard summary.completedLabels.contains(where: { $0.english == "sauna" }) else { return nil }
        if let remaining = summary.remainingLabels.first {
            if summary.remainingLabels.count == 1 {
                return (
                    "After sauna — \(remaining.english) is still on today's plan",
                    "После сауны — \(remaining.russian) ещё в плане на сегодня"
                )
            }
            let english = joinedList(summary.remainingLabels.map(\.english), conjunction: "and")
            let russian = joinedList(summary.remainingLabels.map(\.russian), conjunction: "и")
            return (
                "After sauna — still on today's plan: \(english)",
                "После сауны — ещё в плане: \(russian)"
            )
        }
        if summary.completedLabels.count >= 2 || summary.completedMinutes >= 60 {
            return (
                "After sauna — take it easy for the rest of today",
                "После сауны — остаток дня держите лёгким"
            )
        }
        return nil
    }

    static func nextRemainingActivity(_ input: CoachInputSnapshot) -> PlannedActivity? {
        input.dayContext.upcomingActivities
            .sorted { $0.date < $1.date }
            .first
    }

    // MARK: - Labels

    private static func deduplicatedLabels(from activities: [PlannedActivity]) -> [ActivityLabel] {
        var seen = Set<String>()
        var labels: [ActivityLabel] = []
        for activity in activities {
            let label = activityLabel(activity)
            let key = label.english.lowercased()
            guard seen.insert(key).inserted else { continue }
            labels.append(label)
        }
        return labels
    }

    private static func activityLabel(_ activity: PlannedActivity) -> ActivityLabel {
        let text = "\(activity.title) \(activity.type)".lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if kind == .heat || text.contains("sauna") || text.contains("steam") {
            return ActivityLabel(english: "sauna", russian: "сауна")
        }
        if text.contains("yoga") { return ActivityLabel(english: "yoga", russian: "йога") }
        if text.contains("stretch") { return ActivityLabel(english: "stretching", russian: "растяжка") }
        if text.contains("walk") || text.contains("walking") || text.contains("hike") {
            return ActivityLabel(english: "walk", russian: "прогулка")
        }
        if text.contains("breath") { return ActivityLabel(english: "breathing", russian: "дыхание") }
        if text.contains("mobility") { return ActivityLabel(english: "mobility", russian: "мобильность") }
        if kind == .endurance {
            if text.contains("run") { return ActivityLabel(english: "run", russian: "бег") }
            if text.contains("cycl") || text.contains("bike") {
                return ActivityLabel(english: "ride", russian: "велосессия")
            }
            return ActivityLabel(english: "endurance session", russian: "кардио")
        }
        if kind == .workout {
            if text.contains("upper body") || (text.contains("upper") && text.contains("body")) {
                return ActivityLabel(english: "upper body work", russian: "верх тела")
            }
            if text.contains("lower body") || (text.contains("lower") && text.contains("body")) {
                return ActivityLabel(english: "lower body work", russian: "низ тела")
            }
            if text.contains("full body") || (text.contains("full") && text.contains("body")) {
                return ActivityLabel(english: "full body work", russian: "все тело")
            }
            if text.contains("core") || text.contains("кор") || text.contains("пресс") {
                return ActivityLabel(english: "core work", russian: "кор")
            }
            return ActivityLabel(english: "strength work", russian: "силовая")
        }

        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return ActivityLabel(english: title.lowercased(), russian: title.lowercased())
        }
        return ActivityLabel(english: "session", russian: "сессия")
    }

    private static func joinedList(_ items: [String], conjunction: String) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) \(conjunction) \(items[1])" }
        return "\(items.dropLast().joined(separator: ", ")), \(conjunction) \(items.last!)"
    }
}
