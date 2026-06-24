import Foundation

// MARK: - Bilingual copy primitives

struct CoachV6BilingualText: Equatable, Sendable, Hashable {
    let english: String
    let russian: String

    static func en(_ english: String, _ russian: String) -> CoachV6BilingualText {
        CoachV6BilingualText(english: english, russian: russian)
    }
}

struct CoachV6CopySection: Equatable, Sendable {
    let lines: [CoachV6BilingualText]

    static func single(_ line: CoachV6BilingualText) -> CoachV6CopySection {
        CoachV6CopySection(lines: [line])
    }

    static func lines(_ items: CoachV6BilingualText...) -> CoachV6CopySection {
        CoachV6CopySection(lines: items)
    }

    var isEmpty: Bool { lines.isEmpty }
}

/// Safety-critical overlay — sits above the pack without replacing the primary story.
struct CoachV6WarningLayer: Equatable, Sendable {
    let alert: CoachV6SafetyAlert
    let message: CoachV6BilingualText
}

// MARK: - Copy pack

struct CoachV6CopyPack: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let assessment: CoachV6CopySection
    let recommendation: CoachV6CopySection
    let avoid: CoachV6CopySection
    let nextAction: CoachV6CopySection
    let supportingSignals: CoachV6CopySection
    let warningLayer: CoachV6WarningLayer?
}

// MARK: - Build input

/// Everything the registry needs to assemble a pack — no V5 owners or story builders.
struct CoachV6CopyBuildInput: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let modifiers: CoachV6ScenarioModifiers
    let athleteState: CoachV6AthleteState
    let fuelState: CoachV6FuelState
    let hydrationState: CoachV6HydrationState
    let safetyAlert: CoachV6SafetyAlert?
    let semanticColor: CoachV6SemanticColor
    let alertSeverity: CoachV6AlertSeverity
    let tomorrowWorkout: CoachV6TomorrowWorkout?
    let dayReadiness: CoachV6DayReadiness

    var activityType: CoachV6ActivityType { modifiers.activityType }
    var dayLoad: CoachV6DayLoadBand { modifiers.dayLoad }
    var tomorrowDemand: CoachV6TomorrowDemand { modifiers.tomorrowDemand }
    var timeOfDay: CoachV6TimeOfDay { modifiers.timeOfDay }

    static func from(result: CoachV6Engine.Result) -> CoachV6CopyBuildInput {
        from(
            context: result.context,
            resolution: result.resolution,
            todayInsight: result.todayInsight
        )
    }

    static func from(
        context: CoachV6Context,
        resolution: CoachV6ScenarioResolution,
        todayInsight: CoachV6TodayInsight
    ) -> CoachV6CopyBuildInput {
        CoachV6CopyBuildInput(
            scenario: resolution.scenario,
            modifiers: resolution.modifiers,
            athleteState: CoachV6AthleteStateResolver.resolve(context: context),
            fuelState: context.fuelState,
            hydrationState: context.hydrationState,
            safetyAlert: resolution.safetyAlert,
            semanticColor: todayInsight.semanticColor,
            alertSeverity: todayInsight.alertSeverity,
            tomorrowWorkout: context.tomorrowWorkout,
            dayReadiness: context.dayReadiness
        )
    }
}
