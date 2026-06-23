import XCTest
@testable import WeekFit

/// Explanation-quality guardrails — Rules 1, 9, 13. See `COACH_GUARDRAIL_TEST_MAPPING.md`.
final class CoachGuardrailStakeContractTests: XCTestCase {

    private let now = CoachTestClock.reference
    private var morning: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
    }

    private var evening: Date {
        Calendar.current.date(bySettingHour: 20, minute: 30, second: 0, of: now) ?? now
    }

    private var midday: Date {
        Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: now) ?? now
    }

    private let stakeMarkers = [
        "recovery", "sleep", "tomorrow", "load", "training", "reserve", "body",
        "effort", "ride", "run", "session", "strength", "workout", "fatigue",
        "protect", "absorb", "limit", "readiness", "because", "more than",
        "matters", "spent", "hard", "tonight", "ease", "intensity"
    ]

    private let tomorrowActivityTokens = [
        "ride", "run", "strength", "session", "training", "intervals", "long", "cycling"
    ]

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Rule 9

    func testWindDownNamesTomorrowActivity() throws {
        let tomorrowRide = matrixActivity(
            type: "cycling",
            title: "Long ride",
            minutesFromNow: 18 * 60,
            duration: 210,
            icon: "bicycle",
            baseDate: midday
        )
        let customState = makeState(
            activities: [tomorrowRide],
            currentDate: midday,
            recoveryPercent: 82,
            sleepHours: 7.5
        )
        assertWindDownNamesTomorrowStake(in: customState, scenarioName: "midday tomorrow long ride")

        let tomorrowProtectionScenarios = CoachNarrativeMatrixFactory.allScenarios().filter {
            $0.group == .tomorrowProtection && $0.context.tomorrowHardSession
        }
        XCTAssertFalse(tomorrowProtectionScenarios.isEmpty)
        for scenario in tomorrowProtectionScenarios {
            let matrixDate = CoachNarrativeMatrixStateBuilder.date(for: scenario.context.time)
            let state = CoachNarrativeMatrixStateBuilder.makeState(
                context: scenario.context,
                activities: CoachNarrativeMatrixStateBuilder.activities(for: scenario.context, at: matrixDate),
                currentDate: matrixDate,
                activeCalories: 650,
                completedWorkoutsCount: scenario.context.hasCompletedWorkout ? 1 : nil
            )
            if requiresWindDownNamedStake(state) {
                assertWindDownNamesTomorrowStake(in: state, scenarioName: scenario.name)
            }
        }
    }

    // MARK: - Rule 13

    func testBehaviorChangeCopyIncludesStake() throws {
        let curatedNames = [
            "Run in 2h low recovery",
            "Strength active low recovery",
            "Hard run completed 30m ago",
            "Tomorrow hard session low recovery evening",
            "Tomorrow long ride after today load"
        ]
        for name in curatedNames {
            let scenario = try XCTUnwrap(matrixScenario(named: name), "Missing matrix scenario \(name)")
            let matrixDate = CoachNarrativeMatrixStateBuilder.date(for: scenario.context.time)
            let state = CoachNarrativeMatrixStateBuilder.makeState(
                context: scenario.context,
                activities: CoachNarrativeMatrixStateBuilder.activities(for: scenario.context, at: matrixDate),
                currentDate: matrixDate,
                activeCalories: 900,
                completedWorkoutsCount: scenario.context.hasCompletedWorkout ? 1 : nil
            )
            assertCoachExplanationIncludesStake(in: state, scenarioName: name)
        }

        var failures: [String] = []
        for scenario in CoachNarrativeMatrixFactory.allScenarios() {
            let state = scenario.makeState()
            guard requiresStakeExplanation(state) else { continue }
            if !coachExplanationIncludesStake(state) {
                failures.append("\(scenario.id). \(scenario.name)")
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "Behavior-change copy missing stake on Coach tab:\n" + failures.joined(separator: "\n")
        )
    }

    // MARK: - Rule 1

    func testMatrixScenariosHaveExactlyOneLeadingFamily() {
        var failures: [String] = []
        for scenario in CoachNarrativeMatrixFactory.allScenarios() {
            let state = scenario.makeState()
            if let message = singleFamilyViolation(for: state, scenarioName: scenario.name) {
                failures.append("\(scenario.id). \(message)")
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "Multiple leading families detected:\n" + failures.joined(separator: "\n")
        )
    }

    // MARK: - Rule 9 assertions

    private func requiresWindDownNamedStake(_ state: CoachState) -> Bool {
        guard let story = state.finalStory else { return false }
        let family = CoachGuardrailV5Family.from(story: story)
        guard family == .windDown else { return false }
        if story.owner == .tomorrowProtection {
            return true
        }
        if story.primaryFocus == .tomorrowPlanRisk {
            return true
        }
        return state.guidance?.priority.objective == .protectTomorrow
    }

    private func assertWindDownNamesTomorrowStake(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let story = state.finalStory else {
            XCTFail("\(scenarioName): missing finalStory", file: file, line: line)
            return
        }
        let render = CoachFinalStoryRenderModel(story: story)
        let coach = state.coachPresentation
        let visible = [
            render.title,
            render.displaySubtitle,
            render.subtitle,
            render.primaryRecommendation,
            coach?.title,
            coach?.message,
            coach?.recommendation
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .lowercased()

        let hasNamedStake =
            visible.contains("tomorrow's") ||
            (visible.contains("tomorrow") && tomorrowActivityTokens.contains { visible.contains($0) }) ||
            visible.contains("protect tomorrow's")

        XCTAssertTrue(
            hasNamedStake,
            "\(scenarioName): Wind Down must name tomorrow's stake, got: \"\(render.title)\" / \"\(render.displaySubtitle)\"",
            file: file,
            line: line
        )
    }

    // MARK: - Rule 13 assertions

    private func requiresStakeExplanation(_ state: CoachState) -> Bool {
        guard let story = state.finalStory, let guidance = state.guidance else { return false }
        let render = CoachFinalStoryRenderModel(story: story)

        switch CoachGuardrailV5Family.from(story: story) {
        case .adjust:
            return true
        case .windDown:
            return story.owner == .tomorrowProtection || guidance.priority.objective == .protectTomorrow
        case .recover:
            return story.owner == .postActivityRecovery
        case .inSession:
            return render.colorFamily == .stress ||
                guidance.priority.limiter == .trainingReadiness ||
                guidance.priority.strength == .critical ||
                (guidance.priority.strength == .high && guidance.priority.limiter != .timing)
        case .getReady, .steadyDay, .heatSauna:
            return false
        }
    }

    private func assertCoachExplanationIncludesStake(
        in state: CoachState,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            coachExplanationIncludesStake(state),
            "\(scenarioName): Coach explanation must include a named stake (why, not action-only)",
            file: file,
            line: line
        )
    }

    private func coachExplanationIncludesStake(_ state: CoachState) -> Bool {
        guard let story = state.finalStory, let coach = state.coachPresentation else { return false }
        let render = CoachFinalStoryRenderModel(story: story)

        let explanation = [
            coach.title,
            coach.message,
            coach.recommendation,
            render.title,
            render.displaySubtitle.isEmpty ? render.subtitle : render.displaySubtitle,
            render.whatHappened,
            render.primaryRecommendation,
            render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid,
            story.whatHappened.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved
        ] + render.whyRows.map(\.title)

        let text = explanation
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        guard text.count >= 16 else { return false }
        return stakeMarkers.contains { text.contains($0) }
    }

    // MARK: - Rule 1 assertions

    private func singleFamilyViolation(for state: CoachState, scenarioName: String) -> String? {
        guard let story = state.finalStory, let guidance = state.guidance else {
            return "\(scenarioName): missing story or guidance"
        }

        let storyFamily = CoachGuardrailV5Family.from(story: story)

        if isActivePhase(guidance.phase) {
            if storyFamily != .inSession {
                return "\(scenarioName): live phase but leading family=\(storyFamily.rawValue)"
            }
            if story.owner == .readiness {
                return "\(scenarioName): live phase but Adjust/readiness owner leads"
            }
            if story.owner == .activityPreparation {
                return "\(scenarioName): live phase but Get Ready owner leads"
            }
            return nil
        }

        // Rule 1 protects visible explanation — Today and Coach must not split attention across families.
        let todayCopy = [
            state.todayPresentation.title,
            state.todayPresentation.message
        ].joined(separator: " ")
        let coachCopy = [
            state.coachPresentation?.title,
            state.coachPresentation?.message,
            state.coachPresentation?.recommendation
        ].compactMap { $0 }.joined(separator: " ")

        if let todayFamily = confidentlyInferredFamily(from: todayCopy),
           let coachFamily = confidentlyInferredFamily(from: coachCopy),
           todayFamily != coachFamily {
            return "\(scenarioName): Today=\(todayFamily.rawValue) Coach=\(coachFamily.rawValue)"
        }

        let heroCopy = [
            todayCopy,
            coachCopy,
            CoachFinalStoryRenderModel(story: story).title
        ].joined(separator: " ")

        let impliedFamilies = Set(
            CoachGuardrailV5Family.behaviorChangeFamilies.filter { copyMatchesFamily(heroCopy, family: $0) }
        )
        if impliedFamilies.count > 1 {
            let labels = impliedFamilies.map(\.rawValue).sorted().joined(separator: ", ")
            return "\(scenarioName): multiple visible leading families: \(labels)"
        }

        return nil
    }

    private func confidentlyInferredFamily(from copy: String) -> CoachGuardrailV5Family? {
        let matches = CoachGuardrailV5Family.behaviorChangeFamilies.filter { copyMatchesFamily(copy, family: $0) }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    private func copyMatchesFamily(_ copy: String, family: CoachGuardrailV5Family) -> Bool {
        let text = copy.lowercased()
        return familyCopyMarkers[family]?.contains { text.contains($0) } == true
    }

    private var familyCopyMarkers: [CoachGuardrailV5Family: [String]] {
        [
            .getReady: [
                "prepare for", "get ready", "before the start", "before training",
                "prep for", "prepare calmly"
            ],
            .adjust: [
                "adjust the plan", "change the plan", "reduce the plan", "readiness warning",
                "training readiness", "go gently on the plan", "plan needs adjusting"
            ],
            .recover: [
                "recovery window", "after the session", "after training", "post-workout",
                "let the body absorb", "recovery matters most", "absorb today's"
            ],
            .windDown: [
                "protect tomorrow", "wind down", "save energy for tomorrow", "tomorrow's session",
                "tomorrow's ride", "tomorrow's run", "tomorrow matters"
            ],
            .inSession: [
                "ease up now", "during the session", "while you're riding", "while you're running",
                "right now during", "in this session"
            ]
        ]
    }

    private func isActivePhase(_ phase: CoachActivityPhaseV3?) -> Bool {
        guard let phase else { return false }
        if case .active = phase { return true }
        return false
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
            source: "CoachGuardrailStakeContractTests"
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
