import Foundation
internal import Combine

@MainActor
final class WeekFitUserSettings: ObservableObject {
    static let shared = WeekFitUserSettings()

    @Published private(set) var profileInitials: String
    @Published private(set) var customMealsStorage: String

    private init() {
        profileInitials = UserDefaults.standard.string(forKey: ProfileService.Keys.initials) ?? "P"
        customMealsStorage = UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? ""
    }

    func refreshFromStorage() {
        setProfileInitials(UserDefaults.standard.string(forKey: ProfileService.Keys.initials) ?? "P")
        setCustomMealsStorage(UserDefaults.standard.string(forKey: CustomMealStore.storageKey) ?? "")
    }

    func setProfileInitials(_ value: String) {
        guard profileInitials != value else { return }
        profileInitials = value
    }

    func setCustomMealsStorage(_ value: String) {
        guard customMealsStorage != value else { return }
        customMealsStorage = value
        UserDefaults.standard.set(value, forKey: CustomMealStore.storageKey)
    }
}
