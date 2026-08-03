import Foundation

/// One chronologic beat in the morning proposal day picture.
struct MorningProposalDayMoment: Equatable, Identifiable, Sendable {
    let id: String
    let timeLabel: String
    let title: String
    let systemImage: String
    let isRecommended: Bool
}
