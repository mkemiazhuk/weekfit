import Foundation
internal import Combine

/// Pending open for Plan Add Activity (e.g. Today empty “Your plan” row).
@MainActor
final class PendingPlanAddOpen: ObservableObject {
    nonisolated deinit {}

    static let shared = PendingPlanAddOpen()

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
