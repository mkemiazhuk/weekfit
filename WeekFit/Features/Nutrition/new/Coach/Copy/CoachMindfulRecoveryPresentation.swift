import Foundation

/// Chrome for mindful recovery sessions (breathing / yoga / stretch).
/// Walk recovery keeps its own `CoachWalkRecoveryActionPresentation`.
enum CoachMindfulRecoveryPresentation {

    /// Heart-rate zone chrome (bpm chips / Easy · Zone N) fits walks, not breath/yoga/stretch.
    static func usesHeartRateZoneChrome(_ activityType: CoachActivityType) -> Bool {
        switch activityType {
        case .breathing, .yoga, .stretching:
            return false
        default:
            return true
        }
    }

    static func liveStateBadge(
        activityType: CoachActivityType,
        russian: Bool
    ) -> String {
        switch activityType {
        case .breathing:
            return russian ? "Дыхание" : "Breath work"
        case .yoga:
            return russian ? "Йога" : "Yoga"
        case .stretching:
            return russian ? "Растяжка" : "Stretching"
        default:
            return russian ? "Восстановление" : "Recovery"
        }
    }

    static func todayTitle(
        activityType: CoachActivityType,
        russian: Bool
    ) -> String {
        switch activityType {
        case .breathing:
            return russian ? "Дыхание" : "Breath work"
        case .yoga:
            return russian ? "Йога" : "Yoga time"
        case .stretching:
            return russian ? "Растяжка" : "Stretch time"
        default:
            return russian ? "Восстановление" : "Recovery time"
        }
    }

    static func coachHeadline(
        activityType: CoachActivityType,
        russian: Bool
    ) -> String {
        switch activityType {
        case .breathing:
            return russian ? "Дыхание" : "Breath work"
        case .yoga:
            return russian ? "Йога" : "Yoga session"
        case .stretching:
            return russian ? "Растяжка" : "Stretch session"
        default:
            return russian ? "Восстановительная тренировка" : "Recovery session"
        }
    }
}
