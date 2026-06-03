import Foundation
import HealthKit

struct WatchWorkoutMessage {

    static let typeKey = "type"
    static let workoutTypeKey = "workoutType"
    static let startedAtKey = "startedAt"
    static let endedAtKey = "endedAt"

    enum Event: String {
        case workoutStarted
        case workoutPaused
        case workoutResumed
        case workoutEnded
    }

    static func make(
        event: Event,
        workoutType: HKWorkoutActivityType,
        startedAt: Date,
        endedAt: Date? = nil
    ) -> [String: Any] {
        var payload: [String: Any] = [
            typeKey: event.rawValue,
            workoutTypeKey: Int(workoutType.rawValue),
            startedAtKey: startedAt.timeIntervalSince1970
        ]

        if let endedAt {
            payload[endedAtKey] = endedAt.timeIntervalSince1970
        }

        return payload
    }
}
