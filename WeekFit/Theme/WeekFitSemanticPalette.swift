import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Canvas appearance for WeekFit semantic tokens.
enum WeekFitAppearance: Equatable, Sendable {
    case light
    case dark
}

/// Adaptive semantic design tokens. Components should read these instead of hard-coded opacities.
struct WeekFitSemanticPalette: Equatable, Sendable {
    let appearance: WeekFitAppearance
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

    var isLight: Bool { appearance == .light }

    /// Solid root canvas — Light ivory / Dark OLED. Prefer this over `WeekFitTheme.appScreenBackground`
    /// so chrome never paints from a stale static store snapshot.
    var appScreenBackground: Color {
        switch appearance {
        case .light:
            return WeekFitLightTokens.backgroundPrimary
        case .dark:
            return Color(red: 0.014, green: 0.016, blue: 0.022)
        }
    }

    /// Invalidates `EquatableView` tab layers when Light/Dark or Night Comfort blend changes.
    var appearanceInvalidationToken: UInt64 {
        let appearanceBit: UInt64 = appearance == .light ? 1 : 0
        let blendBits = UInt64(clamping: Int((blendFactor * 1000).rounded()))
        return (appearanceBit << 32) | blendBits
    }

    static let daytime = WeekFitSemanticPalette(appearance: .dark, blendFactor: 0)
    static let light = WeekFitSemanticPalette(appearance: .light, blendFactor: 0)

    init(appearance: WeekFitAppearance = .dark, blendFactor: CGFloat) {
        let blend = min(1, max(0, blendFactor))
        self.appearance = appearance
        self.blendFactor = appearance == .light ? 0 : blend

        switch appearance {
        case .light:
            textPrimaryOpacity = 1.00
            textSecondaryOpacity = 1.00
            textTertiaryOpacity = 1.00

            cardBackgroundOpacity = 1.00
            cardSecondaryOpacity = 1.00
            cardTertiaryOpacity = 1.00
            elevatedCardOpacity = 1.00
            glassOverlayOpacity = 0.92
            activePillOpacity = 1.00

            borderOpacity = 0.42
            borderSoftOpacity = 0.32

            accentSaturation = 1.00
            accentBrightness = 1.00
            accentGlowOpacity = 0.90

            ringTrackOpacity = 1.00
            ringGlowOpacity = 0.10
            ringGradientPeakOpacity = 1.00

            ambientOpacity = 1.00
            cardShadowOpacity = 0.08
            accentCardGlowOpacity = 0.40

        case .dark:
            textPrimaryOpacity = Self.lerp(0.96, 0.86, blend)
            textSecondaryOpacity = Self.lerp(0.70, 0.56, blend)
            textTertiaryOpacity = Self.lerp(0.50, 0.40, blend)

            cardBackgroundOpacity = Self.lerp(0.090, 0.065, blend)
            cardSecondaryOpacity = Self.lerp(0.065, 0.048, blend)
            cardTertiaryOpacity = Self.lerp(0.048, 0.036, blend)
            elevatedCardOpacity = Self.lerp(0.110, 0.080, blend)
            glassOverlayOpacity = Self.lerp(0.055, 0.040, blend)
            activePillOpacity = Self.lerp(0.13, 0.095, blend)

            borderOpacity = Self.lerp(0.085, 0.055, blend)
            borderSoftOpacity = Self.lerp(0.055, 0.036, blend)

            accentSaturation = Self.lerp(1.00, 0.72, blend)
            accentBrightness = Self.lerp(1.00, 0.88, blend)
            accentGlowOpacity = Self.lerp(1.00, 0.55, blend)

            ringTrackOpacity = Self.lerp(0.11, 0.075, blend)
            ringGlowOpacity = Self.lerp(0.18, 0.08, blend)
            ringGradientPeakOpacity = Self.lerp(1.00, 0.86, blend)

            ambientOpacity = Self.lerp(1.00, 0.62, blend)
            cardShadowOpacity = Self.lerp(0.42, 0.30, blend)
            accentCardGlowOpacity = Self.lerp(1.00, 0.55, blend)
        }
    }

    static func interpolated(blend: CGFloat, appearance: WeekFitAppearance = .dark) -> WeekFitSemanticPalette {
        WeekFitSemanticPalette(appearance: appearance, blendFactor: blend)
    }

    /// Scales arbitrary frost opacities for ad-hoc legacy call sites (Dark Mode).
    func scaledOpacity(_ dayOpacity: CGFloat) -> CGFloat {
        switch appearance {
        case .light:
            // Prefer `whiteOpacity` / role tokens; keep a usable fallback.
            return min(1.0, max(0.12, dayOpacity * 2.6))
        case .dark:
            return Self.lerp(dayOpacity, dayOpacity * 0.78, blendFactor)
        }
    }

    /// Bridges dark-era white frost into Light Mode ceramic / text roles.
    /// Prefer explicit semantic tokens for new code.
    func whiteOpacity(_ dayOpacity: CGFloat) -> Color {
        switch appearance {
        case .light:
            // Critical: zero / near-zero must stay clear so "no fill" overlays
            // do not paint opaque ceramic over content (meal library cards).
            if dayOpacity <= 0.001 {
                return .clear
            }
            switch dayOpacity {
            case ...0.035:
                return WeekFitLightTokens.surfaceTertiary
            case ...0.055:
                return WeekFitLightTokens.internalTile
            case ...0.090:
                return WeekFitLightTokens.cardBorder.opacity(0.45)
            case ...0.160:
                return WeekFitLightTokens.textQuaternary
            case ...0.320:
                return WeekFitLightTokens.iconInactive
            case ...0.500:
                return WeekFitLightTokens.textTertiary
            case ...0.720:
                return WeekFitLightTokens.textSecondary
            case ...0.880:
                return WeekFitLightTokens.iconPrimary
            default:
                // Near-white frost on dark → primary ink on light (soft tint CTAs).
                return WeekFitLightTokens.textPrimary
            }
        case .dark:
            return Color.white.opacity(Double(scaledOpacity(dayOpacity)))
        }
    }

