import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Adaptive semantic design tokens. Components should read these instead of hard-coded opacities.
struct WeekFitSemanticPalette: Equatable, Sendable {
    let blendFactor: CGFloat

    let textPrimaryOpacity: CGFloat
    let textSecondaryOpacity: CGFloat
    let textTertiaryOpacity: CGFloat

    let cardBackgroundOpacity: CGFloat
    let cardSecondaryOpacity: CGFloat
    let cardTertiaryOpacity: CGFloat
    let elevatedCardOpacity: CGFloat
    let glassOverlayOpacity: CGFloat
    let activePillOpacity: CGFloat

    let borderOpacity: CGFloat
    let borderSoftOpacity: CGFloat

    let accentSaturation: CGFloat
    let accentBrightness: CGFloat
    let accentGlowOpacity: CGFloat

    let ringTrackOpacity: CGFloat
    let ringGlowOpacity: CGFloat
    let ringGradientPeakOpacity: CGFloat

    let ambientOpacity: CGFloat
    let cardShadowOpacity: CGFloat
    let accentCardGlowOpacity: CGFloat

    static let daytime = WeekFitSemanticPalette(blendFactor: 0)

    init(blendFactor: CGFloat) {
        let blend = min(1, max(0, blendFactor))
        self.blendFactor = blend

        textPrimaryOpacity = Self.lerp(0.94, 0.82, blend)
        textSecondaryOpacity = Self.lerp(0.62, 0.50, blend)
        textTertiaryOpacity = Self.lerp(0.42, 0.34, blend)

        cardBackgroundOpacity = Self.lerp(0.075, 0.055, blend)
        cardSecondaryOpacity = Self.lerp(0.055, 0.040, blend)
        cardTertiaryOpacity = Self.lerp(0.040, 0.030, blend)
        elevatedCardOpacity = Self.lerp(0.095, 0.070, blend)
        glassOverlayOpacity = Self.lerp(0.050, 0.036, blend)
        activePillOpacity = Self.lerp(0.12, 0.085, blend)

        borderOpacity = Self.lerp(0.065, 0.040, blend)
        borderSoftOpacity = Self.lerp(0.040, 0.026, blend)

        accentSaturation = Self.lerp(1.00, 0.72, blend)
        accentBrightness = Self.lerp(1.00, 0.88, blend)
        accentGlowOpacity = Self.lerp(1.00, 0.55, blend)

        ringTrackOpacity = Self.lerp(0.11, 0.075, blend)
        ringGlowOpacity = Self.lerp(0.18, 0.08, blend)
        ringGradientPeakOpacity = Self.lerp(1.00, 0.86, blend)

        ambientOpacity = Self.lerp(1.00, 0.62, blend)
        cardShadowOpacity = Self.lerp(0.28, 0.22, blend)
        accentCardGlowOpacity = Self.lerp(1.00, 0.55, blend)
    }

    static func interpolated(blend: CGFloat) -> WeekFitSemanticPalette {
        WeekFitSemanticPalette(blendFactor: blend)
    }

    /// Scales arbitrary white opacities for ad-hoc legacy call sites.
    func scaledOpacity(_ dayOpacity: CGFloat) -> CGFloat {
        Self.lerp(dayOpacity, dayOpacity * 0.78, blendFactor)
    }

    func whiteOpacity(_ dayOpacity: CGFloat) -> Color {
        Color.white.opacity(scaledOpacity(dayOpacity))
    }

    var textPrimary: Color { Color.white.opacity(textPrimaryOpacity) }
    var textSecondary: Color { Color.white.opacity(textSecondaryOpacity) }
    var textTertiary: Color { Color.white.opacity(textTertiaryOpacity) }

    var cardBackground: Color { Color.white.opacity(cardBackgroundOpacity) }
    var cardSecondary: Color { Color.white.opacity(cardSecondaryOpacity) }
    var cardTertiary: Color { Color.white.opacity(cardTertiaryOpacity) }
    var elevatedCard: Color { Color.white.opacity(elevatedCardOpacity) }
    var glassOverlay: Color { Color.white.opacity(glassOverlayOpacity) }
    var activePill: Color { Color.white.opacity(activePillOpacity) }

    var border: Color { Color.white.opacity(borderOpacity) }
    var borderSoft: Color { Color.white.opacity(borderSoftOpacity) }

    func accent(_ color: Color) -> Color {
        adjustAccent(color, saturation: accentSaturation, brightness: accentBrightness)
    }

    func accentOpacity(_ baseOpacity: CGFloat) -> CGFloat {
        baseOpacity * accentGlowOpacity
    }

    private static func lerp(_ day: CGFloat, _ night: CGFloat, _ blend: CGFloat) -> CGFloat {
        day + (night - day) * blend
    }

    private func adjustAccent(_ color: Color, saturation: CGFloat, brightness: CGFloat) -> Color {
        guard blendFactor > 0.001 else { return color }

        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else {
            return color.opacity(Double(brightness))
        }

        return Color(
            hue: Double(hue),
            saturation: Double(sat * saturation),
            brightness: Double(bri * brightness),
            opacity: Double(alpha)
        )
        #else
        return color.opacity(Double(brightness))
        #endif
    }
}

private struct WeekFitSemanticPaletteKey: EnvironmentKey {
    static let defaultValue = WeekFitSemanticPalette.daytime
}

extension EnvironmentValues {
    var weekFitPalette: WeekFitSemanticPalette {
        get { self[WeekFitSemanticPaletteKey.self] }
        set { self[WeekFitSemanticPaletteKey.self] = newValue }
    }
}

extension View {
    func weekFitNightComfortPreview(blend: CGFloat) -> some View {
        environment(\.weekFitPalette, .interpolated(blend: blend))
    }
}
