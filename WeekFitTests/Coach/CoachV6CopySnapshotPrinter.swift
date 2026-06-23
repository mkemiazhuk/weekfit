import Foundation
@testable import WeekFit

/// Manual QA printer for CoachV6 Russian copy — test target only.
enum CoachV6CopySnapshotPrinter {

    static let logFileURL = URL(fileURLWithPath: "/tmp/WeekFitCoachV6CopySnapshots-RU.txt")

    enum PhaseGroup: String, CaseIterable {
        case dayLevel = "DAY LEVEL"
        case active = "ACTIVE (pre-session)"
        case during = "DURING (live session)"
        case postImmediate = "POST IMMEDIATE"
        case postSettled = "POST SETTLED"
        case eveningAfter = "EVENING AFTER"
        case walk = "WALK"
        case heat = "HEAT / SAUNA"
        case hydrationCritical = "HYDRATION CRITICAL VARIANTS"
        case stackedDayActiveRisk = "STACKED DAY ACTIVE RISK OVERLAY"
    }

    struct Snapshot {
        let scenario: CoachV6ScenarioKey
        let variantLabel: String?
        let badge: String
        let todayTitle: String
        let todaySubtitle: String
        let coachHero: String
        let assessment: String
        let recommendation: String
        let avoid: String
        let nextStep: String
        let supportSignals: [String]
        let warning: String?
    }

    static func renderFullReport() -> String {
        var sections: [String] = []
        sections.append(header())

        for group in PhaseGroup.allCases where group != .hydrationCritical && group != .stackedDayActiveRisk {
            let scenarios = scenarios(in: group)
            guard !scenarios.isEmpty else { continue }
            sections.append(sectionHeader(group))
            for scenario in scenarios {
                if let snapshot = snapshot(for: scenario) {
                    sections.append(format(snapshot))
                }
            }
        }

        sections.append(sectionHeader(.hydrationCritical))
        for scenario in hydrationCriticalScenarios() {
            if let snapshot = snapshot(
                for: scenario,
                input: hydrationCriticalInput(for: scenario),
                variantLabel: "hydrationCritical"
            ) {
                sections.append(format(snapshot))
            }
        }

        sections.append(sectionHeader(.stackedDayActiveRisk))
        for example in stackedRiskExamples() {
            if let snapshot = snapshot(
                for: example.scenario,
                input: example.input,
                variantLabel: example.label
            ) {
                sections.append(format(snapshot))
            }
        }

        return sections.joined(separator: "\n\n")
    }

    static func writeToLogFile(_ text: String) {
        try? text.write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    static func resetLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    // MARK: - Snapshot assembly

    private static func snapshot(
        for scenario: CoachV6ScenarioKey,
        input: CoachV6CopyBuildInput? = nil,
        variantLabel: String? = nil
    ) -> Snapshot? {
        let buildInput = input ?? CoachV6CopyQualityTests.baselineInput(for: scenario)
        guard let result = engineResult(from: buildInput),
              let bridge = CoachV6TabPresentationBridge.build(from: result) else {
            return nil
        }

        let pack = result.copyPack!
        return Snapshot(
            scenario: scenario,
            variantLabel: variantLabel,
            badge: bridge.today.statusLabel,
            todayTitle: bridge.today.title,
            todaySubtitle: bridge.today.message,
            coachHero: bridge.coach.title,
            assessment: russianText(pack.assessment),
            recommendation: russianText(pack.recommendation),
            avoid: russianText(pack.avoid),
            nextStep: russianText(pack.nextAction),
            supportSignals: pack.supportingSignals.lines.map(\.russian),
            warning: pack.warningLayer?.message.russian
        )
    }

    private static func engineResult(from input: CoachV6CopyBuildInput) -> CoachV6Engine.Result? {
        guard let pack = CoachV6CopyRegistry.resolve(input) else { return nil }

        let context = CoachV6Context(
            activityFamily: input.scenario.activityFamily ?? .none,
            activityType: input.modifiers.activityType,
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
            focusActivityID: input.scenario.activityFamily == nil ? nil : "snapshot-\(input.scenario.rawValue)",
            minutesUntilStart: isPreSession(input.scenario) ? 12 : nil,
            minutesSinceEnd: isPostSession(input.scenario) ? 8 : nil,
            dayReadiness: input.dayReadiness
        )

        let resolution = CoachV6ScenarioResolution(
            scenario: input.scenario,
            modifiers: input.modifiers,
            safetyAlert: input.safetyAlert
        )
        let insight = CoachV6PresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )

        return CoachV6Engine.Result(
            context: context,
            resolution: resolution,
            todayInsight: insight,
            copyPack: pack
        )
    }

    // MARK: - Formatting

