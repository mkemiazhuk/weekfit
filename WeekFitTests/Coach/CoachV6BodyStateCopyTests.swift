import XCTest
@testable import WeekFit

final class CoachV6BodyStateCopyTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    // MARK: - Scenario unchanged across body states

    func testActiveEnduranceScenarioUnchangedAcrossBodyStates() {
        let fresh = evaluateActiveEndurance(recoveryPercent: 90, sleepHours: 8, hadHeavyYesterday: false)
        let fatigued = evaluateActiveEndurance(
            recoveryPercent: 65,
            sleepHours: 7.5,
            hadHeavyYesterday: true
        )

        XCTAssertEqual(fresh.scenario, .activeEndurance)
        XCTAssertEqual(fatigued.scenario, .activeEndurance)
    }

    func testDuringEnduranceScenarioUnchangedAcrossBodyStates() {
        let fresh = evaluateDuringEndurance(recoveryPercent: 88, sleepHours: 8)
        let fatigued = evaluateDuringEndurance(recoveryPercent: 48, sleepHours: 7)

        XCTAssertEqual(fresh.scenario, .duringEndurance)
        XCTAssertEqual(fatigued.scenario, .duringEndurance)
    }

    // MARK: - Copy differs across body states

    func testActiveEnduranceCopyDiffersForFreshVsFatigued() throws {
        let fresh = evaluateActiveEndurance(recoveryPercent: 90, sleepHours: 8, hadHeavyYesterday: false)
        let fatigued = evaluateActiveEndurance(
            recoveryPercent: 65,
            sleepHours: 7.5,
            hadHeavyYesterday: true
        )

        let freshPack = try XCTUnwrap(fresh.copyPack)
        let fatiguedPack = try XCTUnwrap(fatigued.copyPack)

        XCTAssertEqual(fresh.athleteStateFromContext.bodyState, .fresh)
        XCTAssertEqual(fatigued.athleteStateFromContext.bodyState, .fatigued)

        XCTAssertNotEqual(
            joinedEnglish(freshPack.assessment),
            joinedEnglish(fatiguedPack.assessment)
        )
        XCTAssertNotEqual(
            joinedEnglish(freshPack.recommendation),
            joinedEnglish(fatiguedPack.recommendation)
        )

        XCTAssertTrue(joinedEnglish(fatiguedPack.assessment).lowercased().contains("ride"))
        XCTAssertTrue(joinedEnglish(fatiguedPack.recommendation).lowercased().contains("20"))
    }

    func testDuringEnduranceCopyDiffersForFreshVsFatigued() throws {
        let fresh = evaluateDuringEndurance(recoveryPercent: 88, sleepHours: 8)
        let fatigued = evaluateDuringEndurance(recoveryPercent: 48, sleepHours: 7)

        let freshPack = try XCTUnwrap(fresh.copyPack)
        let fatiguedPack = try XCTUnwrap(fatigued.copyPack)

        XCTAssertNotEqual(
            joinedEnglish(freshPack.recommendation),
            joinedEnglish(fatiguedPack.recommendation)
        )
        XCTAssertTrue(joinedEnglish(fatiguedPack.recommendation).lowercased().contains("conversational"))
    }

    func testMorningReadinessFatiguedDiffersFromFreshBaseline() throws {
        let freshReadiness = CoachV6DayReadiness(
            recoveryPercent: 90,
            sleepHours: 8,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        let fatiguedReadiness = CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )

        let freshPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .morningReadiness, dayReadiness: freshReadiness, activityType: .none)
        ))
        let fatiguedPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .morningReadiness, dayReadiness: fatiguedReadiness, activityType: .none)
        ))

        XCTAssertNotEqual(
            joinedEnglish(freshPack.assessment),
            joinedEnglish(fatiguedPack.assessment)
        )
        XCTAssertNotEqual(
            joinedEnglish(freshPack.recommendation),
            joinedEnglish(fatiguedPack.recommendation)
        )
        XCTAssertTrue(joinedEnglish(fatiguedPack.assessment).lowercased().contains("morning"))
    }

    func testStableDayFatiguedAdjustsCopy() throws {
        let result = evaluateStableDay(recoveryPercent: 65, sleepHours: 5)
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.athleteStateFromContext.bodyState, .fatigued)
        XCTAssertTrue(joinedEnglish(pack.assessment).lowercased().contains("energy"))
        XCTAssertTrue(joinedEnglish(pack.recommendation).lowercased().contains("intensity"))
    }

    // MARK: - Subject guard

    func testActiveEnduranceFatiguedAssessmentKeepsRideAsSubject() throws {
        let result = evaluateActiveEndurance(
            recoveryPercent: 65,
            sleepHours: 7.5,
            hadHeavyYesterday: true
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertTrue(
            CoachV6CopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .activeEndurance,
                activityType: .cycling
            )
        )
        XCTAssertTrue(CoachV6CopySubjectGuard.mainSectionsAvoidMetricHero(pack: pack))
    }

    func testDuringEnduranceFatiguedRecommendationAvoidsMetricHero() throws {
        let result = evaluateDuringEndurance(recoveryPercent: 48, sleepHours: 7)
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertTrue(
            CoachV6CopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .duringEndurance,
                activityType: .cycling
            )
        )
        XCTAssertTrue(CoachV6CopySubjectGuard.mainSectionsAvoidMetricHero(pack: pack))
    }

    func testMorningReadinessFatiguedKeepsMorningAsSubject() throws {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        let input = makeCopyInput(scenario: .morningReadiness, dayReadiness: readiness, activityType: .none)
        let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(input))

        XCTAssertTrue(
            CoachV6CopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .morningReadiness,
                activityType: .none
            )
        )
        XCTAssertTrue(CoachV6CopySubjectGuard.mainSectionsAvoidMetricHero(pack: pack))
    }

    func testStableDayFatiguedKeepsDayAsSubject() throws {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        let input = makeCopyInput(scenario: .stableDay, dayReadiness: readiness, activityType: .none)
        let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(input))

        XCTAssertTrue(
            CoachV6CopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .stableDay,
                activityType: .none
            )
        )
    }

    // MARK: - Walk scenarios

    func testWalkLightDayFreshKeepsBaselineCopy() throws {
        let readiness = freshReadiness()
        let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkLightDay, dayReadiness: readiness, activityType: .walk)
        ))

        XCTAssertEqual(
            joinedRussian(pack.assessment),
            "Лёгкая прогулка — движение без задачи."
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fresh)
    }

    func testWalkLightDayFatiguedChangesAssessmentAndRecommendation() throws {
        let readiness = screenshotFatiguedReadiness()
        let freshPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkLightDay, dayReadiness: freshReadiness(), activityType: .walk)
        ))
        let fatiguedPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkLightDay, dayReadiness: readiness, activityType: .walk)
        ))

        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
        XCTAssertNotEqual(
            joinedRussian(freshPack.assessment),
            joinedRussian(fatiguedPack.assessment)
        )
        XCTAssertNotEqual(
            joinedRussian(freshPack.recommendation),
            joinedRussian(fatiguedPack.recommendation)
        )
        XCTAssertEqual(
            joinedRussian(fatiguedPack.assessment),
            "Лёгкая прогулка — мягкий вход в день после короткого сна."
        )
        XCTAssertEqual(
            joinedRussian(fatiguedPack.recommendation),
            "Держите темп разговорным: цель — проснуться, а не набрать нагрузку."
        )
    }

    func testWalkLightDayFatiguedKeepsWalkAsSubject() throws {
        let pack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(
                scenario: .walkLightDay,
                dayReadiness: screenshotFatiguedReadiness(),
                activityType: .walk
            )
        ))

        XCTAssertTrue(
            CoachV6CopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .walkLightDay,
                activityType: .walk
            )
        )
        XCTAssertTrue(CoachV6CopySubjectGuard.mainSectionsAvoidMetricHero(pack: pack))
    }

    func testWalkLightDayVeryFatiguedUsesShorterNextAction() throws {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 35,
            sleepHours: 4.5,
            recoveryBand: .low,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        let fatiguedPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkLightDay, dayReadiness: screenshotFatiguedReadiness(), activityType: .walk)
        ))
        let veryFatiguedPack = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkLightDay, dayReadiness: readiness, activityType: .walk)
        ))

        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .veryFatigued)
        XCTAssertNotEqual(
            joinedRussian(fatiguedPack.nextAction),
            joinedRussian(veryFatiguedPack.nextAction)
        )
        XCTAssertTrue(joinedRussian(veryFatiguedPack.nextAction).contains("10–15"))
    }

    func testWalkAfterHeavyLoadFatiguedChangesCopy() throws {
        let readiness = fatiguedReadiness()
        let baseline = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkAfterHeavyLoad, dayReadiness: freshReadiness(), activityType: .walk)
        ))
        let adjusted = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkAfterHeavyLoad, dayReadiness: readiness, activityType: .walk)
        ))

        XCTAssertNotEqual(joinedRussian(baseline.assessment), joinedRussian(adjusted.assessment))
        XCTAssertTrue(joinedRussian(adjusted.assessment).contains("прогулк"))
    }

    func testWalkEveningWindDownFatiguedChangesCopy() throws {
        let readiness = fatiguedReadiness()
        let baseline = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(
                scenario: .walkEveningWindDown,
                dayReadiness: freshReadiness(),
                activityType: .walk,
                timeOfDay: .evening
            )
        ))
        let adjusted = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(
                scenario: .walkEveningWindDown,
                dayReadiness: readiness,
                activityType: .walk,
                timeOfDay: .evening
            )
        ))

        XCTAssertNotEqual(joinedRussian(baseline.assessment), joinedRussian(adjusted.assessment))
        XCTAssertTrue(joinedRussian(adjusted.recommendation).contains("сон"))
    }

    func testWalkRecoveryActionFatiguedChangesCopy() throws {
        let readiness = fatiguedReadiness()
        let baseline = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkRecoveryAction, dayReadiness: freshReadiness(), activityType: .walk)
        ))
        let adjusted = try XCTUnwrap(CoachV6CopyRegistry.resolve(
            makeCopyInput(scenario: .walkRecoveryAction, dayReadiness: readiness, activityType: .walk)
        ))

        XCTAssertNotEqual(joinedRussian(baseline.assessment), joinedRussian(adjusted.assessment))
        XCTAssertTrue(joinedRussian(adjusted.assessment).contains("восстанов"))
    }

    func testWalkLightDayScenarioUnchangedAcrossBodyStates() {
        let fresh = evaluateWalkLightDay(recoveryPercent: 90, sleepHours: 8)
        let fatigued = evaluateWalkLightDay(recoveryPercent: 75, sleepHours: 5.0)

        XCTAssertEqual(fresh.scenario, .walkLightDay)
        XCTAssertEqual(fatigued.scenario, .walkLightDay)
        XCTAssertEqual(fatigued.athleteStateFromContext.bodyState, .fatigued)
    }

    // MARK: - Helpers

    private func evaluateActiveEndurance(
        recoveryPercent: Int,
        sleepHours: Double,
        hadHeavyYesterday: Bool
    ) -> CoachV6Engine.Result {
        let now = date(hour: 13, minute: 0)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(60 * 60),
            type: "workout",
            title: "Afternoon Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 13
        if hadHeavyYesterday {
            brainConfig.completedWorkoutsCount = 2
        }

        return CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: now,
                now: now,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [ride],
                recoveryContext: CoachRecoveryContext(
                    recoveryPercent: recoveryPercent,
                    sleepHours: sleepHours
                ),
                nutritionContext: defaultNutrition,
                source: "CoachV6BodyStateCopyTests"
            ),
            focusActivity: ride
        )
    }

    private func evaluateDuringEndurance(recoveryPercent: Int, sleepHours: Double) -> CoachV6Engine.Result {
        let now = date(hour: 14, minute: 0)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(-30 * 60),
            type: "workout",
            title: "Ride",
            durationMinutes: 120,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 14

        return CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: now,
                now: now,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [ride],
                recoveryContext: CoachRecoveryContext(
                    recoveryPercent: recoveryPercent,
                    sleepHours: sleepHours
                ),
                nutritionContext: defaultNutrition,
                source: "CoachV6BodyStateCopyTests"
            ),
            focusActivity: ride
        )
    }

    private func evaluateStableDay(recoveryPercent: Int, sleepHours: Double) -> CoachV6Engine.Result {
        let afternoon = date(hour: 14, minute: 0)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 14

        return CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: afternoon,
                now: afternoon,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [],
                recoveryContext: CoachRecoveryContext(
                    recoveryPercent: recoveryPercent,
                    sleepHours: sleepHours
                ),
                nutritionContext: defaultNutrition,
                source: "CoachV6BodyStateCopyTests"
            )
        )
    }

    private func evaluateWalkLightDay(recoveryPercent: Int, sleepHours: Double) -> CoachV6Engine.Result {
        let morning = date(hour: 7, minute: 30)
        let walk = PlannedActivity(
            date: morning.addingTimeInterval(-5 * 60),
            type: "recovery",
            title: "Walk",
            durationMinutes: 30,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 7

        return CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: morning,
                now: morning,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [walk],
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 200,
                    exerciseMinutes: 20,
                    standHours: nil,
                    activityGoalCalories: 600,
                    activityProgress: 0.4
                ),
                recoveryContext: CoachRecoveryContext(
                    recoveryPercent: recoveryPercent,
                    sleepHours: sleepHours
                ),
                nutritionContext: defaultNutrition,
                source: "CoachV6BodyStateCopyTests"
            ),
            focusActivity: walk
        )
    }

    private func freshReadiness() -> CoachV6DayReadiness {
        CoachV6DayReadiness(
            recoveryPercent: 90,
            sleepHours: 8,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
    }

    private func fatiguedReadiness() -> CoachV6DayReadiness {
        CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
    }

    private func screenshotFatiguedReadiness() -> CoachV6DayReadiness {
        CoachV6DayReadiness(
            recoveryPercent: 75,
            sleepHours: 5.0,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
    }

    private func makeCopyInput(
        scenario: CoachV6ScenarioKey,
        dayReadiness: CoachV6DayReadiness,
        activityType: CoachV6ActivityType,
        timeOfDay: CoachV6TimeOfDay = .morning
    ) -> CoachV6CopyBuildInput {
        CoachV6CopyBuildInput(
            scenario: scenario,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: activityType,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false
            ),
            athleteState: CoachV6AthleteStateResolver.resolve(dayReadiness: dayReadiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: CoachV6PresentationResolver.semanticColor(for: scenario),
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: dayReadiness
        )
    }

    private var defaultNutrition: CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 1_800,
            caloriesGoal: 2_800,
            proteinCurrent: 90,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
    }

    private func joinedEnglish(_ section: CoachV6CopySection) -> String {
        section.lines.map(\.english).joined(separator: " ")
    }

    private func joinedRussian(_ section: CoachV6CopySection) -> String {
        section.lines.map(\.russian).joined(separator: " ")
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}

private extension CoachV6Engine.Result {
    var athleteStateFromContext: CoachV6AthleteState {
        CoachV6AthleteStateResolver.resolve(context: context)
    }
}
