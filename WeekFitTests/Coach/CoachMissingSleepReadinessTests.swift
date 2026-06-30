import XCTest
@testable import WeekFit

final class CoachMissingSleepReadinessTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - CoachInputReadiness

    func testNoSleepAtSevenAMWithHealthConnectedStaysSettling() {
        let input = makeMissingSleepInput(hour: 7, healthGranted: true)
        let assessment = CoachInputReadiness.assessment(input)

        XCTAssertFalse(assessment.allowed)
        XCTAssertEqual(assessment.dataReadinessState, .settling)
        XCTAssertTrue(assessment.blockingReasons.contains("recoveryAwaitingMorningSync"))
    }

    func testNoSleepAtTenAMWithHealthConnectedAllowsLimitedRecovery() {
        let input = makeMissingSleepInput(hour: 10, healthGranted: true)
        let assessment = CoachInputReadiness.assessment(input)

        XCTAssertTrue(assessment.allowed)
        XCTAssertEqual(assessment.dataReadinessState, .limitedRecovery)
        XCTAssertTrue(assessment.satisfiedConditions.contains("limitedRecoveryMode"))
    }

    func testNoSleepAfterCutoffProducesReadyCoachState() {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )

        XCTAssertEqual(state.status, .ready)
        XCTAssertTrue(state.canRenderTodayCoachInsight)
        XCTAssertNotNil(state.coachUIPresentation)
        XCTAssertTrue(state.coachUIPresentation?.showsLimitedConfidenceBadge == true)
    }

    func testNoSleepBeforeCutoffProducesSettlingCoachState() {
        let input = makeMissingSleepInput(hour: 7, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertNil(state.coachUIPresentation)
    }

    func testNoSleepWithoutHealthAccessStaysSettling() {
        let input = makeMissingSleepInput(hour: 11, healthGranted: false)
        let assessment = CoachInputReadiness.assessment(input)

        XCTAssertFalse(assessment.allowed)
        XCTAssertEqual(assessment.dataReadinessState, .settling)
        XCTAssertTrue(assessment.blockingReasons.contains("healthNotConnected"))
    }

    // MARK: - CoachDayReadiness

    func testMissingRecoveryDataUsesNeutralReadinessBand() {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true)
        let readiness = CoachDayReadinessResolver.resolve(from: input)

        XCTAssertFalse(readiness.recoveryDataAvailable)
        XCTAssertFalse(readiness.sleepIsLow)
        XCTAssertFalse(readiness.isLowRecovery)
        XCTAssertEqual(readiness.recoveryBand, .moderate)
        XCTAssertEqual(readiness.recoveryPercent, 0)
        XCTAssertEqual(readiness.sleepHours, 0)
    }

    // MARK: - Scenario + copy

    func testNoSleepHeavyYesterdayUsesRecoveryStoryWithoutRecoveryClaims() throws {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true, hadHeavyYesterday: true)
        let result = CoachEngine.evaluate(input: input)

        XCTAssertEqual(result.scenario, .recoveryAfterHeavyYesterday)

        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let presentation = try XCTUnwrap(state.coachUIPresentation)
        let combined = [
            presentation.assessment,
            presentation.recommendation,
            presentation.avoid,
            presentation.nextAction,
            presentation.todayMessage
        ].joined(separator: " ").lowercased()

        XCTAssertTrue(presentation.assessment.contains("plan and activity") || presentation.assessment.contains("плане и активности"))
        XCTAssertFalse(combined.contains("0%"))
        XCTAssertFalse(combined.contains("recovery 0"))
        XCTAssertFalse(combined.contains("short night"))
        XCTAssertFalse(combined.contains("коротк"))
    }

    func testNoSleepHeavyYesterdayDoesNotTriggerLowRecoveryPrep() {
        let now = makeDate(hour: 13)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(60 * 60),
            type: "workout",
            title: "Afternoon Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        let input = makeMissingSleepInput(
            hour: 13,
            healthGranted: true,
            hadHeavyYesterday: true,
            activities: [ride]
        )

        let result = CoachEngine.evaluate(input: input)
        XCTAssertNotEqual(result.scenario, .lowRecoveryPrep)
    }

    func testLateSleepArrivalAfterCutoffTransitionsToCoherentReady() {
        let missingInput = makeMissingSleepInput(hour: 11, healthGranted: true)
        let limitedState = CoachState.ready(
            input: missingInput,
            fingerprint: CoachInputFingerprint(snapshot: missingInput),
            reason: "test-limited"
        )
        XCTAssertTrue(limitedState.coachUIPresentation?.showsLimitedConfidenceBadge == true)

        let syncedInput = makeMissingSleepInput(
            hour: 11,
            healthGranted: true,
            recoveryPercent: 82,
            sleepHours: 7.5
        )
        let coherentAssessment = CoachInputReadiness.assessment(syncedInput)
        XCTAssertEqual(coherentAssessment.dataReadinessState, .coherent)

        let syncedState = CoachState.ready(
            input: syncedInput,
            fingerprint: CoachInputFingerprint(snapshot: syncedInput),
            reason: "test-synced"
        )
        XCTAssertFalse(syncedState.coachUIPresentation?.showsLimitedConfidenceBadge == true)
        XCTAssertTrue(syncedState.canRenderTodayCoachInsight)
    }

    func testRecoveryRingModeBeforeCutoffAwaitingSync() {
        let mode = CoachInputReadiness.recoveryRingMode(
            isHealthAccessGranted: true,
            hasRecoverySignals: false,
            now: makeDate(hour: 7)
        )
        XCTAssertEqual(mode, .awaitingMorningSync)
    }

    func testRecoveryRingModeAfterCutoffSleepNotRecorded() {
        let mode = CoachInputReadiness.recoveryRingMode(
            isHealthAccessGranted: true,
            hasRecoverySignals: false,
            now: makeDate(hour: 11)
        )
        XCTAssertEqual(mode, .sleepNotRecorded)
    }

    func testLimitedRecoveryCoachStatusBadgeShowsNoRecovery() {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )

        XCTAssertEqual(state.coachUIPresentation?.statusLabel, "No recovery")
    }

    func testLimitedRecoveryAssessmentUsesConversationalCopy() {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let assessment = state.coachUIPresentation?.assessment ?? ""
        XCTAssertTrue(assessment.contains("plan and activity") || assessment.contains("плане и активности"))
        XCTAssertFalse(assessment.lowercased().contains("not recorded last night"))
    }

    // MARK: - Helpers

    private func makeMissingSleepInput(
        hour: Int,
        minute: Int = 0,
        healthGranted: Bool = true,
        hadHeavyYesterday: Bool = false,
        recoveryPercent: Int = 0,
        sleepHours: Double = 0,
        activities: [PlannedActivity] = []
    ) -> CoachInputSnapshot {
        let now = makeDate(hour: hour, minute: minute)

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = hour
        brainConfig.sleep = .unknown
        brainConfig.metrics = CoachMetricsBuilder.missingHealthKit()
        brainConfig.readiness = .low
        brainConfig.recovery = .compromised
        if hadHeavyYesterday {
            brainConfig.completedWorkoutsCount = 2
            brainConfig.strain = .high
        }

        var brain = HumanBrainStateBuilder.make(brainConfig)
        if recoveryPercent > 0 || sleepHours > 0 {
            brainConfig.metrics = CoachMetricsBuilder.metrics(
                activeCalories: hadHeavyYesterday ? 900 : 0,
                sleepHours: sleepHours
            )
            brainConfig.sleep = sleepHours >= 7 ? .okay : .short
            brainConfig.readiness = .good
            brainConfig.recovery = .stable
            brain = HumanBrainStateBuilder.make(brainConfig)
        }

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: brain,
            plannedActivities: activities,
            dayContext: CoachDayContextBuilder.build(
                activities: activities,
                selectedDate: now,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: recoveryPercent,
                sleepHours: sleepHours
            ),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            isHealthAccessGranted: healthGranted,
            source: "CoachMissingSleepReadinessTests"
        )
    }

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? CoachTestClock.reference
    }
}
