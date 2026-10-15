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

/// Quiet matte card for Today surfaces (no loud borders / gold wash).
struct TodaySurfaceModifier: ViewModifier {
    var elevated: Bool = false
    var cornerRadius: CGFloat = TodayChrome.cardRadius
    var coachEmphasis: Bool = false

    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillStyle)
                    // Short contact shadow only — wide ambient casts a rectangular slab on ivory.
                    .shadow(
                        color: Color.black.opacity(
                            palette.isLight
                                ? WeekFitLightTokens.cardContactShadowOpacity
                                : 0.28
                        ),
                        radius: palette.isLight ? 5 : 10,
                        y: palette.isLight ? 2 : 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        TodayChrome.border(isLight: palette.isLight),
                        lineWidth: palette.isLight ? 0.75 : 1
                    )
            }
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

extension View {
    func todaySurface(
        elevated: Bool = false,
        coachEmphasis: Bool = false,
        cornerRadius: CGFloat = TodayChrome.cardRadius
    ) -> some View {
        modifier(
            TodaySurfaceModifier(
                elevated: elevated,
                cornerRadius: cornerRadius,
                coachEmphasis: coachEmphasis
            )
        )
    }
}
