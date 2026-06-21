import Foundation
@testable import WeekFit

// MARK: - Phase 3 matrix grouping

enum CoachNarrativeMatrixGroup: String, CaseIterable {
    case calmOverview = "A. Calm day / daily overview"
    case recoveryNeeded = "B. Recovery-needed day"
    case workoutPrep = "C. Workout preparation"
    case activeSession = "D. Active session"
    case postWorkout = "E. Post-workout recovery"
    case restAfterLoad = "F. Rest day after load"
    case eveningWindDown = "G. Evening wind-down"
    case tomorrowProtection = "H. Tomorrow protection"
    case nutritionLed = "I. Nutrition-led support"
    case hydrationLed = "J. Hydration-led support"
    case saunaHeat = "K. Sauna / heat"
    case syncEdgeCases = "L. Apple Watch sync reconciliation"
    case missingStaleData = "M. Missing / stale data"
}

enum CoachNarrativeMatrixRunBatch: String, CaseIterable {
    case morning
    case workoutPrep
    case active
    case postWorkout
    case nutritionHydration
    case syncAndPlanner
}

// MARK: - Scenario dimensions

enum CoachNarrativeTimeSlot: String {
    case earlyMorning = "06:30"
    case normalMorning = "09:00"
    case lateMorning = "11:30"
    case afternoon = "15:00"
    case evening = "20:30"
    case lateNight = "23:30"

    var hour: Int {
        switch self {
        case .earlyMorning: return 6
        case .normalMorning: return 9
        case .lateMorning: return 11
        case .afternoon: return 15
        case .evening: return 20
        case .lateNight: return 23
        }
    }

    var minute: Int {
        switch self {
        case .earlyMorning: return 30
        case .lateMorning: return 30
        case .evening: return 30
        case .lateNight: return 30
        default: return 0
        }
    }

    var isEarlyMorning: Bool { self == .earlyMorning || self == .normalMorning }
}

enum CoachNarrativeRecoveryBand: String {
    case excellent
    case good
    case moderate
    case low
    case veryLow

    var percent: Int {
        switch self {
        case .excellent: return 95
        case .good: return 82
        case .moderate: return 67
        case .low: return 48
        case .veryLow: return 22
        }
    }

    var tier: CoachNarrativeScenarioExpectation.RecoveryTier {
        switch self {
        case .excellent, .good: return .high
        case .moderate: return .moderate
        case .low: return .low
        case .veryLow: return .depleted
        }
    }
}

enum CoachNarrativeRecoveryDriver: String {
    case balanced
    case goodSleepLowReadiness
    case shortSleepBalancedSignals
    case fragmentedSleep
    case highRestingHeartRate
    case missingSleepData
    case missingRecoveryScore
    case staleRecoverySnapshot
}

enum CoachNarrativeActivityShape: String {
    case none
    case easyWalkPlanned
    case runPlanned
    case longRidePlanned
    case strengthPlanned
    case saunaPlanned
    case activeWalk
    case activeRun
    case activeLongRide
    case activeStrength
    case activeSauna
    case easyWalkCompleted
    case hardRunCompleted
    case longRideCompleted
    case strengthCompleted
    case skippedActivity
    case syncedWalkNoPlanMatch
    case syncedWalkFutureCoffeeCandidate
    case syncedWalkFuturePlannedWalk
}

enum CoachNarrativeActivityTiming: String {
    case activeNow
    case startsIn15Min
    case startsIn45Min
    case startsIn2Hours
    case startsIn6Hours
    case completed30MinAgo
    case completed3HoursAgo
}

enum CoachNarrativeNutritionShape: String {
    case normal
    case emptyEarlyMorning
    case emptyAfternoon
    case underFueledBeforeWorkout
    case underFueledAfterWorkout
    case strongAdherence
    case highCaloriesLowProtein
    case missingData
}

enum CoachNarrativeHydrationShape: String {
    case normal
    case noWaterEarlyMorning
    case noWaterAfternoon
    case lowBeforeEndurance
    case lowBeforeSauna
    case heatDayLowWater
}

