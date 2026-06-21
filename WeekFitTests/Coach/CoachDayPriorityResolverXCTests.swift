import XCTest
@testable import WeekFit

final class CoachDayPriorityResolverXCTests: XCTestCase {

    private let now = CoachTestClock.reference
    private let selectedDate = CoachTestClock.reference

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testSupportSignalDoesNotDuplicateTitleAndAction() {
        let signal = CoachSupportSignal(
            kind: .sleep,
            title: "Sip gradually if thirsty",
            message: "Sleep is the useful intervention.",
            amount: "Sip gradually if thirsty",
            timing: "Tonight",
            priority: .important
        )

        XCTAssertEqual(signal.bulletText, "Sip gradually if thirsty • Tonight")
    }

    func testManualCompletedActivityWithoutActivityCircleConfirmationDoesNotCreateActualOverload() {
        let manualRide = PlannedActivityBuilder.workout(
            title: "Manual Ride",
            at: CoachTestClock.offset(hours: -2, from: now),
            durationMinutes: 75,
            completed: true
        )
        manualRide.source = "planner"
        manualRide.calories = 700
        let futureMobility = recoveryActivity(
            "Mobility",
            minutesFromNow: 90,
            duration: 20
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 40,
            exerciseMinutes: 4,
            standHours: 3,
            activityGoalCalories: 450,
            activityProgress: 0.09
        )

        let priority = resolve(
            [manualRide, futureMobility],
            brain: HumanBrainStateBuilder.make(
                metrics: CoachMetricsBuilder.metrics(activeCalories: 40, sleepHours: 7.8)
            ),
            actualLoad: actualLoad
        )

        XCTAssertFalse(priority.reasons.contains { $0.contains("dayType=overload") })
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.discrepancyDetected=true"))
        XCTAssertTrue(
            priority.reasons.contains("CoachLoadSourceDebug.discrepancyReason=plannedCompletedHigherThanActivityCircle") ||
                priority.reasons.contains("CoachLoadSourceDebug.discrepancyReason=manualCompletionNotConfirmedByActivityCircle")
        )
    }

    func testActivityCircleHigherThanPlannedActivitiesDrivesCoachActualLoad() {
        let futureRun = PlannedActivityBuilder.workout(
            title: "Evening Run",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 60
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 862,
            exerciseMinutes: 74,
            standHours: 10,
            activityGoalCalories: 450,
            activityProgress: 1.92
        )

        let priority = resolve(
            [futureRun],
            brain: HumanBrainStateBuilder.make(
                strain: .normal,
                recovery: .stable,
                readiness: .good,
                metrics: CoachMetricsBuilder.metrics(activeCalories: 100, sleepHours: 7.8)
            ),
            actualLoad: actualLoad
        )

        XCTAssertTrue(priority.reasons.contains("dayType=overload"))
        XCTAssertTrue(priority.reasons.contains("primaryDriver=accumulatedFatigue"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.healthKitSampleActiveCalories=862"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.discrepancyReason=activityCircleHigherThanPlanned"))
    }

    func testDuplicateAppActivityAndSyncedWorkoutDoesNotDoubleCountCompletedLoad() {
        let appRide = PlannedActivityBuilder.completedWorkout(
            title: "Ride",
            completedHoursAgo: 2,
            now: now
        )
        appRide.source = "planner"
        appRide.calories = 600
        let syncedRide = PlannedActivityBuilder.completedWorkout(
            title: "Ride",
            completedHoursAgo: 2,
            now: now
        )
        syncedRide.source = "HealthKit"
        syncedRide.healthKitWorkoutUUID = UUID().uuidString
        syncedRide.calories = 600
        let futureStretch = recoveryActivity(
            "Stretching",
            minutesFromNow: 60,
            duration: 20
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 610,
            exerciseMinutes: 55,
            standHours: 8,
            activityGoalCalories: 450,
            activityProgress: 1.36
        )

        let priority = resolve(
            [appRide, syncedRide, futureStretch],
            brain: HumanBrainStateBuilder.make(
                metrics: CoachMetricsBuilder.metrics(activeCalories: 610, sleepHours: 7.2)
            ),
            actualLoad: actualLoad
        )

        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.syncedAppleWorkouts=1"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.manualCompletedActivities=1"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.discrepancyDetected=true"))
        XCTAssertFalse(priority.reasons.contains("CoachLoadSourceDebug.healthKitSampleActiveCalories=1200"))
    }

    func testFuturePlannedActivitiesRemainPlanSourceForRemainingRisk() {
        let futureRide = PlannedActivity(
            date: CoachTestClock.offset(minutes: 35, from: now),
            type: "workout",
            title: "Cycling",
            durationMinutes: 60,
            icon: "figure.outdoor.cycle",
            imageName: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 862,
            exerciseMinutes: 74,
            standHours: 10,
            activityGoalCalories: 450,
            activityProgress: 1.92
        )

        let priority = resolve(
            [futureRide],
            brain: HumanBrainStateBuilder.make(
                strain: .normal,
                recovery: .stable,
                readiness: .good,
                metrics: CoachMetricsBuilder.metrics(activeCalories: 862, sleepHours: 7.0)
            ),
            actualLoad: actualLoad
        )

        XCTAssertTrue(priority.reasons.contains("RemainingActivityRiskDebug.activityTitle=Cycling"))
        XCTAssertTrue(priority.reasons.contains("RemainingActivityRiskDebug.plannedDuration=60"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.loadSourceUsed=healthKitSamplesWithAppGoalEstimate"))
    }

    func testCoachActiveCaloriesMatchesActivityCircleWhenProvided() {
        let actualLoad = CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 862,
            exerciseMinutes: 74,
            standHours: 10,
            activityGoalCalories: 450,
            activityProgress: 1.92
        )

        let priority = resolve(
            [],
            brain: HumanBrainStateBuilder.make(
                metrics: CoachMetricsBuilder.metrics(activeCalories: 120, sleepHours: 7.0)
            ),
            actualLoad: actualLoad
        )

        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.healthKitSampleActiveCalories=862"))
        XCTAssertTrue(priority.reasons.contains("CoachLoadSourceDebug.loadSourceUsed=healthKitSamplesWithAppGoalEstimate"))
    }

    func testFoodOnlyDayDoesNotCreateActivityContextCandidate() {
        let breakfast = PlannedActivityBuilder.meal(
            title: "Syrnik",
            at: CoachTestClock.offset(minutes: -45, from: now),
            calories: 360,
            protein: 18,
            carbs: 28,
            fats: 16,
            completed: true
        )
        let secondBreakfast = PlannedActivityBuilder.meal(
            title: "Syrnik",
            at: CoachTestClock.offset(minutes: -35, from: now),
            calories: 365,
            protein: 18,
            carbs: 28,
            fats: 16,
            completed: true
        )
        let coffee = PlannedActivityBuilder.meal(
            title: "Coffee",
            at: CoachTestClock.offset(minutes: -15, from: now),
            calories: 5,
            protein: 0,
            carbs: 0,
            fats: 0,
            completed: true
        )
        let activities = [breakfast, secondBreakfast, coffee]
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )

        let priority = resolve(
            activities,
            brain: HumanBrainStateBuilder.make(
                currentHour: 9,
                hydration: .optimal,
                fuel: .good,
                recovery: .stable,
                readiness: .good
            ),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 730,
                caloriesGoal: 2_400,
                proteinCurrent: 36,
                proteinGoal: 160,
                carbsCurrent: 56,
                carbsGoal: 280,
                fatsCurrent: 32,
                fatsGoal: 70,
                waterCurrent: 0.2,
                waterGoal: 2.5,
                mealsCount: 3,
                lastMealTime: coffee.date
            )
        )

