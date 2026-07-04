import Foundation
import WeekFitPlanner

// MARK: - Activity taxonomy

enum CoachActivityFamily: String, CaseIterable, Equatable, Sendable {
    case endurance
    case racket
    case strength
    case recovery
    case heat
    case none
}

enum CoachActivityType: String, CaseIterable, Equatable, Sendable {
    case cycling
    case running
    case tennis
    case squash
    case upperBody
    case lowerBody
    case core
    case fullBody
    case walk
    case stretching
    case yoga
    case breathing
    case sauna
    case none
}

enum CoachActivityState: String, Equatable, Sendable {
    case none
    case upcoming
    case active
    case justFinished
    case finished
}

enum CoachSessionPhase: String, CaseIterable, Equatable, Sendable {
    case pre
    case during
    case immediatePost
    case settledPost
    case evening
    case tomorrowProtection
    case idle
}

enum CoachDurationBand: String, Equatable, Sendable {
    case short
    case medium
    case long
    case extended

    static func from(minutes: Int) -> CoachDurationBand {
        switch minutes {
        case ..<30:
            return .short
        case 30..<60:
            return .medium
        case 60..<90:
            return .long
        default:
            return .extended
        }
    }
}

enum CoachDayLoadBand: String, CaseIterable, Equatable, Sendable {
    case fresh
    case moderate
    case heavy
    case extreme
}

enum CoachCompletedSeriousActivities: Equatable, Sendable {
    case none
    case one
    case twoOrMore
}

enum CoachFuelState: String, Equatable, Sendable {
    case adequate
    case behind
    case critical
    case unknown

    var isBehind: Bool {
        switch self {
        case .behind, .critical:
            return true
        case .adequate, .unknown:
            return false
        }
    }
}

enum CoachHydrationState: String, Equatable, Sendable {
    case adequate
    case behind
    case critical
    case unknown

    var isBehind: Bool {
        switch self {
        case .behind, .critical:
            return true
        case .adequate, .unknown:
            return false
        }
    }
}

/// Tomorrow's primary planned training — for copy only, not scenario selection.
struct CoachTomorrowWorkout: Equatable, Sendable {
    let title: String
    let startHour: Int
    let startMinute: Int
    let durationMinutes: Int

    var formattedStartTime: String {
        String(format: "%d:%02d", startHour, startMinute)
    }
}

enum CoachTimeOfDay: String, Equatable, Sendable {
    case morning
    case midday
    case afternoon
    case evening
    case lateEvening
    case night

    static func from(hour: Int) -> CoachTimeOfDay {
        switch hour {
        case 5..<10:
            return .morning
        case 10..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        case 21..<23:
            return .lateEvening
        default:
            return .night
        }
    }

    /// True from 23:00 through early morning — sleep-now framing, not wind-down planning.
    static func isSleepNow(_ timeOfDay: CoachTimeOfDay) -> Bool {
        timeOfDay == .night
    }
}

// MARK: - Context
//
// Ownership: facts-only snapshot consumed by `CoachScenarioResolver`, copy registry, and
// presentation modifiers. Built exclusively by `CoachEngine.buildContext`.
// Does not own day aggregates (`CoachDayContext`) or UI phase windows (`CoachActivityWindowPolicy`).

/// Facts-only snapshot for Coach scenario resolution.
/// No narrative, owners, or copy — only telemetry and schedule state.
struct CoachContext: Equatable, Sendable {
    let activityFamily: CoachActivityFamily
    let activityType: CoachActivityType
    let activityState: CoachActivityState
    let sessionPhase: CoachSessionPhase
    let durationBand: CoachDurationBand
    let dayLoadBand: CoachDayLoadBand
    let completedSeriousActivities: CoachCompletedSeriousActivities
    let fuelState: CoachFuelState
    let hydrationState: CoachHydrationState
    let tomorrowDemand: CoachTomorrowDemand
    let timeOfDay: CoachTimeOfDay
    let tomorrowWorkout: CoachTomorrowWorkout?

    let focusActivityID: String?
    let focusSource: CoachFocusSource
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?
    let dayReadiness: CoachDayReadiness
    /// Latest completed serious activity today — for idle `stableDay` copy only.
    let lastCompletedSeriousActivityType: CoachActivityType
    /// Conversational frame — PR1 debug context only; does not route scenarios.
    let conversationPhase: CoachConversationPhase
    /// Human-readable resolver reason for logs and tests.
    let conversationPhaseReason: String

