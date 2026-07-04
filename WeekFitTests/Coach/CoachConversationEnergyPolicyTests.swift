import XCTest
@testable import WeekFit

final class CoachConversationEnergyPolicyTests: XCTestCase {

    // MARK: - Energy classification

    func testSeriousWorkoutActiveAndDuringAreHigh() {
        XCTAssertEqual(energy(for: .activeEndurance), .high)
        XCTAssertEqual(energy(for: .activeRacket), .high)
        XCTAssertEqual(energy(for: .activeStrength), .high)
        XCTAssertEqual(energy(for: .duringEndurance), .high)
        XCTAssertEqual(energy(for: .duringRacket), .high)
        XCTAssertEqual(energy(for: .duringStrength), .high)
    }

    func testSeriousWorkoutPostImmediateIsMedium() {
        XCTAssertEqual(energy(for: .postEnduranceImmediate), .medium)
        XCTAssertEqual(energy(for: .postRacketImmediate), .medium)
        XCTAssertEqual(energy(for: .postStrengthImmediate), .medium)
    }

    func testSeriousWorkoutSettledAndEveningAreLow() {
        for scenario in [
            CoachScenarioKey.postEnduranceSettled,
            .postRacketSettled,
            .postStrengthSettled,
            .eveningAfterEndurance,
            .eveningAfterRacket,
            .eveningAfterStrength
        ] {
            XCTAssertEqual(energy(for: scenario), .low, scenario.rawValue)
        }
    }

    func testRecoveryWalkAndYogaPhasesAreLow() {
        for scenario in [
            CoachScenarioKey.walkAfterHeavyLoad,
            .walkRecoveryAction,
            .activeRecovery,
            .duringRecovery,
            .postRecoveryImmediate
        ] {
            XCTAssertEqual(energy(for: scenario), .low, scenario.rawValue)
        }
    }

    func testSaunaPreparationAndRecoveryAreLow() {
        XCTAssertEqual(energy(for: .saunaPreparation), .low)
        XCTAssertEqual(energy(for: .saunaRecovery), .low)
    }

    func testSaunaActiveIsHigh() {
        XCTAssertEqual(energy(for: .saunaActive), .high)
    }

    func testSafetyCriticalOverridesToHigh() throws {
        let input = CoachCopyQualityTests.baselineInput(for: .duringEndurance)
        let criticalInput = CoachCopyBuildInput(
            scenario: input.scenario,
            modifiers: input.modifiers,
            athleteState: input.athleteState,
            fuelState: input.fuelState,
            hydrationState: input.hydrationState,
            safetyAlert: .hydrationCritical,
            semanticColor: input.semanticColor,
            alertSeverity: .critical,
            tomorrowWorkout: input.tomorrowWorkout,
            dayReadiness: input.dayReadiness,
            focusSource: input.focusSource,
            sessionPhase: input.sessionPhase,
            activityState: input.activityState,
            minutesSinceEnd: input.minutesSinceEnd,
            conversationPhase: input.conversationPhase,
            morningBriefFacts: input.morningBriefFacts,
            mealWindowOpen: input.mealWindowOpen,
            dehydrationRisk: input.dehydrationRisk
        )
        XCTAssertEqual(
            CoachConversationEnergyPolicy.resolve(input: criticalInput),
            .high
        )
    }

    // MARK: - Known badge mismatches fixed

