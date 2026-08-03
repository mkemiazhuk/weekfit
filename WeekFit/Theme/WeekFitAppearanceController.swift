import Foundation
import SwiftUI
internal import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class WeekFitAppearanceController: ObservableObject {

    @Published private(set) var preference: WeekFitAppearancePreference

    init(preference: WeekFitAppearancePreference = .stored) {
        self.preference = preference
        // Seed static tokens before first frame so cold launch never flashes the wrong theme.
        // `.system` uses the current trait; EnvironmentSync re-aligns once ColorScheme is available.
        WeekFitAppearanceSync.apply(
            preference: preference,
            system: Self.bootstrapSystemColorScheme(),
            nightBlend: preference == .light ? 0 : WeekFitPaletteStore.current.blendFactor
        )
    }

    func setPreference(_ preference: WeekFitAppearancePreference) {
        guard self.preference != preference else { return }

        // Align store before publishing so the same turn never has Light env + Dark Theme.*
        WeekFitAppearanceSync.apply(
            preference: preference,
            system: Self.bootstrapSystemColorScheme(),
            nightBlend: preference == .light ? 0 : WeekFitPaletteStore.current.blendFactor
        )

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.preference = preference
        }
        WeekFitAppearancePreference.store(preference)
    }

    var colorSchemeOverride: ColorScheme? {
        preference.colorSchemeOverride
    }

    func resolvedAppearance(system: ColorScheme) -> WeekFitAppearance {
        preference.resolvedAppearance(system: system)
    }

    private static func bootstrapSystemColorScheme() -> ColorScheme {
        #if canImport(UIKit)
        switch UITraitCollection.current.userInterfaceStyle {
        case .light: return .light
        case .dark: return .dark
        default: return .dark
        }
        #else
        return .dark
        #endif
    }
}

/// Single mutator for `WeekFitPaletteStore` + resolved appearance.
@MainActor
enum WeekFitAppearanceSync {
    static func apply(
        preference: WeekFitAppearancePreference,
        system: ColorScheme,
        nightBlend: CGFloat
    ) {
        let appearance = preference.resolvedAppearance(system: system)
        let blend = appearance == .light ? 0 : min(1, max(0, nightBlend))
        WeekFitPaletteStore.update(blend: blend, appearance: appearance)
    }
}
