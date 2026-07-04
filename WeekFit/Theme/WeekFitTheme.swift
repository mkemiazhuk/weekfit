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

    static var backgroundColor: Color { Color(red: 0.035, green: 0.043, blue: 0.047) }
    static var coachAccent: Color { palette.accent(coachAccentBase) }

    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.018, green: 0.026, blue: 0.075),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Slightly lifted OLED canvas for depth-first ambient screens (~3% above pure black).
    static var ambientCanvasBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.058, green: 0.061, blue: 0.068),
                Color(red: 0.048, green: 0.051, blue: 0.058),
                Color(red: 0.040, green: 0.043, blue: 0.050)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Ambient Backgrounds

    static var planAmbient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.43, green: 0.51, blue: 1.0).opacity(0.035 * palette.ambientOpacity),
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
                mealBase.opacity(0.032 * palette.ambientOpacity),
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
                Color(red: 0.93, green: 0.58, blue: 0.26).opacity(0.030 * palette.ambientOpacity),
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
                recoveryBase.opacity(0.035 * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 310
        )
    }

    // MARK: - Cards

    static var cardBackground: Color { palette.cardBackground }
    static var cardSecondary: Color { palette.cardSecondary }
    static var cardTertiary: Color { palette.cardTertiary }
    static var elevatedCard: Color { palette.elevatedCard }

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