enum CoachNarrativePlannerShape: String {
    case empty
    case light
    case hardSingle
    case fullStructured
    case recoveryOnly
    case mixedTrainingRecovery
}

// MARK: - Scenario contract context

struct CoachNarrativeMatrixContext {
    let time: CoachNarrativeTimeSlot
    let recoveryBand: CoachNarrativeRecoveryBand
    let recoveryDriver: CoachNarrativeRecoveryDriver
    let activity: CoachNarrativeActivityShape
    let activityTiming: CoachNarrativeActivityTiming?
    let nutrition: CoachNarrativeNutritionShape
    let hydration: CoachNarrativeHydrationShape
    let planner: CoachNarrativePlannerShape
    let tomorrowHardSession: Bool

    var hasActiveSession: Bool {
        switch activity {
        case .activeWalk, .activeRun, .activeLongRide, .activeStrength, .activeSauna:
            return true
        default:
            return activityTiming == .activeNow
        }
    }

    var hasCompletedWorkout: Bool {
        switch activity {
        case .easyWalkCompleted, .hardRunCompleted, .longRideCompleted, .strengthCompleted,
             .syncedWalkNoPlanMatch, .syncedWalkFutureCoffeeCandidate, .syncedWalkFuturePlannedWalk:
            return true
        default:
            return activityTiming == .completed30MinAgo || activityTiming == .completed3HoursAgo
        }
    }

