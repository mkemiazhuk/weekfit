import Foundation

enum CoachActivityStage {
    case before
    case during
    case after
    case stable
}

enum CoachActivityArchetype {
    case performance
    case endurance
    case recovery
    case heat
    case meal
    case stable
}

enum CoachDayTime {
    case morning
    case preLunch
    case lunch
    case afternoon
    case evening
    case lateEvening
    case night
}

enum CoachDurationBucket {
    case under30
    case thirtyTo60
    case sixtyTo90
    case over90
}

struct CoachActivityScenario {
    let stage: CoachActivityStage
    let archetype: CoachActivityArchetype

    let kind: CoachActivityKindV3
    let load: CoachActivityLoadV3
    let durationBucket: CoachDurationBucket
    let dayTime: CoachDayTime

    let activity: PlannedActivity?
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?
}
