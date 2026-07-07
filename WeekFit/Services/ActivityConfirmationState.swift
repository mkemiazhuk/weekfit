import Foundation
internal import Combine

final class ActivityConfirmationState: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = ActivityConfirmationState()

    @Published var pendingActivity: PlannedActivity?
}
