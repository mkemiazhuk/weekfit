import SwiftUI

enum WeekFitTheme {

    @MainActor
    private static var palette: WeekFitSemanticPalette {
        WeekFitPaletteStore.current
    }

    // MARK: - Semantic Category Colors (bases)

    /// Activity / meal green — punchy on OLED; soft daylight green in Light.
    private static let mealBaseDark = Color(red: 0.55, green: 0.82, blue: 0.61)
    private static let mealBaseLight = WeekFitLightTokens.activity

    private static let workoutBaseDark = Color(red: 0.50, green: 0.62, blue: 0.92)
    private static let workoutBaseLight = WeekFitLightTokens.recovery

    /// Recovery purple (dark) / cyan (light) — light mode uses calm recovery cyan.
    private static let recoveryBaseDark = Color(red: 0.68, green: 0.56, blue: 0.90)
    private static let recoveryBaseLight = WeekFitLightTokens.recovery

    /// Nutrition orange.
    private static let habitBaseDark = Color(red: 0.93, green: 0.62, blue: 0.34)
    private static let habitBaseLight = WeekFitLightTokens.nutrition

    private static let coachAccentBaseDark = Color(red: 0.55, green: 0.40, blue: 0.85)
    private static let coachAccentBaseLight = WeekFitLightTokens.coachPurple

    private static let primaryGreenBaseDark = Color(red: 0.62, green: 0.82, blue: 0.45)
    private static let primaryGreenBaseLight = WeekFitLightTokens.coach

    private static let avatarOrangeBaseDark = Color(red: 0.93, green: 0.62, blue: 0.34)
    private static let avatarOrangeBaseLight = WeekFitLightTokens.nutrition

    /// Champagne warmth for light canvas vignettes / Quick Log.
    static let champagneGlow = WeekFitLightTokens.backgroundTopGlow
    static let ivoryCanvas = WeekFitLightTokens.backgroundPrimary

    /// Internal tile surface (inside premium cards).
    static var internalTile: Color { palette.internalTile }

    private static var mealBase: Color { palette.isLight ? mealBaseLight : mealBaseDark }
    private static var workoutBase: Color { palette.isLight ? workoutBaseLight : workoutBaseDark }
    private static var recoveryBase: Color { palette.isLight ? recoveryBaseLight : recoveryBaseDark }
    private static var habitBase: Color { palette.isLight ? habitBaseLight : habitBaseDark }
    private static var coachAccentBase: Color { palette.isLight ? coachAccentBaseLight : coachAccentBaseDark }
    private static var primaryGreenBase: Color { palette.isLight ? primaryGreenBaseLight : primaryGreenBaseDark }
    private static var avatarOrangeBase: Color { palette.isLight ? avatarOrangeBaseLight : avatarOrangeBaseDark }

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

    static var backgroundColor: Color { appScreenBackground }

    static var coachAccent: Color { palette.accent(coachAccentBase) }

    /// Soft coach-green tint used for Today Coach card hierarchy.
    static var coachSurfaceAccent: Color { primaryGreen }

