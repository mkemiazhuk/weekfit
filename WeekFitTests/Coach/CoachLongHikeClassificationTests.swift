import XCTest
@testable import WeekFit

final class CoachLongHikeClassificationTests: XCTestCase {

    private let colors = (r: 0.35, g: 0.55, b: 0.35)

    override func setUp() {
        super.setUp()
        CoachSessionTracker.resetForTests()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        CoachSessionTracker.resetForTests()
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testFourHourHikeIsSeriousAndElevatedLoad() {
        let hike = hikeActivity(title: "Hiking", durationMinutes: 240)
        let snapshot = CoachPlannedActivitySnapshot(from: hike)

        XCTAssertTrue(CoachActivityClassification.isHikeLike(snapshot))
        XCTAssertTrue(CoachActivityClassifier.isSeriousTraining(snapshot))
        XCTAssertTrue(CoachActivityClassifier.isElevatedTrainingLoad(snapshot))
        XCTAssertEqual(CoachActivityClassifier.coachLoad(for: snapshot), .extreme)
    }

    func testRussianHikeTitleIsDetectedAsHikeLike() {
        let hike = hikeActivity(title: "Хайкинг", durationMinutes: 240, icon: "figure.hiking")
        XCTAssertTrue(CoachActivityClassification.isHikeLike(CoachPlannedActivitySnapshot(from: hike)))
    }

    func testFourHourHikeCoachCopyIsNotEasyHike() throws {
        let now = date(hour: 9, minute: 0)
        let hikeStart = now.addingTimeInterval(30 * 60)
        let hike = hikeActivity(title: "Hiking", at: hikeStart, durationMinutes: 240)

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [hike], brainHour: 9),
            focusActivity: hike
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .walkLightDay)
        XCTAssertEqual(result.context.durationBand, .extended)
        XCTAssertTrue(result.context.isFocusHikeLike)

        let assessment = pack.assessment.lines.map(\.english).joined(separator: " ").lowercased()
        XCTAssertTrue(assessment.contains("4 hours") || assessment.contains("about 4"))
        XCTAssertTrue(
            pack.recommendation.lines.map(\.english).joined(separator: " ").lowercased()
                .contains("water") ||
            pack.recommendation.lines.map(\.english).joined(separator: " ").lowercased()
                .contains("snack")
        )
        XCTAssertFalse(assessment.contains("easy hike"))
        XCTAssertFalse(assessment.contains("twenty easy minutes"))

        let title = bridge.coachTitle.lowercased()
        XCTAssertTrue(title.contains("long hike") || title.contains("hike"))
        XCTAssertFalse(title.contains("easy hike"))
    }

    func testSixHourHikeCopyCoversPackPrepAndWhyRows() throws {
        let now = date(hour: 8, minute: 0)
        let hikeStart = now.addingTimeInterval(45 * 60)
        let hike = hikeActivity(title: "Хайкинг", at: hikeStart, durationMinutes: 360)

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [hike], brainHour: 8),
            focusActivity: hike
        )
        let pack = try XCTUnwrap(result.copyPack)

        let assessment = pack.assessment.lines.map(\.english).joined(separator: " ").lowercased()
        let recommendation = pack.recommendation.lines.map(\.english).joined(separator: " ").lowercased()
        let next = pack.nextAction.lines.map(\.english).joined(separator: " ").lowercased()
        let why = pack.supportingSignals.lines.map(\.english).joined(separator: " ").lowercased()

        XCTAssertTrue(assessment.contains("6 hours") || assessment.contains("full outing"))
        XCTAssertTrue(recommendation.contains("water"))
        XCTAssertTrue(recommendation.contains("snack") || recommendation.contains("layer"))
        XCTAssertTrue(next.contains("water") || next.contains("snack") || next.contains("layer"))
        XCTAssertTrue(
            why.contains("water") || why.contains("snack") || why.contains("turnaround")
        )
        XCTAssertFalse(assessment.contains("easy hike"))
    }

    func testShortHikeStillUsesEasyFraming() throws {
        let now = date(hour: 9, minute: 0)
        let hikeStart = now.addingTimeInterval(30 * 60)
        let hike = hikeActivity(title: "Hiking", at: hikeStart, durationMinutes: 25)

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [hike], brainHour: 9),
            focusActivity: hike
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .walkLightDay)
        let assessment = pack.assessment.lines.map(\.english).joined(separator: " ").lowercased()
        XCTAssertTrue(assessment.contains("easy hike"))
    }

    // MARK: - Helpers

    private func hikeActivity(
        title: String,
        at date: Date = CoachTestClock.reference,
        durationMinutes: Int,
        icon: String = "figure.hiking"
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "walk",
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        brainHour: Int
    ) -> CoachInputSnapshot {
        CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: brainHour)),
            plannedActivities: activities.map(CoachPlannedActivitySnapshot.init(from:)),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 120,
                exerciseMinutes: 0,
                standHours: nil,
                activityGoalCalories: 700,
                activityProgress: 0.1
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7.4),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 400,
                caloriesGoal: 2_600,
                proteinCurrent: 30,
                proteinGoal: 140,
                waterCurrent: 0.6,
                waterGoal: 2.5
            ),
            source: "CoachLongHikeClassificationTests"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? CoachTestClock.reference
    }
}
