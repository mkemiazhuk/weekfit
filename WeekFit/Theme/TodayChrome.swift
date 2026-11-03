import SwiftUI

/// Today-scoped midnight navy chrome — mockup-aligned surfaces without rewriting global Light Mode.
enum TodayChrome {
    /// Screen canvas target ≈ #0B1020.
    static let canvasDark = Color(red: 0.043, green: 0.063, blue: 0.125)
    /// Card surface target ≈ #171D2A.
    static let cardDark = Color(red: 0.090, green: 0.114, blue: 0.165)
    /// Slightly lifted card for Coach emphasis.
    static let cardElevatedDark = Color(red: 0.110, green: 0.132, blue: 0.196)
    /// Secondary text target ≈ #A9B0BF.
    static let secondaryDark = Color(red: 0.663, green: 0.690, blue: 0.749)

    static let cardRadius: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let gapBetweenCards: CGFloat = 12
    static let borderOpacity: Double = 0.06
    /// Floating tab bar occupied height (bar 52 + bottom pad 10 + breathing room).
    /// Must match `WeekFitBottomBar` layout; used via `safeAreaInset`, not fixed screen heights.
    static let tabBarReservedHeight: CGFloat = WeekFitScreenLayout.tabBarClearance

    static func cardFill(isLight: Bool, elevated: Bool = false) -> Color {
        if isLight {
            return elevated ? WeekFitLightTokens.surfacePrimary : WeekFitLightTokens.surfaceCard
        }
        return elevated ? cardElevatedDark : cardDark
    }

    static func border(isLight: Bool) -> Color {
        if isLight {
            return WeekFitLightTokens.cardBorder.opacity(WeekFitLightTokens.cardBorderStrokeOpacity)
        }
        return Color.white.opacity(borderOpacity)
    }

    static func secondaryText(isLight: Bool) -> Color {
        isLight ? WeekFitTheme.secondaryText : secondaryDark
    }
}

/// Dark cards are frosted over the sky. Light stays the solid warm white:
/// system material on the milk canvas turns the plates gray.
/// Reduce Transparency falls back to the solid fill.
struct TodaySurfaceModifier: ViewModifier {
    var elevated: Bool = false
    var cornerRadius: CGFloat = TodayChrome.cardRadius
    var coachEmphasis: Bool = false
    var tint: Color? = nil

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var usesGlass: Bool { !palette.isLight && !reduceTransparency }

    func body(content: Content) -> some View {
        content
            .background { plate }
            .overlay { rim }
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            if usesGlass {
                shape.fill(.ultraThinMaterial)
                shape.fill(TodayChrome.cardDark.opacity(elevated ? 0.52 : 0.64))
                if let tint {
                    shape.fill(tint.opacity(0.16))
                }
                if coachEmphasis {
                    shape.fill(coachGlassWash)
                }
            } else {
                shape.fill(fillStyle)
            }
        }
        .compositingGroup()
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var shadowColor: Color {
        if palette.isLight {
            return Color.black.opacity(WeekFitLightTokens.cardContactShadowOpacity)
        }
        return Color.black.opacity(usesGlass ? 0.36 : 0.28)
    }

    private var shadowRadius: CGFloat {
        if palette.isLight { return 5 }
        return usesGlass ? 18 : 10
    }

    private var shadowY: CGFloat {
        if palette.isLight { return 2 }
        return usesGlass ? 10 : 4
    }

    private var rim: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return shape.strokeBorder(rimStyle, lineWidth: rimWidth)
    }

    private var rimWidth: CGFloat {
        if colorSchemeContrast == .increased { return usesGlass ? 1.25 : (palette.isLight ? 0.75 : 1) }
        return usesGlass ? 0.75 : (palette.isLight ? 0.75 : 1)
    }

    private var rimStyle: AnyShapeStyle {
        if usesGlass {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorSchemeContrast == .increased ? 0.55 : 0.30),
                        Color.white.opacity(colorSchemeContrast == .increased ? 0.16 : 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(TodayChrome.border(isLight: palette.isLight))
    }

    private var coachGlassWash: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.18, blue: 0.28).opacity(0.55),
                Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fillStyle: AnyShapeStyle {
        if coachEmphasis, !palette.isLight {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.14, blue: 0.22),
                        Color(red: 0.10, green: 0.11, blue: 0.20),
                        Color(red: 0.09, green: 0.10, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(TodayChrome.cardFill(isLight: palette.isLight, elevated: elevated))
    }
}

/// Press for glass cards: a small spring scale, so the plate stays opaque while it settles.
struct TodayCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(duration: 0.32, bounce: 0.18), value: configuration.isPressed)
    }
}

extension View {
    func todaySurface(
        elevated: Bool = false,
        coachEmphasis: Bool = false,
        cornerRadius: CGFloat = TodayChrome.cardRadius,
        tint: Color? = nil
    ) -> some View {
        modifier(
            TodaySurfaceModifier(
                elevated: elevated,
                cornerRadius: cornerRadius,
                coachEmphasis: coachEmphasis,
                tint: tint
            )
        )
    }
}
