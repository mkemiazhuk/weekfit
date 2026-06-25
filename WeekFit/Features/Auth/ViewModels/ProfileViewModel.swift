import Foundation
internal import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var destination: ProfileDestination?

    @Published var userProfile: UserProfile
    @Published private(set) var mainSettings: [ProfileItem]
    @Published private(set) var connectedSystems: [ProfileItem]
    @Published private(set) var supportSettings: [ProfileItem]

    private let service: ProfileServicing

    init(service: ProfileServicing = ProfileService()) {
        self.service = service
        self.userProfile = service.loadUserProfile()
        self.mainSettings = service.loadMainSettings()
        self.connectedSystems = service.loadConnectedSystems()
        self.supportSettings = service.loadSupportSettings()
    }

    func openProfileEditor() {
        destination = .editProfile
    }

    func handleTap(_ item: ProfileItem) {
        switch item.type {
        case .notifications:
            destination = .notifications

        case .language:
            destination = .language

        case .nightComfort:
            destination = .nightComfort

        case .healthAccess, .appleHealth:
            destination = .healthAccess

        case .privacy:
            destination = .privacy

        case .help:
            destination = .helpSupport

        case .terms:
            destination = .termsPrivacy

        case .units:
            break
        }
    }

    func updateUserProfile(_ profile: UserProfile) {
        let cleanName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)

        let updatedProfile = UserProfile(
            initials: ProfileService.makeInitials(from: cleanName),
            fullName: cleanName,
            email: cleanEmail
        )

        userProfile = updatedProfile
        service.saveUserProfile(updatedProfile)
        WeekFitUserSettings.shared.refreshFromStorage()
    }

    func signOut() {
        service.signOut()
    }

    func reloadUserProfile() {
        userProfile = service.loadUserProfile()
        WeekFitUserSettings.shared.refreshFromStorage()
    }

    func bodyGoalNeedsSetup(weightKg: Double, heightCm: Double) -> Bool {
        service.bodyGoalNeedsSetup(weightKg: weightKg, heightCm: heightCm)
    }

    func hasManualNutritionGoal() -> Bool {
        service.isManualNutritionGoal()
    }

    func shouldShowBodyGoalSetting(weightKg: Double, heightCm: Double) -> Bool {
        UserNutritionProfile.hasSufficientHealthDataForAutoGoal(
            weightKg: weightKg,
            heightCm: heightCm
        ) ||
            service.isManualNutritionGoal() ||
            service.bodyGoalNeedsSetup(weightKg: weightKg, heightCm: heightCm)
    }

    func saveBodyGoal(_ goal: NutritionGoal) {
        service.saveManualNutritionGoal(goal)
    }
}
