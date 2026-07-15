import Foundation
internal import Combine

@MainActor
final class AppReviewDemoActivation: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = AppReviewDemoActivation()

    @Published private(set) var shouldEnableOnNextRootAppear = false

    private init() {}

    func markPendingEnableFromCredentialLogin() {
        shouldEnableOnNextRootAppear = true
    }

    func consumePendingEnableRequest() -> Bool {
        guard shouldEnableOnNextRootAppear else { return false }
        shouldEnableOnNextRootAppear = false
        return true
    }

    func resetForTests() {
        shouldEnableOnNextRootAppear = false
    }
}
