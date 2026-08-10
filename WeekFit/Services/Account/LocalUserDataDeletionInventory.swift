import Foundation

/// Single inventory of user-scoped local artifacts that must be cleared on
/// account deletion / hard workspace wipe. Keep this list complete — new stores
/// must be registered here.
enum LocalUserDataDeletionInventory {
    /// Clears durable caches that survive a UserDefaults domain wipe but are still
    /// workspace-scoped (shared between local entry and Apple account if left alone).
    /// Does **not** clear AppleIdentity — that stays for the signing-in Apple user.
    @MainActor
    static func clearWorkspaceScopedArtifacts() async {
        await BarcodeProductCache.shared.clearAll()
        NightComfortLocationService.clearCachedLocation()
        ActivityNotificationService.shared.cancelAllNotifications()
        WellnessNotificationService.shared.cancelAll()
        MorningProposalNotificationService.shared.cancelAll()
    }

    /// Clears durable identity / cache artifacts that survive UserDefaults domain wipes.
    /// Used by Delete Account (includes AppleIdentity Keychain/disk).
    @MainActor
    static func clearDurableArtifacts() async {
        AppleIdentityStore.clearAllPersistedIdentities()
        await clearWorkspaceScopedArtifacts()
        WorkspaceOwnerStore.clearOwner()
        WorkspaceOwnerStore.clearGuestToken()
    }
}
