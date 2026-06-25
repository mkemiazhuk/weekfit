import Foundation

struct CoachTomorrowDemandAssessment: Hashable {
    let level: CoachTomorrowDemand
    let primaryTrainingActivity: PlannedActivity?
    let trainingMinutes: Int
    let trainingStressScore: Int

    var hasDemand: Bool {
        level != .none
    }

    var isHard: Bool {
        level == .hard
    }
}

struct CoachTomorrowPlanContext {
    let dayContext: CoachDayContext
}

enum CoachTomorrowDemandResolver {

    static func resolve(tomorrowContext: CoachTomorrowPlanContext?) -> CoachTomorrowDemandAssessment {
        guard let tomorrowContext else {
            return CoachTomorrowDemandAssessment(
                level: .none,
                primaryTrainingActivity: nil,
                trainingMinutes: 0,
                trainingStressScore: 0
            )
        }

        return resolve(dayContext: tomorrowContext.dayContext)
    }

    static func resolve(dayContext: CoachDayContext) -> CoachTomorrowDemandAssessment {
        resolve(
            activities: dayContext.upcomingTrainingActivities,
            trainingMinutes: dayContext.upcomingTrainingMinutes,
            trainingStressScore: dayContext.upcomingTrainingStressScore
        )
    }

    static func resolve(activities: [PlannedActivity]) -> CoachTomorrowDemandAssessment {
        let trainingActivities = activities
            .filter { !$0.isSkipped }
            .filter(isTraining)
        let minutes = trainingActivities.reduce(0) { $0 + $1.effectiveDurationMinutes }
        let stress = trainingActivities.reduce(0) { $0 + stressScore($1) }

        return resolve(
            activities: trainingActivities,
            trainingMinutes: minutes,
            trainingStressScore: stress
        )
    }

    static func isTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolver.kind(for: activity)
        return kind == .workout || kind == .endurance
    }

    private static func resolve(
        activities: [PlannedActivity],
        trainingMinutes: Int,
        trainingStressScore: Int
    ) -> CoachTomorrowDemandAssessment {
        let primary = activities.max {
            CoachActivityContextResolver.load(for: $0).riskScore <
                CoachActivityContextResolver.load(for: $1).riskScore
        }
        let hasHardActivity = primary.map {
            let load = CoachActivityContextResolver.load(for: $0)
            return load == .high || load == .extreme
        } ?? false

        let level: CoachTomorrowDemand
        if trainingStressScore >= 3 || trainingMinutes >= 75 || hasHardActivity {
            level = .hard
        } else if trainingStressScore > 0 || trainingMinutes > 0 || primary != nil {
            level = trainingStressScore >= 2 || trainingMinutes >= 45 ? .moderate : .easy
        } else {
            level = .none
        }

        return CoachTomorrowDemandAssessment(
            level: level,
            primaryTrainingActivity: primary,
            trainingMinutes: trainingMinutes,
            trainingStressScore: trainingStressScore
        )
    }

    private static func stressScore(_ activity: PlannedActivity) -> Int {
        CoachActivityContextResolver.load(for: activity).riskScore
    }
}

private extension CoachActivityLoad {
    var riskScore: Int {
        switch self {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .extreme: return 4
        }
    }
}
