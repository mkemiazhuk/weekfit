import XCTest
@testable import WeekFit

final class CoachDayLoadNarrativeTests: XCTestCase {

    private let now = CoachTestClock.reference

    func testSecondCyclingSessionUsesDayCapProtectionHero() throws {
        WeekFitSetCurrentLanguage(.russian)

        let completedRide = makeCycling(
            title: "Long ride",
            minutesFromNow: -(240 + 30),
            duration: 240,
            completed: true
        )
        completedRide.source = "appleWorkout"
        completedRide.actualDurationMinutes = 240

        let activeRide = makeCycling(
            title: "Cycling",
            minutesFromNow: -8,
            duration: 90,
            completed: false
        )
        activeRide.source = "today"

        let state = makeState(
            activities: [completedRide, activeRide],
            activeCalories: 2_731,
            exerciseMinutes: 282,
            recoveryPercent: 78
        )
        let story = try XCTUnwrap(state.finalStory)

        let hero = story.title.resolved
        let input = try XCTUnwrap(state.input)
        XCTAssertEqual(
            CoachDayLoadNarrativeResolver.resolveFromSnapshot(
                input: input,
                shouldProtectTomorrow: false
            ).coachingJob,
            .dayCap
        )
        XCTAssertTrue(
            hero.localizedCaseInsensitiveContains("Вторая поездка") ||
                hero.localizedCaseInsensitiveContains("не разгоняйте день"),
            hero
        )
        XCTAssertFalse(hero.localizedCaseInsensitiveContains("Войдите в поездку плавно"), hero)
    }

    func testFirstLongRideOpeningKeepsPerformanceHero() throws {
        WeekFitSetCurrentLanguage(.russian)

        let activeRide = makeCycling(
            title: "Long ride",
            minutesFromNow: -8,
            duration: 240,
            completed: false
        )
        activeRide.source = "today"

        let state = makeState(
            activities: [activeRide],
            activeCalories: 420,
            exerciseMinutes: 8,
            recoveryPercent: 88
        )
        let story = try XCTUnwrap(state.finalStory)

        let hero = story.title.resolved
        let input = try XCTUnwrap(state.input)
        XCTAssertEqual(
            CoachDayLoadNarrativeResolver.resolveFromSnapshot(
                input: input,
                shouldProtectTomorrow: false
            ).coachingJob,
            .optimizeExecution
        )
        XCTAssertTrue(hero.localizedCaseInsensitiveContains("Войдите в поездку плавно"), hero)
    }

    func testPriorCompletedSeriousRequiresDifferentActiveSession() {
        let completed = makeCycling(
            title: "Long ride",
            minutesFromNow: -300,
            duration: 240,
            completed: true
        )
        let sameSessionActive = makeCycling(
            title: "Long ride",
            minutesFromNow: -8,
            duration: 240,
            completed: false
        )
        sameSessionActive.id = completed.id

        XCTAssertNil(
            CoachDayLoadNarrativeResolver.priorCompletedSeriousSession(
                seriousCompleted: completed,
                activeActivity: sameSessionActive
            )
        )

        let secondRide = makeCycling(
            title: "Cycling",
            minutesFromNow: -8,
            duration: 90,
            completed: false
        )
        XCTAssertNotNil(
            CoachDayLoadNarrativeResolver.priorCompletedSeriousSession(
                seriousCompleted: completed,
                activeActivity: secondRide
            )
        )
    }

    private func makeCycling(
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
        activity.type = "cycling"
        activity.imageName = "bicycle"
        return activity
    }

    private func makeState(
        activities: [PlannedActivity],
        activeCalories: Double,
        exerciseMinutes: Int,
        recoveryPercent: Int
    ) -> CoachState {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1_400,
            caloriesGoal: 2_200,
            proteinCurrent: 80,
            proteinGoal: 120,
            carbsCurrent: 170,
            carbsGoal: 250,
            waterCurrent: 1.8,
            waterGoal: 2.5,
            mealsCount: 3
        )
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: now)
        brainConfig.hasAnyFoodLogged = true
        brainConfig.waterProgress = 0.72
        brainConfig.hasWorkoutSoon = true
        brainConfig.nextWorkout = activities.first { !$0.isCompleted }
        brainConfig.hydration = .optimal
        brainConfig.fuel = .good
        brainConfig.sleep = .strong
        brainConfig.recovery = .strong
        brainConfig.readiness = .good
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: nutrition.proteinCurrent,
            carbs: nutrition.carbsCurrent,
            calories: nutrition.caloriesCurrent,
            waterLiters: nutrition.waterCurrent,
            activeCalories: activeCalories,
            sleepHours: 7.5
        )
        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: now,
            now: now
        )
        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: brain,
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: activeCalories,
                exerciseMinutes: exerciseMinutes,
                standHours: nil,
                activityGoalCalories: 700,
                activityProgress: activeCalories / 700
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: recoveryPercent, sleepHours: 7.5),
            nutritionContext: nutrition,
            source: "CoachDayLoadNarrativeTests"
        )
        let guidance = CoachEngineV3.decide(
            from: brain.refreshedForCurrentLocalTime(activities: activities),
            plannedActivities: activities,
            selectedDate: now,
            dayContext: dayContext,
            recoveryContext: input.recoveryContext,
            nutritionContext: nutrition
        )
        return CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: now
        )
    }
}
