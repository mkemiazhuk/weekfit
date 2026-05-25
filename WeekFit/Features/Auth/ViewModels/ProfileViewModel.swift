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
            initials: makeInitials(from: cleanName),
            fullName: cleanName,
            email: cleanEmail
        )

        userProfile = updatedProfile
        service.saveUserProfile(updatedProfile)
    }

    func signOut() {
        service.signOut()
    }
    
    func resetLocalData() {
        
    }

    private func makeInitials(from name: String) -> String {
        let parts = name
            .split(separator: " ")
            .map(String.init)

        guard !parts.isEmpty else {
            return "P"
        }

        let initials = parts
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? "P" : initials
    }
}
