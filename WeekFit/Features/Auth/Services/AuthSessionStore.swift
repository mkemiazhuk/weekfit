import Foundation

enum AuthSessionStore {
    private static let appleUserIDKey = "weekfit.auth.appleUserID"
    private static let localSessionKey = "weekfit.auth.localSessionActive"

    static var appleUserID: String? {
        get { UserDefaults.standard.string(forKey: appleUserIDKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: appleUserIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: appleUserIDKey)
            }
        }
    }

    static var hasPersistedAppleSession: Bool {
        guard let appleUserID else { return false }
        return !appleUserID.isEmpty
    }

    /// Device-local session without Apple / email (Open WeekFit).
    static var hasLocalSession: Bool {
        UserDefaults.standard.bool(forKey: localSessionKey)
    }

    static func markLocalSessionActive() {
        UserDefaults.standard.set(true, forKey: localSessionKey)
    }

    static func clearLocalSession() {
        UserDefaults.standard.removeObject(forKey: localSessionKey)
    }

    static func clear() {
        appleUserID = nil
        clearLocalSession()
    }
}
