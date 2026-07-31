import Foundation
import SwiftUI

/// User-facing appearance preference for WeekFit (Light / Dark / System).
enum WeekFitAppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    static let storageKey = "weekfit.appearance.preference"

    static var stored: WeekFitAppearancePreference {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? WeekFitAppearancePreference.system.rawValue
        return WeekFitAppearancePreference(rawValue: raw) ?? .system
    }

    static func store(_ preference: WeekFitAppearancePreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: storageKey)
    }

    /// Override for `.preferredColorScheme`. `nil` follows the system.
    var colorSchemeOverride: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func resolvedAppearance(system: ColorScheme) -> WeekFitAppearance {
        switch self {
        case .system:
            return system == .light ? .light : .dark
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
