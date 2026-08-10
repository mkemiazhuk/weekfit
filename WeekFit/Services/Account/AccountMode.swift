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

    /// Resolves store/mode from **app entry**, not Apple authentication.
    /// Unauthenticated local users who have entered WeekFit still use `.realUser` (production SQLite).
    static func resolve(hasEnteredWeekFit: Bool) -> AccountMode {
        guard hasEnteredWeekFit else { return .unauthenticated }
        if AppReviewDemoCredentials.hasActiveSession {
            return .reviewDemo
        }
        return .realUser
    }

    /// Legacy alias — `isLoggedIn` historically meant “in the app”, not Apple-authenticated.
    static func resolve(isLoggedIn: Bool) -> AccountMode {
        resolve(hasEnteredWeekFit: isLoggedIn)
    }
}
