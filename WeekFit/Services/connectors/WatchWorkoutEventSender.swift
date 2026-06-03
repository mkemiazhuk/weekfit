import Foundation
import WatchConnectivity
import HealthKit

final class WatchWorkoutEventSender: NSObject {

    static let shared = WatchWorkoutEventSender()

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendStarted(
        workoutType: HKWorkoutActivityType,
        startedAt: Date
    ) {
        send(
            WatchWorkoutMessage.make(
                event: .workoutStarted,
                workoutType: workoutType,
                startedAt: startedAt
            )
        )
    }

    func sendPaused(
        workoutType: HKWorkoutActivityType,
        startedAt: Date
    ) {
        send(
            WatchWorkoutMessage.make(
                event: .workoutPaused,
                workoutType: workoutType,
                startedAt: startedAt
            )
        )
    }

    func sendResumed(
        workoutType: HKWorkoutActivityType,
        startedAt: Date
    ) {
        send(
            WatchWorkoutMessage.make(
                event: .workoutResumed,
                workoutType: workoutType,
                startedAt: startedAt
            )
        )
    }

    func sendEnded(
        workoutType: HKWorkoutActivityType,
        startedAt: Date,
        endedAt: Date
    ) {
        send(
            WatchWorkoutMessage.make(
                event: .workoutEnded,
                workoutType: workoutType,
                startedAt: startedAt,
                endedAt: endedAt
            )
        )
    }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default

        guard session.activationState == .activated else {
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        }

        do {
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to update application context:", error)
        }
    }
}

extension WatchWorkoutEventSender: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
#endif

#if os(watchOS)
    func sessionReachabilityDidChange(_ session: WCSession) {}
#endif
}
