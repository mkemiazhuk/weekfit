import XCTest
@testable import WeekFit

/// Final presentation correctness — hero/why dedupe, Today card tone, bilingual snapshots.
final class CoachCopyCorrectnessAuditTests: XCTestCase {

    // MARK: - 10:47 Today card + Coach hero

    func test1047TodayCardShortCalmAfterHeavyYesterdayWalk() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let result = makeRecoveryDayResult(
            timeOfDay: .midday,
            completedWalk: true,
            mealWindowOpen: false,
            fuelBehind: false
        )
        let presentation = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(presentation.todayTitle, "После вчерашней нагрузки")
        XCTAssertEqual(presentation.todayMessage, "Прогулка уже есть — дальше спокойный ритм.")

        XCTAssertTrue(presentation.assessment.contains("вчерашн"))
        XCTAssertTrue(presentation.recommendation.contains("Прогулка уже есть"))
        XCTAssertTrue(presentation.nextAction.contains("первый приём пищи"))

        let heroBlob = [
            presentation.assessment,
            presentation.recommendation,
            presentation.avoid,
            presentation.nextAction
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(heroBlob.contains("остаток дня"))
        XCTAssertFalse(heroBlob.contains("плотный день позади"))
        XCTAssertFalse(heroBlob.contains("еды пока меньше"))
        XCTAssertFalse(presentation.whyRows.contains { CoachCopyQualityAudit.mentionsFuel($0.title) })
    }

    func test1047SnapshotBilingualLinesFilled() throws {
        let input = recoveryDayInput(
            timeOfDay: .midday,
            completedWalk: true,
            mealWindowOpen: false
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))

        for section in [pack.assessment, pack.recommendation, pack.avoid, pack.nextAction] {
            for line in section.lines {
                XCTAssertFalse(line.english.isEmpty, "EN line required")
                XCTAssertFalse(line.russian.isEmpty, "RU line required")
            }
        }

