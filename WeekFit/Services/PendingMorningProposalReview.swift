import Foundation
internal import Combine

/// Shared flag so a morning-plan-check notification tap can open Proposal Review on Today.
@MainActor
final class PendingMorningProposalReview: ObservableObject {

    nonisolated deinit {}

    static let shared = PendingMorningProposalReview()

    @Published private(set) var shouldOpenReview = false
    private(set) var dayKey: String?

    private init() {}

    func requestOpen(dayKey: String?) {
        self.dayKey = dayKey
        shouldOpenReview = true
    }

    @discardableResult
    func consume() -> Bool {
        guard shouldOpenReview else { return false }
        shouldOpenReview = false
        return true
    }

    func resetForTests() {
        shouldOpenReview = false
        dayKey = nil
    }
}
