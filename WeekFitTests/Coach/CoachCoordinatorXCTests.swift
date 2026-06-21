import XCTest
@testable import WeekFit

@MainActor
final class CoachCoordinatorXCTests: XCTestCase {

    private let now = CoachTestClock.reference

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testSameFingerprintDoesNotRecompute() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let input = makeInput()

        let first = coordinator.recomputeIfNeeded(input: input, reason: "initial")
        let second = coordinator.recomputeIfNeeded(input: input, reason: "unchanged")

        XCTAssertEqual(resolverCalls, 1)
        XCTAssertEqual(coordinator.recomputeCount, 1)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
        XCTAssertEqual(first.id, second.id)
    }

    func testPreviousValidStateStaysVisibleWhenInputsAreUnavailable() {
        let coordinator = CoachCoordinator(decisionResolver: Self.guidance(for:))
        let ready = coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")

        coordinator.updateInput(nil)
        let refreshing = coordinator.recomputeIfNeeded(reason: "inputsUnavailable")

        XCTAssertEqual(refreshing.id, ready.id)
        XCTAssertEqual(refreshing.status, .refreshingPrevious)
        XCTAssertNotNil(refreshing.guidance)
        XCTAssertNotNil(refreshing.coachPresentation)
    }

    func testPlaceholderRecoverySleepSnapshotPreservesPreviousFinalStory() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let ready = coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")
        let readyStory = ready.finalStory

        let refreshing = coordinator.recomputeIfNeeded(
            input: makePlaceholderStartupInput(),
            reason: "morningStartup.placeholderRecovery"
        )

        XCTAssertEqual(resolverCalls, 1)
        XCTAssertEqual(refreshing.id, ready.id)
        XCTAssertEqual(refreshing.status, .refreshingPrevious)
        XCTAssertEqual(refreshing.finalStory?.title.resolved, readyStory?.title.resolved)
        XCTAssertEqual(refreshing.finalStory?.colorFamily, readyStory?.colorFamily)
    }

    func testPlaceholderRecoverySleepSnapshotDoesNotCreateFirstFinalStory() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }

        let state = coordinator.recomputeIfNeeded(
            input: makePlaceholderStartupInput(),
            reason: "morningStartup.placeholderFirst"
        )

        XCTAssertEqual(resolverCalls, 0)
        XCTAssertNil(state.finalStory)
        XCTAssertNil(state.coachPresentation)
        XCTAssertFalse(state.hasValidGuidance)
    }

    func testIdleWithinSameTimePhaseDoesNotRecompute() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }

        coordinator.recomputeIfNeeded(input: makeInput(now: now), reason: "initial")
        coordinator.recomputeIfNeeded(input: makeInput(now: now.addingTimeInterval(60)), reason: "idle60s")

        XCTAssertEqual(resolverCalls, 1)
        XCTAssertEqual(coordinator.recomputeCount, 1)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testCoordinatorSchedulesNextActivityLifecycleCheckpoint() {
        let coordinator = CoachCoordinator(decisionResolver: Self.guidance(for:))
        let workout = PlannedActivityBuilder.workout(
            title: "Easy Run",
            at: CoachTestClock.offset(minutes: 30, from: now),
            durationMinutes: 40
        )

        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [workout]),
            reason: "initial"
        )

        XCTAssertEqual(
            coordinator.nextScheduledCheckpoint?.timeIntervalSince1970 ?? 0,
            workout.date.addingTimeInterval(1).timeIntervalSince1970,
            accuracy: 0.5
        )
    }

    func testCoordinatorSchedulesTimePhaseCheckpointWhenNoActivityBoundaryComesFirst() {
        let coordinator = CoachCoordinator(decisionResolver: Self.guidance(for:))
        let expectedPhaseBoundary = Calendar.current.date(
            bySettingHour: 16,
            minute: 0,
            second: 1,
            of: now
        )

        coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")

        XCTAssertEqual(
            coordinator.nextScheduledCheckpoint?.timeIntervalSince1970 ?? 0,
            expectedPhaseBoundary?.timeIntervalSince1970 ?? 0,
            accuracy: 0.5
        )
    }

    func testMealLogUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let meal = PlannedActivityBuilder.meal(title: "Lunch", at: now, calories: 620)

        coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [meal]),
            reason: "meal"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [meal]),
            reason: "mealDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testDrinkLogUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let drink = PlannedActivityBuilder.hydrationLog(at: now)

        coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")
        coordinator.recomputeIfNeeded(
            input: makeInput(
                metrics: CoachMetricsBuilder.metrics(waterLiters: 1.45),
                nutrition: CoachNutritionContext(
                    caloriesCurrent: 1200,
                    caloriesGoal: 2400,
                    proteinCurrent: 80,
                    proteinGoal: 160,
                    carbsCurrent: 120,
                    carbsGoal: 280,
                    fatsCurrent: 40,
                    fatsGoal: 70,
                    waterCurrent: 1.45,
                    waterGoal: 2.5,
                    mealsCount: 0,
                    lastMealTime: nil
                ),
                activities: [drink]
            ),
            reason: "drink"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(
                metrics: CoachMetricsBuilder.metrics(waterLiters: 1.45),
                nutrition: CoachNutritionContext(
                    caloriesCurrent: 1200,
                    caloriesGoal: 2400,
                    proteinCurrent: 80,
                    proteinGoal: 160,
                    carbsCurrent: 120,
                    carbsGoal: 280,
                    fatsCurrent: 40,
                    fatsGoal: 70,
                    waterCurrent: 1.45,
                    waterGoal: 2.5,
                    mealsCount: 0,
                    lastMealTime: nil
                ),
                activities: [drink]
            ),
            reason: "drinkDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testPlannerUpdateUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let workout = PlannedActivityBuilder.workout(
            title: "Easy Run",
            at: CoachTestClock.offset(minutes: 90, from: now),
            durationMinutes: 40
        )

        coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [workout]),
            reason: "planner"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [workout]),
            reason: "plannerDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testMorningRecoveryDayUpcomingPlanDoesNotShowEasyMovementOverride() {
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        let walk = PlannedActivity(
            date: CoachTestClock.offset(minutes: 105, from: morning),
            type: "walking",
            title: "Walk",
            durationMinutes: 45,
            icon: "figure.walk",
            imageName: "figure.walk",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43
        )
        let stretching = PlannedActivity(
            date: CoachTestClock.offset(minutes: 180, from: morning),
            type: "recovery",
            title: "Stretching",
            durationMinutes: 20,
            icon: "figure.cooldown",
            imageName: "figure.cooldown",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43
        )
        let sauna = PlannedActivity(
            date: CoachTestClock.offset(minutes: 300, from: morning),
            type: "recovery",
            title: "Sauna",
            durationMinutes: 20,
            icon: "flame.fill",
            imageName: "flame.fill",
            colorRed: 0.95,
            colorGreen: 0.45,
            colorBlue: 0.20
        )
        let coordinator = CoachCoordinator(decisionResolver: Self.guidance(for:))
        let state = coordinator.recomputeIfNeeded(
            input: makeInput(
                now: morning,
                metrics: CoachMetricsBuilder.metrics(sleepHours: 8.1),
                activities: [walk, stretching, sauna]
            ),
            reason: "morningRecoveryPlan"
        )
        let title = state.finalStory?.title.resolved ?? ""
        let message = state.coachPresentation?.message ?? state.finalStory?.subtitle.resolved ?? ""
        let visible = "\(title) \(message)".lowercased()

        XCTAssertFalse(title.localizedCaseInsensitiveContains("already added"), title)
        XCTAssertFalse(visible.contains("easy movement"), visible)
        XCTAssertFalse(visible.contains("long ride"), visible)
        XCTAssertTrue(
            state.finalStory?.owner == .stableOverview || state.finalStory?.owner == .readiness,
            state.finalStory?.owner.rawValue ?? "nil"
        )
    }

    func testActiveActivityStartUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let activeWorkout = PlannedActivityBuilder.workout(
            title: "Live Run",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 35
        )

        coordinator.recomputeIfNeeded(input: makeInput(), reason: "initial")
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [activeWorkout]),
            reason: "activityStart"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [activeWorkout]),
            reason: "activityStartDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testActivityEndUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let activeWorkout = PlannedActivityBuilder.workout(
            title: "Live Run",
            at: CoachTestClock.offset(minutes: -35, from: now),
            durationMinutes: 45
        )
        let completedWorkout = PlannedActivityBuilder.workout(
            title: activeWorkout.title,
            at: activeWorkout.date,
            durationMinutes: 45,
            completed: true
        )
        completedWorkout.id = activeWorkout.id
        completedWorkout.actualDurationMinutes = 35

        coordinator.recomputeIfNeeded(input: makeInput(activities: [activeWorkout]), reason: "activityActive")
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [completedWorkout]),
            reason: "activityEnd"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(activities: [completedWorkout]),
            reason: "activityEndDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testSelectedDateChangeUpdatesFingerprintAndRecomputesOnce() {
        var resolverCalls = 0
        let coordinator = CoachCoordinator { input in
            resolverCalls += 1
            return Self.guidance(for: input)
        }
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)

        coordinator.recomputeIfNeeded(input: makeInput(now: now), reason: "initial")
        coordinator.recomputeIfNeeded(
            input: makeInput(now: nextDay),
            reason: "dateChange"
        )
        coordinator.recomputeIfNeeded(
            input: makeInput(now: nextDay),
            reason: "dateChangeDuplicate"
        )

        XCTAssertEqual(resolverCalls, 2)
        XCTAssertEqual(coordinator.recomputeCount, 2)
        XCTAssertEqual(coordinator.skippedUnchangedCount, 1)
    }

    func testActiveWalkUsesUpcomingCoreWorkoutAsRationaleNotSchedule() {
        let activeWalk = PlannedActivity(
            id: "active-walk",
            date: CoachTestClock.offset(minutes: -12, from: now),
            type: "recovery",
            title: "Walk",
            durationMinutes: 45,
            icon: "figure.walk",
            imageName: "figure.walk",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43
        )
        let core = PlannedActivity(
            id: "core-workout",
            date: CoachTestClock.offset(minutes: 39, from: now),
            type: "workout",
            title: "Core",
            durationMinutes: 30,
            icon: "figure.strengthtraining.traditional",
            imageName: "figure.strengthtraining.traditional",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let input = makeInput(
            metrics: CoachMetricsBuilder.metrics(sleepHours: 7.0),
            activities: [activeWalk, core]
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: Self.guidance(for: input)
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            brain: input.brain
        )

        XCTAssertEqual(activityContext.activeActivity?.id, activeWalk.id)
        XCTAssertEqual(state.guidance?.priority.focus, .activeActivity)
        XCTAssertEqual(state.rationalePresentation?.sourceActivityID, core.id)
        XCTAssertEqual(state.rationalePresentation?.title, "Save quality for training")
        XCTAssertEqual(
            state.rationalePresentation?.message,
            "Core is the priority training block today. Use this walk to stay loose, not to add fatigue before loading."
        )
        XCTAssertFalse(state.rationalePresentation?.title.contains("39") ?? true)
        XCTAssertFalse(state.rationalePresentation?.message.contains("39") ?? true)
    }

    func testDayPriorityModelPicksCyclingOverCoreWhenRideIsMainWorkload() {
        let activeWalk = PlannedActivity(
            id: "active-walk",
            date: CoachTestClock.offset(minutes: -12, from: now),
            type: "recovery",
            title: "Walk",
            durationMinutes: 45,
            icon: "figure.walk",
            imageName: "figure.walk",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43
        )
        let core = PlannedActivity(
            id: "core-workout",
            date: CoachTestClock.offset(minutes: 39, from: now),
            type: "workout",
            title: "Core",
            durationMinutes: 30,
            icon: "figure.strengthtraining.traditional",
            imageName: "figure.strengthtraining.traditional",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let ride = PlannedActivity(
            id: "cycling-main",
            date: CoachTestClock.offset(minutes: 180, from: now),
            type: "cycling",
            title: "Cycling",
            durationMinutes: 90,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let input = makeInput(
            metrics: CoachMetricsBuilder.metrics(sleepHours: 7.0),
            activities: [activeWalk, core, ride]
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: Self.guidance(for: input)
        )

        XCTAssertEqual(input.dayPriorityModel.primarySession?.id, ride.id)
        XCTAssertEqual(input.dayPriorityModel.secondarySession?.id, core.id)
        XCTAssertTrue(input.dayPriorityModel.supportingSessions.contains { $0.id == activeWalk.id })
        XCTAssertEqual(state.rationalePresentation?.sourceActivityID, ride.id)
        XCTAssertEqual(state.rationalePresentation?.title, "Protect the main effort")
        XCTAssertEqual(
            state.rationalePresentation?.message,
            "Cycling is the key workload today. Keep this walk relaxed so you preserve legs and fueling for the main effort."
        )
    }

    func testActiveWalkUsesUpcomingRunAsEnduranceRationale() {
        let activeWalk = PlannedActivity(
            id: "active-walk",
            date: CoachTestClock.offset(minutes: -12, from: now),
            type: "recovery",
            title: "Walk",
            durationMinutes: 45,
            icon: "figure.walk",
            imageName: "figure.walk",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43
        )
        let run = PlannedActivity(
            id: "tempo-run",
            date: CoachTestClock.offset(minutes: 50, from: now),
            type: "run",
            title: "Tempo Run",
            durationMinutes: 50,
            icon: "figure.run",
            imageName: "figure.run",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let input = makeInput(
            metrics: CoachMetricsBuilder.metrics(sleepHours: 7.0),
            activities: [activeWalk, run]
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: Self.guidance(for: input)
        )

        XCTAssertEqual(state.rationalePresentation?.sourceActivityID, run.id)
        XCTAssertEqual(state.rationalePresentation?.title, "Protect the main effort")
        XCTAssertEqual(
            state.rationalePresentation?.message,
            "Tempo Run is the key workload today. Keep this walk relaxed so you preserve legs and fueling for the main effort."
        )
        XCTAssertFalse(state.rationalePresentation?.message.contains("50") ?? true)
    }

    func testDayPriorityModelConsidersTomorrowDemandOnLoadedDay() {
        let morningRide = PlannedActivity(
            id: "morning-ride",
            date: CoachTestClock.offset(minutes: -180, from: now),
            type: "cycling",
            title: "Morning Ride",
            durationMinutes: 90,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20,
            isCompleted: true
        )
        let eveningRide = PlannedActivity(
            id: "evening-ride",
            date: CoachTestClock.offset(minutes: 240, from: now),
            type: "cycling",
            title: "Evening Ride",
            durationMinutes: 120,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let tomorrowBase = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: now
        ) ?? now.addingTimeInterval(86_400)
        let tomorrowRide = PlannedActivity(
            id: "tomorrow-hard-ride",
            date: CoachTestClock.offset(minutes: 120, from: tomorrowBase),
            type: "cycling",
            title: "Long Ride",
            durationMinutes: 180,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20
        )
        let input = makeInput(
            metrics: CoachMetricsBuilder.metrics(sleepHours: 7.0),
            activities: [morningRide, eveningRide, tomorrowRide]
        )

        XCTAssertEqual(input.dayPriorityModel.primarySession?.id, eveningRide.id)
        XCTAssertTrue(input.dayPriorityModel.dayStressLevel == .overload || input.dayPriorityModel.dayStressLevel == .high)
        XCTAssertEqual(input.dayPriorityModel.tomorrowDemand, .hard)
        XCTAssertEqual(input.dayPriorityModel.protectionTarget, .tomorrow)
    }

    func testOverloadDayWithUnderfuelingOverridesGoodToGoPostActivityStory() {
        let morningRide = PlannedActivity(
            id: "morning-ride",
            date: CoachTestClock.offset(minutes: -240, from: now),
            type: "cycling",
            title: "Morning Ride",
            durationMinutes: 90,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20,
            isCompleted: true
        )
        let keyRide = PlannedActivity(
            id: "key-ride",
            date: CoachTestClock.offset(minutes: -90, from: now),
            type: "cycling",
            title: "Key Ride",
            durationMinutes: 120,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20,
            isCompleted: true
        )
        let metrics = CoachMetricsBuilder.metrics(
            protein: 1,
            carbs: 30,
            calories: 650,
            waterLiters: 1.5,
            activeCalories: 855,
            sleepHours: 7.0
        )
        let input = makeInput(
            metrics: metrics,
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
                lastMealTime: now
            ),
            activities: [morningRide, keyRide]
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: Self.goodToGoGuidance(after: keyRide)
        )

        XCTAssertTrue(input.dayPriorityModel.dayGoal == .overload || input.dayPriorityModel.dayGoal == .performance)
        XCTAssertTrue(input.dayPriorityModel.dayStressLevel == .overload || input.dayPriorityModel.dayStressLevel == .high)
        XCTAssertTrue(state.coachPresentation?.stateLabel.localizedCaseInsensitiveContains("recovery") ?? false)
        XCTAssertTrue(state.coachPresentation?.title.localizedCaseInsensitiveContains("recovery") ?? false)
        XCTAssertTrue(state.coachPresentation?.message.localizedCaseInsensitiveContains("recovery") ?? false)
        XCTAssertNotEqual(state.coachPresentation?.stateLabel, "GOOD TO GO")
        XCTAssertNotEqual(state.coachPresentation?.title, "The work is done")
        XCTAssertTrue(state.todayPresentation.title.localizedCaseInsensitiveContains("recovery"))
        XCTAssertTrue(state.todayPresentation.message.localizedCaseInsensitiveContains("recovery"))
    }

    func testRecoveryNeededPriorityNeverRendersGoodToGo() {
        let keyRide = PlannedActivity(
            id: "key-ride",
            date: CoachTestClock.offset(minutes: -90, from: now),
            type: "cycling",
            title: "Key Ride",
            durationMinutes: 150,
            icon: "bicycle",
            imageName: "bicycle",
            colorRed: 0.95,
            colorGreen: 0.60,
            colorBlue: 0.20,
            isCompleted: true
        )
        let metrics = CoachMetricsBuilder.metrics(
            protein: 1,
            carbs: 30,
            calories: 650,
            waterLiters: 1.5,
            activeCalories: 855,
            sleepHours: 7.0
        )
        let input = makeInput(
            metrics: metrics,
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
                lastMealTime: now
            ),
            activities: [keyRide]
        )
        let recoveryPriority = CoachDayPriorityResult(
            focus: .recoveryNeeded,
            level: .important,
            reason: "Recovery is the current limiter.",
            activity: keyRide,
            overridesTimingFocus: true,
            priority: .recovery,
            limiter: .accumulatedFatigue,
            detailTitle: "The work is done",
            detailMessage: "Training is complete."
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: Self.goodToGoGuidance(
                after: keyRide,
                priority: recoveryPriority
            )
        )

        XCTAssertEqual(state.guidance?.priority.focus, .recoveryNeeded)
        XCTAssertNotEqual(state.coachPresentation?.stateLabel, "GOOD TO GO")
    }

    private func makeInput(
        now: Date? = nil,
        metrics: DailyNutritionMetrics = CoachMetricsBuilder.metrics(),
        nutrition: CoachNutritionContext? = nil,
        activities: [PlannedActivity] = []
    ) -> CoachInputSnapshot {
        let resolvedNow = now ?? self.now
        let goals = CoachMetricsBuilder.standardGoals
        let brain = HumanBrainStateBuilder.make(
            currentHour: Calendar.current.component(.hour, from: resolvedNow),
            metrics: metrics,
            profile: CoachMetricsBuilder.standardProfile()
        )
        let nutritionContext = nutrition ?? CoachNutritionContext(
            caloriesCurrent: metrics.calories,
            caloriesGoal: goals.calories,
            proteinCurrent: metrics.protein,
            proteinGoal: goals.protein,
            carbsCurrent: metrics.carbs,
            carbsGoal: goals.carbs,
            fatsCurrent: metrics.fats,
            fatsGoal: goals.fats,
            waterCurrent: metrics.waterLiters,
            waterGoal: goals.waterLiters,
            mealsCount: activities.filter { $0.type.lowercased() == "meal" && $0.imageName != "hydration" }.count,
            lastMealTime: activities.last { $0.type.lowercased() == "meal" && $0.imageName != "hydration" }?.date
        )

        return CoachInputSnapshot(
            metricsSnapshotID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            selectedDate: resolvedNow,
            now: resolvedNow,
            brain: brain,
            plannedActivities: activities,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: 85,
                sleepHours: metrics.sleepHours
            ),
            nutritionContext: nutritionContext,
            source: "test"
        )
    }

    private func makePlaceholderStartupInput() -> CoachInputSnapshot {
        let placeholderNow = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        let metrics = CoachMetricsBuilder.metrics(
            protein: 0,
            carbs: 0,
            calories: 0,
            waterLiters: 0,
            activeCalories: 0,
            sleepHours: 0
        )
        let brain = HumanBrainStateBuilder.make(
            currentHour: 8,
            hasAnyFoodLogged: false,
            waterProgress: 0,
            sleep: .unknown,
            hydration: .optimal,
            fuel: .good,
            strain: .normal,
            recovery: .stable,
            readiness: .low,
            metrics: metrics
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: [],
            selectedDate: placeholderNow,
            now: placeholderNow
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: CoachMetricsBuilder.standardGoals.calories,
            proteinCurrent: 0,
            proteinGoal: CoachMetricsBuilder.standardGoals.protein,
            carbsCurrent: 0,
            carbsGoal: CoachMetricsBuilder.standardGoals.carbs,
            fatsCurrent: 0,
            fatsGoal: CoachMetricsBuilder.standardGoals.fats,
            waterCurrent: 0,
            waterGoal: CoachMetricsBuilder.standardGoals.waterLiters,
            mealsCount: 0,
            lastMealTime: nil
        )

        return CoachInputSnapshot(
            metricsSnapshotID: UUID(uuidString: "00000000-0000-0000-0000-000000000099"),
            selectedDate: placeholderNow,
            now: placeholderNow,
            brain: brain,
            plannedActivities: [],
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 0, sleepHours: 0),
            nutritionContext: nutrition,
            source: "test.placeholderStartup"
        )
    }

    private static func guidance(for input: CoachInputSnapshot) -> CoachGuidanceV3 {
        CoachEngineV3.decide(
            from: input.brain,
            plannedActivities: input.plannedActivities,
            selectedDate: input.selectedDate,
            dayContext: input.dayContext,
            recoveryContext: input.recoveryContext,
            nutritionContext: input.nutritionContext
        )
    }

    private static func goodToGoGuidance(
        after activity: PlannedActivity,
        priority: CoachDayPriorityResult = .defaultOverview
    ) -> CoachGuidanceV3 {
        CoachGuidanceV3(
            phase: .recovering(activity: activity, kind: .endurance, minutesSinceEnd: 15),
            opportunity: CoachSupportOpportunityV3(
                type: .stable,
                importance: .quiet,
                reason: "Lower-level post-activity story"
            ),
            priority: priority,
            shouldSurface: true,
            stateLabel: "GOOD TO GO",
            title: "The work is done",
            message: "Training is complete.",
            insightTitle: "The work is done",
            insightSubtitle: nil,
            supportActions: [],
            avoidNotes: [],
            icon: "checkmark.circle.fill",
            color: WeekFitTheme.secondaryText,
            importance: .quiet,
            tone: .calm
        )
    }
}
