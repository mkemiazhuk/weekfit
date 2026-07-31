import Foundation

enum MorningProposalChromeState: Equatable, Sendable {
    case hidden
    case gathering
    case proposalReady(changeCount: Int, guidanceCount: Int)
    case noChangesNeeded
    case applied
    case stale
    case unavailable
    case failed
}

enum MorningProposalPresenter {

    static func chromeState(for proposal: MorningPlanProposal?) -> MorningProposalChromeState {
        guard let proposal else { return .hidden }

        switch proposal.status {
        case .gatheringData:
            return .gathering
        case .proposalReady, .reviewing:
            let mutating = proposal.changes.filter { $0.kind != .guidanceOnly }.count
            let guidance = proposal.changes.filter { $0.kind == .guidanceOnly }.count
            return .proposalReady(changeCount: mutating, guidanceCount: guidance)
        case .noChangesNeeded:
            return .noChangesNeeded
        case .applied:
            return .applied
        case .stale:
            return .stale
        case .unavailable, .dismissed, .expired:
            return proposal.status == .unavailable ? .unavailable : .hidden
        case .applying:
            return .gathering
        case .failed:
            return .failed
        }
    }

    static var acknowledgmentShownKeyPrefix: String { "coach.appliedAckShown." }

    static func shouldShowAppliedAcknowledgment(dayKey: String) -> Bool {
        !UserDefaults.standard.bool(forKey: acknowledgmentShownKeyPrefix + dayKey)
    }

    static func markAppliedAcknowledgmentShown(dayKey: String) {
        UserDefaults.standard.set(true, forKey: acknowledgmentShownKeyPrefix + dayKey)
    }
}
