import SwiftUI

/// Shared palette snapshot for static `WeekFitTheme` accessors and legacy call sites.
///
/// **Ownership:** only `WeekFitAppearanceSync.apply` may mutate this store.
/// `WeekFitPaletteEnvironmentSync` keeps it aligned with `@Environment(\.weekFitPalette)`
/// on every render so Theme readers never lag the environment after resume.
@MainActor
enum WeekFitPaletteStore {
    static private(set) var current: WeekFitSemanticPalette = .daytime

    /// Bumps on every successful apply — useful for tests / Equatable diagnostics.
    static private(set) var revision: UInt64 = 0

    static func update(blend: CGFloat, appearance: WeekFitAppearance = .dark) {
        let next = WeekFitSemanticPalette.interpolated(blend: blend, appearance: appearance)
        guard next != current else { return }
        current = next
        revision &+= 1
    }

    static func update(appearance: WeekFitAppearance, blend: CGFloat) {
        update(blend: blend, appearance: appearance)
    }
}
