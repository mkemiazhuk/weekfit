import Foundation

// MARK: - Bilingual copy primitives

struct CoachBilingualText: Equatable, Sendable, Hashable {
    let english: String
    let russian: String

    static func en(_ english: String, _ russian: String) -> CoachBilingualText {
        CoachBilingualText(english: english, russian: russian)
    }
}

struct CoachCopySection: Equatable, Sendable {
    let lines: [CoachBilingualText]

    static func single(_ line: CoachBilingualText) -> CoachCopySection {
        CoachCopySection(lines: [line])
    }

    static func lines(_ items: CoachBilingualText...) -> CoachCopySection {
        CoachCopySection(lines: items)
    }

    var isEmpty: Bool { lines.isEmpty }
}

/// Safety-critical overlay — sits above the pack without replacing the primary story.
struct CoachWarningLayer: Equatable, Sendable {
    let alert: CoachSafetyAlert
    let message: CoachBilingualText
}

// MARK: - Copy pack

struct CoachCopyPack: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let assessment: CoachCopySection
    let recommendation: CoachCopySection
    let avoid: CoachCopySection
    let nextAction: CoachCopySection
    let supportingSignals: CoachCopySection
    let warningLayer: CoachWarningLayer?
}

// MARK: - Build input

/// Everything the registry needs to assemble a pack — no V5 owners or story builders.
struct CoachCopyBuildInput: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let modifiers: CoachScenarioModifiers
    let athleteState: CoachAthleteState
    let fuelState: CoachFuelState
    let hydrationState: CoachHydrationState
    let safetyAlert: CoachSafetyAlert?
    let semanticColor: CoachSemanticColor
    let alertSeverity: CoachAlertSeverity
    let tomorrowWorkout: CoachTomorrowWorkout?
    let dayReadiness: CoachDayReadiness
    let focusSource: CoachFocusSource
    let sessionPhase: CoachSessionPhase
    let activityState: CoachActivityState
    let minutesSinceEnd: Int?
    let conversationPhase: CoachConversationPhase

    var activityType: CoachActivityType { modifiers.activityType }
    var dayLoad: CoachDayLoadBand { modifiers.dayLoad }
    var tomorrowDemand: CoachTomorrowDemand { modifiers.tomorrowDemand }
    var timeOfDay: CoachTimeOfDay { modifiers.timeOfDay }

    static func from(result: CoachEngine.Result) -> CoachCopyBuildInput {
        from(
            context: result.context,
            resolution: result.resolution,
            todayInsight: result.todayInsight
        )
    }

    static func from(
        context: CoachContext,
        resolution: CoachScenarioResolution,
        todayInsight: CoachTodayInsight
    ) -> CoachCopyBuildInput {
        CoachCopyBuildInput(
            scenario: resolution.scenario,
            modifiers: resolution.modifiers,
            athleteState: CoachAthleteStateResolver.resolve(context: context),
            fuelState: context.fuelState,
            hydrationState: context.hydrationState,
            safetyAlert: resolution.safetyAlert,
            semanticColor: todayInsight.semanticColor,
            alertSeverity: todayInsight.alertSeverity,
            tomorrowWorkout: context.tomorrowWorkout,
            dayReadiness: context.dayReadiness,
            focusSource: context.focusSource,
            sessionPhase: context.sessionPhase,
            activityState: context.activityState,
            minutesSinceEnd: context.minutesSinceEnd,
            conversationPhase: context.conversationPhase
        )
    }

    init(
        scenario: CoachScenarioKey,
        modifiers: CoachScenarioModifiers,
        athleteState: CoachAthleteState,
        fuelState: CoachFuelState,
        hydrationState: CoachHydrationState,
        safetyAlert: CoachSafetyAlert?,
        semanticColor: CoachSemanticColor,
        alertSeverity: CoachAlertSeverity,
        tomorrowWorkout: CoachTomorrowWorkout?,
        dayReadiness: CoachDayReadiness,
        focusSource: CoachFocusSource = .idle,
        sessionPhase: CoachSessionPhase = .idle,
        activityState: CoachActivityState = .none,
        minutesSinceEnd: Int? = nil,
        conversationPhase: CoachConversationPhase = .steady
    ) {
        self.scenario = scenario
        self.modifiers = modifiers
        self.athleteState = athleteState
        self.fuelState = fuelState
        self.hydrationState = hydrationState
        self.safetyAlert = safetyAlert
        self.semanticColor = semanticColor
        self.alertSeverity = alertSeverity
        self.tomorrowWorkout = tomorrowWorkout
        self.dayReadiness = dayReadiness
        self.focusSource = focusSource
        self.sessionPhase = sessionPhase
        self.activityState = activityState
        self.minutesSinceEnd = minutesSinceEnd
        self.conversationPhase = conversationPhase
    }
}
