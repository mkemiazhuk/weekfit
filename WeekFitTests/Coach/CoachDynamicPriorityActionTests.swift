import XCTest
@testable import WeekFit

final class CoachDynamicPriorityActionTests: XCTestCase {
    private let now = CoachTestClock.reference

    func testUnderfedUnderhydratedHighLoadDayKeepsRecoveryStory() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 2.25)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertFalse(isFoodOrWaterHero(story.title))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[underfueled,hydrationBehind,proteinBehind]"))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("meal") || actionText(story).localizedCaseInsensitiveContains("protein"))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("sip") || actionText(story).localizedCaseInsensitiveContains("drink"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=highActiveCalories"))
    }

    func testFoodImprovesWaterStillBehindRemovesFoodContributor() throws {
        let before = highLoadScenario(calories: 712, protein: 57, water: 2.25)
        let after = highLoadScenario(calories: 1_500, protein: 118, water: 2.50)
        let story = try XCTUnwrap(after.guidance.screenStory)

        assertRecoveryStory(after.guidance)
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("eat recovery meal"))
        XCTAssertFalse(after.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertFalse(after.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(after.guidance.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertTrue(after.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[hydrationBehind]"))
        XCTAssertTrue(after.guidance.priority.reasons.contains("RecoveryContributorDebug.resolvedContributors=[underfueled,proteinBehind]"))
        XCTAssertNotEqual(before.guidance.priority.decisionScore, after.guidance.priority.decisionScore)
        XCTAssertNotEqual(actionSignature(before.guidance), actionSignature(after.guidance))
    }

    func testWaterImprovesFoodStillBehindRemovesHydrationContributor() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 3.00)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[underfueled,proteinBehind]"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("hydrationBehind") })
        XCTAssertFalse(primaryActionText(story).localizedCaseInsensitiveContains("drink water"))
        XCTAssertFalse(primaryActionText(story).localizedCaseInsensitiveContains("sip"))
    }

    func testFoodAndWaterCompleteLeavesSleepAndWindDownActions() throws {
        let scenario = highLoadScenario(calories: 1_900, protein: 140, water: 3.40)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertFalse(hasActiveRecoveryContributor(scenario.guidance, "underfueled"))
        XCTAssertFalse(hasActiveRecoveryContributor(scenario.guidance, "proteinBehind"))
        XCTAssertFalse(hasActiveRecoveryContributor(scenario.guidance, "hydrationBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("hydrationBehind") })
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("sleep") || actionText(story).localizedCaseInsensitiveContains("evening"))
        assertNoFoodOrWaterAction(story)
        XCTAssertTrue((story.whyThisMatters ?? "").localizedCaseInsensitiveContains("already in place"))
    }

    func testOverfedHydratedHighLoadDayDoesNotRecommendMoreFoodOrWater() throws {
        let scenario = highLoadScenario(calories: 2_600, protein: 190, water: 3.90)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        assertNoFoodOrWaterAction(story)
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("sleep") || actionText(story).localizedCaseInsensitiveContains("load"))
    }

    func testActiveCyclingOverridesStaticRecoverySummary() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 2.25, active: .cycling)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertTrue(isActivePhase(scenario.guidance.phase))
        XCTAssertNotEqual(story.title, "The work is in the bank")
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("day complete"))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("easy") || actionText(story).localizedCaseInsensitiveContains("intensity") || actionText(story).localizedCaseInsensitiveContains("reserve"))
        XCTAssertFalse(containsFoodPrimaryAction(story))
        XCTAssertFalse(containsWaterPrimaryAction(story))
    }

    func testActiveRunningOnOverloadDayGetsStrongerControlGuidance() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 2.25, active: .running)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertTrue(isActivePhase(scenario.guidance.phase))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("day complete"))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("easy") || actionText(story).localizedCaseInsensitiveContains("control") || actionText(story).localizedCaseInsensitiveContains("reserve"))
        XCTAssertFalse(containsFoodPrimaryAction(story))
        XCTAssertFalse(containsWaterPrimaryAction(story))
    }

    func testActiveWalkOnRecoveryDayStaysRelaxed() throws {
        let scenario = highLoadScenario(calories: 1_500, protein: 120, water: 3.0, active: .walk)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertTrue(isActivePhase(scenario.guidance.phase))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("easy") || actionText(story).localizedCaseInsensitiveContains("relaxed") || story.activityContext?.localizedCaseInsensitiveContains("recovery support") == true)
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("replace workout"))
        XCTAssertFalse(containsFoodPrimaryAction(story))
        XCTAssertFalse(containsWaterPrimaryAction(story))
    }

    func testFutureHardWorkoutSoonUnderfedAllowsFuelingPrimaryAction() throws {
        let scenario = trainingSoonScenario(calories: 500, protein: 35, water: 1.5, futureKind: .running)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertTrue(scenario.guidance.priority.focus == .fuelBehind || actionText(story).localizedCaseInsensitiveContains("fuel") || actionText(story).localizedCaseInsensitiveContains("eat"))
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("fuel") || story.myRecommendation.localizedCaseInsensitiveContains("eat") || story.myRecommendation.localizedCaseInsensitiveContains("session") || actionText(story).localizedCaseInsensitiveContains("carb"))
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("drink water"))
    }

    func testFutureHardWorkoutSoonFedHydratedPreparesNormally() throws {
        let scenario = trainingSoonScenario(calories: 1_900, protein: 130, water: 3.0, futureKind: .running)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("refuel"))
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("drink water"))
        XCTAssertTrue(story.myRead.localizedCaseInsensitiveContains("running") || story.myRecommendation.localizedCaseInsensitiveContains("session") || story.title.localizedCaseInsensitiveContains("run"))
    }

    func testPostHardWorkoutSevereUnderfuelingCanLeadRecoveryActions() throws {
        let scenario = highLoadScenario(calories: 500, protein: 35, water: 1.7, recentHardWorkout: true)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertFalse(story.title.localizedCaseInsensitiveContains("day complete"))
        XCTAssertTrue(primaryActionText(story).localizedCaseInsensitiveContains("meal") || primaryActionText(story).localizedCaseInsensitiveContains("eat") || primaryActionText(story).localizedCaseInsensitiveContains("protein"))
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("sip") || actionText(story).localizedCaseInsensitiveContains("drink"))
    }

    func testPostHardWorkoutRefuelCompleteRemovesRefuelAction() throws {
        let before = highLoadScenario(calories: 500, protein: 35, water: 1.7, recentHardWorkout: true)
        let after = highLoadScenario(calories: 1_700, protein: 130, water: 1.7, recentHardWorkout: true)
        let afterStory = try XCTUnwrap(after.guidance.screenStory)

        XCTAssertFalse(after.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertFalse(primaryActionText(afterStory).localizedCaseInsensitiveContains("eat recovery meal"))
        XCTAssertNotEqual(primaryActionText(try XCTUnwrap(before.guidance.screenStory)), primaryActionText(afterStory))
    }

    func testContributorStalenessAcrossNutritionSequence() {
        let under = highLoadScenario(calories: 712, protein: 57, water: 2.25)
        let proteinMeal = highLoadScenario(calories: 1_400, protein: 118, water: 2.25)
        let water = highLoadScenario(calories: 1_400, protein: 118, water: 3.0)
        let anotherMeal = highLoadScenario(calories: 1_900, protein: 150, water: 3.0)
        let deletedMeal = highLoadScenario(calories: 712, protein: 57, water: 3.0)

        assertActive(under, ["underfueled", "hydrationBehind", "proteinBehind"])
        assertActive(proteinMeal, ["hydrationBehind"])
        assertActive(water, [])
        assertActive(anotherMeal, [])
        assertActive(deletedMeal, ["underfueled", "proteinBehind"])
        XCTAssertNotEqual(under.fingerprint.rawValue, proteinMeal.fingerprint.rawValue)
        XCTAssertNotEqual(proteinMeal.fingerprint.rawValue, water.fingerprint.rawValue)
        XCTAssertNotEqual(water.fingerprint.rawValue, deletedMeal.fingerprint.rawValue)
    }

    func testTodayAndCoachPresentationsUseSameCanonicalState() throws {
        let scenario = highLoadScenario(calories: 1_900, protein: 140, water: 3.4)

        XCTAssertEqual(scenario.state.guidance?.priority.priority, scenario.guidance.priority.priority)
        XCTAssertEqual(scenario.state.coachPresentation?.title, scenario.state.todayPresentation.title)
        XCTAssertEqual(scenario.state.coachPresentation?.message, scenario.state.todayPresentation.message)
    }

    func testUnchangedFingerprintCanSkipTabSwitchRecompute() {
        let first = highLoadScenario(calories: 1_900, protein: 140, water: 3.4)
        let refreshing = first.state.preservingPreviousDuringRefresh(createdAt: now.addingTimeInterval(10))

        XCTAssertEqual(first.fingerprint, first.state.fingerprint)
        XCTAssertEqual(refreshing.id, first.state.id)
        XCTAssertEqual(refreshing.todayPresentation.title, first.state.todayPresentation.title)
        XCTAssertEqual(refreshing.coachPresentation?.title, first.state.coachPresentation?.title)
    }
}

