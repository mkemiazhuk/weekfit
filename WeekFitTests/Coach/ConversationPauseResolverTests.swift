import XCTest
@testable import WeekFit

final class ConversationPauseResolverTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    func testSettledPostWithNoRemainingWorkIsPaused() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .settledPost,
                focusSource: .recentCompleted
            )
        )

        XCTAssertTrue(resolution.isPaused)
        XCTAssertNil(resolution.blockedBy)
        XCTAssertEqual(resolution.reason, "settledPostNoWorkRemaining")
    }

    func testIdleWithNoRemainingWorkIsPaused() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .idle,
                focusSource: .idle
            )
        )

        XCTAssertTrue(resolution.isPaused)
        XCTAssertEqual(resolution.reason, "idleNoWorkRemaining")
    }

    func testActiveWorkoutBlocksPause() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .during,
                focusSource: .active,
                activityState: .active
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .activeWorkout)
    }

    func testDuringWorkoutBlocksPause() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .during,
                focusSource: .upcoming,
                activityState: .active
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .duringWorkout)
    }

    func testImmediatePostBlocksPause() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .immediatePost,
                focusSource: .recentCompleted,
                activityState: .justFinished
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .immediatePostRecovery)
    }

    func testImminentPreparationBlocksPause() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .pre,
                focusSource: .upcoming,
                activityState: .upcoming
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .imminentPreparation)
    }

    func testTomorrowProtectionBlocksPause() {
        let resolution = resolve(
            context: baseContext(
                sessionPhase: .tomorrowProtection,
                focusSource: .idle
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .tomorrowProtection)
    }

    func testMeaningfulWorkRemainingBlocksPause() {
        let now = date(hour: 14, minute: 0)
        let upcomingRide = cyclingActivity(
            title: "Afternoon Ride",
            start: now.addingTimeInterval(90 * 60),
            durationMinutes: 90
        )

        let resolution = resolve(
            snapshot: makeInput(now: now, activities: [upcomingRide]),
            context: baseContext(
                sessionPhase: .idle,
                focusSource: .idle
            )
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .meaningfulWorkRemaining)
    }

    func testProtectiveUrgencyBlocksPause() {
        let resolution = resolve(
            context: baseContext(sessionPhase: .idle, focusSource: .idle),
            urgencyLevel: .protective
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .elevatedUrgency)
    }

    func testSafetyAlertBlocksPause() {
        let resolution = resolve(
            context: baseContext(sessionPhase: .idle, focusSource: .idle),
            safetyAlert: .hydrationCritical
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .safetyAlert)
    }

    func testElevatedAlertSeverityBlocksPause() {
        let resolution = resolve(
            context: baseContext(sessionPhase: .idle, focusSource: .idle),
            alertSeverity: .elevated
        )

        XCTAssertFalse(resolution.isPaused)
        XCTAssertEqual(resolution.blockedBy, .safetyAlert)
    }

    // MARK: - Helpers

    private func resolve(
        snapshot: CoachInputSnapshot? = nil,
        context: CoachContext,
        urgencyLevel: CoachUrgencyLevel = .calm,
        safetyAlert: CoachSafetyAlert? = nil,
        alertSeverity: CoachAlertSeverity = .none
    ) -> ConversationPauseResolution {
        ConversationPauseResolver.resolve(
            ConversationPauseResolver.Input(
                snapshot: snapshot ?? makeInput(now: date(hour: 15, minute: 0), activities: []),
                context: context,
                urgencyLevel: urgencyLevel,
                safetyAlert: safetyAlert,
                alertSeverity: alertSeverity
            )
        )
    }

    private func baseContext(
        sessionPhase: CoachSessionPhase,
        focusSource: CoachFocusSource,
        activityState: CoachActivityState = .none
    ) -> CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: activityState,
            sessionPhase: sessionPhase,
            durationBand: .short,
            dayLoadBand: .moderate,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: focusSource,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 82,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            lastCompletedSeriousActivityType: .none
        )
    }

    private func makeInput(now: Date, activities: [PlannedActivity]) -> CoachInputSnapshot {
        CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(
                HumanBrainStateBuilder.Configuration(currentHour: Calendar.current.component(.hour, from: now))
            ),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 400,
                exerciseMinutes: 45,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.7
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "ConversationPauseResolverTests"
        )
    }

    private func cyclingActivity(
        title: String,
        start: Date,
        durationMinutes: Int
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "workout",
            title: title,
            durationMinutes: durationMinutes,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 900,
            isCompleted: false
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
