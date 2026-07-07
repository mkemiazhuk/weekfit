import XCTest
@testable import WeekFit

final class CoachUIPresentationCoverageTests: XCTestCase {

    func testAllScenariosProduceValidCoachUIPresentation() throws {
        for scenario in CoachScenarioKey.allCases {
            let copyInput = CoachCopyQualityTests.baselineInput(for: scenario)
            let pack = try XCTUnwrap(
                CoachCopyRegistry.resolve(copyInput),
                "missing copy pack for \(scenario.rawValue)"
            )
            let engineResult = CoachTestEngineResultBuilder.make(from: copyInput, pack: pack)
            let presentation = try XCTUnwrap(
                CoachTabPresentationBridge.build(from: engineResult),
                "bridge returned nil for \(scenario.rawValue)"
            )

            XCTAssertFalse(presentation.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.todayMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertFalse(presentation.recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.rawValue)
            XCTAssertEqual(presentation.scenario, scenario)
        }
    }

    func testTeaserCopyCoversAllScenarios() {
        for scenario in CoachScenarioKey.allCases {
            let copyInput = CoachCopyQualityTests.baselineInput(for: scenario)
            let pack = CoachCopyRegistry.resolve(copyInput)
            XCTAssertNotNil(pack, scenario.rawValue)

            let engineResult = CoachTestEngineResultBuilder.make(
                from: copyInput,
                pack: pack!
            )
            let teaser = CoachTeaserCopy.resolve(
                from: engineResult,
                localizedAssessment: "Assessment"
            )

            XCTAssertFalse(teaser.todayTitle.english.isEmpty, "\(scenario.rawValue) todayTitle en")
            XCTAssertFalse(teaser.todayTitle.russian.isEmpty, "\(scenario.rawValue) todayTitle ru")
            XCTAssertFalse(teaser.coachHeadline.english.isEmpty, "\(scenario.rawValue) coachHeadline en")
            XCTAssertFalse(teaser.coachHeadline.russian.isEmpty, "\(scenario.rawValue) coachHeadline ru")
        }
    }
}

enum CoachTestEngineResultBuilder {

    static func make(from input: CoachCopyBuildInput, pack: CoachCopyPack) -> CoachEngine.Result {
        let context = CoachContext(
            activityFamily: input.scenario.activityFamily ?? .none,
            activityType: input.activityType,
            activityState: activityState(for: input.scenario),
            sessionPhase: sessionPhase(for: input.scenario),
            durationBand: input.modifiers.durationBand,
            dayLoadBand: input.modifiers.dayLoad,
            completedSeriousActivities: input.modifiers.completedSeriousActivities,
            fuelState: input.fuelState,
            hydrationState: input.hydrationState,
            tomorrowDemand: input.modifiers.tomorrowDemand,
            timeOfDay: input.modifiers.timeOfDay,
            tomorrowWorkout: input.tomorrowWorkout,
            focusActivityID: "coverage-\(input.scenario.rawValue)",
            focusSource: focusSource(for: input.scenario),
            minutesUntilStart: nil,
            minutesSinceEnd: minutesSinceEnd(for: input.scenario),
            dayReadiness: input.dayReadiness,
            lastCompletedSeriousActivityType: input.modifiers.lastCompletedActivityType
        )
        let resolution = CoachScenarioResolution(
            scenario: input.scenario,
            modifiers: input.modifiers,
            safetyAlert: input.safetyAlert
        )
        let insight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        return CoachEngine.Result(
            context: context,
            resolution: resolution,
            todayInsight: insight,
            copyPack: pack,
            morningBriefFacts: nil
        )
    }

    private static func sessionPhase(for scenario: CoachScenarioKey) -> CoachSessionPhase {
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery, .saunaActive:
            return .during
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return .immediatePost
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled, .saunaRecovery:
            return .settledPost
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return .evening
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation:
            return .pre
        case .tomorrowProtection:
            return .tomorrowProtection
        default:
            return .idle
        }
    }

    private static func activityState(for scenario: CoachScenarioKey) -> CoachActivityState {
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery, .saunaActive:
            return .active
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return .justFinished
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled, .saunaRecovery:
            return .finished
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation:
            return .upcoming
        default:
            return .none
        }
    }

    private static func focusSource(for scenario: CoachScenarioKey) -> CoachFocusSource {
        switch activityState(for: scenario) {
        case .active:
            return .active
        case .justFinished, .finished:
            return .recentCompleted
        case .upcoming:
            return .upcoming
        case .none:
            return .idle
        }
    }

    private static func minutesSinceEnd(for scenario: CoachScenarioKey) -> Int? {
        switch scenario {
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return 8
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled, .saunaRecovery:
            return 45
        default:
            return nil
        }
    }
}
