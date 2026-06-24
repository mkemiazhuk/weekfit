import XCTest
@testable import WeekFit

/// Snapshot-like quality guards for all CoachV6 copy packs.
final class CoachV6CopyQualityTests: XCTestCase {

    private let registeredScenarios = CoachV6ScenarioKey.allCases

    // MARK: - Snapshot audit (baseline packs, no modifiers)

    func testBaselineCopyQualitySnapshotsAreClean() throws {
        for scenario in registeredScenarios {
            let input = Self.baselineInput(for: scenario)
            let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(input), scenario.rawValue)
            let report = CoachV6CopyQualityAudit.audit(pack: pack, input: input)
            XCTAssertTrue(report.isClean, "\(scenario.rawValue): \(report.violations)")
        }
    }

    func testMorningReadinessSnapshotSections() throws {
        let pack = try resolveBaseline(.morningReadiness)
        assertSectionsDistinct(pack)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("morning") == true)
        XCTAssertNil(pack.warningLayer)
    }

    func testStableDaySnapshotSections() throws {
        let pack = try resolveBaseline(.stableDay)
        assertSectionsDistinct(pack)
        XCTAssertNil(pack.warningLayer)
    }

    func testDuringEnduranceSnapshotSections() throws {
        let pack = try resolveBaseline(.duringEndurance)
        assertSectionsDistinct(pack)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("bike") == true)
        XCTAssertNil(pack.warningLayer)
    }

    func testWalkAfterHeavyLoadSnapshotSections() throws {
        let pack = try resolveBaseline(.walkAfterHeavyLoad)
        assertSectionsDistinct(pack)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("walk") == true)
        XCTAssertNil(pack.warningLayer)
    }

    func testTomorrowProtectionSnapshotSections() throws {
        let pack = try resolveBaseline(.tomorrowProtection)
        assertSectionsDistinct(pack)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("banked") == true)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("10:30") == false)
        XCTAssertNil(pack.warningLayer)
    }

    // MARK: - Modifier guards

    func testDuringEnduranceHydrationBehindAuditIsClean() throws {
        let result = evaluateCycling(nutrition: behindHydration())
        let pack = try XCTUnwrap(result.copyPack)
        let input = CoachV6CopyBuildInput.from(result: result)
        let report = CoachV6CopyQualityAudit.audit(pack: pack, input: input)

        XCTAssertTrue(report.isClean, report.violations.joined(separator: "; "))
        XCTAssertTrue(CoachV6CopyQualityAudit.mentionsHydration(
            pack.supportingSignals.lines.map(\.english).joined()
        ))
        XCTAssertFalse(CoachV6CopyQualityAudit.mentionsHydration(
            mainStoryText(pack)
        ))
        XCTAssertNil(pack.warningLayer)
    }

    func testDuringEnduranceHydrationCriticalHasWarningLayerOnly() throws {
        let result = evaluateCycling(nutrition: criticalHydration())
        let pack = try XCTUnwrap(result.copyPack)
        let input = CoachV6CopyBuildInput.from(result: result)
        let report = CoachV6CopyQualityAudit.audit(pack: pack, input: input)

        XCTAssertTrue(report.isClean, report.violations.joined(separator: "; "))
        XCTAssertEqual(pack.warningLayer?.alert, .hydrationCritical)
        XCTAssertEqual(pack.scenario, .duringEndurance)
    }

    func testStableDayFuelBehindAuditIsClean() throws {
        let input = stableDayInput(fuelBehind: true)
        let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(input))
        let report = CoachV6CopyQualityAudit.audit(pack: pack, input: input)

        XCTAssertTrue(report.isClean, report.violations.joined(separator: "; "))
        XCTAssertEqual(pack.scenario, .stableDay)
        XCTAssertFalse(CoachV6CopyQualityAudit.mentionsFuel(mainStoryText(pack)))
    }

    func testAllRegisteredScenariosBilingualLinesFilled() throws {
        for scenario in registeredScenarios {
            let pack = try resolveBaseline(scenario)
            for (name, section) in sections(of: pack) {
                for line in section.lines {
                    XCTAssertFalse(line.english.isEmpty, "\(scenario.rawValue).\(name) en")
                    XCTAssertFalse(line.russian.isEmpty, "\(scenario.rawValue).\(name) ru")
                }
            }
        }
    }

    // MARK: - Helpers

    private func resolveBaseline(_ scenario: CoachV6ScenarioKey) throws -> CoachV6CopyPack {
        try XCTUnwrap(CoachV6CopyRegistry.resolve(Self.baselineInput(for: scenario)))
    }

    static func baselineInput(for scenario: CoachV6ScenarioKey) -> CoachV6CopyBuildInput {
        let profile = Self.baselineProfile(for: scenario)
        let dayReadiness = baselineDayReadiness(for: scenario)
        return CoachV6CopyBuildInput(
            scenario: scenario,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: profile.dayLoad,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: profile.tomorrowDemand,
                activityType: profile.activityType,
                durationBand: profile.durationBand,
                completedSeriousActivities: profile.completedSeriousActivities,
                timeOfDay: profile.timeOfDay,
                stackedDayActiveRisk: false
            ),
            athleteState: CoachV6AthleteStateResolver.resolve(dayReadiness: dayReadiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: CoachV6PresentationResolver.semanticColor(for: scenario),
            alertSeverity: .none,
            tomorrowWorkout: profile.tomorrowWorkout,
            dayReadiness: dayReadiness
        )
    }

    private static func baselineDayReadiness(for scenario: CoachV6ScenarioKey) -> CoachV6DayReadiness {
        switch scenario {
        case .protectTomorrowFresh:
            return CoachV6DayReadiness(
                recoveryPercent: 90, sleepHours: 8, recoveryBand: .good,
                hadHeavyYesterday: false, sleepIsLow: false
            )
        case .recoveryAfterHeavyYesterday:
            return CoachV6DayReadiness(
                recoveryPercent: 38, sleepHours: 4.5, recoveryBand: .low,
                hadHeavyYesterday: true, sleepIsLow: true
            )
        case .lowRecoveryPrep:
            return CoachV6DayReadiness(
                recoveryPercent: 35, sleepHours: 4.5, recoveryBand: .low,
                hadHeavyYesterday: false, sleepIsLow: true
            )
        case .morningReadiness, .stableDay:
            return CoachV6DayReadiness(
                recoveryPercent: 82, sleepHours: 7.5, recoveryBand: .good,
                hadHeavyYesterday: false, sleepIsLow: false
            )
        default:
            return .unknown
        }
    }

    private struct BaselineProfile {
        let activityType: CoachV6ActivityType
        let durationBand: CoachV6DurationBand
        let dayLoad: CoachV6DayLoadBand
        let timeOfDay: CoachV6TimeOfDay
        let tomorrowDemand: CoachV6TomorrowDemand
        let completedSeriousActivities: CoachV6CompletedSeriousActivities
        let tomorrowWorkout: CoachV6TomorrowWorkout?
    }

    private static func baselineProfile(for scenario: CoachV6ScenarioKey) -> BaselineProfile {
        switch scenario {
        case .morningReadiness:
            return BaselineProfile(
                activityType: .none, durationBand: .short, dayLoad: .fresh,
                timeOfDay: .morning, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        case .stableDay, .walkLightDay:
            return BaselineProfile(
                activityType: scenario == .walkLightDay ? .walk : .none,
                durationBand: .medium, dayLoad: .fresh, timeOfDay: .afternoon,
                tomorrowDemand: .none, completedSeriousActivities: .none, tomorrowWorkout: nil
            )
        case .duringEndurance:
            return BaselineProfile(
                activityType: .cycling, durationBand: .extended, dayLoad: .fresh,
                timeOfDay: .afternoon, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        case .activeEndurance, .postEnduranceImmediate, .postEnduranceSettled, .eveningAfterEndurance:
            return BaselineProfile(
                activityType: .cycling, durationBand: .extended, dayLoad: .moderate,
                timeOfDay: scenario == .eveningAfterEndurance ? .evening : .afternoon,
                tomorrowDemand: .none, completedSeriousActivities: .one, tomorrowWorkout: nil
            )
        case .activeRacket, .duringRacket, .postRacketImmediate, .postRacketSettled, .eveningAfterRacket:
            return BaselineProfile(
                activityType: .tennis, durationBand: .medium, dayLoad: .moderate,
                timeOfDay: scenario == .eveningAfterRacket ? .evening : .afternoon,
                tomorrowDemand: .none, completedSeriousActivities: .one, tomorrowWorkout: nil
            )
        case .activeStrength, .duringStrength, .postStrengthImmediate, .postStrengthSettled, .eveningAfterStrength:
            return BaselineProfile(
                activityType: .fullBody, durationBand: .medium, dayLoad: .heavy,
                timeOfDay: scenario == .eveningAfterStrength ? .evening : .afternoon,
                tomorrowDemand: .none, completedSeriousActivities: .one, tomorrowWorkout: nil
            )
        case .walkAfterHeavyLoad, .walkRecoveryAction:
            return BaselineProfile(
                activityType: .walk, durationBand: .medium, dayLoad: .heavy,
                timeOfDay: .afternoon, tomorrowDemand: .none, completedSeriousActivities: .one,
                tomorrowWorkout: nil
            )
        case .walkEveningWindDown:
            return BaselineProfile(
                activityType: .walk, durationBand: .short, dayLoad: .moderate,
                timeOfDay: .evening, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        case .activeRecovery, .duringRecovery, .postRecoveryImmediate, .postRecoverySettled, .eveningAfterRecovery:
            return BaselineProfile(
                activityType: .yoga, durationBand: .medium, dayLoad: .moderate,
                timeOfDay: scenario == .eveningAfterRecovery ? .evening : .afternoon,
                tomorrowDemand: .none, completedSeriousActivities: .none, tomorrowWorkout: nil
            )
        case .saunaPreparation, .saunaActive, .saunaRecovery:
            return BaselineProfile(
                activityType: .sauna, durationBand: .medium, dayLoad: .moderate,
                timeOfDay: .afternoon, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        case .tomorrowProtection:
            return BaselineProfile(
                activityType: .none, durationBand: .short, dayLoad: .heavy,
                timeOfDay: .evening, tomorrowDemand: .hard, completedSeriousActivities: .one,
                tomorrowWorkout: CoachV6TomorrowWorkout(
                    title: "Core", startHour: 10, startMinute: 30, durationMinutes: 55
                )
            )
        case .protectTomorrowFresh:
            return BaselineProfile(
                activityType: .none, durationBand: .short, dayLoad: .fresh,
                timeOfDay: .morning, tomorrowDemand: .hard, completedSeriousActivities: .none,
                tomorrowWorkout: CoachV6TomorrowWorkout(
                    title: "Long Run", startHour: 7, startMinute: 0, durationMinutes: 90
                )
            )
        case .recoveryAfterHeavyYesterday:
            return BaselineProfile(
                activityType: .none, durationBand: .short, dayLoad: .fresh,
                timeOfDay: .morning, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        case .lowRecoveryPrep:
            return BaselineProfile(
                activityType: .cycling, durationBand: .long, dayLoad: .fresh,
                timeOfDay: .afternoon, tomorrowDemand: .none, completedSeriousActivities: .none,
                tomorrowWorkout: nil
            )
        }
    }

    private func stableDayInput(fuelBehind: Bool) -> CoachV6CopyBuildInput {
        let dayReadiness = CoachV6DayReadiness.unknown
        return CoachV6CopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: fuelBehind,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .none,
                durationBand: .medium,
                completedSeriousActivities: .none,
                timeOfDay: .afternoon,
                stackedDayActiveRisk: false
            ),
            athleteState: CoachV6AthleteStateResolver.resolve(dayReadiness: dayReadiness),
            fuelState: fuelBehind ? .behind : .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: fuelBehind ? .elevated : .none,
            tomorrowWorkout: nil,
            dayReadiness: dayReadiness
        )
    }

    private func evaluateCycling(nutrition: CoachNutritionContext) -> CoachV6Engine.Result {
        let now = CoachTestClock.reference
        let cycling = PlannedActivity(
            date: CoachTestClock.offset(minutes: -90, from: now),
            type: "workout",
            title: "100 km Cycling",
            durationMinutes: 360,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 900
        )
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 14
        return CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: now,
                now: now,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [cycling],
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 200,
                    exerciseMinutes: 20,
                    standHours: nil,
                    activityGoalCalories: 600,
                    activityProgress: 0.4
                ),
                recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
                nutritionContext: nutrition,
                source: "CoachV6CopyQualityTests"
            ),
            focusActivity: cycling
        )
    }

    private func behindHydration() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 1.06,
            waterGoal: 2.5
        )
    }

    private func criticalHydration() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 0.4,
            waterGoal: 2.5
        )
    }

    private func assertSectionsDistinct(_ pack: CoachV6CopyPack) {
        let texts = [
            pack.assessment, pack.recommendation, pack.avoid, pack.nextAction
        ].flatMap { section in
            section.lines.flatMap { [$0.english, $0.russian] }
        }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        XCTAssertEqual(texts.count, Set(texts).count, "duplicate lines across main sections")
    }

    private func mainStoryText(_ pack: CoachV6CopyPack) -> String {
        [
            pack.assessment, pack.recommendation, pack.avoid, pack.nextAction
        ].flatMap { $0.lines.flatMap { [$0.english, $0.russian] } }.joined(separator: " ")
    }

    private func sections(of pack: CoachV6CopyPack) -> [(String, CoachV6CopySection)] {
        [
            ("assessment", pack.assessment),
            ("recommendation", pack.recommendation),
            ("avoid", pack.avoid),
            ("nextAction", pack.nextAction),
            ("supportingSignals", pack.supportingSignals)
        ]
    }
}
