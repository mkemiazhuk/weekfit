import Foundation
import SwiftUI

struct CoachTodayPresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
}

struct CoachScreenPresentation {
    let stateLabel: String
    let title: String
    let message: String
    let icon: String
    let color: Color
    let supportActions: [CoachSupportActionV3]
    let avoidNotes: [String]
}

struct CoachRationalePresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let sourceActivityID: String
}

enum CoachStateStatus: Equatable {
    case ready
    case refreshingPrevious
    case unavailable(reason: String)
    case invalid(reason: String)
}

struct CoachState: Identifiable {
    let id: UUID
    let createdAt: Date
    let status: CoachStateStatus
    let input: CoachInputSnapshot?
    let fingerprint: CoachInputFingerprint?
    let guidance: CoachGuidanceV3?
    let todayPresentation: CoachTodayPresentation
    let coachPresentation: CoachScreenPresentation?
    let rationalePresentation: CoachRationalePresentation?

    var hasValidGuidance: Bool {
        guidance != nil && coachPresentation != nil
    }

    static func unavailable(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            guidance: nil,
            todayPresentation: CoachTodayPresentation(
                title: "Coach unavailable",
                message: "Connect today’s plan, nutrition, and recovery data to unlock guidance.",
                icon: "sparkles",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil
        )
    }

    static func ready(
        input: CoachInputSnapshot,
        fingerprint: CoachInputFingerprint,
        guidance: CoachGuidanceV3,
        createdAt: Date = Date()
    ) -> CoachState {
        let compact = guidance.v5Interpretation.compactInsight
        let dayNarrative = CoachDayNarrativePresentation.resolve(
            input: input,
            guidance: guidance
        )
        let frame = guidance.dayDecisionFrame
        let frameOwnsNarrative = frame?.shouldOwnNarrative == true
        let frameStory = frameOwnsNarrative ? guidance.screenStory : nil
        let stateLabel = frameOwnsNarrative ? frame?.stateLabel ?? guidance.stateLabel : dayNarrative?.stateLabel ?? guidance.screenStory?.stateLabel ?? guidance.stateLabel
        let title = frameOwnsNarrative ? frameStory?.title ?? frame?.title ?? guidance.title : dayNarrative?.title ?? validTitle(guidance.title) ?? guidance.screenStory?.title ?? guidance.priority.detailTitle
        let message = frameOwnsNarrative ? frameStory?.myRead ?? frame?.diagnosisText ?? guidance.message : dayNarrative?.message ?? guidance.screenStory?.myRead ?? guidance.message
        let icon = dayNarrative?.icon ?? guidance.screenStory?.icon ?? guidance.icon
        let color = dayNarrative?.color ?? guidance.screenStory?.color ?? guidance.color

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            todayPresentation: CoachTodayPresentation(
                title: frameOwnsNarrative ? frameStory?.title ?? frame?.todayTitle ?? compact.title : dayNarrative?.todayTitle ?? compact.title,
                message: frameOwnsNarrative ? frameStory?.myRead ?? frame?.todayMessage ?? compact.text : dayNarrative?.todayMessage ?? compact.text,
                icon: dayNarrative?.icon ?? compact.icon,
                color: dayNarrative?.color ?? compact.color
            ),
            coachPresentation: CoachScreenPresentation(
                stateLabel: stateLabel,
                title: title,
                message: message,
                icon: icon,
                color: color,
                supportActions: guidance.supportActions,
                avoidNotes: guidance.avoidNotes
            ),
            rationalePresentation: CoachRationalePresentation.resolve(from: input)
        )
    }

    func preservingPreviousDuringRefresh(createdAt: Date = Date()) -> CoachState {
        guard hasValidGuidance else { return self }

        return CoachState(
            id: id,
            createdAt: createdAt,
            status: .refreshingPrevious,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            todayPresentation: todayPresentation,
            coachPresentation: coachPresentation,
            rationalePresentation: rationalePresentation
        )
    }
}

private struct CoachDayNarrativePresentation {
    let stateLabel: String
    let title: String
    let message: String
    let todayTitle: String
    let todayMessage: String
    let icon: String
    let color: Color

