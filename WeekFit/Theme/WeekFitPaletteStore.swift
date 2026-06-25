import SwiftUI

/// Shared palette snapshot for static `WeekFitTheme` accessors and legacy call sites.
@MainActor
enum WeekFitPaletteStore {
    static var current: WeekFitSemanticPalette = .daytime

    static func update(blend: CGFloat) {
        current = WeekFitSemanticPalette.interpolated(blend: blend)
    }
}