        XCTAssertEqual(
            pack.assessment.lines.first?.english,
            "After yesterday's load — don't force it today."
        )
        XCTAssertEqual(
            pack.recommendation.lines.first?.english,
            "Walk is already in — keep a calm ordinary rhythm from here."
        )
        XCTAssertEqual(
            pack.nextAction.lines.first?.english,
            "Water by feel — first meal at your usual time."
        )
    }

    // MARK: - Hero vs Why nutrition dedupe

    func testHeroNutritionNotDuplicatedInWhyRowsWhenNextActionPlansMeal() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let result = makeRecoveryDayResult(
            timeOfDay: .midday,
            completedWalk: true,
            mealWindowOpen: false,
            fuelBehind: true
        )
        let presentation = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertTrue(presentation.nextAction.contains("первый приём пищи"))
        XCTAssertFalse(
            presentation.whyRows.contains {
                $0.title.contains("Еды пока меньше") || $0.title.contains("Первый приём пищи ещё впереди")
            },
            "Meal timing belongs in nextAction only when already stated there"
        )
    }

    func testWindDownHeroSuppressesDuplicateHydrationWhyRow() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let evening = date(hour: 22, minute: 0)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -10, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowCore = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 900,
            caloriesGoal: 2_800,
            proteinCurrent: 40,
            proteinGoal: 140,
            waterCurrent: 0.9,
            waterGoal: 2.5
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 22

        let result = CoachEngine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: evening,
                now: evening,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [completedRide, tomorrowCore].coachSnapshots(),
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 2_758,
                    exerciseMinutes: 282,
                    standHours: 11,
                    activityGoalCalories: 700,
                    activityProgress: 3.94
                ),
                recoveryContext: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.0),
                nutritionContext: nutrition,
                source: "CoachCopyCorrectnessAuditTests"
            ),
            focusActivity: completedRide
        )
        let presentation = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertTrue(presentation.nextAction.contains("вод"))
        XCTAssertFalse(presentation.whyRows.contains { $0.icon == "drop.fill" })
    }

    // MARK: - Fasting neutral nutrition

    func testFastingWindowUsesNeutralFirstMealAheadNotFuelBehind() throws {
        let input = fastingEmptyDayInput(timeOfDay: .midday)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))

        XCTAssertFalse(pack.supportingSignals.lines.contains { $0.russian.contains("Еды пока меньше") })
        XCTAssertTrue(pack.supportingSignals.lines.contains { $0.russian.contains("Первый приём пищи ещё впереди") })

        let report = CoachConversationSemanticTimingAudit.audit(pack: pack, input: input)
        XCTAssertTrue(report.isClean, report.findings.map(\.reason).joined(separator: "; "))
    }

    // MARK: - Helpers

    private func recoveryDayInput(
        timeOfDay: CoachTimeOfDay,
        completedWalk: Bool,
        mealWindowOpen: Bool
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 38,
            sleepHours: 5.0,
            recoveryBand: .low,
            hadHeavyYesterday: true,
            sleepIsLow: true
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: completedWalk ? .walk : .none,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: .normal,
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: completedWalk ? .recentCompleted : .idle,
            sessionPhase: completedWalk ? .settledPost : .idle,
            activityState: completedWalk ? .finished : .none,
            minutesSinceEnd: completedWalk ? 45 : nil,
            mealWindowOpen: mealWindowOpen
        )
    }

    private func fastingEmptyDayInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 82,
            sleepHours: 7.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: true,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .none,
                durationBand: .medium,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: .normal,
            fuelState: .behind,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: .elevated,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            mealWindowOpen: false
        )
    }

    private func makeRecoveryDayResult(
        timeOfDay: CoachTimeOfDay,
        completedWalk: Bool,
        mealWindowOpen: Bool,
        fuelBehind: Bool
    ) -> CoachEngine.Result {
        let input = recoveryDayInput(
            timeOfDay: timeOfDay,
            completedWalk: completedWalk,
            mealWindowOpen: mealWindowOpen
        )
        var modifiers = input.modifiers
        if fuelBehind {
            modifiers = CoachScenarioModifiers(
                dayLoad: modifiers.dayLoad,
                fuelBehind: true,
                hydrationBehind: modifiers.hydrationBehind,
                tomorrowDemand: modifiers.tomorrowDemand,
                activityType: modifiers.activityType,
                durationBand: modifiers.durationBand,
                completedSeriousActivities: modifiers.completedSeriousActivities,
                timeOfDay: modifiers.timeOfDay,
                stackedDayActiveRisk: modifiers.stackedDayActiveRisk,
                lastCompletedActivityType: modifiers.lastCompletedActivityType
            )
        }
        let copyInput = CoachCopyBuildInput(
            scenario: input.scenario,
            modifiers: modifiers,
            athleteState: input.athleteState,
            fuelState: fuelBehind ? .behind : input.fuelState,
            hydrationState: input.hydrationState,
            safetyAlert: input.safetyAlert,
            semanticColor: input.semanticColor,
            alertSeverity: fuelBehind ? .elevated : input.alertSeverity,
            tomorrowWorkout: input.tomorrowWorkout,
            dayReadiness: input.dayReadiness,
            focusSource: input.focusSource,
            sessionPhase: input.sessionPhase,
            activityState: input.activityState,
            minutesSinceEnd: input.minutesSinceEnd,
            mealWindowOpen: mealWindowOpen
        )
        let context = CoachContext(
            activityFamily: completedWalk ? .recovery : .none,
            activityType: completedWalk ? .walk : .none,
            activityState: input.activityState,
            sessionPhase: input.sessionPhase,
            durationBand: .short,
            dayLoadBand: .fresh,
            completedSeriousActivities: .none,
            fuelState: copyInput.fuelState,
            hydrationState: copyInput.hydrationState,
            tomorrowDemand: .none,
            timeOfDay: timeOfDay,
            tomorrowWorkout: nil,
            focusActivityID: completedWalk ? "walk" : nil,
            focusSource: input.focusSource,
            minutesUntilStart: nil,
            minutesSinceEnd: input.minutesSinceEnd,
            dayReadiness: input.dayReadiness,
            lastCompletedSeriousActivityType: .none,
            conversationPhase: .steady
        )
        let resolution = CoachScenarioResolution(
            scenario: .stableDay,
            modifiers: modifiers,
            safetyAlert: nil
        )
        let insight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        return CoachEngine.Result(
            context: context,
            resolution: resolution,
            todayInsight: insight,
            copyPack: CoachCopyRegistry.resolve(copyInput),
            morningBriefFacts: nil
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
