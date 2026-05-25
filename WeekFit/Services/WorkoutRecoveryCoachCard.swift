import SwiftUI

enum WorkoutRecoveryCoachState {
    case liveActivity
    case preActivity
    case laterToday
    case recovery
    case recentlyMissed
    case adjustedDay
    case movement
    case sleep
    case balanced
}

enum CoachDayPhase {
    case morning
    case afternoon
    case evening
    case night
}

struct WorkoutRecoveryCoachCard {
    let state: WorkoutRecoveryCoachState
    let title: String
    let action: String
    let message: String
    let focusActivity: PlannedActivity?
}
