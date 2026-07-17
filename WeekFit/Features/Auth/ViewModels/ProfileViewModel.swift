import Foundation
internal import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    @Published var destination: ProfileDestination?

    @Published var userProfile: UserProfile
    @Published private(set) var accountSettings: [ProfileItem]
    @Published private(set) var healthSettings: [ProfileItem]
    @Published private(set) var preferenceSettings: [ProfileItem]
    @Published private(set) var privacyLegalSettings: [ProfileItem]
    @Published private(set) var supportSettings: [ProfileItem]

    /// Compatibility aliases for older call sites.
    var mainSettings: [ProfileItem] { preferenceSettings }
    var connectedSystems: [ProfileItem] { healthSettings }

    private let service: ProfileServicing

    init(service: ProfileServicing = ProfileService()) {
        self.service = service
        self.userProfile = service.loadUserProfile()
        self.accountSettings = service.loadAccountSettings()
        self.healthSettings = service.loadHealthSettings()
        self.preferenceSettings = service.loadPreferenceSettings()
        self.privacyLegalSettings = service.loadPrivacyLegalSettings()
        self.supportSettings = service.loadSupportSettings()
    }

    func openEditName() {
        destination = .editName
    }

    func openAccount() {
        destination = .account
    }

    func openAppleHealth() {
        destination = .healthAccess
    }

    func handleTap(_ item: ProfileItem) {
        switch item.type {
        case .notifications:
            destination = .notifications

        case .language:
            destination = .language

        case .nightComfort:
            destination = .nightComfort

        case .nutritionGoal:
            destination = .nutritionGoal

        case .healthAccess, .appleHealth:
            destination = .healthAccess

        case .account:
            destination = .account

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

    func resolvedNutritionGoal(weightKg: Double, heightCm: Double) -> NutritionGoal {
        service.resolvedNutritionGoal(weightKg: weightKg, heightCm: heightCm)
    }

    func accountRowSubtitle() -> String {
        let name = userProfile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = userProfile.email.trimmingCharacters(in: .whitespacesAndNewlines)

        if AppReviewDemoCredentials.hasActiveSession {
            return AppReviewDemoCredentials.email
        }
        if !name.isEmpty { return name }
        if !email.isEmpty { return email }
        if AuthSessionStore.hasPersistedAppleSession {
            return WeekFitLocalizedString("settings.account.summary.appleSignIn")
        }
        return WeekFitLocalizedString("settings.account.profileSubtitle")
    }
}
