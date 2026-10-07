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
        _ = russian
        switch activityType {
        case .breathing:
            return WeekFitTrilingual("Breath work", "Дыхание", "呼吸练习")
        case .yoga:
            return WeekFitTrilingual("Yoga", "Йога", "瑜伽")
        case .stretching:
            return WeekFitTrilingual("Stretching", "Растяжка", "拉伸")
        default:
            return WeekFitTrilingual("Recovery", "Восстановление", "恢复")
        }
    }

    static func todayTitle(
        activityType: CoachActivityType,
        russian: Bool
    ) -> String {
        _ = russian
        switch activityType {
        case .breathing:
            return WeekFitTrilingual("Breath work", "Дыхание", "呼吸练习")
        case .yoga:
            return WeekFitTrilingual("Yoga time", "Йога", "瑜伽时间")
        case .stretching:
            return WeekFitTrilingual("Stretch time", "Растяжка", "拉伸时间")
        default:
            return WeekFitTrilingual("Recovery time", "Восстановление", "恢复时间")
        }
    }

    static func coachHeadline(
        activityType: CoachActivityType,
        russian: Bool
    ) -> String {
        _ = russian
        switch activityType {
        case .breathing:
            return WeekFitTrilingual("Breath work", "Дыхание", "呼吸练习")
        case .yoga:
            return WeekFitTrilingual("Yoga session", "Йога", "瑜伽训练")
        case .stretching:
            return WeekFitTrilingual("Stretch session", "Растяжка", "拉伸训练")
        default:
            return WeekFitTrilingual("Recovery session", "Восстановительная тренировка", "恢复训练")
        }
    }
}
