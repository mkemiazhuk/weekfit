import Foundation
internal import Combine

@MainActor
final class WeekFitUserSettings: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}
    static let shared = WeekFitUserSettings()

    /// Stable identity for correlating duplicate startup logs (same UUID = same singleton).
    let instanceID = UUID()

    @Published private(set) var profileInitials: String
    /// True once the user has saved a non-empty profile name.
    @Published private(set) var hasProfileName: Bool
    /// Legacy JSON blob kept for disk persistence and AppStorage compatibility.
    @Published private(set) var customMealsStorage: String
    /// Single in-memory catalog — observers must not JSON-decode on save.
    @Published private(set) var customMealsCatalog: [Meals] = []
    @Published private(set) var customMealsCatalogRevision: UInt = 0

    private var customMealsPersistGeneration: UInt = 0

    private init() {
        let id = instanceID.uuidString.prefix(8)
        TodayStartupDiagnostics.child(
            "WeekFitUserSettings.shared.init begin",
            detail: "instance=\(id)"
        )
        ProfileService.migrateProfileStorageIfNeeded()
        profileInitials = ProfileService.resolvedInitials()
        hasProfileName = !ProfileService.resolvedFullName().isEmpty
        let storage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""
        customMealsStorage = storage
        customMealsCatalog = CustomMealStore.load(from: storage)
        // Intentionally no meal seed here — init can be triggered by SwiftUI `@StateObject`
        // during body evaluation. Destructive catalog work runs via `ensureMealLibrarySeeded()`.
        TodayStartupDiagnostics.child(
            "WeekFitUserSettings.shared.init complete",
            detail: "instance=\(id) customMealsCatalogCount=\(customMealsCatalog.count) initials=\(profileInitials) seededFlag=\(UserDefaults.standard.bool(forKey: DefaultMealLibrarySeeder.seededKey))"
        )
    }

    /// Idempotent starter-library ensure. Safe to call from multiple launch paths.
    @discardableResult
    func ensureMealLibrarySeeded() -> Bool {
        DefaultMealLibrarySeeder.seedIfNeeded(settings: self)
    }

    func refreshFromStorage() {
        ProfileService.migrateProfileStorageIfNeeded()
        let nextInitials = ProfileService.resolvedInitials()
        let nextHasProfileName = !ProfileService.resolvedFullName().isEmpty
        let nextCustomMealsStorage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""

        if profileInitials != nextInitials {
            profileInitials = nextInitials
        }

        if hasProfileName != nextHasProfileName {
            hasProfileName = nextHasProfileName
        }

        if customMealsStorage != nextCustomMealsStorage {
            customMealsStorage = nextCustomMealsStorage
            customMealsCatalog = CustomMealStore.load(from: nextCustomMealsStorage)
            customMealsCatalogRevision &+= 1
        }

        ensureMealLibrarySeeded()
    }

    func setProfileInitials(_ value: String) {
        let nextInitials = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedInitials = nextInitials.isEmpty ? "P" : nextInitials
        UserDefaults.standard.set(resolvedInitials, forKey: ProfileService.Keys.initials)

        guard profileInitials != resolvedInitials else { return }
        profileInitials = resolvedInitials
    }

    /// Updates avatar initials + name presence for all tab headers observing this object.
    func applyProfileIdentity(initials: String, hasProfileName: Bool) {
        let nextInitials = initials.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedInitials = nextInitials.isEmpty ? "P" : nextInitials
        UserDefaults.standard.set(resolvedInitials, forKey: ProfileService.Keys.initials)

        if profileInitials != resolvedInitials {
            profileInitials = resolvedInitials
        }
        if self.hasProfileName != hasProfileName {
            self.hasProfileName = hasProfileName
        }
    }

    func setCustomMealsStorage(_ value: String) {
        guard customMealsStorage != value else { return }
        customMealsStorage = value
        UserDefaults.standard.set(value, forKey: CustomMealStore.storageKey)
    }

    /// Updates the shared catalog and persists to disk without forcing JSON re-decode in tabs.
    func replaceCustomMealsCatalog(_ meals: [Meals]) {
        guard customMealsCatalog != meals else { return }
        customMealsCatalog = meals
        customMealsCatalogRevision &+= 1
        persistCustomMealsCatalogToDisk(meals)
        #if DEBUG
        MealMemoryAudit.checkpoint("UserSettings.replaceCustomMealsCatalog count=\(meals.count)")
        #endif
    }

    private func persistCustomMealsCatalogToDisk(_ meals: [Meals]) {
        customMealsPersistGeneration &+= 1
        let generation = customMealsPersistGeneration

        Task.detached(priority: .utility) {
            let encoded = CustomMealStore.encode(meals)
            await MainActor.run { [encoded] in
                guard generation == self.customMealsPersistGeneration else { return }
                UserDefaults.standard.set(encoded, forKey: CustomMealStore.storageKey)
                if self.customMealsStorage != encoded {
                    self.customMealsStorage = encoded
                }
            }
        }
    }
}
