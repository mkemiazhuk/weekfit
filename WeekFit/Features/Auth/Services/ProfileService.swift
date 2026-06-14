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
            static let name = "weekfit.profile.name"
            static let displayName = "weekfit.profile.displayName"
            static let email = "weekfit.profile.email"
            static let initials = "weekfit.profile.initials"
        }

        func loadUserProfile() -> UserProfile {
            Self.migrateProfileStorageIfNeeded()

            let fullName = Self.resolvedFullName()

            let email = UserDefaults.standard
                .string(forKey: Keys.email)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let initials = Self.resolvedInitials()

            return UserProfile(
                initials: initials,
                fullName: fullName,
                email: email
            )
        }

        func saveUserProfile(_ profile: UserProfile) {
            let cleanName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let initials = Self.makeInitials(from: cleanName)

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
                ),
                ProfileItem(
                    icon: "globe",
                    title: "Language",
                    subtitle: "Choose the app language",
                    type: .language
                )
            ]
        }

        func loadConnectedSystems() -> [ProfileItem] {
            [
                ProfileItem(
                    icon: "heart.fill",
                    title: "Health Signals",
                    subtitle: "Powered by Apple Health & Apple Watch",
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

        static func resolvedFullName(defaults: UserDefaults = .standard) -> String {
            cleanString(defaults.string(forKey: Keys.fullName)) ??
            cleanString(defaults.string(forKey: Keys.name)) ??
            cleanString(defaults.string(forKey: Keys.displayName)) ??
            ""
        }

        static func resolvedInitials(defaults: UserDefaults = .standard) -> String {
            let fullName = resolvedFullName(defaults: defaults)

            if !fullName.isEmpty {
                let derivedInitials = makeInitials(from: fullName)

                if cleanString(defaults.string(forKey: Keys.initials)) != derivedInitials {
                    defaults.set(derivedInitials, forKey: Keys.initials)
                }

                return derivedInitials
            }

            return cleanString(defaults.string(forKey: Keys.initials)) ?? "P"
        }

        static func migrateProfileStorageIfNeeded(defaults: UserDefaults = .standard) {
            let fullName = cleanString(defaults.string(forKey: Keys.fullName))
            let fallbackName = cleanString(defaults.string(forKey: Keys.name)) ??
                cleanString(defaults.string(forKey: Keys.displayName))

            if fullName == nil, let fallbackName {
                defaults.set(fallbackName, forKey: Keys.fullName)
            }

            _ = resolvedInitials(defaults: defaults)
        }

        private static func cleanString(_ value: String?) -> String? {
            let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cleaned.isEmpty ? nil : cleaned
        }

        static func makeInitials(from name: String) -> String {
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
