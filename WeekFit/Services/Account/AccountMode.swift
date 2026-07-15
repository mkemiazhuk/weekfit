import Foundation

/// Single source of truth for whether the active session uses review demo data or real user data.
enum AccountMode: Equatable {
    case unauthenticated
    case realUser
    case reviewDemo

    var usesReviewDemoData: Bool {
        self == .reviewDemo
    }

    var usesProductionSwiftDataStore: Bool {
        self != .reviewDemo
    }

    /// Review demo is keyed exclusively to the App Review credential session flag.
    static func resolve(isLoggedIn: Bool) -> AccountMode {
        guard isLoggedIn else { return .unauthenticated }
        if AppReviewDemoCredentials.hasActiveSession {
            return .reviewDemo
        }
        return .realUser
    }
}
