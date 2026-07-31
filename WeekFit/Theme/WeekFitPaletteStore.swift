import SwiftUI

/// Shared palette snapshot for static `WeekFitTheme` accessors and legacy call sites.
@MainActor
enum WeekFitPaletteStore {
    static var current: WeekFitSemanticPalette = .daytime

    static func update(blend: CGFloat, appearance: WeekFitAppearance = .dark) {
        current = WeekFitSemanticPalette.interpolated(blend: blend, appearance: appearance)
    }

    static func update(appearance: WeekFitAppearance, blend: CGFloat) {
        update(blend: blend, appearance: appearance)
    }
}
