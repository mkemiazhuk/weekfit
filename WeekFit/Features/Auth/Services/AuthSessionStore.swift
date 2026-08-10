import Foundation

enum AuthSessionStore {
    private static let appleUserIDKey = "weekfit.auth.appleUserID"
    /// Persisted app-entry flag (legacy key name kept for upgrade compatibility).
    private static let enteredWeekFitKey = "weekfit.auth.localSessionActive"

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

    /// User has entered the local WeekFit experience (welcome “Open WeekFit” or prior local use).
    /// This is **not** authentication — the app is fully usable while unauthenticated.
    static var hasEnteredWeekFit: Bool {
        UserDefaults.standard.bool(forKey: enteredWeekFitKey)
    }

    static func markWeekFitEntered() {
        UserDefaults.standard.set(true, forKey: enteredWeekFitKey)
    }

    static func clearWeekFitEntry() {
        UserDefaults.standard.removeObject(forKey: enteredWeekFitKey)
    }

    /// Clears Apple identity/session only. Preserves app-entry so Sign Out stays inside WeekFit.
    static func clearAppleSession() {
        appleUserID = nil
    }

    /// Full clear used by Delete Account / hard reset of auth artifacts.
    static func clear() {
        appleUserID = nil
        clearWeekFitEntry()
        WorkspaceOwnerStore.clearGuestToken()
    }
}