    static func resolve(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachDayNarrativePresentation? {
        let model = input.dayPriorityModel
        let nutrition = input.nutritionContext
        let constraints = DayConstraints(input: input)
        let isDemandingDay = model.dayGoal == .overload ||
            model.dayStressLevel == .overload ||
            model.dayStressLevel == .high
        let isRecoveryPriority = guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .postActivityRecovery ||
            guidance.priority.priority == .recovery
        let visualStateIsMisleading = guidance.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "ON TRACK"
        let isRecoveryPhase: Bool
        switch guidance.phase {
        case .recovering, .stable:
            isRecoveryPhase = true
        case .active, .preparing:
            isRecoveryPhase = false
        }

        guard isDemandingDay || isRecoveryPriority else { return nil }
        guard isRecoveryPhase || isRecoveryPriority || visualStateIsMisleading else { return nil }
        guard constraints.hasMeaningfulLimiter || visualStateIsMisleading || isRecoveryPriority else {
            return nil
        }

        let completedLine = accomplishmentLine(model: model, input: input)
        let limiterLine = constraints.limiterLine
        let protectionLine = protectionLine(model: model)
        let message = [
            completedLine,
            limiterLine,
            protectionLine
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return CoachDayNarrativePresentation(
            stateLabel: "RECOVERY PRIORITY",
            title: "Recovery is now the priority",
            message: message,
            todayTitle: "Recovery now leads the day",
            todayMessage: todayMessage(
                model: model,
                constraints: constraints,
                nutrition: nutrition
            ),
            icon: "bolt.shield.fill",
            color: WeekFitTheme.purple
        )
    }

    private static func accomplishmentLine(
        model: DayPriorityModel,
        input: CoachInputSnapshot
    ) -> String {
        if let primary = model.primarySession, primary.isCompleted {
            return "You completed the key workload today."
        }

        if input.dayContext.completedTrainingMinutes > 0 || input.dayContext.completedTrainingStressScore > 0 {
            return "Training work is complete for now."
        }

        return "Today has carried a demanding training load."
    }

    private static func protectionLine(model: DayPriorityModel) -> String? {
        switch model.protectionTarget {
        case .tomorrow:
            return "Protect tomorrow by keeping the rest of today easy."
        case .recovery:
            return "Protect recovery before adding more stress."
        case .primarySession:
            return "Protect the work by letting adaptation start now."
        case .consistency:
            return "Protect consistency by not adding extra fatigue."
        }
    }

    private static func todayMessage(
        model: DayPriorityModel,
        constraints: DayConstraints,
        nutrition: CoachNutritionContext?
    ) -> String {
        if constraints.hasFuelLimiter && constraints.hasHydrationLimiter {
            return "The day was demanding, and fuel plus hydration are now behind. Start recovery before adding more stress."
        }

        if constraints.hasFuelLimiter {
            return "The day was demanding, and fueling is now the limiter. Eat enough to support recovery."
        }

        if constraints.hasHydrationLimiter {
            return "The day was demanding, and hydration is now the limiter. Rehydrate steadily before the next block."
        }

        if model.protectionTarget == .tomorrow {
            return "The day was demanding. Downshift now so tomorrow's training is not compromised."
        }

        if nutrition?.needsProteinRecovery == true {
            return "The key work is done. Protein and recovery now matter more than adding load."
        }

        return "The key work is done. Recovery now matters more than adding load."
    }
}

private struct DayConstraints {
    let hasFuelLimiter: Bool
    let hasHydrationLimiter: Bool
    let hasProteinLimiter: Bool

    init(input: CoachInputSnapshot) {
        let nutrition = input.nutritionContext
        let calorieRatio = Self.ratio(
            current: nutrition?.caloriesCurrent ?? input.brain.metrics.calories,
            goal: nutrition?.caloriesGoal ?? input.brain.fullDayGoals.calories
        )
        let proteinRatio = Self.ratio(
            current: nutrition?.proteinCurrent ?? input.brain.metrics.protein,
            goal: nutrition?.proteinGoal ?? input.brain.fullDayGoals.protein
        )
        let waterRatio = Self.ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )

        hasFuelLimiter = input.brain.fuel == .underfueled ||
            calorieRatio < 0.45 ||
            proteinRatio < 0.35
        hasHydrationLimiter = input.brain.hydration == .depleted ||
            input.brain.hydration == .behind ||
            waterRatio < 0.60
        hasProteinLimiter = input.brain.protein == .low ||
            input.brain.protein == .behind ||
            proteinRatio < 0.50
    }

    var hasMeaningfulLimiter: Bool {
        hasFuelLimiter || hasHydrationLimiter || hasProteinLimiter
    }

    var limiterLine: String? {
        switch (hasFuelLimiter, hasHydrationLimiter, hasProteinLimiter) {
        case (true, true, true):
            return "Recovery, hydration and fueling are now the limiting factors, with protein still behind."
        case (true, true, false):
            return "Recovery, hydration and fueling are now the limiting factors."
        case (true, false, true):
            return "Recovery and fueling are now the limiting factors, with protein still behind."
        case (true, false, false):
            return "Recovery and fueling are now the limiting factors."
        case (false, true, true):
            return "Recovery and hydration are now the limiting factors, with protein still behind."
        case (false, true, false):
            return "Recovery and hydration are now the limiting factors."
        case (false, false, true):
            return "Recovery and protein are now the limiting factors."
        case (false, false, false):
            return nil
        }
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return current / goal
    }
}

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
        let kind = CoachActivityContextResolverV3.kind(for: target)
        let load = CoachActivityContextResolverV3.load(for: target)

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

private func validTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
