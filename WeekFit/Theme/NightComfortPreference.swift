import Foundation

enum NightComfortPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case alwaysOn
    case off

    var id: String { rawValue }

    static let storageKey = "weekfit.nightComfort.preference"

    static var stored: NightComfortPreference {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? NightComfortPreference.automatic.rawValue
        return NightComfortPreference(rawValue: raw) ?? .automatic
    }

    static func store(_ preference: NightComfortPreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: storageKey)
    }
}

#if DEBUG
enum NightComfortDebugSettings {
    static let blendOverrideKey = "weekfit.nightComfort.debugBlendOverride"

    static var blendOverride: CGFloat? {
        if let env = ProcessInfo.processInfo.environment["WEEKFIT_NIGHT_COMFORT_BLEND"],
           let value = Double(env) {
            return CGFloat(min(1, max(0, value)))
        }

        let stored = UserDefaults.standard.object(forKey: blendOverrideKey) as? Double
        guard let stored else { return nil }
        return CGFloat(min(1, max(0, stored)))
    }
}
#endif
