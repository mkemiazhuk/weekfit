import Foundation
internal import Combine

@MainActor
final class WeekFitUserSettings: ObservableObject {
    static let shared = WeekFitUserSettings()

    @Published private(set) var profileInitials: String
    /// Legacy JSON blob kept for disk persistence and AppStorage compatibility.
    @Published private(set) var customMealsStorage: String
    /// Single in-memory catalog — observers must not JSON-decode on save.
    @Published private(set) var customMealsCatalog: [Meals] = []
    @Published private(set) var customMealsCatalogRevision: UInt = 0

    private init() {
        ProfileService.migrateProfileStorageIfNeeded()
        profileInitials = ProfileService.resolvedInitials()
        let storage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""
        customMealsStorage = storage
        customMealsCatalog = CustomMealStore.load(from: storage)
    }

    func refreshFromStorage() {
        ProfileService.migrateProfileStorageIfNeeded()
        let nextInitials = ProfileService.resolvedInitials()
        let nextCustomMealsStorage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""

        if profileInitials != nextInitials {
            profileInitials = nextInitials
        }

        if customMealsStorage != nextCustomMealsStorage {
            customMealsStorage = nextCustomMealsStorage
        }
    }

    func setProfileInitials(_ value: String) {
        let nextInitials = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedInitials = nextInitials.isEmpty ? "P" : nextInitials
        UserDefaults.standard.set(resolvedInitials, forKey: ProfileService.Keys.initials)

        guard profileInitials != resolvedInitials else { return }
        profileInitials = resolvedInitials
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
        Task.detached(priority: .utility) {
            let encoded = CustomMealStore.encode(meals)
            await MainActor.run { [encoded] in
                UserDefaults.standard.set(encoded, forKey: CustomMealStore.storageKey)
                if self.customMealsStorage != encoded {
                    self.customMealsStorage = encoded
                }
            }
        }
    }
}
