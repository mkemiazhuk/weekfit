import XCTest
@testable import WeekFit

final class CoachDynamicPriorityActionTests: XCTestCase {
    private let now = CoachTestClock.reference

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testUnderfedUnderhydratedHighLoadDayKeepsRecoveryStory() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 2.25)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertFalse(isFoodOrWaterHero(story.title))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        assertActive(scenario, ["underfueled", "proteinBehind"])
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("RecoveryContributorDebug.proteinLevel=actionRequired"))
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
        XCTAssertFalse(after.guidance.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertTrue(after.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]"))
        XCTAssertTrue(after.guidance.priority.reasons.contains("RecoveryContributorDebug.resolvedContributors=[underfueled,hydrationBehind,proteinBehind]"))
        XCTAssertEqual(before.guidance.priority.priority, after.guidance.priority.priority)
        XCTAssertFalse(isFoodOrWaterHero(story.title))
    }

    func testWaterImprovesFoodStillBehindRemovesHydrationContributor() throws {
        let scenario = highLoadScenario(calories: 712, protein: 57, water: 3.00)
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        assertRecoveryStory(scenario.guidance)
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertFalse(scenario.guidance.priority.reasons.contains {
            $0.hasPrefix("RecoveryContributorDebug.activeContributors=") && $0.contains("hydrationBehind")
        })
        assertActive(scenario, ["underfueled", "proteinBehind"])
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
        XCTAssertTrue(actionText(story).localizedCaseInsensitiveContains("fluid") || actionText(story).localizedCaseInsensitiveContains("hydration"))
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

        assertActive(under, ["underfueled", "proteinBehind"])
        assertActive(proteinMeal, [])
        assertActive(water, [])
        assertActive(anotherMeal, [])
        assertActive(deletedMeal, ["underfueled", "proteinBehind"])
        XCTAssertNotEqual(under.fingerprint.rawValue, proteinMeal.fingerprint.rawValue)
        XCTAssertNotEqual(proteinMeal.fingerprint.rawValue, water.fingerprint.rawValue)
        XCTAssertNotEqual(water.fingerprint.rawValue, deletedMeal.fingerprint.rawValue)
    }

    func testHydrationBandsRespectTimeOfDay() {
        let onPaceAtNoon = highLoadScenario(calories: 1_500, protein: 120, water: 1.55, currentHour: 12)
        let meaningfulLate = highLoadScenario(calories: 1_500, protein: 120, water: 2.30, currentHour: 21)
        let actionRequiredLate = highLoadScenario(calories: 1_500, protein: 120, water: 1.30, currentHour: 20)

        assertActive(onPaceAtNoon, [])
        assertLevel(onPaceAtNoon, "hydration", "onTrajectory")
        assertActive(meaningfulLate, ["hydrationBehind"])
        assertLevel(meaningfulLate, "hydration", "meaningfullyBehind")
        assertActive(actionRequiredLate, ["hydrationBehind"])
        assertLevel(actionRequiredLate, "hydration", "actionRequired")
    }

    func testHydrationAboveNinetyDoesNotRecommendMoreWater() throws {
        let scenario = buildScenario(
            activities: [],
            calories: 1_700,
            protein: 130,
            water: 3.50,
            activeCalories: 1_114,
            activityProgress: 1.57,
            exerciseMinutes: 130,
            recoveryPercent: 86,
            readiness: .low,
            recovery: .vulnerable,
            currentHour: 21
        )
        let story = try XCTUnwrap(scenario.guidance.screenStory)

        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=hydrationBehind"))
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("water"))
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("sip"))
        XCTAssertFalse(actionText(story).localizedCaseInsensitiveContains("drink"))
    }

    func testCaloriesDoNotChaseFullActivityReplacementWhenMinimumFuelingIsCovered() {
        let scenario = highLoadScenario(calories: 1_950, protein: 130, water: 3.0, currentHour: 20)

        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("underfueled") })
    }

    func testAdjustedCaloriesDoNotCreateUnderfueledProblemWhenBaseTargetIsMet() {
        let baseGoals = NutritionGoals(calories: 1_850, protein: 150, carbs: 180, fats: 60, fiber: 35, waterLiters: 3.0)
        let adjustedGoals = NutritionGoals(calories: 2_700, protein: 180, carbs: 320, fats: 80, fiber: 35, waterLiters: 3.8)
        let scenario = buildScenario(
            activities: baseHighLoadActivities(recentHardWorkout: true),
            calories: 1_900,
            protein: 150,
            water: 3.3,
            activeCalories: 1_100,
            activityProgress: 1.5,
            exerciseMinutes: 105,
            recoveryPercent: 82,
            readiness: .good,
            recovery: .stable,
            currentHour: 20,
            baseGoals: baseGoals,
            nutritionGoals: adjustedGoals
        )

        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]"))
    }

    func testAdjustedProteinDoesNotCreateProteinProblemWhenCloseToBaseTarget() {
        let baseGoals = NutritionGoals(calories: 1_850, protein: 150, carbs: 180, fats: 60, fiber: 35, waterLiters: 3.0)
        let adjustedGoals = NutritionGoals(calories: 2_700, protein: 180, carbs: 320, fats: 80, fiber: 35, waterLiters: 3.8)
        let scenario = buildScenario(
            activities: baseHighLoadActivities(recentHardWorkout: true),
            calories: 1_900,
            protein: 145,
            water: 3.3,
            activeCalories: 1_100,
            activityProgress: 1.5,
            exerciseMinutes: 105,
            recoveryPercent: 82,
            readiness: .good,
            recovery: .stable,
            currentHour: 20,
            baseGoals: baseGoals,
            nutritionGoals: adjustedGoals
        )

        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]"))
    }

    func testProteinCarriesMoreWeightThanCalories() {
        let scenario = highLoadScenario(calories: 1_500, protein: 70, water: 3.0, currentHour: 14)

        XCTAssertFalse(scenario.guidance.priority.reasons.contains("contributor=underfueled"))
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("contributor=proteinBehind"))
        assertLevel(scenario, "protein", "meaningfullyBehind")
    }

    func testProteinUsesTrajectoryInsteadOfFullDayTarget() {
        let morning = highLoadScenario(calories: 700, protein: 35, water: 1.2, currentHour: 10)
        let afternoon = highLoadScenario(calories: 1_000, protein: 70, water: 2.0, currentHour: 14)
        let evening = highLoadScenario(calories: 1_500, protein: 60, water: 3.3, currentHour: 20)

        assertActive(morning, [])
        assertLevel(morning, "protein", "onTrajectory")
        XCTAssertFalse(morning.guidance.priority.reasons.contains("contributor=proteinBehind"))

        assertActive(afternoon, ["proteinBehind"])
        assertLevel(afternoon, "protein", "meaningfullyBehind")

        XCTAssertTrue(evening.guidance.priority.reasons.contains("contributor=proteinBehind"))
        assertLevel(evening, "protein", "actionRequired")
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

    func testUnstableRecoverySyncPreventsAuthoritativeDayFrame() throws {
        let futureRun = plannedActivity(.running, minutesFromNow: 90, duration: 60, completed: false)
        let scenario = buildScenario(
            activities: [futureRun],
            calories: 1_200,
            protein: 95,
            water: 2.8,
            activeCalories: 620,
            activityProgress: 1.4,
            exerciseMinutes: 55,
            recoveryPercent: 0,
            readiness: .good,
            recovery: .stable,
            sleepHours: 0
        )
        let frame = try XCTUnwrap(scenario.guidance.dayDecisionFrame)

        XCTAssertFalse(frame.contextConfidence.dayLevelIsAuthoritative)
        XCTAssertFalse(frame.shouldOwnNarrative)
        XCTAssertTrue(scenario.guidance.priority.reasons.contains("ContextConfidence.dayLevelIsAuthoritative=false"))
    }

    func testLowActiveCaloriesCannotCreateOverloadFromEstimatedProgress() throws {
        let saunaLater = sauna(minutesFromNow: 90, duration: 25, completed: false)
        let scenario = buildScenario(
            activities: [saunaLater],
            calories: 1_300,
            protein: 115,
            water: 3.0,
            activeCalories: 172,
            activityProgress: 2.1,
            exerciseMinutes: 16,
            recoveryPercent: 89,
            readiness: .good,
            recovery: .stable,
            sleepHours: 7.8
        )

        XCTAssertNotEqual(DayPriorityModel.build(from: scenario.input).dayStressLevel, .overload)
        XCTAssertNotEqual(scenario.guidance.dayDecisionFrame?.dayType, .overload)
    }

    func testStableSaunaIsNotHighRisk() throws {
        let scenario = buildScenario(
            activities: [sauna(minutesFromNow: 60, duration: 25, completed: false)],
            calories: 1_450,
            protein: 120,
            water: 3.1,
            activeCalories: 172,
            activityProgress: 0.35,
            exerciseMinutes: 16,
            recoveryPercent: 89,
            readiness: .good,
            recovery: .stable,
            sleepHours: 7.8
        )
        let risk = try XCTUnwrap(scenario.guidance.dayDecisionFrame?.remainingActivityRisk)

        XCTAssertNotEqual(risk.riskLevel, .high)
        XCTAssertNotEqual(risk.recommendedAction, .shorten)
        XCTAssertNotEqual(risk.maxRecommendedDuration, 10)
    }

    func testSevereHydrationBehindBeforeSaunaOutranksFood() throws {
        let scenario = buildScenario(
            activities: [sauna(minutesFromNow: 20, duration: 25, completed: false)],
            calories: 500,
            protein: 35,
            water: 0.60,
            activeCalories: 172,
            activityProgress: 0.35,
            exerciseMinutes: 16,
            recoveryPercent: 89,
            readiness: .good,
            recovery: .stable,
            sleepHours: 7.8
        )
        let story = try XCTUnwrap(scenario.guidance.screenStory)
        let firstAction = try XCTUnwrap(story.primaryActions.first)

        XCTAssertTrue(firstAction.type.isHydrationAction)
        XCTAssertFalse(firstAction.type.isFoodAction)
    }

    func testRecoveryContributorsDoNotForcePlanReplacement() throws {
        let futureRun = plannedActivity(.running, minutesFromNow: 90, duration: 60, completed: false)
        let scenario = buildScenario(
            activities: [futureRun],
            calories: 500,
            protein: 35,
            water: 1.4,
            activeCalories: 820,
            activityProgress: 1.55,
            exerciseMinutes: 75,
            recoveryPercent: 89,
            readiness: .good,
            recovery: .stable,
            sleepHours: 7.8
        )
        let frame = try XCTUnwrap(scenario.guidance.dayDecisionFrame)

        XCTAssertTrue(frame.contributors.contains(.underfueled))
        XCTAssertTrue(frame.contributors.contains(.hydrationBehind))
        assertLevel(scenario, "hydration", "meaningfullyBehind")
        XCTAssertNotEqual(frame.primaryDriver, .lowRecovery)
        XCTAssertNotEqual(frame.planStatus, .replace)
    }

    func testMajorScenarioReasoningTracesStayExplainable() throws {
        let stableOpenDay = buildScenario(
            activities: [],
            calories: 1_450,
            protein: 120,
            water: 3.1,
            activeCalories: 140,
            activityProgress: 0.22,
            exerciseMinutes: 18,
            recoveryPercent: 84,
            readiness: .good,
            recovery: .stable
        )
        assertTrace(stableOpenDay, name: "stable open day")
        XCTAssertFalse(stableOpenDay.guidance.priority.reasons.contains("contributor=hydrationBehind"))

        let walkSaunaWalk = buildScenario(
            activities: [
                plannedActivity(.walk, minutesFromNow: 60, duration: 30, completed: false),
                sauna(minutesFromNow: 180, duration: 25, completed: false),
                plannedActivity(.walk, minutesFromNow: 300, duration: 30, completed: false)
            ],
            calories: 1_250,
            protein: 112,
            water: 3.0,
            activeCalories: 120,
            activityProgress: 0.20,
            exerciseMinutes: 15,
            recoveryPercent: 82,
            readiness: .good,
            recovery: .stable
        )
        assertTrace(walkSaunaWalk, name: "walk + sauna + walk")
        XCTAssertNotEqual(DayPriorityModel.build(from: walkSaunaWalk.input).dayGoal, .performance)

        let activeWorkout = highLoadScenario(calories: 1_500, protein: 120, water: 3.0, active: .cycling)
        assertTrace(activeWorkout, name: "active workout")
        XCTAssertTrue(isActivePhase(activeWorkout.guidance.phase))
        XCTAssertTrue(activeWorkout.guidance.supportActions.allSatisfy { $0.actionProvenance == .activeSessionExecution })

        let activeRecovery = highLoadScenario(calories: 1_500, protein: 120, water: 3.0, active: .walk)
        assertTrace(activeRecovery, name: "active recovery")
        XCTAssertTrue(isActivePhase(activeRecovery.guidance.phase))
        XCTAssertNotEqual(try XCTUnwrap(activeRecovery.guidance.screenStory).title, "The work is in the bank")

        let completedHardWorkout = highLoadScenario(calories: 1_700, protein: 130, water: 3.0, recentHardWorkout: true)
        assertTrace(completedHardWorkout, name: "completed hard workout")
        XCTAssertTrue(completedHardWorkout.input.dayContext.completedTrainingActivities.isEmpty == false)

        let highHealthKitNoMatch = buildScenario(
            activities: [],
            calories: 1_400,
            protein: 120,
            water: 3.0,
            activeCalories: 1_050,
            activityProgress: 1.75,
            exerciseMinutes: 95,
            recoveryPercent: 78,
            readiness: .good,
            recovery: .stable
        )
        assertTrace(highHealthKitNoMatch, name: "high HealthKit load with no matched activity")
        XCTAssertTrue(highHealthKitNoMatch.guidance.priority.reasons.contains { $0.contains("highActiveCalories") })
        XCTAssertTrue(highHealthKitNoMatch.guidance.priority.reasons.contains("CoachLoadSourceDebug.loadSourceUsed=healthKitSamplesWithAppGoalEstimate"))

        let futureHardLowRecovery = trainingSoonScenario(
            calories: 900,
            protein: 80,
            water: 2.8,
            futureKind: .running,
            recoveryPercent: 48,
            sleepHours: 5.2
        )
        assertTrace(futureHardLowRecovery, name: "future hard workout + low sleep/recovery")
        XCTAssertTrue(futureHardLowRecovery.guidance.priority.reasons.contains { $0.localizedCaseInsensitiveContains("sleep") || $0.localizedCaseInsensitiveContains("recovery") })

        let hydrationUnresolved = highLoadScenario(calories: 1_500, protein: 120, water: 2.3)
        let hydrationResolved = highLoadScenario(calories: 1_500, protein: 120, water: 3.1)
        assertTrace(hydrationUnresolved, name: "hydration unresolved")
        assertTrace(hydrationResolved, name: "hydration resolved")
        assertActive(hydrationUnresolved, [])
        XCTAssertTrue(hydrationUnresolved.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("hydrationBehind") })
        XCTAssertTrue(hydrationResolved.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("hydrationBehind") })
        XCTAssertFalse(try XCTUnwrap(hydrationResolved.guidance.screenStory).primaryActions.contains { $0.type.isHydrationAction })

        let foodUnresolved = highLoadScenario(calories: 650, protein: 45, water: 3.1, currentHour: 20)
        let foodResolved = highLoadScenario(calories: 1_600, protein: 130, water: 3.1)
        assertTrace(foodUnresolved, name: "food unresolved")
        XCTAssertFalse(foodResolved.guidance.title.isEmpty)
        XCTAssertTrue(foodUnresolved.guidance.priority.reasons.contains("contributor=proteinBehind"))
        assertLevel(foodUnresolved, "protein", "actionRequired")
        XCTAssertTrue(foodResolved.guidance.priority.reasons.contains { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") && $0.contains("proteinBehind") })
        XCTAssertFalse(try XCTUnwrap(foodResolved.guidance.screenStory).primaryActions.contains { $0.type.isFoodAction })

        let afterMidnight = afterMidnightScenario()
        assertTrace(afterMidnight, name: "late evening / after midnight")
        XCTAssertTrue(afterMidnight.guidance.title.isEmpty == false)
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
        recentHardWorkout: Bool = false,
        currentHour: Int? = nil
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
            recovery: active == nil ? .vulnerable : .compromised,
            currentHour: currentHour
        )
    }

    func trainingSoonScenario(
        calories: Double,
        protein: Double,
        water: Double,
        futureKind: ActivityKind,
        recoveryPercent: Int = 82,
        sleepHours: Double = 7.02
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
            recoveryPercent: recoveryPercent,
            readiness: .good,
            recovery: recoveryPercent < 60 ? .compromised : .stable,
            sleepHours: sleepHours
        )
    }

    func afterMidnightScenario() -> Scenario {
        buildScenario(
            activities: [sauna(minutesFromNow: -10, duration: 20)],
            calories: 0,
            protein: 0,
            water: 0,
            activeCalories: 80,
            activityProgress: 0.12,
            exerciseMinutes: 8,
            recoveryPercent: 74,
            readiness: .good,
            recovery: .stable,
            sleepHours: 0,
            currentHour: 1
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
        recovery: HumanBrain.RecoveryState,
        sleepHours: Double = 7.02,
        currentHour: Int? = nil,
        baseGoals: NutritionGoals? = nil,
        nutritionGoals: NutritionGoals? = nil
    ) -> Scenario {
        let nutrition = nutritionContext(calories: calories, protein: protein, water: water, goals: nutritionGoals)
        let brain = brainState(
            calories: calories,
            protein: protein,
            water: water,
            activeCalories: activeCalories,
            readiness: readiness,
            recovery: recovery,
            sleepHours: sleepHours,
            currentHour: currentHour,
            baseGoals: baseGoals
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
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
        let recoveryContext = CoachRecoveryContext(recoveryPercent: recoveryPercent, sleepHours: sleepHours)
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

    func sauna(minutesFromNow: Int, duration: Int, completed: Bool = true) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: now.addingTimeInterval(TimeInterval(minutesFromNow * 60)),
            durationMinutes: duration,
            completed: completed
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
        recovery: HumanBrain.RecoveryState,
        sleepHours: Double = 7.02,
        currentHour: Int? = nil,
        baseGoals: NutritionGoals? = nil
    ) -> HumanBrain.State {
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = currentHour ?? Calendar.current.component(.hour, from: now)
        config.hasAnyFoodLogged = calories > 0
        config.energyCoverage = calories / 1_954
        config.caloriesProgress = calories / 1_954
        config.carbsProgress = calories < 700 ? 0.30 : 0.80
        config.waterProgress = water / 3.75
        config.hydration = water / 3.75 >= 0.70 ? .optimal : .behind
        config.fuel = calories / 1_954 < 0.45 ? .underfueled : .good
        config.protein = protein / 153 >= 0.70 ? .good : .low
        config.goals = baseGoals ?? NutritionGoals(
            calories: 1_954,
            protein: 153,
            carbs: 189,
            fats: 65,
            fiber: 35,
            waterLiters: 3.75
        )
        config.sleep = sleepHours <= 0 ? .unknown : (sleepHours < 6 ? .veryShort : .strong)
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
            sleepHours: sleepHours
        )
        return HumanBrainStateBuilder.make(config)
    }

    func nutritionContext(
        calories: Double,
        protein: Double,
        water: Double,
        goals: NutritionGoals? = nil
    ) -> CoachNutritionContext {
        let resolvedGoals = goals ?? NutritionGoals(
            calories: 1_954,
            protein: 153,
            carbs: 189,
            fats: 65,
            fiber: 35,
            waterLiters: 3.75
        )
        return CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: resolvedGoals.calories,
            proteinCurrent: protein,
            proteinGoal: resolvedGoals.protein,
            carbsCurrent: calories * 0.12,
            carbsGoal: resolvedGoals.carbs,
            fatsCurrent: calories * 0.02,
            fatsGoal: resolvedGoals.fats,
            waterCurrent: water,
            waterGoal: resolvedGoals.waterLiters,
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

    func assertLevel(_ scenario: Scenario, _ domain: String, _ level: String) {
        let expected = "RecoveryContributorDebug.\(domain)Level=\(level)"
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

    func assertTrace(_ scenario: Scenario, name: String) {
        XCTAssertEqual(scenario.input.actualLoad.source, .healthKitSamplesWithAppGoalEstimate, name)
        XCTAssertFalse(scenario.input.dayContext.allActivities.contains { $0.title.isEmpty }, name)
        XCTAssertFalse(scenario.guidance.priority.reasons.isEmpty, name)
        XCTAssertFalse(scenario.guidance.title.isEmpty, name)
        XCTAssertFalse(scenario.guidance.message.isEmpty, name)
        XCTAssertNotNil(scenario.guidance.screenStory, name)
        let visibleActions = scenario.guidance.supportActions
        XCTAssertTrue(
            visibleActions.allSatisfy { action in
                !action.title.isEmpty && !action.subtitle.isEmpty
            },
            name
        )
    }
}

private extension CoachSupportActionTypeV3 {
    var isHydrationAction: Bool {
        switch self {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return true
        default:
            return false
        }
    }

    var isFoodAction: Bool {
        switch self {
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal, .keepDigestionLight:
            return true
        default:
            return false
        }
    }
}
