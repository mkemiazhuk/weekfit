import XCTest
@testable import WeekFit

final class CoachStateTodayCoachInsightTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testCoachActiveCanRenderTodayCoachInsight() {
        let state = makeState(coachUIPresentation: sampleCoachUIPresentation)

        XCTAssertTrue(state.canRenderTodayCoachInsight)
        XCTAssertNil(state.todayCoachInsightHiddenReason)
    }

    func testReadyViaEngineCanRenderTodayCoachInsight() {
        let input = makeCoachInput()
        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            reason: "test"
        )

        XCTAssertNotNil(state.coachUIPresentation)
        XCTAssertTrue(state.canRenderTodayCoachInsight)
        XCTAssertNil(state.todayCoachInsightHiddenReason)
    }

    func testSettlingStateCannotRenderTodayCoachInsight() {
        let state = CoachState.settling(reason: "Coach inputs are still syncing.")

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertEqual(state.todayCoachInsightHiddenReason, .settling)
    }

    func testUnavailableStateCannotRenderTodayCoachInsight() {
        let state = CoachState.unavailable(reason: "Coach inputs have not been collected yet.")

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertEqual(state.todayCoachInsightHiddenReason, .settling)
    }

    func testReadyWithoutCoachUICannotRenderTodayCoachInsight() {
        let state = makeState(coachUIPresentation: nil)

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertEqual(state.todayCoachInsightHiddenReason, .registryGap)
    }

    func testEmptyTodayPresentationCannotRenderTodayCoachInsight() {
        var presentation = sampleCoachUIPresentation
        presentation = CoachUIPresentation(
            scenario: presentation.scenario,
            assessment: presentation.assessment,
            recommendation: presentation.recommendation,
            avoid: presentation.avoid,
            nextAction: presentation.nextAction,
            supportingSignals: presentation.supportingSignals,
            warningMessage: presentation.warningMessage,
            warningAlert: presentation.warningAlert,
            semanticColor: presentation.semanticColor,
            alertSeverity: presentation.alertSeverity,
            icon: presentation.icon,
            urgencyLevel: presentation.urgencyLevel,
            statusLabel: presentation.statusLabel,
            coachTitle: presentation.coachTitle,
            todayTitle: "   ",
            todayMessage: presentation.todayMessage,
            whyRows: presentation.whyRows
        )
        let state = makeState(coachUIPresentation: presentation)

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertEqual(state.todayCoachInsightHiddenReason, .noTodayPresentation)
    }

    func testInvalidStatusCannotRenderTodayCoachInsight() {
        let state = makeState(
            status: .invalid(reason: "test"),
            coachUIPresentation: sampleCoachUIPresentation
        )

        XCTAssertFalse(state.canRenderTodayCoachInsight)
        XCTAssertEqual(state.todayCoachInsightHiddenReason, .stateNotReady)
    }

    // MARK: - Helpers

    private var sampleCoachUIPresentation: CoachUIPresentation {
        CoachUIPresentation(
            scenario: .stableDay,
            assessment: "Main work is done.",
            recommendation: "Keep the rest of the day calm.",
            avoid: "Do not add load.",
            nextAction: "Water and rest.",
            supportingSignals: [],
            warningMessage: nil,
            warningAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            icon: "figure.walk",
            urgencyLevel: .calm,
            statusLabel: "Important now",
            coachTitle: "Recovering now",
            todayTitle: "Recovering now",
            todayMessage: "Recovery is the job for the rest of today.",
            whyRows: []
        )
    }

    private func makeState(
        status: CoachStateStatus = .ready,
        coachUIPresentation: CoachUIPresentation? = nil
    ) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: Date(),
            status: status,
            input: nil,
            fingerprint: nil,
            coachUIPresentation: coachUIPresentation,
            coachIntegrationDebug: coachUIPresentation == nil
                ? nil
                : CoachIntegrationDebug(
                    scenario: .stableDay,
                    copyPackExists: true,
                    usingCoach: true,
                    fallbackReason: nil
                ),
            reflectionOffer: nil
        )
    }

    private func makeCoachInput() -> CoachInputSnapshot {
        CoachInputSnapshot(
            selectedDate: CoachTestClock.reference,
            now: CoachTestClock.reference,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: 14)),
            plannedActivities: [],
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
            source: "CoachStateTodayCoachInsightTests"
        )
    }
}