    init(
        activityFamily: CoachActivityFamily,
        activityType: CoachActivityType,
        activityState: CoachActivityState,
        sessionPhase: CoachSessionPhase,
        durationBand: CoachDurationBand,
        dayLoadBand: CoachDayLoadBand,
        completedSeriousActivities: CoachCompletedSeriousActivities,
        fuelState: CoachFuelState,
        hydrationState: CoachHydrationState,
        tomorrowDemand: CoachTomorrowDemand,
        timeOfDay: CoachTimeOfDay,
        tomorrowWorkout: CoachTomorrowWorkout?,
        focusActivityID: String?,
        focusSource: CoachFocusSource,
        minutesUntilStart: Int?,
        minutesSinceEnd: Int?,
        dayReadiness: CoachDayReadiness,
        lastCompletedSeriousActivityType: CoachActivityType,
        conversationPhase: CoachConversationPhase = .steady,
        conversationPhaseReason: String = CoachConversationPhase.defaultReason
    ) {
        self.activityFamily = activityFamily
        self.activityType = activityType
        self.activityState = activityState
        self.sessionPhase = sessionPhase
        self.durationBand = durationBand
        self.dayLoadBand = dayLoadBand
        self.completedSeriousActivities = completedSeriousActivities
        self.fuelState = fuelState
        self.hydrationState = hydrationState
        self.tomorrowDemand = tomorrowDemand
        self.timeOfDay = timeOfDay
        self.tomorrowWorkout = tomorrowWorkout
        self.focusActivityID = focusActivityID
        self.focusSource = focusSource
        self.minutesUntilStart = minutesUntilStart
        self.minutesSinceEnd = minutesSinceEnd
        self.dayReadiness = dayReadiness
        self.lastCompletedSeriousActivityType = lastCompletedSeriousActivityType
        self.conversationPhase = conversationPhase
        self.conversationPhaseReason = conversationPhaseReason
    }
}

// MARK: - Activity classification

enum CoachActivityClassifier {

    static func family(for activity: CoachPlannedActivitySnapshot) -> CoachActivityFamily {
        switch type(for: activity) {
        case .cycling, .running:
            return .endurance
        case .tennis, .squash:
            return .racket
        case .upperBody, .lowerBody, .core, .fullBody:
            return .strength
        case .walk, .stretching, .yoga, .breathing:
            return .recovery
        case .sauna:
            return .heat
        case .none:
            return .none
        }
    }

    static func type(for activity: CoachPlannedActivitySnapshot) -> CoachActivityType {
        let primary = primaryTokenText(for: activity)
        if let match = classifyType(in: primary) {
            return match
        }

        let accessory = accessoryTokenText(for: activity)
        if let match = classifyType(in: accessory) {
            return match
        }

        return .none
    }

    private static func classifyType(in text: String) -> CoachActivityType? {
        if containsAny(text, ["cycling", "cycle", "bike", "biking", "ride"]) {
            return .cycling
        }
        if containsAny(text, ["running", "run", "jog", "jogging"]) {
            return .running
        }
        if text.contains("tennis") {
            return .tennis
        }
        if text.contains("squash") {
            return .squash
        }
        if containsAny(text, ["swim", "swimming"]) {
            return nil
        }
        if containsAny(text, ["upper body", "upper-body", "upperbody", "push", "pull"]) {
            return .upperBody
        }
        if containsAny(text, ["lower body", "lower-body", "lowerbody", "legs"]) {
            return .lowerBody
        }
        if text.contains("core") {
            return .core
        }
        if containsAny(text, ["full body", "full-body", "fullbody"]) {
            return .fullBody
        }
        if containsAny(text, ["walk", "walking", "hike", "hiking", "прогул"]) {
            return .walk
        }
        if containsAny(text, ["strength", "gym", "lifting", "weights", "dumbbell", "barbell", "workout"]) {
            return .fullBody
        }
        if containsAny(text, ["breathing", "breathwork", "breath", "meditation", "mindfulness"]) {
            return .breathing
        }
        if containsAny(text, ["stretch", "mobility"]) {
            return .stretching
        }
        if text.contains("yoga") {
            return .yoga
        }
        if containsAny(text, ["sauna", "heat"]) {
            return .sauna
        }

        return nil
    }

