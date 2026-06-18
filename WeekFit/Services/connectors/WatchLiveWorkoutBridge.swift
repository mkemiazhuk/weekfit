import Foundation
import WatchConnectivity
import HealthKit
internal import Combine

@MainActor
final class WatchLiveWorkoutBridge: NSObject, ObservableObject {

    static let shared = WatchLiveWorkoutBridge()

    @Published private(set) var liveWorkout: WeekFitLiveWorkout?

    private override init() {
        super.init()
    }

    func start() {
        WatchConnectivitySupport.activateSession(delegate: self)
    }

    private func handle(_ message: [String: Any]) {
        guard
            let rawType = message[WatchWorkoutMessage.typeKey] as? String,
            let event = WatchWorkoutMessage.Event(rawValue: rawType),
            let startedAtRaw = message[WatchWorkoutMessage.startedAtKey] as? TimeInterval
        else {
            return
        }

        let workoutRawValue: UInt?

        if let value = message[WatchWorkoutMessage.workoutTypeKey] as? Int {
            workoutRawValue = UInt(value)
        } else if let value = message[WatchWorkoutMessage.workoutTypeKey] as? UInt {
            workoutRawValue = value
        } else if let value = message[WatchWorkoutMessage.workoutTypeKey] as? NSNumber {
            workoutRawValue = value.uintValue
        } else {
            workoutRawValue = nil
        }

        guard
            let workoutRawValue,
            let workoutType = HKWorkoutActivityType(rawValue: workoutRawValue)
        else {
            return
        }

        let startedAt = Date(timeIntervalSince1970: startedAtRaw)

        switch event {
        case .workoutStarted:
            liveWorkout = WeekFitLiveWorkout(
                id: UUID(),
                workoutType: workoutType,
                startedAt: startedAt,
                endedAt: nil,
                state: .active,
                source: .appleWatch
            )

        case .workoutPaused:
            guard var current = liveWorkout else { return }
            current.state = .paused
            liveWorkout = current

        case .workoutResumed:
            guard var current = liveWorkout else { return }
            current.state = .active
            liveWorkout = current

        case .workoutEnded:
            guard var current = liveWorkout else {
                liveWorkout = nil
                return
            }

            let endedAtRaw = message[WatchWorkoutMessage.endedAtKey] as? TimeInterval
            current.endedAt = endedAtRaw.map { Date(timeIntervalSince1970: $0) } ?? Date()
            current.state = .ended
            liveWorkout = current

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.liveWorkout?.state == .ended {
                    self?.liveWorkout = nil
                }
            }
        }
    }
}

extension WatchLiveWorkoutBridge: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any]
    ) {
        Task { @MainActor in
            self.handle(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        Task { @MainActor in
            self.handle(applicationContext)
        }
    }
}
