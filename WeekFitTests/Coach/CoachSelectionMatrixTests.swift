import XCTest
@testable import WeekFit

/// Focus / phase / scenario consistency matrix for Coach selection.
final class CoachSelectionMatrixTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    private let forbiddenPostStrength: Set<CoachScenarioKey> = [
        .postStrengthImmediate, .postStrengthSettled, .eveningAfterStrength
    ]

    private let forbiddenPostEndurance: Set<CoachScenarioKey> = [
        .postEnduranceImmediate, .postEnduranceSettled, .eveningAfterEndurance
    ]

    private let forbiddenPostRacket: Set<CoachScenarioKey> = [
        .postRacketImmediate, .postRacketSettled, .eveningAfterRacket
    ]

    private let forbiddenPostMindfulRecovery: Set<CoachScenarioKey> = [
        .postRecoveryImmediate, .postRecoverySettled, .eveningAfterRecovery
    ]

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Real-life regression

    func testCompletedWalkBeforeUpcomingCoreDoesNotResolvePostStrengthImmediate() throws {
        let now = date(hour: 9, minute: 7)
        let walkStart = now.addingTimeInterval(-58 * 60)
        var walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: walkStart,
            durationMinutes: 55,
            completed: true
        )
        walk.type = "recovery"
        walk.icon = "figure.walk"

        let coreStart = date(hour: 10, minute: 30)
        let core = PlannedActivityBuilder.workout(
            title: "Core",
            at: coreStart,
            durationMinutes: 45,
            completed: false
        )

        let input = makeInput(
            now: now,
            activities: [walk, core],
            recovery: CoachRecoveryContext(recoveryPercent: 75, sleepHours: 5.0),
            nutrition: emptyNutrition(),
            actualLoad: moderateActualLoad(),
            brainHour: 9
        )
        let result = CoachEngine.evaluate(input: input)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let pack = try XCTUnwrap(result.copyPack)
        let focus = CoachFocusResolver.resolve(input: input)

        XCTAssertEqual(focus.activity?.title, "Core")
        XCTAssertEqual(focus.source, .upcoming)
        XCTAssertEqual(focus.phase, .pre)
        XCTAssertEqual(focus.family, .strength)
        XCTAssertEqual(focus.type, .core)
        XCTAssertEqual(result.context.activityType, .core)

        for forbidden in forbiddenPostStrength {
            XCTAssertNotEqual(result.scenario, forbidden)
        }

        XCTAssertTrue(
            result.scenario == .lowRecoveryPrep || result.scenario == .activeStrength,
            "Expected pre-session Core scenario, got \(result.scenario.rawValue)"
        )

        let story = joinedRussianCopy(pack, bridge: bridge)
        XCTAssertFalse(story.contains("После силовой"))
        XCTAssertFalse(story.contains("Последний подход"))
        XCTAssertFalse(story.lowercased().contains("last set"))

        assertConsistentSelection(input: input, result: result)
    }

    func testCompletedWalkWithWorkoutTypeIsNotClassifiedAsStrength() {
        let now = date(hour: 9, minute: 7)
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-58 * 60),
            durationMinutes: 55,
            completed: true
        )

        XCTAssertEqual(CoachActivityClassifier.type(for: walk), .walk)
        XCTAssertEqual(CoachActivityClassifier.family(for: walk), .recovery)
    }

    // MARK: - 1. Active activity always wins

    func testActiveCyclingWithFutureCoreUsesDuringEndurance() {
        let now = date(hour: 14, minute: 0)
        let cycling = activeActivity(
            title: "Ride",
            start: now.addingTimeInterval(-30 * 60),
            durationMinutes: 120,
            icon: "figure.outdoor.cycle"
        )
        let core = upcomingActivity(title: "Core", at: now.addingTimeInterval(90 * 60))

        assertSelection(
            now: now,
            activities: [cycling, core],
            expectedScenario: .duringEndurance,
            expectedSource: .active,
            expectedPhase: .during,
            expectedFamily: .endurance
        )
    }

    func testActiveCoreWithFutureWalkUsesDuringStrength() {
        let now = date(hour: 14, minute: 0)
        let core = activeActivity(title: "Core", start: now.addingTimeInterval(-20 * 60), durationMinutes: 45)
        let walk = upcomingActivity(title: "Walk", at: now.addingTimeInterval(90 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [core, walk],
            expectedScenario: .duringStrength,
            expectedSource: .active,
            expectedPhase: .during,
            expectedFamily: .strength
        )
    }

    func testActiveSaunaWithFutureCyclingUsesSaunaActive() {
        let now = date(hour: 15, minute: 0)
        var sauna = activeActivity(title: "Sauna", start: now.addingTimeInterval(-10 * 60), durationMinutes: 30)
        sauna.type = "sauna"
        let cycling = upcomingActivity(title: "Cycling", at: now.addingTimeInterval(120 * 60))

        assertSelection(
            now: now,
            activities: [sauna, cycling],
            expectedScenario: .saunaActive,
            expectedSource: .active,
            expectedPhase: .during,
            expectedFamily: .heat
        )
    }

    // MARK: - 2. Upcoming serious beats old completed

    func testCompletedWalkWithUpcomingCoreUsesPreSessionStrength() {
        let now = date(hour: 9, minute: 0)
        let walk = completedActivity(title: "Walk", endedMinutesAgo: 15, durationMinutes: 55, relativeTo: now, type: "recovery")
        let core = upcomingActivity(title: "Core", at: now.addingTimeInterval(80 * 60))

        assertSelection(
            now: now,
            activities: [walk, core],
            allowedScenarios: [.activeStrength, .lowRecoveryPrep],
            forbiddenScenarios: forbiddenPostStrength,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .strength
        )
    }

    func testCompletedWalkWithUpcomingCyclingUsesPreSessionEndurance() {
        let now = date(hour: 9, minute: 0)
        let walk = completedActivity(title: "Walk", endedMinutesAgo: 20, durationMinutes: 40, relativeTo: now, type: "recovery")
        let cycling = upcomingActivity(title: "Cycling", at: now.addingTimeInterval(90 * 60), icon: "figure.outdoor.cycle")

        assertSelection(
            now: now,
            activities: [walk, cycling],
            allowedScenarios: [.activeEndurance, .lowRecoveryPrep],
            forbiddenScenarios: forbiddenPostEndurance,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .endurance
        )
    }

    func testCompletedYogaWithUpcomingTennisUsesPreSessionRacket() {
        let now = date(hour: 11, minute: 0)
        let yoga = completedActivity(title: "Yoga", endedMinutesAgo: 10, durationMinutes: 45, relativeTo: now, type: "recovery")
        let tennis = upcomingActivity(title: "Tennis", at: now.addingTimeInterval(75 * 60))

        assertSelection(
            now: now,
            activities: [yoga, tennis],
            allowedScenarios: [.activeRacket, .lowRecoveryPrep],
            forbiddenScenarios: forbiddenPostMindfulRecovery,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .racket
        )
    }

    func testCompletedSaunaWithUpcomingRunUsesPreSessionEndurance() {
        let now = date(hour: 12, minute: 0)
        var sauna = completedActivity(title: "Sauna", endedMinutesAgo: 12, durationMinutes: 25, relativeTo: now)
        sauna.type = "sauna"
        let run = upcomingActivity(title: "Run", at: now.addingTimeInterval(90 * 60))

        assertSelection(
            now: now,
            activities: [sauna, run],
            allowedScenarios: [.activeEndurance, .lowRecoveryPrep],
            forbiddenScenarios: [.saunaRecovery],
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .endurance
        )
    }

    // MARK: - 3. Completed same-family post window

    func testCompletedCore15MinutesAgoUsesPostStrengthImmediate() {
        let now = date(hour: 10, minute: 30)
        let core = completedActivity(title: "Core", endedMinutesAgo: 15, durationMinutes: 45, relativeTo: now)

        assertSelection(
            now: now,
            activities: [core],
            expectedScenario: .postStrengthImmediate,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .strength
        )
    }

    func testCompletedCycling15MinutesAgoUsesPostEnduranceImmediate() {
        let now = date(hour: 14, minute: 0)
        let cycling = completedActivity(
            title: "Cycling",
            endedMinutesAgo: 15,
            durationMinutes: 90,
            relativeTo: now,
            icon: "figure.outdoor.cycle"
        )

        assertSelection(
            now: now,
            activities: [cycling],
            expectedScenario: .postEnduranceImmediate,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .endurance
        )
    }

    func testCompletedTennis15MinutesAgoUsesPostRacketImmediate() {
        let now = date(hour: 16, minute: 0)
        let tennis = completedActivity(title: "Tennis", endedMinutesAgo: 15, durationMinutes: 75, relativeTo: now)

        assertSelection(
            now: now,
            activities: [tennis],
            expectedScenario: .postRacketImmediate,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .racket
        )
    }

    func testCompletedYoga15MinutesAgoUsesPostRecoveryImmediate() {
        let now = date(hour: 9, minute: 30)
        let yoga = completedActivity(title: "Yoga", endedMinutesAgo: 15, durationMinutes: 40, relativeTo: now, type: "recovery")

        assertSelection(
            now: now,
            activities: [yoga],
            expectedScenario: .postRecoveryImmediate,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .recovery
        )
    }

    func testCompletedSaunaRecentlyUsesSaunaRecovery() {
        let now = date(hour: 18, minute: 0)
        var sauna = completedActivity(title: "Sauna", endedMinutesAgo: 10, durationMinutes: 25, relativeTo: now)
        sauna.type = "sauna"

        assertSelection(
            now: now,
            activities: [sauna],
            expectedScenario: .saunaRecovery,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .heat
        )
    }

    func testCompletedSauna90MinutesAgoReleasesHeatStory() {
        let now = date(hour: 16, minute: 30)
        var sauna = completedActivity(title: "Sauna", endedMinutesAgo: 90, durationMinutes: 45, relativeTo: now)
        sauna.type = "sauna"

        assertSelection(
            now: now,
            activities: [sauna],
            allowedScenarios: [.stableDay, .morningReadiness],
            forbiddenScenarios: [.saunaRecovery, .saunaActive, .saunaPreparation],
            expectedSource: .idle,
            expectedPhase: .idle,
            expectedFamily: .none
        )
    }

    // MARK: - 4. Completed different-family must not leak phase

    func testCompletedCoreWithFutureCyclingDoesNotUsePostEndurance() {
        let now = date(hour: 9, minute: 0)
        let core = completedActivity(title: "Core", endedMinutesAgo: 12, durationMinutes: 45, relativeTo: now)
        let cycling = upcomingActivity(
            title: "Long Cycling",
            at: now.addingTimeInterval(90 * 60),
            icon: "figure.outdoor.cycle",
            durationMinutes: 90
        )

        assertSelection(
            now: now,
            activities: [core, cycling],
            allowedScenarios: [.activeEndurance, .lowRecoveryPrep],
            forbiddenScenarios: forbiddenPostEndurance,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .endurance
        )
    }

    func testCompletedCyclingWithFutureSaunaDoesNotUseSaunaRecovery() {
        let now = date(hour: 17, minute: 0)
        let cycling = completedActivity(title: "Cycling", endedMinutesAgo: 20, durationMinutes: 90, relativeTo: now, icon: "figure.outdoor.cycle")
        var sauna = upcomingActivity(title: "Sauna", at: now.addingTimeInterval(90 * 60))
        sauna.type = "sauna"

        assertSelection(
            now: now,
            activities: [cycling, sauna],
            allowedScenarios: [.postEnduranceImmediate, .postEnduranceSettled],
            forbiddenScenarios: [.saunaRecovery],
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .endurance
        )
    }

    func testCompletedTennisWithFutureYogaDoesNotUsePostMindfulRecovery() {
        let now = date(hour: 10, minute: 0)
        let tennis = completedActivity(title: "Tennis", endedMinutesAgo: 18, durationMinutes: 70, relativeTo: now)
        let yoga = upcomingActivity(title: "Yoga", at: now.addingTimeInterval(80 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [tennis, yoga],
            expectedScenario: .postRacketImmediate,
            forbiddenScenarios: forbiddenPostMindfulRecovery,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .racket
        )
    }

    // MARK: - 5. Completed activity after post window

    func testCompletedCore70MinutesAgoWithNoUpcomingUsesPostStrengthSettled() {
        let now = date(hour: 11, minute: 30)
        let core = completedActivity(title: "Core", endedMinutesAgo: 70, durationMinutes: 45, relativeTo: now)

        assertSelection(
            now: now,
            activities: [core],
            expectedScenario: .postStrengthSettled,
            expectedSource: .recentCompleted,
            expectedPhase: .settledPost,
            expectedFamily: .strength
        )
    }

    func testCompletedCore181MinutesAgoWithFutureWalkUsesWalkScenario() {
        let now = date(hour: 14, minute: 0)
        let core = completedActivity(title: "Core", endedMinutesAgo: 181, durationMinutes: 45, relativeTo: now)
        let walk = upcomingActivity(title: "Walk", at: now.addingTimeInterval(60 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [core, walk],
            allowedScenarios: [.walkLightDay, .walkRecoveryAction],
            forbiddenScenarios: forbiddenPostStrength,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .recovery,
            expectedType: .walk
        )
    }

    func testCompletedCycling181MinutesAgoWithFutureCoreUsesStrengthPrep() {
        let now = date(hour: 15, minute: 0)
        let cycling = completedActivity(title: "Cycling", endedMinutesAgo: 181, durationMinutes: 90, relativeTo: now, icon: "figure.outdoor.cycle")
        let core = upcomingActivity(title: "Core", at: now.addingTimeInterval(45 * 60))

        assertSelection(
            now: now,
            activities: [cycling, core],
            allowedScenarios: [.activeStrength, .lowRecoveryPrep],
            forbiddenScenarios: forbiddenPostEndurance,
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .strength
        )
    }

    // MARK: - 6. Future activity near window

    func testCoreIn30MinutesUsesStrengthPrep() {
        let now = date(hour: 10, minute: 0)
        let core = upcomingActivity(title: "Core", at: now.addingTimeInterval(30 * 60))

        assertSelection(
            now: now,
            activities: [core],
            allowedScenarios: [.activeStrength, .lowRecoveryPrep],
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .strength
        )
    }

    func testWalkIn90MinutesUsesWalkScenarioNotStableDay() {
        let now = date(hour: 8, minute: 0)
        let walk = upcomingActivity(title: "Walk", at: now.addingTimeInterval(90 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [walk],
            allowedScenarios: [.walkLightDay, .walkRecoveryAction],
            forbiddenScenarios: [.stableDay, .morningReadiness],
            expectedSource: .upcoming,
            expectedPhase: .pre,
            expectedFamily: .recovery,
            expectedType: .walk
        )
    }

    // MARK: - 7. Recovery vs training priority

    func testCompletedHeavyCycling15MinutesAgoWithUpcomingWalkKeepsPostEndurance() {
        let now = date(hour: 14, minute: 0)
        let cycling = completedActivity(title: "Long Cycling", endedMinutesAgo: 15, durationMinutes: 120, relativeTo: now, icon: "figure.outdoor.cycle")
        let walk = upcomingActivity(title: "Walk", at: now.addingTimeInterval(60 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [cycling, walk],
            expectedScenario: .postEnduranceImmediate,
            expectedSource: .recentCompleted,
            expectedPhase: .immediatePost,
            expectedFamily: .endurance
        )
    }

    func testCompletedHeavyCycling2HoursAgoWithUpcomingWalkUsesWalkRecoveryAction() {
        let now = date(hour: 16, minute: 0)
        let cycling = completedActivity(title: "Long Cycling", endedMinutesAgo: 120, durationMinutes: 120, relativeTo: now, icon: "figure.outdoor.cycle")
        let walk = upcomingActivity(title: "Walk", at: now.addingTimeInterval(45 * 60), type: "recovery")

        assertSelection(
            now: now,
            activities: [cycling, walk],
            expectedScenario: .postEnduranceSettled,
            expectedSource: .recentCompleted,
            expectedPhase: .settledPost,
            expectedFamily: .endurance
        )
    }

    // MARK: - 8. Low sleep / low recovery with future serious activity

    func testUpcomingCoreWithShortSleepUsesPreSessionNotPost() {
        let now = date(hour: 9, minute: 0)
        let core = upcomingActivity(title: "Core", at: now.addingTimeInterval(80 * 60))

        let input = makeInput(
            now: now,
            activities: [core],
            recovery: CoachRecoveryContext(recoveryPercent: 75, sleepHours: 5.0),
            brainHour: 9
        )
        let result = CoachEngine.evaluate(input: input)
        let focus = CoachFocusResolver.resolve(input: input)

        XCTAssertEqual(focus.source, .upcoming)
        XCTAssertEqual(focus.phase, .pre)
        XCTAssertTrue(result.scenario == .lowRecoveryPrep || result.scenario == .activeStrength)
        for forbidden in forbiddenPostStrength {
            XCTAssertNotEqual(result.scenario, forbidden)
        }
        assertConsistentSelection(input: input, result: result)
    }

    func testUpcomingCyclingWithLowRecoveryUsesPreSessionNotPost() {
        let now = date(hour: 13, minute: 0)
        let cycling = upcomingActivity(title: "Cycling", at: now.addingTimeInterval(90 * 60), icon: "figure.outdoor.cycle")

        let input = makeInput(
            now: now,
            activities: [cycling],
            recovery: CoachRecoveryContext(recoveryPercent: 35, sleepHours: 7.0),
            brainHour: 13
        )
        let result = CoachEngine.evaluate(input: input)

        XCTAssertEqual(CoachFocusResolver.resolve(input: input).source, .upcoming)
        XCTAssertTrue(result.scenario == .lowRecoveryPrep || result.scenario == .activeEndurance)
        for forbidden in forbiddenPostEndurance {
            XCTAssertNotEqual(result.scenario, forbidden)
        }
        assertConsistentSelection(input: input, result: result)
    }

    // MARK: - 9. Copy subject guard on selected scenarios

    func testPostStrengthImmediateCopyMentionsCompletedStrength() throws {
        let now = date(hour: 10, minute: 30)
        let core = completedActivity(title: "Core", endedMinutesAgo: 12, durationMinutes: 45, relativeTo: now)
        let result = CoachEngine.evaluate(input: makeInput(now: now, activities: [core], brainHour: 10))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .postStrengthImmediate)
        XCTAssertTrue(
            CoachCopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: .postStrengthImmediate,
                activityType: .core
            )
        )
    }

    func testActiveEnduranceCopyMentionsUpcomingRide() throws {
        let now = date(hour: 13, minute: 0)
        let cycling = upcomingActivity(title: "Cycling", at: now.addingTimeInterval(90 * 60), icon: "figure.outdoor.cycle")
        let result = CoachEngine.evaluate(input: makeInput(now: now, activities: [cycling], brainHour: 13))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertTrue(result.scenario == .activeEndurance || result.scenario == .lowRecoveryPrep)
        XCTAssertTrue(
            CoachCopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: result.scenario,
                activityType: .cycling
            )
        )
    }

    func testWalkScenarioCopyMentionsWalk() throws {
        let now = date(hour: 9, minute: 0)
        let walk = completedActivity(title: "Walk", endedMinutesAgo: 5, durationMinutes: 30, relativeTo: now, type: "recovery")
        let result = CoachEngine.evaluate(input: makeInput(now: now, activities: [walk], brainHour: 9))
        let pack = try XCTUnwrap(result.copyPack)

        let walkScenarios: Set<CoachScenarioKey> = [.walkLightDay, .walkRecoveryAction, .walkAfterHeavyLoad]
        XCTAssertTrue(walkScenarios.contains(result.scenario))
        XCTAssertTrue(
            CoachCopySubjectGuard.assessmentStartsWithScenarioSubject(
                pack: pack,
                scenario: result.scenario,
                activityType: .walk
            )
        )
    }

    // MARK: - Assertions

    private struct SelectionExpectation {
        let expectedScenario: CoachScenarioKey?
        let allowedScenarios: Set<CoachScenarioKey>?
        let forbiddenScenarios: Set<CoachScenarioKey>
        let expectedSource: CoachFocusSource?
        let expectedPhase: CoachSessionPhase?
        let expectedFamily: CoachActivityFamily?
        let expectedType: CoachActivityType?
    }

    private func assertSelection(
        now: Date,
        activities: [PlannedActivity],
        expectedScenario: CoachScenarioKey? = nil,
        allowedScenarios: Set<CoachScenarioKey>? = nil,
        forbiddenScenarios: Set<CoachScenarioKey> = [],
        expectedSource: CoachFocusSource? = nil,
        expectedPhase: CoachSessionPhase? = nil,
        expectedFamily: CoachActivityFamily? = nil,
        expectedType: CoachActivityType? = nil,
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5)
    ) {
        let input = makeInput(now: now, activities: activities, recovery: recovery, brainHour: Calendar.current.component(.hour, from: now))
        let result = CoachEngine.evaluate(input: input)
        let focus = CoachFocusResolver.resolve(input: input)

        if let expectedScenario {
            XCTAssertEqual(result.scenario, expectedScenario)
        }
        if let allowedScenarios {
            XCTAssertTrue(allowedScenarios.contains(result.scenario), "Expected one of \(allowedScenarios), got \(result.scenario.rawValue)")
        }
        for forbidden in forbiddenScenarios {
            XCTAssertNotEqual(result.scenario, forbidden)
        }
        if let expectedSource {
            XCTAssertEqual(focus.source, expectedSource)
            XCTAssertEqual(result.context.focusSource, expectedSource)
        }
        if let expectedPhase {
            XCTAssertEqual(focus.phase, expectedPhase)
            XCTAssertEqual(result.context.sessionPhase, expectedPhase)
        }
        if let expectedFamily {
            XCTAssertEqual(focus.family, expectedFamily)
            XCTAssertEqual(result.context.activityFamily, expectedFamily)
        }
        if let expectedType {
            XCTAssertEqual(focus.type, expectedType)
            XCTAssertEqual(result.context.activityType, expectedType)
        }

        assertConsistentSelection(input: input, result: result)
    }

    private func assertConsistentSelection(input: CoachInputSnapshot, result: CoachEngine.Result) {
        let focus = CoachFocusResolver.resolve(input: input)
        XCTAssertTrue(
            CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario),
            "Inconsistent selection for \(result.scenario.rawValue): source=\(focus.source.rawValue) family=\(focus.family.rawValue) phase=\(focus.phase.rawValue)"
        )
    }

    // MARK: - Builders

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        brainHour: Int
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: actualLoad ?? freshActualLoad(),
            recoveryContext: recovery,
            nutritionContext: nutrition ?? defaultNutrition(),
            source: "CoachSelectionMatrixTests"
        )
    }

    private func completedActivity(
        title: String,
        endedMinutesAgo: Int,
        durationMinutes: Int,
        relativeTo now: Date,
        type: String = "workout",
        icon: String = "figure.run"
    ) -> PlannedActivity {
        let end = now.addingTimeInterval(-TimeInterval(endedMinutesAgo * 60))
        let start = end.addingTimeInterval(-TimeInterval(durationMinutes * 60))
        return PlannedActivity(
            date: start,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true
        )
    }

    private func upcomingActivity(
        title: String,
        at date: Date,
        type: String = "workout",
        icon: String = "figure.run",
        durationMinutes: Int = 45
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: false
        )
    }

    private func activeActivity(
        title: String,
        start: Date,
        durationMinutes: Int,
        type: String = "workout",
        icon: String = "figure.run"
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: false
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func freshActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 200,
            exerciseMinutes: 20,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 0.4
        )
    }

    private func moderateActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 342,
            exerciseMinutes: 55,
            standHours: nil,
            activityGoalCalories: 560,
            activityProgress: 0.61
        )
    }

    private func defaultNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 1_800,
            caloriesGoal: 2_800,
            proteinCurrent: 90,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
    }

    private func emptyNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_800,
            proteinCurrent: 0,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 3.2
        )
    }

    private func joinedRussianCopy(
        _ pack: CoachCopyPack,
        bridge: CoachUIPresentation
    ) -> String {
        [
            bridge.coachTitle,
            pack.assessment.lines.map(\.russian).joined(),
            pack.recommendation.lines.map(\.russian).joined(),
            pack.avoid.lines.map(\.russian).joined(),
            pack.nextAction.lines.map(\.russian).joined()
        ].joined(separator: " ")
    }
}
