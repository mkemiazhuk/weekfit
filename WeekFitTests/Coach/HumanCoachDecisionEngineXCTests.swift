import XCTest
@testable import WeekFit

final class HumanCoachDecisionEngineXCTests: XCTestCase {

    private let now = CoachTestClock.reference
    private let selectedDate = CoachTestClock.reference

    func testScenario1_perfectMorningNothingPlanned() {
        let decision = resolve(
            [],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .excellent),
            recovery: CoachRecoveryContext(recoveryPercent: 91, sleepHours: 8.2),
            nutrition: nutrition(water: 2.0, meals: 1)
        )

        assertDecision(
            decision,
            status: .goodToGo,
            title: "Today is available",
            myRead: "You slept well, recovered well, and there is no important load already shaping the day.",
            myRecommendation: "If you want to train, choose a purposeful session and keep it appropriate for the week.",
            beCarefulWith: "Adding intensity only because the numbers look good."
        )
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
        XCTAssertEqual(story.title, "Bring the basics online")
        XCTAssertEqual(story.myRead, "The day is open and recovery is strong.")
        XCTAssertEqual(story.myRecommendation, "Use the morning to bring food and fluids online.")
        XCTAssertEqual(output.priority.limiter, .none)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, CoachNarrativeLimiter.none)
        XCTAssertNotEqual(renderedState, "HYDRATION FIRST")
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Nothing in the current day asks for a major change right now"))
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
            story.supportActions.contains { $0.title == "Drink 300-500 ml water" || $0.title == "Sip fluids steadily" },
            "supportActions=\(story.supportActions.map(\.title))"
        )
        XCTAssertTrue(supportText.localizedCaseInsensitiveContains("300-500 ml"))
        XCTAssertTrue(supportText.localizedCaseInsensitiveContains("Hydration"))
    }

    func testSaunaSoonLowWaterCreatesHydrationHero() {
        let sauna = quickSauna(minutesFromNow: 45, duration: 25)
        let output = guidance(
            [sauna],
            brain: brain(currentHour: 8, recovery: .strong, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.4),
            nutrition: nutrition(water: 0, waterGoal: 1.88, meals: 1, calories: 730, carbs: 56)
        )

        let renderedState = output.screenStory?.stateLabel ?? output.stateLabel

        XCTAssertEqual(output.priority.limiter, .hydration)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, .hydration)
        XCTAssertEqual(renderedState, "HYDRATION FIRST")

        let story = output.screenStory
        let renderedText = [
            story?.myRead,
            story?.myRecommendation,
            story?.beCarefulWith
        ].compactMap { $0 }.joined(separator: " ")
        let actionTitles = (story?.primaryActions ?? []).map(\.title).joined(separator: " ")

        XCTAssertTrue(renderedText.localizedCaseInsensitiveContains("heat") || renderedText.localizedCaseInsensitiveContains("sauna"))
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

        XCTAssertEqual(output.priority.limiter, .hydration)
        XCTAssertEqual(output.narrativePlan?.primaryLimiter, .hydration)
        XCTAssertEqual(renderedState, "HYDRATION FIRST")
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
        XCTAssertTrue(supportText.localizedCaseInsensitiveContains("water") || supportText.localizedCaseInsensitiveContains("sip"))
        XCTAssertTrue(visibleTexts(story).joined(separator: " ").localizedCaseInsensitiveContains("sip"))
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

        assertDecision(
            decision,
            status: .adjustPlan,
            title: "Keep the ride, lower the ceiling",
            myRead: "Today's planned ride asks for more quality than your current sleep and recovery profile is likely to give.",
            myRecommendation: "Keep the session if you want it, but make the warm-up decide how much effort belongs today.",
            beCarefulWith: "Forcing the hard part just because it is on the calendar."
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

        assertDecision(
            decision,
            status: .trainingGoalAchieved,
            title: "The useful work is already done",
            myRead: "Today's main training load is already in the bank, so the rest of the day is about absorbing it.",
            myRecommendation: "The training signal is done. Recovery is now the priority: normal food, steady fluids, and no extra training pressure.",
            beCarefulWith: "Adding another workout because you still feel good right now."
        )
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
        XCTAssertEqual(decision.title, "Manage effort")
        XCTAssertTrue(decision.myRead.localizedCaseInsensitiveContains("live"))
        XCTAssertTrue(decision.myRead.localizedCaseInsensitiveContains("adds load"))
        XCTAssertTrue(decision.myRecommendation.localizedCaseInsensitiveContains("reserve"))
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

        assertDecision(
            decision,
            status: .nothingNeedsFixing,
            title: "The day is in a good place",
            myRead: "Training, recovery, and preparation are balanced.",
            myRecommendation: "Enjoy the evening and keep a normal routine.",
            beCarefulWith: "Trying to optimize things that are already working."
        )
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

        assertDecision(
            decision,
            status: .protectTomorrow,
            title: "Protect tomorrow",
            myRead: "Tomorrow contains a long ride session, and today's recovery choices now influence readiness.",
            myRecommendation: "Protect sleep, avoid additional load, and finish hydration gradually.",
            beCarefulWith: "Turning recovery time into more training or activity."
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

        assertDecision(
            decision,
            status: .reducePlan,
            title: "Reduce the plan",
            myRead: "Recovery is the main constraint behind this recommendation. Ride is live, but today's sleep and recovery profile does not support productive hard work.",
            myRecommendation: "Keep it easy or stop early. Finish with reserve.",
            beCarefulWith: "Intervals, threshold work, or trying to prove fitness in a low-readiness state."
        )
    }

    func testLivePlannedCyclingWithReadyRecoveryUsesCautionNotRed() {
        let ride = cycling(title: "Cycling", minutesFromNow: -5, duration: 75)

        let decision = resolve(
            [ride],
            brain: brain(currentHour: 10, recovery: .vulnerable, readiness: .low),
            recovery: CoachRecoveryContext(recoveryPercent: 85, sleepHours: 6.2),
            nutrition: nutrition(water: 0.5, waterGoal: 3.1, meals: 1, calories: 583, carbs: 53, lastMealMinutesAgo: 60)
        )

        XCTAssertEqual(decision.title, "Manage effort")
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
        XCTAssertEqual(guidance.screenStory?.title, "Manage effort")
        XCTAssertEqual(guidance.screenStory?.myRecommendation, "Keep the first minutes easy. Finish with reserve.")
        XCTAssertEqual(guidance.supportActions.map(\.title), [
            "Keep effort easy",
            "Finish with reserve"
        ])
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
        XCTAssertEqual(story.title, "Manage effort")
        XCTAssertEqual(story.myRecommendation, "Keep the first minutes easy. Finish with reserve.")
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("is live"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("recovery"))
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

        assertDecision(
            decision,
            status: .opportunityDay,
            title: "Today can absorb training",
            myRead: "Sleep, recovery, and recent load line up well, and there is no planned session competing for energy.",
            myRecommendation: "Use today deliberately if there is a meaningful session you wanted to place this week.",
            beCarefulWith: "Spending a strong day on random activity that creates fatigue without purpose."
        )
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

        XCTAssertEqual(guidance.stateLabel, CoachNarrativeBadgeIntent.goodToGo.label)
        XCTAssertEqual(guidance.priority.priority, .stable)
        XCTAssertNil(guidance.priority.planChallenge)
        XCTAssertNil(guidance.priority.whyThisMatters)

        let story = try XCTUnwrap(guidance.screenStory)

        XCTAssertEqual(story.title, "The day is in a good place")
        XCTAssertFalse(story.shouldShowWhy)
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        XCTAssertTrue(story.primaryActions.isEmpty)
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
        XCTAssertEqual(contract.bestNextDecision, guidance.priority.todayMessage)
        XCTAssertEqual(contract.what, guidance.priority.todayMessage)
        XCTAssertEqual(guidance.dynamicInsight.text, contract.what)
        XCTAssertEqual(contract.why, guidance.priority.whyThisMatters)
        XCTAssertEqual(contract.how.split(separator: " ").count <= 40, true)

        XCTAssertEqual(storyContract.dailyObjective, contract.dailyObjective)
        XCTAssertEqual(storyContract.primaryLimiter, contract.primaryLimiter)
        XCTAssertEqual(storyContract.bestNextDecision, contract.bestNextDecision)
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

        XCTAssertEqual(guidance.priority.priority, .performance)
        XCTAssertNotNil(guidance.priority.planChallenge)

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertTrue(story.shouldShowPlanAdjustment)
        XCTAssertNotNil(story.planAdjustment)
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

        XCTAssertEqual(guidance.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("Prepare for"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("ride"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("Hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("fresh") || story.myRecommendation.localizedCaseInsensitiveContains("readiness"))
        XCTAssertTrue(
            story.primaryActions.contains { $0.title == "Drink 300-500 ml water" },
            "actions=\(story.primaryActions.map(\.title))"
        )
        XCTAssertTrue(
            story.primaryActions.contains { $0.title == "Eat 30-60g carbs" },
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
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("cycling"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("readiness") || story.myRecommendation.localizedCaseInsensitiveContains("arrive"))
        XCTAssertFalse(visible.contains("arrive ready for heat"))
        XCTAssertFalse(visible.contains("sauna"))
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
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertFalse(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.supportActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(output.supportActions.contains { $0.title == "Drink 300-500 ml water" })
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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
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
        XCTAssertEqual(output.screenStory?.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
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
        XCTAssertFalse(mainText.localizedCaseInsensitiveContains("Drink 300-500 ml"))
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
        XCTAssertTrue(actionTitles.contains("Bring ride nutrition"))
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

        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("prepare"))
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("cycling") || story.title.localizedCaseInsensitiveContains("ride"))
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

        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("fresh") || story.myRecommendation.localizedCaseInsensitiveContains("ready"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml"))
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

        XCTAssertFalse(story.primaryActions.contains { $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })
        XCTAssertFalse([story.title, story.myRead, story.myRecommendation].joined(separator: " ").localizedCaseInsensitiveContains("Hydration"))
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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.prepare.label)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("prepare"))
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
                    "Bring a bottle",
                    "Bring ride nutrition"
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
        XCTAssertTrue(story.supportActions.contains { $0.title == "Eat normally at next meal" })
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

        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Stay flexible") || visible.localizedCaseInsensitiveContains("Keep the day flexible"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Keep recovery easy"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Eat normally at next meal"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Consider a glass of water"))
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

        XCTAssertEqual(noActivity.screenStory?.stateLabel, CoachNarrativeBadgeIntent.goodToGo.label)
        XCTAssertEqual(noActivity.screenStory?.title, "Keep the day simple")
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

        XCTAssertEqual(story.myRead, "The ride starts in about 1h45m. Breakfast is in, so now the goal is arriving fresh.")
        XCTAssertEqual(story.myRecommendation, "Build readiness gradually and keep the first 15-20 minutes easy.")
        XCTAssertEqual(story.beCarefulWith, "Turning preparation into extra training before the ride.")
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
            .init(name: "4. activity started", ride: lifecycleRide(elapsedMinutes: 1), expectedState: "KEEP IT EASY", expectedTitleContains: "keep it easy", mustNotTitleContain: "prepare"),
            .init(name: "5. first 15 minutes", ride: lifecycleRide(elapsedMinutes: 12), expectedState: "KEEP IT EASY", expectedTitleContains: "keep it easy", mustNotTitleContain: "prepare"),
            .init(name: "6. mid-session", ride: lifecycleRide(elapsedMinutes: 90), expectedState: "KEEP IT EASY", expectedTitleContains: "keep it easy", mustNotTitleContain: "prepare"),
            .init(name: "7. late-session", ride: lifecycleRide(elapsedMinutes: 172), expectedState: "KEEP IT EASY", expectedTitleContains: "keep it easy", mustNotTitleContain: "prepare"),
            .init(name: "8. activity completed", ride: lifecycleRide(completedMinutesAgo: 0), expectedState: "RECOVER", expectedTitleContains: "workout", mustNotTitleContain: "prepare"),
            .init(name: "9. post-workout recovery window", ride: lifecycleRide(completedMinutesAgo: 45), expectedState: "RECOVER", expectedTitleContains: "workout", mustNotTitleContain: "prepare"),
            .init(name: "10. recovery completed", ride: lifecycleRide(completedMinutesAgo: 150), expectedState: "START THE DAY", expectedTitleContains: "simple", mustNotTitleContain: "useful work")
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

            XCTAssertTrue(
                actualState.localizedCaseInsensitiveContains(stage.expectedState),
                "\(stage.name) expected state containing \(stage.expectedState), got \(actualState)"
            )
            XCTAssertTrue(
                actualTitle.localizedCaseInsensitiveContains(stage.expectedTitleContains),
                "\(stage.name) expected title containing \(stage.expectedTitleContains), got \(actualTitle)"
            )
            if let forbidden = stage.mustNotTitleContain {
                XCTAssertFalse(
                    actualTitle.localizedCaseInsensitiveContains(forbidden),
                    "\(stage.name) must not remain stuck in \(forbidden), got \(actualTitle)"
                )
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
                expectedStateContains: "PREPARE",
                expectedTitleContains: "cycling",
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
                expectedTitleContains: "keep it easy",
                forbiddenTitleContains: "prepare",
                hydrationMayDominate: false
            ),
            .init(
                name: "5. Cycling completed",
                activities: [cyclingComplete],
                brain: brain(currentHour: 13, recovery: .stable, readiness: .good),
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: nutrition(water: 1.0, meals: 2, calories: 1_400, carbs: 160),
                expectedStateContains: "RECOVER",
                expectedTitleContains: "done",
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
                expectedStateContains: "HYDRATION FIRST",
                expectedTitleContains: "hydration",
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

            XCTAssertTrue(story.stateLabel.localizedCaseInsensitiveContains(scenario.expectedStateContains), scenario.name)
            XCTAssertTrue(story.title.localizedCaseInsensitiveContains(scenario.expectedTitleContains), scenario.name)
            if let forbiddenTitle = scenario.forbiddenTitleContains {
                XCTAssertFalse(story.title.localizedCaseInsensitiveContains(forbiddenTitle), scenario.name)
            }
            XCTAssertTrue(duplicateWarnings.isEmpty, scenario.name)
            XCTAssertTrue(invalidActionWarnings.isEmpty, scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("controlled"), scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("Preparation matters more than chasing any single metric"), scenario.name)
            XCTAssertFalse(rendered.localizedCaseInsensitiveContains("Nothing in the current day asks for a major change right now"), scenario.name)
            XCTAssertFalse(brokenTime, scenario.name)
            if !scenario.hydrationMayDominate {
                XCTAssertFalse(hydrationDominant, scenario.name)
            } else {
                XCTAssertEqual(output.priority.limiter, .hydration, scenario.name)
                XCTAssertEqual(output.priority.strength, .critical, scenario.name)
            }
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
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Eat 30-60 g carbs"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Eat 30-60g carbs" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
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
        let visible = visibleTexts(story).joined(separator: " ")

        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Hydration is improving") || visible.localizedCaseInsensitiveContains("Good start on hydration"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
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

        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Hydration is improving") || visible.localizedCaseInsensitiveContains("Good start on hydration"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
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

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("meal is in"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("give it time to settle"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Sip more before leaving" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Keep the first 10 minutes easy" || $0.title == "Start easy" })
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

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("meal is in") || visible.localizedCaseInsensitiveContains("food is already handled"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("hydration is still missing") || visible.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Keep the first 10 minutes easy" || $0.title == "Start easy" })
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

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("main prep is done"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("food is in and hydration has started"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Keep the first 10 minutes easy" || $0.title == "Start easy" })
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

        XCTAssertTrue(visible.localizedCaseInsensitiveContains("hydration is still missing") || visible.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(afterDeletingWater.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
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
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("Add 30-60 g carbs"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Eat 30-60g carbs" })
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
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Hydration is significantly behind"))
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Add 300-500 ml now"))
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Fuel is still missing"))
        XCTAssertTrue(support.localizedCaseInsensitiveContains("Add 30-60g carbs"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("Add 30-60 g carbs"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Eat 30-60g carbs" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(output.supportActions.contains { $0.title == "Drink 300-500 ml water" })
        XCTAssertTrue(output.supportActions.contains { $0.title == "Eat 30-60g carbs" })
        XCTAssertTrue(teaser.localizedCaseInsensitiveContains("Drink 300-500 ml now"))
        XCTAssertTrue(teaser.localizedCaseInsensitiveContains("Add 30-60 g carbs"))
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

        XCTAssertEqual(output.priority.focus, .prepareForActivity)
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("main prep is done"))
        XCTAssertTrue(visible.localizedCaseInsensitiveContains("food is in and hydration has started"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Bring a bottle" })
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Keep the first 10 minutes easy" || $0.title == "Start easy" })
        XCTAssertTrue(story.primaryActions.contains { $0.subtitle == "Keep the first 10 minutes easy" })
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

        XCTAssertEqual(story.title, "Protect tomorrow")
        XCTAssertEqual(story.myRead, "Tomorrow contains a long cycling session, and today's recovery choices now influence readiness.")
        XCTAssertEqual(story.myRecommendation, "Protect sleep, avoid additional load, and finish hydration gradually.")
        XCTAssertEqual(story.beCarefulWith, "Turning recovery time into more training or activity.")
        XCTAssertFalse(story.shouldShowWhy)
        XCTAssertNil(story.whyThisMatters)
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

        XCTAssertEqual(story.title, "The day is in a good place")
        XCTAssertEqual(story.myRead, "Training, recovery, and preparation are balanced.")
        XCTAssertEqual(story.myRecommendation, "Enjoy the evening and keep a normal routine.")
        XCTAssertEqual(story.beCarefulWith, "Trying to optimize things that are already working.")
        XCTAssertFalse(story.shouldShowWhy)
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
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("normal dinner"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("sip fluids gradually"))
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

        XCTAssertNotEqual(eveningReset.1.title, protectTomorrow.1.title)
        XCTAssertNotEqual(eveningReset.1.stateLabel, protectTomorrow.1.stateLabel)
        XCTAssertNotEqual(eveningReset.1.myRead, protectTomorrow.1.myRead)
        XCTAssertNotEqual(eveningReset.1.myRecommendation, protectTomorrow.1.myRecommendation)
        XCTAssertNotEqual(eveningReset.1.beCarefulWith, protectTomorrow.1.beCarefulWith)
        XCTAssertNotEqual(eveningReset.1.primaryActions.map(\.title), protectTomorrow.1.primaryActions.map(\.title))

        XCTAssertEqual(protectTomorrow.1.stateLabel, CoachNarrativeBadgeIntent.protectTomorrow.label)
        XCTAssertTrue(protectTomorrow.1.myRead.localizedCaseInsensitiveContains("tomorrow"))
        XCTAssertTrue(protectTomorrow.1.myRead.localizedCaseInsensitiveContains("fresh"))
        XCTAssertTrue(protectTomorrow.1.myRecommendation.localizedCaseInsensitiveContains("Protect sleep"))
        XCTAssertTrue(protectTomorrow.1.myRecommendation.localizedCaseInsensitiveContains("recovery"))
        XCTAssertFalse(protectTomorrow.1.myRecommendation.localizedCaseInsensitiveContains("hydration"))
        XCTAssertTrue(protectTomorrow.1.beCarefulWith.localizedCaseInsensitiveContains("more training or activity"))
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
        XCTAssertEqual(story.title, "Protect tomorrow")
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("next important event"))
        XCTAssertEqual(story.myRecommendation, "Keep the evening light. Protect sleep and start recovery now.")
        XCTAssertEqual(story.beCarefulWith, "Turning recovery time into more training or activity.")
        XCTAssertTrue(scenario.priority.supportBullets.contains("Sip gradually if thirsty"))
        XCTAssertTrue(scenario.priority.supportBullets.contains("Protect sleep"))
        XCTAssertTrue(scenario.priority.supportBullets.contains("Skip extra intensity"))
        assertNoExecutionLanguage(in: story.primaryActions)
        XCTAssertTrue(actionTitles.contains("Skip extra training"))
        assertClosePhaseActions(story.primaryActions)
    }

    func testEveningWindDownActionsContainNoExecutionLanguage() throws {
        let scenario = try protectTomorrowEveningScenario(includesTomorrowRide: false)
        let story = scenario.story
        let actionTitles = story.primaryActions.map(\.title)

        XCTAssertEqual(scenario.priority.focus, .eveningWindDown)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.windDown.label)
        assertNoExecutionLanguage(in: story.primaryActions)
        XCTAssertTrue(actionTitles.contains("Prepare for sleep"))
        XCTAssertTrue(actionTitles.contains("Keep the evening calm"))
        XCTAssertTrue(actionTitles.contains("Skip extra training"))
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

        XCTAssertEqual(scenario.priority.priority, .stable)
        XCTAssertEqual(scenario.guidance.narrativePlan?.objective, .startDay)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.startDay.label)
        XCTAssertNotEqual(story.stateLabel, CoachNarrativeBadgeIntent.manageEffort.label)
        XCTAssertEqual(story.title, "Bring the basics online")
        XCTAssertEqual(story.myRead, "Recovery is strong, and the ride is still later today.")
        XCTAssertEqual(story.myRecommendation, "Start hydration early and eat normally through the morning.")
        XCTAssertEqual(story.beCarefulWith, "Waiting until the ride window to catch up.")
        XCTAssertTrue(story.primaryActions.map(\.title).contains("Start with 300-500 ml"))
        XCTAssertTrue(story.primaryActions.map(\.title).contains("Eat normally at next meal"))
        XCTAssertTrue(story.primaryActions.map(\.title).contains("Keep the ride plan unchanged"))
    }

    func testCoachScreenRendersMorningSetupGuidanceInsteadOfCurrentStatusFallback() throws {
        let scenario = try morningHighRecoveryLaterRideScenario()
        let fallbackEquivalent = CoachGuidanceV3(
            phase: scenario.guidance.phase,
            opportunity: scenario.guidance.opportunity,
            priority: scenario.guidance.priority,
            shouldSurface: scenario.guidance.shouldSurface,
            stateLabel: scenario.guidance.stateLabel,
            title: scenario.guidance.title,
            message: scenario.guidance.message,
            insightTitle: scenario.guidance.insightTitle,
            insightSubtitle: scenario.guidance.insightSubtitle,
            supportActions: scenario.guidance.supportActions,
            avoidNotes: scenario.guidance.avoidNotes,
            icon: scenario.guidance.icon,
            color: scenario.guidance.color,
            importance: scenario.guidance.importance,
            tone: scenario.guidance.tone,
            screenStory: nil,
            v5Contract: scenario.guidance.v5Contract,
            narrativePlan: scenario.guidance.narrativePlan
        )

        XCTAssertEqual(scenario.story.stateLabel, CoachNarrativeBadgeIntent.startDay.label)
        XCTAssertEqual(scenario.story.title, "Bring the basics online")
        XCTAssertEqual(scenario.guidance.priority.priority, .stable)
        XCTAssertEqual(scenario.guidance.priority.focus, .dailyOverview)
        XCTAssertEqual(scenario.guidance.priority.limiter, .hydration)
        XCTAssertEqual(ExpertCoachRenderMode.resolve(cachedGuidance: scenario.guidance), .guidance)
        XCTAssertEqual(ExpertCoachRenderMode.resolve(cachedGuidance: nil), .fallbackCurrentStatus)
        XCTAssertEqual(ExpertCoachRenderMode.resolve(cachedGuidance: fallbackEquivalent), .fallbackCurrentStatus)
    }

    func testCoachDoesNotMentionTrainingLaterWhenNoActivityExists() throws {
        let scenario = try morningHighRecoveryLaterRideScenario(includesRide: false)
        let visibleText = visibleCoachText(story: scenario.story, guidance: scenario.guidance).lowercased()

        XCTAssertNil(scenario.context.dayContext.nextActivity)
        XCTAssertEqual(scenario.story.stateLabel, CoachNarrativeBadgeIntent.startDay.label)
        XCTAssertEqual(scenario.story.myRead, "Recovery is strong, and the day is open.")
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

        XCTAssertTrue(visibleCoachText(story: withRide.story, guidance: withRide.guidance).lowercased().contains("ride is still later today"))
        XCTAssertNil(afterDeletion.context.dayContext.nextActivity)
        XCTAssertEqual(afterDeletion.story.myRead, "Recovery is strong, and the day is open.")
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
        XCTAssertTrue(openDayText.localizedCaseInsensitiveContains("day is open"))
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

        XCTAssertEqual(scenario.story.title, "Bring the basics online")
        XCTAssertEqual(scenario.story.myRead, "Recovery is strong, and the day is open.")
        XCTAssertEqual(scenario.story.myRecommendation, "Use the morning to bring hydration and food online.")
        XCTAssertTrue(actionTitles.contains("Start with 300-500 ml"))
        XCTAssertTrue(actionTitles.contains("Eat normally at next meal"))
        XCTAssertTrue(actionTitles.contains("Keep the day flexible"))
        XCTAssertFalse(visibleText.contains("ride window"))
        XCTAssertFalse(visibleText.contains("keep the ride plan unchanged"))
        XCTAssertFalse(visibleText.contains("training later today"))
    }

    func testRecovery99PreventsUnnecessaryRideReductionLanguage() throws {
        let scenario = try morningHighRecoveryLaterRideScenario()
        let visibleText = visibleCoachText(story: scenario.story, guidance: scenario.guidance).lowercased()

        XCTAssertEqual(scenario.priority.priority, .stable)
        XCTAssertEqual(scenario.guidance.narrativePlan?.objective, .startDay)
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
        XCTAssertEqual(scenario.priority.priority, .stable)
        XCTAssertEqual(scenario.guidance.narrativePlan?.objective, .startDay)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.startDay.label)
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
        XCTAssertEqual(story.activityContext, "Tonight this is a bridge into sleep, so the next win is cooling down cleanly.")
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

        XCTAssertTrue(starting.myRecommendation.localizedCaseInsensitiveContains("Ignore targets"))
        XCTAssertTrue(middle.myRecommendation.localizedCaseInsensitiveContains("repeatable"))
        XCTAssertTrue(finishing.myRecommendation.localizedCaseInsensitiveContains("reserve"))
        XCTAssertNotEqual(starting.myRecommendation, middle.myRecommendation)
        XCTAssertNotEqual(middle.myRecommendation, finishing.myRecommendation)

        XCTAssertEqual(startingGuidance.dynamicInsight.text, "Ignore targets for the first few minutes.")
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

        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("close to today's hydration goal"))
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
        XCTAssertEqual(plan.primaryLimiter, .hydration)
        XCTAssertEqual(plan.urgency, .caution)
        XCTAssertTrue([CoachNarrativeBadgeIntent.manageEffort, .keepControlled].contains(plan.badgeIntent))

        let story = try XCTUnwrap(guidance.screenStory)
        let visibleText = visibleTexts(story).joined(separator: " ").lowercased()

        XCTAssertTrue(visibleText.contains("live"))
        XCTAssertTrue(visibleText.contains("hydration"))
        XCTAssertTrue(visibleText.contains("fuel"))
        XCTAssertTrue(visibleText.contains("sauna"))
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
            brain: brain(currentHour: 21, recovery: .stable, readiness: .good),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 6.2),
            nutrition: nutrition(water: 0.5, waterGoal: 2.4, meals: 1, calories: 1_200, carbs: 140, lastMealMinutesAgo: 90)
        )

        XCTAssertEqual(guidance.priority.priority, .activeSession)
        XCTAssertEqual(guidance.priority.focus, .activeActivity)
        XCTAssertEqual(guidance.priority.detailTitle, "Keep upper body steady")

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertEqual(story.title, guidance.priority.detailTitle)
        XCTAssertEqual(story.title, "Keep upper body steady")
        XCTAssertNotEqual(story.title, "Keep session easy")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("keep the session easy"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("avoid extra stress"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("finish with reserve"))
        XCTAssertTrue(story.primaryActions.contains { $0.title == "Protect sleep" })
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
        XCTAssertEqual(plan.primaryLimiter, .none)
        XCTAssertEqual(plan.urgency, .execution)

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertEqual(story.title, "Let the session prove itself")
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("fuel is still light"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration is not yet supporting"))
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveEnduranceWithNoFuelUsesFuelAsPrimaryLimiter() throws {
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
        XCTAssertEqual(plan.primaryLimiter, .fuel)
        XCTAssertTrue(plan.actionIntents.contains { intent in
            if case .eat = intent { return true }
            return false
        })

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("Fuel"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("food"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("limiter"))
        XCTAssertLessThanOrEqual(occurrences(of: "fuel", in: visibleTexts(story).joined(separator: " ")), 3)
        assertCompactActiveStory(story)
        assertNoSupportSignalLeakage(story)
    }

    func testActiveEnduranceWithNoWaterUsesHydrationAsPrimaryLimiter() throws {
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
        XCTAssertEqual(plan.primaryLimiter, .hydration)
        XCTAssertTrue(plan.actionIntents.contains { intent in
            if case .drink = intent { return true }
            return false
        })

        let story = try XCTUnwrap(guidance.screenStory)
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("Hydration"))
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
        XCTAssertEqual(plan.primaryLimiter, .fuel)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("Fuel"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("form"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("reserve"))
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
        XCTAssertEqual(plan.primaryLimiter, .hydration)
        XCTAssertFalse(plan.secondaryLimiters.isEmpty)
        let story = try XCTUnwrap(output.screenStory)

        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("Hydration"))
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
        XCTAssertEqual(plan.primaryLimiter, .hydration)
        XCTAssertTrue(plan.actionIntents.contains { intent in
            if case .drink = intent { return true }
            return false
        })
        XCTAssertFalse(output.priority.todayTitle.localizedCaseInsensitiveContains("Walk"))
        assertNoSupportSignalLeakage(try XCTUnwrap(output.screenStory))
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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.recover.label)
        XCTAssertEqual(story.title, "Keep recovery easy")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("walk, yoga, and sauna easy"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("sauna stay restorative"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration matters because"))
        XCTAssertFalse(story.shouldShowPlanAdjustment)
        assertNoDuplicateIdeas(story)
        assertTodayInsightIsTeaser(guidance, scenario: "morning recovery day with sauna")
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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.recover.label)
        XCTAssertEqual(story.title, "Keep recovery easy")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("walk and sauna easy"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("yoga"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertFalse(story.myRead.localizedCaseInsensitiveContains("hydration matters because"))
        XCTAssertFalse(guidance.dynamicInsight.title.localizedCaseInsensitiveContains("heat"))
        XCTAssertTrue(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("sip") || $0.type == .hydrateBeforeSession || $0.type == .steadyHydration })

        XCTAssertEqual(guidance.v5Interpretation.storyType, .recovery)
        XCTAssertTrue(guidance.v5Interpretation.supportSignals.contains(.hydration))
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
            assertNoGenericAdvice(story, scenario: scenario.name)
            assertTodayInsightIsTeaser(guidance, scenario: scenario.name)

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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.adjustTrainingReadiness.label)
        XCTAssertEqual(output.title, "Adjust training readiness")
        XCTAssertEqual(story.title, "Adjust training readiness")
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

        XCTAssertEqual(output.priority.priority, .sleepPreparation)
        XCTAssertEqual(output.priority.focus, .eveningWindDown)
        XCTAssertEqual(output.priority.limiter, .sleep)
        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.protectSleep.label)
        XCTAssertEqual(story.title, "Sleep comes first")
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("sleep"))
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

        XCTAssertEqual(story.stateLabel, CoachNarrativeBadgeIntent.reducePlan.label)
        XCTAssertTrue(story.shouldShowBeCarefulWith)
        XCTAssertTrue(visible.contains("recovery") || visible.contains("sleep"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("hydration"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("fuel"))
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("Eat") })
        XCTAssertFalse(story.primaryActions.contains { $0.title.localizedCaseInsensitiveContains("Drink") })
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

        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("Tennis"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("controlled"))
        XCTAssertTrue(story.myRecommendation.localizedCaseInsensitiveContains("comfort"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("hydration is not fully covered"))
        XCTAssertFalse(story.myRecommendation.localizedCaseInsensitiveContains("ignore targets"))
        assertTodayInsightIsTeaser(guidance, scenario: "late active tennis")
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

        XCTAssertTrue(visibleTexts(tennisStory).joined(separator: " ").localizedCaseInsensitiveContains("tomorrow's tennis"))
        XCTAssertFalse(visibleTexts(tennisStory).joined(separator: " ").localizedCaseInsensitiveContains("tomorrow's training"))
        XCTAssertTrue(visibleTexts(strengthStory).joined(separator: " ").localizedCaseInsensitiveContains("tomorrow's strength"))
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
            supportBullets: ["Hydration could use attention", "Bring a bottle", "Bring ride nutrition"],
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
        for ride: PlannedActivity
    ) throws -> (context: CoachDecisionContext, priority: CoachDayPriorityResult, guidance: CoachGuidanceV3) {
        let brain = brain(currentHour: 10, recovery: .strong, readiness: .good)
        let nutrition = nutrition(water: 1.0, meals: 1, calories: 850, carbs: 110, lastMealMinutesAgo: 60)
        let dayContext = CoachDayContextBuilder.build(
            activities: [ride],
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: [ride],
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
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
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
        recovery: HumanBrain.RecoveryState,
        readiness: HumanBrain.ReadinessState,
        strain: HumanBrain.StrainState = .normal
    ) -> HumanBrain.State {
        HumanBrainStateBuilder.make(
            currentHour: currentHour,
            hydration: .optimal,
            fuel: .good,
            strain: strain,
            recovery: recovery,
            readiness: readiness
        )
    }

    func nutrition(
        water: Double = 2.0,
        waterGoal: Double = 2.5,
        meals: Int? = 1,
        calories: Double = 1_800,
        carbs: Double = 210,
        lastMealMinutesAgo: Int? = nil
    ) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: 2_400,
            proteinCurrent: 110,
            proteinGoal: 150,
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
