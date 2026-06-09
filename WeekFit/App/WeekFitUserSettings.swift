import Foundation
internal import Combine

@MainActor
final class WeekFitUserSettings: ObservableObject {
    static let shared = WeekFitUserSettings()

    @Published private(set) var profileInitials: String
    @Published private(set) var customMealsStorage: String

    private init() {
        ProfileService.migrateProfileStorageIfNeeded()
        profileInitials = ProfileService.resolvedInitials()
        customMealsStorage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""
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
}
