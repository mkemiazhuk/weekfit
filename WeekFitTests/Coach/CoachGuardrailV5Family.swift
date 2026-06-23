import Foundation
@testable import WeekFit

/// V5 narrative family mapping for guardrail contract tests only.
enum CoachGuardrailV5Family: String, Hashable, CaseIterable {
    case inSession
    case getReady
    case adjust
    case recover
    case steadyDay
    case windDown
    case heatSauna

    var isBehaviorChange: Bool {
        switch self {
        case .steadyDay, .heatSauna:
            return false
        default:
            return true
        }
    }

    static var behaviorChangeFamilies: [CoachGuardrailV5Family] {
        allCases.filter(\.isBehaviorChange)
    }

    static func from(story: CoachFinalStory) -> CoachGuardrailV5Family {
        from(owner: story.owner, focus: story.primaryFocus)
    }

    static func from(owner: CoachFinalStoryOwner, focus: CoachDayFocus?) -> CoachGuardrailV5Family {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution, .fuelingDuringActivity, .hydrationExecution:
            return .inSession
        case .activityPreparation:
            return .getReady
        case .readiness:
            return .adjust
        case .postActivityRecovery, .recovery:
            return .recover
        case .tomorrowProtection:
            return .windDown
        case .hydration, .fuel:
            return .steadyDay
        case .stableOverview:
            if focus == .eveningWindDown || focus == .tomorrowPlanRisk {
                return .windDown
            }
            return .steadyDay
        }
    }

    static func from(priority: CoachDayPriorityResult) -> CoachGuardrailV5Family? {
        switch priority.focus {
        case .activeActivity:
            return .inSession
        case .prepareForActivity, .nextActivityLater, .performanceReadiness:
            return .getReady
        case .trainingReadinessWarning:
            return .adjust
        case .postActivityRecovery, .recoveryNeeded:
            return .recover
        case .eveningWindDown, .tomorrowPlanRisk:
            return .windDown
        case .hydrationBehind, .fuelBehind, .dailyOverview:
            return nil
        }
    }
}
