import Foundation

/// Release workspace-isolation policy for the shared single SQLite / SwiftData store.
///
/// # Principle
/// Data belongs to the workspace where it was created. Do **not** implicitly share
/// or migrate data between Local and Apple identities.
///
/// # Release architecture (single `default.store`)
/// Isolation is enforced by wiping the shared store when the active workspace owner
/// changes. This is a deliberate release-hardening fallback — not the long-term model.
///
/// | Transition | Behavior |
/// |---|---|
/// | Fresh Local | Empty local workspace |
/// | Local → Apple A | Wipe local; open clean Apple A (requires user confirmation) |
/// | Apple A → Open WeekFit (Local) | Wipe Apple A from the shared store; open clean Local |
/// | Apple A → Apple B | Wipe Apple A; open clean Apple B |
/// | Apple A → Sign Out → Sign in Apple A | **Keep** data: owner marker stays `apple:<id>` while on welcome |
/// | Apple A → Sign Out → Open WeekFit → Sign in Apple A | Apple A data was wiped for Local; Apple A starts clean |
/// | Delete Account Apple A | Full wipe + identity clear |
/// | Reset Local Data | Wipe **current** workspace only; auth/entry unchanged |
///
/// # Limitation
/// One on-disk store cannot retain Local and Apple A (or Apple A and Apple B)
/// simultaneously. Switching to another workspace destroys the previous one's
/// on-device data. Per-identity databases are the long-term fix
/// (see `docs/persistence-sqlite-data-migration-plan.md`).
enum WorkspaceIsolationPolicy {
    /// True when Sign in with Apple would replace the current **local** workspace.
    static func signingInWithAppleWouldReplaceLocalWorkspace(
        ownerID: String? = WorkspaceOwnerStore.ownerID
    ) -> Bool {
        guard let ownerID else { return false }
        return WorkspaceOwnerStore.isLocalCompatibleOwner(ownerID)
    }

    /// True when Open WeekFit (local entry) would replace an **Apple** workspace
    /// still bound to the shared store (typical after Sign Out).
    static func openingLocalWouldReplaceAppleWorkspace(
        ownerID: String? = WorkspaceOwnerStore.ownerID
    ) -> Bool {
        guard let ownerID else { return false }
        return WorkspaceOwnerStore.isAppleOwner(ownerID)
    }
}
