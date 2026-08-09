import Foundation
import HealthKit

struct WeekFitLiveWorkout: Identifiable, Equatable {
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startedAt: Date
    var endedAt: Date?
    var state: State
    let source: Source
    /// Latest BPM from HealthKit while the session is live (phone-side stream).
    var currentHeartRateBPM: Int? = nil
    /// Zone 1…5 matching `HeartRateZones` (nil when no fresh sample).
    var heartRateZone: Int? = nil

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
