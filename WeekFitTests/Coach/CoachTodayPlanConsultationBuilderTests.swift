import XCTest
@testable import WeekFit

final class CoachTodayPlanConsultationBuilderTests: XCTestCase {

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        WeekFitWarmLocalizationCache()
        super.tearDown()
    }

    func testBuilderReturnsNilForStableDayWithoutAdjustScenario() {
        let state = makeState(
            scenario: .stableDay,
            recoveryPercent: 80,
            sleepHours: 7.5,
            activities: [cycling(atHour: 15)]
        )
        XCTAssertNil(CoachTodayPlanConsultationBuilder.build(from: state))
    }

    func testBuilderReturnsNilWhenNoUpcomingTraining() {
        let state = makeState(
            scenario: .lowRecoveryPrep,
            recoveryPercent: 48,
            sleepHours: 6.2,
            activities: []
        )
        XCTAssertNil(CoachTodayPlanConsultationBuilder.build(from: state))
    }

    func testLowRecoveryPrepBuildsCompactConsultationHierarchy() throws {
        WeekFitSetCurrentLanguage(.english)
        WeekFitWarmLocalizationCache()

        let state = makeState(
            scenario: .lowRecoveryPrep,
            recoveryPercent: 48,
            sleepHours: 6.2,
            activities: [cycling(atHour: 14, minute: 53)]
        )
        let presentation = try XCTUnwrap(CoachTodayPlanConsultationBuilder.build(from: state))

        XCTAssertEqual(presentation.scenario, .lowRecoveryPrep)
        XCTAssertFalse(presentation.eyebrow.isEmpty)
        XCTAssertFalse(presentation.headline.isEmpty)
        XCTAssertFalse(presentation.summary.isEmpty)
        XCTAssertEqual(presentation.changeItems.count, 3)
        XCTAssertEqual(presentation.changeItems[0].kind, .keep)
        XCTAssertEqual(presentation.changeItems[1].kind, .adjust)
        XCTAssertEqual(presentation.changeItems[2].kind, .remove)
        XCTAssertEqual(presentation.timelineItems.count, 1)
        XCTAssertEqual(presentation.timelineItems[0].kind, .keep)
        XCTAssertTrue(presentation.timelineItems[0].isSelectedByDefault)
        XCTAssertTrue(presentation.reasonValue.lowercased().contains("recovery"))
        XCTAssertFalse(presentation.noteHeadline.isEmpty)
        XCTAssertFalse(presentation.primaryCTATitle.isEmpty)
        XCTAssertFalse(presentation.secondaryCTATitle.isEmpty)
    }

    func testRussianCopyUsesCyrillicHierarchy() throws {
        WeekFitSetCurrentLanguage(.russian)
        WeekFitWarmLocalizationCache()

        let state = makeState(
            scenario: .lowRecoveryPrep,
            recoveryPercent: 48,
            sleepHours: 6.2,
            activities: [cycling(atHour: 14, minute: 53)]
        )
        let presentation = try XCTUnwrap(CoachTodayPlanConsultationBuilder.build(from: state))

        XCTAssertTrue(containsCyrillic(presentation.eyebrow), presentation.eyebrow)
        XCTAssertTrue(containsCyrillic(presentation.headline), presentation.headline)
        XCTAssertTrue(containsCyrillic(presentation.summary), presentation.summary)
        XCTAssertTrue(containsCyrillic(presentation.changesSectionTitle), presentation.changesSectionTitle)
        XCTAssertTrue(containsCyrillic(presentation.timelineSectionTitle), presentation.timelineSectionTitle)
        XCTAssertTrue(containsCyrillic(presentation.primaryCTATitle), presentation.primaryCTATitle)
        XCTAssertTrue(containsCyrillic(presentation.secondaryCTATitle), presentation.secondaryCTATitle)
        XCTAssertTrue(presentation.changeItems[0].title.contains("оставить") || containsCyrillic(presentation.changeItems[0].title))
    }

    func testSecondarySeriousTrainingAppearsAsRemoveTimelineRow() throws {
        WeekFitSetCurrentLanguage(.english)
        WeekFitWarmLocalizationCache()

        let state = makeState(
            scenario: .lowRecoveryPrep,
            recoveryPercent: 45,
            sleepHours: 5.8,
            activities: [
                cycling(atHour: 10, duration: 90),
                strength(atHour: 18, duration: 60)
            ]
        )
        let presentation = try XCTUnwrap(CoachTodayPlanConsultationBuilder.build(from: state))

        XCTAssertGreaterThanOrEqual(presentation.timelineItems.count, 2)
        XCTAssertEqual(presentation.timelineItems[0].kind, .keep)
        XCTAssertEqual(presentation.timelineItems[1].kind, .remove)
        XCTAssertTrue(presentation.timelineItems[1].isSelectedByDefault)
    }

    func testDoesNotInventRemoveTimelineWhenOnlyOneActivity() throws {
        let state = makeState(
            scenario: .lowRecoveryPrep,
            recoveryPercent: 48,
            sleepHours: 6.2,
            activities: [cycling(atHour: 15)]
        )
        let presentation = try XCTUnwrap(CoachTodayPlanConsultationBuilder.build(from: state))
        XCTAssertEqual(presentation.timelineItems.count, 1)
        XCTAssertFalse(presentation.timelineItems.contains(where: { $0.kind == .remove }))
    }

    // MARK: - Helpers

    private func makeState(
        scenario: CoachScenarioKey,
        recoveryPercent: Int,
        sleepHours: Double,
        activities: [CoachPlannedActivitySnapshot]
    ) -> CoachState {
        let now = CoachTestClock.reference
        let brain = HumanBrainStateBuilder.make(
            HumanBrainStateBuilder.Configuration(
                currentHour: 10,
                metrics: CoachMetricsBuilder.metrics(
                    activeCalories: 200,
                    sleepHours: sleepHours
                ),
                readiness: recoveryPercent < 55 ? .compromised : .good
            )
        )

        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: brain,
            plannedActivities: activities,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: recoveryPercent,
                sleepHours: sleepHours
            ),
            nutritionContext: nil,
            source: "test.todayPlanConsultation"
        )

        let presentation = CoachUIPresentation(
            scenario: scenario,
            assessment: "Assessment",
            recommendation: "Recommendation",
            avoid: "Avoid",
            nextAction: "Next",
            supportingSignals: [],
            warningMessage: nil,
            warningAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            icon: "heart.fill",
            urgencyLevel: .elevated,
            statusLabel: "Adjust",
            coachTitle: "Ease the plan",
            todayTitle: "Ease today",
            todayMessage: "Keep intensity moderate.",
            whyRows: []
        )

        return CoachState(
            id: UUID(),
            createdAt: now,
            status: .ready,
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            coachUIPresentation: presentation,
            coachIntegrationDebug: nil,
            reflectionOffer: nil
        )
    }

    private func cycling(atHour: Int, minute: Int = 0, duration: Int = 60) -> CoachPlannedActivitySnapshot {
        let base = CoachTestClock.reference
        let date = Calendar.current.date(bySettingHour: atHour, minute: minute, second: 0, of: base) ?? base
        return CoachPlannedActivitySnapshot(
            date: date,
            type: "workout",
            title: "Cycling",
            durationMinutes: duration,
            icon: "figure.outdoor.cycle",
            imageName: "cycling"
        )
    }

    private func strength(atHour: Int, duration: Int = 55) -> CoachPlannedActivitySnapshot {
        let base = CoachTestClock.reference
        let date = Calendar.current.date(bySettingHour: atHour, minute: 0, second: 0, of: base) ?? base
        return CoachPlannedActivitySnapshot(
            date: date,
            type: "workout",
            title: "Full Body",
            durationMinutes: duration,
            icon: "figure.strengthtraining.traditional",
            imageName: "fullbody"
        )
    }

    private func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }
}
