import Foundation
import WeekFitPlanner

// MARK: - Activity taxonomy

enum CoachV6ActivityFamily: String, CaseIterable, Equatable, Sendable {
    case endurance
    case racket
    case strength
    case recovery
    case heat
    case none
}

enum CoachV6ActivityType: String, CaseIterable, Equatable, Sendable {
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

enum CoachV6ActivityState: String, Equatable, Sendable {
    case none
    case upcoming
    case active
    case justFinished
    case finished
}

enum CoachV6SessionPhase: String, CaseIterable, Equatable, Sendable {
    case pre
    case during
    case immediatePost
    case settledPost
    case evening
    case tomorrowProtection
    case idle
}

enum CoachV6DurationBand: String, Equatable, Sendable {
    case short
    case medium
    case long
    case extended

    static func from(minutes: Int) -> CoachV6DurationBand {
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

enum CoachV6DayLoadBand: String, CaseIterable, Equatable, Sendable {
    case fresh
    case moderate
    case heavy
    case extreme
}

enum CoachV6CompletedSeriousActivities: Equatable, Sendable {
    case none
    case one
    case twoOrMore
}

enum CoachV6FuelState: String, Equatable, Sendable {
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

enum CoachV6HydrationState: String, Equatable, Sendable {
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

enum CoachV6TomorrowDemand: String, Equatable, Sendable {
    case none
    case easy
    case moderate
    case hard
}

/// Tomorrow's primary planned training — for copy only, not scenario selection.
struct CoachV6TomorrowWorkout: Equatable, Sendable {
    let title: String
    let startHour: Int
    let startMinute: Int
    let durationMinutes: Int

    var formattedStartTime: String {
        String(format: "%d:%02d", startHour, startMinute)
    }
}

enum CoachV6TimeOfDay: String, Equatable, Sendable {
    case morning
    case midday
    case afternoon
    case evening
    case lateEvening
    case night

    static func from(hour: Int) -> CoachV6TimeOfDay {
        switch hour {
        case 5..<10:
            return .morning
        case 10..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        case 21..<24:
            return .lateEvening
        default:
            return .night
        }
    }
}

// MARK: - Context

/// Facts-only snapshot for CoachV6 scenario resolution.
/// No narrative, owners, or copy — only telemetry and schedule state.
struct CoachV6Context: Equatable, Sendable {
    let activityFamily: CoachV6ActivityFamily
    let activityType: CoachV6ActivityType
    let activityState: CoachV6ActivityState
    let sessionPhase: CoachV6SessionPhase
    let durationBand: CoachV6DurationBand
    let dayLoadBand: CoachV6DayLoadBand
    let completedSeriousActivities: CoachV6CompletedSeriousActivities
    let fuelState: CoachV6FuelState
    let hydrationState: CoachV6HydrationState
    let tomorrowDemand: CoachV6TomorrowDemand
    let timeOfDay: CoachV6TimeOfDay
    let tomorrowWorkout: CoachV6TomorrowWorkout?

    let focusActivityID: String?
    let focusSource: CoachV6FocusSource
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?
    let dayReadiness: CoachV6DayReadiness
}

// MARK: - Activity classification

enum CoachV6ActivityClassifier {

    static func family(for activity: PlannedActivity) -> CoachV6ActivityFamily {
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

    static func type(for activity: PlannedActivity) -> CoachV6ActivityType {
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

    private static func classifyType(in text: String) -> CoachV6ActivityType? {
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

    static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
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

    private static func inferredLoad(for activity: PlannedActivity) -> CoachV6DayLoadBand {
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

    private static func primaryTokenText(for activity: PlannedActivity) -> String {
        [activity.type, activity.title]
            .joined(separator: " ")
            .lowercased()
    }

    private static func accessoryTokenText(for activity: PlannedActivity) -> String {
        [activity.icon, activity.imageName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
            .lowercased()
    }

    private static func tokenText(for activity: PlannedActivity) -> String {
        [primaryTokenText(for: activity), accessoryTokenText(for: activity)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
