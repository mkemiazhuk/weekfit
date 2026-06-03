import Foundation

enum CoachActivityScenarioResolver {

    static func resolve(
        phase: CoachActivityPhaseV3,
        brain: HumanBrain.State
    ) -> CoachActivityScenario {

        switch phase {

        case .preparing(let activity, let kind, let minutesUntil):
            let load = CoachActivityContextResolverV3.load(for: activity)

            return CoachActivityScenario(
                stage: .before,
                archetype: archetype(kind: kind, load: load, activity: activity),
                kind: kind,
                load: load,
                durationBucket: durationBucket(activity.durationMinutes),
                dayTime: dayTime(from: brain.currentHour),
                activity: activity,
                minutesUntilStart: minutesUntil,
                minutesSinceEnd: nil
            )

        case .active(let activity, let kind):
            let load = CoachActivityContextResolverV3.load(for: activity)

            return CoachActivityScenario(
                stage: .during,
                archetype: archetype(kind: kind, load: load, activity: activity),
                kind: kind,
                load: load,
                durationBucket: durationBucket(activity.durationMinutes),
                dayTime: dayTime(from: brain.currentHour),
                activity: activity,
                minutesUntilStart: nil,
                minutesSinceEnd: nil
            )

        case .recovering(let activity, let kind, let minutesSinceEnd):
            let load = CoachActivityContextResolverV3.load(for: activity)

            return CoachActivityScenario(
                stage: .after,
                archetype: archetype(kind: kind, load: load, activity: activity),
                kind: kind,
                load: load,
                durationBucket: durationBucket(activity.durationMinutes),
                dayTime: dayTime(from: brain.currentHour),
                activity: activity,
                minutesUntilStart: nil,
                minutesSinceEnd: minutesSinceEnd
            )

        case .stable:
            return CoachActivityScenario(
                stage: .stable,
                archetype: .stable,
                kind: .other,
                load: .low,
                durationBucket: .under30,
                dayTime: dayTime(from: brain.currentHour),
                activity: nil,
                minutesUntilStart: nil,
                minutesSinceEnd: nil
            )
        }
    }

    // MARK: - Archetype

    private static func archetype(
        kind: CoachActivityKindV3,
        load: CoachActivityLoadV3,
        activity: PlannedActivity
    ) -> CoachActivityArchetype {

        switch kind {

        case .heat:
            return .heat

        case .meal:
            // Meals are intentionally not Coach moments.
            return .stable

        case .recovery:
            return .recovery

        case .workout:
            return .performance

        case .endurance:
            // IMPORTANT:
            // Running / cycling / cardio should stay endurance even when load is low.
            // Otherwise Coach incorrectly turns an upcoming run into "Evening Recovery".
            //
            // Only easy walk / hike can behave as recovery when load is low.
            if load == .low && isWalkLike(activity) {
                return .recovery
            }

            return .endurance

        case .other:
            return .stable
        }
    }

    // MARK: - Buckets

    private static func durationBucket(_ minutes: Int) -> CoachDurationBucket {
        if minutes < 30 {
            return .under30
        }

        if minutes < 60 {
            return .thirtyTo60
        }

        if minutes < 90 {
            return .sixtyTo90
        }

        return .over90
    }

    private static func dayTime(from hour: Int) -> CoachDayTime {
        switch hour {
        case 5..<10:
            return .morning
        case 10..<12:
            return .preLunch
        case 12..<14:
            return .lunch
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        case 21..<24:
            return .lateEvening
        default:
            return .night
        }
    }

    // MARK: - Helpers

    private static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title)".lowercased()

        return text.contains("walk") ||
               text.contains("walking") ||
               text.contains("hike")
    }
}