private extension CoachDynamicPriorityActionTests {
    enum ActivityKind {
        case cycling
        case running
        case walk
    }

    struct Scenario {
        let guidance: CoachGuidanceV3
        let input: CoachInputSnapshot
        let fingerprint: CoachInputFingerprint
        let state: CoachState
    }

    func highLoadScenario(
        calories: Double,
        protein: Double,
        water: Double,
        active: ActivityKind? = nil,
        recentHardWorkout: Bool = false
    ) -> Scenario {
        var activities = baseHighLoadActivities(recentHardWorkout: recentHardWorkout)
        if let active {
            activities.append(activeActivity(active))
        }
        activities.append(tomorrowRecovery("Walk", hoursFromStartOfTomorrow: 10, duration: 45))
        activities.append(tomorrowRecovery("Sauna", hoursFromStartOfTomorrow: 18, duration: 25))

        return buildScenario(
            activities: activities,
            calories: calories,
            protein: protein,
            water: water,
            activeCalories: 1_114,
            activityProgress: 1.57,
            exerciseMinutes: 130,
            recoveryPercent: 86,
            readiness: active == nil ? .low : .compromised,
            recovery: active == nil ? .vulnerable : .compromised
        )
    }

    func trainingSoonScenario(
        calories: Double,
        protein: Double,
        water: Double,
        futureKind: ActivityKind
    ) -> Scenario {
        let future = plannedActivity(futureKind, minutesFromNow: 45, duration: 60, completed: false)
        return buildScenario(
            activities: [future],
            calories: calories,
            protein: protein,
            water: water,
            activeCalories: 180,
            activityProgress: 0.35,
            exerciseMinutes: 25,
            recoveryPercent: 82,
            readiness: .good,
            recovery: .stable
        )
    }

