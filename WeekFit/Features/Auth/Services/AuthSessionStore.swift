import Foundation

enum AuthSessionStore {
    private static let appleUserIDKey = "weekfit.auth.appleUserID"

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

    static func clear() {
        appleUserID = nil
    }
}
