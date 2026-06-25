import Foundation

enum CoachScenarioConsistency {

    private static let postScenarios: Set<CoachScenarioKey> = [
        .postEnduranceImmediate, .postEnduranceSettled, .eveningAfterEndurance,
        .postRacketImmediate, .postRacketSettled, .eveningAfterRacket,
        .postStrengthImmediate, .postStrengthSettled, .eveningAfterStrength,
        .postRecoveryImmediate, .postRecoverySettled, .eveningAfterRecovery,
        .saunaRecovery
    ]

    private static let preActiveScenarios: Set<CoachScenarioKey> = [
        .activeEndurance, .activeRacket, .activeStrength, .activeRecovery,
        .saunaPreparation, .lowRecoveryPrep
    ]

    static func isConsistent(
        selection: CoachFocusSelection,
        scenario: CoachScenarioKey
    ) -> Bool {
        if selection.source == .upcoming {
            if postScenarios.contains(scenario) { return false }
            if scenario.sessionPhaseKind == .immediatePost || scenario.sessionPhaseKind == .settledPost {
                return false
            }
        }

        if selection.source == .recentCompleted {
            if preActiveScenarios.contains(scenario) && scenario != .lowRecoveryPrep {
                return false
            }
            if selection.phase == .pre || selection.phase == .during {
                return false
            }
        }

        if selection.source == .active {
            if postScenarios.contains(scenario) { return false }
            if selection.phase != .during && !duringScenarios.contains(scenario) {
                return false
            }
        }

        if postScenarios.contains(scenario) {
            guard selection.source == .recentCompleted else { return false }
            guard let scenarioFamily = scenario.activityFamily else { return false }
            guard selection.family == scenarioFamily else { return false }
        }

        if let scenarioFamily = scenario.activityFamily,
           selection.source != .idle,
           selection.family != .none {
            if walkScenarios.contains(scenario) {
                guard selection.type == .walk else { return false }
            } else if heatScenarios.contains(scenario) {
                guard selection.family == .heat else { return false }
            } else if scenarioFamily != .recovery || mindfulRecoveryScenarios.contains(scenario) {
                guard selection.family == scenarioFamily else { return false }
            }
        }

        return true
    }

    static func assertConsistent(
        selection: CoachFocusSelection,
        scenario: CoachScenarioKey,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assert(
            isConsistent(selection: selection, scenario: scenario),
            "Scenario \(scenario.rawValue) inconsistent with focus source \(selection.source.rawValue), family \(selection.family.rawValue), phase \(selection.phase.rawValue)",
            file: file,
            line: line
        )
    }

    private static let duringScenarios: Set<CoachScenarioKey> = [
        .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
        .saunaActive, .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction
    ]

    private static let walkScenarios: Set<CoachScenarioKey> = [
        .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction
    ]

    private static let heatScenarios: Set<CoachScenarioKey> = [
        .saunaPreparation, .saunaActive, .saunaRecovery
    ]

    private static let mindfulRecoveryScenarios: Set<CoachScenarioKey> = [
        .activeRecovery, .duringRecovery, .postRecoveryImmediate,
        .postRecoverySettled, .eveningAfterRecovery
    ]
}

private extension CoachScenarioKey {
    enum SessionPhaseKind {
        case pre
        case during
        case immediatePost
        case settledPost
        case evening
        case idle
    }

    var sessionPhaseKind: SessionPhaseKind {
        switch self {
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery,
             .saunaPreparation, .lowRecoveryPrep:
            return .pre
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .saunaActive, .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction:
            return .during
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return .immediatePost
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled, .saunaRecovery:
            return .settledPost
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return .evening
        case .stableDay, .morningReadiness, .tomorrowProtection, .protectTomorrowFresh, .recoveryAfterHeavyYesterday:
            return .idle
        }
    }
}