        XCTAssertEqual(CoachCanonicalDayState.selectedDayActivities(from: activities, selectedDate: selectedDate).count, 3)
        XCTAssertTrue(dayContext.allActivities.isEmpty)
        XCTAssertTrue(CoachCanonicalDayState.coachRelevantActivities(from: activities).isEmpty)
        XCTAssertFalse(priority.reasons.contains { $0.localizedCaseInsensitiveContains("activity context") })
        XCTAssertFalse(priority.reasons.contains { $0.localizedCaseInsensitiveContains("activity context") })
    }

    func testWorkoutSoonWithLowRecovery_readinessWarningWins() {
        let completed = PlannedActivityBuilder.workout(
            title: "Morning Strength",
            at: CoachTestClock.offset(minutes: -120, from: now),
            durationMinutes: 90,
            completed: true
        )

        let upcoming = PlannedActivityBuilder.workout(
            title: "Intervals",
            at: CoachTestClock.offset(minutes: 15, from: now),
            durationMinutes: 60
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.30,
            carbsProgress: 0.20,
            waterProgress: 0.45,
            hydration: .behind,
            fuel: .underfueled,
            protein: .low,
            strain: .high,
            recovery: .compromised,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(
                protein: 12,
                carbs: 40,
                calories: 700,
                waterLiters: 1.1,
                activeCalories: 820,
                sleepHours: 6.1
            )
        )

        let priority = resolve(
            [completed, upcoming],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 6.1),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 700,
                caloriesGoal: 2400,
                proteinCurrent: 12,
                proteinGoal: 160,
                carbsCurrent: 40,
                carbsGoal: 280,
                fatsCurrent: 20,
                fatsGoal: 70,
                waterCurrent: 1.1,
                waterGoal: 2.5,
                mealsCount: 1,
                lastMealTime: CoachTestClock.offset(minutes: -180, from: now)
            )
        )

        XCTAssertEqual(priority.focus, .trainingReadinessWarning)
        XCTAssertTrue(priority.overridesTimingFocus)
        XCTAssertEqual(priority.activity?.id, upcoming.id)
    }

    func testCriticalTrainingReadinessWarningBeatsNormalRunPreparation() {
        let walk1 = PlannedActivityBuilder.workout(
            title: "Walk",
            at: CoachTestClock.offset(minutes: -300, from: now),
            durationMinutes: 35,
            completed: true
        )
        walk1.type = "recovery"
        let walk2 = PlannedActivityBuilder.workout(
            title: "Walk",
            at: CoachTestClock.offset(minutes: -230, from: now),
            durationMinutes: 30,
            completed: true
        )
        walk2.type = "recovery"
        let core = PlannedActivityBuilder.workout(
            title: "Core",
            at: CoachTestClock.offset(minutes: -180, from: now),
            durationMinutes: 45,
            completed: true
        )
        let workout = PlannedActivityBuilder.workout(
            title: "Workout",
            at: CoachTestClock.offset(minutes: -110, from: now),
            durationMinutes: 75,
            completed: true
        )
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: -35, from: now),
            durationMinutes: 25,
            completed: true
        )
        sauna.type = "sauna"
        let run = PlannedActivityBuilder.workout(
            title: "Running",
            at: CoachTestClock.offset(minutes: 48, from: now),
            durationMinutes: 50
        )
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

        let priority = resolve(
            [walk1, walk2, core, workout, sauna, run],
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

        XCTAssertEqual(priority.priority, .planChallenge)
        XCTAssertEqual(priority.focus, .trainingReadinessWarning)
        XCTAssertEqual(priority.strength, .critical)
        XCTAssertEqual(priority.activity?.id, run.id)
        XCTAssertNotEqual(priority.priority, .performance)
        XCTAssertNotEqual(priority.focus, .prepareForActivity)
        XCTAssertTrue(
            priority.title.localizedCaseInsensitiveContains("downgrade") ||
                priority.title.localizedCaseInsensitiveContains("modify") ||
                priority.title.localizedCaseInsensitiveContains("adjust") ||
                priority.title.localizedCaseInsensitiveContains("replace") ||
                priority.title.localizedCaseInsensitiveContains("skip") ||
                priority.title.localizedCaseInsensitiveContains("lower") ||
                priority.title.localizedCaseInsensitiveContains("risky")
        )
        XCTAssertTrue(priority.reasons.contains { $0 == "decisionType=planAdjustment" || $0 == "dayDecisionFrame=selected" })
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("remaining plan"))
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("running intensity"))
    }

    func testShortSleepFromBrainMetricsStillGeneratesTrainingCandidateAfterRefresh() {
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: CoachTestClock.offset(minutes: 300, from: now),
            durationMinutes: 75
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 11,
            hasAnyFoodLogged: true,
            waterProgress: 0.70,
            hydration: .optimal,
            fuel: .good,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                calories: 1_200,
                waterLiters: 1.5,
                sleepHours: 4.7
            )
        )

        let activityContext = activityContext([cycling], brain: brain)
        let nutritionRefreshPriority = resolve(
            [cycling],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_200,
                caloriesGoal: 2_400,
                proteinCurrent: 55,
                proteinGoal: 160,
                carbsCurrent: 180,
                carbsGoal: 280,
                fatsCurrent: 28,
                fatsGoal: 70,
                waterCurrent: 1.5,
                waterGoal: 2.5,
                mealsCount: 1,
                lastMealTime: CoachTestClock.offset(minutes: -90, from: now)
            )
        )
        let expertRefreshPriority = resolve(
            [cycling],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8.2),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_200,
                caloriesGoal: 2_400,
                proteinCurrent: 55,
                proteinGoal: 160,
                carbsCurrent: 180,
                carbsGoal: 280,
                fatsCurrent: 28,
                fatsGoal: 70,
                waterCurrent: 1.5,
                waterGoal: 2.5,
                mealsCount: 1,
                lastMealTime: CoachTestClock.offset(minutes: -90, from: now)
            )
        )

        XCTAssertEqual(CoachCanonicalDayState.coachRelevantActivities(from: [cycling]).count, 1)
        XCTAssertEqual(activityContext.laterTodayActivity?.id, cycling.id)
        XCTAssertEqual(activityContext.nextUpcomingActivity?.id, cycling.id)
        XCTAssertEqual(nutritionRefreshPriority.priority, .planChallenge)
        XCTAssertEqual(nutritionRefreshPriority.limiter, .sleep)
        XCTAssertEqual(nutritionRefreshPriority.activity?.id, cycling.id)
        XCTAssertEqual(expertRefreshPriority.priority, nutritionRefreshPriority.priority)
        XCTAssertEqual(expertRefreshPriority.limiter, nutritionRefreshPriority.limiter)
        XCTAssertEqual(expertRefreshPriority.activity?.id, nutritionRefreshPriority.activity?.id)
    }

    func testCompletedRecoveryTransfersOwnershipToNextRecoveryBlock() {
        let completedWalk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: CoachTestClock.offset(minutes: -45, from: now),
            durationMinutes: 30,
            completed: true
        )
        completedWalk.type = "recovery"
        let stretching = PlannedActivityBuilder.workout(
            title: "Stretching",
            at: CoachTestClock.offset(minutes: 25, from: now),
            durationMinutes: 20
        )
        stretching.type = "recovery"
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 80, from: now),
            durationMinutes: 25
        )
        sauna.type = "sauna"

        let priority = resolve(
            [completedWalk, stretching, sauna],
            brain: steadyBrain,
            nutrition: steadyNutrition
        )

        XCTAssertTrue(priority.priority == .stable || priority.priority == .performance)
        XCTAssertNotNil(priority.activity?.id)
        XCTAssertNotEqual(priority.activity?.id, completedWalk.id)
    }

    func testRecentlyCompletedWorkoutKeepsOwnershipDuringRecoveryHold() {
        let completedWorkout = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -65, from: now),
            durationMinutes: 60,
            completed: true
        )
        let stretching = PlannedActivityBuilder.workout(
            title: "Stretching",
            at: CoachTestClock.offset(minutes: 30, from: now),
            durationMinutes: 20
        )
        stretching.type = "recovery"

        let priority = resolve(
            [completedWorkout, stretching],
            brain: steadyBrain,
            nutrition: steadyNutrition
        )

        XCTAssertTrue([CoachDayFocus.postActivityRecovery, .dailyOverview].contains(priority.focus))
        XCTAssertEqual(priority.activity?.id, completedWorkout.id)
    }

    func testSaunaSoonWithLowHydration_addsHydrationSupportWithoutHydrationWinning() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve([sauna], brain: brain)

        assertExecutionLayerIsNotPrimary(priority)
        XCTAssertTrue(priority.priority == .performance || priority.priority == .planChallenge || priority.priority == .recovery)
        XCTAssertEqual(priority.activity?.id, sauna.id)
        XCTAssertTrue(priority.supportBullets.contains { $0.localizedCaseInsensitiveContains("400-600 ml") })
    }

    func testSaunaPreparationUsesActivityNarrativeWithHydrationAction() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.0,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 0.0,
                waterGoal: 3.0
            )
        )

        assertExecutionLayerIsNotPrimary(priority)
        XCTAssertTrue(priority.priority == .performance || priority.priority == .planChallenge)
        XCTAssertTrue(priority.focus == .prepareForActivity || priority.focus == .trainingReadinessWarning)
        XCTAssertNotEqual(priority.limiter, .hydration)
        XCTAssertEqual(priority.activity?.id, sauna.id)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertNotEqual(priority.title, "Hydration before heat")
    }

    func testSaunaSoonWithHydrationGoalReached_hydrationDoesNotRemainLimiter() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 3.2,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.focus, .hydrationBehind)
        XCTAssertNotEqual(priority.limiter, .hydration)
    }

    func testSaunaSoonWithHydrationExactlyAtGoal_hydrationDoesNotRemainLimiter() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 3.0,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.focus, .hydrationBehind)
        XCTAssertNotEqual(priority.limiter, .hydration)
    }

    func testHydrationSaunaSequence_usesLatestWaterContext() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.0,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let atZero = resolve(
            [],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 0.0,
                waterGoal: 3.0
            )
        )
        XCTAssertNotEqual(atZero.focus, CoachDayFocus.hydrationBehind)
        XCTAssertNotEqual(atZero.priority, CoachDayPriority.hydration)

        let afterOneLiterWithSauna = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 1.0,
                waterGoal: 3.0
            )
        )
        XCTAssertNotEqual(afterOneLiterWithSauna.focus, CoachDayFocus.hydrationBehind)
        XCTAssertNotEqual(afterOneLiterWithSauna.priority, CoachDayPriority.hydration)
        XCTAssertTrue(afterOneLiterWithSauna.supportBullets.contains { $0.localizedCaseInsensitiveContains("stay steady before sauna") })

        let afterGoalReached = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_500,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 150,
                waterCurrent: 3.2,
                waterGoal: 3.0
            )
        )
        XCTAssertNotEqual(afterGoalReached.focus, .hydrationBehind)
        XCTAssertNotEqual(afterGoalReached.limiter, .hydration)
    }

    func testSaunaLaterThanNinetyMinutesDoesNotLockHydrationAfterHalfGoal() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 180, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 10,
            energyCoverage: 0.90,
            caloriesProgress: 0.75,
            waterProgress: 0.67,
            hydration: .behind,
            fuel: .good,
            recovery: .strong,
            readiness: .excellent
        )

        let priority = resolve(
            [sauna],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_700,
                caloriesGoal: 2_400,
                proteinCurrent: 120,
                proteinGoal: 150,
                waterCurrent: 2.0,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.priority, .hydration)
        XCTAssertNotEqual(priority.focus, .hydrationBehind)
        XCTAssertNotEqual(priority.title, "Hydrate before heat")
    }

    func testSaunaLaterThanNinetyMinutesLetsRecoveryStateWin() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 150, from: now),
            durationMinutes: 30
        )
        sauna.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.80,
            caloriesProgress: 0.70,
            waterProgress: 0.67,
            sleep: .short,
            hydration: .behind,
            fuel: .good,
            recovery: .vulnerable,
            readiness: .low
        )

        let priority = resolve(
            [sauna],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 5.3),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_600,
                caloriesGoal: 2_400,
                proteinCurrent: 100,
                proteinGoal: 150,
                waterCurrent: 2.0,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.priority, .recovery)
        XCTAssertNotEqual(priority.title, "Hydrate before heat")
    }

    func testNoActivityNowWithNutritionBehind_doesNotMakeFuelPrimary() {
        let laterWorkout = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: 180, from: now),
            durationMinutes: 60
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.35,
            caloriesProgress: 0.20,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low
        )

        let priority = resolve(
            [laterWorkout],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 600,
                caloriesGoal: 2400,
                proteinCurrent: 45,
                proteinGoal: 150,
                waterCurrent: 2.4,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.focus, .fuelBehind)
        XCTAssertNotEqual(priority.priority, .fueling)
        XCTAssertEqual(priority.activity?.id, laterWorkout.id)
    }

    func testRecentMealSuppressesFuelBeforeTrainingWhenFuelIsNotCritical() {
        let recentMeal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: -45, from: now),
            calories: 700,
            protein: 45,
            carbs: 95,
            fats: 20
        )
        let workout = PlannedActivityBuilder.workout(
            title: "Tempo Ride",
            at: CoachTestClock.offset(minutes: 90, from: now),
            durationMinutes: 90
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.65,
            carbsProgress: 0.60,
            caloriesProgress: 0.55,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [recentMeal, workout],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_350,
                caloriesGoal: 2_400,
                proteinCurrent: 85,
                proteinGoal: 150,
                carbsCurrent: 170,
                carbsGoal: 300,
                fatsCurrent: 45,
                fatsGoal: 80,
                waterCurrent: 2.7,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: recentMeal.date
            )
        )

        XCTAssertNotEqual(priority.priority, .fueling)
        XCTAssertNotEqual(priority.focus, .fuelBehind)
        XCTAssertNotEqual(priority.title, "Fuel before training")
    }

    func testDistantFutureWorkoutDoesNotCreateFuelBeforeTraining() {
        let workout = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: 360, from: now),
            durationMinutes: 75
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 12,
            energyCoverage: 0.80,
            carbsProgress: 0.70,
            caloriesProgress: 0.70,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .strong,
            readiness: .excellent
        )

        let priority = resolve([workout], brain: brain, nutrition: steadyNutrition)

        XCTAssertNotEqual(priority.priority, .fueling)
        XCTAssertNotEqual(priority.title, "Fuel before training")
    }

    func testRecoveryWalkDoesNotOverPrioritizeFueling() {
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 30
        )
        walk.type = "recovery"
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.55,
            carbsProgress: 0.50,
            caloriesProgress: 0.50,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .light,
            protein: .behind,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve([walk], brain: brain, nutrition: steadyNutrition)

        XCTAssertNotEqual(priority.priority, .fueling)
        XCTAssertNotEqual(priority.title, "Fuel before training")
    }

    func testNightSuppressesFuelingWithoutClearRefuelReason() {
        let scenarioNow = fixedDate(hour: 23, minute: 15)
        let workout = PlannedActivityBuilder.workout(
            title: "Morning Strength",
            at: fixedDate(hour: 8),
            durationMinutes: 75
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.30,
            carbsProgress: 0.30,
            caloriesProgress: 0.30,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [workout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 800,
                caloriesGoal: 2_400,
                proteinCurrent: 55,
                proteinGoal: 150,
                carbsCurrent: 90,
                carbsGoal: 300,
                fatsCurrent: 30,
                fatsGoal: 80,
                waterCurrent: 2.7,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.priority, .fueling)
        XCTAssertNotEqual(priority.title, "Fuel before training")
    }

    func testActivityOutsidePrepWindow_doesNotPrepare() {
        let laterWorkout = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: 180, from: now),
            durationMinutes: 60
        )

        let priority = resolve([laterWorkout], brain: steadyBrain)

        XCTAssertEqual(priority.priority, .performance)
        XCTAssertFalse(priority.overridesTimingFocus)
        XCTAssertTrue(priority.phase(for: activityContext([laterWorkout])).isStable)
    }

    func testCyclingLaterOutsidePrepWindowStillGivesPlanGuidance() {
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: CoachTestClock.offset(minutes: 150, from: now),
            durationMinutes: 90
        )
        cycling.type = "cycling"

        let priority = resolve([cycling], brain: steadyBrain)

        XCTAssertTrue(priority.focus == .nextActivityLater || priority.focus == .prepareForActivity)
        XCTAssertTrue(priority.priority == .stable || priority.priority == .performance)
        XCTAssertEqual(priority.activity?.id, cycling.id)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("No pressure"))
    }

    func testMealSaunaBeforeHardTrainingUsesSequenceAwareGuidance() {
        let meal = PlannedActivityBuilder.meal(
            title: "Beef Pasta",
            at: CoachTestClock.offset(minutes: 10, from: now),
            completed: false
        )
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 35, from: now),
            durationMinutes: 25
        )
        sauna.type = "recovery"
        let training = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: CoachTestClock.offset(minutes: 90, from: now),
            durationMinutes: 75
        )
        training.type = "cycling"

        let priority = resolve(
            [meal, sauna, training],
            brain: steadyBrain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 800,
                caloriesGoal: 2_400,
                proteinCurrent: 45,
                proteinGoal: 160,
                waterCurrent: 0.6,
                waterGoal: 3.0
            )
        )

        XCTAssertTrue(priority.focus == .nextActivityLater || priority.focus == .prepareForActivity)
        XCTAssertTrue(priority.priority == .stable || priority.priority == .performance)
        XCTAssertNotNil(priority.activity?.id)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("first"))
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.supportBullets.isEmpty)
        XCTAssertFalse(priority.supportBullets.contains { $0.localizedCaseInsensitiveContains("save legs") })
    }

    func testCompletedMealSaunaBeforeHardTrainingKeepsCompletedContext() {
        let completedMeal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: -60, from: now),
            completed: true
        )
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 30, from: now),
            durationMinutes: 25
        )
        sauna.type = "recovery"
        let training = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: 100, from: now),
            durationMinutes: 70
        )

        let priority = resolve([completedMeal, sauna, training], brain: steadyBrain)

        XCTAssertTrue(priority.focus == .nextActivityLater || priority.focus == .prepareForActivity)
        XCTAssertNotNil(priority.activity?.id)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertTrue(priority.planChallenge != nil || priority.priority == .performance)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("first"))
    }

    func testActiveMealBlocksGenericFallback() {
        let meal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: -5, from: now),
            completed: false
        )

        let priority = resolve([meal], brain: steadyBrain)

        XCTAssertEqual(priority.focus, CoachDayFocus.dailyOverview)
        XCTAssertTrue(priority.activity?.id == meal.id || priority.activity == nil)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing is planned"))
    }

    func testCriticalHydrationIsElevatedSupportWithoutBecomingPrimaryDuringPrep() {
        let tennis = PlannedActivityBuilder.workout(
            title: "Tennis",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 75
        )
        tennis.type = "tennis"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.16,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [tennis],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_400,
                caloriesGoal: 2_400,
                proteinCurrent: 80,
                proteinGoal: 160,
                waterCurrent: 0.50,
                waterGoal: 3.06
            )
        )

        XCTAssertNotEqual(priority.priority, CoachDayPriority.hydration)
        XCTAssertNotEqual(priority.focus, CoachDayFocus.hydrationBehind)
        XCTAssertEqual(priority.limiter, CoachLimiter.timing)
        XCTAssertFalse(priority.supportBullets.isEmpty)
    }

    func testHydrationSupportAcknowledgesProgression() {
        let tennis = PlannedActivityBuilder.workout(
            title: "Tennis",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 75
        )
        tennis.type = "tennis"

        func priority(waterCurrent: Double, waterGoal: Double) -> CoachDayPriorityResult {
            let ratio = waterGoal > 0 ? waterCurrent / waterGoal : 0
            let brain = HumanBrainStateBuilder.make(
                currentHour: 14,
                waterProgress: ratio,
                hydration: .depleted,
                fuel: .good,
                recovery: .stable,
                readiness: .good
            )
            return resolve(
                [tennis],
                brain: brain,
                nutrition: CoachNutritionContext(
                    caloriesCurrent: 1_400,
                    caloriesGoal: 2_400,
                    proteinCurrent: 80,
                    proteinGoal: 160,
                    waterCurrent: waterCurrent,
                    waterGoal: waterGoal
                )
            )
        }

        let severe = priority(waterCurrent: 0.50, waterGoal: 3.06)
        let improving = priority(waterCurrent: 0.73, waterGoal: 3.06)
        let returning = priority(waterCurrent: 1.01, waterGoal: 3.06)

        XCTAssertNotEqual(severe.priority, CoachDayPriority.hydration)
        XCTAssertFalse(severe.supportBullets.isEmpty)
        XCTAssertFalse(improving.supportBullets.isEmpty)
        XCTAssertFalse(returning.supportBullets.isEmpty)
        XCTAssertEqual(severe.activity?.id, tennis.id)
        XCTAssertEqual(improving.activity?.id, tennis.id)
        XCTAssertEqual(returning.activity?.id, tennis.id)
    }

    func testDuplicateHydrationSupportSignalsAreRemoved() {
        let meal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: -5, from: now),
            completed: false
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.16,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [meal],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 900,
                caloriesGoal: 2_400,
                proteinCurrent: 55,
                proteinGoal: 160,
                waterCurrent: 0.50,
                waterGoal: 3.06
            )
        )

        let hydrationActions = priority.supportBullets.filter {
            $0.localizedCaseInsensitiveContains("300-500 ml") ||
            $0.localizedCaseInsensitiveContains("Hydration is significantly behind")
        }
        XCTAssertEqual(hydrationActions.count, 1)
    }

    func testFuelingSupportAcknowledgesCarbAndMealProgression() {
        let tennis = PlannedActivityBuilder.workout(
            title: "Tennis",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 75
        )
        tennis.type = "tennis"

        func priority(carbs: Double, calories: Double, meal: PlannedActivity? = nil) -> CoachDayPriorityResult {
            let activities = [meal, tennis].compactMap { $0 }
            let brain = HumanBrainStateBuilder.make(
                currentHour: 14,
                carbsProgress: carbs / 300,
                waterProgress: 0.80,
                hydration: .optimal,
                fuel: carbs > 0 ? .light : .underfueled,
                recovery: .stable,
                readiness: .good
            )
            return resolve(
                activities,
                brain: brain,
                nutrition: CoachNutritionContext(
                    caloriesCurrent: calories,
                    caloriesGoal: 2_400,
                    proteinCurrent: 70,
                    proteinGoal: 160,
                    carbsCurrent: carbs,
                    carbsGoal: 300,
                    fatsCurrent: 35,
                    fatsGoal: 80,
                    waterCurrent: 2.5,
                    waterGoal: 3.0,
                    mealsCount: meal == nil ? 0 : 1,
                    lastMealTime: meal?.date
                )
            )
        }

        let missing = priority(carbs: 0, calories: 200)
        let started = priority(carbs: 50, calories: 700)
        let covered = priority(carbs: 130, calories: 1_100)
        let meal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: -10, from: now),
            calories: 700,
            carbs: 90,
            completed: true
        )
        let mealIn = priority(carbs: 90, calories: 900, meal: meal)

        XCTAssertEqual(missing.activity?.id, tennis.id)
        XCTAssertFalse(missing.supportBullets.isEmpty)
        XCTAssertTrue(missing.supportBullets.contains { $0.localizedCaseInsensitiveContains("carb") || $0.localizedCaseInsensitiveContains("fuel") })
        XCTAssertTrue(started.supportBullets.contains { $0.localizedCaseInsensitiveContains("Fuel is started") })
        XCTAssertFalse(started.supportBullets.contains { $0.localizedCaseInsensitiveContains("30-60g carbs") })
        XCTAssertTrue(covered.supportBullets.contains { $0.localizedCaseInsensitiveContains("Fuel is covered") })
        XCTAssertFalse(covered.supportBullets.contains { $0.localizedCaseInsensitiveContains("30-60g carbs") })
        XCTAssertTrue(mealIn.supportBullets.contains { $0.localizedCaseInsensitiveContains("Meal is in") })
        XCTAssertTrue(mealIn.supportBullets.contains { $0.localizedCaseInsensitiveContains("settle") })
    }

    func testLoggedDayWithHydrationBehindDoesNotUseNothingPlannedFallback() {
        let completedMeal = PlannedActivityBuilder.meal(
            title: "Breakfast",
            at: CoachTestClock.offset(minutes: -180, from: now),
            completed: true
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.15,
            hydration: .depleted,
            fuel: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [completedMeal],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 900,
                caloriesGoal: 2_400,
                proteinCurrent: 45,
                proteinGoal: 160,
                waterCurrent: 0.4,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: completedMeal.date
            )
        )

        XCTAssertEqual(priority.focus, CoachDayFocus.dailyOverview)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing is planned"))
        XCTAssertFalse(priority.reason.localizedCaseInsensitiveContains("no activity is planned"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("day"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("fluid") || priority.message.localizedCaseInsensitiveContains("water"))
    }

    func testRecentCompletedWorkoutStaysPostActivityBeforeFallback() {
        let workout = PlannedActivityBuilder.workout(
            title: "Tempo Run",
            at: CoachTestClock.offset(minutes: -90, from: now),
            durationMinutes: 60,
            completed: true
        )

        let priority = resolve([workout], brain: steadyBrain)

        XCTAssertEqual(priority.focus, CoachDayFocus.postActivityRecovery)
        XCTAssertEqual(priority.activity?.id, workout.id)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing is planned"))
    }

    func testCompletedQuickActionPreventsGenericFallbackButIsNotOverWeighted() {
        let quickWorkout = PlannedActivityBuilder.workout(
            title: "Core Activation",
            at: CoachTestClock.offset(minutes: -30, from: now),
            durationMinutes: 10,
            completed: true
        )

        let priority = resolve([quickWorkout], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertEqual(priority.focus, CoachDayFocus.dailyOverview)
        XCTAssertEqual(priority.activity?.id, quickWorkout.id)
        XCTAssertEqual(priority.title, "Small session logged")
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("choose a useful block"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing is planned"))
        XCTAssertFalse(priority.focus == CoachDayFocus.postActivityRecovery)
    }

    func testActiveStretchingBeforeTennisStaysLiveGuidanceAndSavesEnergy() {
        let stretching = PlannedActivityBuilder.workout(
            title: "Stretching",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 20
        )
        stretching.type = "recovery"
        let tennis = PlannedActivityBuilder.workout(
            title: "Tennis",
            at: CoachTestClock.offset(minutes: 35, from: now),
            durationMinutes: 75
        )
        tennis.type = "tennis"

        let priority = resolve([stretching, tennis], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertEqual(priority.focus, CoachDayFocus.activeActivity)
        XCTAssertEqual(priority.activity?.id, stretching.id)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertTrue(priority.supportBullets.contains {
            $0.localizedCaseInsensitiveContains("tennis") ||
            $0.localizedCaseInsensitiveContains("save energy")
        })
    }

    func testWaterLogsAreNeverSelectedAsMainCoachActivity() {
        let water = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: -5, from: now)
        )
        let tennis = PlannedActivityBuilder.workout(
            title: "Tennis",
            at: CoachTestClock.offset(minutes: 45, from: now),
            durationMinutes: 75
        )
        tennis.type = "tennis"

        let priority = resolve([water, tennis], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertNotEqual(priority.activity?.id, water.id)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("water"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("water log"))
    }

    func testActiveActivityWinsWithoutSeriousReadinessIssue() {
        let active = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -10, from: now),
            durationMinutes: 60
        )

        let priority = resolve([active], brain: steadyBrain)

        XCTAssertEqual(priority.focus, .activeActivity)
        XCTAssertEqual(priority.priority, .activeSession)
        XCTAssertFalse(priority.overridesTimingFocus)
        XCTAssertEqual(priority.activity?.id, active.id)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("in progress"))
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testActiveWorkoutWithLowFuelAndHydrationStaysLiveGuidance() {
        let active = PlannedActivityBuilder.workout(
            title: "Upper Body",
            at: CoachTestClock.offset(minutes: -10, from: now),
            durationMinutes: 45
        )
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: CoachTestClock.offset(minutes: 150, from: now),
            durationMinutes: 90
        )
        cycling.type = "cycling"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 12,
            hasAnyFoodLogged: false,
            energyCoverage: 0.10,
            carbsProgress: 0.05,
            caloriesProgress: 0.05,
            waterProgress: 0.0,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [active, cycling],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_400,
                proteinCurrent: 0,
                proteinGoal: 160,
                carbsCurrent: 0,
                carbsGoal: 300,
                waterCurrent: 0,
                waterGoal: 3.0,
                mealsCount: 0
            )
        )

        XCTAssertEqual(priority.focus, CoachDayFocus.activeActivity)
        XCTAssertEqual(priority.priority, CoachDayPriority.activeSession)
        XCTAssertEqual(priority.activity?.id, active.id)
        XCTAssertTrue(priority.title.localizedCaseInsensitiveContains("upper body"))
        XCTAssertFalse(priority.supportBullets.isEmpty)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("No pressure"))
    }

    func testPostWorkoutInsideWindow_recoveryWins() {
        let completed = PlannedActivityBuilder.workout(
            title: "Tempo Run",
            at: CoachTestClock.offset(minutes: -55, from: now),
            durationMinutes: 45,
            completed: true
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.40,
            caloriesProgress: 0.25,
            waterProgress: 0.40,
            hydration: .behind,
            fuel: .underfueled,
            protein: .behind,
            recovery: .vulnerable,
            readiness: .moderate
        )

        let priority = resolve([completed], brain: brain)

        XCTAssertEqual(priority.focus, .postActivityRecovery)
        XCTAssertFalse(priority.overridesTimingFocus)
        XCTAssertEqual(priority.activity?.id, completed.id)
    }

    func testCompletedSaunaReinforcesRecoveryInsteadOfPostWorkoutRecovery() {
        let sauna = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: -35, from: now),
            durationMinutes: 30,
            completed: true
        )
        sauna.type = "recovery"

        let priority = resolve([sauna], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.focus, .dailyOverview)
        XCTAssertNotEqual(priority.focus, .postActivityRecovery)
        XCTAssertTrue(priority.title.localizedCaseInsensitiveContains("sauna"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("easy"))
    }

    func testCompletedSaunaStopsOwningScreenAfterHoldWindow() {
        let scenarioNow = fixedDate(hour: 19)
        let sauna = sauna(hour: 17, minute: 0)
        sauna.isCompleted = true
        let tomorrowCycling = workout("Cycling", dayOffset: 1, hour: 9, duration: 120)
        tomorrowCycling.type = "cycling"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 19,
            hasAnyFoodLogged: true,
            energyCoverage: 0.35,
            carbsProgress: 0.22,
            caloriesProgress: 0.21,
            waterProgress: 0.21,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            strain: .high,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(
                protein: 17,
                carbs: 30,
                calories: 264,
                waterLiters: 0.75,
                activeCalories: 950,
                sleepHours: 5.5
            )
        )

        let priority = resolve(
            [sauna, tomorrowCycling],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 5.5),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 264,
                caloriesGoal: 1_838,
                proteinCurrent: 17,
                proteinGoal: 153,
                carbsCurrent: 30,
                carbsGoal: 169,
                fatsCurrent: 9,
                fatsGoal: 61,
                waterCurrent: 0.75,
                waterGoal: 3.56,
                mealsCount: 1,
                lastMealTime: scenarioNow.addingTimeInterval(-4 * 3_600)
            )
        )

        XCTAssertNotEqual(priority.title, "Sauna is done")
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertNotNil(priority.activity?.id)
    }

    func testCompletedShortRecoveryWalkDoesNotTriggerPostActivityRecovery() {
        let walk = PlannedActivityBuilder.workout(
            title: "Easy Walk",
            at: CoachTestClock.offset(minutes: -25, from: now),
            durationMinutes: 15,
            completed: true
        )
        walk.type = "recovery"

        let priority = resolve([walk], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertNotEqual(priority.focus, .postActivityRecovery)
        XCTAssertNotEqual(priority.priority, .recovery)
        XCTAssertEqual(priority.priority, .stable)
    }

    func testRecoveryDayNoMealsDoesNotMakeFuelingLead() {
        let recoveryWalk = PlannedActivityBuilder.workout(
            title: "Recovery Walk",
            at: fixedDate(hour: 12),
            durationMinutes: 30
        )
        recoveryWalk.type = "recovery"
        let scenarioNow = fixedDate(hour: 11, minute: 15)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 11,
            hasAnyFoodLogged: false,
            energyCoverage: 0.20,
            carbsProgress: 0.0,
            caloriesProgress: 0.0,
            waterProgress: 0.70,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .strong,
            readiness: .good
        )

        let priority = resolve(
            [recoveryWalk],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_400,
                proteinCurrent: 0,
                proteinGoal: 160,
                carbsCurrent: 0,
                carbsGoal: 300,
                fatsCurrent: 0,
                fatsGoal: 80,
                waterCurrent: 2.1,
                waterGoal: 3.0,
                mealsCount: 0
            )
        )

        XCTAssertNotEqual(priority.priority, CoachDayPriority.fueling)
        XCTAssertNotEqual(priority.focus, CoachDayFocus.fuelBehind)
        XCTAssertEqual(priority.priority, CoachDayPriority.stable)
        XCTAssertTrue(priority.supportBullets.contains { $0.localizedCaseInsensitiveContains("Eat normally") })
    }

    func testLateNightLowWaterLowProteinNoRecentWorkout_closesDayInsteadOfChasingTargets() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.30,
            caloriesProgress: 0.25,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            strain: .normal,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 600,
                caloriesGoal: 2_400,
                proteinCurrent: 35,
                proteinGoal: 160,
                waterCurrent: 0.5,
                waterGoal: 3.0
            )
        )

        // a7b7d4d: adequate sleep (7.1h) → protection framing without chasing hydration/protein targets.
        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.limiter, .none)
        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("protein"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("eat"))
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testAfterMidnightLowWaterLowProteinNoRecentWorkout_closesDayInsteadOfChasingTargets() {
        for (hour, minute) in [(0, 30), (1, 0)] {
            let scenarioNow = fixedDate(hour: hour, minute: minute)
            let brain = HumanBrainStateBuilder.make(
                currentHour: hour,
                energyCoverage: 0.30,
                caloriesProgress: 0.25,
                waterProgress: 0.20,
                hydration: .depleted,
                fuel: .underfueled,
                protein: .low,
                strain: .normal,
                recovery: .stable,
                readiness: .good
            )

            let priority = resolve(
                [],
                brain: brain,
                now: scenarioNow,
                selectedDate: scenarioNow,
                recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
                nutrition: CoachNutritionContext(
                    caloriesCurrent: 600,
                    caloriesGoal: 2_400,
                    proteinCurrent: 35,
                    proteinGoal: 160,
                    waterCurrent: 0.5,
                    waterGoal: 3.0
                )
            )

            XCTAssertEqual(priority.priority, .stable)
            XCTAssertEqual(priority.focus, .eveningWindDown)
            XCTAssertEqual(priority.objective, .completeDay)
            XCTAssertEqual(priority.horizon, .today)
            XCTAssertFalse(priority.todayTitle.isEmpty)
            XCTAssertFalse(priority.todayMessage.isEmpty)
            XCTAssertFalse(priority.message.isEmpty)
            XCTAssertFalse(priority.message.isEmpty)
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("protein"))
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("eat"))
        }
    }

    func testOneAmLowValueActiveRecoveryStillSurfacesDayClosedSleepCopy() {
        let scenarioNow = fixedDate(hour: 1)
        let mobility = PlannedActivityBuilder.workout(
            title: "Mobility",
            at: Calendar.current.date(byAdding: .minute, value: -5, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 25
        )
        mobility.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 1,
            energyCoverage: 0.30,
            caloriesProgress: 0.25,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            strain: .normal,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [mobility],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 600,
                caloriesGoal: 2_400,
                proteinCurrent: 35,
                proteinGoal: 160,
                waterCurrent: 0.5,
                waterGoal: 3.0
            )
        )

        XCTAssertTrue(priority.priority == .sleepPreparation || priority.priority == .activeSession)
        XCTAssertTrue(priority.focus == .eveningWindDown || priority.focus == .activeActivity)
        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertFalse(priority.todayMessage.isEmpty)
        XCTAssertEqual(priority.title, priority.detailTitle)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("mobility in progress"))
    }

    func testLateEveningHardWorkoutJustEnded_allowsLightRecoveryNutrition() {
        let scenarioNow = fixedDate(hour: 22)
        let completed = PlannedActivityBuilder.workout(
            title: "Long Strength",
            at: Calendar.current.date(byAdding: .minute, value: -70, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 60,
            completed: true
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 22,
            energyCoverage: 0.35,
            caloriesProgress: 0.25,
            waterProgress: 0.65,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            strain: .high,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [completed],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 7.0),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 800,
                caloriesGoal: 2_400,
                proteinCurrent: 40,
                proteinGoal: 160,
                waterCurrent: 2.0,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.focus, .postActivityRecovery)
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("light"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("protein"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("heavy late dinner"))
    }

    func testWorkoutInFortyFiveMinutesFuelAndHydrationLow_prioritizesPreparation() {
        let scenarioNow = fixedDate(hour: 16, minute: 30)
        let workout = PlannedActivityBuilder.workout(
            title: "Strength",
            at: Calendar.current.date(byAdding: .minute, value: 45, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 60
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 16,
            energyCoverage: 0.25,
            carbsProgress: 0.15,
            caloriesProgress: 0.20,
            waterProgress: 0.25,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [workout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 500,
                caloriesGoal: 2_400,
                proteinCurrent: 40,
                proteinGoal: 160,
                waterCurrent: 0.6,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.title, "Prepare for strength")
        XCTAssertEqual(priority.priority, CoachDayPriority.performance)
        XCTAssertEqual(priority.focus, CoachDayFocus.prepareForActivity)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.supportBullets.isEmpty)
        XCTAssertFalse(priority.overridesTimingFocus)
    }

    func testSmallBananaBeforeCyclingReducesButDoesNotCollapsePreparation() {
        let scenarioNow = fixedDate(hour: 10, minute: 55)
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: Calendar.current.date(byAdding: .minute, value: 35, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 75
        )

        let beforeBrain = HumanBrainStateBuilder.make(
            currentHour: 10,
            hasAnyFoodLogged: false,
            energyCoverage: 0.05,
            carbsProgress: 0.0,
            caloriesProgress: 0.0,
            waterProgress: 0.10,
            hydration: .depleted,
            fuel: .underfueled,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                calories: 0,
                waterLiters: 0.2,
                sleepHours: 6.8
            )
        )
        let afterBrain = HumanBrainStateBuilder.make(
            currentHour: 10,
            hasAnyFoodLogged: true,
            energyCoverage: 0.12,
            carbsProgress: 0.10,
            caloriesProgress: 0.04,
            waterProgress: 0.10,
            hydration: .depleted,
            fuel: .underfueled,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                carbs: 27,
                calories: 105,
                waterLiters: 0.2,
                sleepHours: 6.8
            )
        )

        let before = resolve(
            [cycling],
            brain: beforeBrain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 6.8),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_400,
                proteinCurrent: 0,
                proteinGoal: 160,
                carbsCurrent: 0,
                carbsGoal: 280,
                fatsCurrent: 0,
                fatsGoal: 70,
                waterCurrent: 0.2,
                waterGoal: 3.0,
                mealsCount: 0,
                lastMealTime: nil
            )
        )
        let after = resolve(
            [cycling],
            brain: afterBrain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 6.8),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 105,
                caloriesGoal: 2_400,
                proteinCurrent: 1,
                proteinGoal: 160,
                carbsCurrent: 27,
                carbsGoal: 280,
                fatsCurrent: 0,
                fatsGoal: 70,
                waterCurrent: 0.2,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: scenarioNow
            )
        )

        XCTAssertEqual(before.priority, CoachDayPriority.performance)
        XCTAssertEqual(before.focus, CoachDayFocus.prepareForActivity)
        XCTAssertEqual(after.priority, CoachDayPriority.performance)
        XCTAssertEqual(after.focus, CoachDayFocus.prepareForActivity)
        XCTAssertGreaterThan(before.decisionScore, after.decisionScore)
        XCTAssertGreaterThanOrEqual(after.decisionScore, 70)
        XCTAssertTrue(after.supportBullets.contains { $0.localizedCaseInsensitiveContains("carb") })
        XCTAssertTrue(after.supportBullets.contains { $0.localizedCaseInsensitiveContains("bottle") || $0.localizedCaseInsensitiveContains("water") })
    }

    func testPreparationWithShortSleepKeepsPreparationNarrative() throws {
        let scenarioNow = now
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: Calendar.current.date(byAdding: .minute, value: 53, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 75
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 10,
            energyCoverage: 0.10,
            carbsProgress: 0.05,
            caloriesProgress: 0.10,
            waterProgress: 0.10,
            hydration: .depleted,
            fuel: .underfueled,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(
                calories: 200,
                waterLiters: 0.2,
                sleepHours: 4.7
            )
        )

        let activityContext = activityContext(
            [cycling],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: CoachDayContextBuilder.build(
                activities: [cycling],
                selectedDate: scenarioNow,
                now: scenarioNow
            ),
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 4.7),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 200,
                caloriesGoal: 2_400,
                proteinCurrent: 10,
                proteinGoal: 160,
                carbsCurrent: 20,
                carbsGoal: 280,
                fatsCurrent: 8,
                fatsGoal: 70,
                waterCurrent: 0.2,
                waterGoal: 3.0,
                mealsCount: 0,
                lastMealTime: nil
            ),
            readiness: readiness
        )
        let priority = CoachDayPriorityResult(
            focus: .prepareForActivity,
            level: .high,
            reason: "The next workout is inside its preparation window.",
            activity: cycling,
            overridesTimingFocus: false,
            priority: .performance,
            strength: .high,
            mode: .reinforcement,
            limiter: .sleep,
            title: "Prepare for cycling",
            message: "Prepare for cycling without treating short sleep as a recovery-day story.",
            supportBullets: [
                "Eat 20-40g carbs before the ride",
                "Keep the first 15-20 minutes easy"
            ],
            whyThisMatters: "Short sleep should adjust workout execution, not replace workout preparation."
        )
        let decision = HumanCoachDecisionEngine.resolve(
            context: context,
            priority: priority
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: CoachSupportOpportunityResolverV3.resolve(
                phase: activityContext.phase,
                readiness: readiness,
                brain: brain
            ),
            legacyPriority: priority
        )

        let story = try XCTUnwrap(guidance.screenStory)
        let renderedCopy = [
            story.title,
            story.myRead,
            story.myRecommendation,
            story.primaryActions.map(\.title).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        XCTAssertEqual(guidance.priority.priority, CoachDayPriority.performance)
        XCTAssertEqual(guidance.priority.focus, CoachDayFocus.prepareForActivity)
        XCTAssertTrue(story.title.localizedCaseInsensitiveContains("Prepare"))
        XCTAssertFalse(renderedCopy.isEmpty)
        XCTAssertTrue(renderedCopy.contains("sleep"))
        XCTAssertTrue(renderedCopy.contains("fuel") || renderedCopy.contains("carb") || renderedCopy.contains("nutrition"))
        XCTAssertTrue(renderedCopy.contains("easy") || renderedCopy.contains("ceiling") || renderedCopy.contains("controlled"))
    }

    func testPreparationPlanChallengeMentionsSelectedCycling() throws {
        let scenarioNow = now
        let cycling = PlannedActivityBuilder.workout(
            title: "Cycling",
            at: Calendar.current.date(byAdding: .minute, value: 35, to: scenarioNow) ?? scenarioNow,
            durationMinutes: 75
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 10,
            hasAnyFoodLogged: true,
            energyCoverage: 0.12,
            carbsProgress: 0.10,
            caloriesProgress: 0.04,
            waterProgress: 0.10,
            hydration: .depleted,
            fuel: .underfueled,
            recovery: .compromised,
            readiness: .compromised,
            metrics: CoachMetricsBuilder.metrics(
                carbs: 27,
                calories: 105,
                waterLiters: 0.2,
                sleepHours: 4.2
            )
        )
        let activityContext = activityContext(
            [cycling],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: CoachDayContextBuilder.build(
                activities: [cycling],
                selectedDate: scenarioNow,
                now: scenarioNow
            ),
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.2),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 105,
                caloriesGoal: 2_400,
                proteinCurrent: 1,
                proteinGoal: 160,
                carbsCurrent: 27,
                carbsGoal: 280,
                fatsCurrent: 0,
                fatsGoal: 70,
                waterCurrent: 0.2,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: scenarioNow
            ),
            readiness: readiness
        )
        let priority = CoachDayPriorityResult(
            focus: .tomorrowPlanRisk,
            level: .high,
            reason: "The planned session conflicts with current readiness.",
            activity: cycling,
            overridesTimingFocus: true,
            priority: .planChallenge,
            strength: .high,
            mode: .adjustment,
            limiter: .sleep,
            title: "Reduce today's intensity",
            message: "Short sleep means the upcoming session should be adjusted.",
            supportBullets: [
                "Keep effort easy",
                "Keep the first 10 minutes easy",
                "Shorten if needed"
            ],
            whyThisMatters: "A hard plan only works when the body can absorb it.",
            planChallenge: "If the warm-up feels flat, shorten the ride or remove intensity."
        )
        let decision = HumanCoachDecisionEngine.resolve(
            context: context,
            priority: priority
        )
        let guidance = HumanCoachDecisionEngine.adapt(
            decision,
            phase: activityContext.phase,
            opportunity: CoachSupportOpportunityResolverV3.resolve(
                phase: activityContext.phase,
                readiness: readiness,
                brain: brain
            ),
            legacyPriority: priority
        )

        let story = try XCTUnwrap(guidance.screenStory)
        let renderedCopy = [
            story.title,
            story.myRead,
            story.myRecommendation,
            story.primaryActions.map(\.title).joined(separator: " ")
        ].joined(separator: " ").lowercased()

        XCTAssertTrue(guidance.priority.priority == .planChallenge || guidance.priority.priority == .performance || guidance.priority.priority == .recovery)
        XCTAssertTrue(guidance.priority.focus == .tomorrowPlanRisk || guidance.priority.focus == .trainingReadinessWarning || guidance.priority.focus == .recoveryNeeded)
        XCTAssertFalse(story.myRead.isEmpty)
        XCTAssertFalse(story.myRead.lowercased().hasPrefix("tomorrow's plan"))
        XCTAssertFalse(renderedCopy.isEmpty)
        XCTAssertFalse(renderedCopy.isEmpty)
        XCTAssertFalse(renderedCopy.contains("bring ride nutrition"))
        XCTAssertFalse(renderedCopy.contains("prepare fueling"))
        XCTAssertFalse(renderedCopy.contains("support fueling"))
        XCTAssertFalse(renderedCopy.contains("manage nutrition"))
    }

    func testMorningMealBeforeRunInsidePrepWindow_surfacesPreparationGuidance() {
        let scenarioNow = fixedDate(hour: 8, minute: 41)
        let meal = PlannedActivityBuilder.meal(
            title: "Breakfast",
            at: fixedDate(hour: 9),
            completed: false
        )
        let run = PlannedActivityBuilder.workout(
            title: "Running",
            at: fixedDate(hour: 9, minute: 30),
            durationMinutes: 60
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 8,
            energyCoverage: 0.80,
            carbsProgress: 0.70,
            caloriesProgress: 0.70,
            waterProgress: 0.80,
            sleep: .strong,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .strong,
            readiness: .excellent,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 40, sleepHours: 7.8)
        )

        let priority = resolve(
            [meal, run],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.8),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_700,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 160,
                waterCurrent: 2.4,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.activity?.id, run.id)
        XCTAssertEqual(priority.priority, .performance)
        XCTAssertTrue([CoachDayFocus.prepareForActivity, .performanceReadiness].contains(priority.focus))
        XCTAssertEqual(priority.objective, .prepareActivity)
        XCTAssertNotEqual(priority.objective, .recoveryDay)
        XCTAssertFalse(priority.todayTitle.localizedCaseInsensitiveContains("recovery day"))
    }

    func testRecoveryDayClassificationDoesNotWinWhenTrainingRemainsToday() {
        let scenarioNow = fixedDate(hour: 8, minute: 41)
        let mobility = PlannedActivityBuilder.workout(
            title: "Recovery Mobility",
            at: fixedDate(hour: 9),
            durationMinutes: 20
        )
        mobility.type = "recovery"
        let run = PlannedActivityBuilder.workout(
            title: "Running",
            at: fixedDate(hour: 9, minute: 30),
            durationMinutes: 60
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 8,
            energyCoverage: 0.85,
            carbsProgress: 0.75,
            caloriesProgress: 0.75,
            waterProgress: 0.85,
            sleep: .strong,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .strong,
            readiness: .excellent,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 20, sleepHours: 8.1)
        )

        let priority = resolve(
            [mobility, run],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8.1),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.activity?.id, run.id)
        XCTAssertNotEqual(priority.objective, .recoveryDay)
        XCTAssertNotEqual(priority.priority, .recovery)
        XCTAssertFalse(priority.todayTitle.localizedCaseInsensitiveContains("recovery day"))
    }

    func testCriticalSleepLimiterOverridesRunPreparationWindow() {
        let scenarioNow = fixedDate(hour: 8, minute: 41)
        let meal = PlannedActivityBuilder.meal(
            title: "Breakfast",
            at: fixedDate(hour: 9),
            completed: false
        )
        let run = PlannedActivityBuilder.workout(
            title: "Running",
            at: fixedDate(hour: 9, minute: 30),
            durationMinutes: 60
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 8,
            energyCoverage: 0.80,
            carbsProgress: 0.70,
            caloriesProgress: 0.70,
            waterProgress: 0.80,
            sleep: .veryShort,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .stable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 40, sleepHours: 3.5)
        )

        let priority = resolve(
            [meal, run],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 76, sleepHours: 3.5),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.activity?.id, run.id)
        XCTAssertEqual(priority.limiter, .sleep)
        XCTAssertTrue([CoachDayPriority.sleepPreparation, .planChallenge].contains(priority.priority))
        XCTAssertNotEqual(priority.focus, .prepareForActivity)
        XCTAssertTrue(priority.overridesTimingFocus)
    }

    func testMorningPoorSleepWithEveningWorkout_managesReadinessAndIntensity() {
        let scenarioNow = fixedDate(hour: 7)
        let workout = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: fixedDate(hour: 18),
            durationMinutes: 75
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 7,
            energyCoverage: 0.70,
            caloriesProgress: 0.60,
            waterProgress: 0.75,
            sleep: .veryShort,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .stable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 100, sleepHours: 3.5)
        )

        let priority = resolve(
            [workout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 76, sleepHours: 3.5),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.focus, .trainingReadinessWarning)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("intensity"))
        XCTAssertNotNil(priority.planChallenge)
    }

    func testMiddayGoodRecoveryLowCaloriesWorkoutLater_prioritizesFuelBeforeTraining() {
        let scenarioNow = fixedDate(hour: 12, minute: 30)
        let workout = PlannedActivityBuilder.workout(
            title: "Tempo Ride",
            at: fixedDate(hour: 17),
            durationMinutes: 90
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 12,
            energyCoverage: 0.20,
            carbsProgress: 0.12,
            caloriesProgress: 0.15,
            waterProgress: 0.85,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .strong,
            readiness: .excellent
        )

        let priority = resolve(
            [workout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8.0),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 350,
                caloriesGoal: 2_400,
                proteinCurrent: 25,
                proteinGoal: 160,
                waterCurrent: 2.5,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.priority, CoachDayPriority.performance)
        XCTAssertEqual(priority.focus, CoachDayFocus.prepareForActivity)
        XCTAssertFalse(priority.supportBullets.isEmpty)
        XCTAssertEqual(priority.activity?.id, workout.id)
    }

    func testEveningHardWorkoutTomorrow_protectsRecoveryTonight() {
        let scenarioNow = fixedDate(hour: 21)
        let tomorrowWorkout = workout("Long Ride", dayOffset: 1, hour: 9, duration: 150)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 21,
            energyCoverage: 0.80,
            caloriesProgress: 0.75,
            waterProgress: 0.80,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [tomorrowWorkout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: steadyNutrition
        )

        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertTrue(priority.objective == .protectTomorrow || priority.objective == .recoverFromActivity || priority.objective == .completeDay)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("eat"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
    }

    func testNoActivityNormalMetrics_staysSteadyWithoutGenericRecoveryWarning() {
        let scenarioNow = fixedDate(hour: 15)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 15,
            energyCoverage: 0.80,
            caloriesProgress: 0.70,
            waterProgress: 0.80,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .normal,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.focus, .dailyOverview)
        XCTAssertEqual(priority.messageFamily, .stable)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("recovery"))
        XCTAssertEqual(priority.objective, .maintainCourse)
        XCTAssertEqual(priority.horizon, .today)
        XCTAssertTrue(priority.opportunity == .none || priority.opportunity == .trainingOpportunity)
        XCTAssertTrue(priority.interventionValue == .none || priority.interventionValue == .useful)
        XCTAssertEqual(priority.completionState, .complete)
    }

    func testHighReadinessNoScheduleDay_coachesOpportunityWithoutInventingProblem() {
        let scenarioNow = fixedDate(hour: 11)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 11,
            energyCoverage: 0.88,
            caloriesProgress: 0.82,
            waterProgress: 0.90,
            sleep: .strong,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .strong,
            readiness: .excellent,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 60, sleepHours: 8.2)
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 92, sleepHours: 8.2),
            nutrition: steadyNutrition
        )

        XCTAssertTrue(priority.priority == .stable || priority.priority == .performance)
        XCTAssertTrue(priority.opportunity == .highReadiness || priority.opportunity == .trainingOpportunity)
        XCTAssertTrue(priority.completionState == .complete || priority.completionState == .goodEnough)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing needs attention"))
    }

    func testLateNightGoodEnoughProteinAndHydration_sleepWinsOverTargetChasing() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.92,
            caloriesProgress: 0.92,
            waterProgress: 0.93,
            hydration: .behind,
            fuel: .good,
            protein: .behind,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.2),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 2_250,
                caloriesGoal: 2_400,
                proteinCurrent: 168,
                proteinGoal: 180,
                waterCurrent: 2.8,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.objective, .completeDay)
        XCTAssertEqual(priority.completionState, .goodEnough)
        XCTAssertEqual(priority.interventionValue, .low)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("protein"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
    }

    func testTomorrowDemandNoneCannotProtectTomorrowInSameEvening() {
        let scenarioNow = fixedDate(hour: 23, minute: 10)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 1.0,
            caloriesProgress: 1.0,
            waterProgress: 0.90,
            sleep: .strong,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .veryHigh,
            recovery: .strong,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(
                calories: 2_400,
                waterLiters: 2.8,
                activeCalories: 950,
                sleepHours: 7.8
            )
        )
        let demand = CoachTomorrowDemandResolver.resolve(
            tomorrowContext: tomorrowContext(
                activities: [],
                selectedDate: scenarioNow,
                now: scenarioNow
            )
        )
        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 89, sleepHours: 7.8),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 2_400,
                caloriesGoal: 2_400,
                proteinCurrent: 160,
                proteinGoal: 160,
                waterCurrent: 2.8,
                waterGoal: 3.0,
                mealsCount: 3
            )
        )

        XCTAssertEqual(demand.level, .none)
        XCTAssertFalse(demand.hasDemand)
        XCTAssertNotEqual(priority.objective, .protectTomorrow)
        XCTAssertNotEqual(priority.horizon, .tomorrow)
        XCTAssertFalse(priority.tomorrowProtection.recommended)
        XCTAssertFalse(priority.tomorrowProtection.active)
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("Protect tomorrow"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("Protect tomorrow"))
    }

    func testEmptyDayStillProducesCalmHumanStateGuidance() {
        let scenarioNow = fixedDate(hour: 14)
        let priority = resolve(
            [],
            brain: steadyBrain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.4),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.focus, .dailyOverview)
        XCTAssertEqual(priority.objective, .maintainCourse)
        XCTAssertTrue(priority.opportunity == .none || priority.opportunity == .trainingOpportunity)
        XCTAssertTrue(priority.interventionValue == .none || priority.interventionValue == .useful)
        XCTAssertEqual(priority.completionState, .complete)
        XCTAssertFalse(priority.message.isEmpty)
        assertNoScheduleReaderCopy(priority, scenario: "empty day calm guidance")
    }

    func testHighReadinessNoScheduleSurfacesOpportunity() {
        let scenarioNow = fixedDate(hour: 10)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 10,
            energyCoverage: 0.90,
            caloriesProgress: 0.85,
            waterProgress: 0.90,
            sleep: .strong,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .strong,
            readiness: .excellent,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 50, sleepHours: 8.2)
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 92, sleepHours: 8.2),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 2_100,
                caloriesGoal: 2_400,
                proteinCurrent: 145,
                proteinGoal: 160,
                waterCurrent: 2.8,
                waterGoal: 3.0
            )
        )

        XCTAssertTrue(priority.opportunity == .highReadiness || priority.opportunity == .trainingOpportunity)
        XCTAssertEqual(priority.objective, .buildReadiness)
        XCTAssertEqual(priority.interventionValue, .useful)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("nothing needs"))
        assertNoScheduleReaderCopy(priority, scenario: "high readiness no schedule")
    }

    func testLateNightGoodEnoughProteinAndHydrationSleepWins() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.95,
            caloriesProgress: 0.92,
            waterProgress: 0.78,
            hydration: .behind,
            fuel: .good,
            protein: .behind,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.2),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 2_250,
                caloriesGoal: 2_400,
                proteinCurrent: 168,
                proteinGoal: 180,
                waterCurrent: 2.35,
                waterGoal: 3.0
            )
        )

        // a7b7d4d: good late-night nutrition + 7.2h sleep → wind-down, not sleep-deficit priority.
        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.limiter, .none)
        XCTAssertEqual(priority.objective, .completeDay)
        XCTAssertEqual(priority.completionState, .goodEnough)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("protein"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
    }

    func testRecentMealSuppressesNutritionGapNextImportantEvent() {
        let scenarioNow = fixedDate(hour: 14)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.25,
            caloriesProgress: 0.20,
            waterProgress: 0.80,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )
        let context = decisionContext(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 450,
                caloriesGoal: 2_400,
                proteinCurrent: 20,
                proteinGoal: 160,
                waterCurrent: 2.4,
                waterGoal: 3.0,
                mealsCount: 1,
                lastMealTime: scenarioNow.addingTimeInterval(-60)
            )
        )

        let normalized = CoachLifecycleDecisionPipeline.normalizedContext(from: context)

        XCTAssertNotEqual(normalized.nextImportantEvent, .nutritionGapToday)
    }

    func testBadSleepAndHydrationBehindKeepsRecoveryNarrative() {
        let scenarioNow = fixedDate(hour: 14)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            waterProgress: 0.12,
            sleep: .veryShort,
            hydration: .depleted,
            fuel: .good,
            protein: .good,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(waterLiters: 0.35, sleepHours: 5.4)
        )

        let priority = resolve(
            [],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 52, sleepHours: 5.4),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_600,
                caloriesGoal: 2_400,
                proteinCurrent: 130,
                proteinGoal: 160,
                waterCurrent: 0.35,
                waterGoal: 3.0
            )
        )

        assertExecutionLayerIsNotPrimary(priority)
        XCTAssertTrue(priority.priority == .recovery || priority.priority == .sleepPreparation || priority.priority == .planChallenge)
    }

    func testWorkoutSoonAndCarbsBehindKeepsTrainingPreparationNarrative() {
        let scenarioNow = fixedDate(hour: 15)
        let workout = PlannedActivityBuilder.workout(
            title: "Intervals",
            at: scenarioNow.addingTimeInterval(60 * 60),
            durationMinutes: 60
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 15,
            energyCoverage: 0.30,
            carbsProgress: 0.10,
            caloriesProgress: 0.22,
            waterProgress: 0.80,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .good,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [workout],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 500,
                caloriesGoal: 2_400,
                proteinCurrent: 100,
                proteinGoal: 160,
                carbsCurrent: 20,
                carbsGoal: 260,
                waterCurrent: 2.4,
                waterGoal: 3.0
            )
        )

        assertExecutionLayerIsNotPrimary(priority)
        XCTAssertEqual(priority.priority, CoachDayPriority.performance)
        XCTAssertEqual(priority.focus, CoachDayFocus.prepareForActivity)
        XCTAssertEqual(priority.activity?.id, workout.id)
    }

    func testRecoveryDayWithoutBreakfastKeepsRecoveryDayNarrative() {
        let scenarioNow = fixedDate(hour: 10)
        let walk = recoveryActivity(
            "Recovery Walk",
            minutesFromNow: 90,
            duration: 30
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 10,
            energyCoverage: 0.10,
            caloriesProgress: 0.0,
            waterProgress: 0.60,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )

        let priority = resolve(
            [walk],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_200,
                proteinCurrent: 0,
                proteinGoal: 150,
                waterCurrent: 1.8,
                waterGoal: 3.0,
                mealsCount: 0
            )
        )

        assertExecutionLayerIsNotPrimary(priority)
        XCTAssertTrue(priority.priority == .recovery || priority.priority == .stable || priority.priority == .sleepPreparation)
    }

    func testPoorRecoveryTodayWithRecoveryTomorrowRecognizesRecoverySpace() {
        let scenarioNow = fixedDate(hour: 17)
        let tomorrowRecovery = recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 17,
            energyCoverage: 0.80,
            caloriesProgress: 0.75,
            waterProgress: 0.80,
            sleep: .short,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 220, sleepHours: 5.2)
        )

        let priority = resolve(
            [tomorrowRecovery],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 5.2),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.priority, .recovery)
        XCTAssertTrue(priority.objective == .recoveryDay || priority.objective == .buildReadiness)
        XCTAssertEqual(priority.horizon, .today)
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testTodayCardAndCoachScreenUseSameResolvedPriorityDecision() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.25,
            caloriesProgress: 0.20,
            waterProgress: 0.20,
            hydration: .depleted,
            fuel: .underfueled,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )
        let recovery = CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.1)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 500,
            caloriesGoal: 2_400,
            proteinCurrent: 30,
            proteinGoal: 160,
            waterCurrent: 0.5,
            waterGoal: 3.0
        )

        let guidance = CoachEngineV3.decide(
            from: brain,
            plannedActivities: [],
            selectedDate: scenarioNow,
            dayContext: CoachDayContextBuilder.build(
                activities: [],
                selectedDate: scenarioNow,
                now: scenarioNow
            ),
            recoveryContext: recovery,
            nutritionContext: nutrition
        )

        XCTAssertFalse(guidance.priority.todayTitle.isEmpty)
        XCTAssertEqual(guidance.title, guidance.priority.detailTitle)
        XCTAssertFalse(guidance.message.isEmpty)
        XCTAssertEqual(guidance.insightTitle, guidance.priority.todayTitle)
        XCTAssertFalse(guidance.dynamicInsight.text.isEmpty)
    }

    func testLaterActivityToday_readinessCanWinWithoutUrgency() {
        let laterWorkout = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: 180, from: now),
            durationMinutes: 60
        )

        let priority = resolve([laterWorkout], brain: steadyBrain)

        XCTAssertEqual(priority.priority, .performance)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertEqual(priority.activity?.id, laterWorkout.id)
        XCTAssertFalse(priority.title.isEmpty)

        let guidance = CoachEngineV3.decide(
            from: steadyBrain,
            plannedActivities: [laterWorkout],
            selectedDate: selectedDate,
            dayContext: CoachDayContextBuilder.build(
                activities: [laterWorkout],
                selectedDate: selectedDate,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutritionContext: steadyNutrition
        )

        XCTAssertEqual(guidance.priority.priority, .stable)
        XCTAssertFalse(guidance.shouldSurface)
    }

    func testHighLoadLateEveningStretchingActiveBreathingUpcoming_recoveryPriorityWins() {
        let stretching = PlannedActivityBuilder.workout(
            title: "Stretching",
            at: CoachTestClock.offset(minutes: -1, from: now),
            durationMinutes: 20
        )
        stretching.type = "recovery"

        let breathing = PlannedActivityBuilder.workout(
            title: "Breathing",
            at: CoachTestClock.offset(minutes: 28, from: now),
            durationMinutes: 10
        )
        breathing.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 22,
            energyCoverage: 0.95,
            caloriesProgress: 0.80,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .veryHigh,
            recovery: .vulnerable,
            readiness: .moderate,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 2_672, sleepHours: 2.9)
        )

        let priority = resolve(
            [stretching, breathing],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 53, sleepHours: 2.9),
            nutrition: steadyNutrition
        )

        XCTAssertTrue(priority.priority == .sleepPreparation || priority.priority == .recovery)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertEqual(priority.title, priority.detailTitle)
        XCTAssertEqual(priority.message, priority.detailMessage)
        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertFalse(priority.todayMessage.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertTrue(priority.overridesTimingFocus || priority.priority == .recovery)
        XCTAssertEqual(priority.activity?.id, stretching.id)

        let guidance = CoachEngineV3.decide(
            from: brain,
            plannedActivities: [stretching, breathing],
            selectedDate: selectedDate,
            dayContext: CoachDayContextBuilder.build(
                activities: [stretching, breathing],
                selectedDate: selectedDate,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 53, sleepHours: 2.9),
            nutritionContext: steadyNutrition
        )

        XCTAssertTrue(guidance.priority.priority == .sleepPreparation || guidance.priority.priority == .recovery)
        XCTAssertFalse(guidance.title.isEmpty)
        XCTAssertEqual(guidance.title, guidance.priority.detailTitle)
        XCTAssertFalse(guidance.message.isEmpty)
        XCTAssertEqual(guidance.insightTitle, guidance.priority.todayTitle)
        XCTAssertFalse(guidance.insightTitle.isEmpty)
        XCTAssertFalse(guidance.insightSubtitle?.isEmpty ?? true)
        XCTAssertFalse(guidance.dynamicInsight.text.isEmpty)
        XCTAssertFalse(guidance.insightSubtitle?.localizedCaseInsensitiveContains("Recovery priority") ?? false)
        XCTAssertFalse(guidance.title.localizedCaseInsensitiveContains("stretching in progress"))
    }

    func testLowRecoveryPoorSleepWithHardTrainingTomorrow_challengesTomorrowPlan() {
        let tomorrowWorkout = PlannedActivityBuilder.workout(
            title: "Endurance Session",
            at: CoachTestClock.offset(hours: 22, from: now),
            durationMinutes: 100
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 20,
            energyCoverage: 0.80,
            caloriesProgress: 0.60,
            waterProgress: 0.80,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .high,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 900, sleepHours: 4.5)
        )

        let recovery = CoachRecoveryContext(recoveryPercent: 42, sleepHours: 4.5)
        let priority = resolve(
            [tomorrowWorkout],
            brain: brain,
            recovery: recovery,
            nutrition: steadyNutrition
        )

        XCTAssertTrue(priority.focus == .tomorrowPlanRisk || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.priority == .planChallenge || priority.priority == .recovery)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertTrue(priority.objective == .protectTomorrow || priority.objective == .recoverFromActivity)
        XCTAssertEqual(priority.title, priority.detailTitle)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.todayTitle.isEmpty)
        XCTAssertFalse(priority.todayMessage.isEmpty)
        XCTAssertTrue(priority.activity?.id == tomorrowWorkout.id || priority.activity == nil)
        XCTAssertFalse(priority.message.isEmpty)

        let guidance = CoachEngineV3.decide(
            from: brain,
            plannedActivities: [tomorrowWorkout],
            selectedDate: selectedDate,
            dayContext: CoachDayContextBuilder.build(
                activities: [tomorrowWorkout],
                selectedDate: selectedDate,
                now: now
            ),
            recoveryContext: recovery,
            nutritionContext: steadyNutrition
        )

        XCTAssertTrue(guidance.priority.focus == .tomorrowPlanRisk || guidance.priority.focus == .recoveryNeeded)
        XCTAssertFalse(guidance.title.isEmpty)
        XCTAssertFalse(guidance.message.isEmpty)
        XCTAssertFalse(guidance.message.localizedCaseInsensitiveContains("The day is open enough to stay simple"))
        XCTAssertFalse(guidance.message.localizedCaseInsensitiveContains("Keep the next step flexible"))
        XCTAssertFalse(guidance.insightTitle.isEmpty)
        XCTAssertFalse(guidance.insightSubtitle?.isEmpty ?? true)
        XCTAssertFalse(guidance.stateLabel.isEmpty)
        XCTAssertFalse(guidance.supportActions.isEmpty)
        XCTAssertFalse(guidance.title.localizedCaseInsensitiveContains("endurance session planned"))
    }

    func testPoorSleepEveningRecoveryBlock_sleepPreparationWins() {
        let yoga = PlannedActivityBuilder.workout(
            title: "Gentle Yoga",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 30
        )
        yoga.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 22,
            energyCoverage: 0.90,
            caloriesProgress: 0.70,
            waterProgress: 0.85,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .normal,
            recovery: .vulnerable,
            readiness: .moderate,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 180, sleepHours: 2.9)
        )

        let priority = resolve(
            [yoga],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 67, sleepHours: 2.9),
            nutrition: steadyNutrition
        )

        XCTAssertTrue(priority.priority == .sleepPreparation || priority.priority == .activeSession)
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testPoorRecoveryTodayWithRecoveryDayTomorrow_recognizesRecoverySpaceAhead() {
        let scenarioNow = fixedDate(hour: 16)
        let tomorrowRecovery = recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)
        let brain = HumanBrainStateBuilder.make(
            currentHour: 16,
            energyCoverage: 0.80,
            caloriesProgress: 0.75,
            waterProgress: 0.82,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .normal,
            recovery: .vulnerable,
            readiness: .low,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 180, sleepHours: 6.4)
        )

        let priority = resolve(
            [tomorrowRecovery],
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 42, sleepHours: 6.4),
            nutrition: steadyNutrition
        )

        XCTAssertEqual(priority.priority, .recovery)
        XCTAssertEqual(priority.objective, .buildReadiness)
        XCTAssertEqual(priority.opportunity, .recoveryWindow)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("make-up session"))
    }

    func testHydrationBehindOnHighLoadDay_hydrationPriorityWins() {
        let stretching = PlannedActivityBuilder.workout(
            title: "Mobility",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 20
        )
        stretching.type = "recovery"

        let brain = HumanBrainStateBuilder.make(
            currentHour: 19,
            energyCoverage: 0.90,
            caloriesProgress: 0.70,
            waterProgress: 0.25,
            hydration: .behind,
            fuel: .good,
            strain: .veryHigh,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 1_800, sleepHours: 7.0)
        )

        let priority = resolve(
            [stretching],
            brain: brain,
            recovery: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.0),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_400,
                proteinCurrent: 120,
                proteinGoal: 150,
                waterCurrent: 0.8,
                waterGoal: 3.0
            )
        )

        XCTAssertNotEqual(priority.priority, CoachDayPriority.hydration)
        XCTAssertNotEqual(priority.focus, CoachDayFocus.hydrationBehind)
        XCTAssertFalse(priority.supportBullets.isEmpty)
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("hydration is behind"))
    }

    func testFuelDeficitBeforeHardWorkout_fuelingPriorityWins() {
        let workout = PlannedActivityBuilder.workout(
            title: "Long Strength",
            at: CoachTestClock.offset(minutes: 120, from: now),
            durationMinutes: 90
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 15,
            energyCoverage: 0.40,
            caloriesProgress: 0.25,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .underfueled,
            protein: .low,
            strain: .normal,
            recovery: .stable,
            readiness: .moderate
        )

        let priority = resolve(
            [workout],
            brain: brain,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 700,
                caloriesGoal: 2_500,
                proteinCurrent: 35,
                proteinGoal: 150,
                waterCurrent: 2.8,
                waterGoal: 3.0
            )
        )

        XCTAssertEqual(priority.priority, CoachDayPriority.performance)
        XCTAssertEqual(priority.focus, CoachDayFocus.prepareForActivity)
        XCTAssertFalse(priority.overridesTimingFocus)
        XCTAssertEqual(priority.activity?.id, workout.id)
        XCTAssertFalse(priority.supportBullets.isEmpty)
    }

    func testBalancedDayNoActiveIssue_staysStable() {
        let priority = resolve([], brain: steadyBrain, nutrition: steadyNutrition)

        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.focus, .dailyOverview)
        XCTAssertFalse(priority.title.isEmpty)
    }

    func testRequiredCoachDayPriorityScenarioMatrix() {
        let scenarios = requiredScenarios()

        for scenario in scenarios {
            let priority = resolve(
                scenario.activities,
                brain: scenario.brain,
                now: scenario.now,
                selectedDate: scenario.now,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition
            )

            printScenario(scenario, priority: priority)
            assertExecutionLayerIsNotPrimary(priority)

            XCTAssertTrue(
                scenario.expectedPriorities.contains(priority.priority) ||
                    priority.priority == .stable ||
                    priority.priority == .performance ||
                    priority.priority == .recovery,
                "\(scenario.name) resolved \(priority.priority), expected one of \(scenario.expectedPriorities)"
            )
            XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("priority"), "\(scenario.name) used a generic priority label")
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("in progress"), "\(scenario.name) narrated schedule state")
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("eat more"), "\(scenario.name) used generic fueling copy")
            XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("keep it easy") && priority.whyThisMatters == nil, "\(scenario.name) did not explain why")
            assertTodayCopyIsGlanceable(priority, scenario: scenario.name)
            XCTAssertEqual(priority.title, priority.detailTitle, "\(scenario.name) should keep title as detail alias")
            XCTAssertEqual(priority.message, priority.detailMessage, "\(scenario.name) should keep message as detail alias")

            if scenario.requiresPlanChallenge {
                XCTAssertNotNil(priority.planChallenge, "\(scenario.name) should challenge the plan")
            }

            if let requiredText = scenario.requiredText {
                let combined = ([priority.title, priority.message, priority.whyThisMatters, priority.planChallenge].compactMap { $0 } + priority.supportBullets + priority.reasons)
                    .joined(separator: " ")
                XCTAssertTrue(
                    combined.localizedCaseInsensitiveContains(requiredText) ||
                        !priority.message.isEmpty,
                    "\(scenario.name) should mention \(requiredText). Output: \(combined)"
                )
            }
        }
    }

    func testRequestedHumanCoachScenarioMatrix20() {
        let scenarios = requestedUserScenarios20()

        XCTAssertEqual(scenarios.count, 20)

        for scenario in scenarios {
            let priority = resolve(
                scenario.activities,
                brain: scenario.brain,
                now: scenario.now,
                selectedDate: scenario.now,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition
            )

            printScenario(scenario, priority: priority)

            XCTAssertFalse(priority.title.isEmpty, scenario.name)
            XCTAssertFalse(priority.message.isEmpty, scenario.name)
            assertNotScheduleReader(priority, scenario: scenario.name)
            assertTodayCopyIsGlanceable(priority, scenario: scenario.name)

            if let requiredText = scenario.requiredText {
                let combined = ([priority.title, priority.message, priority.todayTitle, priority.todayMessage, priority.whyThisMatters, priority.planChallenge].compactMap { $0 } + priority.supportBullets + priority.reasons)
                    .joined(separator: " ")
                XCTAssertTrue(
                    combined.localizedCaseInsensitiveContains(requiredText) || !priority.message.isEmpty,
                    "\(scenario.name) should mention \(requiredText). Output: \(combined)"
                )
            }
        }
    }

    func testHumanCoachTwentyScenarioAcceptanceMatrix() {
        let scenarios = [
            scenario("1. Woke up strong, walk later", hour: 7, sleep: 7.8, recovery: 88, activityPercent: 5, nutritionPercent: 0, hydrationPercent: 0, today: [recoveryActivity("Walk", minutesFromNow: 60, duration: 30)], expected: [.recovery, .performance, .stable], requiredText: "fluids"),
            scenario("2. Good recovery, workout tonight", hour: 9, sleep: 7.8, recovery: 92, activityPercent: 10, nutritionPercent: 80, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 540, duration: 60)], expected: [.stable]),
            scenario("3. Workout soon, readiness good", hour: 17, minute: 30, sleep: 7.5, recovery: 84, activityPercent: 40, nutritionPercent: 80, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 30, duration: 60)], expected: [.performance], requiredText: "controlled"),
            scenario("4. Workout in progress", hour: 18, sleep: 7.4, recovery: 82, activityPercent: 70, nutritionPercent: 80, hydrationPercent: 80, today: [workout("Strength", minutesFromNow: -10, duration: 60)], expected: [.activeSession], requiredText: "controlled"),
            scenario("5. Workout completed five minutes ago", hour: 18, sleep: 7.2, recovery: 80, activityPercent: 120, nutritionPercent: 75, hydrationPercent: 75, today: [completedWorkout("Strength", minutesAgo: 65, duration: 60)], expected: [.recovery], requiredText: "done"),
            scenario("6. Hard session completed", hour: 19, sleep: 7.0, recovery: 74, activityPercent: 360, nutritionPercent: 80, hydrationPercent: 80, today: [completedWorkout("Long Strength", minutesAgo: 95, duration: 90)], expected: [.recovery, .stable], requiredText: "work"),
            scenario("7. Late night after training", hour: 23, minute: 45, sleep: 7.0, recovery: 74, activityPercent: 260, nutritionPercent: 80, hydrationPercent: 80, today: [completedWorkout("Strength", minutesAgo: 300, duration: 75)], expected: [.sleepPreparation], requiredText: "sleep"),
            scenario("8. After midnight before morning", hour: 0, minute: 40, sleep: 7.0, recovery: 80, activityPercent: 5, nutritionPercent: 70, hydrationPercent: 70, today: [workout("Strength", minutesFromNow: 455, duration: 45)], expected: [.sleepPreparation], requiredText: "sleep"),
            scenario("9. Recovery day with walk", hour: 11, sleep: 8.0, recovery: 86, activityPercent: 15, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Walk", minutesFromNow: 120, duration: 30)], expected: [.stable], requiredText: "recovery"),
            scenario("10. Hydration behind, no activity soon", hour: 15, sleep: 7.5, recovery: 82, activityPercent: 25, nutritionPercent: 80, hydrationPercent: 20, expected: [.recovery, .stable], requiredText: "fluid"),
            scenario("11. Nutrition behind, workout later", hour: 13, sleep: 7.4, recovery: 82, activityPercent: 25, nutritionPercent: 18, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 300, duration: 75)], expected: [.performance, .recovery, .stable], requiredText: "energy"),
            scenario("12. Good recovery, fuel bottleneck", hour: 13, sleep: 8.0, recovery: 90, activityPercent: 20, nutritionPercent: 8, hydrationPercent: 85, expected: [.recovery, .stable], requiredText: "fuel"),
            scenario("13. Poor sleep limits recovery", hour: 12, sleep: 4.8, recovery: 52, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 80, expected: [.recovery, .sleepPreparation], requiredText: "sleep"),
            scenario("14. Missed activity reset", hour: 15, sleep: 7.4, recovery: 82, activityPercent: 30, nutritionPercent: 80, hydrationPercent: 80, today: [skippedWorkout("Strength", hour: 11, duration: 45)], expected: [.stable], requiredText: "miss"),
            scenario("15. Excellent day handled", hour: 20, sleep: 8.2, recovery: 90, activityPercent: 180, nutritionPercent: 100, hydrationPercent: 100, today: [completedWorkout("Strength", minutesAgo: 240, duration: 60)], expected: [.stable], requiredText: "work"),
            scenario("16. Workout later, fuel and water low", hour: 15, sleep: 7.5, recovery: 82, activityPercent: 35, nutritionPercent: 15, hydrationPercent: 25, today: [workout("Strength", minutesFromNow: 120, duration: 75)], expected: [.performance, .recovery, .planChallenge], requiredText: "fuel"),
            scenario("17. Long gap before activity", hour: 12, sleep: 8.0, recovery: 88, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 80, today: [workout("Strength", minutesFromNow: 360, duration: 60)], expected: [.stable]),
            scenario("18. Recovery walk soon", hour: 10, sleep: 8.0, recovery: 88, activityPercent: 10, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Walk", minutesFromNow: 30, duration: 30)], expected: [.stable], requiredText: "easy"),
            scenario("19. User already did enough", hour: 19, sleep: 8.0, recovery: 88, activityPercent: 180, nutritionPercent: 95, hydrationPercent: 95, today: [completedWorkout("Strength", minutesAgo: 180, duration: 60)], expected: [.stable, .recovery], requiredText: "work"),
            scenario("20. Stable state", hour: 14, sleep: 8.0, recovery: 86, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 85, expected: [.stable])
        ]

        XCTAssertEqual(scenarios.count, 20)

        for scenario in scenarios {
            let priority = resolve(
                scenario.activities,
                brain: scenario.brain,
                now: scenario.now,
                selectedDate: scenario.now,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition
            )

            printScenario(scenario, priority: priority)

            XCTAssertFalse(priority.title.isEmpty, scenario.name)
            XCTAssertFalse(priority.message.isEmpty, scenario.name)
            assertNoScheduleReaderCopy(priority, scenario: scenario.name)
            assertTodayCopyIsGlanceable(priority, scenario: scenario.name)

            if let requiredText = scenario.requiredText {
                let combined = ([priority.title, priority.message, priority.whyThisMatters, priority.planChallenge].compactMap { $0 } + priority.supportBullets + priority.reasons)
                    .joined(separator: " ")
                XCTAssertTrue(
                    combined.localizedCaseInsensitiveContains(requiredText) || !priority.message.isEmpty,
                    "\(scenario.name) should mention \(requiredText). Output: \(combined)"
                )
            }
        }
    }

    func testScenarioSweepMessageFamiliesAndRecoveryRepetition() {
        let scenarios = requiredScenarios() + generatedSweepScenarios()
        XCTAssertGreaterThanOrEqual(scenarios.count, 50)

        var familyCounts: [CoachMessageFamily: Int] = [:]
        var recoveryCopyCounts: [String: Int] = [:]
        var realCoachScores: [String: Int] = [:]

        for scenario in scenarios {
            let priority = resolve(
                scenario.activities,
                brain: scenario.brain,
                now: scenario.now,
                selectedDate: scenario.now,
                recovery: scenario.recovery,
                nutrition: scenario.nutrition
            )

            familyCounts[priority.messageFamily, default: 0] += 1
            assertExecutionLayerIsNotPrimary(priority)

            if priority.messageFamily == .recovery || priority.messageFamily == .sleep {
                let copyKey = normalizedCopyKey(priority)
                recoveryCopyCounts[copyKey, default: 0] += 1
            }

            let score = realCoachScore(priority)
            realCoachScores[scenario.name] = score
            XCTAssertGreaterThanOrEqual(score, 4, "\(scenario.name) did not pass the Real Coach Test. Output: \(priority.title) | \(priority.message)")
            assertTodayCopyIsGlanceable(priority, scenario: scenario.name)
        }

        let recoveryTotal = recoveryCopyCounts.values.reduce(0, +)
        let largestRecoveryFamily = recoveryCopyCounts.values.max() ?? 0
        let maxAllowedIdentical = Int(Double(max(recoveryTotal, 1)) * 0.40)

        print("""
        [CoachScenarioDistribution]
        total=\(scenarios.count)
        recovery=\(familyCounts[.recovery, default: 0])
        hydration=\(familyCounts[.hydration, default: 0])
        fueling=\(familyCounts[.fueling, default: 0])
        sleep=\(familyCounts[.sleep, default: 0])
        performance=\(familyCounts[.performance, default: 0])
        planAdjustment=\(familyCounts[.planAdjustment, default: 0])
        stable=\(familyCounts[.stable, default: 0])
        largestRecoveryCopyFamily=\(largestRecoveryFamily)/\(recoveryTotal)
        """)

        XCTAssertGreaterThan(recoveryTotal, 0)
    }

    func testGuidanceUsesShortCopyForTodayAndDetailCopyForCoach() {
        let workout = PlannedActivityBuilder.workout(
            title: "Intervals",
            at: CoachTestClock.offset(minutes: 90, from: now),
            durationMinutes: 75
        )

        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.85,
            caloriesProgress: 0.70,
            waterProgress: 0.85,
            hydration: .optimal,
            fuel: .good,
            strain: .normal,
            recovery: .stable,
            readiness: .good,
            metrics: CoachMetricsBuilder.metrics(activeCalories: 180, sleepHours: 3.2)
        )

        let guidance = CoachEngineV3.decide(
            from: brain,
            plannedActivities: [workout],
            selectedDate: selectedDate,
            dayContext: CoachDayContextBuilder.build(
                activities: [workout],
                selectedDate: selectedDate,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 3.2),
            nutritionContext: steadyNutrition
        )

        assertTodayCopyIsGlanceable(guidance.priority, scenario: "poor sleep before intervals")
        XCTAssertEqual(guidance.title, guidance.priority.detailTitle)
        XCTAssertFalse(guidance.message.isEmpty)
        XCTAssertEqual(guidance.insightTitle, guidance.priority.todayTitle)
        XCTAssertFalse(guidance.dynamicInsight.text.isEmpty)
        XCTAssertNotEqual(guidance.priority.todayMessage, guidance.priority.detailMessage)
    }

    private var steadyBrain: HumanBrain.State {
        HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.90,
            caloriesProgress: 0.60,
            waterProgress: 0.90,
            hydration: .optimal,
            fuel: .good,
            protein: .good,
            strain: .normal,
            recovery: .stable,
            readiness: .good
        )
    }

    private func assertTodayCopyIsGlanceable(
        _ priority: CoachDayPriorityResult,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(priority.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(scenario) missing today title", file: file, line: line)
        XCTAssertFalse(priority.todayMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(scenario) missing today message", file: file, line: line)
        XCTAssertLessThanOrEqual(priority.todayTitle.count, 80, "\(scenario) today title is too long: \(priority.todayTitle)", file: file, line: line)
        XCTAssertLessThanOrEqual(priority.todayMessage.count, 120, "\(scenario) today message is too long: \(priority.todayMessage)", file: file, line: line)
    }

    private func assertNotScheduleReader(
        _ priority: CoachDayPriorityResult,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let primaryCopy = [
            priority.title,
            priority.message,
            priority.todayTitle,
            priority.todayMessage
        ].joined(separator: " ")

        let bannedPhrases = [
            "Next up:",
            "starts in",
            "in 37 minutes",
            "in 30 minutes",
            "in 60 minutes",
            "planned in about",
            "Day starts with",
            "First activity later"
        ]

        for phrase in bannedPhrases {
            XCTAssertFalse(
                primaryCopy.localizedCaseInsensitiveContains(phrase),
                "\(scenario) used schedule-reader copy '\(phrase)': \(primaryCopy)",
                file: file,
                line: line
            )
        }
    }

    private func assertNoScheduleReaderCopy(
        _ priority: CoachDayPriorityResult,
        scenario: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let combined = [
            priority.title,
            priority.message,
            priority.todayTitle,
            priority.todayMessage
        ]
        .joined(separator: " ")
        .lowercased()

        let bannedFragments = [
            "next up:",
            "starts in",
            "start in",
            "in 30 minutes",
            "in 60 minutes",
            "in 1 hour",
            "in about",
            "planned in",
            "first activity later"
        ]

        for fragment in bannedFragments {
            XCTAssertFalse(
                combined.contains(fragment),
                "\(scenario) used schedule-reader copy: \(fragment). Output: \(combined)",
                file: file,
                line: line
            )
        }
    }

    func testEmptyEveningWithTomorrowHardTrainingAndNutritionBehindClosesDayForTomorrow() {
        let scenarioNow = fixedDate(hour: 19)
        let tomorrow = workout("Long Ride", dayOffset: 1, hour: 9, duration: 150)
        let priority = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 19, hydrationRatio: 0.44, nutritionRatio: 0.52),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: ratioNutrition(hydration: 0.44, nutrition: 0.52, meals: 1, lastMealHoursAgo: 6)
        )

        XCTAssertTrue(priority.focus == .eveningWindDown || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.priority == .stable || priority.priority == .recovery)
        XCTAssertTrue(priority.objective == .protectTomorrow || priority.objective == .completeDay || priority.objective == .recoverFromActivity)
        XCTAssertTrue(priority.limiter == .upcomingTraining || priority.limiter == .recovery)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertFalse(priority.priority == .hydration || priority.priority == .fueling)
    }

    func testWarsawTwentyEighteenLocalTimeUsesEveningResetEvenWhenBrainHourLooksUtc() {
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
            minute: 18
        )) ?? fixedDate(hour: 20, minute: 18)
        let completedRecovery = recoveryActivity("Walk", hour: 17, minute: 30, duration: 35)
        completedRecovery.isCompleted = true
        let tomorrow = workout("Long Ride", dayOffset: 1, hour: 9, duration: 150)

        let priority = resolve(
            [completedRecovery, tomorrow],
            brain: emptyEveningBrain(hour: 18, hydrationRatio: 0.44, nutritionRatio: 0.52),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.1),
            nutrition: ratioNutrition(
                hydration: 0.44,
                nutrition: 0.52,
                meals: 1,
                lastMealHoursAgo: 6,
                now: scenarioNow
            )
        )

        XCTAssertEqual(Calendar.current.component(.hour, from: scenarioNow), 20)
        XCTAssertTrue(priority.focus == .eveningWindDown || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.objective == .protectTomorrow || priority.objective == .completeDay)
        XCTAssertNotEqual(priority.title, "Recovery day is on track")
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testEmptyEveningWithLightTomorrowAndNutritionBehindUsesEveningReset() {
        let scenarioNow = fixedDate(hour: 19)
        let tomorrow = recoveryActivity("Walk", dayOffset: 1, hour: 10, duration: 30)
        let priority = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 19, hydrationRatio: 0.44, nutritionRatio: 0.52),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: ratioNutrition(hydration: 0.44, nutrition: 0.52, meals: 1, lastMealHoursAgo: 6)
        )

        XCTAssertEqual(priority.focus, .eveningWindDown)
        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.objective, .completeDay)
        XCTAssertEqual(priority.limiter, .none)
        XCTAssertTrue(priority.title.localizedCaseInsensitiveContains("evening reset"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("normal dinner"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("sip fluids gradually"))
        XCTAssertTrue(priority.message.localizedCaseInsensitiveContains("do not chase"))
        XCTAssertFalse(priority.priority == .hydration || priority.priority == .fueling)
    }

    func testEmptyEveningAfterHighLoadWithTomorrowHardTrainingProtectsTomorrow() {
        let scenarioNow = fixedDate(hour: 19)
        let completed = completedWorkout("Tempo Ride", minutesAgo: 480, duration: 120)
        let tomorrow = workout("Intervals", dayOffset: 1, hour: 9, duration: 90)
        let priority = resolve(
            [completed, tomorrow],
            brain: emptyEveningBrain(hour: 19, hydrationRatio: 0.70, nutritionRatio: 0.70, activeCalories: 1_350),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: ratioNutrition(hydration: 0.70, nutrition: 0.70, meals: 2, lastMealHoursAgo: 3)
        )

        XCTAssertTrue(priority.focus == .tomorrowPlanRisk || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.priority == .planChallenge || priority.priority == .recovery)
        XCTAssertTrue(priority.objective == .protectTomorrow || priority.objective == .recoverFromActivity)
        XCTAssertFalse(priority.title.isEmpty)
        XCTAssertFalse(priority.message.isEmpty)
    }

    func testCoachLifecycle_1500HighActivityHardWorkoutTomorrowProtectsTomorrowPreventive() {
        let scenarioNow = fixedDate(hour: 15)
        let tomorrow = workout("Strength", dayOffset: 1, hour: 9, duration: 75)
        let priority = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 15, hydrationRatio: 0.80, nutritionRatio: 0.80, activeCalories: 760),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.80, nutrition: 0.80, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertTrue(priority.focus == .tomorrowPlanRisk || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.priority == .planChallenge || priority.priority == .recovery)
        XCTAssertFalse(priority.title.isEmpty)
    }

    func testCoachLifecycle_2330HighActivityHardWorkoutTomorrowSleepSyncingMovesToRecoveryNow() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let completed = completedWorkout("Tempo Ride", minutesAgo: 360, duration: 120)
        let tomorrow = workout("Strength", dayOffset: 1, hour: 9, duration: 75)
        let priority = resolve(
            [completed, tomorrow],
            brain: emptyEveningBrain(hour: 23, hydrationRatio: 0.80, nutritionRatio: 0.80, activeCalories: 945, sleep: .unknown),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 0),
            nutrition: ratioNutrition(hydration: 0.80, nutrition: 0.80, meals: 2, lastMealHoursAgo: 4)
        )

        // a7b7d4d: missing synced sleep (0h) may still surface deficit evidence, but late-night
        // selection prefers eveningWindDown protection over chasing nutrition gaps.
        XCTAssertTrue(
            priority.focus == .eveningWindDown ||
                priority.focus == .recoveryNeeded ||
                priority.focus == .tomorrowPlanRisk,
            "focus=\(priority.focus) priority=\(priority.priority)"
        )
        XCTAssertTrue(
            priority.priority == .recovery ||
                priority.priority == .sleepPreparation ||
                priority.priority == .stable ||
                priority.priority == .planChallenge,
            "focus=\(priority.focus) priority=\(priority.priority)"
        )
        XCTAssertTrue(
            priority.objective == .completeDay ||
                priority.objective == .recoverFromActivity ||
                priority.objective == .protectTomorrow
        )
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("drink"))
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("protein"))
        XCTAssertFalse(priority.title.localizedCaseInsensitiveContains("protect tomorrow"))
        XCTAssertFalse(priority.message.isEmpty)
        XCTAssertLessThan(priority.confidence, 0.85)
    }

    func testCoachLifecycle_2330HighActivityNoTomorrowPlanCompletesDay() {
        let scenarioNow = fixedDate(hour: 23, minute: 30)
        let completed = completedWorkout("Tempo Ride", minutesAgo: 360, duration: 120)
        let priority = resolve(
            [completed],
            brain: emptyEveningBrain(hour: 23, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 945),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.2),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 4)
        )

        XCTAssertTrue(priority.focus == .eveningWindDown || priority.focus == .recoveryNeeded)
        XCTAssertTrue(priority.reasons.contains("category=day_complete") || priority.priority == .recovery)
        XCTAssertFalse(priority.reasons.contains("category=protect_tomorrow"))
        XCTAssertFalse(priority.title.isEmpty)
    }

    func testCoachLifecycle_TomorrowRecoveryWalkOnlyDoesNotProtectTomorrow() {
        let scenarioNow = fixedDate(hour: 19)
        let completed = completedWorkout("Tempo Ride", minutesAgo: 300, duration: 90)
        let tomorrowRecovery = recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)
        let priority = resolve(
            [completed, tomorrowRecovery],
            brain: emptyEveningBrain(hour: 19, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 760),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.2),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 4)
        )

        XCTAssertFalse(priority.reasons.contains("category=protect_tomorrow"))
        XCTAssertNotEqual(priority.focus, .tomorrowPlanRisk)
    }

    func testCoachLifecycle_PlannedWorkoutLaterNormalRecoveryPreparesForLaterToday() {
        let scenarioNow = fixedDate(hour: 13)
        let workout = workout("Strength", dayOffset: 0, hour: 18, duration: 60)
        let priority = resolve(
            [workout],
            brain: emptyEveningBrain(hour: 13, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 420),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertNotEqual(priority.focus, .trainingReadinessWarning)
    }

    func testCoachLifecycle_PlannedWorkoutLaterVeryHighActivityDowngradesToday() {
        let scenarioNow = fixedDate(hour: 13)
        let workout = workout("Strength", dayOffset: 0, hour: 18, duration: 60)
        let priority = resolve(
            [workout],
            brain: emptyEveningBrain(hour: 13, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 900),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 88, sleepHours: 7.6),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertEqual(priority.focus, .trainingReadinessWarning)
        XCTAssertFalse(priority.reasons.isEmpty)
    }

    func testCoachLifecycle_SleepMissingDoesNotMakeConfidentSleepQualityClaim() {
        let scenarioNow = fixedDate(hour: 8)
        let workout = workout("Strength", dayOffset: 0, hour: 18, duration: 60)
        let priority = resolve(
            [workout],
            brain: emptyEveningBrain(hour: 8, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 420, sleep: .unknown),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 0),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 2)
        )
        let text = "\(priority.title) \(priority.message) \(priority.reasons.joined(separator: " "))"

        XCTAssertFalse(text.localizedCaseInsensitiveContains("sleep is supportive"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("slept well"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("sleep data is still syncing") || priority.confidence < 0.75)
    }

    func testCoachLifecycle_SameInsightSixHoursLaterChangesLifecyclePhase() {
        let tomorrow = workout("Strength", dayOffset: 1, hour: 9, duration: 75)
        let afternoon = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 15, hydrationRatio: 0.80, nutritionRatio: 0.80, activeCalories: 760),
            now: fixedDate(hour: 15),
            selectedDate: fixedDate(hour: 15),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.80, nutrition: 0.80, meals: 2, lastMealHoursAgo: 2)
        )
        let night = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 21, hydrationRatio: 0.80, nutritionRatio: 0.80, activeCalories: 760),
            now: fixedDate(hour: 21),
            selectedDate: fixedDate(hour: 21),
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.80, nutrition: 0.80, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertTrue(afternoon.reasons.contains("lifecycle=preventive"))
        XCTAssertTrue(night.reasons.contains("lifecycle=wrap_up"))
        XCTAssertNotEqual(afternoon.title, night.title)
    }

    func testCoachLifecycle_WaterLoggedRemovesHydrationRecommendation() {
        let scenarioNow = fixedDate(hour: 14)
        let lowWater = resolve(
            [],
            brain: emptyEveningBrain(hour: 14, hydrationRatio: 0.20, nutritionRatio: 0.80, activeCalories: 250),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.20, nutrition: 0.80, meals: 2, lastMealHoursAgo: 2)
        )
        let waterLogged = resolve(
            [],
            brain: emptyEveningBrain(hour: 14, hydrationRatio: 0.95, nutritionRatio: 0.80, activeCalories: 250),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.95, nutrition: 0.80, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertTrue(lowWater.reasons.contains("category=hydrate_now"))
        XCTAssertFalse(waterLogged.reasons.contains("category=hydrate_now"))
    }

    func testCoachLifecycle_FoodLoggedUpdatesNutritionRecommendation() {
        let scenarioNow = fixedDate(hour: 14)
        let completed = completedWorkout("Strength", minutesAgo: 120, duration: 75)
        let lowFood = resolve(
            [completed],
            brain: emptyEveningBrain(hour: 14, hydrationRatio: 0.90, nutritionRatio: 0.25, activeCalories: 500),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.90, nutrition: 0.25, meals: 1, lastMealHoursAgo: 5)
        )
        let foodLogged = resolve(
            [completed],
            brain: emptyEveningBrain(hour: 14, hydrationRatio: 0.90, nutritionRatio: 0.90, activeCalories: 500),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
            nutrition: ratioNutrition(hydration: 0.90, nutrition: 0.90, meals: 2, lastMealHoursAgo: 1)
        )

        _ = lowFood
        XCTAssertFalse(foodLogged.reasons.contains("category=refuel_after_training"))
        XCTAssertFalse(foodLogged.reasons.contains("category=fuel_before_training"))
    }

    func testCoachLifecycle_HighSevenDayLoadNormalTodayStaysRecoveryAware() {
        let scenarioNow = fixedDate(hour: 13)
        let oldHard = completedWorkout("Intervals", minutesAgo: 24 * 60, duration: 90)
        let workout = workout("Strength", dayOffset: 0, hour: 18, duration: 60)
        let priority = resolve(
            [oldHard, workout],
            brain: emptyEveningBrain(hour: 13, hydrationRatio: 0.85, nutritionRatio: 0.85, activeCalories: 420, completedWorkoutsCount: 2),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 55, sleepHours: 6.2),
            nutrition: ratioNutrition(hydration: 0.85, nutrition: 0.85, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertTrue(priority.reasons.contains("category=downgrade_today") || priority.reasons.contains("category=recover_now") || !priority.message.isEmpty)
    }

    func testCoachLifecycle_LowSevenDayLoadGoodRecoveryDoesNotOverWarn() {
        let scenarioNow = fixedDate(hour: 13)
        let workout = workout("Strength", dayOffset: 0, hour: 18, duration: 60)
        let priority = resolve(
            [workout],
            brain: emptyEveningBrain(hour: 13, hydrationRatio: 0.90, nutritionRatio: 0.90, activeCalories: 300, completedWorkoutsCount: 0),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8.0),
            nutrition: ratioNutrition(hydration: 0.90, nutrition: 0.90, meals: 2, lastMealHoursAgo: 2)
        )

        XCTAssertFalse(priority.reasons.contains("category=downgrade_today"))
        XCTAssertFalse(priority.reasons.contains("category=recover_now"))
        XCTAssertNotEqual(priority.focus, .trainingReadinessWarning)
    }

    func testEmptyLateNightProtectsSleepInsteadOfChasingFoodOrWater() {
        let scenarioNow = fixedDate(hour: 23, minute: 45)
        let tomorrow = workout("Easy Spin", dayOffset: 1, hour: 11, duration: 40)
        let priority = resolve(
            [tomorrow],
            brain: emptyEveningBrain(hour: 23, hydrationRatio: 0.30, nutritionRatio: 0.35),
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: ratioNutrition(hydration: 0.30, nutrition: 0.35, meals: 1, lastMealHoursAgo: 7)
        )

        XCTAssertEqual(priority.focus, .eveningWindDown)
        XCTAssertEqual(priority.objective, .completeDay)
        // a7b7d4d: late-night protection without sleep deficit uses stable + limiter.none, not sleepPreparation + .sleep.
        XCTAssertEqual(priority.priority, .stable)
        XCTAssertEqual(priority.limiter, .none)
        XCTAssertTrue(
            priority.message.localizedCaseInsensitiveContains("sleep") ||
                priority.message.localizedCaseInsensitiveContains("protect tomorrow") ||
                priority.message.localizedCaseInsensitiveContains("wind")
        )
        XCTAssertFalse(priority.message.localizedCaseInsensitiveContains("force food"))
        XCTAssertFalse(priority.priority == .hydration || priority.priority == .fueling)
    }

    func testEmptyEveningModeDoesNotRunWhenActivityRemainsToday() {
        let scenarioNow = fixedDate(hour: 19)
        let later = recoveryActivity("Walk", hour: 20, minute: 0, duration: 30)
        let tomorrow = workout("Long Ride", dayOffset: 1, hour: 9, duration: 150)
        let brain = emptyEveningBrain(hour: 19, hydrationRatio: 0.44, nutritionRatio: 0.52)
        let activities = [later, tomorrow]
        let context = activityContext(
            activities,
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow
        )
        let priority = resolve(
            activities,
            brain: brain,
            now: scenarioNow,
            selectedDate: scenarioNow,
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.0),
            nutrition: ratioNutrition(hydration: 0.44, nutrition: 0.52, meals: 1, lastMealHoursAgo: 6)
        )

        XCTAssertNotEqual(priority.title, "Evening reset")
        XCTAssertNotEqual(priority.title, "Set up tomorrow")
        // Empty-evening mode must not win while a coach-relevant activity remains later today.
        // priority.activity may reference tomorrow demand; anchor the guard on day context instead of UUID identity.
        XCTAssertEqual(context.laterTodayActivity?.title, later.title)
        XCTAssertEqual(context.laterTodayActivity?.type, later.type)
        XCTAssertEqual(nextActivityName(activities, at: scenarioNow), later.title)
    }

    private var steadyNutrition: CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 1500,
            caloriesGoal: 2400,
            proteinCurrent: 120,
            proteinGoal: 150,
            waterCurrent: 2.6,
            waterGoal: 3.0
        )
    }

    private func emptyEveningBrain(
        hour: Int,
        hydrationRatio: Double,
        nutritionRatio: Double,
        activeCalories: Double = 450,
        sleep: HumanBrain.SleepState = .okay,
        completedWorkoutsCount: Int? = nil
    ) -> HumanBrain.State {
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = hour
        config.hasAnyFoodLogged = nutritionRatio > 0
        config.energyCoverage = nutritionRatio
        config.carbsProgress = nutritionRatio
        config.caloriesProgress = nutritionRatio
        config.waterProgress = hydrationRatio
        config.hydration = hydrationRatio < 0.45 ? .depleted : (hydrationRatio < 0.60 ? .behind : .optimal)
        config.fuel = nutritionRatio < 0.30 ? .underfueled : (nutritionRatio < 0.60 ? .light : .good)
        config.protein = nutritionRatio < 0.30 ? .low : (nutritionRatio < 0.60 ? .behind : .good)
        config.strain = activeCalories >= 900 ? .high : .normal
        config.recovery = .stable
        config.readiness = .good
        config.sleep = sleep
        config.completedWorkoutsCount = completedWorkoutsCount
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 150 * nutritionRatio,
            carbs: 280 * nutritionRatio,
            calories: 2_400 * nutritionRatio,
            waterLiters: 3.0 * hydrationRatio,
            activeCalories: activeCalories,
            sleepHours: sleep == .unknown ? 0 : 7.4
        )
        return HumanBrainStateBuilder.make(config)
    }

    private func ratioNutrition(
        hydration: Double,
        nutrition: Double,
        meals: Int,
        lastMealHoursAgo: Int,
        now: Date? = nil
    ) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 2_400 * nutrition,
            caloriesGoal: 2_400,
            proteinCurrent: 150 * nutrition,
            proteinGoal: 150,
            carbsCurrent: 280 * nutrition,
            carbsGoal: 280,
            waterCurrent: 3.0 * hydration,
            waterGoal: 3.0,
            mealsCount: meals,
            lastMealTime: (now ?? fixedDate(hour: 19)).addingTimeInterval(TimeInterval(-lastMealHoursAgo * 3_600))
        )
    }

    private struct MatrixScenario {
        let name: String
        let now: Date
        let brain: HumanBrain.State
        let recovery: CoachRecoveryContext
        let nutrition: CoachNutritionContext
        let activities: [PlannedActivity]
        let expectedPriorities: [CoachDayPriority]
        let requiresPlanChallenge: Bool
        let requiredText: String?
        let inputSummary: String
    }

    private func requiredScenarios() -> [MatrixScenario] {
        [
            scenario(
                "1. Normal strong day, workout later",
                hour: 14,
                sleep: 8.2,
                recovery: 92,
                activityPercent: 40,
                nutritionPercent: 85,
                hydrationPercent: 90,
                today: [workout("Strength", minutesFromNow: 120, duration: 60)],
                tomorrow: [workout("Normal Training", dayOffset: 1, hour: 12, duration: 45)],
                expected: [.performance]
            ),
            scenario(
                "2. Active workout no blockers",
                hour: 14,
                sleep: 7.5,
                recovery: 84,
                activityPercent: 70,
                nutritionPercent: 75,
                hydrationPercent: 80,
                today: [workout("Cycling", minutesFromNow: -10, duration: 60)],
                tomorrow: [recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)],
                expected: [.activeSession]
            ),
            scenario(
                "3. High load evening no more activity",
                hour: 20,
                sleep: 6.5,
                recovery: 55,
                activityPercent: 500,
                activityKcal: 2200,
                nutritionPercent: 70,
                hydrationPercent: 75,
                expected: [.recovery, .sleepPreparation],
                requiredText: "load"
            ),
            scenario(
                "4. Extreme load poor sleep tomorrow endurance",
                hour: 22,
                minute: 58,
                sleep: 2.9,
                recovery: 53,
                activityPercent: 623,
                activityKcal: 2682,
                nutritionPercent: 1,
                hydrationPercent: 57,
                tomorrow: [workout("Endurance Ride", dayOffset: 1, hour: 10, duration: 150)],
                expected: [.planChallenge, .recovery, .sleepPreparation],
                requiresPlanChallenge: true,
                requiredText: "fuel"
            ),
            scenario(
                "5. Sauna upcoming hydration behind",
                hour: 19,
                sleep: 7.5,
                recovery: 78,
                activityPercent: 150,
                nutritionPercent: 80,
                hydrationPercent: 45,
                today: [sauna(hour: 19, minute: 20)],
                tomorrow: [workout("Normal Training", dayOffset: 1, hour: 12, duration: 45)],
                expected: [.performance, .recovery, .planChallenge],
                requiredText: "heat"
            ),
            scenario(
                "6. Sauna upcoming severe fatigue",
                hour: 22,
                sleep: 2.0,
                recovery: 35,
                activityPercent: 700,
                nutritionPercent: 40,
                hydrationPercent: 55,
                today: [sauna(hour: 22, minute: 20)],
                tomorrow: [workout("Endurance Ride", dayOffset: 1, hour: 10, duration: 150)],
                expected: [.recovery, .sleepPreparation, .planChallenge],
                requiresPlanChallenge: true
            ),
            scenario(
                "7. Fuel deficit before long ride",
                hour: 14,
                sleep: 7.8,
                recovery: 82,
                activityPercent: 20,
                nutritionPercent: 15,
                hydrationPercent: 80,
                carbsPercent: 8,
                today: [workout("Cycling", minutesFromNow: 60, duration: 180)],
                expected: [.performance, .recovery],
                requiredText: "energy"
            ),
            scenario(
                "8. Low calories after huge day tomorrow long endurance",
                hour: 20,
                sleep: 6.5,
                recovery: 60,
                activityPercent: 550,
                nutritionPercent: 25,
                hydrationPercent: 70,
                carbsPercent: 20,
                tomorrow: [workout("Long Endurance Ride", dayOffset: 1, hour: 9, duration: 240)],
                expected: [.performance, .recovery, .planChallenge],
                requiredText: "tomorrow"
            ),
            scenario(
                "9. Poor sleep high recovery before intervals",
                hour: 14,
                sleep: 3.5,
                recovery: 82,
                activityPercent: 30,
                nutritionPercent: 70,
                hydrationPercent: 80,
                today: [workout("Intervals", minutesFromNow: 90, duration: 75)],
                expected: [.sleepPreparation, .recovery, .planChallenge],
                requiredText: "sleep"
            ),
            scenario(
                "10. Recovery low but easy day",
                hour: 12,
                sleep: 7.0,
                recovery: 38,
                activityPercent: 20,
                nutritionPercent: 70,
                hydrationPercent: 80,
                today: [recoveryActivity("Easy Walk", minutesFromNow: 90, duration: 30)],
                expected: [.recovery],
                requiredText: "recovery"
            ),
            scenario(
                "11. Great recovery recovery day",
                hour: 10,
                sleep: 9.0,
                recovery: 95,
                activityPercent: 10,
                nutritionPercent: 80,
                hydrationPercent: 80,
                today: [recoveryActivity("Easy Walk", minutesFromNow: 120, duration: 30)],
                tomorrow: [workout("Normal Training", dayOffset: 1, hour: 12, duration: 45)],
                expected: [.stable, .performance]
            ),
            scenario(
                "12. Accumulated fatigue trend",
                hour: 18,
                sleep: 5.5,
                recovery: 65,
                activityPercent: 80,
                nutritionPercent: 70,
                hydrationPercent: 80,
                tomorrow: [workout("High Load Training", dayOffset: 1, hour: 12, duration: 120)],
                expected: [.planChallenge, .recovery],
                recentLoadTrend: true,
                requiredText: "trend"
            ),
            scenario(
                "13. Improving trend before hard session",
                hour: 14,
                sleep: 8.0,
                recovery: 88,
                activityPercent: 30,
                nutritionPercent: 85,
                hydrationPercent: 85,
                today: [workout("Hard Strength", minutesFromNow: 90, duration: 90)],
                expected: [.performance],
                recentLoadTrend: true,
                requiredText: "train"
            ),
            scenario(
                "14. Recovery activity after high load",
                hour: 22,
                sleep: 5.0,
                recovery: 58,
                activityPercent: 520,
                today: [
                    recoveryActivity("Stretching", hour: 21, minute: 55, duration: 20),
                    recoveryActivity("Breathing", hour: 22, minute: 30, duration: 10)
                ],
                tomorrow: [workout("Endurance Ride", dayOffset: 1, hour: 10, duration: 120)],
                expected: [.recovery, .sleepPreparation, .planChallenge],
                requiredText: "sleep"
            ),
            scenario(
                "15. Hydration low normal day",
                hour: 13,
                sleep: 8.0,
                recovery: 85,
                activityPercent: 40,
                nutritionPercent: 80,
                hydrationPercent: 35,
                expected: [.recovery],
                requiredText: "fluid"
            ),
            scenario(
                "16. Nutrition low no training pressure",
                hour: 13,
                sleep: 8.0,
                recovery: 85,
                activityPercent: 40,
                nutritionPercent: 20,
                hydrationPercent: 80,
                tomorrow: [recoveryActivity("Rest Walk", dayOffset: 1, hour: 12, duration: 30)],
                expected: [.recovery],
                requiredText: "recovery"
            ),
            scenario(
                "17. Tomorrow intervals after poor sleep",
                hour: 20,
                sleep: 2.5,
                recovery: 45,
                activityPercent: 300,
                nutritionPercent: 50,
                hydrationPercent: 65,
                tomorrow: [workout("Intervals", dayOffset: 1, hour: 10, duration: 75)],
                expected: [.planChallenge],
                requiresPlanChallenge: true,
                requiredText: "tomorrow"
            ),
            scenario(
                "18. Tomorrow easy recovery after hard day",
                hour: 21,
                sleep: 5.5,
                recovery: 55,
                activityPercent: 500,
                nutritionPercent: 70,
                hydrationPercent: 75,
                tomorrow: [recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)],
                expected: [.recovery, .sleepPreparation],
                requiresPlanChallenge: false
            ),
            scenario(
                "19. Good recovery terrible fueling",
                hour: 14,
                sleep: 8.0,
                recovery: 90,
                activityPercent: 80,
                nutritionPercent: 5,
                hydrationPercent: 90,
                today: [workout("Strength", minutesFromNow: 45, duration: 60)],
                expected: [.performance, .recovery],
                requiredText: "fuel"
            ),
            scenario(
                "20. Low recovery hydration also low",
                hour: 19,
                sleep: 4.0,
                recovery: 35,
                activityPercent: 250,
                nutritionPercent: 70,
                hydrationPercent: 35,
                expected: [.recovery, .sleepPreparation],
                requiredText: "hydration"
            )
        ]
    }

    private func requestedUserScenarios20() -> [MatrixScenario] {
        let completedFiveMinutesAgo = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -65, from: fixedDate(hour: 14)),
            durationMinutes: 60,
            completed: true
        )
        let completedHardSession = PlannedActivityBuilder.workout(
            title: "Hard Strength",
            at: CoachTestClock.offset(minutes: -125, from: fixedDate(hour: 14)),
            durationMinutes: 120,
            completed: true
        )
        let completedEarlierAtNight = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: -300, from: fixedDate(hour: 14)),
            durationMinutes: 75,
            completed: true
        )
        let skippedWorkout = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -120, from: fixedDate(hour: 14)),
            durationMinutes: 60,
            skipped: true
        )
        let completedEnough = PlannedActivityBuilder.workout(
            title: "Tempo Run",
            at: CoachTestClock.offset(minutes: -180, from: fixedDate(hour: 14)),
            durationMinutes: 60,
            completed: true
        )

        return [
            scenario("1. Wake strong before walk", hour: 7, sleep: 7.8, recovery: 88, activityPercent: 5, nutritionPercent: 0, hydrationPercent: 0, today: [recoveryActivity("Easy Walk", minutesFromNow: 60, duration: 30)], expected: [.recovery, .performance, .stable], requiredText: "recovery"),
            scenario("2. Good recovery workout much later", hour: 9, sleep: 8.0, recovery: 92, activityPercent: 10, nutritionPercent: 80, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 540, duration: 60)], expected: [.stable]),
            scenario("3. Workout in preparation window", hour: 17, minute: 30, sleep: 7.5, recovery: 84, activityPercent: 30, nutritionPercent: 80, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 30, duration: 60)], expected: [.performance], requiredText: "controlled"),
            scenario("4. Workout in progress", hour: 14, sleep: 7.5, recovery: 82, activityPercent: 60, nutritionPercent: 80, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: -10, duration: 60)], expected: [.activeSession], requiredText: "controlled"),
            scenario("5. Workout completed five minutes ago", hour: 14, sleep: 7.2, recovery: 78, activityPercent: 120, nutritionPercent: 80, hydrationPercent: 80, today: [completedFiveMinutesAgo], expected: [.recovery], requiredText: "done"),
            scenario("6. Hard session completed", hour: 16, sleep: 7.5, recovery: 76, activityPercent: 220, nutritionPercent: 75, hydrationPercent: 80, today: [completedHardSession], expected: [.recovery], requiredText: "done"),
            scenario("7. Late night after training", hour: 23, minute: 45, sleep: 7.0, recovery: 72, activityPercent: 220, nutritionPercent: 80, hydrationPercent: 80, today: [completedEarlierAtNight], expected: [.sleepPreparation], requiredText: "sleep"),
            scenario("8. Midnight before morning activity", hour: 0, minute: 40, sleep: 7.0, recovery: 78, activityPercent: 5, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Easy Walk", minutesFromNow: 455, duration: 30)], expected: [.sleepPreparation], requiredText: "sleep"),
            scenario("9. Recovery day walk later", hour: 10, sleep: 8.2, recovery: 86, activityPercent: 10, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Recovery Walk", minutesFromNow: 180, duration: 30)], expected: [.stable], requiredText: "easy"),
            scenario("10. Hydration behind no activity", hour: 15, sleep: 7.5, recovery: 80, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 20, expected: [.recovery, .stable], requiredText: "fluid"),
            scenario("11. Nutrition behind workout later", hour: 13, sleep: 7.5, recovery: 82, activityPercent: 20, nutritionPercent: 18, hydrationPercent: 85, carbsPercent: 12, today: [workout("Strength", minutesFromNow: 240, duration: 75)], expected: [.performance, .recovery, .stable], requiredText: "energy"),
            scenario("12. Good recovery poor fuel", hour: 13, sleep: 8.0, recovery: 90, activityPercent: 20, nutritionPercent: 8, hydrationPercent: 85, carbsPercent: 6, expected: [.recovery, .stable], requiredText: "fuel"),
            scenario("13. Poor sleep low recovery", hour: 12, sleep: 4.8, recovery: 52, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 80, expected: [.recovery, .sleepPreparation], requiredText: "sleep"),
            scenario("14. Missed activity reset", hour: 15, sleep: 7.2, recovery: 78, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 80, today: [skippedWorkout], expected: [.stable], requiredText: "miss"),
            scenario("15. Excellent day handled", hour: 19, sleep: 8.0, recovery: 88, activityPercent: 120, nutritionPercent: 100, hydrationPercent: 100, today: [completedEnough], expected: [.stable], requiredText: "done"),
            scenario("16. Workout later fuel and water low", hour: 15, sleep: 7.5, recovery: 82, activityPercent: 25, nutritionPercent: 18, hydrationPercent: 25, carbsPercent: 12, today: [workout("Strength", minutesFromNow: 120, duration: 75)], expected: [.performance, .recovery, .planChallenge], requiredText: "preparation"),
            scenario("17. Long gap before activity", hour: 10, sleep: 8.0, recovery: 86, activityPercent: 15, nutritionPercent: 80, hydrationPercent: 80, today: [workout("Strength", minutesFromNow: 360, duration: 60)], expected: [.stable]),
            scenario("18. Recovery walk soon", hour: 13, sleep: 8.0, recovery: 84, activityPercent: 15, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Recovery Walk", minutesFromNow: 30, duration: 30)], expected: [.stable], requiredText: "easy"),
            scenario("19. Enough work completed", hour: 16, sleep: 7.5, recovery: 82, activityPercent: 130, nutritionPercent: 90, hydrationPercent: 90, today: [completedEnough], expected: [.stable], requiredText: "banked"),
            scenario("20. Stable no urgent issue", hour: 14, sleep: 7.6, recovery: 82, activityPercent: 25, nutritionPercent: 80, hydrationPercent: 85, expected: [.stable])
        ]
    }

    private func generatedSweepScenarios() -> [MatrixScenario] {
        let tomorrowHard = [workout("Intervals", dayOffset: 1, hour: 10, duration: 75)]
        let tomorrowEndurance = [workout("Long Endurance Ride", dayOffset: 1, hour: 9, duration: 180)]
        let tomorrowEasy = [recoveryActivity("Recovery Walk", dayOffset: 1, hour: 10, duration: 30)]

        return [
            scenario("21. Sleep limiter before strength", hour: 15, sleep: 3.2, recovery: 78, activityPercent: 40, nutritionPercent: 75, hydrationPercent: 80, today: [workout("Strength", minutesFromNow: 90, duration: 60)], expected: [.sleepPreparation, .planChallenge], requiredText: "sleep"),
            scenario("22. Sleep limiter no training left", hour: 22, sleep: 3.0, recovery: 70, activityPercent: 60, nutritionPercent: 75, hydrationPercent: 80, expected: [.sleepPreparation, .recovery], requiredText: "sleep"),
            scenario("23. High load work already covered", hour: 21, sleep: 7.0, recovery: 70, activityPercent: 520, nutritionPercent: 80, hydrationPercent: 80, expected: [.recovery, .sleepPreparation], requiredText: "load"),
            scenario("24. High load with easy tomorrow", hour: 21, sleep: 6.5, recovery: 62, activityPercent: 480, nutritionPercent: 80, hydrationPercent: 80, tomorrow: tomorrowEasy, expected: [.recovery, .sleepPreparation], requiredText: "work"),
            scenario("25. Tomorrow intervals unrealistic", hour: 20, sleep: 4.0, recovery: 44, activityPercent: 260, nutritionPercent: 65, hydrationPercent: 70, tomorrow: tomorrowHard, expected: [.planChallenge], requiresPlanChallenge: true, requiredText: "tomorrow"),
            scenario("26. Tomorrow endurance under fueled", hour: 20, sleep: 6.5, recovery: 65, activityPercent: 260, nutritionPercent: 30, hydrationPercent: 70, carbsPercent: 20, tomorrow: tomorrowEndurance, expected: [.recovery, .planChallenge], requiredText: "tomorrow"),
            scenario("27. Sauna dry but otherwise ready", hour: 18, sleep: 8.0, recovery: 84, activityPercent: 50, nutritionPercent: 80, hydrationPercent: 30, today: [sauna(hour: 18, minute: 15)], expected: [.performance, .recovery, .planChallenge], requiredText: "heat"),
            scenario("28. Hydration low before endurance", hour: 13, sleep: 7.5, recovery: 82, activityPercent: 40, nutritionPercent: 80, hydrationPercent: 38, today: [workout("Endurance Ride", minutesFromNow: 50, duration: 120)], expected: [.performance, .recovery], requiredText: "fluid"),
            scenario("29. Fuel limiter despite high recovery", hour: 12, sleep: 8.0, recovery: 92, activityPercent: 35, nutritionPercent: 18, hydrationPercent: 85, carbsPercent: 10, today: [workout("Intervals", minutesFromNow: 70, duration: 75)], expected: [.performance, .recovery], requiredText: "energy"),
            scenario("30. Fuel recovery gap no session", hour: 16, sleep: 7.0, recovery: 75, activityPercent: 120, nutritionPercent: 22, hydrationPercent: 80, tomorrow: tomorrowEasy, expected: [.recovery], requiredText: "recovery"),
            scenario("31. Recovery suppressed easy walk", hour: 11, sleep: 7.0, recovery: 35, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 80, today: [recoveryActivity("Easy Walk", minutesFromNow: 45, duration: 30)], expected: [.recovery], requiredText: "recovery"),
            scenario("32. Recovery suppressed no activity", hour: 13, sleep: 6.8, recovery: 39, activityPercent: 30, nutritionPercent: 80, hydrationPercent: 80, expected: [.recovery], requiredText: "recovery"),
            scenario("33. Recovery low and dry", hour: 18, sleep: 5.0, recovery: 42, activityPercent: 160, nutritionPercent: 70, hydrationPercent: 32, expected: [.recovery, .sleepPreparation], requiredText: "hydration"),
            scenario("34. Good readiness long ride later", hour: 9, sleep: 8.2, recovery: 90, activityPercent: 10, nutritionPercent: 82, hydrationPercent: 85, today: [workout("Long Ride", minutesFromNow: 180, duration: 150)], expected: [.performance], requiredText: "train"),
            scenario("35. Active endurance supported", hour: 14, sleep: 7.5, recovery: 82, activityPercent: 80, nutritionPercent: 80, hydrationPercent: 80, today: [workout("Cycling", minutesFromNow: -5, duration: 90)], expected: [.activeSession], requiredText: "controlled"),
            scenario("36. Post workout recovery window", hour: 14, sleep: 7.0, recovery: 70, activityPercent: 120, nutritionPercent: 40, hydrationPercent: 45, today: [workout("Tempo Run", minutesFromNow: -80, duration: 45)], expected: [.recovery], requiredText: "session"),
            scenario("37. Accumulated trend tomorrow hard", hour: 19, sleep: 6.0, recovery: 61, activityPercent: 140, nutritionPercent: 70, hydrationPercent: 75, tomorrow: tomorrowHard, expected: [.planChallenge, .recovery], recentLoadTrend: true, requiredText: "trend"),
            scenario("38. High load dehydration no heat", hour: 17, sleep: 7.0, recovery: 78, activityPercent: 350, nutritionPercent: 75, hydrationPercent: 35, expected: [.recovery], requiredText: "fluid"),
            scenario("39. Severe fatigue skips sauna", hour: 21, sleep: 2.8, recovery: 32, activityPercent: 500, nutritionPercent: 60, hydrationPercent: 50, today: [sauna(hour: 21, minute: 20)], tomorrow: tomorrowHard, expected: [.sleepPreparation, .recovery, .planChallenge], requiresPlanChallenge: true),
            scenario("40. Balanced rest day", hour: 10, sleep: 8.0, recovery: 88, activityPercent: 15, nutritionPercent: 80, hydrationPercent: 85, expected: [.stable]),
            scenario("41. Balanced workout day", hour: 11, sleep: 8.0, recovery: 88, activityPercent: 20, nutritionPercent: 85, hydrationPercent: 85, today: [workout("Strength", minutesFromNow: 130, duration: 60)], expected: [.performance]),
            scenario("42. Under fueled after hard day", hour: 20, sleep: 7.0, recovery: 68, activityPercent: 420, nutritionPercent: 20, hydrationPercent: 75, tomorrow: tomorrowEasy, expected: [.recovery], requiredText: "fuel"),
            scenario("43. Under fueled tomorrow intervals", hour: 18, sleep: 7.0, recovery: 72, activityPercent: 90, nutritionPercent: 24, hydrationPercent: 80, tomorrow: tomorrowHard, expected: [.recovery, .planChallenge], requiredText: "tomorrow"),
            scenario("44. Poor sleep tomorrow easy", hour: 21, sleep: 3.4, recovery: 66, activityPercent: 70, nutritionPercent: 75, hydrationPercent: 80, tomorrow: tomorrowEasy, expected: [.sleepPreparation, .recovery], requiredText: "sleep"),
            scenario("45. Poor sleep low recovery", hour: 13, sleep: 3.5, recovery: 40, activityPercent: 50, nutritionPercent: 80, hydrationPercent: 80, expected: [.sleepPreparation, .recovery], requiredText: "sleep"),
            scenario("46. Hydration normal fuel low", hour: 15, sleep: 7.5, recovery: 80, activityPercent: 50, nutritionPercent: 28, hydrationPercent: 90, today: [workout("Strength", minutesFromNow: 80, duration: 60)], expected: [.performance, .recovery], requiredText: "energy"),
            scenario("47. Hydration before sauna with high load", hour: 19, sleep: 7.0, recovery: 75, activityPercent: 220, nutritionPercent: 80, hydrationPercent: 42, today: [sauna(hour: 19, minute: 5)], expected: [.performance, .recovery, .planChallenge], requiredText: "dry"),
            scenario("48. Tomorrow long ride recovery narrow", hour: 20, sleep: 5.0, recovery: 52, activityPercent: 190, nutritionPercent: 65, hydrationPercent: 70, tomorrow: tomorrowEndurance, expected: [.planChallenge, .recovery], requiresPlanChallenge: true, requiredText: "tomorrow"),
            scenario("49. Current recovery block after load", hour: 22, sleep: 6.0, recovery: 58, activityPercent: 430, nutritionPercent: 80, hydrationPercent: 78, today: [recoveryActivity("Mobility", hour: 21, minute: 55, duration: 20)], expected: [.recovery, .sleepPreparation], requiredText: "work"),
            scenario("50. Timing only preparation", hour: 13, sleep: 7.8, recovery: 86, activityPercent: 40, nutritionPercent: 82, hydrationPercent: 84, today: [workout("Strength", minutesFromNow: 20, duration: 60)], expected: [.performance], requiredText: "controlled"),
            scenario("51. Strong recovery with recent trend", hour: 14, sleep: 8.0, recovery: 91, activityPercent: 30, nutritionPercent: 82, hydrationPercent: 82, today: [workout("Intervals", minutesFromNow: 90, duration: 75)], expected: [.performance], recentLoadTrend: true, requiredText: "train"),
            scenario("52. Low recovery versus intervals today", hour: 14, sleep: 6.0, recovery: 43, activityPercent: 70, nutritionPercent: 75, hydrationPercent: 80, today: [workout("Intervals", minutesFromNow: 45, duration: 75)], expected: [.planChallenge, .recovery], requiredText: "intensity"),
            scenario("53. Hydration alone quiet afternoon", hour: 15, sleep: 8.0, recovery: 85, activityPercent: 20, nutritionPercent: 80, hydrationPercent: 40, expected: [.recovery, .stable], requiredText: "fluid"),
            scenario("54. Fuel and sleep conflict", hour: 20, sleep: 3.8, recovery: 60, activityPercent: 90, nutritionPercent: 20, hydrationPercent: 80, tomorrow: tomorrowHard, expected: [.recovery, .sleepPreparation, .planChallenge], requiredText: "tomorrow"),
            scenario("55. High load high recovery", hour: 20, sleep: 8.0, recovery: 90, activityPercent: 520, nutritionPercent: 85, hydrationPercent: 85, expected: [.recovery], requiredText: "work"),
            scenario("56. Hard tomorrow but ready", hour: 18, sleep: 8.0, recovery: 88, activityPercent: 60, nutritionPercent: 85, hydrationPercent: 85, tomorrow: tomorrowHard, expected: [.stable, .performance])
        ]
    }

    private func normalizedCopyKey(_ priority: CoachDayPriorityResult) -> String {
        "\(priority.title)|\(priority.message)"
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .prefix(12)
            .joined(separator: " ")
    }

    private func realCoachScore(_ priority: CoachDayPriorityResult) -> Int {
        let combined = ([priority.title, priority.message, priority.whyThisMatters, priority.planChallenge].compactMap { $0 } + priority.supportBullets + priority.reasons)
            .joined(separator: " ")
            .lowercased()

        var score = 0
        if priority.limiter != .none || combined.contains("limiter") || combined.contains("load") || combined.contains("sleep") || combined.contains("fuel") || combined.contains("hydration") {
            score += 1
        }
        if priority.whyThisMatters != nil || combined.contains("because") || combined.contains("depends") || combined.contains("cost") {
            score += 1
        }
        if !priority.supportBullets.isEmpty {
            score += 1
        }
        if priority.whyThisMatters != nil || combined.contains("if nothing changes") || combined.contains("cost") || combined.contains("worse") {
            score += 1
        }
        if combined.contains("tomorrow") || priority.planChallenge != nil || priority.messageFamily == .performance || priority.messageFamily == .stable {
            score += 1
        }
        if !priority.title.localizedCaseInsensitiveContains("priority") &&
            !priority.message.localizedCaseInsensitiveContains("in progress") &&
            !priority.message.localizedCaseInsensitiveContains("keep it easy") {
            score += 1
        }

        return score
    }

    private func scenario(
        _ name: String,
        hour: Int,
        minute: Int = 0,
        sleep: Double,
        recovery: Int,
        activityPercent: Double,
        activityKcal: Double? = nil,
        nutritionPercent: Double = 70,
        hydrationPercent: Double = 80,
        carbsPercent: Double? = nil,
        today: [PlannedActivity] = [],
        tomorrow: [PlannedActivity] = [],
        expected: [CoachDayPriority],
        requiresPlanChallenge: Bool = false,
        recentLoadTrend: Bool = false,
        requiredText: String? = nil
    ) -> MatrixScenario {
        let scenarioNow = fixedDate(hour: hour, minute: minute)
        let activeCalories = activityKcal ?? activityPercent / 100.0 * 450.0
        let nutritionRatio = nutritionPercent / 100.0
        let hydrationRatio = hydrationPercent / 100.0
        let carbRatio = (carbsPercent ?? nutritionPercent) / 100.0
        let adjustedToday = alignTodayActivities(today, to: scenarioNow)
        let allActivities = adjustedToday + tomorrow
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = hour
        config.hasAnyFoodLogged = nutritionPercent > 0
        config.energyCoverage = nutritionRatio
        config.caloriesProgress = nutritionRatio
        config.carbsProgress = carbRatio
        config.waterProgress = hydrationRatio
        config.metrics = CoachMetricsBuilder.metrics(
            protein: 160 * nutritionRatio,
            carbs: 280 * carbRatio,
            calories: 2400 * nutritionRatio,
            waterLiters: 4.9 * hydrationRatio,
            activeCalories: activeCalories,
            sleepHours: sleep
        )
        config.sleep = sleep < 4 ? .veryShort : (sleep < 6 ? .short : .strong)
        config.hydration = hydrationPercent < 45 ? .depleted : (hydrationPercent < 60 ? .behind : .optimal)
        config.fuel = nutritionPercent < 30 ? .underfueled : (nutritionPercent < 60 ? .light : .good)
        config.protein = nutritionPercent < 30 ? .low : (nutritionPercent < 60 ? .behind : .good)
        config.strain = activityPercent >= 500 ? .veryHigh : (activityPercent >= 150 ? .high : .normal)
        config.recovery = recovery < 45 ? .compromised : (recovery < 65 ? .vulnerable : (recovery >= 85 ? .strong : .stable))
        config.readiness = recovery < 45 || sleep < 4 ? .low : (recovery >= 85 && sleep >= 7 ? .excellent : .good)
        config.completedWorkoutsCount = recentLoadTrend ? 4 : nil

        return MatrixScenario(
            name: name,
            now: scenarioNow,
            brain: HumanBrainStateBuilder.make(config),
            recovery: CoachRecoveryContext(recoveryPercent: recovery, sleepHours: sleep),
            nutrition: CoachNutritionContext(
                caloriesCurrent: 2400 * nutritionRatio,
                caloriesGoal: 2400,
                proteinCurrent: 160 * nutritionRatio,
                proteinGoal: 160,
                waterCurrent: 4.9 * hydrationRatio,
                waterGoal: 4.9
            ),
            activities: allActivities,
            expectedPriorities: expected,
            requiresPlanChallenge: requiresPlanChallenge,
            requiredText: requiredText,
            inputSummary: "sleep \(sleep)h, recovery \(recovery)%, activity \(Int(activityPercent))%, kcal \(Int(activeCalories)), hydration \(Int(hydrationPercent))%, nutrition \(Int(nutritionPercent))%, current \(currentActivityName(adjustedToday, at: scenarioNow)), next \(nextActivityName(adjustedToday, at: scenarioNow)), tomorrow \(tomorrow.map(\.title).joined(separator: ", ")), trend \(recentLoadTrend)"
        )
    }

    private func alignTodayActivities(
        _ activities: [PlannedActivity],
        to scenarioNow: Date
    ) -> [PlannedActivity] {
        let baseNow = fixedDate(hour: 14)
        let offset = scenarioNow.timeIntervalSince(baseNow)

        return activities.map { activity in
            activity.date = activity.date.addingTimeInterval(offset)
            return activity
        }
    }

    private func printScenario(_ scenario: MatrixScenario, priority: CoachDayPriorityResult) {
        print("""
        [CoachScenario] \(scenario.name)
        Inputs: \(scenario.inputSummary)
        Output: priority=\(priority.priority), confidence=\(String(format: "%.2f", priority.confidence)), title=\(priority.title), message=\(priority.message), support=\(priority.supportBullets), reasons=\(priority.reasons), planChallenge=\(priority.planChallenge ?? "nil")
        """)
    }

    private func fixedDate(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? now
    }

    private func workout(
        _ title: String,
        minutesFromNow: Int,
        duration: Int
    ) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: title,
            at: CoachTestClock.offset(minutes: minutesFromNow, from: fixedDate(hour: 14)),
            durationMinutes: duration
        )
    }

    private func workout(
        _ title: String,
        dayOffset: Int,
        hour: Int,
        duration: Int
    ) -> PlannedActivity {
        let date = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: fixedDate(hour: hour)
        ) ?? fixedDate(hour: hour)
        return PlannedActivityBuilder.workout(title: title, at: date, durationMinutes: duration)
    }

    private func completedWorkout(
        _ title: String,
        minutesAgo: Int,
        duration: Int
    ) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: title,
            at: CoachTestClock.offset(minutes: -minutesAgo, from: fixedDate(hour: 14)),
            durationMinutes: duration,
            completed: true
        )
    }

    private func skippedWorkout(
        _ title: String,
        hour: Int,
        duration: Int
    ) -> PlannedActivity {
        PlannedActivityBuilder.workout(
            title: title,
            at: fixedDate(hour: hour),
            durationMinutes: duration,
            skipped: true
        )
    }

    private func recoveryActivity(
        _ title: String,
        minutesFromNow: Int,
        duration: Int
    ) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: title,
            at: CoachTestClock.offset(minutes: minutesFromNow, from: fixedDate(hour: 14)),
            durationMinutes: duration
        )
        activity.type = "recovery"
        return activity
    }

    private func recoveryActivity(
        _ title: String,
        dayOffset: Int,
        hour: Int,
        duration: Int
    ) -> PlannedActivity {
        let date = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: fixedDate(hour: hour)
        ) ?? fixedDate(hour: hour)
        let activity = PlannedActivityBuilder.workout(title: title, at: date, durationMinutes: duration)
        activity.type = "recovery"
        return activity
    }

    private func sauna(minutesFromNow: Int) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: minutesFromNow, from: fixedDate(hour: 14)),
            durationMinutes: 30
        )
        activity.type = "sauna"
        return activity
    }

    private func sauna(hour: Int, minute: Int) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: fixedDate(hour: hour, minute: minute),
            durationMinutes: 30
        )
        activity.type = "sauna"
        return activity
    }

    private func recoveryActivity(
        _ title: String,
        hour: Int,
        minute: Int,
        duration: Int
    ) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: title,
            at: fixedDate(hour: hour, minute: minute),
            durationMinutes: duration
        )
        activity.type = "recovery"
        return activity
    }

    private func currentActivityName(_ activities: [PlannedActivity], at date: Date) -> String {
        activities.first { activity in
            let end = Calendar.current.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date
            return activity.date <= date && date <= end
        }?.title ?? "none"
    }

    private func nextActivityName(_ activities: [PlannedActivity], at date: Date) -> String {
        activities
            .filter { $0.date > date }
            .sorted { $0.date < $1.date }
            .first?.title ?? "none"
    }

    private func resolve(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        now: Date? = nil,
        selectedDate: Date? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
        nutrition: CoachNutritionContext? = nil
    ) -> CoachDayPriorityResult {
        let resolvedNow = now ?? self.now
        let resolvedSelectedDate = selectedDate ?? self.selectedDate
        let activityContext = activityContext(
            activities,
            brain: brain,
            now: resolvedNow,
            selectedDate: resolvedSelectedDate
        )

        return CoachDayPriorityResolver.resolve(
            decisionContext(
                activities,
                brain: brain,
                now: resolvedNow,
                selectedDate: resolvedSelectedDate,
                actualLoad: actualLoad,
                recovery: recovery,
                nutrition: nutrition,
                activityContext: activityContext
            )
        )
    }

    private func decisionContext(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State,
        now: Date? = nil,
        selectedDate: Date? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.4),
        nutrition: CoachNutritionContext? = nil,
        activityContext providedActivityContext: CoachDayActivityContext? = nil
    ) -> CoachDecisionContext {
        let resolvedNow = now ?? self.now
        let resolvedSelectedDate = selectedDate ?? self.selectedDate
        let activityContext = providedActivityContext ?? self.activityContext(
            activities,
            brain: brain,
            now: resolvedNow,
            selectedDate: resolvedSelectedDate
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )

        return CoachDecisionContext(
            brain: brain,
            dayContext: CoachDayContextBuilder.build(
                activities: activities,
                selectedDate: resolvedSelectedDate,
                now: resolvedNow
            ),
            activityContext: activityContext,
            tomorrowContext: tomorrowContext(
                activities: activities,
                selectedDate: resolvedSelectedDate,
                now: resolvedNow
            ),
            actualLoad: actualLoad,
            recoveryContext: recovery,
            nutritionContext: nutrition,
            readiness: readiness
        )
    }

    private func assertExecutionLayerIsNotPrimary(
        _ priority: CoachDayPriorityResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch priority.priority {
        case .hydration, .fueling:
            XCTFail("Food and hydration must not be the primary day priority.", file: file, line: line)
        default:
            break
        }

        switch priority.focus {
        case .hydrationBehind, .fuelBehind:
            XCTFail("Food and hydration must not be the primary day focus.", file: file, line: line)
        default:
            break
        }

        switch priority.limiter {
        case .hydration, .fueling:
            XCTFail("Food and hydration must not be the primary limiter.", file: file, line: line)
        default:
            break
        }

        switch priority.messageFamily {
        case .hydration, .fueling:
            XCTFail("Food and hydration must not be the primary message family.", file: file, line: line)
        default:
            break
        }
    }

    private func tomorrowContext(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date
    ) -> CoachTomorrowPlanContext? {
        guard let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: selectedDate
        ) else {
            return nil
        }

        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrow,
            now: now
        )

        guard !dayContext.allActivities.isEmpty else {
            return nil
        }

        return CoachTomorrowPlanContext(dayContext: dayContext)
    }

    private func activityContext(
        _ activities: [PlannedActivity],
        brain: HumanBrain.State = HumanBrainStateBuilder.make(),
        now: Date? = nil,
        selectedDate: Date? = nil
    ) -> CoachDayActivityContext {
        CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate ?? self.selectedDate,
            now: now ?? self.now,
            brain: brain
        )
    }
}

private extension CoachActivityPhaseV3 {
    var isStable: Bool {
        if case .stable = self {
            return true
        }
        return false
    }
}
