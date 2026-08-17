import XCTest
@testable import WeekFit

final class CoachLearnedContextBuilderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        CoachDiscoveryStore.resetForTests()
        CoachObservationStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        CoachDiscoveryStore.resetForTests()
        CoachObservationStore.resetForTests()
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testProteinGapNudgeWhenBelowLearnedTrainingDayRange() {
        let observations = ProteinTrainingDayRecoveryFixtures.observationsWithStableDelta()
        let discovery = CoachDiscovery(
            beliefID: .proteinTrainingDayRecovery,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.12",
            effectSize: 12,
            confidence: 0.85,
            eligibleDayCount: 18
        )

        let learned = CoachLearnedContextBuilder.build(
            input: makeInput(proteinCurrent: 70),
            context: trainingContext,
            discoveries: [discovery],
            observations: observations
        )

        let nudge = learned.primaryNudge
        XCTAssertEqual(nudge?.kind, .proteinGapOnTrainingDay)
        XCTAssertEqual(nudge?.beliefID, .proteinTrainingDayRecovery)
        XCTAssertEqual(nudge?.currentProteinGrams, 70)
        XCTAssertGreaterThan(nudge?.gapGrams ?? 0, 19)
        XCTAssertTrue(nudge?.message.english.contains("70 g protein") ?? false)
    }

    func testNoProteinNudgeWhenAlreadyInLearnedRange() {
        let observations = ProteinTrainingDayRecoveryFixtures.observationsWithStableDelta()
        let discovery = CoachDiscovery(
            beliefID: .proteinTrainingDayRecovery,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.12",
            effectSize: 12,
            confidence: 0.85,
            eligibleDayCount: 18
        )

        let learned = CoachLearnedContextBuilder.build(
            input: makeInput(proteinCurrent: 180),
            context: trainingContext,
            discoveries: [discovery],
            observations: observations
        )

        XCTAssertFalse(learned.relevantToday.contains { $0.kind == .proteinGapOnTrainingDay })
    }

    func testHardTrainingLowRecoveryNudgeWhenRecoveryIsLow() {
        let discovery = CoachDiscovery(
            beliefID: .hardTrainingLowRecoveryCost,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.10",
            effectSize: 10,
            confidence: 0.8,
            eligibleDayCount: 14
        )

        let learned = CoachLearnedContextBuilder.build(
            input: makeInput(proteinCurrent: 120, recoveryPercent: 48),
            context: trainingContext,
            discoveries: [discovery],
            observations: []
        )

        XCTAssertEqual(learned.primaryNudge?.kind, .hardTrainingOnLowRecovery)
        XCTAssertTrue(learned.primaryNudge?.message.english.contains("lower-recovery") ?? false)
    }

    func testAdaptCopyPolicyPrependsNudgeIntoSupportingSignals() {
        let observations = ProteinTrainingDayRecoveryFixtures.observationsWithStableDelta()
        let discovery = CoachDiscovery(
            beliefID: .proteinTrainingDayRecovery,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.12",
            effectSize: 12,
            confidence: 0.85,
            eligibleDayCount: 18
        )
        CoachDiscoveryStore.seedForTests(discoveries: [discovery])
        CoachObservationStore.seedForTests(observations)

        let pack = CoachCopyPack(
            scenario: .stableDay,
            assessment: .single(.en("Assessment", "Оценка")),
            recommendation: .single(.en("Recommendation", "Рекомендация")),
            avoid: .single(.en("Avoid", "Избегать")),
            nextAction: .single(.en("Next", "Далее")),
            supportingSignals: .lines(
                .en("Existing why", "Существующий why"),
                .en("Second why", "Второй why"),
                .en("Third why", "Третий why")
            ),
            warningLayer: nil
        )

        let adapted = CoachDiscoveryAdaptCopyPolicy.apply(
            to: pack,
            input: makeInput(proteinCurrent: 70),
            context: trainingContext
        )

        XCTAssertEqual(adapted.supportingSignals.lines.count, 3)
        XCTAssertTrue(adapted.supportingSignals.lines[0].english.contains("70 g protein"))
        XCTAssertEqual(adapted.scenario, .stableDay)
        XCTAssertEqual(adapted.assessment, pack.assessment)
    }

    func testPreferAvoidHardLoadRequiresActiveDiscoveryAndLowRecovery() {
        let discovery = CoachDiscovery(
            beliefID: .hardTrainingLowRecoveryCost,
            status: .active,
            firstLearnedAt: Date(),
            lastEvaluatedAt: Date(),
            materialChangeToken: "established.10",
            effectSize: 10,
            confidence: 0.8,
            eligibleDayCount: 16
        )

        XCTAssertTrue(
            CoachLearnedContextBuilder.preferAvoidHardLoadOnLowRecovery(
                recoveryPercent: 52,
                discoveries: [discovery]
            )
        )
        XCTAssertFalse(
            CoachLearnedContextBuilder.preferAvoidHardLoadOnLowRecovery(
                recoveryPercent: 72,
                discoveries: [discovery]
            )
        )
        XCTAssertFalse(
            CoachLearnedContextBuilder.preferAvoidHardLoadOnLowRecovery(
                recoveryPercent: 52,
                discoveries: []
            )
        )
    }

    // MARK: - Helpers

    private var trainingContext: CoachContext {
        CoachContext(
            activityFamily: .endurance,
            activityType: .cycling,
            activityState: .finished,
            sessionPhase: .settledPost,
            durationBand: .long,
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
            minutesSinceEnd: 40,
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

    private func makeInput(proteinCurrent: Double, recoveryPercent: Int = 82) -> CoachInputSnapshot {
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
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: recoveryPercent,
                sleepHours: 7.5
            ),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_400,
                proteinCurrent: proteinCurrent,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachLearnedContextBuilderTests"
        )
    }
}
