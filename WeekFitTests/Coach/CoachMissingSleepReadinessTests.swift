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

    func testNoSleepAtSevenAMWithHealthConnectedShowsNeutralGuidance() {
        let input = makeMissingSleepInput(hour: 7, healthGranted: true)
        let assessment = CoachInputReadiness.assessment(input)

        XCTAssertTrue(assessment.allowed)
        XCTAssertEqual(assessment.dataReadinessState, .limitedRecovery)
        XCTAssertTrue(assessment.satisfiedConditions.contains("limitedRecoveryMode"))
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
        XCTAssertFalse(state.coachUIPresentation?.showsLimitedConfidenceBadge == true)
        XCTAssertNotEqual(state.coachUIPresentation?.todayTitle, "Check your watch")
    }

    func testNoSleepBeforeMorningStillShowsStandardFocus() throws {
        let input = makeMissingSleepInput(hour: 7, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )

        let presentation = try XCTUnwrap(state.coachUIPresentation)
        XCTAssertTrue(state.canRenderTodayCoachInsight)
        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.todayTitle, "Check your watch")
        XCTAssertNotEqual(presentation.coachTitle, "Drink water")
        XCTAssertFalse(presentation.todayMessage.localizedCaseInsensitiveContains("either it died"))
        let display = CoachTodayCardCopy.display(from: presentation, nextActivityTitle: nil)
        XCTAssertNotEqual(display.title, "Check your watch")
        XCTAssertFalse(display.title.isEmpty)
    }

    func testLanguageChangeBypassesReadinessGateAndSwitchesCopy() {
        let input = makeMissingSleepInput(hour: 7, healthGranted: true)
        XCTAssertTrue(CoachInputReadiness.assessment(input).allowed)

        WeekFitSetCurrentLanguage(.english)
        let englishState = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "seed.en",
            bypassReadinessGate: true
        )
        XCTAssertNotNil(englishState.coachUIPresentation)
        let englishTitle = englishState.coachUIPresentation?.todayTitle ?? ""

        WeekFitSetCurrentLanguage(.russian)
        let russianState = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "languageChange.ru",
            bypassReadinessGate: true
        )
        XCTAssertNotNil(russianState.coachUIPresentation)
        let russianTitle = russianState.coachUIPresentation?.todayTitle ?? ""
        XCTAssertFalse(russianTitle.isEmpty)
        XCTAssertNotEqual(englishTitle, russianTitle)
        XCTAssertTrue(
            russianTitle.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) },
            "Expected Cyrillic coach title after RU language change, got: \(russianTitle)"
        )
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

        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.todayTitle, "Check your watch")
        XCTAssertFalse(combined.contains("0%"))
        XCTAssertFalse(combined.contains("recovery 0"))
        XCTAssertFalse(combined.contains("short night"))
        XCTAssertFalse(combined.contains("коротк"))
    }

    func testNoSleepLowWaterRecommendsDrinking() throws {
        let input = makeMissingSleepInput(hour: 14, healthGranted: true, waterCurrent: 0.2)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let presentation = try XCTUnwrap(state.coachUIPresentation)
        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.recommendation, "Drink some water and keep the day easy.")
    }

    func testNoSleepLowFuelRecommendsAMeal() throws {
        let input = makeMissingSleepInput(
            hour: 14,
            healthGranted: true,
            caloriesCurrent: 400,
            proteinCurrent: 20
        )
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let presentation = try XCTUnwrap(state.coachUIPresentation)
        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.recommendation, "Eat a normal meal and keep the day easy.")
    }

    func testNoSleepUpcomingSessionKeepsThePlan() throws {
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
        let input = makeMissingSleepInput(hour: 13, healthGranted: true, activities: [ride])
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let presentation = try XCTUnwrap(state.coachUIPresentation)
        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.todayTitle, "Check your watch")
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
        XCTAssertFalse(limitedState.coachUIPresentation?.showsLimitedConfidenceBadge == true)

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

    func testRecoveryRingModeWithoutSleepShowsNotRecorded() {
        let mode = CoachInputReadiness.recoveryRingMode(
            isHealthAccessGranted: true,
            hasRecoverySignals: false,
            now: makeDate(hour: 7)
        )
        XCTAssertEqual(mode, .sleepNotRecorded)
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

        XCTAssertFalse(state.coachUIPresentation?.showsLimitedConfidenceBadge == true)
        XCTAssertNotEqual(state.coachUIPresentation?.statusLabel, "No sleep data")
    }

    func testLimitedRecoveryAssessmentUsesConversationalCopy() throws {
        let input = makeMissingSleepInput(hour: 11, healthGranted: true)
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )
        let presentation = try XCTUnwrap(state.coachUIPresentation)
        XCTAssertNotEqual(presentation.todayTitle, "Check your watch")
        XCTAssertFalse(presentation.todayMessage.localizedCaseInsensitiveContains("either it died"))
        XCTAssertFalse(presentation.showsLimitedConfidenceBadge)
        XCTAssertNotEqual(presentation.statusLabel, "No sleep data")
    }

    func testRecoveryContextSleepSatisfiesReadinessWhenBrainMetricsSleepMissing() {
        let now = makeDate(hour: 14)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 14
        brainConfig.metrics = CoachMetricsBuilder.metrics(activeCalories: 400, sleepHours: 0)
        brainConfig.sleep = .short
        brainConfig.readiness = .moderate
        brainConfig.recovery = .stable

        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: [],
            dayContext: CoachDayContextBuilder.build(
                activities: [],
                selectedDate: now,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 58, sleepHours: 5.0),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            isHealthAccessGranted: true,
            source: "CoachMissingSleepReadinessTests"
        )

        let assessment = CoachInputReadiness.assessment(input)

        XCTAssertTrue(assessment.satisfiedConditions.contains("sleepHours"))
        XCTAssertFalse(assessment.blockingReasons.contains("sleepPlaceholder"))
    }

    // MARK: - Helpers

    private func makeMissingSleepInput(
        hour: Int,
        minute: Int = 0,
        healthGranted: Bool = true,
        hadHeavyYesterday: Bool = false,
        recoveryPercent: Int = 0,
        sleepHours: Double = 0,
        activities: [PlannedActivity] = [],
        caloriesCurrent: Double = 1_800,
        proteinCurrent: Double = 90,
        waterCurrent: Double = 1.8
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
            plannedActivities: activities.coachSnapshots(),
            dayContext: CoachDayContextBuilder.build(
                activities: activities.coachSnapshots(),
                selectedDate: now,
                now: now
            ),
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: recoveryPercent,
                sleepHours: sleepHours
            ),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: caloriesCurrent,
                caloriesGoal: 2_800,
                proteinCurrent: proteinCurrent,
                proteinGoal: 140,
                waterCurrent: waterCurrent,
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
