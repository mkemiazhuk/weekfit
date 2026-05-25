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

    static let background = Color(red: 0.035, green: 0.043, blue: 0.047)

    static let cardBackground = Color.white.opacity(0.085)
    static let cardSecondary = Color.white.opacity(0.060)
    static let cardTertiary = Color.white.opacity(0.045)

    static let elevatedCard = Color.white.opacity(0.105)

    // MARK: - Text

    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    // MARK: - Borders

    static let border = Color.white.opacity(0.070)
    static let borderSoft = Color.white.opacity(0.045)

    // MARK: - Glass / Material Helpers

    static let glassOverlay = Color.white.opacity(0.055)
    static let activePill = Color.white.opacity(0.13)

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