    static func isSeriousTraining(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let activityType = type(for: activity)
        guard activityType != .none else { return false }

        switch activityType {
        case .walk, .stretching, .yoga, .breathing, .sauna, .none:
            return false
        case .cycling, .running:
            let minutes = activity.effectiveDurationMinutes
            let load = inferredLoad(for: activity)
            let text = tokenText(for: activity)
            return minutes >= 75 || load == .heavy || load == .extreme ||
                text.contains("interval") || text.contains("long")
        case .tennis, .squash:
            let minutes = activity.effectiveDurationMinutes
            let load = inferredLoad(for: activity)
            return minutes >= 60 || load == .heavy || load == .extreme
        case .upperBody, .lowerBody, .core, .fullBody:
            let minutes = activity.effectiveDurationMinutes
            let load = inferredLoad(for: activity)
            return minutes >= 45 || load == .heavy || load == .extreme
        }
    }

    private static func inferredLoad(for activity: CoachPlannedActivitySnapshot) -> CoachDayLoadBand {
        let minutes = activity.effectiveDurationMinutes
        let calories = activity.calories

        if minutes >= 120 || calories >= 900 {
            return .extreme
        }
        if minutes >= 75 || calories >= 600 {
            return .heavy
        }
        if minutes >= 45 || calories >= 350 {
            return .moderate
        }
        return .fresh
    }

    private static func primaryTokenText(for activity: CoachPlannedActivitySnapshot) -> String {
        [activity.type, activity.title]
            .joined(separator: " ")
            .lowercased()
    }

    private static func accessoryTokenText(for activity: CoachPlannedActivitySnapshot) -> String {
        [activity.icon, activity.imageName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
            .lowercased()
    }

    private static func tokenText(for activity: CoachPlannedActivitySnapshot) -> String {
        [primaryTokenText(for: activity), accessoryTokenText(for: activity)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    // MARK: - Legacy kind/load bridge (PR3 Phase B)
    //
    // `CoachActivityKind` / `CoachActivityLoad` remain for DayContext and DayPriorityModel.
    // Scenario routing uses `type` / `family` above.

    static func coachKind(for activity: CoachPlannedActivitySnapshot) -> CoachActivityKind {
        let title = activity.title.lowercased()
        let typeLabel = activity.type.lowercased()

        if typeLabel == "meal" ||
            title.contains("meal") ||
            title.contains("lunch") ||
            title.contains("dinner") {
            return .meal
        }

        if title.contains("sauna") ||
            typeLabel.contains("sauna") ||
            title.contains("hot yoga") ||
            typeLabel.contains("hot yoga") ||
            title.contains("heat") ||
            typeLabel.contains("heat") {
            return .heat
        }

        if containsAny(tokenText(for: activity), ["swim", "swimming"]) {
            return .endurance
        }

        switch type(for: activity) {
        case .cycling, .running:
            return .endurance
        case .tennis, .squash, .upperBody, .lowerBody, .core, .fullBody:
            return .workout
        case .walk, .stretching, .yoga, .breathing:
            return .recovery
        case .sauna:
            return .heat
        case .none:
            if typeLabel.contains("recovery") || title.contains("recovery") {
                return .recovery
            }
            return .other
        }
    }

    static func coachLoad(for activity: CoachPlannedActivitySnapshot) -> CoachActivityLoad {
        let title = activity.title.lowercased()
        let typeLabel = activity.type.lowercased()
        let duration = activity.durationMinutes
        let calories = activityCalories(for: activity)

        if duration >= 180 || calories >= 1800 {
            return .extreme
        }

        if duration >= 120 || calories >= 1000 {
            return .high
        }

        if CoachActivityClassification.isWalkLike(activity) {
            return calories >= 600 ? .moderate : .low
        }

        if CoachActivityClassification.isHikeLike(activity) {
            if duration >= 180 || calories >= 1000 { return .moderate }
            return .low
        }

        if title.contains("walk") || typeLabel.contains("walk") {
            return duration >= 90 || calories >= 500 ? .moderate : .low
        }

        if title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("ride") ||
            title.contains("run") ||
            typeLabel.contains("cycling") ||
            typeLabel.contains("run") {

            if duration >= 120 || calories >= 1000 { return .high }
            if duration >= 60 || calories >= 400 { return .moderate }
            return .low
        }

        if title.contains("strength") ||
            title.contains("gym") ||
            title.contains("hiit") ||
            title.contains("workout") ||
            typeLabel.contains("strength") ||
            typeLabel.contains("gym") ||
            typeLabel.contains("hiit") ||
            typeLabel.contains("workout") {

            if duration >= 90 || calories >= 700 { return .high }
            return .moderate
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            title.contains("recovery") ||
            title.contains("breath") ||
            typeLabel.contains("breath") {
            return .low
        }

        return .moderate
    }

    static func activityCalories(for activity: CoachPlannedActivitySnapshot) -> Int {
        max(activity.calories, 0)
    }
}
