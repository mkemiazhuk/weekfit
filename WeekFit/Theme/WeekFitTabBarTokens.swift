import SwiftUI

/// Bottom-tab navigation chrome.
/// Selection is neutral ink on a gray capsule, not a metric or brand hue.
enum WeekFitTabBarTokens {

    // MARK: - Light

    /// Active capsule fill — neutral gray, just enough to mark the selected tab.
    static let activeFillLight = Color(red: 0.894, green: 0.894, blue: 0.886) // #E4E4E2
    /// No outline on the light active pill (fill alone carries selection).
    static let activeStrokeLight = Color.clear
    static let activeStrokeOpacityLight: Double = 0
    /// Active icon + label — same ink as primary text.
    static let activeForegroundLight = Color(red: 0.161, green: 0.169, blue: 0.157) // #292B28
    /// Inactive icon + label.
    static let inactiveLight = Color(red: 0.455, green: 0.459, blue: 0.443) // #747571

    // MARK: - Dark

    /// Active capsule — neutral charcoal (selected without a colored chip).
    static let activeFillDark = Color(white: 0.18)
    /// No stroke on dark active pill — fill alone is enough.
    static let activeStrokeDark = Color.clear
    static let activeStrokeOpacityDark: Double = 0
    /// Active icon + label — clear white.
    static let activeForegroundDark = Color.white
    /// Inactive icon + label — muted grey on OLED.
    static let inactiveDark = Color(red: 0.52, green: 0.54, blue: 0.58) // #858A94

    // MARK: - Resolved

    @MainActor
    static func activeFill(isLight: Bool) -> Color {
        isLight ? activeFillLight : activeFillDark
    }

    @MainActor
    static func activeStroke(isLight: Bool) -> Color {
        if isLight {
            return activeStrokeLight.opacity(activeStrokeOpacityLight)
        }
        return activeStrokeDark.opacity(activeStrokeOpacityDark)
    }

    @MainActor
    static func activeForeground(isLight: Bool) -> Color {
        isLight ? activeForegroundLight : activeForegroundDark
    }

    @MainActor
    static func inactiveForeground(isLight: Bool) -> Color {
        isLight ? inactiveLight : inactiveDark
    }
}
