import Foundation

/// Fixed reviewer credentials supplied in App Store Connect → App Review Information.
enum AppReviewDemoCredentials {
    static let email = "review@weekfit.app"
    static let password = "review_passw0rd"

    static func matches(email: String, password: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Self.email.lowercased()
            && password == Self.password
    }

    static var hasActiveSession: Bool {
        UserDefaults.standard.bool(forKey: AppReviewDemoStore.sessionActiveKey)
    }

    static func markSessionActive() {
        UserDefaults.standard.set(true, forKey: AppReviewDemoStore.sessionActiveKey)
    }

    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: AppReviewDemoStore.sessionActiveKey)
    }
}