    /// True specular highlight — always white. Use for ceramic card sheen.
    func specularHighlight(_ opacity: CGFloat) -> Color {
        switch appearance {
        case .light:
            return Color.white.opacity(Double(min(0.55, max(0.20, opacity * 0.85))))
        case .dark:
            return Color.white.opacity(Double(scaledOpacity(opacity)))
        }
    }

    var textPrimary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.textPrimary
        case .dark: return Color.white.opacity(textPrimaryOpacity)
        }
    }

    var textSecondary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.textSecondary
        case .dark: return Color.white.opacity(textSecondaryOpacity)
        }
    }

    var textTertiary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.textTertiary
        case .dark: return Color.white.opacity(textTertiaryOpacity)
        }
    }

    var textQuaternary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.textQuaternary
        case .dark: return Color.white.opacity(textTertiaryOpacity * 0.78)
        }
    }

    var textDisabled: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.textDisabled
        case .dark: return Color.white.opacity(textTertiaryOpacity * 0.72)
        }
    }

    var iconPrimary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.iconPrimary
        case .dark: return Color.white.opacity(textPrimaryOpacity)
        }
    }

    var iconSecondary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.iconSecondary
        case .dark: return Color.white.opacity(textSecondaryOpacity)
        }
    }

    var iconInactive: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.iconInactive
        case .dark: return Color.white.opacity(textTertiaryOpacity)
        }
    }

    var cardBackground: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.surfaceCard
        case .dark: return Color.white.opacity(cardBackgroundOpacity)
        }
    }

    var cardSecondary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.surfaceSecondary
        case .dark: return Color.white.opacity(cardSecondaryOpacity)
        }
    }

    var cardTertiary: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.surfaceTertiary
        case .dark: return Color.white.opacity(cardTertiaryOpacity)
        }
    }

    var elevatedCard: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.surfacePrimary
        case .dark: return Color.white.opacity(elevatedCardOpacity)
        }
    }

    var glassOverlay: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.surfacePrimary.opacity(glassOverlayOpacity)
        case .dark: return Color.white.opacity(glassOverlayOpacity)
        }
    }

    var activePill: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.tabActiveCapsule
        case .dark: return Color.white.opacity(activePillOpacity)
        }
    }

    var border: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.cardBorder.opacity(borderOpacity)
        case .dark: return Color.white.opacity(borderOpacity)
        }
    }

    var borderSoft: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.divider.opacity(borderSoftOpacity)
        case .dark: return Color.white.opacity(borderSoftOpacity)
        }
    }

    // MARK: - Premium card surfaces

    var cardSurface: Color {
        switch appearance {
        case .light:
            return WeekFitLightTokens.surfaceCard
        case .dark:
            return Color(
                red: Self.lerp(0.050, 0.038, blendFactor),
                green: Self.lerp(0.053, 0.041, blendFactor),
                blue: Self.lerp(0.062, 0.050, blendFactor)
            )
        }
    }

    var cardSurfaceElevated: Color {
        switch appearance {
        case .light:
            return WeekFitLightTokens.surfacePrimary
        case .dark:
            return Color(
                red: Self.lerp(0.068, 0.050, blendFactor),
                green: Self.lerp(0.072, 0.054, blendFactor),
                blue: Self.lerp(0.084, 0.064, blendFactor)
            )
        }
    }

    var cardSurfaceWarm: Color {
        switch appearance {
        case .light:
            return WeekFitLightTokens.surfaceSecondary
        case .dark:
            return Color(
                red: Self.lerp(0.058, 0.044, blendFactor),
                green: Self.lerp(0.054, 0.042, blendFactor),
                blue: Self.lerp(0.048, 0.038, blendFactor)
            )
        }
    }

    var internalTile: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.internalTile
        case .dark: return Color.white.opacity(cardTertiaryOpacity)
        }
    }

    var cardBorder: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.cardBorder.opacity(WeekFitLightTokens.cardBorderStrokeOpacity)
        case .dark: return Color.white.opacity(Self.lerp(0.12, 0.075, blendFactor))
        }
    }

    var cardInnerHighlight: Color {
        switch appearance {
        case .light: return Color.white.opacity(0.35)
        case .dark: return Color.white.opacity(Self.lerp(0.050, 0.030, blendFactor))
        }
    }

    var cardAccentOverlayOpacity: CGFloat {
        switch appearance {
        case .light: return 0.045
        case .dark: return Self.lerp(0.12, 0.070, blendFactor)
        }
    }

    var ringTrack: Color {
        switch appearance {
        case .light: return WeekFitLightTokens.inactiveTrack
        case .dark: return Color.white.opacity(ringTrackOpacity)
        }
    }

    var shadowAmbient: Color {
        switch appearance {
        case .light: return Color.black.opacity(cardShadowOpacity)
        case .dark: return Color.black.opacity(cardShadowOpacity)
        }
    }

    var shadowContact: Color {
        switch appearance {
        case .light: return Color.black.opacity(0.05)
        case .dark: return Color.clear
        }
    }

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
        guard appearance == .dark, blendFactor > 0.001 else { return color }

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
        environment(\.weekFitPalette, .interpolated(blend: blend, appearance: .dark))
    }

    func weekFitAppearancePreview(_ appearance: WeekFitAppearance) -> some View {
        environment(\.weekFitPalette, .interpolated(blend: 0, appearance: appearance))
    }
}
