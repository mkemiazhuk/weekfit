import Foundation
import HealthKit

struct WeekFitLiveWorkout: Identifiable, Equatable {
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startedAt: Date
    var endedAt: Date?
    var state: State
    let source: Source

    enum State: String, Codable {
        case active
        case paused
        case ended
    }

    enum Source: String, Codable {
        case appleWatch
        case healthKit
    }

    var isLive: Bool {
        state == .active || state == .paused
    }
}
