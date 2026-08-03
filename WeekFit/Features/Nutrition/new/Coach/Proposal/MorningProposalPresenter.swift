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
        case .gatheringData, .applying:
            // Stay silent until we have a confident proposal — no “gathering” chrome.
            return .hidden
        case .proposalReady, .reviewing:
            guard hasConfidentProposal(proposal) else { return .hidden }
            let mutating = proposal.changes.filter { $0.kind != .guidanceOnly }.count
            let guidance = proposal.changes.filter { $0.kind == .guidanceOnly }.count
            return .proposalReady(changeCount: mutating, guidanceCount: guidance)
        case .noChangesNeeded, .failed, .stale, .unavailable:
            return .hidden
        case .applied:
            return .applied
        case .dismissed, .expired:
            return .hidden
        }
    }

    /// Today overlay only when there is a concrete proposal — not soft cold-start tips
    /// like “learning your patterns.”
    static func hasConfidentProposal(_ proposal: MorningPlanProposal) -> Bool {
        let mutating = proposal.changes.filter { $0.kind != .guidanceOnly }
        if !mutating.isEmpty { return true }

        let hasActionableGuidance = proposal.changes.contains { change in
            guard change.kind == .guidanceOnly,
                  case .guidanceOnly(let payload) = change.payload else { return false }
            switch payload.guidanceCode {
            case .morningFuelWithoutLibrary,
                 .morningFuelGentleRecovery,
                 .morningFuelSteadyEnergy,
                 .preferIndoorOrEarlier,
                 .easeOutdoorHeat,
                 .shelteredRoutesWind,
                 .warmUpInCold:
                return true
            default:
                return false
            }
        }
        return hasActionableGuidance
    }

    static var acknowledgmentShownKeyPrefix: String { "coach.appliedAckShown." }

    static func shouldShowAppliedAcknowledgment(dayKey: String) -> Bool {
        !UserDefaults.standard.bool(forKey: acknowledgmentShownKeyPrefix + dayKey)
    }

    static func markAppliedAcknowledgmentShown(dayKey: String) {
        UserDefaults.standard.set(true, forKey: acknowledgmentShownKeyPrefix + dayKey)
    }

    static func resetAppliedAcknowledgmentShownForTests(dayKey: String) {
        UserDefaults.standard.removeObject(forKey: acknowledgmentShownKeyPrefix + dayKey)
    }
}
