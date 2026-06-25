import Foundation

enum CoachInputDataReadinessState: String, Hashable {
    case coherent
    case settling
}

struct CoachInputReadinessAssessment {
    let allowed: Bool
    let dataReadinessState: CoachInputDataReadinessState
    let satisfiedConditions: [String]
    let blockingReasons: [String]

    var summary: String {
        [
            "allowed=\(allowed)",
            "state=\(dataReadinessState.rawValue)",
            "satisfied=\(satisfiedConditions.joined(separator: ","))",
            "blocked=\(blockingReasons.joined(separator: ","))"
        ].joined(separator: " ")
    }
}

enum CoachInputReadiness {

    static func assessment(_ input: CoachInputSnapshot) -> CoachInputReadinessAssessment {
        var satisfied: [String] = []
        var blocked: [String] = []

        if input.nutritionContext != nil {
            satisfied.append("nutrition")
        } else {
            blocked.append("nutritionMissing")
        }

        if input.recoveryContext.recoveryPercent > 0 {
            satisfied.append("recoveryPercent")
        } else {
            blocked.append("recoveryPlaceholder")
        }

        if input.recoveryContext.sleepHours > 0 && input.brain.metrics.sleepHours > 0 {
            satisfied.append("sleepHours")
        } else {
            blocked.append("sleepPlaceholder")
        }

        if input.brain.sleep != .unknown {
            satisfied.append("sleepState")
        } else {
            blocked.append("sleepUnknown")
        }

        let readinessLooksPlaceholder = input.brain.sleep == .unknown &&
            input.recoveryContext.recoveryPercent <= 0 &&
            (input.brain.readiness == .low || input.brain.readiness == .compromised)
        if readinessLooksPlaceholder {
            blocked.append("readinessPlaceholder:\(input.brain.readiness)")
        } else {
            satisfied.append("readinessState")
        }

        let dayContextMatchesSelectedDate = Calendar.current.isDate(input.dayContext.date, inSameDayAs: input.selectedDate)
        let dayContextClockIsCurrent = abs(input.dayContext.now.timeIntervalSince(input.now)) < 2
        if dayContextMatchesSelectedDate && dayContextClockIsCurrent {
            satisfied.append("activityContext")
        } else {
            blocked.append("activityContextStale")
        }

        let allowed = blocked.isEmpty
        return CoachInputReadinessAssessment(
            allowed: allowed,
            dataReadinessState: allowed ? .coherent : .settling,
            satisfiedConditions: satisfied,
            blockingReasons: blocked
        )
    }
}
