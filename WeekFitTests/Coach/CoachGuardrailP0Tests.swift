import XCTest
@testable import WeekFit

/// Explicit P0 guardrail coverage — see `COACH_GUARDRAIL_TEST_MAPPING.md`.
final class CoachGuardrailP0Tests: XCTestCase {

    private let now = CoachTestClock.reference
    private var morning: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
    }

    private let activeSessionOwners: Set<CoachFinalStoryOwner> = [
        .activeActivity,
        .pacingExecution,
        .sustainableExecution,
        .fuelingDuringActivity,
        .hydrationExecution
    ]

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Rule 4

    func testAdjustBeatsGetReadyWhenRecoveryPoorInPrepWindow() throws {
        let strengthSoon = makeState(
            activities: [
                matrixActivity(
                    type: "strength",
                    title: "Strength",
                    minutesFromNow: 40,
                    duration: 60,
                    icon: "dumbbell.fill",
                    baseDate: morning
                )
            ],
            currentDate: morning,
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            recoveryPercent: 48,
            sleepHours: 5.4
        )
        assertAdjustBeatsGetReady(in: strengthSoon, scenarioName: "strength prep 40m recovery 48%")

        let edgeRecovery = makeState(
            activities: [
                matrixActivity(
                    type: "running",
                    title: "Run",
                    minutesFromNow: 45,
                    duration: 60,
                    icon: "figure.run",
                    baseDate: morning
                )
            ],
            currentDate: morning,
            sleepState: .okay,
            recoveryState: .stable,
            readinessState: .compromised,
            recoveryPercent: 62,
            sleepHours: 6.8
        )
        assertAdjustBeatsGetReady(in: edgeRecovery, scenarioName: "run prep 45m recovery 62%")

        let matrixScenario = try XCTUnwrap(
            matrixScenario(named: "Run in 2h low recovery"),
            "Expected matrix scenario for low-recovery prep window"
        )
        let matrixState = CoachNarrativeMatrixStateBuilder.makeState(
            context: matrixScenario.context,
            activities: CoachNarrativeMatrixStateBuilder.activities(
                for: matrixScenario.context,
                at: CoachNarrativeMatrixStateBuilder.date(for: matrixScenario.context.time)
            ),
            currentDate: CoachNarrativeMatrixStateBuilder.date(for: matrixScenario.context.time)
        )
        assertAdjustBeatsGetReady(in: matrixState, scenarioName: matrixScenario.name)
    }

    func testMorningPlanCheckAdjustBeatsGetReady() throws {
        let morningTime = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: now) ?? morning
        let eveningStrength = matrixActivity(
            type: "strength",
            title: "Evening Strength",
            minutesFromNow: 630,
            duration: 75,
            icon: "dumbbell.fill",
            baseDate: morningTime
        )
        let morningPlanCheck = makeState(
            activities: [eveningStrength],
            currentDate: morningTime,
            sleepState: .veryShort,
            recoveryState: .compromised,
            readinessState: .low,
            recoveryPercent: 46,
            sleepHours: 4.2
        )
        assertMorningPlanCheckAdjustBeatsGetReady(
            in: morningPlanCheck,
            scenarioName: "morning plan check evening strength recovery 46%"
        )

        let eveningIntervals = matrixActivity(
            type: "running",
            title: "Intervals",
            minutesFromNow: 600,
            duration: 75,
            icon: "figure.run",
            baseDate: morningTime
        )
        let hardEveningRun = makeState(
            activities: [eveningIntervals],
            currentDate: morningTime,
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            recoveryPercent: 52,
            sleepHours: 5.1
        )
        assertMorningPlanCheckAdjustBeatsGetReady(
            in: hardEveningRun,
            scenarioName: "morning plan check evening intervals recovery 52%"
        )
    }

    // MARK: - Rule 5

    func testLiveSessionNeverSurfacesSeparateAdjustCard() throws {
        let activeStrength = matrixActivity(
            type: "strength",
            title: "Upper body",
            minutesFromNow: -8,
            duration: 60,
            icon: "dumbbell.fill",
            baseDate: morning,
            source: "today"
        )
        let liveState = makeState(
            activities: [activeStrength],
            currentDate: morning,
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            activeCalories: 220,
            recoveryPercent: 44,
            sleepHours: 5.1
        )
        assertInSessionAbsorbsAdjust(in: liveState, scenarioName: "live strength low recovery")

        let matrixScenario = try XCTUnwrap(
            matrixScenario(named: "Strength active low recovery"),
            "Expected matrix scenario for live low recovery"
        )
        let matrixDate = CoachNarrativeMatrixStateBuilder.date(for: matrixScenario.context.time)
        let matrixState = CoachNarrativeMatrixStateBuilder.makeState(
            context: matrixScenario.context,
            activities: CoachNarrativeMatrixStateBuilder.activities(for: matrixScenario.context, at: matrixDate),
            currentDate: matrixDate,
            activeCalories: 180
        )
        assertInSessionAbsorbsAdjust(in: matrixState, scenarioName: matrixScenario.name)
    }

    // MARK: - Rule 3

    func testStableOverviewNeverLeadsWhenReadinessWarningEligible() throws {
        let prepStates = [
            makeState(
                activities: [
                    matrixActivity(
                        type: "running",
                        title: "Run",
                        minutesFromNow: 45,
                        duration: 60,
                        icon: "figure.run",
                        baseDate: morning
                    )
                ],
                currentDate: morning,
                sleepState: .short,
                recoveryState: .compromised,
                readinessState: .low,
                recoveryPercent: 48,
                sleepHours: 5.4
            ),
            makeState(
                activities: [
                    matrixActivity(
                        type: "cycling",
                        title: "Long ride",
                        minutesFromNow: 120,
                        duration: 150,
                        icon: "bicycle",
                        baseDate: morning
                    )
                ],
                currentDate: morning,
                sleepState: .short,
                recoveryState: .compromised,
                readinessState: .low,
                recoveryPercent: 48,
                sleepHours: 5.6
            )
        ]

        for state in prepStates {
            assertStableDoesNotMaskLimiter(in: state)
        }

        let matrixScenario = try XCTUnwrap(matrixScenario(named: "Run in 2h low recovery"))
        let matrixDate = CoachNarrativeMatrixStateBuilder.date(for: matrixScenario.context.time)
        let matrixState = CoachNarrativeMatrixStateBuilder.makeState(
            context: matrixScenario.context,
            activities: CoachNarrativeMatrixStateBuilder.activities(for: matrixScenario.context, at: matrixDate),
            currentDate: matrixDate
        )
        assertStableDoesNotMaskLimiter(in: matrixState)
    }

    // MARK: - Rule 6

    func testGoodRecoveryLiveWalkNeverShowsRedEaseUp() throws {
        let liveWalk = matrixActivity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -5,
            duration: 30,
            icon: "figure.walk",
            baseDate: morning,
            source: "today"
        )
        let customState = makeState(
            activities: [liveWalk],
            currentDate: morning,
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 75,
            recoveryPercent: 86,
            sleepHours: 7.8
        )
        assertNoRedEaseUpWithoutLimiter(in: customState, scenarioName: "live walk good recovery")

        for scenarioName in ["Easy walk active", "Walk active excellent recovery"] {
            let matrixScenario = try XCTUnwrap(matrixScenario(named: scenarioName))
            let matrixDate = CoachNarrativeMatrixStateBuilder.date(for: matrixScenario.context.time)
            let matrixState = CoachNarrativeMatrixStateBuilder.makeState(
                context: matrixScenario.context,
                activities: CoachNarrativeMatrixStateBuilder.activities(for: matrixScenario.context, at: matrixDate),
                currentDate: matrixDate,
                activeCalories: scenarioName.contains("excellent") ? 70 : 80
            )
            assertNoRedEaseUpWithoutLimiter(in: matrixState, scenarioName: matrixScenario.name)
        }
    }

    // MARK: - Assertions

    private func assertAdjustBeatsGetReady(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance = state.guidance, let story = state.finalStory else {
            XCTFail("Missing guidance or finalStory for \(scenarioName)", file: file, line: line)
            return
        }

        let isAdjustPriority =
            guidance.priority.focus == .trainingReadinessWarning ||
            guidance.priority.priority == .planChallenge
        XCTAssertTrue(
            isAdjustPriority,
            "\(scenarioName): expected Adjust priority, got focus=\(guidance.priority.focus) priority=\(guidance.priority.priority)",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            guidance.priority.focus,
            .prepareForActivity,
            "\(scenarioName): Get Ready focus must not win when recovery is poor in prep window",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            story.owner,
            .activityPreparation,
            "\(scenarioName): Get Ready owner must not lead when recovery is poor in prep window",
            file: file,
            line: line
        )
    }

    private func assertMorningPlanCheckAdjustBeatsGetReady(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance = state.guidance, let story = state.finalStory else {
            XCTFail("Missing guidance or finalStory for \(scenarioName)", file: file, line: line)
            return
        }

        let isAdjustPriority =
            guidance.priority.focus == .trainingReadinessWarning ||
            guidance.priority.priority == .planChallenge
        XCTAssertTrue(
            isAdjustPriority,
            "\(scenarioName): expected Adjust priority outside prep window, got focus=\(guidance.priority.focus) priority=\(guidance.priority.priority)",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            guidance.priority.focus,
            .prepareForActivity,
            "\(scenarioName): Get Ready focus must not win during morning plan check",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            story.owner,
            .activityPreparation,
            "\(scenarioName): Get Ready owner must not lead during morning plan check",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            story.owner,
            .stableOverview,
            "\(scenarioName): Steady Day must not mask poor morning readiness before evening hard session",
            file: file,
            line: line
        )
        XCTAssertEqual(
            story.owner,
            .readiness,
            "\(scenarioName): Adjust/readiness owner must lead during morning plan check, got \(story.owner.rawValue)",
            file: file,
            line: line
        )
    }

    private func assertInSessionAbsorbsAdjust(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance = state.guidance, let story = state.finalStory else {
            XCTFail("Missing guidance or finalStory for \(scenarioName)", file: file, line: line)
            return
        }

        XCTAssertTrue(
            guidance.phase.isActive,
            "\(scenarioName): expected live phase",
            file: file,
            line: line
        )
        XCTAssertTrue(
            activeSessionOwners.contains(story.owner),
            "\(scenarioName): expected In Session owner, got \(story.owner.rawValue)",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            story.owner,
            .readiness,
            "\(scenarioName): Adjust/readiness must not surface as a separate leading family while live",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            story.owner,
            .activityPreparation,
            "\(scenarioName): Get Ready must not lead while live",
            file: file,
            line: line
        )
    }

    private func assertStableDoesNotMaskLimiter(
        in state: CoachState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance = state.guidance, let story = state.finalStory else {
            XCTFail("Missing guidance or finalStory", file: file, line: line)
            return
        }

        let readinessWarningEligible =
            guidance.priority.focus == .trainingReadinessWarning ||
            guidance.priority.priority == .planChallenge ||
            guidance.priority.limiter == .trainingReadiness

        guard readinessWarningEligible else {
            return
        }

        XCTAssertNotEqual(
            story.owner,
            .stableOverview,
            "Steady Day must not lead when a readiness warning is eligible (focus=\(guidance.priority.focus))",
            file: file,
            line: line
        )
    }

    private func assertNoRedEaseUpWithoutLimiter(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance = state.guidance, let story = state.finalStory else {
            XCTFail("Missing guidance or finalStory for \(scenarioName)", file: file, line: line)
            return
        }

        XCTAssertTrue(
            guidance.phase.isActive,
            "\(scenarioName): expected live phase",
            file: file,
            line: line
        )

        if guidance.priority.focus == .trainingReadinessWarning {
            XCTAssertNotEqual(
                guidance.priority.strength,
                .critical,
                "\(scenarioName): critical readiness warning requires an active limiter",
                file: file,
                line: line
            )
        }

        let render = CoachFinalStoryRenderModel(story: story)
        let visible = [
            state.todayPresentation.title,
            state.todayPresentation.message,
            state.coachPresentation?.title,
            state.coachPresentation?.recommendation,
            render.title,
            render.primaryRecommendation,
            render.displayAvoid
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        XCTAssertFalse(
            visible.localizedCaseInsensitiveContains("not the day to push"),
            "\(scenarioName): good-recovery live walk must not show depleted ease-up copy",
            file: file,
            line: line
        )
        XCTAssertFalse(
            render.colorFamily == .stress &&
                visible.localizedCaseInsensitiveContains("ease up"),
            "\(scenarioName): red ease-up requires an active limiter",
            file: file,
            line: line
        )
    }

    // MARK: - Builders

    private func matrixScenario(named name: String) -> CoachNarrativeMatrixScenario? {
        CoachNarrativeMatrixFactory.allScenarios().first { $0.name == name }
    }

    private func matrixActivity(
        type: String,
        title: String,
        minutesFromNow: Int,
        duration: Int,
        icon: String,
        baseDate: Date,
        completed: Bool = false,
        source: String = "planner"
    ) -> PlannedActivity {
        CoachNarrativeMatrixStateBuilder.activity(
            type: type,
            title: title,
            minutesFromNow: minutesFromNow,
            duration: duration,
            icon: icon,
            completed: completed,
            baseDate: baseDate,
            source: source
        )
    }

    private func makeState(
        activities: [PlannedActivity],
        currentDate: Date,
        nutrition: CoachNutritionContext? = nil,
        sleepState: HumanBrain.SleepState = .okay,
        recoveryState: HumanBrain.RecoveryState = .stable,
        readinessState: HumanBrain.ReadinessState = .good,
        activeCalories: Double = 240,
        recoveryPercent: Int = 84,
        sleepHours: Double = 7.4
    ) -> CoachState {
        let resolvedNutrition = nutrition ?? defaultNutrition()
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: currentDate)
        brainConfig.hasAnyFoodLogged = (resolvedNutrition.mealsCount ?? 0) > 0
        brainConfig.waterProgress = resolvedNutrition.waterGoal > 0
            ? resolvedNutrition.waterCurrent / resolvedNutrition.waterGoal
            : 1
        brainConfig.hasWorkoutSoon = activities.contains { !$0.isCompleted && !$0.isSkipped }
        brainConfig.nextWorkout = activities.first { !$0.isCompleted && !$0.isSkipped }
        brainConfig.hoursToNextWorkout = brainConfig.nextWorkout.map {
            max(0, $0.date.timeIntervalSince(currentDate) / 3600)
        }
        brainConfig.hydration = resolvedNutrition.waterCurrent <= 0.5 ? .behind : .optimal
        brainConfig.fuel = resolvedNutrition.caloriesCurrent < 600 ? .underfueled : .good
        brainConfig.sleep = sleepState
        brainConfig.recovery = recoveryState
        brainConfig.readiness = readinessState
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: resolvedNutrition.proteinCurrent,
            carbs: resolvedNutrition.carbsCurrent,
            calories: resolvedNutrition.caloriesCurrent,
            waterLiters: resolvedNutrition.waterCurrent,
            activeCalories: activeCalories,
            sleepHours: sleepHours
        )

        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: currentDate,
            now: currentDate
        )
        let input = CoachInputSnapshot(
            selectedDate: currentDate,
            now: currentDate,
            brain: brain,
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: activeCalories,
                exerciseMinutes: nil,
                standHours: nil,
                activityGoalCalories: nil,
                activityProgress: nil
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: recoveryPercent, sleepHours: sleepHours),
            nutritionContext: resolvedNutrition,
            source: "CoachGuardrailP0Tests"
        )
        let guidance = CoachEngineV3.decide(
            from: brain.refreshedForCurrentLocalTime(activities: activities),
            plannedActivities: activities,
            selectedDate: currentDate,
            dayContext: dayContext,
            recoveryContext: input.recoveryContext,
            nutritionContext: resolvedNutrition
        )

        return CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: currentDate
        )
    }

    private func defaultNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 900,
            caloriesGoal: 2_400,
            proteinCurrent: 55,
            proteinGoal: 150,
            carbsCurrent: 90,
            carbsGoal: 280,
            fatsCurrent: 25,
            fatsGoal: 70,
            waterCurrent: 1.4,
            waterGoal: 2.5,
            mealsCount: 1,
            lastMealTime: CoachTestClock.offset(minutes: -120, from: now)
        )
    }
}

private extension CoachActivityPhaseV3 {
    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}