    func testRecoveryWalkScenariosUseLowRecoveringBadge() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        for scenario in [CoachScenarioKey.walkAfterHeavyLoad, .walkRecoveryAction] {
            let presentation = try presentation(for: scenario)
            XCTAssertEqual(presentation.conversationEnergy, .low, scenario.rawValue)
            XCTAssertEqual(presentation.urgencyLevel, .calm, scenario.rawValue)
            XCTAssertEqual(presentation.statusLabel, "ВОССТАНАВЛИВАЕМСЯ", scenario.rawValue)
        }
    }

    func testRecoveryYogaScenariosUseLowRecoveringBadge() throws {
        WeekFitSetCurrentLanguage(.english)
        defer { WeekFitSetCurrentLanguage(.english) }

        for scenario in [
            CoachScenarioKey.activeRecovery,
            .duringRecovery,
            .postRecoveryImmediate
        ] {
            let presentation = try presentation(for: scenario)
            XCTAssertEqual(presentation.conversationEnergy, .low, scenario.rawValue)
            XCTAssertEqual(presentation.urgencyLevel, .calm, scenario.rawValue)
            XCTAssertEqual(presentation.statusLabel, "RECOVERING", scenario.rawValue)
            XCTAssertEqual(presentation.semanticColor, .recovery, scenario.rawValue)
        }
    }

    func testSaunaPreparationUsesLowBadge() throws {
        WeekFitSetCurrentLanguage(.english)
        defer { WeekFitSetCurrentLanguage(.english) }

        let presentation = try presentation(for: .saunaPreparation)
        XCTAssertEqual(presentation.conversationEnergy, .low)
        XCTAssertEqual(presentation.statusLabel, "RECOVERING")
        XCTAssertEqual(presentation.urgencyLevel, .calm)
    }

    func testSaunaActiveUsesLiveBadge() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let presentation = try presentation(for: .saunaActive)
        XCTAssertEqual(presentation.conversationEnergy, .high)
        XCTAssertEqual(presentation.urgencyLevel, .live)
        XCTAssertEqual(presentation.statusLabel, "СЕЙЧАС")
    }

    // MARK: - Baseline energy audit (33 scenarios)

    func testBaselineConversationEnergyMatchesIntent() {
        var failures: [String] = []
        for scenario in CoachScenarioKey.allCases {
            let expected = expectedEnergy(for: scenario)
            let actual = energy(for: scenario)
            if actual != expected {
                failures.append("\(scenario.rawValue): expected \(expected), got \(actual)")
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testBaselineBadgeAlignsWithConversationEnergy() {
        var failures: [String] = []

        for scenario in CoachScenarioKey.allCases {
            guard let result = engineResult(for: scenario) else {
                failures.append("\(scenario.rawValue): missing engine result")
                continue
            }
            let energy = result.todayInsight.conversationEnergy
            let urgency = result.todayInsight.urgencyLevel

            switch energy {
            case .low:
                if urgency != .calm {
                    failures.append("\(scenario.rawValue): low energy should be calm urgency, got \(urgency)")
                }
            case .medium:
                if urgency != .protective {
                    failures.append("\(scenario.rawValue): medium energy should be protective urgency, got \(urgency)")
                }
            case .high:
                if urgency != .focused && urgency != .live && urgency != .critical {
                    failures.append("\(scenario.rawValue): high energy has weak urgency \(urgency)")
                }
            }

            if !badgeMatchesEnergy(
                energy: energy,
                statusLabelEN: badgeLabel(for: result, russian: false),
                statusLabelRU: badgeLabel(for: result, russian: true),
                scenario: scenario,
                safetyAlert: result.todayInsight.safetyAlert,
                stacked: result.modifiers.stackedDayActiveRisk
            ) {
                failures.append(
                    "\(scenario.rawValue): badge mismatch for energy \(energy) — " +
                    "EN=\(badgeLabel(for: result, russian: false)) " +
                    "RU=\(badgeLabel(for: result, russian: true))"
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    // MARK: - Badge snapshots EN + RU

    func testBadgeLabelSnapshotsEnglish() throws {
        let report = badgeSnapshotReport(russian: false)
        XCTAssertFalse(report.isEmpty)
        // Spot-check key scenarios
        XCTAssertTrue(report.contains("walkAfterHeavyLoad: RECOVERING"))
        XCTAssertTrue(report.contains("duringEndurance: LIVE"))
        XCTAssertTrue(report.contains("saunaActive: LIVE"))
        XCTAssertTrue(report.contains("stableDay: ALL GOOD"))
    }

    func testBadgeLabelSnapshotsRussian() throws {
        let report = badgeSnapshotReport(russian: true)
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("walkAfterHeavyLoad: ВОССТАНАВЛИВАЕМСЯ"))
        XCTAssertTrue(report.contains("duringEndurance: СЕЙЧАС"))
        XCTAssertTrue(report.contains("saunaActive: СЕЙЧАС"))
        XCTAssertTrue(report.contains("stableDay: ВСЁ ХОРОШО"))
    }

    // MARK: - Helpers

    private func energy(for scenario: CoachScenarioKey) -> CoachConversationEnergy {
        CoachConversationEnergyPolicy.resolve(
            input: CoachCopyQualityTests.baselineInput(for: scenario)
        )
    }

    private func expectedEnergy(for scenario: CoachScenarioKey) -> CoachConversationEnergy {
        switch scenario {
        case .stableDay, .morningReadiness, .recoveryAfterHeavyYesterday,
             .walkLightDay, .walkEveningWindDown, .walkAfterHeavyLoad, .walkRecoveryAction,
             .activeRecovery, .duringRecovery, .postRecoveryImmediate, .postRecoverySettled,
             .eveningAfterRecovery,
             .postEnduranceSettled, .postRacketSettled, .postStrengthSettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength,
             .saunaPreparation, .saunaRecovery:
            return .low
        case .tomorrowProtection, .protectTomorrowFresh, .lowRecoveryPrep,
             .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate:
            return .medium
        case .saunaActive:
            return .high
        case .activeEndurance, .activeRacket, .activeStrength,
             .duringEndurance, .duringRacket, .duringStrength:
            return .high
        }
    }

    private struct PresentationSnapshot {
        let conversationEnergy: CoachConversationEnergy
        let urgencyLevel: CoachUrgencyLevel
        let statusLabel: String
        let semanticColor: CoachSemanticColor
    }

    private func presentation(for scenario: CoachScenarioKey) throws -> PresentationSnapshot {
        let result = try XCTUnwrap(engineResult(for: scenario))
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        return PresentationSnapshot(
            conversationEnergy: result.todayInsight.conversationEnergy,
            urgencyLevel: bridge.urgencyLevel,
            statusLabel: bridge.statusLabel,
            semanticColor: bridge.semanticColor
        )
    }

    private func engineResult(for scenario: CoachScenarioKey) -> CoachEngine.Result? {
        let input = CoachCopyQualityTests.baselineInput(for: scenario)
        guard let pack = CoachCopyRegistry.resolve(input) else { return nil }

        let context = CoachContext(
            activityFamily: scenario.activityFamily ?? .none,
            activityType: input.modifiers.activityType,
            activityState: activityState(for: scenario),
            sessionPhase: sessionPhase(for: scenario),
            durationBand: input.modifiers.durationBand,
            dayLoadBand: input.modifiers.dayLoad,
            completedSeriousActivities: input.modifiers.completedSeriousActivities,
            fuelState: input.fuelState,
            hydrationState: input.hydrationState,
            tomorrowDemand: input.modifiers.tomorrowDemand,
            timeOfDay: input.modifiers.timeOfDay,
            tomorrowWorkout: input.tomorrowWorkout,
            focusActivityID: scenario.activityFamily == nil ? nil : "energy-\(scenario.rawValue)",
            focusSource: focusSource(for: scenario),
            minutesUntilStart: isPreSession(scenario) ? 12 : nil,
            minutesSinceEnd: isPostSession(scenario) ? 8 : nil,
            dayReadiness: input.dayReadiness,
            lastCompletedSeriousActivityType: input.modifiers.lastCompletedActivityType,
            conversationPhase: input.conversationPhase
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
            morningBriefFacts: input.morningBriefFacts
        )
    }

    private func badgeLabel(for result: CoachEngine.Result, russian: Bool) -> String {
        if russian {
            WeekFitSetCurrentLanguage(.russian)
        } else {
            WeekFitSetCurrentLanguage(.english)
        }
        return CoachTabPresentationBridge.build(from: result)?.statusLabel ?? "—"
    }

    private func badgeSnapshotReport(russian: Bool) -> String {
        CoachScenarioKey.allCases.map { scenario in
            guard let result = engineResult(for: scenario) else {
                return "\(scenario.rawValue): —"
            }
            let label = badgeLabel(for: result, russian: russian)
            return "\(scenario.rawValue): \(label)"
        }.joined(separator: "\n")
    }

    private func badgeMatchesEnergy(
        energy: CoachConversationEnergy,
        statusLabelEN: String,
        statusLabelRU: String,
        scenario: CoachScenarioKey,
        safetyAlert: CoachSafetyAlert?,
        stacked: Bool
    ) -> Bool {
        if safetyAlert != nil {
            return statusLabelEN == "IMPORTANT" && statusLabelRU == "ВАЖНО"
        }
        if stacked {
            return statusLabelEN == "ATTENTION" && statusLabelRU == "ВНИМАНИЕ"
        }

        let profile = CoachStableDayProfile.resolve(
            scenario: scenario,
            modifiers: CoachCopyQualityTests.baselineInput(for: scenario).modifiers,
            dayReadiness: CoachCopyQualityTests.baselineInput(for: scenario).dayReadiness
        )
        let labels = CoachConversationEnergyBadge.resolve(
            energy: energy,
            scenario: scenario,
            safetyAlert: nil,
            stackedDayActiveRisk: false,
            stableDayProfile: profile
        )
        return statusLabelEN == labels.english && statusLabelRU == labels.russian
    }

    private func isPreSession(_ scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation,
             .lowRecoveryPrep:
            return true
        default:
            return false
        }
    }

    private func isPostSession(_ scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return true
        default:
            return false
        }
    }

    private func activityState(for scenario: CoachScenarioKey) -> CoachActivityState {
        switch scenario {
        case .morningReadiness, .stableDay, .tomorrowProtection, .protectTomorrowFresh,
             .recoveryAfterHeavyYesterday:
            return .none
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation,
             .lowRecoveryPrep:
            return .upcoming
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .saunaActive, .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction:
            return .active
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return .justFinished
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery,
             .saunaRecovery:
            return .finished
        }
    }

    private func sessionPhase(for scenario: CoachScenarioKey) -> CoachSessionPhase {
        switch scenario {
        case .morningReadiness, .stableDay, .protectTomorrowFresh, .recoveryAfterHeavyYesterday:
            return .idle
        case .tomorrowProtection:
            return .tomorrowProtection
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation,
             .lowRecoveryPrep:
            return .pre
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .saunaActive, .walkLightDay, .walkAfterHeavyLoad, .walkRecoveryAction:
            return .during
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return .immediatePost
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery,
             .saunaRecovery:
            return .settledPost
        case .walkEveningWindDown:
            return .evening
        }
    }

    private func focusSource(for scenario: CoachScenarioKey) -> CoachFocusSource {
        if isPreSession(scenario) { return .upcoming }
        if isPostSession(scenario) { return .recentCompleted }
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .saunaActive, .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction:
            return .active
        default:
            return .idle
        }
    }
}
