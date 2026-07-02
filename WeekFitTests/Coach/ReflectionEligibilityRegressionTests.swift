import XCTest
@testable import WeekFit

/// Regression guard: Reflection cannot appear while Guidance owners are active.
final class ReflectionEligibilityRegressionTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        seedPendingUnderstandingEvent()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testReflectionBlockedDuringActiveWorkout() {
        assertReflectionBlocked(
            context: baseContext(
                sessionPhase: .during,
                focusSource: .active,
                activityState: .active
            ),
            expectedBlocker: .activeWorkout
        )
    }

    func testReflectionBlockedDuringPreWorkoutPreparation() {
        assertReflectionBlocked(
            context: baseContext(
                sessionPhase: .pre,
                focusSource: .upcoming,
                activityState: .upcoming,
                minutesUntilStart: 45
            ),
            expectedBlocker: .imminentPreparation
        )
    }

    func testReflectionBlockedDuringImmediatePostWorkout() {
        assertReflectionBlocked(
            context: baseContext(
                sessionPhase: .immediatePost,
                focusSource: .recentCompleted,
                activityState: .justFinished,
                minutesSinceEnd: 12
            ),
            expectedBlocker: .immediatePostRecovery
        )
    }

    func testReflectionBlockedDuringTomorrowProtection() {
        assertReflectionBlocked(
            context: baseContext(
                sessionPhase: .tomorrowProtection,
                focusSource: .idle,
                tomorrowDemand: .hard
            ),
            expectedBlocker: .tomorrowProtection
        )
    }

    func testReflectionBlockedWhenMeaningfulActivityRemainsLaterToday() {
        let now = date(hour: 14, minute: 0)
        let upcomingRide = cyclingActivity(
            title: "Afternoon Ride",
            start: now.addingTimeInterval(90 * 60),
            durationMinutes: 90
        )

        assertReflectionBlocked(
            snapshot: makeInput(now: now, activities: [upcomingRide]),
            context: baseContext(sessionPhase: .idle, focusSource: .idle),
            expectedBlocker: .meaningfulWorkRemaining
        )
    }

    func testReflectionBlockedUnderProtectiveUrgency() {
        assertReflectionBlocked(
            context: pausedContext,
            urgencyLevel: .protective,
            expectedBlocker: .elevatedUrgency
        )
    }

    func testReflectionBlockedUnderCriticalUrgency() {
        assertReflectionBlocked(
            context: pausedContext,
            urgencyLevel: .critical,
            expectedBlocker: .elevatedUrgency
        )
    }

    func testReflectionBlockedWhenSafetyAlertIsActive() {
        assertReflectionBlocked(
            context: pausedContext,
            safetyAlert: .hydrationCritical,
            expectedBlocker: .safetyAlert
        )
    }

    func testReflectionBlockedWhenAlertSeverityIsElevated() {
        assertReflectionBlocked(
            context: pausedContext,
            alertSeverity: .elevated,
            expectedBlocker: .safetyAlert
        )
    }

    func testReflectionBlockedWhenAlertSeverityIsCritical() {
        assertReflectionBlocked(
            context: pausedContext,
            alertSeverity: .critical,
            expectedBlocker: .safetyAlert
        )
    }

    func testReflectionContinuationViewRendersNothingWithoutOffer() {
        let view = CoachReflectionContinuationView(offer: nil)
        XCTAssertNil(view.offer)
    }

    // MARK: - Assertions

    private func assertReflectionBlocked(
        snapshot: CoachInputSnapshot? = nil,
        context: CoachContext,
        urgencyLevel: CoachUrgencyLevel = .calm,
        safetyAlert: CoachSafetyAlert? = nil,
        alertSeverity: CoachAlertSeverity = .none,
        expectedBlocker: ConversationPauseBlocker,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let resolvedSnapshot = snapshot ?? makeInput(now: date(hour: 15, minute: 0), activities: [])

        let pause = ConversationPauseResolver.resolve(
            ConversationPauseResolver.Input(
                snapshot: resolvedSnapshot,
                context: context,
                urgencyLevel: urgencyLevel,
                safetyAlert: safetyAlert,
                alertSeverity: alertSeverity
            )
        )

        XCTAssertFalse(pause.isPaused, file: file, line: line)
        XCTAssertEqual(pause.blockedBy, expectedBlocker, file: file, line: line)

        let offer = ReflectionComposer.compose(
            ReflectionComposer.Input(
                snapshot: resolvedSnapshot,
                context: context,
                urgencyLevel: urgencyLevel,
                safetyAlert: safetyAlert,
                alertSeverity: alertSeverity
            )
        )

        XCTAssertNil(offer, file: file, line: line)
        XCTAssertNotNil(CoachUnderstandingStore.nextUnspokenEvent(), file: file, line: line)
    }

    // MARK: - Fixtures

    private func seedPendingUnderstandingEvent() {
        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(
                id: .sleepConsistencyRecovery,
                maturity: .emerging,
                lastUpdated: Date()
            ),
            pendingEvents: [
                UnderstandingEvent.make(
                    beliefID: .sleepConsistencyRecovery,
                    change: .emerged,
                    maturity: .emerging
                )
            ]
        )
    }

    private var pausedContext: CoachContext {
        baseContext(
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            minutesSinceEnd: 45
        )
    }

    private func baseContext(
        sessionPhase: CoachSessionPhase,
        focusSource: CoachFocusSource,
        activityState: CoachActivityState = .none,
        tomorrowDemand: CoachTomorrowDemand = .none,
        minutesUntilStart: Int? = nil,
        minutesSinceEnd: Int? = nil
    ) -> CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: activityState,
            sessionPhase: sessionPhase,
            durationBand: .short,
            dayLoadBand: .moderate,
            completedSeriousActivities: sessionPhase == .settledPost ? .one : .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: focusSource,
            minutesUntilStart: minutesUntilStart,
            minutesSinceEnd: minutesSinceEnd,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 82,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            lastCompletedSeriousActivityType: .cycling
        )
    }

    private func makeInput(now: Date, activities: [PlannedActivity]) -> CoachInputSnapshot {
        CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(
                HumanBrainStateBuilder.Configuration(currentHour: Calendar.current.component(.hour, from: now))
            ),
            plannedActivities: activities,
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
            source: "ReflectionEligibilityRegressionTests"
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
