import Foundation
import WeekFitPlanner

struct MorningProposalGateInput: Sendable, Equatable {
    let now: Date
    let dayRolloverCompleted: Bool
    let healthRefreshCompleted: Bool
    let healthRefreshTimedOut: Bool
    let isHealthAccessGranted: Bool
    let sleepHours: Double
    let recoveryDataAvailable: Bool
    let todayPlanLoaded: Bool
    let tomorrowPlanLoaded: Bool
    let yesterdayContextLoaded: Bool
    let isMorningWindow: Bool
    let hasCompletedPlannedItemToday: Bool
    let existingStatus: CoachProposalStatus?
}

enum MorningProposalGateDecision: Sendable, Equatable {
    case gatheringData
    case allowGeneration
    case unavailable(reason: String)
    case keepExisting(CoachProposalStatus)
}

enum MorningProposalGate {

    static let healthTimeoutSeconds: TimeInterval = 8

    static func decide(input: MorningProposalGateInput) -> MorningProposalGateDecision {
        if let existing = input.existingStatus {
            switch existing {
            case .applied, .dismissed, .expired:
                return .keepExisting(existing)
            case .applying:
                return .keepExisting(.applying)
            default:
                break
            }
        }

        guard input.dayRolloverCompleted else {
            return .gatheringData
        }

        guard input.isMorningWindow else {
            return .unavailable(reason: "outside_window")
        }

        if input.hasCompletedPlannedItemToday {
            if let existing = input.existingStatus, existing == .proposalReady || existing == .reviewing || existing == .stale {
                return .keepExisting(.expired)
            }
            return .unavailable(reason: "day_started")
        }

        guard input.todayPlanLoaded, input.tomorrowPlanLoaded, input.yesterdayContextLoaded else {
            return .gatheringData
        }

        if !input.healthRefreshCompleted && !input.healthRefreshTimedOut {
            return .gatheringData
        }

        if !input.isHealthAccessGranted && !input.healthRefreshTimedOut {
            // Still allow generation path — engine will restrict to guidance/unavailable.
            return .allowGeneration
        }

        return .allowGeneration
    }

    static func sleepPresence(from input: MorningProposalGateInput) -> ProposalSleepPresenceToken {
        ProposalInputFingerprintBuilder.sleepPresence(
            sleepHours: input.sleepHours,
            recoveryDataAvailable: input.recoveryDataAvailable,
            timedOutWithoutSleep: input.healthRefreshTimedOut && input.sleepHours <= 0
        )
    }
}
