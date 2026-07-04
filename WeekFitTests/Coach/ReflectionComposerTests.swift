import XCTest
@testable import WeekFit

final class ReflectionComposerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testReturnsNilWhenConversationIsNotPaused() {
        let input = ReflectionComposer.Input(
            snapshot: makeInput(),
            context: blockedContext,
            urgencyLevel: .live,
            safetyAlert: nil,
            alertSeverity: .none
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [
                UnderstandingEvent.make(
                    beliefID: .sleepConsistencyRecovery,
                    change: .emerged,
                    maturity: .emerging
                )
            ]
        )

        XCTAssertNil(ReflectionComposer.compose(input))
    }

    func testReturnsOfferAtPauseWhenUnderstandingChanged() {
        let event = UnderstandingEvent.make(
            beliefID: .sleepConsistencyRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [event]
        )

        let offer = ReflectionComposer.compose(
            ReflectionComposer.Input(
                snapshot: makeInput(),
                context: pausedContext,
                urgencyLevel: .calm,
                safetyAlert: nil,
                alertSeverity: .none
            )
        )

        XCTAssertNotNil(offer)
        XCTAssertEqual(offer?.id, event.id)
        XCTAssertEqual(offer?.kind, .newDiscovery)
        XCTAssertFalse(offer?.message.isEmpty ?? true)
        XCTAssertNotNil(CoachUnderstandingStore.nextUnspokenEvent())
    }

    func testMarksSpokenOnlyAfterDisplay() {
        let event = UnderstandingEvent.make(
            beliefID: .sleepConsistencyRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [event]
        )

        let offer = ReflectionComposer.compose(
            ReflectionComposer.Input(
                snapshot: makeInput(),
                context: pausedContext,
                urgencyLevel: .calm,
                safetyAlert: nil,
                alertSeverity: .none
            )
        )

        XCTAssertNotNil(offer)
        XCTAssertNotNil(CoachUnderstandingStore.nextUnspokenEvent())

        ReflectionOfferDisplayTracker.markDisplayed(offer!)
        XCTAssertNil(CoachUnderstandingStore.nextUnspokenEvent())
    }

    func testShowsPendingBeliefEventsOneAtATime() {
        let consistencyEvent = UnderstandingEvent.make(
            beliefID: .sleepConsistencyRecovery,
            change: .emerged,
            maturity: .emerging
        )
        let durationEvent = UnderstandingEvent.make(
            beliefID: .sleepDurationRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [consistencyEvent, durationEvent]
        )

        let input = ReflectionComposer.Input(
            snapshot: makeInput(),
            context: pausedContext,
            urgencyLevel: .calm,
            safetyAlert: nil,
            alertSeverity: .none
        )

        let firstOffer = ReflectionComposer.compose(input)
        XCTAssertEqual(firstOffer?.id, consistencyEvent.id)

        ReflectionOfferDisplayTracker.markDisplayed(firstOffer!)

        let secondOffer = ReflectionComposer.compose(input)
        XCTAssertEqual(secondOffer?.id, durationEvent.id)
    }

    func testReturnsNilAtPauseWithoutUnderstandingChange() {
        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .watching, lastUpdated: Date())
        )

        XCTAssertNil(
            ReflectionComposer.compose(
                ReflectionComposer.Input(
                    snapshot: makeInput(),
                    context: pausedContext,
                    urgencyLevel: .calm,
                    safetyAlert: nil,
                    alertSeverity: .none
                )
            )
        )
    }

    func testReadyCoachStateIncludesReflectionOnlyWhenEarned() {
        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [
                UnderstandingEvent.make(
                    beliefID: .sleepConsistencyRecovery,
                    change: .emerged,
                    maturity: .emerging
                )
            ]
        )

        let input = makeCoachInputForStablePause()
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "ReflectionComposerTests"
        )

        XCTAssertNotNil(state.coachUIPresentation)
        if state.coachIntegrationDebug?.scenario == .stableDay {
            XCTAssertNotNil(state.reflectionOffer)
        } else {
            XCTAssertNil(state.reflectionOffer)
        }
    }

    // MARK: - Helpers

    private var pausedContext: CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .settledPost,
            durationBand: .short,
            dayLoadBand: .moderate,
            completedSeriousActivities: .one,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: .recentCompleted,
            minutesUntilStart: nil,
            minutesSinceEnd: 45,
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

    private var blockedContext: CoachContext {
        CoachContext(
            activityFamily: .endurance,
            activityType: .cycling,
            activityState: .active,
            sessionPhase: .during,
            durationBand: .long,
            dayLoadBand: .heavy,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: "ride",
            focusSource: .active,
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

    private func makeInput() -> CoachInputSnapshot {
        let now = CoachTestClock.reference
        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: 15)),
            plannedActivities: [],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 550,
                exerciseMinutes: 90,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.0
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
            source: "ReflectionComposerTests"
        )
    }

    private func makeCoachInputForStablePause() -> CoachInputSnapshot {
        let now = date(hour: 15, minute: 30)
        let completedRide = PlannedActivity(
            date: date(hour: 8, minute: 0),
            type: "workout",
            title: "Morning Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            calories: 900,
            isCompleted: true
        )

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: 15)),
            plannedActivities: [completedRide].coachSnapshots(),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 850,
                exerciseMinutes: 110,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.4
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_900,
                caloriesGoal: 2_800,
                proteinCurrent: 110,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "ReflectionComposerTests.stablePause"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
