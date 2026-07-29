import SwiftUI

enum WeekFitTheme {

    @MainActor
    private static var palette: WeekFitSemanticPalette {
        WeekFitPaletteStore.current
    }

    // MARK: - Semantic Category Colors (bases)

    private static let mealBase = Color(red: 0.55, green: 0.82, blue: 0.61)
    private static let workoutBase = Color(red: 0.50, green: 0.62, blue: 0.92)
    private static let recoveryBase = Color(red: 0.68, green: 0.56, blue: 0.90)
    private static let habitBase = Color(red: 0.93, green: 0.62, blue: 0.34)
    private static let coachAccentBase = Color(red: 0.55, green: 0.40, blue: 0.85)
    private static let primaryGreenBase = Color(red: 0.62, green: 0.82, blue: 0.45)
    private static let avatarOrangeBase = Color(red: 0.93, green: 0.62, blue: 0.34)

    static var meal: Color { palette.accent(mealBase) }
    static var workout: Color { palette.accent(workoutBase) }
    static var recovery: Color { palette.accent(recoveryBase) }
    static var habit: Color { palette.accent(habitBase) }

    // MARK: - Generic UI Colors

    static var green: Color { meal }
    static var blue: Color { workout }
    static var orange: Color { habit }
    static var purple: Color { recovery }

    // MARK: - Base UI

    static var backgroundColor: Color { Color(red: 0.018, green: 0.020, blue: 0.024) }
    static var coachAccent: Color { palette.accent(coachAccentBase) }

    /// Deep OLED canvas — near-black with a quiet blue lift so matte cards separate cleanly.
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.014, green: 0.016, blue: 0.022),
                Color(red: 0.022, green: 0.028, blue: 0.062),
                Color(red: 0.012, green: 0.014, blue: 0.018)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Slightly lifted OLED canvas for depth-first ambient screens.
    static var ambientCanvasBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.042, green: 0.045, blue: 0.054),
                Color(red: 0.032, green: 0.035, blue: 0.044),
                Color(red: 0.024, green: 0.027, blue: 0.034)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Ambient Backgrounds

    static var planAmbient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.43, green: 0.51, blue: 1.0).opacity(0.048 * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.92, y: 0.00),
            startRadius: 20,
            endRadius: 260
        )
    }

    static var todayAmbient: RadialGradient {
        RadialGradient(
            colors: [
                mealBase.opacity(0.045 * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 300
        )
    }

    static var mealsAmbient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.93, green: 0.58, blue: 0.26).opacity(0.042 * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 300
        )
    }

    static var coachAmbient: RadialGradient {
        RadialGradient(
            colors: [
                recoveryBase.opacity(0.050 * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 310
        )
    }

    static var healthAmbient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.25, blue: 0.35).opacity(0.07 * palette.ambientOpacity),
                Color.clear
            ],
            center: .center,
            startRadius: 20,
            endRadius: 280
        )
    }

    // MARK: - Cards

    static var cardBackground: Color { palette.cardBackground }
    static var cardSecondary: Color { palette.cardSecondary }
    static var cardTertiary: Color { palette.cardTertiary }
    static var elevatedCard: Color { palette.elevatedCard }

    /// Semantic premium surfaces — prefer these over hard-coded blacks/grays.
    static var cardSurface: Color { palette.cardSurface }
    static var cardSurfaceElevated: Color { palette.cardSurfaceElevated }
    static var cardBorder: Color { palette.cardBorder }
    static var cardInnerHighlight: Color { palette.cardInnerHighlight }
    static var cardAccentOverlayOpacity: CGFloat { palette.cardAccentOverlayOpacity }

    // MARK: - Text

    static var primaryText: Color { palette.textPrimary }
    static var secondaryText: Color { palette.textSecondary }
    static var tertiaryText: Color { palette.textTertiary }

    // MARK: - Borders

    static var border: Color { palette.border }
    static var borderSoft: Color { palette.borderSoft }

    // MARK: - Glass / Material Helpers

    static var glassOverlay: Color { palette.glassOverlay }
    static var activePill: Color { palette.activePill }

    // MARK: - Shadows

    static var cardShadow: Color { Color.black.opacity(palette.cardShadowOpacity) }
    static var softShadow: Color { Color.black.opacity(palette.scaledOpacity(0.18)) }

    // MARK: - Avatar

    static var avatarOrange: Color { palette.accent(avatarOrangeBase) }

    // MARK: - RGB Values (non-visual constants)

    static let mealRGB = (red: 0.55, green: 0.82, blue: 0.61)
    static let workoutRGB = (red: 0.50, green: 0.62, blue: 0.92)
    static let recoveryRGB = (red: 0.68, green: 0.56, blue: 0.90)
    static let habitRGB = (red: 0.93, green: 0.62, blue: 0.34)

    static var primaryGreen: Color { palette.accent(primaryGreenBase) }

    /// Brand metallic gold — onboarding splash / premium accents.
    static let brandGold = Color(red: 0.90, green: 0.74, blue: 0.38)
    static let brandGoldDeep = Color(red: 0.72, green: 0.52, blue: 0.22)

    // MARK: - Night Comfort helpers

    static func accent(_ color: Color) -> Color {
        palette.accent(color)
    }

    static func whiteOpacity(_ opacity: CGFloat) -> Color {
        palette.whiteOpacity(opacity)
    }

    static func scaledOpacity(_ opacity: CGFloat) -> CGFloat {
        palette.scaledOpacity(opacity)
    }

    static func accentOpacity(_ opacity: CGFloat) -> CGFloat {
        palette.accentOpacity(opacity)
    }

    static var ambientOpacity: CGFloat { palette.ambientOpacity }
    static var ringGlowOpacity: CGFloat { palette.ringGlowOpacity }
}

enum WeekFitMacroColor {

    @MainActor
    private static var palette: WeekFitSemanticPalette {
        WeekFitPaletteStore.current
    }

    private static let caloriesBase = Color(red: 0.93, green: 0.58, blue: 0.26)
    private static let proteinBase = Color(red: 0.42, green: 0.62, blue: 0.88)
    private static let carbsBase = Color(red: 0.66, green: 0.55, blue: 0.86)
    private static let fatsBase = Color(red: 0.49, green: 0.70, blue: 0.52)

    static var calories: Color { palette.accent(caloriesBase) }
    static var protein: Color { palette.accent(proteinBase) }
    static var carbs: Color { palette.accent(carbsBase) }
    static var fats: Color { palette.accent(fatsBase) }
}
