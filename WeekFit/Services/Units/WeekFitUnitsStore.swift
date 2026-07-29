import Foundation
internal import Combine

/// Stores the user's selected unit preference and exposes the resolved unit system used for presentation.
/// - Note: Weather should never refetch just because units changed; presentation converts locally.
@MainActor
final class WeekFitUnitsStore: ObservableObject {

    static let shared = WeekFitUnitsStore()

    @Published private(set) var selectedPreference: WeekFitUnitPreference

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.selectedPreference = raw.flatMap(WeekFitUnitPreference.init(rawValue:)) ?? .automatic
    }

    /// Device-resolved system used to format measurement values.
    var resolvedSystem: WeekFitResolvedUnitSystem {
        WeekFitUnitPolicy.resolvedSystem(for: selectedPreference, locale: .autoupdatingCurrent)
    }

    func setSelectedPreference(_ preference: WeekFitUnitPreference) {
        guard selectedPreference != preference else { return }
        selectedPreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Self.storageKey)
    }

    // MARK: - Test hooks
    @MainActor
    func _testReloadFromUserDefaults() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        selectedPreference = raw.flatMap(WeekFitUnitPreference.init(rawValue:)) ?? .automatic
    }
}

extension WeekFitUnitsStore {
    static let storageKey = "weekfit.units.preference"
}