    private static func header() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return """
        CoachV6 Copy Snapshot — RU
        Generated: \(formatter.string(from: Date()))
        Log file: \(logFileURL.path)

        Run locally:
        xcodebuild test -scheme WeekFit \\
          -destination 'platform=iOS Simulator,name=iPhone 17' \\
          -only-testing:WeekFitTests/CoachV6CopySnapshotPrinterTests/testPrintAllRussianCopySnapshots
        """
    }

    private static func sectionHeader(_ group: PhaseGroup) -> String {
        """
        ═══════════════════════════════════════
        \(group.rawValue)
        ═══════════════════════════════════════
        """
    }

    private static func format(_ snapshot: Snapshot) -> String {
        let scenarioLine: String
        if let variantLabel = snapshot.variantLabel {
            scenarioLine = "SCENARIO: \(snapshot.scenario.rawValue) [\(variantLabel)]"
        } else {
            scenarioLine = "SCENARIO: \(snapshot.scenario.rawValue)"
        }

        let support = snapshot.supportSignals.isEmpty
            ? "—"
            : snapshot.supportSignals.joined(separator: " | ")
        let warning = snapshot.warning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? snapshot.warning!
            : "—"

        return """
        \(scenarioLine)
        Badge: \(snapshot.badge)
        Today title: \(snapshot.todayTitle)
        Today subtitle: \(snapshot.todaySubtitle)
        Coach hero: \(snapshot.coachHero)
        Assessment: \(snapshot.assessment)
        Recommendation: \(snapshot.recommendation)
        Avoid: \(snapshot.avoid)
        Next step: \(snapshot.nextStep)
        Support signals: \(support)
        Warning: \(warning)
        """
    }

    private static func russianText(_ section: CoachV6CopySection) -> String {
        section.lines.map(\.russian).joined(separator: " ")
    }

    // MARK: - Scenario groups

    private static func scenarios(in group: PhaseGroup) -> [CoachV6ScenarioKey] {
        switch group {
        case .dayLevel:
            return [.morningReadiness, .stableDay, .tomorrowProtection,
                    .protectTomorrowFresh, .recoveryAfterHeavyYesterday]
        case .active:
            return [.activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .lowRecoveryPrep]
        case .during:
            return [.duringEndurance, .duringRacket, .duringStrength, .duringRecovery]
        case .postImmediate:
            return [
                .postEnduranceImmediate, .postRacketImmediate,
                .postStrengthImmediate, .postRecoveryImmediate
            ]
        case .postSettled:
            return [
                .postEnduranceSettled, .postRacketSettled,
                .postStrengthSettled, .postRecoverySettled
            ]
        case .eveningAfter:
            return [
                .eveningAfterEndurance, .eveningAfterRacket,
                .eveningAfterStrength, .eveningAfterRecovery
            ]
        case .walk:
            return [.walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction]
        case .heat:
            return [.saunaPreparation, .saunaActive, .saunaRecovery]
        case .hydrationCritical, .stackedDayActiveRisk:
            return []
        }
    }

    private static func hydrationCriticalScenarios() -> [CoachV6ScenarioKey] {
        [.duringEndurance, .duringRacket, .saunaActive]
    }

    private static func hydrationCriticalInput(for scenario: CoachV6ScenarioKey) -> CoachV6CopyBuildInput {
        let base = CoachV6CopyQualityTests.baselineInput(for: scenario)
        return CoachV6CopyBuildInput(
            scenario: scenario,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: base.modifiers.dayLoad,
                fuelBehind: false,
                hydrationBehind: true,
                tomorrowDemand: base.modifiers.tomorrowDemand,
                activityType: base.modifiers.activityType,
                durationBand: base.modifiers.durationBand,
                completedSeriousActivities: base.modifiers.completedSeriousActivities,
                timeOfDay: base.modifiers.timeOfDay,
                stackedDayActiveRisk: false
            ),
            fuelState: .adequate,
            hydrationState: .critical,
            safetyAlert: .hydrationCritical,
            semanticColor: CoachV6PresentationResolver.semanticColor(for: scenario),
            alertSeverity: .critical,
            tomorrowWorkout: base.tomorrowWorkout,
            dayReadiness: base.dayReadiness
        )
    }

    private struct StackedRiskExample {
        let scenario: CoachV6ScenarioKey
        let input: CoachV6CopyBuildInput
        let label: String
    }

    private static func stackedRiskExamples() -> [StackedRiskExample] {
        [
            StackedRiskExample(
                scenario: .duringStrength,
                input: stackedRiskInput(scenario: .duringStrength, activityType: .fullBody),
                label: "duringStrength + heavy day + tomorrow hard"
            ),
            StackedRiskExample(
                scenario: .duringEndurance,
                input: stackedRiskInput(scenario: .duringEndurance, activityType: .cycling),
                label: "duringEndurance + heavy day + tomorrow hard"
            ),
            StackedRiskExample(
                scenario: .activeEndurance,
                input: stackedRiskInput(scenario: .activeEndurance, activityType: .cycling),
                label: "activeEndurance + heavy day + tomorrow hard"
            )
        ]
    }

    private static func stackedRiskInput(
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType
    ) -> CoachV6CopyBuildInput {
        return CoachV6CopyBuildInput(
            scenario: scenario,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .hard,
                activityType: activityType,
                durationBand: .medium,
                completedSeriousActivities: .one,
                timeOfDay: .lateEvening,
                stackedDayActiveRisk: true
            ),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .risk,
            alertSeverity: .critical,
            tomorrowWorkout: CoachV6TomorrowWorkout(
                title: "Core",
                startHour: 10,
                startMinute: 30,
                durationMinutes: 55
            ),
            dayReadiness: .unknown
        )
    }

    // MARK: - Context helpers

    private static func isPreSession(_ scenario: CoachV6ScenarioKey) -> Bool {
        switch scenario {
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery, .saunaPreparation,
             .lowRecoveryPrep:
            return true
        default:
            return false
        }
    }

    private static func isPostSession(_ scenario: CoachV6ScenarioKey) -> Bool {
        switch scenario {
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate:
            return true
        default:
            return false
        }
    }

    private static func activityState(for scenario: CoachV6ScenarioKey) -> CoachV6ActivityState {
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

    private static func sessionPhase(for scenario: CoachV6ScenarioKey) -> CoachV6SessionPhase {
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
             .saunaRecovery:
            return .settledPost
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery,
             .walkEveningWindDown:
            return .evening
        }
    }
}
