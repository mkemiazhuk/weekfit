import XCTest
@testable import WeekFit

final class CoachDiscoveryComposerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachDiscoveryStore.resetForTests()
        CoachUnderstandingStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        CoachDiscoveryStore.resetForTests()
        CoachUnderstandingStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testReturnsNilWhenConversationIsNotPaused() {
        seedPendingOffer()

        let offer = CoachDiscoveryComposer.compose(
            CoachDiscoveryComposer.Input(
                snapshot: makeInput(),
                context: blockedContext,
                urgencyLevel: .live,
                safetyAlert: nil,
                alertSeverity: .none
            )
        )

        XCTAssertNil(offer)
        XCTAssertNotNil(CoachDiscoveryStore.nextOffer())
    }

    func testReturnsOfferWhenPausedAndPending() {
        let pending = seedPendingOffer()

        let offer = CoachDiscoveryComposer.compose(
            CoachDiscoveryComposer.Input(
                snapshot: makeInput(),
                context: pausedContext,
                urgencyLevel: .calm,
                safetyAlert: nil,
                alertSeverity: .none
            )
        )

        XCTAssertEqual(offer?.id, pending.id)
        XCTAssertEqual(offer?.beliefID, .sleepDurationRecovery)
        XCTAssertEqual(offer?.kind, .firstLearned)
    }

    func testReturnsNilAtPauseWithoutPendingOffer() {
        CoachDiscoveryStore.seedForTests()

        XCTAssertNil(
            CoachDiscoveryComposer.compose(
                CoachDiscoveryComposer.Input(
                    snapshot: makeInput(),
                    context: pausedContext,
                    urgencyLevel: .calm,
                    safetyAlert: nil,
                    alertSeverity: .none
                )
            )
        )
    }

    func testDiscoveryTakesPrecedenceOverReflectionWhenBothAvailable() {
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
        // Understanding reset clears discovery storage — seed offer after it.
        let pending = seedPendingOffer()

        let discoveryInput = CoachDiscoveryComposer.Input(
            snapshot: makeInput(),
            context: pausedContext,
            urgencyLevel: .calm,
            safetyAlert: nil,
            alertSeverity: .none
        )
        let reflectionInput = ReflectionComposer.Input(
            snapshot: makeInput(),
            context: pausedContext,
            urgencyLevel: .calm,
            safetyAlert: nil,
            alertSeverity: .none
        )

        let discovery = CoachDiscoveryComposer.compose(discoveryInput)
        let reflection = ReflectionComposer.compose(reflectionInput)

        XCTAssertEqual(discovery?.id, pending.id)
        XCTAssertNotNil(reflection)

        // Same precedence rule as CoachState.ready — discovery owns the Tell slot.
        let tellReflection = discovery == nil ? reflection : nil
        XCTAssertNil(tellReflection)
    }

    // MARK: - Helpers

    @discardableResult
    private func seedPendingOffer() -> CoachDiscoveryOffer {
        let discovery = CoachDiscovery(
            beliefID: .sleepDurationRecovery,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.10",
            effectSize: 10,
            confidence: 0.8,
            eligibleDayCount: 12
        )
        let offer = CoachDiscoveryOffer.make(
            discoveryID: discovery.id,
            beliefID: .sleepDurationRecovery,
            kind: .firstLearned,
            materialChangeToken: discovery.materialChangeToken
        )
        CoachDiscoveryStore.seedForTests(
            discoveries: [discovery],
            pendingOffers: [offer]
        )
        return offer
    }

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
            source: "CoachDiscoveryComposerTests"
        )
    }
}
