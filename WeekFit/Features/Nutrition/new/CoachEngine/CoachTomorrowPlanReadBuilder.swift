import Foundation

/// Builds human-readable tomorrow recovery-plan labels from scheduled activities.
enum CoachTomorrowPlanReadBuilder {

    struct RecoveryPlanSummary: Equatable {
        let englishActivityList: String
        let russianActivityList: String
    }

    static func tomorrowActivities(input: CoachInputSnapshot) -> [PlannedActivity] {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.selectedDate) else {
            return []
        }
        return input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: tomorrow) && !$0.isSkipped }
            .sorted { $0.date < $1.date }
    }

    static func isRecoveryFocused(input: CoachInputSnapshot) -> Bool {
        guard input.dayPriorityModel.tomorrowDemand != .hard else { return false }
        let activities = tomorrowActivities(input: input)
        guard !activities.isEmpty else { return false }
        return activities.allSatisfy { !isTraining($0) }
    }

    private static func isTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .workout || kind == .endurance
    }

    static func recoveryPlanSummary(input: CoachInputSnapshot) -> RecoveryPlanSummary? {
        guard isRecoveryFocused(input: input) else { return nil }
        let labels = deduplicatedLabels(from: tomorrowActivities(input: input))
        guard !labels.isEmpty else { return nil }
        return RecoveryPlanSummary(
            englishActivityList: joinedList(labels.map(\.english), conjunction: "and"),
            russianActivityList: joinedList(labels.map(\.russian), conjunction: "и")
        )
    }

    static func forwardClause(summary: RecoveryPlanSummary) -> (english: String, russian: String) {
        (
            "Tomorrow has \(summary.englishActivityList) — a calm evening and sleep are enough.",
            "Завтра в плане \(summary.russianActivityList) — достаточно спокойного вечера и сна."
        )
    }

    // MARK: - Activity labels

    private static func deduplicatedLabels(from activities: [PlannedActivity]) -> [(english: String, russian: String)] {
        var seen = Set<String>()
        var labels: [(english: String, russian: String)] = []
        for activity in activities {
            let label = activityLabel(activity)
            let key = label.english.lowercased()
            guard seen.insert(key).inserted else { continue }
            labels.append(label)
        }
        return labels
    }

    private static func activityLabel(_ activity: PlannedActivity) -> (english: String, russian: String) {
        switch recoveryFamily(for: activity) {
        case .breathing:
            return ("breathing", "дыхание")
        case .stretching:
            return ("stretching", "растяжка")
        case .yoga:
            return ("yoga", "йога")
        case .mobility:
            return ("mobility", "мобильность")
        case .walk:
            return ("walk", "прогулка")
        case .sauna:
            return ("sauna", "сауна")
        case .other:
            let title = activityTitleFallback(activity)
            if title != "Recovery activity" {
                return (title.lowercased(), title.lowercased())
            }
            return ("recovery work", "восстановительная активность")
        }
    }

    private enum RecoveryFamily {
        case breathing
        case stretching
        case yoga
        case mobility
        case walk
        case sauna
        case other
    }

    private static func recoveryFamily(for activity: PlannedActivity) -> RecoveryFamily {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if text.contains("breath") { return .breathing }
        if text.contains("stretch") { return .stretching }
        if text.contains("yoga") { return .yoga }
        if text.contains("mobility") { return .mobility }
        if text.contains("walk") || text.contains("walking") || text.contains("hike") { return .walk }
        if kind == .heat || text.contains("sauna") || text.contains("steam") || text.contains("bath") {
            return .sauna
        }
        return .other
    }

    private static func activityTitleFallback(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "Recovery activity" : type
    }

    private static func joinedList(_ items: [String], conjunction: String) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) \(conjunction) \(items[1])" }
        let head = items.dropLast().joined(separator: ", ")
        return "\(head) \(conjunction) \(items.last!)"
    }
}
