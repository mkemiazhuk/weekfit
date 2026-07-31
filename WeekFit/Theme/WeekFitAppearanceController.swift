import Foundation
import SwiftUI
internal import Combine

@MainActor
final class WeekFitAppearanceController: ObservableObject {

    @Published private(set) var preference: WeekFitAppearancePreference

    init(preference: WeekFitAppearancePreference = .stored) {
        self.preference = preference
    }

    func setPreference(_ preference: WeekFitAppearancePreference) {
        guard self.preference != preference else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.preference = preference
        }
        WeekFitAppearancePreference.store(preference)

        // Sync static theme tokens immediately so WeekFitTheme.* and backgrounds
        // never briefly disagree (white text on ivory, etc.).
        switch preference {
        case .light:
            WeekFitPaletteStore.update(blend: 0, appearance: .light)
        case .dark:
            WeekFitPaletteStore.update(
                blend: WeekFitPaletteStore.current.blendFactor,
                appearance: .dark
            )
        case .system:
            break
        }
    }

    var colorSchemeOverride: ColorScheme? {
        preference.colorSchemeOverride
    }

    func resolvedAppearance(system: ColorScheme) -> WeekFitAppearance {
        preference.resolvedAppearance(system: system)
    }
}
