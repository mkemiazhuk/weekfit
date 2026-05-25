import Foundation

protocol ProfileServicing {
    func loadUserProfile() -> UserProfile
    func saveUserProfile(_ profile: UserProfile)

    func loadMainSettings() -> [ProfileItem]
    func loadSupportSettings() -> [ProfileItem]
    func loadConnectedSystems() -> [ProfileItem]

    func signOut()
}

final class ProfileService: ProfileServicing {

    enum Keys {
        static let fullName = "weekfit.profile.fullName"
        static let email = "weekfit.profile.email"
        static let initials = "weekfit.profile.initials"
    }

    func loadUserProfile() -> UserProfile {
        let fullName = UserDefaults.standard
            .string(forKey: Keys.fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let email = UserDefaults.standard
            .string(forKey: Keys.email)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let storedInitials = UserDefaults.standard
            .string(forKey: Keys.initials)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let initials = storedInitials?.isEmpty == false
            ? storedInitials!
            : makeInitials(from: fullName)

        return UserProfile(
            initials: initials,
            fullName: fullName,
            email: email
        )
    }

    func saveUserProfile(_ profile: UserProfile) {
        let cleanName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let initials = makeInitials(from: cleanName)

        UserDefaults.standard.set(cleanName, forKey: Keys.fullName)
        UserDefaults.standard.set(cleanEmail, forKey: Keys.email)
        UserDefaults.standard.set(initials, forKey: Keys.initials)
    }

    func loadMainSettings() -> [ProfileItem] {
        [
            ProfileItem(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Workout and recovery reminders",
                type: .notifications
            )
        ]
    }

    func loadConnectedSystems() -> [ProfileItem] {
        [
            ProfileItem(
                icon: "heart.fill",
                title: "Apple Health",
                subtitle: "Connected",
                type: .appleHealth
            )
        ]
    }

    func loadSupportSettings() -> [ProfileItem] {
        [
            ProfileItem(
                icon: "questionmark.circle.fill",
                title: "Help & Support",
                subtitle: nil,
                type: .help
            ),
            ProfileItem(
                icon: "doc.text.fill",
                title: "Terms & Privacy",
                subtitle: nil,
                type: .terms
            )
        ]
    }

    func signOut() {
        // No account login for now.
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
