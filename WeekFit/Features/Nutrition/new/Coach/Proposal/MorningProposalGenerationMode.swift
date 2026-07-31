import Foundation

/// Phase 1.5 planning mode — replaces the binary `todayOpen.count <= 1` full-day gate.
enum MorningProposalGenerationMode: String, Sendable, Equatable {
    case compose
    case optimize
    case protect
    case closed
}

enum MorningProposalGenerationModeResolver {

    static func resolve(
        openCount: Int,
        hasCompletedOrPartialToday: Bool,
        isMorningWindow: Bool
    ) -> MorningProposalGenerationMode {
        if hasCompletedOrPartialToday || !isMorningWindow {
            return .closed
        }
        switch openCount {
        case 0, 1:
            return .compose
        case 2, 3:
            return .optimize
        default:
            return .protect
        }
    }
}

enum ProposalStackedLoadToken: String, Codable, Sendable, Equatable {
    case unavailable
    case clear
    case elevated
}

extension ProposalStackedLoadToken {
    var isElevated: Bool { self == .elevated }
}
