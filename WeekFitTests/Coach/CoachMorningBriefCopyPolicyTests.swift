import XCTest
import WeekFitPlanner
@testable import WeekFit

final class CoachMorningBriefCopyPolicyTests: XCTestCase {

    func testMorningReadinessIncludesSleepRecoveryAndInstruction() throws {
        let facts = CoachMorningBriefFactsBuilder.synthetic(
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 82,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            )
        )
        let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)

        let assessment = pack.assessment.english.lowercased()
        XCTAssertTrue(assessment.contains("morning"))
        XCTAssertTrue(assessment.contains("7h 30m") || assessment.contains("7h"))
        XCTAssertTrue(assessment.contains("82"))

        let nextAction = pack.nextAction.english.lowercased()
        XCTAssertTrue(
            nextAction.contains("walk") ||
                nextAction.contains("stretch") ||
                nextAction.contains("block")
        )
    }

    func testHeavyYesterdayAssessmentInterpolatesRussianSleepAndRecovery() {
        let facts = CoachMorningBriefFacts(
            recoveryDataAvailable: true,
            sleepHours: 6.0,
            recoveryPercent: 58,
            recoveryBand: .moderate,
            sleepIsLow: false,
            hadHeavyYesterday: true,
            nextActivity: nil,
            todayActivityCount: 0,
            seriousActivityCount: 0,
            tomorrowWorkout: nil,
            minutesUntilNextActivity: nil,
            nextActivityIsImminent: false
        )
        let text = CoachMorningBriefCopyPolicy.recoveryAfterHeavyYesterdayAssessment(for: facts)
        XCTAssertFalse(text.russian.contains("\\("), text.russian)
        XCTAssertTrue(text.russian.contains("58"), text.russian)
        XCTAssertTrue(text.russian.contains("сон"), text.russian)
        XCTAssertFalse(text.english.lowercased().contains("legs"), text.english)
    }

    func testProtectTomorrowFreshLocalizesLongRunTitleInRussian() {
        let facts = CoachMorningBriefFacts(
            recoveryDataAvailable: true,
            sleepHours: 8.0,
            recoveryPercent: 90,
            recoveryBand: .good,
            sleepIsLow: false,
            hadHeavyYesterday: false,
            nextActivity: nil,
            todayActivityCount: 0,
            seriousActivityCount: 0,
            tomorrowWorkout: CoachTomorrowWorkout(
                title: "Long Run",
                startHour: 7,
                startMinute: 0,
                durationMinutes: 90
            ),
            minutesUntilNextActivity: nil,
            nextActivityIsImminent: false
        )
        let text = CoachMorningBriefCopyPolicy.protectTomorrowFreshAssessment(
            facts: facts,
            tomorrowWorkout: facts.tomorrowWorkout
        )
        XCTAssertTrue(text.english.contains("Long Run"), text.english)
        XCTAssertTrue(text.russian.lowercased().contains("длинный бег"), text.russian)
        XCTAssertFalse(text.russian.lowercased().contains("long"), text.russian)
    }

    func testMorningReadinessWithPlannedRideGivesConcreteNextAction() {
        let facts = CoachMorningBriefFacts(
            recoveryDataAvailable: true,
            sleepHours: 7.5,
            recoveryPercent: 82,
            recoveryBand: .good,
            sleepIsLow: false,
            hadHeavyYesterday: false,
            nextActivity: CoachPlannedActivitySummary(
                title: "Morning Ride",
                startHour: 10,
                startMinute: 30,
                durationMinutes: 90,
                activityType: .cycling
            ),
            todayActivityCount: 1,
            seriousActivityCount: 1,
            tomorrowWorkout: nil,
            minutesUntilNextActivity: 40,
            nextActivityIsImminent: true
        )
        let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)

        XCTAssertTrue(pack.assessment.english.contains("Morning Ride"))
        XCTAssertTrue(pack.assessment.english.contains("10:30"))
        XCTAssertTrue(
            pack.nextAction.english.lowercased().contains("breakfast") ||
                pack.nextAction.english.lowercased().contains("warmup")
        )
    }

    func testFarAwayRideDoesNotUseBeforeSessionOrGearPrep() {
        let facts = CoachMorningBriefFacts(
            recoveryDataAvailable: true,
            sleepHours: 7.5,
            recoveryPercent: 82,
            recoveryBand: .good,
            sleepIsLow: false,
            hadHeavyYesterday: false,
            nextActivity: CoachPlannedActivitySummary(
                title: "Evening Ride",
                startHour: 19,
                startMinute: 0,
                durationMinutes: 90,
                activityType: .cycling
            ),
            todayActivityCount: 1,
            seriousActivityCount: 1,
            tomorrowWorkout: nil,
            minutesUntilNextActivity: 580,
            nextActivityIsImminent: false
        )
        let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)
        let teaser = CoachMorningBriefCopyPolicy.teaser(for: facts, scenario: .morningReadiness)

        XCTAssertFalse(teaser.coachHeadline.english.lowercased().contains("before"))
        XCTAssertFalse(pack.nextAction.english.lowercased().contains("gear"))
        XCTAssertFalse(pack.recommendation.english.lowercased().contains("first block"))
        XCTAssertTrue(pack.assessment.english.contains("Later today"))
    }

    func testEngineMorningIdleCopyIsInstructional() throws {
        CoachSessionTracker.resetForTests()
        defer { CoachSessionTracker.resetForTests() }

        let morning = date(hour: 7, minute: 30)
        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], brainHour: 7)
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .morningReadiness)
        XCTAssertTrue(pack.assessment.lines.first?.english.lowercased().contains("morning") == true)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("82") == true)
        XCTAssertFalse(bridge.todayMessage.lowercased().contains("слушайте тело"))
        XCTAssertFalse(pack.recommendation.lines.first?.english.lowercased().contains("feel") == true)
    }

    func testTeaserUsesMorningGreetingWithoutDuplicateStats() throws {
        CoachSessionTracker.resetForTests()
        defer { CoachSessionTracker.resetForTests() }

        let morning = date(hour: 7, minute: 30)
        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], brainHour: 7)
        )
        let teaser = CoachTeaserCopy.resolve(from: result, localizedAssessment: "")

        XCTAssertEqual(teaser.todayTitle.english, "Good morning")
        XCTAssertEqual(teaser.todayTitle.russian, "Доброе утро")
        XCTAssertFalse(teaser.todayTitle.english.contains("%"))
    }

    // MARK: - Helpers

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        brainHour: Int
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_800,
                proteinCurrent: 0,
                proteinGoal: 140,
                waterCurrent: 0,
                waterGoal: 2.5
            ),
            source: "CoachMorningBriefCopyPolicyTests"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