    var hasPlannedWorkoutInPrepWindow: Bool {
        guard let timing = activityTiming else { return false }
        switch timing {
        case .startsIn15Min, .startsIn45Min, .startsIn2Hours:
            switch activity {
            case .runPlanned, .longRidePlanned, .strengthPlanned, .easyWalkPlanned, .saunaPlanned:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    var hasWorkoutContext: Bool {
        hasActiveSession || hasCompletedWorkout || hasPlannedWorkoutInPrepWindow ||
            activityTiming == .startsIn6Hours ||
            [.runPlanned, .longRidePlanned, .strengthPlanned, .easyWalkPlanned, .saunaPlanned].contains(activity)
    }

    var plannedActivityKind: String? {
        switch activity {
        case .runPlanned, .activeRun, .hardRunCompleted: return "run"
        case .longRidePlanned, .activeLongRide, .longRideCompleted: return "ride"
        case .strengthPlanned, .activeStrength, .strengthCompleted: return "strength"
        case .easyWalkPlanned, .activeWalk, .easyWalkCompleted, .syncedWalkNoPlanMatch,
             .syncedWalkFutureCoffeeCandidate, .syncedWalkFuturePlannedWalk: return "walk"
        case .saunaPlanned, .activeSauna: return "sauna"
        default: return nil
        }
    }

    var hasFuelGap: Bool {
        switch nutrition {
        case .emptyEarlyMorning, .emptyAfternoon, .underFueledBeforeWorkout, .underFueledAfterWorkout,
             .highCaloriesLowProtein, .missingData:
            return true
        default:
            return false
        }
    }

    var hasHydrationGap: Bool {
        switch hydration {
        case .noWaterEarlyMorning, .noWaterAfternoon, .lowBeforeEndurance, .lowBeforeSauna, .heatDayLowWater:
            return true
        default:
            return false
        }
    }

    var sleepTier: CoachNarrativeScenarioExpectation.SleepTier {
        switch recoveryDriver {
        case .balanced, .goodSleepLowReadiness, .shortSleepBalancedSignals:
            return recoveryBand == .excellent ? .excellent : .adequate
        case .fragmentedSleep, .highRestingHeartRate:
            return .fragmented
        case .missingSleepData, .missingRecoveryScore, .staleRecoverySnapshot:
            return .adequate
        }
    }
}

struct CoachNarrativeMatrixScenario {
    let id: Int
    let group: CoachNarrativeMatrixGroup
    let name: String
    let inputSummary: String
    let intent: String
    let context: CoachNarrativeMatrixContext
    let makeState: () -> CoachState

    var runBatch: CoachNarrativeMatrixRunBatch {
        switch group {
        case .calmOverview, .recoveryNeeded, .missingStaleData:
            return .morning
        case .workoutPrep:
            return .workoutPrep
        case .activeSession:
            return .active
        case .postWorkout, .restAfterLoad, .eveningWindDown:
            return .postWorkout
        case .nutritionLed, .hydrationLed:
            return .nutritionHydration
        case .tomorrowProtection, .saunaHeat, .syncEdgeCases:
            return .syncAndPlanner
        }
    }
}

// MARK: - Audit types

enum CoachNarrativeIssueClass: String, Codable {
    case stateOwnerBug = "State/owner bug"
    case contextSelectionBug = "Context selection bug"
    case evidenceMismatch = "Evidence mismatch"
    case copyQuality = "Copy quality issue"
    case heuristicFalsePositive = "Heuristic false positive"
}

enum CoachNarrativeContractFlag: String, CaseIterable, Codable {
    case ownerPriorityMismatch = "Owner/priority mismatch"
    case badgeMismatch = "Badge mismatch with owner"
    case activeContextViolation = "Active session contract violation"
    case plannedWorkoutViolation = "Planned workout contract violation"
    case noWorkoutContextViolation = "Workout language without workout context"
    case recoverySeverityViolation = "Recovery severity contract violation"
    case nutritionTimingViolation = "Nutrition timing contract violation"
    case hydrationTimingViolation = "Hydration timing contract violation"
    case sleepRecoveryEvidenceViolation = "Recovery evidence claim mismatch"
    case internalCopyContradiction = "Contradiction within story copy"
    case todayCoachMisalignment = "Today card vs Coach screen mismatch"
    case duplicateTemplate = "Duplicate/template fatigue"
    case rawMetricRepetition = "Raw metric repetition"
    case activityMismatch = "Activity type mismatch"
    case syncEdgeCaseViolation = "Apple Watch sync edge case violation"
    case roboticCopy = "Robotic or dashboard-like copy"
    case rawLocalizationKey = "Raw localization key leaked"
    case emptyVisibleSection = "Expected visible section is empty"
}

struct CoachNarrativeContractFinding: Equatable, Codable {
    let flag: CoachNarrativeContractFlag
    let severity: CoachNarrativeAuditSeverity
    let issueClass: CoachNarrativeIssueClass
    let detail: String
}

struct CoachNarrativeFullStorySnapshot: Equatable, Codable {
    let phase: String
    let priority: String
    let owner: String
    let intent: String
    let badge: String
    let title: String
    let read: String
    let recommendation: String
    let careful: String
    let why: [String]
    let supportItems: [String]
    let todayTitle: String
    let todaySubtitle: String
    let coachTitle: String
    let coachRead: String
    let coachRecommendation: String
    let coachCareful: String
    let coachWhy: [String]
}

struct CoachNarrativeContractAuditResult: Equatable {
    let snapshot: CoachNarrativeFullStorySnapshot
    let findings: [CoachNarrativeContractFinding]

    var severity: CoachNarrativeAuditSeverity {
        if findings.contains(where: { $0.severity == .fail }) { return .fail }
        if findings.contains(where: { $0.severity == .warn }) { return .warn }
        return .pass
    }

    var isBlocking: Bool { severity == .fail }

    var p0Findings: [CoachNarrativeContractFinding] {
        findings.filter { $0.severity == .fail && $0.issueClass != .heuristicFalsePositive }
    }

    var p1Findings: [CoachNarrativeContractFinding] {
        findings.filter { $0.severity == .warn && $0.issueClass == .copyQuality }
    }
}

struct CoachNarrativeMatrixAuditRow {
    let scenario: CoachNarrativeMatrixScenario
    let result: CoachNarrativeContractAuditResult
}
