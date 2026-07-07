import Foundation

enum CoachInputDataReadinessState: String, Hashable {
    case coherent
    case settling
    case limitedRecovery
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

/// Recovery ring presentation on Today — mirrors Coach readiness without routing changes.
enum CoachRecoveryRingMode: Equatable {
    case hasData
    case awaitingMorningSync
    case sleepNotRecorded
}

enum CoachInputReadiness {

    /// Local hour (inclusive) after which missing sleep/recovery stops blocking Coach.
    static let missingSleepCutoffHour = 10

    static func recoveryRingMode(
        isHealthAccessGranted: Bool,
        hasRecoverySignals: Bool,
        now: Date = Date()
    ) -> CoachRecoveryRingMode {
        if hasRecoverySignals {
            return .hasData
        }
        guard isHealthAccessGranted else {
            return .awaitingMorningSync
        }
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= missingSleepCutoffHour {
            return .sleepNotRecorded
        }
        return .awaitingMorningSync
    }

    static func assessment(_ input: CoachInputSnapshot) -> CoachInputReadinessAssessment {
        var satisfied: [String] = []
        var blocked: [String] = []

        if input.nutritionContext != nil {
            satisfied.append("nutrition")
        } else {
            blocked.append("nutritionMissing")
        }

        let recoveryDataAvailable = hasRecoveryData(input)
        var dataReadinessState: CoachInputDataReadinessState = .coherent

        if recoveryDataAvailable {
            appendFullRecoveryChecks(
                input: input,
                satisfied: &satisfied,
                blocked: &blocked
            )
        } else if input.isHealthAccessGranted {
            let hour = Calendar.current.component(.hour, from: input.now)
            if hour < missingSleepCutoffHour {
                blocked.append("recoveryAwaitingMorningSync")
                blocked.append("recoveryPlaceholder")
                blocked.append("sleepPlaceholder")
                blocked.append("sleepUnknown")
                if readinessLooksPlaceholder(input) {
                    blocked.append("readinessPlaceholder:\(input.brain.readiness)")
                }
            } else {
                satisfied.append("limitedRecoveryMode")
                dataReadinessState = .limitedRecovery
            }
        } else {
            blocked.append("healthNotConnected")
            blocked.append("recoveryPlaceholder")
            blocked.append("sleepPlaceholder")
            blocked.append("sleepUnknown")
            if readinessLooksPlaceholder(input) {
                blocked.append("readinessPlaceholder:\(input.brain.readiness)")
            }
        }

        let dayContextMatchesSelectedDate = Calendar.current.isDate(input.dayContext.date, inSameDayAs: input.selectedDate)
        let dayContextClockIsCurrent = abs(input.dayContext.now.timeIntervalSince(input.now)) < 2
        if dayContextMatchesSelectedDate && dayContextClockIsCurrent {
            satisfied.append("activityContext")
        } else {
            blocked.append("activityContextStale")
        }

        let allowed = blocked.isEmpty
        if !allowed {
            dataReadinessState = .settling
        } else if recoveryDataAvailable {
            dataReadinessState = .coherent
        }

        return CoachInputReadinessAssessment(
            allowed: allowed,
            dataReadinessState: dataReadinessState,
            satisfiedConditions: satisfied,
            blockingReasons: blocked
        )
    }

    private static func hasRecoveryData(_ input: CoachInputSnapshot) -> Bool {
        input.recoveryContext.recoveryPercent > 0 || input.recoveryContext.sleepHours > 0
    }

    private static func resolvedSleepHours(for input: CoachInputSnapshot) -> Double {
        max(input.recoveryContext.sleepHours, input.brain.metrics.sleepHours)
    }

    private static func appendFullRecoveryChecks(
        input: CoachInputSnapshot,
        satisfied: inout [String],
        blocked: inout [String]
    ) {
        if input.recoveryContext.recoveryPercent > 0 {
            satisfied.append("recoveryPercent")
        } else {
            blocked.append("recoveryPlaceholder")
        }

        if input.recoveryContext.sleepHours > 0 && resolvedSleepHours(for: input) > 0 {
            satisfied.append("sleepHours")
        } else {
            blocked.append("sleepPlaceholder")
        }

        if input.brain.sleep != .unknown {
            satisfied.append("sleepState")
        } else {
            blocked.append("sleepUnknown")
        }

        if readinessLooksPlaceholder(input) {
            blocked.append("readinessPlaceholder:\(input.brain.readiness)")
        } else {
            satisfied.append("readinessState")
        }
    }

    private static func readinessLooksPlaceholder(_ input: CoachInputSnapshot) -> Bool {
        input.brain.sleep == .unknown &&
            input.recoveryContext.recoveryPercent <= 0 &&
            (input.brain.readiness == .low || input.brain.readiness == .compromised)
    }
}
