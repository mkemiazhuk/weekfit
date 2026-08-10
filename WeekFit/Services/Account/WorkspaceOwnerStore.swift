import Foundation

/// Persisted workspace owner for the shared production SwiftData + UserDefaults store.
///
/// Release constraint: there is still one on-disk store (`default.store`). Isolation is
/// enforced by wiping that store whenever the active identity changes between
/// local (no account) and Apple, or between different Apple IDs.
enum WorkspaceOwnerStore {
    static let ownerKey = "weekfit.workspace.ownerID"
    static let guestTokenKey = "weekfit.auth.guestToken"

    /// Stable owner for the on-device local (unauthenticated) workspace.
    static let localOwnerID = "local"

    /// `apple:<id>`, `local`, or legacy `guest:<uuid>` currently bound to the production workspace.
    static var ownerID: String? {
        get {
            let value = UserDefaults.standard.string(forKey: ownerKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: ownerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ownerKey)
            }
        }
    }

    static var guestToken: String? {
        get {
            let value = UserDefaults.standard.string(forKey: guestTokenKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: guestTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: guestTokenKey)
            }
        }
    }

    static func appleOwnerID(_ appleUserID: String) -> String {
        "apple:\(appleUserID)"
    }

    static func guestOwnerID(_ token: String) -> String {
        "guest:\(token)"
    }

    static func isAppleOwner(_ owner: String) -> Bool {
        owner.hasPrefix("apple:")
    }

    static func isLocalCompatibleOwner(_ owner: String) -> Bool {
        owner == localOwnerID || owner.hasPrefix("guest:")
    }

    /// Identity that should own the production workspace for the current entry state.
    /// Local (unauthenticated) users use the stable `local` owner — not a fake guest account.
    static func currentIdentityToken(
        appleUserID: String? = AuthSessionStore.appleUserID,
        hasEnteredWeekFit: Bool = AuthSessionStore.hasEnteredWeekFit
    ) -> String? {
        if let appleUserID, !appleUserID.isEmpty {
            return appleOwnerID(appleUserID)
        }
        if hasEnteredWeekFit {
            return localOwnerID
        }
        return nil
    }

    /// Prefer claiming the existing local/guest workspace as `local` without reminting.
    /// After Sign Out we keep an Apple owner marker so the **same** Apple identity can
    /// return from welcome without wiping. Entering as local while that marker remains
    /// still triggers `requiresWorkspaceReset` (Apple → local).
    static func ensureLocalOwnerClaim() {
        clearGuestToken()
        if let owner = ownerID, isAppleOwner(owner) {
            return
        }
        ownerID = localOwnerID
    }

    static func clearGuestToken() {
        guestToken = nil
    }

    static func clearOwner() {
        ownerID = nil
    }

    /// True when the incoming session must not inherit the current workspace contents.
    ///
    /// Destructive for:
    /// - local/guest → Apple (no anonymous plan/meals into an account)
    /// - Apple → local (no account plan/meals into Open WeekFit)
    /// - Apple A → Apple B
    static func requiresWorkspaceReset(forIncomingIdentity incoming: String?) -> Bool {
        guard let incoming, !incoming.isEmpty else { return false }
        guard let owner = ownerID else {
            // Pre-isolation installs have no owner marker — claim the orphaned workspace
            // for the current identity without wiping (preserves upgrade data).
            return false
        }
        if owner == incoming { return false }

        let ownerIsApple = isAppleOwner(owner)
        let incomingIsApple = isAppleOwner(incoming)
        let ownerIsLocal = isLocalCompatibleOwner(owner)
        let incomingIsLocal = isLocalCompatibleOwner(incoming) || incoming == localOwnerID

        // Local/guest → Apple: Apple account must not inherit anonymous workspace.
        if ownerIsLocal && incomingIsApple { return true }
        // Apple → local (Open WeekFit after Sign Out): local must not inherit account workspace.
        if ownerIsApple && incomingIsLocal { return true }
        // Local ↔ legacy guest / local: same device workspace.
        if ownerIsLocal && incomingIsLocal { return false }

        // Apple A → Apple B is a hard identity switch on one shared store.
        if ownerIsApple && incomingIsApple { return true }

        return owner != incoming
    }
}
