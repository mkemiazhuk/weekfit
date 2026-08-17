import SwiftUI

/// Widget-only palette mirrored from WeekFit light/dark tokens (no app Theme dependency).
public enum WeekFitWidgetPalette {
    public static let activity = Color(red: 0.196, green: 0.725, blue: 0.420)
    public static let nutrition = Color(red: 0.898, green: 0.553, blue: 0.196)
    public static let recovery = Color(red: 0.208, green: 0.678, blue: 0.816)
    public static let brandGold = Color(red: 0.725, green: 0.541, blue: 0.196)
    public static let brandGoldSoft = Color(red: 0.949, green: 0.898, blue: 0.765)
    public static let brandGoldDark = Color(red: 0.588, green: 0.431, blue: 0.141)

    public static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.070, green: 0.070, blue: 0.078)
            : Color(red: 0.965, green: 0.953, blue: 0.933)
    }

    public static func backgroundSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.110, green: 0.110, blue: 0.120)
            : Color(red: 0.945, green: 0.928, blue: 0.900)
    }

    public static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.145, green: 0.145, blue: 0.156)
            : Color.white.opacity(0.78)
    }

    public static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.12, green: 0.11, blue: 0.10)
    }

    public static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.58)
            : Color(red: 0.42, green: 0.38, blue: 0.33)
    }

    public static func tertiaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.42)
            : Color(red: 0.55, green: 0.50, blue: 0.44)
    }

    public static func track(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color(red: 0.88, green: 0.86, blue: 0.82)
    }

    public static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    public static func modeTint(for mode: WeekFitWidgetSnapshot.DayMode) -> Color {
        switch mode {
        case .goodToGo: return activity
        case .maintain: return brandGold
        case .takeItEasy: return nutrition
        case .recoveryFocus: return recovery
        case .empty: return brandGold
        }
    }
}
