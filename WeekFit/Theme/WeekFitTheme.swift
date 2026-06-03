import SwiftUI

enum WeekFitTheme {

    // MARK: - Semantic Category Colors

    static let meal = Color(red: 0.55, green: 0.82, blue: 0.61)
    static let workout = Color(red: 0.50, green: 0.62, blue: 0.92)
    static let recovery = Color(red: 0.68, green: 0.56, blue: 0.90)
    static let habit = Color(red: 0.93, green: 0.62, blue: 0.34)

    // MARK: - Generic UI Colors

    static let green = meal
    static let blue = workout
    static let orange = habit
    static let purple = recovery

    // MARK: - Base UI

    static let backgroundColor = Color(red: 0.035, green: 0.043, blue: 0.047)
    
    static let coachAccent = Color(red: 0.55, green: 0.40, blue: 0.85)

    static let appBackground = LinearGradient(
        colors: [
            Color.black,
            Color(red: 0.018, green: 0.026, blue: 0.075),
            Color.black
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Ambient Backgrounds

    static let planAmbient = RadialGradient(
        colors: [
            Color(red: 0.43, green: 0.51, blue: 1.0).opacity(0.035),
            Color.clear
        ],
        center: UnitPoint(x: 0.92, y: 0.00),
        startRadius: 20,
        endRadius: 260
    )

    static let todayAmbient = RadialGradient(
        colors: [
            meal.opacity(0.032),
            Color.clear
        ],
        center: UnitPoint(x: 0.90, y: 0.02),
        startRadius: 24,
        endRadius: 300
    )

    static let mealsAmbient = RadialGradient(
        colors: [
            Color(red: 0.93, green: 0.58, blue: 0.26).opacity(0.030),
            Color.clear
        ],
        center: UnitPoint(x: 0.90, y: 0.02),
        startRadius: 24,
        endRadius: 300
    )

    static let coachAmbient = RadialGradient(
        colors: [
            recovery.opacity(0.035),
            Color.clear
        ],
        center: UnitPoint(x: 0.90, y: 0.02),
        startRadius: 24,
        endRadius: 310
    )

    // MARK: - Cards

    static let cardBackground = Color.white.opacity(0.075)
    static let cardSecondary = Color.white.opacity(0.055)
    static let cardTertiary = Color.white.opacity(0.040)

    static let elevatedCard = Color.white.opacity(0.095)

    // MARK: - Text

    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    // MARK: - Borders

    static let border = Color.white.opacity(0.065)
    static let borderSoft = Color.white.opacity(0.040)

    // MARK: - Glass / Material Helpers

    static let glassOverlay = Color.white.opacity(0.050)
    static let activePill = Color.white.opacity(0.12)

    // MARK: - Shadows

    static let cardShadow = Color.black.opacity(0.28)
    static let softShadow = Color.black.opacity(0.18)

    // MARK: - Avatar

    static let avatarOrange = Color(red: 0.93, green: 0.62, blue: 0.34)

    // MARK: - RGB Values

    static let mealRGB = (red: 0.55, green: 0.82, blue: 0.61)
    static let workoutRGB = (red: 0.50, green: 0.62, blue: 0.92)
    static let recoveryRGB = (red: 0.68, green: 0.56, blue: 0.90)
    static let habitRGB = (red: 0.93, green: 0.62, blue: 0.34)

    static let primaryGreen = Color(red: 0.62, green: 0.82, blue: 0.45)
}

enum WeekFitMacroColor {

    static let calories = Color(
        red: 0.93,
        green: 0.58,
        blue: 0.26
    )

    static let protein = Color(
        red: 0.42,
        green: 0.62,
        blue: 0.88
    )

    static let carbs = Color(
        red: 0.66,
        green: 0.55,
        blue: 0.86
    )

    static let fats = Color(
        red: 0.49,
        green: 0.70,
        blue: 0.52
    )
}