    func buildScenario(
        activities: [PlannedActivity],
        calories: Double,
        protein: Double,
        water: Double,
        activeCalories: Double,
        activityProgress: Double,
        exerciseMinutes: Int,
        recoveryPercent: Int,
        readiness: HumanBrain.ReadinessState,
        recovery: HumanBrain.RecoveryState
    ) -> Scenario {
        let nutrition = nutritionContext(calories: calories, protein: protein, water: water)
        let brain = brainState(
            calories: calories,
            protein: protein,
            water: water,
            activeCalories: activeCalories,
            readiness: readiness,
            recovery: recovery
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitActivityCircle,
            activeCalories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: 12,
            activityGoalCalories: activeCalories / activityProgress,
            activityProgress: activityProgress
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: now,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: now,
            now: now,
            brain: brain
        )
        let readinessContext = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowDay = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrowDate,
            now: now
        )
        let recoveryContext = CoachRecoveryContext(recoveryPercent: recoveryPercent, sleepHours: 7.02)
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowDay.allActivities.isEmpty ? nil : CoachTomorrowPlanContext(dayContext: tomorrowDay),
            actualLoad: actualLoad,
            recoveryContext: recoveryContext,
            nutritionContext: nutrition,
            readiness: readinessContext
        )
        let priority = CoachDayPriorityResolver.resolve(context)
        let decision = HumanCoachDecisionEngine.resolve(context: context, priority: priority)
        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: activityContext.phase,
            readiness: readinessContext,
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
        let input = CoachInputSnapshot(
            metricsSnapshotID: nil,
            selectedDate: now,
            now: now,
            brain: brain,
            plannedActivities: activities,
            actualLoad: actualLoad,
            dayContext: dayContext,
            recoveryContext: recoveryContext,
            nutritionContext: nutrition,
            source: "CoachDynamicPriorityActionTests"
        )
        let fingerprint = CoachInputFingerprint(snapshot: input)
        let state = CoachState.ready(
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            createdAt: now
        )
        return Scenario(guidance: guidance, input: input, fingerprint: fingerprint, state: state)
    }

    func baseHighLoadActivities(recentHardWorkout: Bool) -> [PlannedActivity] {
        [
            completed(.walk, minutesFromNow: -520, duration: 35),
            completed(.walk, minutesFromNow: -440, duration: 30),
            completed(.walk, minutesFromNow: -390, duration: 25),
            completed(.running, title: "Core", minutesFromNow: -320, duration: 45),
            completed(.running, title: "Workout", minutesFromNow: recentHardWorkout ? -45 : -240, duration: 60),
            sauna(minutesFromNow: -170, duration: 30),
            completed(.cycling, minutesFromNow: -80, duration: 60)
        ]
    }

    func completed(
        _ kind: ActivityKind,
        title: String? = nil,
        minutesFromNow: Int,
        duration: Int
    ) -> PlannedActivity {
        let activity = plannedActivity(kind, title: title, minutesFromNow: minutesFromNow, duration: duration, completed: true)
        activity.source = "appleWorkout"
        return activity
    }

    func activeActivity(_ kind: ActivityKind) -> PlannedActivity {
        let activity = plannedActivity(kind, minutesFromNow: -5, duration: kind == .walk ? 30 : 60, completed: false)
        activity.source = "today"
        return activity
    }

    func plannedActivity(
        _ kind: ActivityKind,
        title: String? = nil,
        minutesFromNow: Int,
        duration: Int,
        completed: Bool
    ) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: title ?? defaultTitle(for: kind),
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: completed
        )
        switch kind {
        case .cycling:
            activity.type = "cycling"
        case .running:
            activity.type = title == "Core" || title == "Workout" ? "workout" : "running"
        case .walk:
            activity.type = "recovery"
        }
        return activity
    }

    func sauna(minutesFromNow: Int, duration: Int) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: true
        )
        activity.type = "sauna"
        activity.source = "planner"
        return activity
    }

    func tomorrowRecovery(_ title: String, hoursFromStartOfTomorrow hour: Int, duration: Int) -> PlannedActivity {
        let startOfTomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now
        let activity = PlannedActivityBuilder.workout(
            title: title,
            at: Calendar.current.date(byAdding: .hour, value: hour, to: startOfTomorrow) ?? startOfTomorrow,
            durationMinutes: duration
        )
        activity.type = "recovery"
        return activity
    }

    func defaultTitle(for kind: ActivityKind) -> String {
        switch kind {
        case .cycling:
            return "Cycling"
        case .running:
            return "Running"
        case .walk:
            return "Walk"
        }
    }

    func brainState(
        calories: Double,
        protein: Double,
        water: Double,
        activeCalories: Double,
        readiness: HumanBrain.ReadinessState,
        recovery: HumanBrain.RecoveryState
    ) -> HumanBrain.State {
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = Calendar.current.component(.hour, from: now)
        config.hasAnyFoodLogged = calories > 0
        config.energyCoverage = calories / 1_954
        config.caloriesProgress = calories / 1_954
        config.carbsProgress = calories < 700 ? 0.30 : 0.80
        config.waterProgress = water / 3.75
        config.hydration = water / 3.75 >= 0.70 ? .optimal : .behind
        config.fuel = calories / 1_954 < 0.45 ? .underfueled : .good
        config.protein = protein / 153 >= 0.70 ? .good : .low
        config.sleep = .strong
        config.recovery = recovery
        config.readiness = readiness
        config.strain = .veryHigh
        config.completedWorkoutsCount = 4
        config.metrics = CoachMetricsBuilder.metrics(
            protein: protein,
            carbs: calories * 0.12,
            calories: calories,
            waterLiters: water,
            activeCalories: activeCalories,
            sleepHours: 7.02
        )
        return HumanBrainStateBuilder.make(config)
    }

    func nutritionContext(calories: Double, protein: Double, water: Double) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: 1_954,
            proteinCurrent: protein,
            proteinGoal: 153,
            carbsCurrent: calories * 0.12,
            carbsGoal: 189,
            fatsCurrent: calories * 0.02,
            fatsGoal: 65,
            waterCurrent: water,
            waterGoal: 3.75,
            mealsCount: calories > 0 ? 4 : 0,
            lastMealTime: calories / 1_954 >= 0.70 || protein / 153 >= 0.70 ? now.addingTimeInterval(-45 * 60) : nil
        )
    }

    func assertRecoveryStory(_ guidance: CoachGuidanceV3) {
        XCTAssertEqual(guidance.priority.priority, .recovery)
        XCTAssertEqual(guidance.priority.focus, .recoveryNeeded)
        let title = guidance.screenStory?.title ?? guidance.title
        XCTAssertFalse(title.localizedCaseInsensitiveContains("drink water"))
        XCTAssertFalse(title.localizedCaseInsensitiveContains("eat now"))
        XCTAssertFalse(title.localizedCaseInsensitiveContains("day complete"))
    }

    func assertNoFoodOrWaterAction(_ story: CoachScreenStory) {
        let text = actionText(story)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("eat recovery meal"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("add protein"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("refuel"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("drink"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("sip"))
    }

    func containsFoodPrimaryAction(_ story: CoachScreenStory) -> Bool {
        let text = primaryActionText(story)
        return text.localizedCaseInsensitiveContains("eat ") ||
            text.localizedCaseInsensitiveContains("meal") ||
            text.localizedCaseInsensitiveContains("protein") ||
            text.localizedCaseInsensitiveContains("carb") ||
            text.localizedCaseInsensitiveContains("refuel")
    }

    func containsWaterPrimaryAction(_ story: CoachScreenStory) -> Bool {
        let text = primaryActionText(story)
        return text.localizedCaseInsensitiveContains("drink") ||
            text.localizedCaseInsensitiveContains("sip") ||
            text.localizedCaseInsensitiveContains("water") ||
            text.localizedCaseInsensitiveContains("hydrate")
    }

    func assertActive(_ scenario: Scenario, _ contributors: [String]) {
        let expected = "RecoveryContributorDebug.activeContributors=[\(contributors.joined(separator: ","))]"
        XCTAssertTrue(scenario.guidance.priority.reasons.contains(expected), "Missing \(expected) in \(scenario.guidance.priority.reasons)")
    }

    func hasActiveRecoveryContributor(_ guidance: CoachGuidanceV3, _ contributor: String) -> Bool {
        guidance.priority.reasons.contains("contributor=\(contributor)")
    }

    func actionText(_ story: CoachScreenStory) -> String {
        (story.primaryActions + story.supportActions)
            .flatMap { [$0.title, $0.subtitle] }
            .joined(separator: " ")
    }

    func primaryActionText(_ story: CoachScreenStory) -> String {
        story.primaryActions
            .flatMap { [$0.title, $0.subtitle] }
            .joined(separator: " ")
    }

    func actionSignature(_ guidance: CoachGuidanceV3) -> String {
        guidance.screenStory.map(actionText) ?? guidance.supportActions.map(\.title).joined(separator: "|")
    }

    func isFoodOrWaterHero(_ title: String) -> Bool {
        title.localizedCaseInsensitiveContains("drink water") ||
            title.localizedCaseInsensitiveContains("hydrate") ||
            title.localizedCaseInsensitiveContains("eat now") ||
            title.localizedCaseInsensitiveContains("refuel")
    }

    func isActivePhase(_ phase: CoachActivityPhaseV3) -> Bool {
        if case .active = phase {
            return true
        }
        return false
    }
}
