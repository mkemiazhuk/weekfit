import SwiftUI

/// Plan screen chrome tokens — calendar, day summary, Add CTA, completion.
/// Light values follow the approved Plan mock; Dark keeps legacy accents.
enum WeekFitPlanChromeTokens {

    // MARK: - Calendar (light)

    /// Selected-day capsule wash.
    static let calendarSelectedFill = Color(red: 0.933, green: 0.918, blue: 0.965) // #EEEAF6
    /// Marker under the selected day (and soft today cue when unselected).
    static let calendarSelectedDot = Color(red: 0.510, green: 0.439, blue: 0.682) // #8270AE

    // MARK: - Day summary (light)

    /// Recovery day card fill — near-white lavender.
    static let recoveryDayFill = Color(red: 0.973, green: 0.965, blue: 0.988) // #F8F6FC
    static let recoveryIconWell = Color(red: 0.933, green: 0.910, blue: 0.973) // #EEE8F8
    static let recoveryIcon = Color(red: 0.537, green: 0.455, blue: 0.682) // #8974AE

    /// Activity / endurance / load / mixed day card fill.
    static let activityDayFill = WeekFitSemanticMetricTokens.activitySoft
    static let activityIconWell = WeekFitSemanticMetricTokens.activitySoft
    static let activityIcon = WeekFitSemanticMetricTokens.activityInk

    // MARK: - Add CTA (light)

    /// Pale gold wash on the milk canvas, gold ink — same family as the avatar.
    /// A solid dark fill read as a stamp on the light page.
    static let addFill = WeekFitLightTokens.brandGoldSoft // #F2E5C3
    static let addForeground = WeekFitLightTokens.brandGoldDark // #966E24
    static let addStroke = WeekFitLightTokens.brandGold // #B98A32

    // MARK: - Completion (light)

    static let completed = Color(red: 0.302, green: 0.596, blue: 0.459) // #4D9875
    static let loggedBadgeFill = Color(red: 0.937, green: 0.961, blue: 0.941) // #EFF5F0
    static let loggedBadgeInk = Color(red: 0.282, green: 0.486, blue: 0.376) // #487C60

    // MARK: - Nutrition timeline icons (light)

    static let nutritionIcon = WeekFitSemanticMetricTokens.nutritionIcon
    static let nutritionIconWell = WeekFitSemanticMetricTokens.nutritionSoft

    // MARK: - Resolved

    @MainActor
    static func calendarSelectedFill(isLight: Bool) -> Color {
        isLight ? calendarSelectedFill : WeekFitTheme.brandGold.opacity(0.22)
    }

    @MainActor
    static func calendarDot(isLight: Bool, isSelected: Bool, isToday: Bool) -> Color {
        guard isToday || isSelected else { return .clear }
        if isLight {
            if isSelected { return calendarSelectedDot }
            return calendarSelectedDot.opacity(0.55)
        }
        return WeekFitTheme.brandGold.opacity(isSelected ? 1 : 0.85)
    }

    @MainActor
    static func addFill(isLight: Bool) -> Color {
        isLight ? addFill : WeekFitTheme.brandGold.opacity(0.20)
    }

    @MainActor
    static func addForeground(isLight: Bool) -> Color {
        isLight ? addForeground : WeekFitTheme.brandGold
    }

    static func addStroke(isLight: Bool) -> Color {
        isLight ? addStroke.opacity(0.38) : .clear
    }

    @MainActor
    static func completed(isLight: Bool) -> Color {
        isLight ? completed : Color(red: 0.40, green: 0.76, blue: 0.58)
    }

    @MainActor
    static func loggedBadgeFill(isLight: Bool) -> Color {
        isLight ? loggedBadgeFill : completed(isLight: false).opacity(0.16)
    }

    @MainActor
    static func loggedBadgeInk(isLight: Bool) -> Color {
        isLight ? loggedBadgeInk : completed(isLight: false)
    }

    @MainActor
    static func daySummaryFill(kind: PlanDayKind, isLight: Bool) -> Color {
        if isLight {
            switch kind {
            case .recovery:
                return recoveryDayFill
            case .endurance, .load, .mixed:
                return activityDayFill
            case .open:
                return Color.white.opacity(0.97)
            }
        }
        return WeekFitTheme.cardBackground
    }

    @MainActor
    static func daySummaryAccentOverlay(kind: PlanDayKind, isLight: Bool) -> Color {
        guard !isLight else { return .clear }
        switch kind {
        case .recovery:
            return WeekFitSemanticMetricTokens.recovery.opacity(0.22)
        case .endurance, .load, .mixed:
            return WeekFitSemanticMetricTokens.activity.opacity(0.18)
        case .open:
            return .clear
        }
    }

    @MainActor
    static func daySummaryStroke(kind: PlanDayKind, isLight: Bool) -> Color {
        if isLight {
            switch kind {
            case .recovery:
                return calendarSelectedDot.opacity(0.10)
            case .endurance, .load, .mixed:
                return WeekFitSemanticMetricTokens.activity.opacity(0.12)
            case .open:
                return Color.black.opacity(0.05)
            }
        }
        return WeekFitTheme.whiteOpacity(0.07)
    }

    @MainActor
    static func daySummaryIconWell(kind: PlanDayKind, isLight: Bool) -> Color {
        if isLight {
            switch kind {
            case .recovery: return recoveryIconWell
            case .endurance, .load, .mixed: return activityIconWell
            case .open: return Color.black.opacity(0.05)
            }
        }
        switch kind {
        case .recovery: return WeekFitSemanticMetricTokens.recovery.opacity(0.24)
        case .endurance, .load, .mixed: return WeekFitSemanticMetricTokens.activity.opacity(0.22)
        case .open: return WeekFitTheme.whiteOpacity(0.08)
        }
    }

    @MainActor
    static func daySummaryIcon(kind: PlanDayKind, isLight: Bool) -> Color {
        if isLight {
            switch kind {
            case .recovery: return recoveryIcon
            case .endurance, .load, .mixed: return activityIcon
            case .open: return WeekFitLightTokens.textSecondary
            }
        }
        switch kind {
        case .recovery: return WeekFitSemanticMetricTokens.recovery.opacity(0.92)
        case .endurance, .load, .mixed: return WeekFitSemanticMetricTokens.activity.opacity(0.92)
        case .open: return WeekFitTheme.secondaryText
        }
    }
}
