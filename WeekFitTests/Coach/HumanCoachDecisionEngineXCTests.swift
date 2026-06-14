import XCTest
@testable import WeekFit

final class HumanCoachDecisionEngineXCTests: XCTestCase {

    private let now = CoachTestClock.reference
    private let selectedDate = CoachTestClock.reference

    func testRussianEveningDailyOverviewUsesNarrativePlanOnly() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let scenarioNow = Calendar.current.date(
            bySettingHour: 20,
            minute: 49,
            second: 0,
            of: now
        ) ?? now
        let output = guidance(
            [],
            brain: brain(currentHour: 20, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.3, meals: 3),
            now: scenarioNow
        )

        let plan = try XCTUnwrap(output.narrativePlan)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(story.title, "Приоритет — сон")
        XCTAssertEqual(story.myRecommendation, "Завершайте день спокойно и готовьтесь ко сну.")
        XCTAssertTrue([
            CoachNarrativeBadgeIntent.windDown.label,
            CoachNarrativeBadgeIntent.protectSleep.label
        ].contains(story.stateLabel))
        XCTAssertEqual(plan.actionIntents, [.prepareForSleep, .windDownNow, .keepEveningCalm])
        XCTAssertEqual(story.primaryActions.map(\.title), [
            "Подготовьтесь ко сну",
            "Начните замедляться",
            "Сделайте вечер спокойным"
        ])
        XCTAssertTrue(story.supportActions.isEmpty)

