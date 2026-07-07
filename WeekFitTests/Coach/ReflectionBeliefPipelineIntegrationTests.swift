import XCTest
@testable import WeekFit

/// End-to-end audit for the sleep-belief cluster and Reflection queue behavior.
final class ReflectionBeliefPipelineIntegrationTests: XCTestCase {

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

    // MARK: - Coexistence

    @MainActor
    func testAllThreeSleepBeliefsUpgradeIndependentlyOnSameRefresh() async {
        CoachObservationStore.seedForTests(SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs())

        CoachUnderstandingService.evaluateBeliefs()

        XCTAssertEqual(CoachUnderstandingStore.belief(for: .sleepConsistencyRecovery).maturity, .emerging)
        XCTAssertEqual(CoachUnderstandingStore.belief(for: .sleepDurationRecovery).maturity, .emerging)
        XCTAssertEqual(CoachUnderstandingStore.belief(for: .lateBedtimeRecovery).maturity, .emerging)

        let pending = CoachUnderstandingStore.pendingEventsForTests()
        XCTAssertEqual(pending.count, 3)
        XCTAssertEqual(Set(pending.map(\.beliefID)), Set([
            .sleepConsistencyRecovery,
            .sleepDurationRecovery,
            .lateBedtimeRecovery,
        ]))
    }

    func testRegistryEvaluatesAllBeliefsWithoutCrossInterference() {
        let observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        XCTAssertEqual(results.count, 7)

        let sleepResults = results.filter {
            [.sleepConsistencyRecovery, .sleepDurationRecovery, .lateBedtimeRecovery].contains($0.beliefID)
        }
        XCTAssertEqual(sleepResults.count, 3)
        XCTAssertTrue(sleepResults.allSatisfy { $0.maturity == .emerging })
        XCTAssertTrue(sleepResults.allSatisfy { $0.event?.change == .emerged })

        let heavyLoad = results.first { $0.beliefID == .heavyLoadRecoveryLag }
        XCTAssertEqual(heavyLoad?.maturity, .watching)
        XCTAssertNil(heavyLoad?.event)

        let recoveryAfterRest = results.first { $0.beliefID == .recoveryAfterRestDay }
        XCTAssertEqual(recoveryAfterRest?.maturity, .watching)
        XCTAssertNil(recoveryAfterRest?.event)

        let consecutiveFatigue = results.first { $0.beliefID == .consecutiveHardDaysFatigue }
        XCTAssertEqual(consecutiveFatigue?.maturity, .watching)
        XCTAssertNil(consecutiveFatigue?.event)

        let underfueling = results.first { $0.beliefID == .underfuelingRecovery }
        XCTAssertEqual(underfueling?.maturity, .watching)
        XCTAssertNil(underfueling?.event)
    }

