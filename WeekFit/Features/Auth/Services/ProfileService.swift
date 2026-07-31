    import Foundation

    protocol ProfileServicing {
        func loadUserProfile() -> UserProfile
        func saveUserProfile(_ profile: UserProfile)

        func loadAccountSettings() -> [ProfileItem]
        func loadHealthSettings() -> [ProfileItem]
        func loadPreferenceSettings() -> [ProfileItem]
        func loadPrivacyLegalSettings() -> [ProfileItem]
        func loadSupportSettings() -> [ProfileItem]

        /// Legacy alias used by older call sites / tests.
        func loadMainSettings() -> [ProfileItem]
        func loadConnectedSystems() -> [ProfileItem]

        func loadManualNutritionGoal() -> NutritionGoal?
        func isManualNutritionGoal() -> Bool
        func saveManualNutritionGoal(_ goal: NutritionGoal)
        func bodyGoalNeedsSetup(weightKg: Double, heightCm: Double) -> Bool
        func resolvedNutritionGoal(weightKg: Double, heightCm: Double) -> NutritionGoal

        func signOut()
    }

    final class ProfileService: ProfileServicing {

        enum Keys {
            static let fullName = "weekfit.profile.fullName"
            static let name = "weekfit.profile.name"
            static let displayName = "weekfit.profile.displayName"
            static let givenName = "weekfit.profile.givenName"
            static let familyName = "weekfit.profile.familyName"
            static let email = "weekfit.profile.email"
            static let initials = "weekfit.profile.initials"
            static let nutritionGoal = "weekfit.profile.nutritionGoal"
            static let nutritionGoalIsManual = "weekfit.profile.nutritionGoalIsManual"
        }

        private let defaults: UserDefaults

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

        nonisolated deinit {}

        func loadUserProfile() -> UserProfile {
            Self.migrateProfileStorageIfNeeded(defaults: defaults)

            let fullName = Self.resolvedFullName(defaults: defaults)

            let email = defaults
                .string(forKey: Keys.email)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let initials = Self.resolvedInitials(defaults: defaults)

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

            defaults.set(cleanName, forKey: Keys.fullName)
            defaults.set(cleanEmail, forKey: Keys.email)
            defaults.set(initials, forKey: Keys.initials)

            // Keep greeting first-name in sync for manual edits.
            if cleanName.isEmpty {
                defaults.removeObject(forKey: Keys.givenName)
                defaults.removeObject(forKey: Keys.familyName)
            } else {
                let first = cleanName.split(whereSeparator: \.isWhitespace).first.map(String.init)
                defaults.set(first, forKey: Keys.givenName)
                defaults.removeObject(forKey: Keys.familyName)
            }
        }

        /// Applies Apple-provided name only when the profile display name is empty.
        /// Never overwrites a manually edited (or previously persisted) non-empty name.
        @discardableResult
        func applyAppleNameIfEmpty(_ parsed: ApplePersonNameParser.ParsedName) -> Bool {
            Self.migrateProfileStorageIfNeeded(defaults: defaults)
            guard Self.resolvedFullName(defaults: defaults).isEmpty else { return false }

            let display = parsed.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !display.isEmpty else { return false }

            defaults.set(display, forKey: Keys.fullName)
            defaults.set(Self.makeInitials(from: display), forKey: Keys.initials)
            if let given = parsed.givenName {
                defaults.set(given, forKey: Keys.givenName)
            } else {
                defaults.removeObject(forKey: Keys.givenName)
            }
            if let family = parsed.familyName {
                defaults.set(family, forKey: Keys.familyName)
            } else {
                defaults.removeObject(forKey: Keys.familyName)
            }
            return true
        }

        func applyAppleEmailIfEmpty(_ email: String?) {
            let clean = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !clean.isEmpty else { return }
            let existing = defaults.string(forKey: Keys.email)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard existing.isEmpty else { return }
            defaults.set(clean, forKey: Keys.email)
        }

        func loadAccountSettings() -> [ProfileItem] {
            [
                ProfileItem(
                    icon: "person.crop.circle.fill",
                    title: WeekFitLocalizedString("settings.account.title"),
                    subtitle: WeekFitLocalizedString("settings.account.profileSubtitle"),
                    type: .account
                )
            ]
        }

        func loadHealthSettings() -> [ProfileItem] {
            [
                ProfileItem(
                    icon: "heart.fill",
                    title: WeekFitLocalizedString("settings.root.appleHealth"),
                    subtitle: WeekFitLocalizedString("settings.profile.item.healthSignals.subtitle"),
                    type: .appleHealth
                )
            ]
        }

        func loadPreferenceSettings() -> [ProfileItem] {
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
                ),
                ProfileItem(
                    icon: "circle.lefthalf.filled",
                    title: WeekFitLocalizedString("settings.appearance.title"),
                    subtitle: WeekFitLocalizedString("settings.appearance.profileSubtitle"),
                    type: .appearance
                ),
                ProfileItem(
                    icon: "moon.stars.fill",
                    title: WeekFitLocalizedString("settings.nightComfort.title"),
                    subtitle: WeekFitLocalizedString("settings.nightComfort.profileSubtitle"),
                    type: .nightComfort
                ),
                ProfileItem(
                    icon: "target",
                    title: WeekFitLocalizedString("settings.nutritionGoal.title"),
                    subtitle: WeekFitLocalizedString("settings.nutritionGoal.profileSubtitle"),
                    type: .nutritionGoal
                ),
                ProfileItem(
                    icon: "ruler",
                    title: WeekFitLocalizedString("settings.units.title"),
                    subtitle: nil,
                    type: .units
                )
            ]
        }

        func loadPrivacyLegalSettings() -> [ProfileItem] {
            [
                ProfileItem(
                    icon: "doc.text.fill",
                    title: "Terms & Privacy",
                    subtitle: nil,
                    type: .terms
                )
            ]
        }

        func loadMainSettings() -> [ProfileItem] {
            loadPreferenceSettings()
        }

        func loadManualNutritionGoal() -> NutritionGoal? {
            guard let rawValue = defaults.string(forKey: Keys.nutritionGoal) else { return nil }
            return NutritionGoal(rawValue: rawValue)
        }

        func isManualNutritionGoal() -> Bool {
            defaults.bool(forKey: Keys.nutritionGoalIsManual)
        }

        func saveManualNutritionGoal(_ goal: NutritionGoal) {
            defaults.set(goal.rawValue, forKey: Keys.nutritionGoal)
            defaults.set(true, forKey: Keys.nutritionGoalIsManual)
        }

        func bodyGoalNeedsSetup(weightKg: Double, heightCm: Double) -> Bool {
            UserNutritionProfile.needsManualBodyGoalSelection(
                weightKg: weightKg,
                heightCm: heightCm,
                manualGoal: loadManualNutritionGoal(),
                isManualGoal: isManualNutritionGoal()
            )
        }

        func resolvedNutritionGoal(weightKg: Double, heightCm: Double) -> NutritionGoal {
            UserNutritionProfile.resolveGoal(
                weightKg: weightKg,
                heightCm: heightCm,
                manualGoal: loadManualNutritionGoal(),
                isManualGoal: isManualNutritionGoal()
            )
        }

        func makeNutritionProfile(
            weightKg: Double,
            heightCm: Double,
            age: Int,
            sex: BiologicalSex
        ) -> UserNutritionProfile {
            UserNutritionProfile.resolve(
                weightKg: weightKg,
                heightCm: heightCm,
                age: age,
                sex: sex,
                manualGoal: loadManualNutritionGoal(),
                isManualGoal: isManualNutritionGoal()
            )
        }

        func loadConnectedSystems() -> [ProfileItem] {
            loadHealthSettings()
        }

        func loadSupportSettings() -> [ProfileItem] {
            [
                ProfileItem(
                    icon: "heart.text.square.fill",
                    title: WeekFitLocalizedString("review.helpWeekFit.title"),
                    subtitle: WeekFitLocalizedString("review.helpWeekFit.rowSubtitle"),
                    type: .helpWeekFit
                ),
                ProfileItem(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: nil,
                    type: .help
                )
            ]
        }

        func signOut() {
            // Auth sign-out is owned by AuthViewModel.
        }

        static func resolvedFullName(defaults: UserDefaults = .standard) -> String {
            cleanString(defaults.string(forKey: Keys.fullName)) ??
            cleanString(defaults.string(forKey: Keys.name)) ??
            cleanString(defaults.string(forKey: Keys.displayName)) ??
            ""
        }

        /// First name for greetings — prefers stored givenName, else first token of display name.
        static func resolvedGivenName(defaults: UserDefaults = .standard) -> String {
            if let given = cleanString(defaults.string(forKey: Keys.givenName)) {
                return given
            }
            let display = resolvedFullName(defaults: defaults)
            guard !display.isEmpty else { return "" }
            return display.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? display
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

        static func cleanString(_ value: String?) -> String? {
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