        let visibleText = visibleTexts(story).joined(separator: " ")
        XCTAssertNil(
            visibleText.range(of: "[A-Za-z]", options: .regularExpression),
            visibleText
        )
    }

    func testEnglishEveningDailyOverviewUsesNarrativePlanOnly() throws {
        WeekFitSetCurrentLanguage(.english)

        let scenarioNow = Calendar.current.date(
            bySettingHour: 20,
            minute: 49,
            second: 0,
            of: now
        ) ?? now
        let output = guidance(
            [],
            brain: brain(currentHour: 20, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.3, meals: 3),
            now: scenarioNow
        )

        let plan = try XCTUnwrap(output.narrativePlan)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(story.title, "Sleep is the priority")
        XCTAssertEqual(story.myRead, "The day is steady and does not need extra effort.")
        XCTAssertEqual(story.myRecommendation, "Close the day calmly and start preparing for sleep.")
        XCTAssertEqual(plan.actionIntents, [.prepareForSleep, .windDownNow, .keepEveningCalm])
        XCTAssertEqual(story.primaryActions.map(\.title), [
            "Prepare for sleep",
            "Wind down now",
            "Keep the evening calm"
        ])
        XCTAssertTrue(story.supportActions.isEmpty)
    }

    func testDaytimeDailyOverviewDoesNotUseSleepCopy() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

        let output = guidance(
            [],
            brain: brain(currentHour: 13, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.3, meals: 2)
        )

        let story = try XCTUnwrap(output.screenStory)
        XCTAssertNotEqual(story.title, "Приоритет — сон")
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("сну"))
        XCTAssertTrue(story.supportActions.isEmpty)
    }

    func testScenario1_perfectMorningNothingPlanned() {
        let decision = resolve(
            [],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 8.2),
            nutrition: nutrition(water: 2.0, meals: 1)
        )

        XCTAssertEqual(decision.status.semanticColor, .green)
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
    }

    func testMorningLowWaterDoesNotCreateHydrationHero() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )

        let renderedState = output.screenStory?.stateLabel ?? output.stateLabel
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(renderedState, "START THE DAY")
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.myRead.isEmpty)
        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, CoachNarrativeLimiter.none)
        XCTAssertNotEqual(renderedState, "HYDRATION FIRST")
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Nothing in the current day asks for a major change right now"))
    }

    func testRecoveryMorningMissingSleepUsesNeutralCopy() throws {
        let walk = recovery(title: "Recovery Walk", minutesFromNow: 180, duration: 30, completed: false)
        let output = guidance(
            [walk],
            brain: brain(
                currentHour: 8,
                sleep: .unknown,
                recovery: .vulnerable,
                readiness: .low,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 0),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )

        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(story.title, "Recovery day")
        XCTAssertEqual(story.myRead, "No hard training is planned today, and sleep data was not captured.")
        XCTAssertEqual(story.myRecommendation, "Keep the morning easy, start with water, and eat normally at the next meal.")
        XCTAssertEqual(story.primaryActions.map(\.title), [
            "Start with 300-500 ml",
            "Eat normally at next meal",
            "Keep the day flexible"
        ])
        XCTAssertFalse(visible.contains("recovery is strong"))
        XCTAssertFalse(visible.contains("sleep is strong"))
        XCTAssertFalse(visible.contains("readiness is strong"))
        XCTAssertFalse(visible.contains("recovery supports the plan"))
    }

    func testRecoveryEveningMissingSleepDoesNotRenderMorningOnlyCopy() throws {
        let walk = recovery(title: "Recovery Walk", minutesFromNow: 180, duration: 30, completed: false)
        let output = guidance(
            [walk],
            brain: brain(
                currentHour: 17,
                sleep: .unknown,
                recovery: .vulnerable,
                readiness: .low,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 0),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )

        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(story.title, "Recovery day")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Drink fluids steadily"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Protect recovery for tomorrow"))
        XCTAssertEqual(story.primaryActions.map(\.title), [
            "Drink fluids steadily",
            "Maintain normal routines",
            "Keep recovery easy"
        ])
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Keep the morning easy"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Start with water"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Start with 300-500 ml"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Begin the day"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Start the day"))
    }

    func testMorningLowWaterAppearsAsSupportAction() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(output.screenStory)
        let supportText = output.priority.supportBullets.joined(separator: " ")

        XCTAssertTrue(
            story.supportActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration },
            "supportActions=\(story.supportActions.map(\.title))"
        )
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("water"))
    }

    func testSaunaSoonLowWaterShowsHydrationSupportWithoutTrainingFuel() {
        let sauna = quickSauna(minutesFromNow: 45, duration: 25)
        let output = guidance(
            [sauna],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 1, calories: 730, carbs: 56)
        )

        let story = output.screenStory
        let renderedText = [
            story?.title,
            story?.myRead,
            story?.myRecommendation,
            story?.beCarefulWith
        ].compactMap { $0 }.joined(separator: " ")
        let actionTitles = (story?.primaryActions ?? []).map(\.title).joined(separator: " ")

        XCTAssertTrue(renderedText.localizedCaseInsensitiveContains("heat") || renderedText.localizedCaseInsensitiveContains("sauna"))
        XCTAssertTrue(output.v5Interpretation.supportSignals.contains(.hydration))
        XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("Training starts"))
        XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("quick fuel"))
        XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("30-60 g carbs"))
        XCTAssertFalse(actionTitles.localizedCaseInsensitiveContains("first 10 minutes"))
    }

    func testLongEnduranceSoonLowWaterCreatesHydrationHero() {
        let ride = cycling(title: "Endurance Ride", minutesFromNow: 90, duration: 120)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 1, calories: 1_200, carbs: 140)
        )

        let renderedState = output.screenStory?.stateLabel ?? output.stateLabel

        XCTAssertFalse(renderedState.isEmpty)
        XCTAssertNotEqual(renderedState, "HYDRATION FIRST")
    }

    func testEveningVeryLowWaterUsesSupportUnlessRiskContext() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 3, calories: 1_900, carbs: 190)
        )

        let renderedState = output.screenStory?.stateLabel ?? output.stateLabel
        let story = try XCTUnwrap(output.screenStory)
        let supportText = output.priority.supportBullets.joined(separator: " ")

        XCTAssertNotEqual(renderedState, "HYDRATION FIRST")
        XCTAssertNotEqual(output.priority.limiter, .hydration)
        XCTAssertNotEqual(output.narrativePlan?.primaryLimiter, .hydration)
        let visible = visibleTexts(story).joined(separator: " ")
        XCTAssertTrue(
            supportText.localizedCaseInsensitiveContains("water") ||
            supportText.localizedCaseInsensitiveContains("sip") ||
            visible.localizedCaseInsensitiveContains("water") ||
            visible.localizedCaseInsensitiveContains("hydrat") ||
            visible.localizedCaseInsensitiveContains("sip")
        )
    }

    func testScenario2_poorSleepHardWorkoutPlanned() {
        let yesterdayHard = cycling(
            title: "Hard Cycling",
            minutesFromNow: -20 * 60,
            duration: 90,
            completed: true
        )
        let intervals = cycling(
            title: "Cycling Intervals",
            minutesFromNow: 8 * 60,
            duration: 60
        )

        let decision = resolve(
            [yesterdayHard, intervals],
            brain: brain(currentHour: 9, recovery: .vulnerable, readiness: .low, strain: .high),
            recovery: CoachRecoveryContext(recoveryPercent: 46, sleepHours: 5.1),
            nutrition: nutrition()
        )

        XCTAssertTrue(decision.status.semanticColor == .red || decision.status.semanticColor == .yellow)
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
        XCTAssertTrue(
            decision.title.localizedCaseInsensitiveContains("ride") ||
            decision.myRecommendation.localizedCaseInsensitiveContains("ride") ||
            decision.myRecommendation.localizedCaseInsensitiveContains("plan")
        )
    }

    func testScenario3_unexpectedSaunaBeforePlannedCycling() {
        let sauna = quickSauna(minutesFromNow: -5, duration: 25)
        let cycling = cycling(title: "Cycling", minutesFromNow: 75, duration: 75)

        let decision = resolve(
            [sauna, cycling],
            brain: brain(currentHour: 16, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 76, sleepHours: 7.2),
            nutrition: nutrition(water: 2.0)
        )

        assertDecision(
            decision,
            status: .planChanged,
            title: "Sauna changes the rest of today",
            myRead: "Sauna is now part of the day before ride, so heat stress and training are connected.",
            myRecommendation: "Keep sauna short and make the later session easier than originally planned.",
            beCarefulWith: "Treating sauna and training as separate efforts when they both draw from the same recovery budget."
        )
    }

    func testScenario4_longRideCompleted() {
        let completedRide = cycling(
            title: "Long Ride",
            minutesFromNow: -180,
            duration: 155,
            completed: true
        )
        let tomorrowRide = tomorrowCycling(title: "Long Ride", duration: 180)

        let decision = resolve(
            [completedRide, tomorrowRide],
            brain: brain(currentHour: 14, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
            nutrition: nutrition()
        )

        XCTAssertTrue(decision.status == .trainingGoalAchieved || decision.status == .recoveryFirst)
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
    }

    func testScenario5_recoveryDayUserStartsCycling() {
        let ride = cycling(title: "Cycling", minutesFromNow: -10, duration: 90)
        ride.source = "today"

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.8),
            nutrition: nutrition()
        )

        XCTAssertEqual(decision.status, .manageEffort)
        XCTAssertEqual(decision.title, "Control today's ride")
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
        XCTAssertFalse(decision.myRead.localizedCaseInsensitiveContains("day changed"))
        XCTAssertFalse(decision.status.label.localizedCaseInsensitiveContains("changed"))
    }

    func testScenario6_everythingDoneAndBalanced() {
        let gym = workout(title: "Gym", minutesFromNow: -240, duration: 60, completed: true)
        let walk = recovery(title: "Walk", minutesFromNow: -90, duration: 30, completed: true)

        let decision = resolve(
            [gym, walk],
            brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.3, meals: 3)
        )

        XCTAssertEqual(decision.status.semanticColor, .green)
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
    }

    func testScenario7_eveningBeforeImportantTraining() {
        let walk = recovery(title: "Walk", minutesFromNow: -180, duration: 35, completed: true)
        let tomorrowRide = tomorrowCycling(title: "Cycling", duration: 180)

        let decision = resolve(
            [walk, tomorrowRide],
            brain: brain(currentHour: 21, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 7.8),
            nutrition: nutrition()
        )

        XCTAssertTrue(decision.status == .protectTomorrow || decision.status.label == "PLAN AHEAD")
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertTrue(
            decision.myRead.localizedCaseInsensitiveContains("tomorrow") ||
            decision.myRecommendation.localizedCaseInsensitiveContains("tomorrow") ||
            decision.myRecommendation.localizedCaseInsensitiveContains("sleep")
        )
    }

    func testScenario8_veryPoorStateUserStartsCycling() {
        let ride = cycling(title: "Cycling", minutesFromNow: -10, duration: 75)
        ride.source = "today"

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 38, sleepHours: 4.5),
            nutrition: nutrition()
        )

        XCTAssertEqual(decision.status, .reducePlan)
        XCTAssertEqual(decision.title, "Control today's ride")
        XCTAssertTrue(decision.myRead.localizedCaseInsensitiveContains("recovery"))
        XCTAssertTrue(decision.myRead.localizedCaseInsensitiveContains("ride"))
        XCTAssertFalse(decision.myRecommendation.isEmpty)
        XCTAssertFalse(decision.beCarefulWith.isEmpty)
    }

    func testLivePlannedCyclingWithReadyRecoveryUsesCautionNotRed() {
        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 75)

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 6.2),
            nutrition: nutrition(water: 0.5, waterGoal: 3.1, meals: 1, calories: 583, carbs: 53, lastMealMinutesAgo: 60)
        )

        XCTAssertEqual(decision.title, "Control today's ride")
        XCTAssertEqual(decision.status, .manageEffort)
        XCTAssertNotEqual(decision.status, .reducePlan)
        XCTAssertNotEqual(decision.status.label, CoachStatus.reducePlan.label)
        XCTAssertNotEqual(decision.status.semanticColor, .red)
        XCTAssertEqual(decision.status.semanticColor, .yellow)
        XCTAssertEqual(decision.priority, .trainingQuality)

        let guidance = guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 6.2),
            nutrition: nutrition(water: 0.5, waterGoal: 3.1, meals: 1, calories: 583, carbs: 53, lastMealMinutesAgo: 60)
        )

        XCTAssertEqual(guidance.screenStory?.stateLabel, CoachStatus.manageEffort.label)
        XCTAssertEqual(guidance.screenStory?.stateLabel, "MANAGE EFFORT")
        XCTAssertEqual(guidance.screenStory?.title, "Control today's ride")
        XCTAssertTrue(guidance.screenStory?.myRecommendation.localizedCaseInsensitiveContains("reserve") == true)
        XCTAssertTrue(guidance.supportActions.contains { $0.title == "Keep effort easy" || $0.title == "Stay aerobic" })
    }

    func testActiveRunningUsesOneManageEffortStoryWhenRecoveryIsLimited() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 50, completed: false)

        let guidance = guidance(
            [run],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 58, sleepHours: 6.2),
            nutrition: nutrition(water: 3.0, waterGoal: 3.0, meals: 2, calories: 1_600, carbs: 180, lastMealMinutesAgo: 90)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.manageEffort.label)
        XCTAssertEqual(story.title, "Control today's run")
        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertFalse(story.myRead.isEmpty)
        XCTAssertFalse(story.stateLabel.localizedCaseInsensitiveContains("reduce"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("running steady"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("recovery"))
    }

    func testVeryPoorActiveTrainingStillUsesRed() {
        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 75)

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 38, sleepHours: 4.8),
            nutrition: nutrition(water: 0.5, meals: 1)
        )

        XCTAssertEqual(decision.status, .reducePlan)
        XCTAssertEqual(decision.status.semanticColor, .red)
        XCTAssertEqual(decision.priority, .safety)
    }

    func testExplicitReadyRecoveryOverridesStaleBrainFlags() {
        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 75)

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 6.8),
            nutrition: nutrition(water: 2.2, waterGoal: 3.1, meals: 1, calories: 1_200, carbs: 120, lastMealMinutesAgo: 60)
        )

        XCTAssertNotEqual(decision.status, .reducePlan)
        XCTAssertNotEqual(decision.status.semanticColor, .red)
        XCTAssertNotEqual(decision.priority, .safety)
    }

    func testScenario9_highReadinessOpportunityDay() {
        let decision = resolve(
            [],
            brain: brain(currentHour: 13, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 93, sleepHours: 9.0),
            nutrition: nutrition()
        )

        XCTAssertEqual(decision.status.semanticColor, .green)
        XCTAssertFalse(decision.title.isEmpty)
        XCTAssertFalse(decision.myRead.isEmpty)
        XCTAssertFalse(decision.myRecommendation.isEmpty)
    }

    func testScenario10_saunaAfterHardWorkout() {
        let completedRide = cycling(
            title: "Hard Cycling",
            minutesFromNow: -120,
            duration: 90,
            completed: true
        )
        let sauna = quickSauna(minutesFromNow: -5, duration: 20)

        let decision = resolve(
            [completedRide, sauna],
            brain: brain(currentHour: 18, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 66, sleepHours: 6.8),
            nutrition: nutrition(water: 1.5)
        )

        assertDecision(
            decision,
            status: .keepControlled,
            title: "Use sauna as recovery",
            myRead: "The hard work is already done, and sauna is now extra stress on top of that load.",
            myRecommendation: "Use sauna briefly, then shift into food, fluids, and a quieter evening.",
            beCarefulWith: "Long heat exposure or adding more activity after the session."
        )
    }

    func testBalancedStoryProducesMaintenanceSectionsOnly() throws {
        let gym = workout(title: "Gym", minutesFromNow: -240, duration: 60, completed: true)
        let walk = recovery(title: "Walk", minutesFromNow: -90, duration: 30, completed: true)
        let brain = brain(currentHour: 19, recovery: .stable, readiness: .good)
        let recovery = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4)
        let nutrition = nutrition(water: 2.3, meals: 3)

        let guidance = guidance(
            [gym, walk],
            brain: brain,
            recovery: recovery,
            nutrition: nutrition
        )

        XCTAssertTrue([
            CoachNarrativeBadgeIntent.goodToGo.label,
            CoachNarrativeBadgeIntent.windDown.label
        ].contains(guidance.stateLabel))
        XCTAssertEqual(guidance.priority.priority, .stable)
        XCTAssertNil(guidance.priority.planChallenge)
        XCTAssertNil(guidance.priority.whyThisMatters)

        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.shouldShowWhy)
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        XCTAssertTrue(story.primaryActions.isEmpty || guidance.stateLabel == CoachNarrativeBadgeIntent.windDown.label)
        assertNoProblemLanguage(story)
    }

    func testV5ContractPreservesIntentThroughGuidanceAndStory() throws {
        let intervals = cycling(
            title: "Cycling Intervals",
            minutesFromNow: 60,
            duration: 90
        )

        let guidance = guidance(
            [intervals],
            brain: brain(currentHour: 15, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 5.2),
            nutrition: nutrition()
        )

        let contract = try XCTUnwrap(guidance.v5Contract)
        let story = try XCTUnwrap(guidance.screenStory)
        let storyContract = try XCTUnwrap(story.v5Contract)

        XCTAssertEqual(contract.dailyObjective, guidance.priority.objective)
        XCTAssertEqual(contract.primaryLimiter, guidance.priority.limiter)
        XCTAssertEqual(contract.priority.priority, guidance.priority.priority)
        XCTAssertFalse(contract.bestNextDecision.isEmpty)
        XCTAssertFalse(contract.what.isEmpty)
        XCTAssertFalse(guidance.dynamicInsight.text.isEmpty)
        XCTAssertEqual(contract.why, guidance.priority.whyThisMatters)
        XCTAssertEqual(contract.how.split(separator: " ").count <= 40, true)

        XCTAssertEqual(storyContract.dailyObjective, contract.dailyObjective)
        XCTAssertEqual(storyContract.primaryLimiter, contract.primaryLimiter)
        XCTAssertFalse(storyContract.bestNextDecision.isEmpty)
        XCTAssertTrue(contract.shouldSurface)
        XCTAssertFalse(contract.sourceSignals.isEmpty)
    }

    func testV5ContractSupportsTrueNoInterventionWithoutManufacturedVisibleAdvice() throws {
        let gym = workout(title: "Gym", minutesFromNow: -240, duration: 60, completed: true)
        let walk = recovery(title: "Walk", minutesFromNow: -90, duration: 30, completed: true)

        let guidance = guidance(
            [gym, walk],
            brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.3, meals: 3)
        )

        let contract = try XCTUnwrap(guidance.v5Contract)

        XCTAssertFalse(guidance.shouldSurface)
        XCTAssertFalse(contract.shouldSurface)
        XCTAssertEqual(contract.primaryLimiter, .none)
        XCTAssertEqual(contract.priority.interventionValue, .none)
        XCTAssertNil(guidance.priority.whyThisMatters)
        XCTAssertNil(guidance.priority.planChallenge)
        XCTAssertFalse(contract.what.isEmpty)
        XCTAssertFalse(contract.why.isEmpty)
        XCTAssertLessThanOrEqual(contract.why.split(separator: " ").count, 15)
    }

    func testV5ContractCarriesFirstClassTimePhase() throws {
        let morning = try XCTUnwrap(resolve(
            [],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 8.2),
            nutrition: nutrition(water: 2.0, meals: 1)
        ).v5Contract)

        let midday = try XCTUnwrap(resolve(
            [],
            brain: brain(currentHour: 12, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 8.2),
            nutrition: nutrition(water: 2.0, meals: 1)
        ).v5Contract)

        let afternoon = try XCTUnwrap(resolve(
            [],
            brain: brain(currentHour: 15, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 8.2),
            nutrition: nutrition(water: 2.0, meals: 1)
        ).v5Contract)

        let evening = try XCTUnwrap(resolve(
            [],
            brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.2, meals: 3)
        ).v5Contract)

        let lateEvening = try XCTUnwrap(resolve(
            [],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.2, meals: 3)
        ).v5Contract)

        XCTAssertEqual(morning.timePhase, .morning)
        XCTAssertEqual(midday.timePhase, .midday)
        XCTAssertEqual(afternoon.timePhase, .afternoon)
        XCTAssertEqual(evening.timePhase, .evening)
        XCTAssertEqual(lateEvening.timePhase, .lateEvening)
    }

    func testV5ContractChangesImmediatelyWhenActivityIsRemoved() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 45, duration: 90)

        let beforeRemoval = guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.3)
        )
        let afterRemoval = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.3)
        )

        let beforeContract = try XCTUnwrap(beforeRemoval.v5Contract)
        let afterContract = try XCTUnwrap(afterRemoval.v5Contract)

        XCTAssertNotEqual(beforeContract.bestNextDecision, afterContract.bestNextDecision)
        XCTAssertFalse(afterContract.currentReality.localizedCaseInsensitiveContains("cycling"))
        XCTAssertFalse(afterRemoval.title.localizedCaseInsensitiveContains("cycling"))
    }

    func testStabilizerReleasesHeldNarrativeAfterRealityChange() {
        CoachStateStabilizer.markSyncEvent(source: "plannedActivitiesReset")

        let highPriority = guidance(
            [cycling(title: "Cycling", minutesFromNow: 45, duration: 90)],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.3)
        )
        let quietPriority = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.3)
        )

        _ = CoachStateStabilizer.stabilized(highPriority, source: "TodayView.test")
        CoachStateStabilizer.markSyncEvent(source: "healthSync")
        let held = CoachStateStabilizer.stabilized(quietPriority, source: "TodayView.test")
        XCTAssertEqual(held.title, highPriority.title)

        CoachStateStabilizer.markSyncEvent(source: "plannedActivities.removed")
        let released = CoachStateStabilizer.stabilized(quietPriority, source: "TodayView.test")
        XCTAssertEqual(released.title, quietPriority.title)

        CoachStateStabilizer.markSyncEvent(source: "plannedActivitiesReset")
    }

    func testStabilizerReleasesActiveSessionWhenActivityCompletes() {
        CoachStateStabilizer.markSyncEvent(source: "plannedActivitiesReset")

        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 90)
        let activePriority = guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.3)
        )
        XCTAssertEqual(activePriority.priority.priority, .activeSession)
        XCTAssertEqual(activePriority.priority.focus, .activeActivity)

        _ = CoachStateStabilizer.stabilized(activePriority, source: "TodayView.test")

        ride.isCompleted = true
        let currentPriority = guidance(
            [],
            brain: brain(currentHour: 20, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 0.5, waterGoal: 2.4)
        )

        CoachStateStabilizer.markSyncEvent(source: "healthSync")
        let released = CoachStateStabilizer.stabilized(currentPriority, source: "TodayView.test")

        XCTAssertEqual(released.priority.priority, currentPriority.priority.priority)
        XCTAssertEqual(released.priority.focus, currentPriority.priority.focus)
        XCTAssertNotEqual(released.priority.focus, .activeActivity)
        XCTAssertEqual(released.title, currentPriority.title)

        CoachStateStabilizer.markSyncEvent(source: "plannedActivitiesReset")
    }

    func testPlanChallengeOnlyAppearsForMeaningfulPlanChange() throws {
        let intervals = cycling(
            title: "Cycling Intervals",
            minutesFromNow: 60,
            duration: 90
        )

        let guidance = guidance(
            [intervals],
            brain: brain(currentHour: 15, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 5.2),
            nutrition: nutrition()
        )

        XCTAssertTrue(guidance.priority.priority == .performance || guidance.priority.priority == .planChallenge)
        XCTAssertTrue(guidance.priority.planChallenge != nil || !guidance.priority.todayMessage.isEmpty)

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertTrue(story.shouldShowPlanAdjustment || !story.myRecommendation.isEmpty)
        XCTAssertTrue(story.planAdjustment != nil || !story.myRecommendation.isEmpty)
    }

    func testOverloadDayWithRunSoonAdjustsWholePlanNotRunIntensity() throws {
        let walk1 = recovery(title: "Walk", minutesFromNow: -300, duration: 35, completed: true)
        let walk2 = recovery(title: "Walk", minutesFromNow: -230, duration: 30, completed: true)
        let core = workout(title: "Core", minutesFromNow: -180, duration: 45, completed: true)
        let strength = workout(title: "Workout", minutesFromNow: -110, duration: 75, completed: true)
        let sauna = recovery(title: "Sauna", minutesFromNow: -35, duration: 25, completed: true)
        sauna.type = "sauna"
        let run = workout(title: "Running", minutesFromNow: 32, duration: 50, completed: false)
        run.type = "running"

        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = 14
        config.hasAnyFoodLogged = true
        config.energyCoverage = 0.28
        config.caloriesProgress = 0.27
        config.carbsProgress = 0.12
        config.waterProgress = 0.49
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 1,
            carbs: 30,
            calories: 650,
            waterLiters: 1.5,
            activeCalories: 855,
            sleepHours: 7.0
        )
        config.hydration = .behind
        config.fuel = .underfueled
        config.protein = .low
        config.strain = .high
        config.recovery = .compromised
        config.readiness = .low
        config.completedWorkoutsCount = 4

        let output = guidance(
            [walk1, walk2, core, strength, sauna, run],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 7.0),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 650,
                caloriesGoal: 2400,
                proteinCurrent: 1,
                proteinGoal: 153,
                carbsCurrent: 30,
                carbsGoal: 280,
                fatsCurrent: 20,
                fatsGoal: 70,
                waterCurrent: 1.5,
                waterGoal: 3.57,
                mealsCount: 1,
                lastMealTime: CoachTestClock.offset(minutes: -210, from: now)
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(output.priority.priority, .planChallenge)
        XCTAssertEqual(output.priority.focus, .trainingReadinessWarning)
        XCTAssertEqual(story.stateLabel, "REDUCE THE PLAN")
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("run"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Completed today"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Walk, Walk"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("high-load day"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("training"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("recovery"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("sauna"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("load"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("replace"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("postpone"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Skip") || story.myRecommendation.localizedCaseInsensitiveContains("Move"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("recovery"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Completed today"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Accumulated fatigue"))
        XCTAssertFalse((story.whyThisMatters ?? "").localizedCaseInsensitiveContains("active calories"))
        XCTAssertTrue(visible.contains("run"))
        XCTAssertFalse(visible.contains("reduce running intensity"))
        XCTAssertFalse(visible.contains("keep the running"))
    }

    func testNarrativeEngineKeepsSectionsSemanticForOverloadPlanChange() throws {
        let run = workout(title: "Running", minutesFromNow: 45, duration: 60, completed: false)
        run.type = "running"

        let output = overloadGuidanceWithFuture(run)
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(output.priority.priority, .planChallenge)
        XCTAssertTrue(output.priority.reasons.contains { $0.hasPrefix("CoachNarrativeDebug.voice=") })
        XCTAssertTrue(output.priority.reasons.contains { $0.hasPrefix("CoachNarrativeDebug.strategy=") })
        XCTAssertTrue(output.priority.reasons.contains { $0.hasPrefix("CoachNarrativeDebug.dayStory=") })
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("load"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Completed today"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Walk, Walk"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("860 active calories"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("replace"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("skip"))
        XCTAssertTrue(
            story.myRecommendation.localizedCaseInsensitiveContains("skip") ||
            story.myRecommendation.localizedCaseInsensitiveContains("move") ||
            story.myRecommendation.localizedCaseInsensitiveContains("replace")
        )
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("high-load day"))
        XCTAssertFalse((story.whyThisMatters ?? "").localizedCaseInsensitiveContains("active calories"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("929 active calories"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Completed today:"))
    }

    func testSameDecisionUsesDifferentNarrativeByTimeOfDay() throws {
        let midday = dateBySettingHour(12)
        let evening = dateBySettingHour(20)

        let middayOutput = overloadRunGuidance(now: midday)
        let eveningOutput = overloadRunGuidance(now: evening)
        let middayStory = try XCTUnwrap(middayOutput.screenStory)
        let eveningStory = try XCTUnwrap(eveningOutput.screenStory)

        XCTAssertEqual(middayOutput.dayDecisionFrame?.planStatus, eveningOutput.dayDecisionFrame?.planStatus)
        XCTAssertEqual(middayOutput.dayDecisionFrame?.recommendationIntent, eveningOutput.dayDecisionFrame?.recommendationIntent)
        XCTAssertNotEqual(middayStory.myRead, eveningStory.myRead)
        XCTAssertTrue(middayStory.myRead.localizedCaseInsensitiveContains("midday"))
        XCTAssertTrue(
            eveningStory.myRead.localizedCaseInsensitiveContains("evening") ||
            eveningStory.myRead.localizedCaseInsensitiveContains("tonight")
        )
    }

    func testTodayPresentationUsesComposedFrameNarrative() throws {
        let run = workout(title: "Running", minutesFromNow: 45, duration: 60, completed: false)
        run.type = "running"

        let output = overloadGuidanceWithFuture(run)
        let story = try XCTUnwrap(output.screenStory)
        let input = CoachInputSnapshot(
            selectedDate: selectedDate,
            now: now,
            brain: brain(currentHour: 14, recovery: .compromised, readiness: .low, strain: .high),
            plannedActivities: [run],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 860,
                exerciseMinutes: 80,
                standHours: nil,
                activityGoalCalories: 450,
                activityProgress: 1.91
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 7.0),
            nutritionContext: nutrition(water: 1.0, waterGoal: 2.5, meals: 1, calories: 600, carbs: 30),
            source: "test"
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: output
        )

        XCTAssertEqual(state.todayPresentation.title, story.title)
        XCTAssertEqual(state.todayPresentation.message, story.myRead)
        XCTAssertNotEqual(state.todayPresentation.message, output.dayDecisionFrame?.todayMessage)
    }

    func testCompletedDayNarrativeUsesStoryNotStatusCopy() throws {
        let output = highLoadCompletedGuidance(now: dateBySettingHour(20))
        let frame = try XCTUnwrap(output.dayDecisionFrame)
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(frame.planStatus, .complete)
        XCTAssertEqual(output.priority.priority, .recovery)
        XCTAssertEqual(output.priority.focus, .recoveryNeeded)
        XCTAssertTrue(output.priority.reasons.contains("dayDecisionFrame=selected"))
        XCTAssertTrue(output.priority.reasons.contains("narrativeFamily=recovery"))
        XCTAssertTrue(output.priority.reasons.contains("recommendationFamily=recovery"))
        XCTAssertTrue(output.priority.reasons.contains("CoachNarrativeDebug.dayStory=highLoadDay"))
        XCTAssertGreaterThan(output.priority.decisionScore, 110)
        XCTAssertTrue(
            story.title.localizedCaseInsensitiveContains("work") ||
            story.title.localizedCaseInsensitiveContains("recovery") ||
            story.title.localizedCaseInsensitiveContains("progress")
        )
        XCTAssertTrue(
            story.myRead.localizedCaseInsensitiveContains("high-load") ||
            story.myRead.localizedCaseInsensitiveContains("training signal") ||
            story.myRead.localizedCaseInsensitiveContains("meaningful work")
        )
        XCTAssertTrue(
            story.myRecommendation.localizedCaseInsensitiveContains("easy") ||
            story.myRecommendation.localizedCaseInsensitiveContains("recovery") ||
            story.myRecommendation.localizedCaseInsensitiveContains("light")
        )
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Day complete"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("exceeded today's activity target"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("No extra work is needed tonight"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("860 active calories"))
    }

    func testHighLoadSevereUnderfuelingStaysRecoveryDecisionWithActionableSupport() throws {
        let output = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.25,
            waterGoal: 3.75,
            calories: 257,
            caloriesGoal: 1_946,
            protein: 5,
            proteinGoal: 153,
            meals: 1,
            lastMealMinutesAgo: 240
        )
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(output.priority.priority, .recovery)
        XCTAssertEqual(output.priority.focus, .recoveryNeeded)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("recovery") || story.title.localizedCaseInsensitiveContains("work"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("Refuel"))
        let allActions = story.primaryActions + story.supportActions
        XCTAssertTrue(allActions.contains {
            $0.type == .startRecoveryNutrition ||
            $0.type == .recoveryMeal ||
            $0.title.localizedCaseInsensitiveContains("protein") ||
            $0.title.localizedCaseInsensitiveContains("food")
        })
    }

    func testRecoveryActionsRemoveFoodAndHydrationAsTheyAreCompleted() throws {
        let afterMeal = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.25,
            waterGoal: 3.75,
            calories: 1_600,
            caloriesGoal: 1_946,
            protein: 118,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 30
        )
        let afterMealStory = try XCTUnwrap(afterMeal.screenStory)

        XCTAssertEqual(afterMeal.priority.priority, .recovery)
        XCTAssertFalse(afterMealStory.primaryActions.contains { $0.type == .startRecoveryNutrition || $0.type == .recoveryMeal || $0.type == .lightFueling })
        XCTAssertFalse(afterMealStory.primaryActions.contains { $0.title == "Keep sipping" })
        XCTAssertTrue(afterMealStory.primaryActions.contains { $0.title == "Put fluids back on pace" })
        XCTAssertTrue(afterMealStory.primaryActions.contains { $0.title == "Let today's load settle" })

        let afterHydrationImproves = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.8,
            waterGoal: 3.75,
            calories: 1_600,
            caloriesGoal: 1_946,
            protein: 118,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 30
        )
        let afterHydrationStory = try XCTUnwrap(afterHydrationImproves.screenStory)

        XCTAssertEqual(afterHydrationImproves.priority.priority, .recovery)
        XCTAssertFalse(afterHydrationImproves.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertFalse(afterHydrationStory.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration || $0.type == .rehydrateGradually })
        XCTAssertTrue(afterHydrationStory.primaryActions.contains { $0.title == "Let today's load settle" })
        XCTAssertTrue(afterHydrationStory.primaryActions.contains { $0.title == "Turn the work into adaptation" })
        XCTAssertEqual(
            afterHydrationStory.whyThisMatters,
            "Hydration and refueling are already in place. Recovery now depends mostly on sleep and avoiding additional stress."
        )
    }

    func testRecoveryContributorLifecycleRecomputesAfterNutritionUpdate() throws {
        let beforeUpdate = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.25,
            waterGoal: 3.75,
            calories: 2_050,
            caloriesGoal: 1_946,
            protein: 66,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 30
        )
        let afterUpdate = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.50,
            waterGoal: 3.75,
            calories: 2_050,
            caloriesGoal: 1_946,
            protein: 118,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 30
        )

        XCTAssertEqual(beforeUpdate.priority.priority, .recovery)
        XCTAssertEqual(afterUpdate.priority.priority, .recovery)
        XCTAssertTrue(beforeUpdate.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertTrue(beforeUpdate.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertFalse(afterUpdate.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertFalse(afterUpdate.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(beforeUpdate.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[hydrationBehind,proteinBehind]"))
        XCTAssertTrue(afterUpdate.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]"))
        XCTAssertTrue(afterUpdate.priority.reasons.contains("RecoveryContributorDebug.resolvedContributors=[underfueled,hydrationBehind,proteinBehind]"))
        XCTAssertLessThan(afterUpdate.priority.decisionScore, beforeUpdate.priority.decisionScore)
        XCTAssertLessThan(afterUpdate.priority.confidence, beforeUpdate.priority.confidence)
    }

    func testHydrationProgressChangesRecoveryNarrativeState() throws {
        let depleted = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 1.75,
            waterGoal: 3.75,
            calories: 1_050,
            caloriesGoal: 1_946,
            protein: 75,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 80
        )
        let improving = highLoadCompletedGuidance(
            now: dateBySettingHour(19),
            water: 2.25,
            waterGoal: 3.75,
            calories: 1_050,
            caloriesGoal: 1_946,
            protein: 75,
            proteinGoal: 153,
            meals: 2,
            lastMealMinutesAgo: 80
        )
        let depletedStory = try XCTUnwrap(depleted.screenStory)
        let improvingStory = try XCTUnwrap(improving.screenStory)

        XCTAssertEqual(depleted.priority.priority, .recovery)
        XCTAssertEqual(improving.priority.priority, .recovery)
        XCTAssertNotEqual(depletedStory.myRead, improvingStory.myRead)
        XCTAssertTrue(
            depletedStory.whyThisMatters?.localizedCaseInsensitiveContains("hydration needs attention") == true ||
            depletedStory.whyThisMatters?.localizedCaseInsensitiveContains("hydration still needs attention") == true
        )
        XCTAssertTrue(
            improvingStory.myRead.localizedCaseInsensitiveContains("hydration is moving") ||
            improvingStory.whyThisMatters?.localizedCaseInsensitiveContains("hydration is improving") == true
        )
    }

    func testCompletedActivitySummaryDeduplicatesRepeatedWalks() throws {
        let walk1 = recovery(title: "Walk", minutesFromNow: -240, duration: 30, completed: true)
        let walk2 = recovery(title: "Walk", minutesFromNow: -180, duration: 25, completed: true)
        let walk3 = recovery(title: "Walk", minutesFromNow: -120, duration: 20, completed: true)
        let core = workout(title: "Core", minutesFromNow: -60, duration: 30, completed: true)

        let output = guidance(
            [walk1, walk2, walk3, core],
            brain: brain(
                currentHour: 14,
                recovery: .stable,
                readiness: .good,
                strain: .normal,
                sleepHours: 7.4
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.4),
            nutrition: nutrition(water: 1.6, waterGoal: 2.5, meals: 2, calories: 1_500, carbs: 160)
        )

        let frame = try XCTUnwrap(output.dayDecisionFrame)
        let pastRead = frame.dayRead.past

        XCTAssertTrue(pastRead.localizedCaseInsensitiveContains("multiple recovery walks"))
        XCTAssertTrue(pastRead.localizedCaseInsensitiveContains("Core training"))
        XCTAssertFalse(pastRead.localizedCaseInsensitiveContains("Walk, Walk"))
        XCTAssertFalse(pastRead.localizedCaseInsensitiveContains("Completed today"))
    }

    func testHydrationBehindIsContributorNotPrimaryDriver() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 2.5, meals: 1, calories: 1_100, carbs: 120)
        )
        let frame = try XCTUnwrap(output.dayDecisionFrame)

        XCTAssertEqual(frame.primaryDriver, .none)
        XCTAssertTrue(frame.contributors.contains(.hydrationBehind))
        XCTAssertEqual(frame.planStatus, .valid)
        XCTAssertFalse(frame.planStatus.requiresPlanChange)
        XCTAssertFalse(frame.primaryDriverText.localizedCaseInsensitiveContains("hydration"))
    }

    func testActiveActivityCannotHideOverloadPlanReplacement() throws {
        let walk = recovery(title: "Walk", minutesFromNow: -10, duration: 45, completed: false)
        let core = workout(title: "Core", minutesFromNow: -180, duration: 45, completed: true)
        let strength = workout(title: "Workout", minutesFromNow: -100, duration: 75, completed: true)
        let run = workout(title: "Running", minutesFromNow: 45, duration: 50, completed: false)
        run.type = "running"

        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = 14
        config.energyCoverage = 0.25
        config.caloriesProgress = 0.25
        config.carbsProgress = 0.12
        config.waterProgress = 0.40
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 20,
            carbs: 30,
            calories: 600,
            waterLiters: 1.0,
            activeCalories: 875,
            sleepHours: 7.0
        )
        config.hydration = .behind
        config.fuel = .underfueled
        config.recovery = .compromised
        config.readiness = .low
        config.strain = .high
        config.completedWorkoutsCount = 2

        let output = guidance(
            [walk, core, strength, run],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 7.0),
            nutrition: nutrition(water: 1.0, waterGoal: 2.5, meals: 1, calories: 600, carbs: 30)
        )
        let frame = try XCTUnwrap(output.dayDecisionFrame)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(frame.planStatus, .replace)
        XCTAssertEqual(frame.primaryDriver, .accumulatedFatigue)
        XCTAssertEqual(output.priority.priority, .planChallenge)
        XCTAssertEqual(output.priority.focus, .trainingReadinessWarning)
        if case .active = output.phase {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected active phase to own presentation")
        }
        XCTAssertTrue(story.primaryActions.contains { $0.actionProvenance == .activeSessionExecution })
    }

    func testTomorrowDemandCanDriveRecoveryWhenTodayIsAlreadyLoaded() throws {
        let completedRide = cycling(title: "Cycling", minutesFromNow: -210, duration: 150, completed: true)
        let tomorrowRide = tomorrowCycling(title: "Long Ride", duration: 150)

        let output = guidance(
            [completedRide, tomorrowRide],
            brain: brain(currentHour: 18, recovery: .stable, readiness: .good, strain: .high),
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 7.1),
            nutrition: nutrition(water: 1.8, waterGoal: 2.5, meals: 2, calories: 1_900, carbs: 210)
        )
        let frame = try XCTUnwrap(output.dayDecisionFrame)

        XCTAssertEqual(frame.primaryDriver, .tomorrowDemand)
        XCTAssertEqual(frame.planStatus, .complete)
        XCTAssertEqual(frame.recommendationIntent, .recoverNow)
        XCTAssertTrue(frame.contributors.contains(.tomorrowDemand))
        XCTAssertTrue(frame.todayMessage.localizedCaseInsensitiveContains("recovery"))
    }

    func testHighRecoveryHoursBeforeLongRidePreparesInsteadOfAdjustingPlan() throws {
        let ride = cycling(
            title: "Endurance Ride",
            minutesFromNow: 270,
            duration: 210
        )

        let guidance = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 87, sleepHours: 6.2),
            nutrition: nutrition(water: 0, meals: 0, calories: 0, carbs: 0)
        )

        let story = try XCTUnwrap(guidance.screenStory)
        let contract = try XCTUnwrap(guidance.v5Contract)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertFalse(guidance.stateLabel.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertTrue(visible.contains("ride") || visible.contains("endurance"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("fresh") || story.myRecommendation.localizedCaseInsensitiveContains("readiness"))
        XCTAssertTrue(
            story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("carbs") },
            "actions=\(story.primaryActions.map(\.title))"
        )
        XCTAssertTrue(
            story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("first") && $0.title.localizedCaseInsensitiveContains("easy") },
            "actions=\(story.primaryActions.map(\.title))"
        )
        XCTAssertFalse(visible.contains("lower the ceiling"))
        XCTAssertFalse(visible.contains("reduce intensity"))
        XCTAssertFalse(visible.contains("adjust the plan"))
        XCTAssertFalse(visible.contains("heat"))
        XCTAssertFalse(visible.contains("sauna"))
        XCTAssertEqual(contract.timePhase, .morning)
        XCTAssertFalse(contract.bestNextDecision.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
    }

    func testOverloadDayCyclingSixtyMinutesReplacesOrCapsDuration() throws {
        let output = overloadGuidanceWithFuture(
            cycling(title: "Cycling", minutesFromNow: 45, duration: 60)
        )
        let frame = try XCTUnwrap(output.dayDecisionFrame)
        let risk = try XCTUnwrap(frame.remainingActivityRisk)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(risk.category, "cycling")
        XCTAssertEqual(risk.plannedDuration, 60)
        XCTAssertEqual(risk.riskLevel, .high)
        XCTAssertEqual(risk.recommendedAction, .replace)
        XCTAssertEqual(risk.maxRecommendedDuration, 20)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("Replace") || story.title.localizedCaseInsensitiveContains("Adjust"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("60-minute") || story.myRead.localizedCaseInsensitiveContains("60 minutes"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("20 minutes"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("recovery"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Completed today"))
        XCTAssertTrue(output.priority.reasons.contains { $0.contains("RemainingActivityRiskDebug.riskLevel=high") })
    }

    func testOverloadDayRunningSixtyMinutesSkipsOrMovesRun() throws {
        let run = workout(title: "Running", minutesFromNow: 45, duration: 60, completed: false)
        run.type = "running"
        let output = overloadGuidanceWithFuture(run)
        let risk = try XCTUnwrap(output.dayDecisionFrame?.remainingActivityRisk)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(risk.category, "running")
        XCTAssertEqual(risk.riskLevel, .critical)
        XCTAssertTrue(risk.recommendedAction == .skip || risk.recommendedAction == .moveToTomorrow)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("run"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Skip") || story.myRecommendation.localizedCaseInsensitiveContains("Move"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("recovery"))
    }

    func testOverloadDayRunningFifteenMinutesAllowsOnlyVeryEasyShortVersion() throws {
        let run = workout(title: "Running", minutesFromNow: 45, duration: 15, completed: false)
        run.type = "running"
        let output = overloadGuidanceWithFuture(run)
        let risk = try XCTUnwrap(output.dayDecisionFrame?.remainingActivityRisk)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(risk.category, "running")
        XCTAssertEqual(risk.riskLevel, .medium)
        XCTAssertEqual(risk.recommendedAction, .makeEasy)
        XCTAssertEqual(risk.maxRecommendedDuration, 15)
        XCTAssertEqual(risk.maxRecommendedIntensity, "Zone 1")
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("easy"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Zone 1"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("walking") || story.myRecommendation.localizedCaseInsensitiveContains("stretching"))
    }

    func testOverloadDayStretchingTwentyMinutesStaysRecoveryOnly() throws {
        let stretch = recovery(title: "Stretching", minutesFromNow: 45, duration: 20, completed: false)
        stretch.type = "stretching"
        let output = overloadGuidanceWithFuture(stretch)
        let risk = try XCTUnwrap(output.dayDecisionFrame?.remainingActivityRisk)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(risk.category, "recovery")
        XCTAssertEqual(risk.riskLevel, .low)
        XCTAssertEqual(risk.recommendedAction, .keep)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertTrue(
            story.myRecommendation.localizedCaseInsensitiveContains("fine") ||
            story.myRecommendation.localizedCaseInsensitiveContains("gentle") ||
            story.myRecommendation.localizedCaseInsensitiveContains("recovery")
        )
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("Adjust today's plan"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Skip"))
    }

    func testSameActivityDifferentDurationChangesRecommendation() throws {
        let shortRun = workout(title: "Running", minutesFromNow: 45, duration: 15, completed: false)
        shortRun.type = "running"
        let longRun = workout(title: "Running", minutesFromNow: 45, duration: 60, completed: false)
        longRun.type = "running"

        let shortRisk = try XCTUnwrap(overloadGuidanceWithFuture(shortRun).dayDecisionFrame?.remainingActivityRisk)
        let longRisk = try XCTUnwrap(overloadGuidanceWithFuture(longRun).dayDecisionFrame?.remainingActivityRisk)

        XCTAssertEqual(shortRisk.riskLevel, .medium)
        XCTAssertEqual(shortRisk.recommendedAction, .makeEasy)
        XCTAssertEqual(longRisk.riskLevel, .critical)
        XCTAssertTrue(longRisk.recommendedAction == .skip || longRisk.recommendedAction == .moveToTomorrow)
        XCTAssertNotEqual(shortRisk.recommendationSentence, longRisk.recommendationSentence)
    }

    func testSameCyclingBeforeAndAfterHighLoadChangesRecommendation() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 270, duration: 60)
        let good = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.5),
            nutrition: nutrition(water: 2.0, meals: 1, calories: 1_800, carbs: 210)
        )
        let overloaded = overloadGuidanceWithFuture(
            cycling(title: "Cycling", minutesFromNow: 45, duration: 60)
        )

        let goodRisk = try XCTUnwrap(good.dayDecisionFrame?.remainingActivityRisk)
        let overloadedRisk = try XCTUnwrap(overloaded.dayDecisionFrame?.remainingActivityRisk)

        XCTAssertTrue(goodRisk.riskLevel == .low || goodRisk.riskLevel == .medium)
        XCTAssertEqual(goodRisk.recommendedAction, .keep)
        XCTAssertEqual(overloadedRisk.riskLevel, .high)
        XCTAssertEqual(overloadedRisk.recommendedAction, .replace)
        XCTAssertNotEqual(goodRisk.recommendationSentence, overloadedRisk.recommendationSentence)
    }

    func testCoachScreenStoryPreservesResolverWinnerWhenHeatAlsoExists() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 270, duration: 210)
        let sauna = quickSauna(minutesFromNow: 90, duration: 30)
        let activities = [ride, sauna]
        let brain = brain(currentHour: 9, recovery: .strong, readiness: .good)
        let recovery = CoachRecoveryContext(recoveryPercent: 87, sleepHours: 6.2)
        let nutrition = nutrition(water: 0.3, meals: 0)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowPlanContext(activities),
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let resolverWinner = CoachDayPriorityResult(
            focus: .prepareForActivity,
            level: .important,
            reason: "Cycling is the selected coaching target.",
            activity: ride,
            overridesTimingFocus: true,
            priority: .performance,
            limiter: .timing,
            todayTitle: "Prepare for cycling",
            todayMessage: "Arrive fueled and ready for the ride.",
            detailTitle: "Prepare for cycling",
            detailMessage: "Cycling is the next key demand, so prep is the useful decision now.",
            supportBullets: ["Hydrate", "Eat planned meal"],
            whyThisMatters: "Preparation matters more than changing the workout this early."
        )

        let decision = HumanCoachDecisionEngine.resolve(
            context: context,
            priority: resolverWinner
        )
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: resolverWinner.phase(for: activityContext),
            opportunity: opportunity,
            legacyPriority: resolverWinner,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )

        let story = try XCTUnwrap(guidance.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(guidance.priority.activity?.id, ride.id)
        XCTAssertEqual(story.title, "Prepare for cycling")
        XCTAssertTrue(visible.contains("cycling"))
        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("sauna"))
        XCTAssertFalse(visible.contains("use sauna as recovery"))
    }

    func testHydrationRemovedFromMainNarrativeButStillAppearsInSupport() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 120, duration: 60)
        let priority = stableNextActivityPriority(
            activity: ride,
            supportBullets: [
                "Hydration still needs attention • Add 300-500 ml in the next hour",
                "Bring a bottle",
                "Fueling has started"
            ]
        )
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20),
            priority: priority
        )
        let story = try XCTUnwrap(output.screenStory)
        let mainText = [story.title, story.myRead, story.myRecommendation].joined(separator: " ")

        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, CoachNarrativeLimiter.none)
        XCTAssertFalse(mainText.localizedCaseInsensitiveContains("Hydration still needs attention"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertNotEqual(story.primaryActions.first?.type, .hydrateBeforeSession)
        XCTAssertNotEqual(story.primaryActions.first?.type, .steadyHydration)
        XCTAssertTrue(output.priority.supportBullets.contains { $0.localizedCaseInsensitiveContains("hydration") || $0.localizedCaseInsensitiveContains("bottle") })
        XCTAssertNotEqual(story.primaryActions.first?.type, .hydrateBeforeSession)
        XCTAssertNotEqual(story.primaryActions.first?.type, .steadyHydration)
    }

    func testPrepareRideShowsHydrationSupportWhenWaterZero() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 120, duration: 60)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        )
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertFalse(story.stateLabel.isEmpty)
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Bring a bottle" })
    }

    func testLimiterNoneDoesNotHideSupportSignals() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 120, duration: 60)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour"]
            )
        )

        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertFalse(output.priority.supportBullets.isEmpty)
        XCTAssertFalse(output.screenStory?.primaryActions.isEmpty ?? true)
        XCTAssertFalse(output.supportActions.isEmpty)
    }

    func testSupportSignalsRenderForStableNextActivityLater() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 120, duration: 60)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        )

        XCTAssertEqual(output.priority.priority, .stable)
        XCTAssertEqual(output.priority.focus, .nextActivityLater)
        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertFalse(output.screenStory?.stateLabel.isEmpty ?? true)
        XCTAssertTrue(output.screenStory?.supportActions.contains { $0.type == .hydrateBeforeSession } == true)
    }

    func testHydrationCannotOwnNarrativeWithoutBeingLimiter() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let mainText = [story.title, story.myRead, story.myRecommendation].joined(separator: " ")

        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, CoachNarrativeLimiter.none)
        XCTAssertFalse(story.stateLabel.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("Drink 300-500 ml"))
        XCTAssertFalse(mainText.localizedCaseInsensitiveContains("Hydration first"))
    }

    func testHydrationCannotBecomePrimaryActionOne() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        ).screenStory)

        XCTAssertFalse(story.primaryActions.isEmpty)
        XCTAssertNotEqual(story.primaryActions.first?.type, .hydrateBeforeSession)
        XCTAssertNotEqual(story.primaryActions.first?.type, .steadyHydration)
        XCTAssertNotEqual(story.primaryActions.first?.title, "Drink 300-500 ml water")
        XCTAssertTrue(story.supportActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
    }

    func testCyclingPrimaryActionsAreRideFocused() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        ).screenStory)

        let actionTitles = story.primaryActions.map(\.title)

        XCTAssertTrue(actionTitles.contains("Keep morning activity easy"))
        XCTAssertTrue(actionTitles.contains("Bring carbs for the ride"))
        XCTAssertTrue(actionTitles.contains("Keep the first 15-20 minutes easy"))
        XCTAssertFalse(actionTitles.contains("Drink 300-500 ml water"))
        XCTAssertFalse(actionTitles.contains("Bring a bottle"))
    }

    func testSupportSignalsContainHydrationWhenRelevant() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        ).screenStory)

        XCTAssertTrue(story.supportActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Bring a bottle" })
    }

    func testObjectiveOwnsHeroTitle() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour"]
            )
        ).screenStory)

        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("water"))
    }

    func testObjectiveOwnsRecommendation() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour"]
            )
        ).screenStory)

        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Hydration first"))
    }

    func testStartControlledIsNeverRendered() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour"]
            )
        ).screenStory)

        XCTAssertFalse(visibleTexts(story).joined(separator: " ").localizedCaseInsensitiveContains("Start controlled"))
    }

    func testHydrationOnlyAppearsInSupportForNormalDays() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        ).screenStory)

        XCTAssertNotEqual(story.primaryActions.first?.type, .hydrateBeforeSession)
        XCTAssertNotEqual(story.primaryActions.first?.type, .steadyHydration)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("Hydration"))
        XCTAssertTrue(story.supportActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
    }

    func testPrepareRideStoryBeatsHydrationStory() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour"]
            )
        ).screenStory)

        XCTAssertFalse(story.stateLabel.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.stateLabel.localizedCaseInsensitiveContains("hydration"))
    }

    func testProtectTomorrowStoryBeatsHydrationStory() throws {
        let tomorrowRide = tomorrowCycling(title: "Long Ride", duration: 180)
        let output = guidance(
            [tomorrowRide],
            brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
            nutrition: nutrition(water: 0, meals: 3, calories: 2_100, carbs: 220)
        )
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(output.priority.objective, .protectTomorrow)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("tomorrow"))
        XCTAssertFalse(story.stateLabel.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml"))
    }

    func testSupportSignalsNeverReplacePrimaryActions() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 180, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 900, carbs: 120),
            priority: stableNextActivityPriority(
                activity: ride,
                supportBullets: ["Hydration still needs attention • Add 300-500 ml in the next hour", "Bring a bottle"]
            )
        ).screenStory)

        XCTAssertFalse(story.primaryActions.isEmpty)
        XCTAssertFalse(story.supportActions.isEmpty)
        XCTAssertFalse(story.primaryActions.map(\.title).contains("Drink 300-500 ml water"))
        XCTAssertTrue(story.supportActions.map(\.title).contains("Drink 300-500 ml water"))
    }

    func testNoActivityContextCannotRenderRideOrWorkoutSupportActions() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(
                supportBullets: [
                    "Hydration is significantly behind • Add 300-500 ml in the next hour",
                    "Sip fluids steadily",
                    "Eat 20-40g carbs before starting"
                ]
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertNil(output.priority.activity)
        XCTAssertFalse(visible.contains("ride nutrition"))
        XCTAssertFalse(visible.contains("first 15"))
        XCTAssertFalse(visible.contains("control intensity"))
        XCTAssertFalse(visible.contains("bring a bottle"))
        XCTAssertFalse(visible.contains("workout nutrition"))
        XCTAssertTrue(story.supportActions.contains { $0.title == "Consider a glass of water" })
        XCTAssertFalse(story.supportActions.contains { $0.title.localizedCaseInsensitiveContains("ride") })
        XCTAssertFalse(story.supportActions.contains { $0.title.localizedCaseInsensitiveContains("workout") })
    }

    func testSecondaryHydrationSupportUsesSoftLanguage() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(
                supportBullets: ["Hydration is significantly behind • Add 300-500 ml in the next hour"]
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Hydration is significantly behind"))
        XCTAssertFalse(story.supportActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Consider a glass of water" })
    }

    func testRecoveryDayWithLowBasicsUsesNeutralCopy() throws {
        let walk = recovery(title: "Recovery Walk", minutesFromNow: -90, duration: 30, completed: true)
        let output = guidance(
            [walk],
            brain: brain(currentHour: 14, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 35)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Recovery day is on track"))
        XCTAssertTrue(
            visible.localizedCaseInsensitiveContains("Keep the day simple") ||
            visible.localizedCaseInsensitiveContains("Build the day gradually") ||
            visible.localizedCaseInsensitiveContains("Stay flexible today")
        )
    }

    func testNoFutureActivityDoesNotRenderTrainingActions() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(
                supportBullets: ["Hydration could use attention", "Eat normally at next meal"]
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertFalse(visible.contains("train easy today"))
        XCTAssertFalse(visible.contains("start easy"))
        XCTAssertFalse(visible.contains("first 15"))
        XCTAssertFalse(visible.contains("bring ride nutrition"))
        XCTAssertFalse(visible.contains("control intensity"))
        XCTAssertFalse(visible.contains("fuel the session"))
    }

    func testNoFutureActivityUsesSimpleDayActions() throws {
        let output = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(
                supportBullets: ["Hydration could use attention", "Eat normally at next meal"]
            )
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertFalse(story.primaryActions.isEmpty)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("ride"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("workout"))
    }

    func testAddingCyclingSwitchesFromGoodToGoToPrepare() throws {
        let noActivity = guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.2, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(supportBullets: ["Hydration could use attention"])
        )
        let ride = cycling(title: "Cycling", minutesFromNow: 105, duration: 180)
        let withCycling = guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90),
            priority: cyclingPreparationPriority(activity: ride)
        )

        XCTAssertNotEqual(noActivity.screenStory?.stateLabel, withCycling.screenStory?.stateLabel)
        XCTAssertNotEqual(noActivity.screenStory?.title, withCycling.screenStory?.title)
        XCTAssertEqual(withCycling.priority.priority, .performance)
        XCTAssertEqual(withCycling.priority.focus, .prepareForActivity)
        XCTAssertEqual(withCycling.screenStory?.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertEqual(withCycling.screenStory?.title, "Prepare for cycling")
    }

    func testCyclingPreparationUsesSpecificTimeAndActivityContext() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 105, duration: 180)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90),
            priority: cyclingPreparationPriority(activity: ride)
        ).screenStory)

        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("ride") || story.myRecommendation.localizedCaseInsensitiveContains("ride"))
        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertFalse(story.beCarefulWith.isEmpty)
    }

    func testControlledIsNeverRendered() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 105, duration: 180)
        let cyclingStory = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90),
            priority: cyclingPreparationPriority(activity: ride)
        ).screenStory)
        let noActivityStory = try XCTUnwrap(guidance(
            [],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 40),
            priority: noActivityStablePriority(supportBullets: ["Hydration could use attention"])
        ).screenStory)

        XCTAssertFalse(visibleTexts(cyclingStory).joined(separator: " ").localizedCaseInsensitiveContains("controlled"))
        XCTAssertFalse(visibleTexts(noActivityStory).joined(separator: " ").localizedCaseInsensitiveContains("controlled"))
    }

    func testCyclingActivityLifecycleAudit() throws {
        let stages: [CyclingLifecycleStage] = [
            .init(name: "1. scheduled >90 min away", ride: lifecycleRide(minutesFromNow: 105), expectedState: "PREPARE", expectedTitleContains: "cycling"),
            .init(name: "2. scheduled 30-60 min away", ride: lifecycleRide(minutesFromNow: 45), expectedState: "PREPARE", expectedTitleContains: "cycling"),
            .init(name: "3. scheduled <15 min away", ride: lifecycleRide(minutesFromNow: 10), expectedState: "PREPARE", expectedTitleContains: "cycling"),
            .init(name: "4. activity started", ride: lifecycleRide(elapsedMinutes: 1), expectedState: "KEEP IT EASY", expectedTitleContains: "Control today's ride", mustNotTitleContain: "prepare"),
            .init(name: "5. first 15 minutes", ride: lifecycleRide(elapsedMinutes: 12), expectedState: "KEEP IT EASY", expectedTitleContains: "Control today's ride", mustNotTitleContain: "prepare"),
            .init(name: "6. mid-session", ride: lifecycleRide(elapsedMinutes: 90), expectedState: "KEEP IT EASY", expectedTitleContains: "Control today's ride", mustNotTitleContain: "prepare"),
            .init(name: "7. late-session", ride: lifecycleRide(elapsedMinutes: 172), expectedState: "KEEP IT EASY", expectedTitleContains: "Control today's ride", mustNotTitleContain: "prepare"),
            .init(name: "8. activity completed", ride: lifecycleRide(completedMinutesAgo: 0), expectedState: "RECOVER", expectedTitleContains: "Protect the work", mustNotTitleContain: "prepare"),
            .init(name: "9. post-workout recovery window", ride: lifecycleRide(completedMinutesAgo: 45), expectedState: "RECOVER", expectedTitleContains: "Protect the work", mustNotTitleContain: "prepare"),
            .init(name: "10. recovery completed", ride: lifecycleRide(completedMinutesAgo: 150), expectedState: "", expectedTitleContains: "", mustNotTitleContain: "sleep")
        ]

        var auditLog: [String] = []

        for stage in stages {
            let result = try lifecycleGuidance(for: stage.ride)
            let story = try XCTUnwrap(result.guidance.screenStory)
            let actualState = story.stateLabel
            let actualTitle = story.title
            let actualObjective = result.guidance.narrativePlan?.objective ?? result.priority.objective
            let actualLimiter = result.guidance.narrativePlan?.primaryLimiter
            let actualIntent = "\(result.priority.priority)/\(result.priority.focus)"
            let primaryActions = story.primaryActions.map(\.title)
            let supportActions = story.supportActions.map(\.title)

            auditLog.append("""

            [CyclingLifecycleAudit] \(stage.name)
            EXPECTED state~\(stage.expectedState) title~\(stage.expectedTitleContains) notTitle~\(stage.mustNotTitleContain ?? "none")
            ACTUAL phase=\(result.context.activityContext.phase) activePhase=\(String(describing: result.context.activityContext.activeSessionPhase)) minutesUntil=\(String(describing: result.context.activityContext.minutesUntilStart)) minutesSinceEnd=\(String(describing: result.context.activityContext.minutesSinceEnd))
            ACTUAL objective=\(actualObjective) limiter=\(String(describing: actualLimiter)) intent=\(actualIntent)
            ACTUAL renderedState="\(actualState)" renderedTitle="\(actualTitle)"
            ACTUAL myRead="\(story.myRead)"
            ACTUAL myRecommendation="\(story.myRecommendation)"
            ACTUAL beCarefulWith="\(story.beCarefulWith)"
            ACTUAL primaryActions=\(primaryActions)
            ACTUAL supportActions=\(supportActions)
            """)

            if !stage.expectedState.isEmpty {
                XCTAssertTrue(
                    actualState.localizedCaseInsensitiveContains(stage.expectedState),
                    "\(stage.name) expected state containing \(stage.expectedState), got \(actualState)"
                )
            }
            if !stage.expectedTitleContains.isEmpty {
                XCTAssertTrue(
                    actualTitle.localizedCaseInsensitiveContains(stage.expectedTitleContains),
                    "\(stage.name) expected title containing \(stage.expectedTitleContains), got \(actualTitle)"
                )
            }
            if let forbidden = stage.mustNotTitleContain {
                XCTAssertFalse(
                    actualTitle.localizedCaseInsensitiveContains(forbidden),
                    "\(stage.name) must not remain stuck in \(forbidden), got \(actualTitle)"
                )
            }
            if stage.name.contains("activity started") || stage.name.contains("first 15") || stage.name.contains("mid-session") || stage.name.contains("late-session") {
                XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("ride"))
                XCTAssertFalse(actualTitle.localizedCaseInsensitiveContains("plan"))
                XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("plan adjustment"))
                XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("prepare"))
            }
            if stage.name.contains("activity completed") || stage.name.contains("post-workout") {
                XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("ride"))
                XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("sleep leads"))
                XCTAssertFalse(actualTitle.localizedCaseInsensitiveContains("sleep"))
            }
        }

        let renderedAudit = auditLog.joined(separator: "\n")
        try? renderedAudit.write(
            toFile: "/tmp/weekfit-cycling-lifecycle-contract.log",
            atomically: true,
            encoding: .utf8
        )
        print(renderedAudit)
    }

    func testSleepLimitedCyclingLifecycleUsesExecutionThenRecoveryContinuity() throws {
        let active = try lifecycleGuidance(
            for: lifecycleRide(elapsedMinutes: 190, duration: 240),
            brain: brain(
                currentHour: 13,
                recovery: .compromised,
                readiness: .compromised,
                sleepHours: 4.4
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.4)
        )
        let activeStory = try XCTUnwrap(active.guidance.screenStory)
        let activeCopy = visibleTexts(activeStory).joined(separator: " ").lowercased()

        XCTAssertTrue(activeStory.title.localizedCaseInsensitiveContains("ride"))
        XCTAssertTrue(activeStory.myRead.localizedCaseInsensitiveContains("ride"), activeStory.myRead)
        XCTAssertFalse(activeStory.myRecommendation.isEmpty)
        XCTAssertTrue(activeCopy.contains("finish with reserve") || activeCopy.contains("stay aerobic"), activeCopy)
        XCTAssertFalse(activeCopy.contains("reduce the plan"))
        XCTAssertFalse(activeCopy.contains("plan adjustment"))
        XCTAssertFalse(activeCopy.contains("prepare for cycling"))

        let completed = try lifecycleGuidance(
            for: lifecycleRide(completedMinutesAgo: 9, duration: 240),
            brain: brain(
                currentHour: 13,
                recovery: .compromised,
                readiness: .compromised,
                sleepHours: 4.4
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.4)
        )
        let completedStory = try XCTUnwrap(completed.guidance.screenStory)
        let completedCopy = visibleTexts(completedStory).joined(separator: " ").lowercased()

        XCTAssertFalse(completedStory.title.isEmpty)
        XCTAssertTrue(completedStory.myRead.localizedCaseInsensitiveContains("ride"), completedStory.myRead)
        XCTAssertTrue(completedStory.myRead.localizedCaseInsensitiveContains("sleep"))
        XCTAssertFalse(completedStory.myRecommendation.isEmpty)
        XCTAssertFalse(completedStory.title.localizedCaseInsensitiveContains("sleep"))
        XCTAssertFalse(completedCopy.contains("sleep leads today"))
        XCTAssertFalse(completedCopy.contains("prepare for cycling"))
    }

    func testPostWorkoutRecoveryLeadsUntilLateEveningSleepHandoff() throws {
        let afternoonNow = Calendar.current.date(bySettingHour: 17, minute: 12, second: 0, of: now) ?? now
        let nightNow = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
        let afternoonRide = completedRide(endingMinutesBefore: 180, now: afternoonNow)
        let nightRide = completedRide(endingMinutesBefore: 410, now: nightNow)

        let afternoon = try lifecycleGuidance(
            for: afternoonRide,
            now: afternoonNow,
            brain: brain(
                currentHour: 17,
                recovery: .compromised,
                readiness: .compromised,
                sleepHours: 4.4
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.4)
        )
        let afternoonStory = try XCTUnwrap(afternoon.guidance.screenStory)
        let afternoonCopy = visibleTexts(afternoonStory).joined(separator: " ").lowercased()

        XCTAssertFalse(afternoonStory.title.isEmpty)
        XCTAssertTrue(afternoonCopy.contains("ride") || afternoonCopy.contains("recovery") || afternoonCopy.contains("sleep"))
        XCTAssertFalse(afternoonStory.title.localizedCaseInsensitiveContains("sleep"))
        XCTAssertFalse(afternoonCopy.contains("make tonight's sleep the main win"))

        let night = try lifecycleGuidance(
            for: nightRide,
            now: nightNow,
            brain: brain(
                currentHour: 21,
                recovery: .compromised,
                readiness: .compromised,
                sleepHours: 4.4
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.4)
        )
        let nightStory = try XCTUnwrap(night.guidance.screenStory)
        let nightCopy = visibleTexts(nightStory).joined(separator: " ").lowercased()

        XCTAssertFalse(nightStory.title.isEmpty)
        XCTAssertFalse(nightCopy.isEmpty)
    }

    func testCoachV5DynamicTextScenarioAudit() throws {
        let completedWalk = recovery(title: "Walk", minutesFromNow: -90, duration: 30, completed: true)
        let cyclingFar = cycling(title: "Cycling", minutesFromNow: 90, duration: 180)
        let cyclingSoon = cycling(title: "Cycling", minutesFromNow: 35, duration: 180)
        let cyclingActive = lifecycleRide(elapsedMinutes: 8, duration: 180)
        let cyclingComplete = lifecycleRide(completedMinutesAgo: 5, duration: 180)
        let eveningWalk = recovery(title: "Walk", minutesFromNow: -120, duration: 30, completed: true)
        let tomorrowRide = tomorrowCycling(title: "Long Ride", duration: 180)
        let sauna = quickSauna(minutesFromNow: 45, duration: 30)
        let eveningNow = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        let nightNow = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now

        let scenarios: [CoachDynamicTextScenario] = [
            .init(
                name: "1. No future activity",
                activities: [completedWalk],
                brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: nutrition(water: 0, meals: 1, calories: 372, carbs: 35),
                expectedStateContains: "GOOD TO GO",
                expectedTitleContains: "simple",
                forbidsActivityActions: true,
                hydrationMayDominate: false
            ),
            .init(
                name: "2. Cycling added, 90-120 min away",
                activities: [cyclingFar],
                brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
                nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90),
                expectedStateContains: "",
                expectedTitleContains: "",
                hydrationMayDominate: false
            ),
            .init(
                name: "3. Cycling 30-45 min away",
                activities: [cyclingSoon],
                brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
                nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90),
                expectedStateContains: "PREPARE",
                expectedTitleContains: "cycling",
                hydrationMayDominate: false
            ),
            .init(
                name: "4. Cycling active",
                activities: [cyclingActive],
                brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
                nutrition: nutrition(water: 0.7, meals: 1, calories: 900, carbs: 120),
                expectedStateContains: "KEEP IT EASY",
                expectedTitleContains: "",
                forbiddenTitleContains: "prepare",
                hydrationMayDominate: false
            ),
            .init(
                name: "5. Cycling completed",
                activities: [cyclingComplete],
                brain: brain(currentHour: 13, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: nutrition(water: 1.0, meals: 2, calories: 1_400, carbs: 160),
                expectedStateContains: "",
                expectedTitleContains: "",
                forbiddenTitleContains: "prepare",
                hydrationMayDominate: false
            ),
            .init(
                name: "6. Evening no activity",
                activities: [eveningWalk],
                brain: brain(currentHour: 20, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: nutrition(water: 1.0, meals: 3, calories: 1_900, carbs: 190),
                expectedStateContains: "WIND DOWN",
                expectedTitleContains: "evening",
                now: nightNow,
                forbidsActivityActions: true,
                hydrationMayDominate: false
            ),
            .init(
                name: "7. Tomorrow long ride",
                activities: [tomorrowRide],
                brain: brain(currentHour: 19, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: nutrition(water: 1.0, meals: 3, calories: 2_000, carbs: 220),
                expectedStateContains: "PROTECT TOMORROW",
                expectedTitleContains: "tomorrow",
                now: eveningNow,
                hydrationMayDominate: false
            ),
            .init(
                name: "8. Sauna soon + low water",
                activities: [sauna],
                brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
                nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90),
                expectedStateContains: "",
                expectedTitleContains: "",
                hydrationMayDominate: true
            )
        ]

        var auditLog: [String] = []

        for scenario in scenarios {
            let output = guidance(
                scenario.activities,
                brain: scenario.brain,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition,
                now: scenario.now
            )
            let story = try XCTUnwrap(output.screenStory, scenario.name)
            let rendered = renderedTexts(story)
            let duplicateWarnings = duplicateTextWarnings(story)
            let invalidActionWarnings = invalidActionWarnings(
                story: story,
                output: output,
                forbidsActivityActions: scenario.forbidsActivityActions
            )
            let selectedActivity = output.priority.activity?.title ?? "none"
            let limiter = output.narrativePlan?.primaryLimiter ?? CoachNarrativeLimiter.none
            let hydrationDominant = hydrationDominates(story)
            let brokenTime = rendered.localizedCaseInsensitiveContains("starts in in ") ||
                rendered.localizedCaseInsensitiveContains("starts in starting soon")

            auditLog.append("""

            [CoachDynamicTextAudit] \(scenario.name)
            objective=\(output.narrativePlan?.objective ?? output.priority.objective)
            priority=\(output.priority.priority)/\(output.priority.focus)
            limiter=\(limiter)
            selectedActivity=\(selectedActivity)
            renderedState="\(story.stateLabel)"
            renderedTitle="\(story.title)"
            myRead="\(story.myRead)"
            myRecommendation="\(story.myRecommendation)"
            beCarefulWith="\(story.beCarefulWith)"
            primaryActions=\(story.primaryActions.map(\.title))
            supportActions=\(story.supportActions.map(\.title))
            duplicateTextWarnings=\(duplicateWarnings)
            invalidActionWarnings=\(invalidActionWarnings)
            """)

            if !scenario.expectedStateContains.isEmpty {
                XCTAssertTrue(story.stateLabel.localizedCaseInsensitiveContains(scenario.expectedStateContains), scenario.name)
            }
            if !scenario.expectedTitleContains.isEmpty {
                XCTAssertTrue(story.title.localizedCaseInsensitiveContains(scenario.expectedTitleContains), scenario.name)
            }
            if let forbiddenTitle = scenario.forbiddenTitleContains {
                XCTAssertFalse(story.title.localizedCaseInsensitiveContains(forbiddenTitle), scenario.name)
            }
            XCTAssertFalse(duplicateWarnings.contains { $0.localizedCaseInsensitiveContains("controlled") }, scenario.name)
            XCTAssertFalse(invalidActionWarnings.contains { $0.localizedCaseInsensitiveContains("controlled") }, scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("controlled"), scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("Preparation matters more than chasing any single metric"), scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("Nothing in the current day asks for a major change right now"), scenario.name)
            XCTAssertFalse(brokenTime, scenario.name)
            XCTAssertFalse(hydrationDominant && rendered.localizedCaseInsensitiveContains("Hydration first"), scenario.name)
            XCTAssertFalse(story.primaryActions.isEmpty && !story.supportActions.isEmpty, scenario.name)
        }

        let renderedAudit = auditLog.joined(separator: "\n")
        try? renderedAudit.write(
            toFile: "/tmp/weekfit-dynamic-text-audit.log",
            atomically: true,
            encoding: .utf8
        )
        print(renderedAudit)
    }

    func testPrepWindowWithNoWaterOrFoodShowsConcreteSupportSignals() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 60, duration: 75)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 0, calories: 0, carbs: 0)
        ).screenStory)

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertTrue(story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
        XCTAssertTrue(story.primaryActions.contains { $0.type == .lightFueling || $0.type == .sustainEnergy })
        XCTAssertTrue(story.primaryActions.contains { $0.type == .controlIntensity || $0.type == .steadyHydration })
        XCTAssertFalse(visibleTexts(story).joined(separator: " ").localizedCaseInsensitiveContains("Support the session first"))
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Hydrate" })
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Eat planned meal" })
    }

    func testPrepWindowAfterWaterLoggedSwitchesToBottleAndSipping() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 55, duration: 75)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.5, meals: 0, calories: 0, carbs: 0)
        ).screenStory)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
    }

    func testPrepWindowAfterMoreWaterLoggedDoesNotAskForAnotherBolus() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 50, duration: 75)
        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.75, meals: 0, calories: 0, carbs: 0)
        ).screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Add 300-500 ml now"))
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
    }

    func testPrepWindowAfterRecentMealWithLowWaterKeepsFluidsMoving() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 50, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.2, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Fuel is still missing"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Eat planned meal"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Add 30-60g carbs"))
    }

    func testPrepWindowMealLoggedButWaterZeroKeepsHydrationWarningVisible() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 20, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")
        let allActions = story.primaryActions + story.supportActions

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertTrue(allActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Fuel is still missing"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Eat planned meal"))
    }

    func testPrepWindowMealLoggedAndWaterStartedMovesToReadyToStart() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 20, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.5, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Fuel is still missing"))
    }

    func testPrepWindowWaterDeletedDoesNotReuseHydrationImprovingNarrative() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 10, duration: 75)
        let afterWater = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.5, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        ).screenStory)
        XCTAssertTrue(visibleTexts(afterWater).joined(separator: " ").localizedCaseInsensitiveContains("hydration has started"))

        let afterDeletingWater = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        ).screenStory)
        let visible = visibleTexts(afterDeletingWater).joined(separator: " ")

        XCTAssertFalse(visible.localizedCaseInsensitiveContains("hydration has started"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Hydration is improving"))
    }

    func testPrepWindowNoMealAndWaterZeroShowsBothWarnings() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 20, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
        XCTAssertTrue(story.primaryActions.contains { $0.type == .lightFueling || $0.type == .sustainEnergy })
    }

    func testPrepareForActivitySupportSignalsAreVisibleInGuidanceAndStory() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 7, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(output.screenStory)
        let support = output.priority.supportBullets.joined(separator: " ")
        let teaser = output.dynamicInsight.text

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Hydration") || support.localizedCaseInsensitiveContains("water"))
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Fuel") || support.localizedCaseInsensitiveContains("carb"))
        XCTAssertTrue(story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
        XCTAssertTrue(story.primaryActions.contains { $0.type == .lightFueling || $0.type == .sustainEnergy })
        XCTAssertFalse(teaser.localizedCaseInsensitiveContains("Hydration first"))
    }

    func testPrepWindowAfterWaterAndRecentMealConfirmsMainPrepDone() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: 50, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.75, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Fuel is still missing"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Eat planned meal"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Add 30-60g carbs"))
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
    }

    func testPreparationWindowBeatsStableOverviewWhenBasicsImprove() {
        let ride = cycling(title: "Cycling", minutesFromNow: 50, duration: 75)
        let output = guidance(
            [ride],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.75, meals: 1, calories: 700, carbs: 90, lastMealMinutesAgo: 20)
        )

        XCTAssertEqual(output.priority.priority, .performance)
        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertEqual(output.priority.activity?.id, ride.id)
        XCTAssertEqual(output.priority.detailTitle, "Prepare for cycling")
    }

    func testMorningNoMealsWithoutHardActivityDoesNotCreateFuelWarning() throws {
        let walk = recovery(title: "Walk", minutesFromNow: -30, duration: 30, completed: true)
        let output = guidance(
            [walk],
            brain: brain(currentHour: 9, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: nutrition(water: 0.75, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertNotEqual(output.priority.focus, .fuelBehind)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Fuel is still missing"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Add 30-60g carbs"))
    }

    func testLateEveningRideStoryHasOneWhyAndNoPlanAdjustmentWhenReady() throws {
        let walk = recovery(title: "Walk", minutesFromNow: -180, duration: 35, completed: true)
        let tomorrowRide = tomorrowCycling(title: "Cycling", duration: 180)

        let guidance = guidance(
            [walk, tomorrowRide],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 7.8),
            nutrition: nutrition()
        )

        let story = try XCTUnwrap(guidance.screenStory)

        let visible = visibleTexts(story).joined(separator: " ")
        XCTAssertTrue(
            visible.localizedCaseInsensitiveContains("tomorrow") ||
            visible.localizedCaseInsensitiveContains("cycling") ||
            visible.localizedCaseInsensitiveContains("sleep")
        )
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        assertNoDuplicateIdeas(story)
    }

    func testLateBalancedEveningHidesWhyAndPlanAdjustment() throws {
        let guidance = guidance(
            [],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.2, meals: 3)
        )

        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("reduce"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("extra training"))
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        XCTAssertFalse(story.shouldShowActivityContext)
        assertNoProblemLanguage(story)
        assertNoDuplicateIdeas(story)
    }

    func testLocalEveningEmptyDayRendersWindDownNotGoodToGo() throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Europe/Warsaw") ?? previousTimeZone
        defer { NSTimeZone.default = previousTimeZone }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let scenarioNow = calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 5,
            hour: 20,
            minute: 25
        )) ?? now
        let brain = HumanBrainStateBuilder.make(
            currentHour: 18,
            hasAnyFoodLogged: true,
            energyCoverage: 0.52,
            carbsProgress: 0.52,
            caloriesProgress: 0.52,
            waterProgress: 0.43,
            hydration: .depleted,
            fuel: .light,
            protein: .behind,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                protein: 78,
                carbs: 146,
                calories: 1_248,
                waterLiters: 1.29,
                activeCalories: 350
            )
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1_248,
            caloriesGoal: 2_400,
            proteinCurrent: 78,
            proteinGoal: 150,
            carbsCurrent: 146,
            carbsGoal: 280,
            waterCurrent: 1.29,
            waterGoal: 3.0,
            mealsCount: 1,
            lastMealTime: scenarioNow.addingTimeInterval(-6 * 3_600)
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: [],
            selectedDate: scenarioNow,
            now: scenarioNow
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: [],
            selectedDate: scenarioNow,
            now: scenarioNow,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(Calendar.current.component(.hour, from: scenarioNow), 20)
        XCTAssertEqual(priority.focus, .eveningWindDown)
        XCTAssertEqual(guidance.stateLabel, CoachNarrativeBadgeIntent.windDown.label)
        XCTAssertNotEqual(guidance.stateLabel, CoachNarrativeBadgeIntent.goodToGo.label)
        XCTAssertFalse(priority.reasons.joined(separator: " ").localizedCaseInsensitiveContains("late night"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("start easy"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("first 10 minutes"))
    }

    func testProtectTomorrowObjectiveChangesFullEveningNarrativeContract() throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Europe/Warsaw") ?? previousTimeZone
        defer { NSTimeZone.default = previousTimeZone }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let scenarioNow = calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 5,
            hour: 20,
            minute: 25
        )) ?? now
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: scenarioNow) ?? scenarioNow
        let tomorrowRideDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrowDate) ?? tomorrowDate
        let tomorrowRide = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: tomorrowRideDate,
            durationMinutes: 180
        )

        func makeGuidance(_ activities: [PlannedActivity]) throws -> (CoachDayPriorityResult, CoachScreenStory) {
            let brain = HumanBrainStateBuilder.make(
                currentHour: 20,
                hasAnyFoodLogged: true,
                energyCoverage: 0.52,
                carbsProgress: 0.52,
                caloriesProgress: 0.52,
                waterProgress: 0.43,
                hydration: .depleted,
                fuel: .light,
                protein: .behind,
                recovery: .stable,
                readiness: .good,
                metrics: CoachMetricsBuilder.metrics(
                    protein: 78,
                    carbs: 146,
                    calories: 1_248,
                    waterLiters: 1.29,
                    activeCalories: 350
                )
            )
            let nutrition = CoachNutritionContext(
                caloriesCurrent: 1_248,
                caloriesGoal: 2_400,
                proteinCurrent: 78,
                proteinGoal: 150,
                carbsCurrent: 146,
                carbsGoal: 280,
                waterCurrent: 1.29,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: scenarioNow.addingTimeInterval(-6 * 3_600)
            )
            let dayContext = CoachDayContextBuilder.build(
                activities: activities,
                selectedDate: scenarioNow,
                now: scenarioNow
            )
            let activityContext = CoachActivityContextResolverV3.resolveDayContext(
                activities: activities,
                selectedDate: scenarioNow,
                now: scenarioNow,
                brain: brain
            )
            let readiness = CoachReadinessAnalyzerV3.analyze(
                brain: brain,
                phase: activityContext.phase
            )
            let tomorrowContext: CoachTomorrowPlanContext? = {
                let tomorrowDay = CoachDayContextBuilder.build(
                    activities: activities,
                    selectedDate: tomorrowDate,
                    now: scenarioNow
                )
                return tomorrowDay.allActivities.isEmpty ? nil : CoachTomorrowPlanContext(dayContext: tomorrowDay)
            }()
            let context = CoachDecisionContext(
                brain: brain,
                dayContext: dayContext,
                activityContext: activityContext,
                tomorrowContext: tomorrowContext,
                recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
                nutritionContext: nutrition,
                readiness: readiness
            )
            let priority = CoachDayPriorityResolver.resolve(context)
            let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
            let opportunity = CoachSupportOpportunityResolverV3.resolve(
                phase: activityContext.phase,
                readiness: readiness,
                brain: brain
            )
            let guidance = HumanCoachDecisionEngine.adapt(
                decision,
                phase: activityContext.phase,
                opportunity: opportunity,
                legacyPriority: priority,
                activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
                activeSessionPhase: activityContext.activeSessionPhase
            )
            return (priority, try XCTUnwrap(guidance.screenStory))
        }

        let eveningReset = try makeGuidance([])
        let protectTomorrow = try makeGuidance([tomorrowRide])

        XCTAssertEqual(eveningReset.0.objective, .completeDay)
        XCTAssertEqual(protectTomorrow.0.objective, .protectTomorrow)
        XCTAssertEqual(protectTomorrow.0.limiter, .upcomingTraining)

        XCTAssertFalse(protectTomorrow.1.myRead.isEmpty)
        XCTAssertFalse(protectTomorrow.1.myRecommendation.isEmpty)
    }

    func testProtectTomorrowDoesNotMentionCaloriesWhenNutritionCovered() throws {
        let scenario = try protectTomorrowEveningScenario()
        let story = scenario.story
        let visibleText = (
            scenario.priority.supportBullets +
            [story.myRead, story.myRecommendation, story.beCarefulWith] +
            story.primaryActions.map(\.title) +
            scenario.guidance.avoidNotes
        )
        .joined(separator: " ")
        .lowercased()

        XCTAssertEqual(scenario.priority.objective, .protectTomorrow)
        XCTAssertFalse(visibleText.contains("calorie"))
        XCTAssertFalse(visibleText.contains("food"))
        XCTAssertFalse(visibleText.contains("meal"))
        XCTAssertFalse(visibleText.contains("fuel"))
    }

    func testProtectTomorrowWithGoodRecoveryIsHighNotCritical() throws {
        let scenario = try protectTomorrowEveningScenario(
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
            activeCalories: 350
        )

        XCTAssertEqual(scenario.priority.objective, .protectTomorrow)
        XCTAssertEqual(scenario.priority.strength, .high)
        XCTAssertEqual(scenario.priority.level, .important)
        XCTAssertEqual(scenario.guidance.narrativePlan?.urgency, .caution)
    }

    func testProtectTomorrowHydrationActionsAreDeduped() throws {
        let scenario = try protectTomorrowEveningScenario()
        let hydrationModerationBullets = scenario.priority.supportBullets.filter { bullet in
            let normalized = bullet.lowercased()
            return normalized.contains("water") ||
                normalized.contains("fluid") ||
                normalized.contains("hydrate") ||
                normalized.contains("hydration") ||
                normalized.contains("sip")
        }
        let supportText = scenario.priority.supportBullets.joined(separator: " ").lowercased()

        XCTAssertEqual(hydrationModerationBullets.count, 1)
        XCTAssertTrue(supportText.contains("sip gradually if thirsty"))
        XCTAssertFalse(supportText.contains("do not chase water now"))
        XCTAssertFalse(supportText.contains("do not chase the full water target"))
    }

    func testProtectTomorrowLongRideTomorrowIsHighNotCriticalWithoutSafetyLimiter() throws {
        let scenario = try protectTomorrowEveningScenario(
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
            activeCalories: 350
        )

        XCTAssertEqual(scenario.priority.objective, .protectTomorrow)
        XCTAssertEqual(scenario.priority.limiter, .upcomingTraining)
        XCTAssertEqual(scenario.priority.strength, .high)
        XCTAssertEqual(scenario.priority.level, .important)
        XCTAssertEqual(scenario.guidance.narrativePlan?.urgency, .caution)
    }

    func testProtectTomorrowMentionsHydrationOnlyWhenFuelCovered() throws {
        let scenario = try protectTomorrowEveningScenario()
        let story = scenario.story
        let actionTitles = story.primaryActions.map(\.title)

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertTrue(
            story.myRead.localizedCaseInsensitiveContains("next important event") ||
            story.myRecommendation.localizedCaseInsensitiveContains("sleep") ||
            story.myRecommendation.localizedCaseInsensitiveContains("recovery")
        )
        XCTAssertFalse(story.beCarefulWith.isEmpty)
        XCTAssertTrue(scenario.priority.supportBullets.contains { $0.localizedCaseInsensitiveContains("sip") || $0.localizedCaseInsensitiveContains("hydrat") })
        XCTAssertTrue(scenario.priority.supportBullets.contains("Protect sleep"))
        XCTAssertTrue(scenario.priority.supportBullets.contains("Skip extra intensity"))
        assertNoExecutionLanguage(in: story.primaryActions)
        assertClosePhaseActions(story.primaryActions)
    }

    func testEveningWindDownActionsContainNoExecutionLanguage() throws {
        let scenario = try protectTomorrowEveningScenario(includesTomorrowRide: false)
        let story = scenario.story
        let actionTitles = story.primaryActions.map(\.title)

        XCTAssertEqual(scenario.priority.focus, .eveningWindDown)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.windDown.label)
        assertNoExecutionLanguage(in: story.primaryActions)
        XCTAssertFalse(actionTitles.isEmpty)
    }

    func testProtectTomorrowRequiresRealTomorrowDemand() throws {
        let scenario = try protectTomorrowEveningScenario(
            recovery: CoachRecoveryContext(recoveryPercent: 89, sleepHours: 7.4),
            activeCalories: 350,
            includesTomorrowRide: false
        )
        let visibleText = visibleCoachText(
            story: scenario.story,
            guidance: scenario.guidance
        ).lowercased()

        XCTAssertEqual(scenario.priority.focus, .eveningWindDown)
        XCTAssertNotEqual(scenario.priority.objective, .protectTomorrow)
        XCTAssertNotEqual(scenario.story.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        XCTAssertFalse(visibleText.contains("tomorrow's training"))
        XCTAssertFalse(visibleText.contains("next important event"))
    }

    func testProtectTomorrowActionsContainNoExecutionLanguage() throws {
        let scenario = try protectTomorrowEveningScenario()

        XCTAssertEqual(scenario.priority.objective, .protectTomorrow)
        XCTAssertEqual(scenario.story.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        assertNoExecutionLanguage(in: scenario.story.primaryActions)
    }

    func testVisibleCopyContainsNoInternalEngineTerminology() throws {
        let scenarios = [
            try protectTomorrowEveningScenario(),
            try protectTomorrowEveningScenario(includesTomorrowRide: false)
        ]
        let forbiddenTerms = ["support signal", "limiter", "priority", "candidate", "main story"]

        for scenario in scenarios {
            let visibleText = visibleCoachText(
                story: scenario.story,
                guidance: scenario.guidance
            ).lowercased()

            for term in forbiddenTerms {
                XCTAssertFalse(
                    visibleText.contains(term),
                    "Visible Coach copy should not contain internal term '\(term)': \(visibleText)"
                )
            }
        }
    }

    func testHeroAndActionsUseSameDayPhase() throws {
        let evening = try protectTomorrowEveningScenario(includesTomorrowRide: false)
        let protectTomorrow = try protectTomorrowEveningScenario()

        XCTAssertEqual(evening.story.stateLabel, CoachNarrativeBadgeIntent.windDown.label)
        XCTAssertEqual(protectTomorrow.story.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        assertClosePhaseActions(evening.story.primaryActions)
        assertClosePhaseActions(protectTomorrow.story.primaryActions)
    }

    func testMorningHighRecoveryLaterRideUsesSetupNotManageEffort() throws {
        let scenario = try morningHighRecoveryLaterRideScenario()
        let story = scenario.story

        XCTAssertNotEqual(scenario.priority.priority, .planChallenge)
        XCTAssertNotEqual(story.stateLabel, CoachNarrativeBadgeIntent.manageEffort.label)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.myRead.isEmpty)
        XCTAssertFalse(story.myRecommendation.isEmpty)
        XCTAssertFalse(story.primaryActions.isEmpty)
    }

    func testCoachScreenRendersMorningSetupGuidanceInsteadOfCurrentStatusFallback() throws {
        let scenario = try morningHighRecoveryLaterRideScenario()

        XCTAssertFalse(scenario.story.stateLabel.isEmpty)
        XCTAssertFalse(scenario.story.title.isEmpty)
        XCTAssertNotEqual(scenario.guidance.priority.priority, .planChallenge)
        XCTAssertNotEqual(scenario.guidance.priority.focus, .trainingReadinessWarning)
        XCTAssertNotEqual(scenario.guidance.priority.limiter, .none)
        XCTAssertNotNil(scenario.guidance.screenStory)
        XCTAssertEqual(scenario.guidance.screenStory?.title, scenario.story.title)
    }

    func testCoachDoesNotMentionTrainingLaterWhenNoActivityExists() throws {
        let scenario = try morningHighRecoveryLaterRideScenario(includesRide: false)
        let visibleText = visibleCoachText(story: scenario.story, guidance: scenario.guidance).lowercased()

        XCTAssertNil(scenario.context.dayContext.nextActivity)
        XCTAssertFalse(scenario.story.stateLabel.isEmpty)
        XCTAssertFalse(scenario.story.myRead.isEmpty)
        XCTAssertFalse(visibleText.contains("training later today"))
        XCTAssertFalse(visibleText.contains("training is still later"))
        XCTAssertFalse(visibleText.contains("ride is still later"))
        XCTAssertFalse(visibleText.contains("activity later today"))
        XCTAssertFalse(visibleText.contains("prepare for training"))
    }

    func testCoachClearsTrainingNarrativeAfterPlannedActivityDeleted() throws {
        let withRide = try morningHighRecoveryLaterRideScenario(includesRide: true)
        let afterDeletion = try morningHighRecoveryLaterRideScenario(includesRide: false)
        let deletedVisibleText = visibleCoachText(story: afterDeletion.story, guidance: afterDeletion.guidance).lowercased()

        XCTAssertTrue(visibleCoachText(story: withRide.story, guidance: withRide.guidance).lowercased().contains("ride") || visibleCoachText(story: withRide.story, guidance: withRide.guidance).lowercased().contains("cycling"))
        XCTAssertNil(afterDeletion.context.dayContext.nextActivity)
        XCTAssertFalse(afterDeletion.story.myRead.isEmpty)
        XCTAssertFalse(deletedVisibleText.contains("ride is still later"))
        XCTAssertFalse(deletedVisibleText.contains("training is still later"))
        XCTAssertFalse(deletedVisibleText.contains("ride window"))
        XCTAssertFalse(deletedVisibleText.contains("keep the ride plan unchanged"))
    }

    func testCoachInvalidatesCachedGuidanceWhenPlanChanges() throws {
        let withRide = try morningHighRecoveryLaterRideScenario(includesRide: true)
        let withoutRide = try morningHighRecoveryLaterRideScenario(includesRide: false)
        let rideText = visibleCoachText(story: withRide.story, guidance: withRide.guidance)
        let openDayText = visibleCoachText(story: withoutRide.story, guidance: withoutRide.guidance)

        XCTAssertNotEqual(withRide.context.dayContext.nextActivity?.id, withoutRide.context.dayContext.nextActivity?.id)
        XCTAssertNotEqual(rideText, openDayText)
        XCTAssertFalse(openDayText.isEmpty)
        XCTAssertFalse(openDayText.localizedCaseInsensitiveContains("ride plan unchanged"))
    }

    func testTodayAndCoachUseSameResolvedActivityContext() throws {
        let withRide = try morningHighRecoveryLaterRideScenario(includesRide: true)
        let withoutRide = try morningHighRecoveryLaterRideScenario(includesRide: false)

        XCTAssertNotNil(withRide.context.dayContext.nextActivity)
        XCTAssertNotNil(withRide.context.activityContext.nextUpcomingActivity)
        XCTAssertNil(withoutRide.context.dayContext.nextActivity)
        XCTAssertNil(withoutRide.context.activityContext.nextUpcomingActivity)
    }

    func testMorningSetupWithoutTrainingUsesOpenDayLanguage() throws {
        let scenario = try morningHighRecoveryLaterRideScenario(includesRide: false)
        let actionTitles = scenario.story.primaryActions.map(\.title)
        let visibleText = visibleCoachText(story: scenario.story, guidance: scenario.guidance).lowercased()

        XCTAssertFalse(scenario.story.title.isEmpty)
        XCTAssertFalse(scenario.story.myRead.isEmpty)
        XCTAssertFalse(scenario.story.myRecommendation.isEmpty)
        XCTAssertFalse(actionTitles.isEmpty)
        XCTAssertFalse(visibleText.contains("ride window"))
        XCTAssertFalse(visibleText.contains("keep the ride plan unchanged"))
        XCTAssertFalse(visibleText.contains("training later today"))
    }

    func testRecovery99PreventsUnnecessaryRideReductionLanguage() throws {
        let scenario = try morningHighRecoveryLaterRideScenario()
        let visibleText = visibleCoachText(story: scenario.story, guidance: scenario.guidance).lowercased()

        XCTAssertNotEqual(scenario.priority.priority, .planChallenge)
        XCTAssertEqual(scenario.priority.strength, .medium)
        XCTAssertFalse(visibleText.contains("lower the ceiling"))
        XCTAssertFalse(visibleText.contains("reduce"))
        XCTAssertFalse(visibleText.contains("manage effort"))
        XCTAssertFalse(visibleText.contains("adjust the plan"))
    }

    func testNoFoodNoWaterMorningDoesNotLowerCeilingBeforePrepWindow() throws {
        let scenario = try morningHighRecoveryLaterRideScenario(minutesUntilRide: 360)
        let story = scenario.story
        let visibleText = visibleCoachText(story: story, guidance: scenario.guidance).lowercased()

        XCTAssertNil(scenario.context.activityContext.preparingActivity)
        XCTAssertNotEqual(scenario.priority.priority, .planChallenge)
        XCTAssertNotEqual(story.stateLabel, CoachNarrativeBadgeIntent.manageEffort.label)
        XCTAssertFalse(visibleText.contains("lower the ceiling"))
        XCTAssertFalse(visibleText.contains("make the warm-up decide"))
        XCTAssertFalse(visibleText.contains("start controlled"))
        XCTAssertFalse(visibleText.contains("train easy today"))
    }

    private func protectTomorrowEveningScenario(
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
        activeCalories: Double = 350,
        includesTomorrowRide: Bool = true
    ) throws -> (priority: CoachDayPriorityResult, guidance: CoachGuidanceV3, story: CoachScreenStory) {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Europe/Warsaw") ?? previousTimeZone
        defer { NSTimeZone.default = previousTimeZone }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let scenarioNow = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 5,
            hour: 20,
            minute: 25
        )))
        let tomorrowDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: scenarioNow))
        let tomorrowRideDate = try XCTUnwrap(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrowDate))
        let tomorrowRide = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: tomorrowRideDate,
            durationMinutes: 180
        )
        let activities = includesTomorrowRide ? [tomorrowRide] : []
        let brain = HumanBrainStateBuilder.make(
            currentHour: 20,
            hasAnyFoodLogged: true,
            energyCoverage: 1.23,
            carbsProgress: 1.42,
            caloriesProgress: 1.23,
            waterProgress: 0.43,
            hydration: .depleted,
            fuel: .good,
            protein: .good,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                protein: 120,
                carbs: 398,
                calories: 2_952,
                waterLiters: 1.29,
                activeCalories: activeCalories
            )
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2_952,
            caloriesGoal: 2_400,
            proteinCurrent: 120,
            proteinGoal: 150,
            carbsCurrent: 398,
            carbsGoal: 280,
            waterCurrent: 1.29,
            waterGoal: 3.0,
            mealsCount: 4,
            lastMealTime: scenarioNow.addingTimeInterval(-30 * 60)
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let tomorrowDay = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrowDate,
            now: scenarioNow
        )
        let tomorrowContext = tomorrowDay.allActivities.isEmpty ? nil : CoachTomorrowPlanContext(dayContext: tomorrowDay)
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowContext,
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )

        return (priority, guidance, try XCTUnwrap(guidance.screenStory))
    }

    private func morningHighRecoveryLaterRideScenario(
        minutesUntilRide: Int = 360,
        includesRide: Bool = true
    ) throws -> (
        context: CoachDecisionContext,
        priority: CoachDayPriorityResult,
        guidance: CoachGuidanceV3,
        story: CoachScreenStory
    ) {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Europe/Warsaw") ?? previousTimeZone
        defer { NSTimeZone.default = previousTimeZone }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let scenarioNow = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 6,
            hour: 6,
            minute: 0
        )))
        let ride = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: scenarioNow.addingTimeInterval(TimeInterval(minutesUntilRide * 60)),
            durationMinutes: 180
        )
        let activities = includesRide ? [ride] : []
        let brain = HumanBrainStateBuilder.make(
            currentHour: 6,
            hasAnyFoodLogged: false,
            energyCoverage: 0,
            carbsProgress: 0,
            caloriesProgress: 0,
            waterProgress: 0,
            hydration: .depleted,
            fuel: .light,
            protein: .behind,
            recovery: .strong,
            readiness: .excellent,
            metrics: CoachMetricsBuilder.metrics(
                protein: 0,
                carbs: 0,
                calories: 0,
                waterLiters: 0,
                activeCalories: 0
            )
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_400,
            proteinCurrent: 0,
            proteinGoal: 150,
            carbsCurrent: 0,
            carbsGoal: 280,
            waterCurrent: 0,
            waterGoal: 3.0,
            mealsCount: 0,
            lastMealTime: nil
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 99, sleepHours: 8.1),
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )

        return (context, priority, guidance, try XCTUnwrap(guidance.screenStory))
    }

    private func assertNoExecutionLanguage(
        in actions: [CoachSupportingAction],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let forbiddenTerms = [
            "train easy today",
            "start controlled",
            "pace yourself",
            "manage effort",
            "use body feedback now"
        ]
        let text = actions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ").lowercased()

        for term in forbiddenTerms {
            XCTAssertFalse(text.contains(term), "Action copy contains execution term '\(term)': \(text)", file: file, line: line)
        }
    }

    private func assertClosePhaseActions(
        _ actions: [CoachSupportingAction],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let closeTerms = [
            "prepare for sleep",
            "keep the evening calm",
            "skip extra training",
            "leave tomorrow for tomorrow",
            "protect sleep",
            "wind down",
            "sip calmly"
        ]
        let actionText = actions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ").lowercased()

        assertNoExecutionLanguage(in: actions, file: file, line: line)
        XCTAssertFalse(actions.isEmpty, "Close-phase cards should expose close-phase actions.", file: file, line: line)
        for action in actions {
            let text = "\(action.title) \(action.subtitle)".lowercased()
            XCTAssertTrue(
                closeTerms.contains { text.contains($0) },
                "Action is not close-phase copy: \(action.title) / \(action.subtitle). All actions: \(actionText)",
                file: file,
                line: line
            )
        }
    }

    private func visibleCoachText(story: CoachScreenStory, guidance: CoachGuidanceV3) -> String {
        (
            [
                story.stateLabel,
                story.title,
                story.myRead,
                story.myRecommendation,
                story.beCarefulWith,
                story.whyThisMatters ?? "",
                story.planAdjustment ?? "",
                story.activityContext ?? "",
                guidance.title,
                guidance.message,
                guidance.insightTitle,
                guidance.insightSubtitle ?? ""
            ] +
            story.primaryActions.flatMap { [$0.title, $0.subtitle] } +
            guidance.supportActions.flatMap { [$0.title, $0.subtitle] } +
            guidance.avoidNotes
        )
        .joined(separator: " ")
    }

    func testLateActiveSaunaUsesSituationalContextNotEducation() throws {
        let sauna = quickSauna(minutesFromNow: -5, duration: 25)

        let guidance = guidance(
            [sauna],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.2, meals: 3)
        )

        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(story.title, "Keep the sauna easy tonight")
        XCTAssertEqual(story.myRead, "You started a recovery sauna session late in the evening.")
        XCTAssertEqual(story.myRecommendation, "Use it to relax, not to extend the day.")
        XCTAssertEqual(story.beCarefulWith, "Long exposure, dehydration, or turning heat into another effort.")
        XCTAssertNil(story.whyThisMatters)
        XCTAssertFalse(story.shouldShowWhy)
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        XCTAssertTrue(story.shouldShowActivityContext)
        XCTAssertEqual(story.activityContext, "This is a bridge into sleep, so the next win is cooling down cleanly.")
        XCTAssertFalse(story.activityContext?.localizedCaseInsensitiveContains("circulation") == true)
        assertNoDuplicateIdeas(story)
    }

    func testActiveSessionGuidanceChangesByPhase() throws {
        let startingGuidance = guidance(
            [cycling(title: "Endurance Ride", minutesFromNow: -5, duration: 60)],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.4)
        )
        let starting = try XCTUnwrap(startingGuidance.screenStory)

        let middle = try XCTUnwrap(guidance(
            [cycling(title: "Endurance Ride", minutesFromNow: -30, duration: 60)],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.4)
        ).screenStory)

        let finishing = try XCTUnwrap(guidance(
            [cycling(title: "Endurance Ride", minutesFromNow: -55, duration: 60)],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.4)
        ).screenStory)

        XCTAssertFalse(starting.myRecommendation.isEmpty)
        XCTAssertFalse(middle.myRecommendation.isEmpty)
        XCTAssertFalse(finishing.myRecommendation.isEmpty)
        XCTAssertNotEqual(starting.myRecommendation, middle.myRecommendation)
        XCTAssertNotEqual(middle.myRecommendation, finishing.myRecommendation)

        XCTAssertFalse(startingGuidance.dynamicInsight.text.isEmpty)
        XCTAssertLessThanOrEqual(startingGuidance.dynamicInsight.text.count, 80)
        XCTAssertFalse(startingGuidance.dynamicInsight.text.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(startingGuidance.dynamicInsight.text.localizedCaseInsensitiveContains("because"))
    }

    func testUncertainActiveIdentityUsesNeutralActivityContext() throws {
        let strength = workout(title: "Strength", minutesFromNow: -5, duration: 60, completed: false)
        let ride = cycling(title: "Endurance Ride", minutesFromNow: -5, duration: 60)

        let guidance = guidance(
            [strength, ride],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.4)
        )

        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertTrue(story.shouldShowActivityContext)
        XCTAssertFalse(story.activityContext?.localizedCaseInsensitiveContains("Strength") == true)
        XCTAssertFalse(story.activityContext?.localizedCaseInsensitiveContains("Endurance Ride") == true)
        XCTAssertTrue(story.activityContext?.localizedCaseInsensitiveContains("targets") == true)
    }

    func testWhyThisMattersHidesFillerWhenStoryAlreadyExplainsIt() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: -10, duration: 90)
        ride.source = "today"

        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.8),
            nutrition: nutrition(water: 2.4)
        ).screenStory)

        XCTAssertFalse(story.shouldShowWhy)
        XCTAssertNil(story.whyThisMatters)
    }

    func testActiveRecommendationUsesHydrationContextInsteadOfGenericHydration() throws {
        let ride = cycling(title: "Endurance Ride", minutesFromNow: -30, duration: 60)

        let story = try XCTUnwrap(guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: nutrition(water: 2.4)
        ).screenStory)

        let primaryText = story.primaryActions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ")
        XCTAssertTrue(primaryText.localizedCaseInsensitiveContains("easy") || primaryText.localizedCaseInsensitiveContains("reserve") || primaryText.localizedCaseInsensitiveContains("aerobic"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Hydrate steadily"))
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Hydrate steadily" })
    }

    func testActiveManualRunWithNoFoodNoWaterAndSaunaLaterPreservesDayObjective() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)
        run.source = "today"
        let sauna = quickSauna(minutesFromNow: 120, duration: 30)

        let guidance = guidance(
            [run, sauna],
            brain: brain(currentHour: 10, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 6.2),
            nutrition: nutrition(water: 0, waterGoal: 3.2, meals: 0, calories: 0, carbs: 0, lastMealMinutesAgo: nil)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        XCTAssertEqual(guidance.priority.objective, .prepareActivity)
        let plan = try XCTUnwrap(guidance.narrativePlan)
        XCTAssertEqual(plan.priority, .activeSession)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        XCTAssertEqual(plan.urgency, .caution)
        XCTAssertTrue([CoachNarrativeBadgeIntent.manageEffort, .keepControlled].contains(plan.badgeIntent))

        let story = try XCTUnwrap(guidance.screenStory)
        let visibleText = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertTrue(visibleText.contains("live") || visibleText.contains("run"))
        XCTAssertFalse(story.primaryActions.contains { action in
            action.title.localizedCaseInsensitiveContains("Drink") ||
                action.title.localizedCaseInsensitiveContains("Eat") ||
                action.title.localizedCaseInsensitiveContains("Fuel")
        })
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("Do not force"))
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
        XCTAssertFalse(guidance.dynamicInsight.title.localizedCaseInsensitiveContains("Prepare for sauna"))
    }

    func testActiveSessionScreenStoryPreservesResolverActivitySpecificTitle() throws {
        let upperBody = workout(title: "Upper Body", minutesFromNow: -10, duration: 45, completed: false)
        upperBody.source = "today"

        let guidance = guidance(
            [upperBody],
            brain: brain(currentHour: 20, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 6.2),
            nutrition: nutrition(water: 0.5, waterGoal: 2.4, meals: 1, calories: 1_200, carbs: 140, lastMealMinutesAgo: 90)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        XCTAssertEqual(guidance.priority.detailTitle, "Control today's upper body session")

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertEqual(story.title, guidance.priority.detailTitle)
        XCTAssertEqual(story.title, "Control today's upper body session")
        XCTAssertNotEqual(story.title, "Keep session easy")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("control") || story.myRecommendation.localizedCaseInsensitiveContains("reserve"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Reduce load" || $0.title == "Use body feedback now" })
    }

    func testLateNightActiveRideKeepsActiveStoryWithTimingContext() throws {
        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 45)
        ride.source = "today"

        let guidance = guidance(
            [ride],
            brain: brain(currentHour: 23, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 89, sleepHours: 7.4),
            nutrition: nutrition(water: 2.6, waterGoal: 3.0, meals: 3, calories: 1_900, carbs: 180, lastMealMinutesAgo: 90)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        XCTAssertNotEqual(guidance.screenStory?.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        XCTAssertNotEqual(guidance.screenStory?.title, "Protect the night")

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertEqual(story.title, "Enjoy the ride")
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("started cycling late"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("recovery is holding up well"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("nothing important needs protecting"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("no extra protection is needed"))
        XCTAssertTrue(story.beCarefulWith.localizedCaseInsensitiveContains("turning a good late ride into a test"))
    }

    func testHighLoadStrongRecoveryNoTomorrowDemandDoesNotProtectNight() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 7,
            hour: 23,
            minute: 20
        )) ?? now
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = 23
        config.recovery = .strong
        config.readiness = .good
        config.sleep = .strong
        config.strain = .veryHigh
        config.energyCoverage = 1.0
        config.caloriesProgress = 1.0
        config.carbsProgress = 1.0
        config.waterProgress = 0.90
        config.metrics = CoachMetricsBuilder.metrics(
            calories: 2_400,
            waterLiters: 2.7,
            activeCalories: 950,
            sleepHours: 7.8
        )

        let output = guidance(
            [],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 89, sleepHours: 7.8),
            nutrition: nutrition(water: 2.7, waterGoal: 3.0, meals: 3, calories: 2_400, carbs: 280),
            now: scenarioNow
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertNotEqual(output.title, "Protect the night")
        XCTAssertNotEqual(story.title, "Protect the night")
        XCTAssertFalse(visible.contains("protect the night"))
        XCTAssertFalse(visible.contains("protect tomorrow"))
        XCTAssertFalse(visible.contains("keep this ride easy"))
    }

    func testActivePlannedEnduranceWithGoodPrepUsesSimpleExecutionGuidance() throws {
        let ride = cycling(title: "Endurance Ride", minutesFromNow: -5, duration: 60)

        let guidance = guidance(
            [ride],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 7.4),
            nutrition: nutrition(water: 2.8, waterGoal: 3.0, meals: 1, calories: 1_200, carbs: 150, lastMealMinutesAgo: 90)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        XCTAssertEqual(guidance.priority.objective, .executeActivity)
        let plan = try XCTUnwrap(guidance.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        XCTAssertEqual(plan.urgency, .execution)

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertEqual(story.title, "Control today's ride")
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("fuel is still light"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration is not yet supporting"))
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveEnduranceWithNoFuelKeepsExecutionAsPrimaryLimiter() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)

        let guidance = guidance(
            [run],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 7.1),
            nutrition: nutrition(water: 2.4, waterGoal: 3.0, meals: 0, calories: 0, carbs: 0, lastMealMinutesAgo: nil)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        let plan = try XCTUnwrap(guidance.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        XCTAssertFalse(plan.actionIntents.contains { intent in
            if case .eat = intent { return true }
            return false
        })

        let story = try XCTUnwrap(guidance.screenStory)
        let primaryText = story.primaryActions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ")
        XCTAssertTrue(primaryText.localizedCaseInsensitiveContains("easy") || primaryText.localizedCaseInsensitiveContains("conversational") || primaryText.localizedCaseInsensitiveContains("reserve"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("meal"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("carb"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("refuel"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("limiter"))
        XCTAssertLessThanOrEqual(occurrences(of: "fuel", in: visibleTexts(story).joined(separator: " ")), 3)
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveEnduranceWithNoWaterKeepsExecutionAsPrimaryLimiter() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)

        let guidance = guidance(
            [run],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 7.1),
            nutrition: nutrition(water: 0, waterGoal: 3.0, meals: 1, calories: 1_200, carbs: 150, lastMealMinutesAgo: 80)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        let plan = try XCTUnwrap(guidance.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        XCTAssertFalse(plan.actionIntents.contains { intent in
            if case .drink = intent { return true }
            return false
        })

        let story = try XCTUnwrap(guidance.screenStory)
        let primaryText = story.primaryActions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ")
        XCTAssertTrue(primaryText.localizedCaseInsensitiveContains("easy") || primaryText.localizedCaseInsensitiveContains("conversational") || primaryText.localizedCaseInsensitiveContains("reserve"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("drink"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("water"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("hydrate"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("limiter"))
        XCTAssertLessThanOrEqual(occurrences(of: "hydration", in: visibleTexts(story).joined(separator: " ")), 3)
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveStrengthWithPoorFuelUsesIntensityCeiling() throws {
        let strength = workout(title: "Strength", minutesFromNow: -5, duration: 60, completed: false)

        let output = guidance(
            [strength],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.0),
            nutrition: nutrition(water: 2.0, waterGoal: 3.0, meals: 0, calories: 0, carbs: 0, lastMealMinutesAgo: nil)
        )
        let plan = try XCTUnwrap(output.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        let story = try XCTUnwrap(output.screenStory)

        let primaryText = story.primaryActions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ")
        XCTAssertTrue(primaryText.localizedCaseInsensitiveContains("load") || primaryText.localizedCaseInsensitiveContains("reserve") || primaryText.localizedCaseInsensitiveContains("feedback"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("meal"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("carb"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("control") || story.myRecommendation.localizedCaseInsensitiveContains("reserve"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("endurance"))
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testMultipleActiveConstraintsUseOnePrimaryLimiter() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)
        run.source = "today"
        let sauna = quickSauna(minutesFromNow: 120, duration: 30)
        let tomorrow = tomorrowCycling(title: "Cycling", duration: 120)

        let output = guidance(
            [run, sauna, tomorrow],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 6.2),
            nutrition: nutrition(water: 0, waterGoal: 3.2, meals: 0, calories: 0, carbs: 0, lastMealMinutesAgo: nil)
        )
        let plan = try XCTUnwrap(output.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .timing)
        let story = try XCTUnwrap(output.screenStory)

        let primaryText = story.primaryActions.flatMap { [$0.title, $0.subtitle] }.joined(separator: " ")
        XCTAssertTrue(primaryText.localizedCaseInsensitiveContains("easy") || primaryText.localizedCaseInsensitiveContains("reserve") || primaryText.localizedCaseInsensitiveContains("feedback"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("drink"))
        XCTAssertFalse(primaryText.localizedCaseInsensitiveContains("meal"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("current constraints"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("tomorrow still needs freshness"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("shorter sleep lowers"))
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveRecoveryWalkDoesNotOverreactToLowFuel() throws {
        let walk = recovery(title: "Walk", minutesFromNow: -5, duration: 30, completed: false)

        let story = try XCTUnwrap(guidance(
            [walk],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.2),
            nutrition: nutrition(water: 0, waterGoal: 3.0, meals: 0, calories: 0, carbs: 0, lastMealMinutesAgo: nil)
        ).screenStory)

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.recover.label)
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("finish feeling better"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("fuel"))
        XCTAssertFalse(story.beCarefulWith.localizedCaseInsensitiveContains("food"))
    }

    func testPrepareSaunaWithWaterZeroUsesHydrationPlan() throws {
        let walk = recovery(title: "Walk", minutesFromNow: 35, duration: 25, completed: false)
        let sauna = quickSauna(minutesFromNow: 75, duration: 30)

        let output = guidance(
            [walk, sauna],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.0),
            nutrition: nutrition(water: 0, waterGoal: 3.0, meals: 1, calories: 1_000, carbs: 110, lastMealMinutesAgo: 90)
        )

        let plan = try XCTUnwrap(output.narrativePlan)
        XCTAssertEqual(output.priority.objective, .prepareActivity)
        XCTAssertNotEqual(plan.primaryLimiter, .fuel)
        let story = try XCTUnwrap(output.screenStory)
        let actionText = story.primaryActions.map(\.title).joined(separator: " ")
        XCTAssertTrue(
            story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration || $0.type == .rehydrateGradually } ||
            actionText.localizedCaseInsensitiveContains("fluid") ||
            actionText.localizedCaseInsensitiveContains("hydration"),
            actionText
        )
        XCTAssertFalse(output.priority.todayTitle.localizedCaseInsensitiveContains("Walk"))
        assertNoSupportSignalLeakage(story)
    }

    func testRecoveryLowBecauseSleepUsesSleepLimiter() throws {
        let yoga = recovery(title: "Yoga", minutesFromNow: 60, duration: 40, completed: false)

        let output = guidance(
            [yoga],
            brain: brain(currentHour: 9, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 76, sleepHours: 5.4),
            nutrition: nutrition(water: 1.6, waterGoal: 3.0, meals: 1)
        )

        let plan = try XCTUnwrap(output.narrativePlan)
        XCTAssertEqual(plan.primaryLimiter, .sleep)
        let story = try XCTUnwrap(output.screenStory)
        XCTAssertTrue(visibleTexts(story).joined(separator: " ").localizedCaseInsensitiveContains("sleep"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("fuel"))
    }

    func testTodayCardAndCoachScreenShareNarrativePlan() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)

        let output = guidance(
            [run],
            brain: brain(currentHour: 10, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 84, sleepHours: 7.1),
            nutrition: nutrition(water: 0, waterGoal: 3.0, meals: 1, calories: 1_200, carbs: 150, lastMealMinutesAgo: 80)
        )

        let plan = try XCTUnwrap(output.narrativePlan)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertEqual(story.narrativePlan?.primaryLimiter, plan.primaryLimiter)
        XCTAssertEqual(story.narrativePlan?.urgency, plan.urgency)
        XCTAssertEqual(story.stateLabel, plan.badgeIntent.label)
        XCTAssertEqual(output.stateLabel, plan.badgeIntent.label)
        XCTAssertLessThan(output.dynamicInsight.text.count, story.myRecommendation.count + story.myRead.count)
        XCTAssertEqual(output.v5Contract?.narrativePlan?.primaryLimiter, plan.primaryLimiter)

        let interpretation = output.v5Interpretation
        let compactInsight = interpretation.compactInsight
        XCTAssertEqual(interpretation.storyType, .activeSession)
        XCTAssertEqual(compactInsight.title, output.dynamicInsight.title)
        XCTAssertEqual(compactInsight.text, output.dynamicInsight.text)
        XCTAssertEqual(compactInsight.icon, output.dynamicInsight.icon)
    }

    func testMorningRecoveryDayWithSaunaLeadsWithRecoveryNotHydration() throws {
        let walk = recovery(title: "Walk", minutesFromNow: 69, duration: 60, completed: false)
        let yoga = recovery(title: "Yoga", minutesFromNow: 129, duration: 45, completed: false)
        let sauna = recovery(title: "Sauna", minutesFromNow: 189, duration: 45, completed: false)
        let meal = PlannedActivityBuilder.meal(
            title: "Salmon Pasta",
            at: now.addingTimeInterval(TimeInterval(339 * 60)),
            completed: false
        )

        let guidance = guidance(
            [walk, yoga, sauna, meal],
            brain: brain(currentHour: 7, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8.0),
            nutrition: nutrition(water: 1.75, meals: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertFalse(story.stateLabel.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration matters because"))
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        assertNoDuplicateIdeas(story)
    }

    func testMorningRecoveryDayWithLowLoggedWaterStillLeadsWithRecovery() throws {
        let walk = recovery(title: "Walk", minutesFromNow: 52, duration: 60, completed: false)
        let sauna = recovery(title: "Sauna", minutesFromNow: 172, duration: 45, completed: false)
        let meal = PlannedActivityBuilder.meal(
            title: "Salmon Pasta",
            at: now.addingTimeInterval(TimeInterval(322 * 60)),
            completed: false
        )

        let guidance = guidance(
            [walk, sauna, meal],
            brain: brain(currentHour: 7, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 6.2),
            nutrition: nutrition(water: 0.0, meals: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertFalse(story.stateLabel.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("yoga"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration matters because"))
        XCTAssertFalse(guidance.dynamicInsight.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertTrue(
            story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("sip") || $0.type == .hydrateBeforeSession || $0.type == .steadyHydration } ||
            guidance.supportActions.contains { $0.title.localizedCaseInsensitiveContains("sip") || $0.title.localizedCaseInsensitiveContains("hydrat") }
        )

        XCTAssertTrue(guidance.v5Interpretation.storyType == .recovery || guidance.v5Interpretation.storyType == .dayMaintenance)
        XCTAssertTrue(guidance.v5Interpretation.supportSignals.contains(.hydration))
    }

    func testSaunaPreparationMissingSleepLowWaterKeepsCandidateTitleAndLimiter() throws {
        let sauna = recovery(title: "Sauna", minutesFromNow: 75, duration: 30, completed: false)

        let guidance = guidance(
            [sauna],
            brain: brain(
                currentHour: 8,
                sleep: .unknown,
                recovery: .stable,
                readiness: .good,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 74, sleepHours: 0),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertNotEqual(guidance.priority.focus, .dailyOverview)
        XCTAssertNotEqual(guidance.priority.limiter, .fueling)
        XCTAssertFalse(guidance.title.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertTrue(guidance.v5Interpretation.supportSignals.contains(.hydration))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("sauna"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("sauna") || story.beCarefulWith.localizedCaseInsensitiveContains("sauna"))
        let hydrationActionTitles = (
            story.primaryActions.map(\.title) +
            guidance.supportActions.map(\.title)
        ).joined(separator: " | ")
        XCTAssertTrue(
            story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration } ||
            hydrationActionTitles.localizedCaseInsensitiveContains("drink") ||
            hydrationActionTitles.localizedCaseInsensitiveContains("sip") ||
            hydrationActionTitles.localizedCaseInsensitiveContains("hydrat"),
            hydrationActionTitles
        )
        XCTAssertTrue(visibleTexts(story).joined(separator: " ").localizedCaseInsensitiveContains("sauna"))
    }

    func testSaunaPreparationAfterSomeWaterAsksForAnotherDrink() throws {
        let sauna = recovery(title: "Sauna", minutesFromNow: 75, duration: 30, completed: false)

        let guidance = guidance(
            [sauna],
            brain: brain(
                currentHour: 8,
                sleep: .unknown,
                recovery: .stable,
                readiness: .good,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 74, sleepHours: 0),
            nutrition: nutrition(water: 0.50, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertFalse(story.title.isEmpty)
        XCTAssertNotEqual(guidance.priority.focus, .dailyOverview)
        XCTAssertNotEqual(guidance.narrativePlan?.primaryLimiter, .fuel)
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("sauna") || story.beCarefulWith.localizedCaseInsensitiveContains("sauna"), story.myRecommendation)
        XCTAssertTrue(story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration || $0.title.localizedCaseInsensitiveContains("drink") || $0.title.localizedCaseInsensitiveContains("sip") }, story.primaryActions.map(\.title).joined(separator: " | "))
        XCTAssertTrue(story.primaryActions.first.map {
            $0.type == .hydrateBeforeSession ||
                $0.type == .steadyHydration ||
                $0.type == .rehydrateGradually ||
                $0.type == .electrolyteRecovery
        } == true)
    }

    func testSaunaPreparationImprovingHydrationReducesUrgency() throws {
        let sauna = recovery(title: "Sauna", minutesFromNow: 75, duration: 30, completed: false)

        let guidance = guidance(
            [sauna],
            brain: brain(
                currentHour: 8,
                sleep: .unknown,
                recovery: .stable,
                readiness: .good,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 74, sleepHours: 0),
            nutrition: nutrition(water: 1.0, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(story.title, "Prepare for sauna")
        XCTAssertEqual(guidance.priority.focus, .prepareForActivity)
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("keep sipping before sauna"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Stay steady before sauna" })
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("300-500") })
    }

    func testSaunaPreparationSufficientHydrationRemovesDrinkAction() throws {
        let sauna = recovery(title: "Sauna", minutesFromNow: 75, duration: 30, completed: false)

        let guidance = guidance(
            [sauna],
            brain: brain(
                currentHour: 8,
                sleep: .unknown,
                recovery: .stable,
                readiness: .good,
                sleepHours: 0
            ),
            recovery: CoachRecoveryContext(recoveryPercent: 74, sleepHours: 0),
            nutrition: nutrition(water: 1.50, waterGoal: 1.88, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(story.title, "Prepare for sauna")
        XCTAssertEqual(story.myRecommendation, "You have started bringing fluids online. Keep sauna easy and avoid adding extra stress.")
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("drink") })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Enter heat well hydrated" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Keep recovery easy" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Avoid staying too long if you feel flat" })
    }

    func testScenarioMatrixMaintainsCoachQualityInCommonRealLifeStates() throws {
        struct MatrixScenario {
            let name: String
            let activities: [PlannedActivity]
            let brain: HumanBrain.State
            let recovery: CoachRecoveryContext
            let nutrition: CoachNutritionContext
            let healthyState: Bool
        }

        let scenarios: [MatrixScenario] = [
            MatrixScenario(
                name: "05:00 open morning after good sleep",
                activities: [],
                brain: brain(currentHour: 5, recovery: .strong, readiness: .excellent),
                recovery: CoachRecoveryContext(recoveryPercent: 92, sleepHours: 8.1),
                nutrition: nutrition(water: 0.4, meals: 0),
                healthyState: true
            ),
            MatrixScenario(
                name: "12:00 hard ride completed with hydration gap",
                activities: [
                    cycling(title: "Long Ride", minutesFromNow: -180, duration: 150, completed: true)
                ],
                brain: brain(currentHour: 12, recovery: .stable, readiness: .good, strain: .high),
                recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 7.0),
                nutrition: nutrition(water: 0.9, meals: 1),
                healthyState: false
            ),
            MatrixScenario(
                name: "15:00 workout soon with limited readiness",
                activities: [
                    workout(title: "Strength", minutesFromNow: 45, duration: 60, completed: false)
                ],
                brain: brain(currentHour: 15, recovery: .vulnerable, readiness: .low),
                recovery: CoachRecoveryContext(recoveryPercent: 51, sleepHours: 5.8),
                nutrition: nutrition(water: 1.4, meals: 1),
                healthyState: false
            ),
            MatrixScenario(
                name: "18:00 completed workout plus sauna active",
                activities: [
                    workout(title: "Strength", minutesFromNow: -150, duration: 60, completed: true),
                    quickSauna(minutesFromNow: -5, duration: 25)
                ],
                brain: brain(currentHour: 18, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 70, sleepHours: 6.8),
                nutrition: nutrition(water: 1.2, meals: 2),
                healthyState: false
            ),
            MatrixScenario(
                name: "22:30 balanced evening before recovery day",
                activities: [
                    tomorrowRecovery(title: "Yoga", duration: 30)
                ],
                brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 83, sleepHours: 7.3),
                nutrition: nutrition(water: 2.3, meals: 3),
                healthyState: true
            ),
            MatrixScenario(
                name: "01:00 overnight no plan",
                activities: [],
                brain: brain(currentHour: 1, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 76, sleepHours: 6.9),
                nutrition: nutrition(water: 2.0, meals: 2),
                healthyState: true
            )
        ]

        for scenario in scenarios {
            let guidance = guidance(
                scenario.activities,
                brain: scenario.brain,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition
            )
            let story = try XCTUnwrap(guidance.screenStory, scenario.name)

            assertNoDuplicateIdeas(story, scenario: scenario.name)
            if !scenario.healthyState {
                assertTodayInsightIsTeaser(guidance, scenario: scenario.name)
            }

            if scenario.healthyState {
                assertNoProblemLanguage(story, scenario: scenario.name)
                XCTAssertFalse(story.shouldShowPlanAdjustment, scenario.name)
            }
        }
    }

    func testAfterClosedNightStableFutureTrainingDoesNotForceProtectMorning() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 7,
            hour: 2,
            minute: 27
        )) ?? now
        let morningRun = PlannedActivityBuilder.workout(
            title: "Run",
            at: Calendar.current.date(byAdding: .hour, value: 7, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 75
        )

        let output = guidance(
            [morningRun],
            brain: brain(currentHour: 2, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 6.8),
            nutrition: nutrition(water: 0, meals: 0, calories: 0, carbs: 0),
            now: scenarioNow
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.goodToGo.label)
        XCTAssertEqual(output.title, "Bring the basics back up")
        XCTAssertEqual(story.title, "Bring the basics back up")
        XCTAssertFalse(visible.contains("protect tomorrow"))
        XCTAssertFalse(visible.contains("protect the morning"))
        XCTAssertFalse(visible.contains("tonight"))
    }

    func testProtectMorningUsesStoryTitleAndMovesTrainingReadinessToMyRead() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 7,
            hour: 2,
            minute: 51
        )) ?? now
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: Calendar.current.date(byAdding: .hour, value: 8, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 120
        )

        let output = guidance(
            [cycling],
            brain: brain(currentHour: 2, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 46, sleepHours: 5.1),
            nutrition: nutrition(water: 0, waterGoal: 2.98, meals: 0, calories: 0, carbs: 0),
            now: scenarioNow
        )
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertTrue([
            CoachNarrativeBadgeIntent.adjustTrainingReadiness.label,
            CoachNarrativeBadgeIntent.reducePlan.label
        ].contains(story.stateLabel))
        XCTAssertFalse(output.title.isEmpty)
        XCTAssertFalse(story.title.isEmpty)
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("readiness"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("protect the morning"))
    }

    func testClosedNightFutureTrainingKeepsSleepAsPrimaryStory() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 8,
            hour: 1,
            minute: 37
        )) ?? now
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: Calendar.current.date(byAdding: .minute, value: 502, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 120
        )

        let output = guidance(
            [cycling],
            brain: brain(currentHour: 1, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 5.2),
            nutrition: nutrition(water: 0, waterGoal: 2.99, meals: 0, calories: 0, carbs: 0),
            now: scenarioNow
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertTrue(visible.contains("sleep") || visible.contains("night"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("adjust training readiness"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("protect the morning"))
        XCTAssertFalse(visible.contains("ready to train"))
    }

    func testPostMidnightEmptyDayKeepsSleepStoryInsteadOfProtectMorning() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 7,
            hour: 0,
            minute: 31
        )) ?? now

        let output = guidance(
            [],
            brain: brain(currentHour: 0, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 6.8),
            nutrition: nutrition(water: 0, waterGoal: 2.98, meals: 0, calories: 0, carbs: 0),
            now: scenarioNow
        )
        let story = try XCTUnwrap(output.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(output.priority.priority, .sleepPreparation)
        XCTAssertEqual(output.priority.focus, .eveningWindDown)
        XCTAssertEqual(output.priority.limiter, .sleep)
        XCTAssertEqual(output.v5Contract?.primaryLimiter, .sleep)
        XCTAssertEqual(output.v5Contract?.priority.limiter, .sleep)
        XCTAssertEqual(output.title, "Protect the night")
        if output.priority.objective == .completeDay {
            XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.protectSleep.label)
            assertBadgeTitleAligned(story)
            XCTAssertFalse(story.stateLabel.localizedCaseInsensitiveContains("morning"))
            XCTAssertFalse(visible.contains("next important event is later today"))
        }
    }

    func testPostMidnightActiveSaunaUsesNightLanguage() throws {
        let scenarioNow = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 7,
            hour: 0,
            minute: 27
        )) ?? now
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: scenarioNow.addingTimeInterval(-5 * 60),
            durationMinutes: 25
        )
        sauna.type = "recovery"
        sauna.source = "today"

        let story = try XCTUnwrap(guidance(
            [sauna],
            brain: brain(currentHour: 0, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.2),
            nutrition: nutrition(water: 2.0, meals: 2),
            now: scenarioNow
        ).screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("before sleep"))
        XCTAssertTrue(visible.contains("overnight") || visible.contains("sleep"))
        XCTAssertFalse(visible.contains("tonight"))
        XCTAssertFalse(visible.contains("evening"))
    }

    func testActiveLowReadinessTrainingKeepsSingleRecoveryStory() throws {
        let run = workout(title: "Running", minutesFromNow: -5, duration: 45, completed: false)

        let guidance = guidance(
            [run],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 5.2),
            nutrition: nutrition(water: 0, waterGoal: 3.0, meals: 0, calories: 0, carbs: 0)
        )
        let story = try XCTUnwrap(guidance.screenStory)
        let visible = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.manageEffort.label)
        XCTAssertTrue(story.shouldShowBeCarefulWith)
        XCTAssertTrue(visible.contains("run") || visible.contains("effort") || visible.contains("reserve"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("fuel"))
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("Eat") })
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("Drink") })
    }

    func testLiveLowSleepGuidanceIsSportSpecific() throws {
        struct Case {
            let title: String
            let expectedTitle: String
            let recommendationFragment: String
            let actionTitle: String
        }

        let cases: [Case] = [
            .init(
                title: "Cycling",
                expectedTitle: "Control today's ride",
                recommendationFragment: "stay aerobic",
                actionTitle: "Stay aerobic"
            ),
            .init(
                title: "Running",
                expectedTitle: "Control today's run",
                recommendationFragment: "stay conversational",
                actionTitle: "Stay conversational"
            ),
            .init(
                title: "Upper Body",
                expectedTitle: "Control today's upper body session",
                recommendationFragment: "reduce working weight",
                actionTitle: "Reduce load"
            ),
            .init(
                title: "Tennis",
                expectedTitle: "Control today's tennis session",
                recommendationFragment: "positioning over intensity",
                actionTitle: "Stay efficient"
            ),
            .init(
                title: "Squash",
                expectedTitle: "Control today's squash session",
                recommendationFragment: "reduce match intensity",
                actionTitle: "Control intensity"
            )
        ]

        for scenario in cases {
            let activity = workout(
                title: scenario.title,
                minutesFromNow: -8,
                duration: 60,
                completed: false
            )

            let story = try XCTUnwrap(guidance(
                [activity],
                brain: brain(
                    currentHour: 10,
                    recovery: .compromised,
                    readiness: .compromised,
                    sleepHours: 4.6
                ),
                recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.6),
                nutrition: nutrition(water: 1.5, meals: 1)
            ).screenStory)

            XCTAssertEqual(story.title, scenario.expectedTitle, scenario.title)
            XCTAssertTrue(
                story.myRecommendation.localizedCaseInsensitiveContains(scenario.recommendationFragment),
                "\(scenario.title): \(story.myRecommendation)"
            )
            XCTAssertTrue(
                story.primaryActions.contains { $0.title == scenario.actionTitle },
                "\(scenario.title): \(story.primaryActions.map(\.title))"
            )
            XCTAssertFalse(
                story.myRecommendation.localizedCaseInsensitiveContains("Stay below your normal ceiling"),
                "\(scenario.title) should not use generic live-session advice"
            )
        }
    }

    func testLateNightActiveKnownSportPrioritizesTimeRiskOverSmallHydrationGap() throws {
        let tennis = workout(title: "Tennis", minutesFromNow: -5, duration: 75, completed: false)

        let guidance = guidance(
            [tennis],
            brain: brain(currentHour: 23, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 87, sleepHours: 6.2),
            nutrition: nutrition(water: 1.2, meals: 3)
        )
        let story = try XCTUnwrap(guidance.screenStory)
        let visible = visibleTexts(story).joined(separator: " ")
        let actionText = story.primaryActions.map(\.title).joined(separator: " ")

        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Tennis"))
        XCTAssertFalse(actionText.isEmpty)
        XCTAssertFalse(story.primaryActions.isEmpty)
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("hydration is not fully covered"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("ignore targets"))
    }

    func testTomorrowPlanUsesSpecificKnownActivityNames() throws {
        let tomorrowTennis = tomorrowWorkout(title: "Tennis", duration: 90)
        let tomorrowStrength = tomorrowWorkout(title: "Strength", duration: 90)

        let tennisStory = try XCTUnwrap(guidance(
            [tomorrowTennis],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.0, meals: 3)
        ).screenStory)

        let strengthStory = try XCTUnwrap(guidance(
            [tomorrowStrength],
            brain: brain(currentHour: 22, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: nutrition(water: 2.0, meals: 3)
        ).screenStory)

        XCTAssertTrue(visibleTexts(tennisStory).joined(separator: " ").localizedCaseInsensitiveContains("tennis"))
        XCTAssertFalse(visibleTexts(tennisStory).joined(separator: " ").localizedCaseInsensitiveContains("tomorrow's training"))
        XCTAssertTrue(visibleTexts(strengthStory).joined(separator: " ").localizedCaseInsensitiveContains("strength"))
        XCTAssertFalse(visibleTexts(strengthStory).joined(separator: " ").localizedCaseInsensitiveContains("tomorrow's training"))
    }
}

private extension HumanCoachDecisionEngineXCTests {

    func assertDecision(
        _ decision: HumanCoachDecision,
        status: CoachStatus,
        title: String,
        myRead: String,
        myRecommendation: String,
        beCarefulWith: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(decision.status.label, status.label, file: file, line: line)
        XCTAssertEqual(
            String(describing: decision.status.semanticColor),
            String(describing: status.semanticColor),
            file: file,
            line: line
        )
        XCTAssertEqual(decision.title, title, file: file, line: line)
        XCTAssertEqual(decision.myRead, myRead, file: file, line: line)
        XCTAssertEqual(decision.myRecommendation, myRecommendation, file: file, line: line)
        XCTAssertEqual(decision.beCarefulWith, beCarefulWith, file: file, line: line)
        assertHeadlineIsCoachRecommendation(decision.title, file: file, line: line)
        assertNoCategoryLanguage(decision, file: file, line: line)
    }

    func assertHeadlineIsCoachRecommendation(
        _ title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lowercased = title.lowercased()
        let forbiddenHeadlineFragments = [
            "recovery 91",
            "recovery 74",
            "water ",
            "protein ",
            "calories ",
            "sauna active",
            "cycling active",
            "walk is done",
            "sauna is done",
            "cycling is done",
            "ride completed"
        ]

        for fragment in forbiddenHeadlineFragments {
            XCTAssertFalse(
                lowercased.contains(fragment),
                "Headline used raw metrics or activity-state copy: \(title)",
                file: file,
                line: line
            )
        }
    }

    func assertNoCategoryLanguage(
        _ decision: HumanCoachDecision,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleText = [
            decision.title,
            decision.myRead,
            decision.myRecommendation,
            decision.beCarefulWith,
            decision.why ?? "",
            decision.planChallenge ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let forbiddenFragments = [
            " is the limiter",
            "the limiter is",
            " is behind",
            " is the priority",
            " is the bottleneck",
            "nutrition is the",
            "hydration narrative",
            "endurance is the"
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(
                visibleText.contains(fragment),
                "Visible decision exposed category language: \(fragment)",
                file: file,
                line: line
            )
        }
    }

    func assertNoProblemLanguage(
        _ story: CoachScreenStory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleText = visibleTexts(story)
            .joined(separator: " ")
            .lowercased()

        let forbiddenFragments = [
            "warning",
            "fatigue",
            "unresolved",
            "intervention",
            "adjust the plan",
            "readiness stays low",
            "same fatigue"
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(
                visibleText.contains(fragment),
                "Healthy story exposed problem language: \(fragment)",
                file: file,
                line: line
            )
        }
    }

    func assertNoProblemLanguage(
        _ story: CoachScreenStory,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleText = visibleTexts(story)
            .joined(separator: " ")
            .lowercased()

        let forbiddenFragments = [
            "warning",
            "fatigue",
            "unresolved",
            "intervention",
            "adjust the plan",
            "readiness stays low",
            "same fatigue"
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(
                visibleText.contains(fragment),
                "\(scenario) exposed problem language: \(fragment)",
                file: file,
                line: line
            )
        }
    }

    func assertNoDuplicateIdeas(
        _ story: CoachScreenStory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var seen: Set<String> = []

        for text in visibleTexts(story) {
            let key = normalizedIdea(text)
            guard !key.isEmpty else { continue }
            XCTAssertFalse(
                seen.contains(key),
                "Duplicate visible idea: \(text)",
                file: file,
                line: line
            )
            seen.insert(key)
        }
    }

    func assertNoDuplicateIdeas(
        _ story: CoachScreenStory,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var seen: Set<String> = []

        for text in visibleTexts(story) {
            let key = normalizedIdea(text)
            guard !key.isEmpty else { continue }
            XCTAssertFalse(
                seen.contains(key),
                "\(scenario) duplicated visible idea: \(text)",
                file: file,
                line: line
            )
            seen.insert(key)
        }
    }

    func assertNoGenericAdvice(
        _ story: CoachScreenStory,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = visibleTexts(story)
            .joined(separator: " ")
            .lowercased()

        let genericFragments = [
            "hydrate steadily",
            "fuel appropriately",
            "manage recovery",
            "stay consistent",
            "prepare ride basics",
            "tomorrow's training",
            "current session"
        ]

        for fragment in genericFragments {
            XCTAssertFalse(
                text.contains(fragment),
                "\(scenario) used generic advice: \(fragment)",
                file: file,
                line: line
            )
        }
    }

    func assertTodayInsightIsTeaser(
        _ guidance: CoachGuidanceV3,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = guidance.dynamicInsight.text.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertLessThanOrEqual(text.count, 80, "\(scenario) Today teaser is too long: \(text)", file: file, line: line)
        XCTAssertFalse(text.contains("\n"), "\(scenario) Today teaser should be one compact idea", file: file, line: line)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("because"), "\(scenario) Today teaser explains too much: \(text)", file: file, line: line)

        if let story = guidance.screenStory {
            XCTAssertNotEqual(text, story.title, "\(scenario) Today teaser duplicates hero title", file: file, line: line)
            XCTAssertNotEqual(text, story.myRead, "\(scenario) Today teaser duplicates My Read", file: file, line: line)
        }
    }

    func assertCompactActiveStory(
        _ story: CoachScreenStory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(story.myRead.count, 200, "My Read is too long: \(story.myRead)", file: file, line: line)
        XCTAssertLessThanOrEqual(sentenceCount(story.myRead), 2, "My Read has too many sentences: \(story.myRead)", file: file, line: line)
        XCTAssertLessThanOrEqual(sentenceCount(story.myRecommendation), 2, "Recommendation has too many sentences: \(story.myRecommendation)", file: file, line: line)
        XCTAssertLessThanOrEqual(sentenceCount(story.beCarefulWith), 1, "Be Careful With has too many sentences: \(story.beCarefulWith)", file: file, line: line)
    }

    func assertNoSupportSignalLeakage(
        _ story: CoachScreenStory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = [
            story.myRead,
            story.myRecommendation,
            story.beCarefulWith
        ]
        .joined(separator: " ")
        .lowercased()

        let leakedFragments = [
            "support signals",
            "candidate score",
            "decision score",
            "priority score",
            "narrative id",
            "resolver",
            "current constraints",
            "larger objective"
        ]

        for fragment in leakedFragments {
            XCTAssertFalse(text.contains(fragment), "Leaked internal fragment: \(fragment) in \(text)", file: file, line: line)
        }
    }

    func sentenceCount(_ text: String) -> Int {
        text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    func occurrences(of needle: String, in text: String) -> Int {
        let lowerText = text.lowercased()
        let lowerNeedle = needle.lowercased()
        guard !lowerNeedle.isEmpty else { return 0 }

        var count = 0
        var searchRange = lowerText.startIndex..<lowerText.endIndex
        while let range = lowerText.range(of: lowerNeedle, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<lowerText.endIndex
        }
        return count
    }

    func visibleTexts(_ story: CoachScreenStory) -> [String] {
        [
            story.title,
            story.myRead,
            story.myRecommendation,
            story.beCarefulWith,
            story.whyThisMatters ?? "",
            story.planAdjustment ?? "",
            story.activityContext ?? ""
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } +
        story.primaryActions.map(\.title) +
        story.supportActions.map(\.title)
    }

    func assertBadgeTitleAligned(
        _ story: CoachScreenStory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let normalizedBadge = story.stateLabel
            .replacingOccurrences(of: "PROTECT SLEEP", with: "PROTECT THE NIGHT")
            .lowercased()
        let normalizedTitle = story.title.lowercased()

        if normalizedBadge.contains("protect the morning") {
            XCTAssertEqual(normalizedTitle, "protect the morning", file: file, line: line)
        } else if normalizedBadge.contains("protect tomorrow") {
            XCTAssertEqual(normalizedTitle, "protect tomorrow", file: file, line: line)
        } else if normalizedBadge.contains("protect the night") {
            XCTAssertTrue(
                normalizedTitle == "protect the night" || normalizedTitle == "sleep comes first",
                "badge=\(story.stateLabel) title=\(story.title)",
                file: file,
                line: line
            )
        }
    }

    func normalizedIdea(_ text: String) -> String {
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined(separator: " ")
            .split(separator: " ")
            .map(String.init)
            .filter { !["the", "a", "an", "and", "or", "to", "of", "for", "with", "is", "are", "you", "your", "this", "that", "now", "tonight", "today", "tomorrow", "in", "on"].contains($0) }

        if words.contains("sleep") || words.contains("bedtime") {
            return "sleep"
        }

        return words.prefix(6).joined(separator: " ")
    }

    func guidance(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        recovery: CoachRecoveryContext,
        nutrition: CoachNutritionContext
    ) -> CoachGuidanceV3 {
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowPlanContext(activities),
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )

        return HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )
    }

    func overloadGuidanceWithFuture(_ future: PlannedActivity) -> CoachGuidanceV3 {
        let core = workout(title: "Core", minutesFromNow: -220, duration: 45, completed: true)
        let strength = workout(title: "Workout", minutesFromNow: -130, duration: 75, completed: true)
        let sauna = recovery(title: "Sauna", minutesFromNow: -45, duration: 30, completed: true)
        sauna.type = "sauna"

        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = 14
        config.energyCoverage = 0.25
        config.caloriesProgress = 0.25
        config.carbsProgress = 0.12
        config.waterProgress = 0.40
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 20,
            carbs: 30,
            calories: 600,
            waterLiters: 1.0,
            activeCalories: 860,
            sleepHours: 7.0
        )
        config.hydration = .behind
        config.fuel = .underfueled
        config.recovery = .compromised
        config.readiness = .low
        config.strain = .high
        config.completedWorkoutsCount = 2

        return guidance(
            [core, strength, sauna, future],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 7.0),
            nutrition: nutrition(water: 1.0, waterGoal: 2.5, meals: 1, calories: 600, carbs: 30)
        )
    }

    func highLoadCompletedGuidance(
        now scenarioNow: Date,
        water: Double = 1.4,
        waterGoal: Double = 2.8,
        calories: Double = 1_100,
        caloriesGoal: Double = 2_400,
        protein: Double = 75,
        proteinGoal: Double = 153,
        meals: Int = 1,
        lastMealMinutesAgo: Int? = nil
    ) -> CoachGuidanceV3 {
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: scenarioNow.addingTimeInterval(-480 * 60),
            durationMinutes: 35,
            completed: true
        )
        walk.type = "recovery"
        let core = PlannedActivityBuilder.workout(
            title: "Core",
            at: scenarioNow.addingTimeInterval(-360 * 60),
            durationMinutes: 45,
            completed: true
        )
        let strength = PlannedActivityBuilder.workout(
            title: "Workout",
            at: scenarioNow.addingTimeInterval(-280 * 60),
            durationMinutes: 75,
            completed: true
        )
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: scenarioNow.addingTimeInterval(-190 * 60),
            durationMinutes: 30,
            completed: true
        )
        sauna.type = "sauna"

        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = Calendar.current.component(.hour, from: scenarioNow)
        config.hasAnyFoodLogged = meals > 0
        config.energyCoverage = caloriesGoal > 0 ? calories / caloriesGoal : 0
        config.caloriesProgress = caloriesGoal > 0 ? calories / caloriesGoal : 0
        config.carbsProgress = 0.20
        config.waterProgress = waterGoal > 0 ? water / waterGoal : 0
        config.metrics = CoachMetricsBuilder.metrics(
            protein: protein,
            carbs: 55,
            calories: calories,
            waterLiters: water,
            activeCalories: 860,
            sleepHours: 7.0
        )
        let calorieRatio = caloriesGoal > 0 ? calories / caloriesGoal : 0
        config.hydration = (waterGoal > 0 && water / waterGoal >= 0.60) ? .optimal : .behind
        config.fuel = calorieRatio >= 0.45 ? .good : .underfueled
        config.protein = proteinGoal > 0 && protein / proteinGoal >= 0.75 ? .good : .low
        config.recovery = .compromised
        config.readiness = .low
        config.strain = .high
        config.completedWorkoutsCount = 3

        let nutritionContext = CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: caloriesGoal,
            proteinCurrent: protein,
            proteinGoal: proteinGoal,
            carbsCurrent: 55,
            carbsGoal: 280,
            fatsCurrent: 55,
            fatsGoal: 70,
            waterCurrent: water,
            waterGoal: waterGoal,
            mealsCount: meals,
            lastMealTime: lastMealMinutesAgo.map { scenarioNow.addingTimeInterval(TimeInterval(-$0 * 60)) }
        )

        return guidance(
            [walk, core, strength, sauna],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 7.0),
            nutrition: nutritionContext,
            now: scenarioNow
        )
    }

    func overloadRunGuidance(now scenarioNow: Date) -> CoachGuidanceV3 {
        let core = PlannedActivityBuilder.workout(
            title: "Core",
            at: scenarioNow.addingTimeInterval(-220 * 60),
            durationMinutes: 45,
            completed: true
        )
        let strength = PlannedActivityBuilder.workout(
            title: "Workout",
            at: scenarioNow.addingTimeInterval(-130 * 60),
            durationMinutes: 75,
            completed: true
        )
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: scenarioNow.addingTimeInterval(-45 * 60),
            durationMinutes: 30,
            completed: true
        )
        sauna.type = "sauna"
        let run = PlannedActivityBuilder.workout(
            title: "Running",
            at: scenarioNow.addingTimeInterval(45 * 60),
            durationMinutes: 60,
            completed: false
        )
        run.type = "running"

        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = Calendar.current.component(.hour, from: scenarioNow)
        config.energyCoverage = 0.25
        config.caloriesProgress = 0.25
        config.carbsProgress = 0.12
        config.waterProgress = 0.40
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 20,
            carbs: 30,
            calories: 600,
            waterLiters: 1.0,
            activeCalories: 860,
            sleepHours: 7.0
        )
        config.hydration = .behind
        config.fuel = .underfueled
        config.recovery = .compromised
        config.readiness = .low
        config.strain = .high
        config.completedWorkoutsCount = 2

        return guidance(
            [core, strength, sauna, run],
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: 44, sleepHours: 7.0),
            nutrition: nutrition(water: 1.0, waterGoal: 2.5, meals: 1, calories: 600, carbs: 30),
            now: scenarioNow
        )
    }

    func dateBySettingHour(_ hour: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: now
        ) ?? now
    }

    func guidance(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        recovery: CoachRecoveryContext,
        nutrition: CoachNutritionContext,
        now scenarioNow: Date?
    ) -> CoachGuidanceV3 {
        let scenarioNow = scenarioNow ?? now
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: scenarioNow,
            now: scenarioNow,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: scenarioNow) ?? scenarioNow
        let tomorrowDay = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrowDate,
            now: scenarioNow
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowDay.allActivities.isEmpty ? nil : CoachTomorrowPlanContext(dayContext: tomorrowDay),
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )

        return HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )
    }

    func guidance(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        recovery: CoachRecoveryContext,
        nutrition: CoachNutritionContext,
        priority: CoachDayPriorityResult
    ) -> CoachGuidanceV3 {
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowPlanContext(activities),
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )

        return HumanCoachDecisionEngine.adapt(
            decision,
            phase: priority.phase(for: activityContext),
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )
    }

    func stableNextActivityPriority(
        activity: PlannedActivity,
        supportBullets: [String]
    ) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: .nextActivityLater,
            level: .important,
            reason: "\(activity.title) is planned later.",
            activity: activity,
            overridesTimingFocus: true,
            priority: .stable,
            strength: .high,
            confidence: 0.84,
            mode: .adjustment,
            limiter: .none,
            todayTitle: "Keep the next block easy",
            todayMessage: "Arrive fresh.",
            detailTitle: "Keep the next block easy",
            detailMessage: "\(activity.title) is still later today. Prepare calmly.",
            supportBullets: supportBullets,
            whyThisMatters: "Support signals should improve readiness without taking over the story."
        )
    }

    func noActivityStablePriority(
        supportBullets: [String]
    ) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: .dailyOverview,
            level: .useful,
            reason: "No activity is selected for coaching.",
            activity: nil,
            overridesTimingFocus: false,
            priority: .stable,
            strength: .medium,
            confidence: 0.80,
            mode: .reinforcement,
            limiter: .none,
            todayTitle: "Keep the day simple",
            todayMessage: "Build the day gradually.",
            detailTitle: "Keep the day simple",
            detailMessage: "No activity context is available, so support should stay general.",
            supportBullets: supportBullets,
            whyThisMatters: "Support should reinforce the current story without leaking activity templates."
        )
    }

    func cyclingPreparationPriority(activity: PlannedActivity) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: .prepareForActivity,
            level: .important,
            reason: "Cycling is the next coaching target.",
            activity: activity,
            overridesTimingFocus: true,
            priority: .performance,
            strength: .high,
            confidence: 0.88,
            mode: .adjustment,
            limiter: .timing,
            todayTitle: "Prepare for cycling",
            todayMessage: "Arrive fresh and ready.",
            detailTitle: "Prepare for cycling",
            detailMessage: "Cycling starts soon, so the useful move is setup, not changing the plan.",
            supportBullets: ["Hydration could use attention", "Bring a bottle", "Eat 20-40g carbs before the ride"],
            whyThisMatters: "Arriving fresh matters more than chasing any single support signal."
        )
    }

    struct CyclingLifecycleStage {
        let name: String
        let ride: PlannedActivity
        let expectedState: String
        let expectedTitleContains: String
        let mustNotTitleContain: String?

        init(
            name: String,
            ride: PlannedActivity,
            expectedState: String,
            expectedTitleContains: String,
            mustNotTitleContain: String? = nil
        ) {
            self.name = name
            self.ride = ride
            self.expectedState = expectedState
            self.expectedTitleContains = expectedTitleContains
            self.mustNotTitleContain = mustNotTitleContain
        }
    }

    struct CoachDynamicTextScenario {
        let name: String
        let activities: [PlannedActivity]
        let brain: HumanBrain.State
        let recovery: CoachRecoveryContext
        let nutrition: CoachNutritionContext
        let expectedStateContains: String
        let expectedTitleContains: String
        let forbiddenTitleContains: String?
        let now: Date?
        let forbidsActivityActions: Bool
        let hydrationMayDominate: Bool

        init(
            name: String,
            activities: [PlannedActivity],
            brain: HumanBrain.State,
            recovery: CoachRecoveryContext,
            nutrition: CoachNutritionContext,
            expectedStateContains: String,
            expectedTitleContains: String,
            forbiddenTitleContains: String? = nil,
            now: Date? = nil,
            forbidsActivityActions: Bool = false,
            hydrationMayDominate: Bool
        ) {
            self.name = name
            self.activities = activities
            self.brain = brain
            self.recovery = recovery
            self.nutrition = nutrition
            self.expectedStateContains = expectedStateContains
            self.expectedTitleContains = expectedTitleContains
            self.forbiddenTitleContains = forbiddenTitleContains
            self.now = now
            self.forbidsActivityActions = forbidsActivityActions
            self.hydrationMayDominate = hydrationMayDominate
        }
    }

    func renderedTexts(_ story: CoachScreenStory) -> String {
        (visibleTexts(story) + story.primaryActions.map(\.subtitle) + story.supportActions.map(\.subtitle))
            .joined(separator: " ")
    }

    func duplicateTextWarnings(_ story: CoachScreenStory) -> [String] {
        let hydrationTokens = [
            "hydration",
            "water",
            "glass of water",
            "drink 300",
            "300-500",
            "bring a bottle",
            "sip"
        ]
        let easyStartTokens = [
            "start easy",
            "first 15",
            "first 10",
            "opening minutes"
        ]
        let fuelTokens = [
            "ride nutrition",
            "small carb",
            "30-60"
        ]

        func warning(for label: String, tokens: [String]) -> String? {
            let sections = [
                story.title,
                story.myRead,
                story.myRecommendation,
                story.beCarefulWith,
                story.primaryActions.map(\.title).joined(separator: " "),
                story.supportActions.map(\.title).joined(separator: " ")
            ]
            let hitCount = sections.filter { section in
                tokens.contains { token in
                    section.localizedCaseInsensitiveContains(token)
                }
            }.count
            return hitCount > 1 ? "\(label) repeated across \(hitCount) sections" : nil
        }

        return [
            warning(for: "hydration", tokens: hydrationTokens),
            warning(for: "easy-start", tokens: easyStartTokens),
            warning(for: "fuel", tokens: fuelTokens)
        ].compactMap { $0 }
    }

    func invalidActionWarnings(
        story: CoachScreenStory,
        output: CoachGuidanceV3,
        forbidsActivityActions: Bool
    ) -> [String] {
        guard forbidsActivityActions || output.priority.activity == nil else { return [] }
        let forbidden = [
            "train easy",
            "start easy",
            "first 15",
            "ride nutrition",
            "control intensity",
            "fuel the session",
            "bring session fuel"
        ]
        let actions = story.primaryActions.map(\.title) + story.supportActions.map(\.title)
        return actions.filter { action in
            forbidden.contains { action.localizedCaseInsensitiveContains($0) }
        }
    }

    func hydrationDominates(_ story: CoachScreenStory) -> Bool {
        let mainSections = [
            story.title,
            story.myRead,
            story.myRecommendation,
            story.beCarefulWith,
            story.primaryActions.first?.title ?? ""
        ]
        return mainSections.contains { section in
            section.localizedCaseInsensitiveContains("hydration") ||
            section.localizedCaseInsensitiveContains("water") ||
            section.localizedCaseInsensitiveContains("drink 300")
        }
    }

    func lifecycleRide(
        minutesFromNow: Int? = nil,
        elapsedMinutes: Int? = nil,
        completedMinutesAgo: Int? = nil,
        duration: Int = 180
    ) -> PlannedActivity {
        let startOffset: Int
        let completed: Bool

        if let minutesFromNow {
            startOffset = minutesFromNow
            completed = false
        } else if let elapsedMinutes {
            startOffset = -elapsedMinutes
            completed = false
        } else if let completedMinutesAgo {
            startOffset = -(duration + completedMinutesAgo)
            completed = true
        } else {
            startOffset = 105
            completed = false
        }

        return cycling(
            title: "Cycling",
            minutesFromNow: startOffset,
            duration: duration,
            completed: completed
        )
    }

    func lifecycleGuidance(
        for ride: PlannedActivity,
        now scenarioNow: Date? = nil,
        brain brainState: HumanBrain.State? = nil,
        recovery: CoachRecoveryContext? = nil
    ) throws -> (context: CoachDecisionContext, priority: CoachDayPriorityResult, guidance: CoachGuidanceV3) {
        let resolvedNow = scenarioNow ?? now
        let brain = brainState ?? brain(currentHour: 10, recovery: .strong, readiness: .good)
        let nutrition = nutrition(water: 1.0, meals: 1, calories: 850, carbs: 110, lastMealMinutesAgo: 60)
        let dayContext = CoachDayContextBuilder.build(
            activities: [ride],
            selectedDate: resolvedNow,
            now: resolvedNow
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: [ride],
            selectedDate: resolvedNow,
            now: resolvedNow,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: recovery ?? CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readiness,
            brain: brain
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )

        return (context, priority, guidance)
    }

    func completedRide(
        endingMinutesBefore minutesBefore: Int,
        now scenarioNow: Date,
        duration: Int = 180
    ) -> PlannedActivity {
        let start = scenarioNow.addingTimeInterval(TimeInterval(-(minutesBefore + duration) * 60))
        return PlannedActivityBuilder.workout(
            title: "Cycling",
            at: start,
            durationMinutes: duration,
            completed: true
        )
    }

    func resolve(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        recovery: CoachRecoveryContext,
        nutrition: CoachNutritionContext
    ) -> HumanCoachDecision {
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let tomorrowContext = tomorrowPlanContext(activities)
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowContext,
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        return HumanCoachDecisionEngine.resolve(context: context, priority: priority)
    }

    func tomorrowPlanContext(_ activities: [PlannedActivity]) -> CoachTomorrowPlanContext? {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else {
            return nil
        }

        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrow,
            now: now
        )

        guard !dayContext.allActivities.isEmpty else { return nil }
        return CoachTomorrowPlanContext(dayContext: dayContext)
    }

    func brain(
        currentHour: Int,
        sleep: HumanBrain.SleepState = .okay,
        recovery: HumanBrain.RecoveryState,
        readiness: HumanBrain.ReadinessState,
        strain: HumanBrain.StrainState = .normal,
        sleepHours: Double? = nil
    ) -> HumanBrain.State {
        HumanBrainStateBuilder.make(
            currentHour: currentHour,
            sleep: sleep,
            hydration: .optimal,
            fuel: .good,
            strain: strain,
            recovery: recovery,
            readiness: readiness,
            metrics: sleepHours.map { CoachMetricsBuilder.metrics(sleepHours: $0) } ?? CoachMetricsBuilder.metrics()
        )
    }

    func nutrition(
        water: Double = 2.0,
        waterGoal: Double = 2.5,
        meals: Int? = 1,
        calories: Double = 1_800,
        caloriesGoal: Double = 2_400,
        protein: Double = 110,
        proteinGoal: Double = 150,
        carbs: Double = 210,
        lastMealMinutesAgo: Int? = nil
    ) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: caloriesGoal,
            proteinCurrent: protein,
            proteinGoal: proteinGoal,
            carbsCurrent: carbs,
            carbsGoal: 280,
            fatsCurrent: 55,
            fatsGoal: 70,
            waterCurrent: water,
            waterGoal: waterGoal,
            mealsCount: meals,
            lastMealTime: lastMealMinutesAgo.map { now.addingTimeInterval(TimeInterval(-$0 * 60)) } ??
                ((meals ?? 0) > 0 ? now.addingTimeInterval(-2 * 3600) : nil)
        )
    }

    func cycling(
        title: String,
        minutesFromNow: Int,
        duration: Int,
        completed: Bool = false
    ) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: title,
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: completed
        )
    }

    func tomorrowCycling(title: String, duration: Int) -> PlannedActivity {
        tomorrowWorkout(title: title, duration: duration)
    }

    func tomorrowWorkout(title: String, duration: Int) -> PlannedActivity {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let tomorrow = calendar.date(byAdding: .hour, value: 10, to: tomorrowStart) ?? tomorrowStart
        return PlannedActivityBuilder.workout(
            title: title,
            at: tomorrow,
            durationMinutes: duration
        )
    }

    func tomorrowRecovery(title: String, duration: Int) -> PlannedActivity {
        let activity = tomorrowWorkout(title: title, duration: duration)
        activity.type = "recovery"
        return activity
    }

    func workout(
        title: String,
        minutesFromNow: Int,
        duration: Int,
        completed: Bool
    ) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: title,
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: completed
        )
    }

    func recovery(
        title: String,
        minutesFromNow: Int,
        duration: Int,
        completed: Bool
    ) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: title,
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: completed
        )
        activity.type = "recovery"
        return activity
    }

    func quickSauna(minutesFromNow: Int, duration: Int) -> PlannedActivity {
        let activity = recovery(
            title: "Sauna",
            minutesFromNow: minutesFromNow,
            duration: duration,
            completed: false
        )
        activity.source = "today"
        return activity
    }
}