    func testHeavyLoadBeliefCoexistsWithSleepBeliefsInSerializedQueue() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .heavyLoadRecoveryLag, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .sleepDurationRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .lateBedtimeRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .heavyLoadRecoveryLag, maturity: .emerging, lastUpdated: Date()),
            ],
            pendingEvents: events
        )

        let input = pausedReflectionInput
        var seenIDs: [String] = []

        for expected in events {
            let offer = ReflectionComposer.compose(input)
            XCTAssertEqual(offer?.id, expected.id)
            seenIDs.append(offer!.id)
            ReflectionOfferDisplayTracker.markDisplayed(offer!)
        }

        XCTAssertEqual(seenIDs, events.map(\.id))
        XCTAssertNil(ReflectionComposer.compose(input))
    }

    func testHeavyLoadBeliefEvaluatesAlongsideSleepBeliefsWithoutInterference() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithRecoveryLag()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        XCTAssertEqual(results.count, 7)

        let heavyLoad = results.first { $0.beliefID == .heavyLoadRecoveryLag }
        XCTAssertEqual(heavyLoad?.maturity, .emerging)
        XCTAssertEqual(heavyLoad?.event?.change, .emerged)

        let sleepResults = results.filter {
            [.sleepConsistencyRecovery, .sleepDurationRecovery, .lateBedtimeRecovery].contains($0.beliefID)
        }
        XCTAssertEqual(sleepResults.count, 3)
        XCTAssertTrue(sleepResults.allSatisfy { $0.maturity == .watching })
        XCTAssertTrue(sleepResults.allSatisfy { $0.event == nil })

        let recoveryAfterRest = results.first { $0.beliefID == .recoveryAfterRestDay }
        XCTAssertEqual(recoveryAfterRest?.maturity, .watching)
        XCTAssertNil(recoveryAfterRest?.event)

        let consecutiveFatigue = results.first { $0.beliefID == .consecutiveHardDaysFatigue }
        XCTAssertEqual(consecutiveFatigue?.maturity, .watching)
        XCTAssertNil(consecutiveFatigue?.event)

        let underfueling = results.first { $0.beliefID == .underfuelingRecovery }
        XCTAssertEqual(underfueling?.maturity, .watching)
        XCTAssertNil(underfueling?.event)
    }

    func testConsecutiveHardDaysFatigueCoexistsWithExistingBeliefsInSerializedQueue() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .heavyLoadRecoveryLag, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .recoveryAfterRestDay, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .consecutiveHardDaysFatigue, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: events.map {
                CoachBelief(id: $0.beliefID, maturity: .emerging, lastUpdated: Date())
            },
            pendingEvents: events
        )

        let input = pausedReflectionInput
        var seenIDs: [String] = []

        for expected in events {
            let offer = ReflectionComposer.compose(input)
            XCTAssertEqual(offer?.id, expected.id)
            seenIDs.append(offer!.id)
            ReflectionOfferDisplayTracker.markDisplayed(offer!)
        }

        XCTAssertEqual(seenIDs, events.map(\.id))
        XCTAssertNil(ReflectionComposer.compose(input))
    }

    func testConsecutiveHardDaysFatigueEvaluatesAlongsideOtherBeliefsWithoutInterference() {
        let observations = ConsecutiveHardDaysFatigueFixtures.observationsWithConsecutiveFatigue()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        XCTAssertEqual(results.count, 7)

        let consecutiveFatigue = results.first { $0.beliefID == .consecutiveHardDaysFatigue }
        XCTAssertEqual(consecutiveFatigue?.maturity, .emerging)
        XCTAssertEqual(consecutiveFatigue?.event?.change, .emerged)

        let others = results.filter { $0.beliefID != .consecutiveHardDaysFatigue }
        XCTAssertEqual(others.count, 6)
        XCTAssertTrue(others.allSatisfy { $0.maturity == .watching })
        XCTAssertTrue(others.allSatisfy { $0.event == nil })
    }

    func testRecoveryAfterRestDayCoexistsWithSleepAndHeavyLoadBeliefsInSerializedQueue() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .heavyLoadRecoveryLag, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .recoveryAfterRestDay, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: events.map {
                CoachBelief(id: $0.beliefID, maturity: .emerging, lastUpdated: Date())
            },
            pendingEvents: events
        )

        let input = pausedReflectionInput
        var seenIDs: [String] = []

        for expected in events {
            let offer = ReflectionComposer.compose(input)
            XCTAssertEqual(offer?.id, expected.id)
            seenIDs.append(offer!.id)
            ReflectionOfferDisplayTracker.markDisplayed(offer!)
        }

        XCTAssertEqual(seenIDs, events.map(\.id))
        XCTAssertNil(ReflectionComposer.compose(input))
    }

    func testRecoveryAfterRestDayEvaluatesAlongsideOtherBeliefsWithoutInterference() {
        let observations = RecoveryAfterRestDayFixtures.observationsWithRecoveryRebound()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        XCTAssertEqual(results.count, 7)

        let recoveryAfterRest = results.first { $0.beliefID == .recoveryAfterRestDay }
        XCTAssertEqual(recoveryAfterRest?.maturity, .emerging)
        XCTAssertEqual(recoveryAfterRest?.event?.change, .emerged)

        let others = results.filter { $0.beliefID != .recoveryAfterRestDay }
        XCTAssertEqual(others.count, 6)
        XCTAssertTrue(others.allSatisfy { $0.maturity == .watching })
        XCTAssertTrue(others.allSatisfy { $0.event == nil })
    }

    func testUnderfuelingRecoveryCoexistsWithExistingBeliefsInSerializedQueue() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .heavyLoadRecoveryLag, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .recoveryAfterRestDay, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .consecutiveHardDaysFatigue, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .underfuelingRecovery, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: events.map {
                CoachBelief(id: $0.beliefID, maturity: .emerging, lastUpdated: Date())
            },
            pendingEvents: events
        )

        let input = pausedReflectionInput
        var seenIDs: [String] = []

        for expected in events {
            let offer = ReflectionComposer.compose(input)
            XCTAssertEqual(offer?.id, expected.id)
            seenIDs.append(offer!.id)
            ReflectionOfferDisplayTracker.markDisplayed(offer!)
        }

        XCTAssertEqual(seenIDs, events.map(\.id))
        XCTAssertNil(ReflectionComposer.compose(input))
    }

    func testUnderfuelingRecoveryEvaluatesAlongsideOtherBeliefsWithoutInterference() {
        let observations = UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop()
        let results = CoachBeliefRegistry.evaluateAll(observations: observations)

        XCTAssertEqual(results.count, 7)

        let underfueling = results.first { $0.beliefID == .underfuelingRecovery }
        XCTAssertEqual(underfueling?.maturity, .emerging)
        XCTAssertEqual(underfueling?.event?.change, .emerged)

        let others = results.filter { $0.beliefID != .underfuelingRecovery }
        XCTAssertEqual(others.count, 6)
        XCTAssertTrue(others.allSatisfy { $0.maturity == .watching })
        XCTAssertTrue(others.allSatisfy { $0.event == nil })
    }

    // MARK: - Event queue

    func testMultipleUpgradesSerializeReflectionOneAtATime() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .sleepDurationRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .lateBedtimeRecovery, maturity: .emerging, lastUpdated: Date()),
            ],
            pendingEvents: events
        )

        let input = pausedReflectionInput
        var seenIDs: [String] = []

        for _ in 0..<3 {
            let offer = ReflectionComposer.compose(input)
            XCTAssertNotNil(offer)
            seenIDs.append(offer!.id)
            XCTAssertNotNil(CoachUnderstandingStore.nextUnspokenEvent())
            ReflectionOfferDisplayTracker.markDisplayed(offer!)
        }

        XCTAssertEqual(Set(seenIDs), Set(events.map(\.id)))
        XCTAssertNil(ReflectionComposer.compose(input))
        XCTAssertNil(CoachUnderstandingStore.nextUnspokenEvent())
    }

    func testSpokenEventsAreNeverRepeated() {
        let event = UnderstandingEvent.make(
            beliefID: .sleepConsistencyRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [event],
            spokenEventIDs: [event.id]
        )

        XCTAssertNil(CoachUnderstandingStore.nextUnspokenEvent())
        XCTAssertNil(ReflectionComposer.compose(pausedReflectionInput))
    }

    func testRecomposeWithoutDisplayDoesNotConsumeEvent() {
        let event = UnderstandingEvent.make(
            beliefID: .lateBedtimeRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .lateBedtimeRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [event]
        )

        let input = pausedReflectionInput

        let first = ReflectionComposer.compose(input)
        let second = ReflectionComposer.compose(input)

        XCTAssertEqual(first?.id, event.id)
        XCTAssertEqual(second?.id, event.id)
        XCTAssertEqual(CoachUnderstandingStore.nextUnspokenEvent()?.id, event.id)
        XCTAssertTrue(CoachUnderstandingStore.spokenEventIDsForTests().isEmpty)
    }

    // MARK: - Downgrade

    func testDowngradeDoesNotEnqueueReflectionEvent() {
        let downgrade = BeliefEvaluationResult(
            beliefID: .sleepDurationRecovery,
            previousMaturity: .established,
            nextMaturity: .weakening,
            evidence: nil,
            confidence: 0.2,
            effectSize: 2.5,
            event: nil
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepDurationRecovery, maturity: .established, lastUpdated: Date())
        )

        CoachUnderstandingStore.applyEvaluation(downgrade)

        XCTAssertEqual(CoachUnderstandingStore.belief(for: .sleepDurationRecovery).maturity, .weakening)
        XCTAssertTrue(CoachUnderstandingStore.pendingEventsForTests().isEmpty)
        XCTAssertNil(ReflectionComposer.compose(pausedReflectionInput))
    }

    func testDowngradeClearsUnspokenPendingEventsForBelief() {
        let staleEvent = UnderstandingEvent.make(
            beliefID: .sleepConsistencyRecovery,
            change: .emerged,
            maturity: .emerging
        )

        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepConsistencyRecovery, maturity: .established, lastUpdated: Date()),
            pendingEvents: [staleEvent]
        )

        let downgrade = BeliefEvaluationResult(
            beliefID: .sleepConsistencyRecovery,
            previousMaturity: .established,
            nextMaturity: .weakening,
            evidence: nil,
            confidence: 0.1,
            effectSize: 1.0,
            event: nil
        )

        CoachUnderstandingStore.applyEvaluation(downgrade)

        XCTAssertNil(CoachUnderstandingStore.nextUnspokenEvent())
        XCTAssertTrue(CoachUnderstandingStore.pendingEventsForTests().isEmpty)
    }

    func testRetiredBeliefDoesNotEmitUpgradeEventWhenEvidenceReturns() {
        let observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs()

        for evaluator: any CoachBeliefEvaluator.Type in [
            SleepConsistencyBeliefEvaluator.self,
            SleepDurationBeliefEvaluator.self,
            LateBedtimeBeliefEvaluator.self,
        ] {
            let result = evaluator.evaluate(observations: observations, currentMaturity: .retired)
            XCTAssertEqual(result.nextMaturity, .retired, "\(evaluator.beliefID) should stay retired")
            XCTAssertNil(result.event, "\(evaluator.beliefID) should not emit from retired")
        }
    }

    // MARK: - Coach-only surface

    func testTodayCoachInsightDoesNotSurfaceReflectionOffer() {
        let input = makeCoachInput()
        CoachUnderstandingStore.seedForTests(
            belief: CoachBelief(id: .sleepDurationRecovery, maturity: .emerging, lastUpdated: Date()),
            pendingEvents: [
                UnderstandingEvent.make(
                    beliefID: .sleepDurationRecovery,
                    change: .emerged,
                    maturity: .emerging
                )
            ]
        )

        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "ReflectionBeliefPipelineIntegrationTests"
        )

        XCTAssertTrue(state.canRenderTodayCoachInsight)
        XCTAssertNotNil(state.coachUIPresentation)
    }

    func testReflectionBlockedDuringActiveCoachStatesDespitePendingEvents() {
        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .sleepDurationRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .lateBedtimeRecovery, maturity: .emerging, lastUpdated: Date()),
            ],
            pendingEvents: [
                UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
                UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
                UnderstandingEvent.make(beliefID: .lateBedtimeRecovery, change: .emerged, maturity: .emerging),
            ]
        )

        let blockedInput = ReflectionComposer.Input(
            snapshot: makeCoachInput(),
            context: CoachContext(
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
            ),
            urgencyLevel: .live,
            safetyAlert: nil,
            alertSeverity: .none
        )

        XCTAssertNil(ReflectionComposer.compose(blockedInput))
        XCTAssertEqual(CoachUnderstandingStore.pendingEventsForTests().count, 3)
        XCTAssertNotNil(CoachUnderstandingStore.nextUnspokenEvent())
    }

    // MARK: - Helpers

    private var pausedReflectionInput: ReflectionComposer.Input {
        ReflectionComposer.Input(
            snapshot: makeCoachInput(),
            context: CoachContext(
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
            ),
            urgencyLevel: .calm,
            safetyAlert: nil,
            alertSeverity: .none
        )
    }

    private func makeCoachInput() -> CoachInputSnapshot {
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
            source: "ReflectionBeliefPipelineIntegrationTests"
        )
    }
}

// MARK: - Fixtures

enum SleepBeliefIntegrationFixtures {

    static func observationsSupportingAllThreeBeliefs() -> [CoachDailyObservation] {
        var observations: [CoachDailyObservation] = []
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference

        let normalBedtime = (22 * 60) + 45
        let lateBedtime = (1 * 60) + (24 * 60)

        var dayOffset = 1
        for index in 0..<5 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: 84 + (index % 2),
                    bedStartNormalizedMinutes: normalBedtime + (index % 2) * 5
                )
            )
            dayOffset += 1
        }

        for index in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 360,
                    recoveryPercent: 68 - (index % 2),
                    bedStartNormalizedMinutes: lateBedtime
                )
            )
            dayOffset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
