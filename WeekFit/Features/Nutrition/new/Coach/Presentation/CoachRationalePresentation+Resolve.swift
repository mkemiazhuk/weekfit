import Foundation
import SwiftUI

extension CoachRationalePresentation {
    static func resolve(from input: CoachInputSnapshot) -> CoachRationalePresentation? {
        guard let active = input.dayContext.allActivities.first(where: { isActiveActivity($0, now: input.now) }) ??
                input.brain.activities.first(where: { isActiveActivity($0, now: input.now) }) else {
            return nil
        }

        let model = input.dayPriorityModel
        let target = rationaleTarget(
            active: active,
            model: model
        )
        guard let target else { return nil }

        let rationale = rationaleCopy(
            active: active,
            target: target,
            model: model
        )

        return CoachRationalePresentation(
            title: rationale.title,
            message: rationale.message,
            icon: icon(for: target),
            color: WeekFitTheme.meal,
            sourceActivityID: target.id
        )
    }

    private static func isActiveActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date

        return activity.date <= now && now <= end
    }

    private static func cleanTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Training" : trimmed
    }

    private static func activeActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        if title.contains("walk") || type.contains("walk") {
            return "walk"
        }
        return "session"
    }

    private static func rationaleTarget(
        active: PlannedActivity,
        model: DayPriorityModel
    ) -> PlannedActivity? {
        if let primary = model.primarySession, primary.id != active.id {
            return primary
        }

        if let secondary = model.secondarySession, secondary.id != active.id {
            return secondary
        }

        return nil
    }

    private static func rationaleCopy(
        active: PlannedActivity,
        target: PlannedActivity,
        model: DayPriorityModel
    ) -> (title: String, message: String) {
        let targetName = cleanTitle(target.title)
        let activeName = activeActivityName(active)
        let kind = CoachActivityContextResolver.kind(for: target)
        let load = CoachActivityContextResolver.load(for: target)

        if model.protectionTarget == .tomorrow {
            return (
                title: "Protect tomorrow",
                message: "Tomorrow carries real demand. Keep this \(activeName) easy so today supports recovery instead of borrowing from the next training day."
            )
        }

        switch kind {
        case .endurance:
            return (
                title: "Protect the main effort",
                message: "\(targetName) is the key workload today. Keep this \(activeName) relaxed so you preserve legs and fueling for the main effort."
            )

        case .workout:
            let loadPhrase = load == .high || load == .extreme
                ? "the highest-value training block"
                : "the priority training block"
            return (
                title: "Save quality for training",
                message: "\(targetName) is \(loadPhrase) today. Use this \(activeName) to stay loose, not to add fatigue before loading."
            )

        case .heat:
            return (
                title: "Arrive settled for heat",
                message: "\(targetName) will add heat stress. Keep this \(activeName) easy so you start hydrated, calm, and not already taxed."
            )

        case .recovery:
            return (
                title: "Keep the day restorative",
                message: "\(targetName) is meant to support recovery. Keep this \(activeName) easy so the day stays restorative, not draining."
            )

        case .meal:
            return (
                title: "Keep digestion easy",
                message: "\(targetName) is the next useful reset. Keep this \(activeName) easy so appetite and digestion stay steady."
            )

        case .other:
            return (
                title: "Protect what comes next",
                message: "\(targetName) is the next meaningful block. Keep this \(activeName) easy so you arrive fresh instead of carrying extra fatigue."
            )
        }
    }

    private static func icon(for activity: PlannedActivity) -> String {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("core") || text.contains("strength") || text.contains("gym") {
            return "figure.core.training"
        }
        if text.contains("run") {
            return "figure.run"
        }
        if text.contains("ride") || text.contains("bike") || text.contains("cycle") {
            return "bicycle"
        }
        return "figure.strengthtraining.traditional"
    }
}

func validTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
