import Foundation
import SwiftData
internal import Combine

@MainActor
final class AccountSessionController: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = AccountSessionController()

    @Published private(set) var mode: AccountMode = .unauthenticated
    @Published private(set) var isTransitioning = false

    /// When true, the next transition into `.realUser` wipes local WeekFit data first.
    /// Used after Create Account so a new identity never inherits the previous user's store.
    private(set) var shouldResetLocalDataOnNextRealUserEntry = false

    var activeContainer: ModelContainer {
        switch mode {
        case .reviewDemo:
            return WeekFitModelContainer.reviewDemo
        case .realUser, .unauthenticated:
            return WeekFitModelContainer.production
        }
    }

    var containerIdentity: String {
        switch mode {
        case .reviewDemo:
            return "swiftdata-review-demo"
        case .realUser, .unauthenticated:
            return "swiftdata-production"
        }
    }

    private init() {}

    func beginTransition() {
        isTransitioning = true
    }

    func endTransition() {
        isTransitioning = false
    }

    func setMode(_ newMode: AccountMode, reason: String) {
        guard mode != newMode else { return }
        mode = newMode
        AccountSessionDiagnostics.log(
            "Resolved account mode (\(reason))",
            mode: newMode,
            store: containerIdentity,
            accountKind: newMode == .reviewDemo ? "appReview" : (newMode == .realUser ? "realUser" : "none")
        )
    }

    func requestLocalDataResetOnNextRealUserEntry() {
        shouldResetLocalDataOnNextRealUserEntry = true
    }

    @discardableResult
    func consumeLocalDataResetOnNextRealUserEntry() -> Bool {
        guard shouldResetLocalDataOnNextRealUserEntry else { return false }
        shouldResetLocalDataOnNextRealUserEntry = false
        return true
    }

    func resetForTests() {
        mode = .unauthenticated
        isTransitioning = false
        shouldResetLocalDataOnNextRealUserEntry = false
    }
}
