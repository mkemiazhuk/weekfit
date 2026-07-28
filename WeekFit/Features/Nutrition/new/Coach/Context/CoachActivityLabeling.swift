import Foundation
import WeekFitCoachCore

/// App bridge: maps coach activity snapshots into WeekFitCoachCore label signals.
/// Phase B foundation only — not yet wired into Coach templates or day stress.
enum CoachActivityLabeling {
    static func signals(
        for activity: CoachPlannedActivitySnapshot,
        activeCalories: Int? = nil,
        averageHeartRate: Double? = nil,
        distanceKm: Double? = nil,
        elevationGainMeters: Double? = nil,
        averagePaceMinPerKm: Double? = nil
    ) -> CoachActivityLabelSignals {
        let calories = activeCalories ?? (activity.calories > 0 ? activity.calories : nil)
        return CoachActivityLabelSignals(
            durationMinutes: activity.effectiveDurationMinutes,
            title: activity.title,
            type: activity.type,
            icon: activity.icon,
            imageName: activity.imageName,
            activeCalories: calories,
            averageHeartRate: averageHeartRate,
            distanceKm: distanceKm,
            elevationGainMeters: elevationGainMeters,
            averagePaceMinPerKm: averagePaceMinPerKm
        )
    }

    static func descriptor(
        for activity: CoachPlannedActivitySnapshot,
        activeCalories: Int? = nil,
        averageHeartRate: Double? = nil,
        distanceKm: Double? = nil,
        elevationGainMeters: Double? = nil,
        averagePaceMinPerKm: Double? = nil
    ) -> CoachActivityLabelDescriptor? {
        CoachActivityLabelBuilder.descriptor(
            for: signals(
                for: activity,
                activeCalories: activeCalories,
                averageHeartRate: averageHeartRate,
                distanceKm: distanceKm,
                elevationGainMeters: elevationGainMeters,
                averagePaceMinPerKm: averagePaceMinPerKm
            )
        )
    }
}
