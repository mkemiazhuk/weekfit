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

    static let cardRadius: CGFloat = 28
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

/// Warm white plate on the milk canvas. A tint marks a section (focus, up next).
/// Shadow stays on the rounded shape, so it cannot paint a gray rectangle.
struct WeekFitLightGlassPlate: View {
    var cornerRadius: CGFloat
    var tint: Color? = nil

    private var warmWhite: Color { Color(red: 1.0, green: 0.988, blue: 0.973) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(warmWhite)
            .overlay {
                if let tint {
                    shape.fill(tint.opacity(0.14))
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color(red: 0.45, green: 0.38, blue: 0.30).opacity(tint == nil ? 0.14 : 0.10),
                    lineWidth: 1
                )
            }
            .shadow(color: Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.05), radius: 8, y: 3)
    }
}

/// Frosted dark plate shared by Today and every other screen.
/// Reduce Transparency falls back to the solid fill at each call site.
struct WeekFitDarkGlassPlate: View {
    var cornerRadius: CGFloat
    var elevated: Bool = false
    var tint: Color? = nil
    var coachEmphasis: Bool = false
    var shadowOpacity: Double = 0.36
    var shadowRadius: CGFloat = 18
    var shadowY: CGFloat = 10

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(TodayChrome.cardDark.opacity(elevated ? 0.52 : 0.64))
            if let tint {
                shape.fill(tint.opacity(0.16))
            }
            if coachEmphasis {
                shape.fill(coachGlassWash)
            }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowY)
        .overlay {
            shape.strokeBorder(rim, lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.75)
        }
    }

    private var rim: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorSchemeContrast == .increased ? 0.55 : 0.30),
                Color.white.opacity(colorSchemeContrast == .increased ? 0.16 : 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
}

/// Light Today cards are porcelain glass. Dark cards frost over the sky.
/// Reduce Transparency falls back to the solid fill.
struct TodaySurfaceModifier: ViewModifier {
    var elevated: Bool = false
    var cornerRadius: CGFloat = TodayChrome.cardRadius
    var coachEmphasis: Bool = false
    var tint: Color? = nil

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var usesDarkGlass: Bool { !palette.isLight && !reduceTransparency }
    private var usesLightGlass: Bool { palette.isLight && !reduceTransparency }

    func body(content: Content) -> some View {
        content
            .background { plate }
            .overlay { rim }
    }

    @ViewBuilder
    private var plate: some View {
        if usesDarkGlass {
            WeekFitDarkGlassPlate(
                cornerRadius: cornerRadius,
                elevated: elevated,
                tint: tint,
                coachEmphasis: coachEmphasis
            )
        } else if usesLightGlass {
            WeekFitLightGlassPlate(cornerRadius: cornerRadius, tint: tint)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fillStyle)
                .compositingGroup()
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
    }

    private var shadowColor: Color {
        if palette.isLight {
            return Color.black.opacity(WeekFitLightTokens.cardContactShadowOpacity)
        }
        return Color.black.opacity(0.28)
    }

    private var shadowRadius: CGFloat {
        if palette.isLight { return 5 }
        return 10
    }

    private var shadowY: CGFloat {
        if palette.isLight { return 2 }
        return 4
    }

    @ViewBuilder
    private var rim: some View {
        if !usesDarkGlass && !usesLightGlass {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(TodayChrome.border(isLight: palette.isLight), lineWidth: rimWidth)
        }
    }

    private var rimWidth: CGFloat {
        if colorSchemeContrast == .increased { return palette.isLight ? 0.75 : 1 }
        return palette.isLight ? 0.75 : 1
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