    /// Soft surface washes for metric families (Light Mode only).
    static var activitySoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.activitySoft : meal.opacity(0.12)
    }
    static var nutritionSoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.nutritionSoft : habit.opacity(0.12)
    }
    static var recoverySoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.recoverySoft : recovery.opacity(0.12)
    }
    static var coachSoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.coachSoft : primaryGreen.opacity(0.12)
    }
    static var coachPurpleSoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.coachPurpleSoft : coachAccent.opacity(0.12)
    }
    static var stressSoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.stressSoft : habit.opacity(0.12)
    }
    static var stressAccent: Color {
        palette.isLight ? WeekFitLightTokens.stress : habit
    }
    static var waterSoftSurface: Color {
        palette.isLight ? WeekFitLightTokens.waterSoft : workout.opacity(0.12)
    }

    /// Warm neutral accent for Quick Log / utility surfaces.
    static var warmNeutralAccent: Color {
        palette.isLight ? WeekFitLightTokens.brandGoldSoft : champagneGlow
    }

    /// Single continuous root canvas for every screen.
    /// Light: warm ivory. Dark: deep OLED. No gradient banding / secondary content wells.
    static var appScreenBackground: Color {
        if palette.isLight {
            return WeekFitLightTokens.backgroundPrimary
        }
        return Color(red: 0.014, green: 0.016, blue: 0.022)
    }

    /// Deep OLED / ivory page fill — alias of `appScreenBackground` (kept for call-site compatibility).
    /// Must stay a solid color so header, scroll gutters, and tab clearance share one plane.
    static var appBackground: Color { appScreenBackground }

    /// Ambient screens share the same root canvas (glows paint on top; never a second fill).
    static var ambientCanvasBackground: Color { appScreenBackground }

    // MARK: - Ambient Backgrounds

    static var planAmbient: RadialGradient {
        let peak = palette.isLight ? 0.025 : 0.048
        return RadialGradient(
            colors: [
                Color(red: 0.43, green: 0.51, blue: 1.0).opacity(peak * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.92, y: 0.00),
            startRadius: 20,
            endRadius: 260
        )
    }

    static var todayAmbient: RadialGradient {
        let peak = palette.isLight ? 0.06 : 0.045
        return RadialGradient(
            colors: [
                (palette.isLight ? WeekFitLightTokens.backgroundTopGlow : mealBase)
                    .opacity(peak * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.50, y: 0.00),
            startRadius: 24,
            endRadius: palette.isLight ? 280 : 300
        )
    }

    static var mealsAmbient: RadialGradient {
        // Light: no tint wash — any opaque residual under rounded cards reads as
        // corner "triangles" and a second content canvas. Dark keeps soft glow.
        let peak = palette.isLight ? 0.0 : 0.042
        return RadialGradient(
            colors: [
                (palette.isLight ? WeekFitLightTokens.nutrition : Color(red: 0.93, green: 0.58, blue: 0.26))
                    .opacity(peak * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 300
        )
    }

    static var coachAmbient: RadialGradient {
        let peak = palette.isLight ? 0.0 : 0.050
        return RadialGradient(
            colors: [
                (palette.isLight ? WeekFitLightTokens.coachPurple : recoveryBase)
                    .opacity(peak * palette.ambientOpacity),
                Color.clear
            ],
            center: UnitPoint(x: 0.90, y: 0.02),
            startRadius: 24,
            endRadius: 310
        )
    }

    static var healthAmbient: RadialGradient {
        let peak = palette.isLight ? 0.06 : 0.07
        return RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.25, blue: 0.35).opacity(peak * palette.ambientOpacity),
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
    static var cardSurfaceWarm: Color { palette.cardSurfaceWarm }
    static var cardBorder: Color { palette.cardBorder }
    static var cardInnerHighlight: Color { palette.cardInnerHighlight }
    static var cardAccentOverlayOpacity: CGFloat { palette.cardAccentOverlayOpacity }

    // MARK: - Text

    static var primaryText: Color { palette.textPrimary }
    static var secondaryText: Color { palette.textSecondary }
    static var tertiaryText: Color { palette.textTertiary }
    static var quaternaryText: Color { palette.textQuaternary }
    static var disabledText: Color { palette.textDisabled }

    static var iconPrimary: Color { palette.iconPrimary }
    static var iconSecondary: Color { palette.iconSecondary }
    static var iconInactive: Color { palette.iconInactive }

    // MARK: - Borders

    static var border: Color { palette.border }
    static var borderSoft: Color { palette.borderSoft }
    static var divider: Color {
        palette.isLight ? WeekFitLightTokens.divider : palette.border
    }

    // MARK: - Glass / Material Helpers

    static var glassOverlay: Color { palette.glassOverlay }
    static var activePill: Color { palette.activePill }

    // MARK: - Shadows

    static var cardShadow: Color { palette.shadowAmbient }

    static var softShadow: Color {
        if palette.isLight {
            return Color.black.opacity(0.06)
        }
        return Color.black.opacity(palette.scaledOpacity(0.18))
    }

    static var primaryCTA: Color {
        palette.isLight ? WeekFitLightTokens.primaryCTA : primaryGreen
    }

    static var primaryCTAForeground: Color {
        palette.isLight ? WeekFitLightTokens.primaryCTAForeground : Color.white.opacity(0.94)
    }

    // MARK: - Avatar

    static var avatarOrange: Color { palette.accent(avatarOrangeBase) }

    // MARK: - RGB Values (non-visual constants)

    static let mealRGB = (red: 0.55, green: 0.82, blue: 0.61)
    static let workoutRGB = (red: 0.50, green: 0.62, blue: 0.92)
    static let recoveryRGB = (red: 0.68, green: 0.56, blue: 0.90)
    static let habitRGB = (red: 0.93, green: 0.62, blue: 0.34)

    static var primaryGreen: Color { palette.accent(primaryGreenBase) }

    /// Settings / preference chrome (icons, toggles, checks).
    /// Light: calm coach green. Dark: keeps OLED neon used across settings.
    static var settingsAccent: Color {
        palette.isLight
            ? WeekFitLightTokens.coach
            : Color(red: 170 / 255, green: 255 / 255, blue: 70 / 255)
    }

    /// Soft well behind settings row icons.
    static var settingsIconWell: Color {
        palette.isLight
            ? WeekFitLightTokens.coachSoft
            : Color.white.opacity(0.045)
    }

    /// Brand metallic gold — onboarding splash / premium accents.
    /// Light Mode uses the restrained brand gold; Dark keeps OLED champagne.
    static var brandGold: Color {
        palette.isLight ? WeekFitLightTokens.brandGold : Color(red: 0.90, green: 0.74, blue: 0.38)
    }
    static var brandGoldDeep: Color {
        palette.isLight ? WeekFitLightTokens.brandGoldDark : Color(red: 0.72, green: 0.52, blue: 0.22)
    }

    // MARK: - Night Comfort helpers

    static func accent(_ color: Color) -> Color {
        palette.accent(color)
    }

    static func whiteOpacity(_ opacity: CGFloat) -> Color {
        palette.whiteOpacity(opacity)
    }

    static func specularHighlight(_ opacity: CGFloat) -> Color {
        palette.specularHighlight(opacity)
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

    private static let caloriesBaseDark = Color(red: 0.93, green: 0.58, blue: 0.26)
    private static let proteinBaseDark = Color(red: 0.42, green: 0.62, blue: 0.88)
    private static let carbsBaseDark = Color(red: 0.66, green: 0.55, blue: 0.86)
    private static let fatsBaseDark = Color(red: 0.49, green: 0.70, blue: 0.52)

    static var calories: Color {
        palette.accent(palette.isLight ? WeekFitLightTokens.nutrition : caloriesBaseDark)
    }
    static var protein: Color {
        palette.accent(palette.isLight ? WeekFitLightTokens.protein : proteinBaseDark)
    }
    static var carbs: Color {
        palette.accent(palette.isLight ? WeekFitLightTokens.carbs : carbsBaseDark)
    }
    static var fats: Color {
        palette.accent(palette.isLight ? WeekFitLightTokens.fats : fatsBaseDark)
    }
}
