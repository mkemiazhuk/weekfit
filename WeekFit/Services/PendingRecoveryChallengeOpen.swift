import Foundation
internal import Combine

/// Pending open for `weekfit://challenge/recovery7` (and App Store In-App Event deep links).
@MainActor
final class PendingRecoveryChallengeOpen: ObservableObject {
    nonisolated deinit {}

    static let shared = PendingRecoveryChallengeOpen()

    @Published private(set) var shouldOpen = false

    private init() {}

    func requestOpen() {
        shouldOpen = true
    }

    @discardableResult
    func consume() -> Bool {
        guard shouldOpen else { return false }
        shouldOpen = false
        return true
    }

    func resetForTests() {
        shouldOpen = false
    }
}
