import XCTest
import WeekFitPlanner
@testable import WeekFit

final class CoachSessionFocusEligibilityTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testMealIsNotSessionFocusCandidate() {
        let meal = snapshot(
            type: "meal",
            title: "Beef Buckwheat",
            hour: 19,
            duration: 15
        )
        XCTAssertTrue(CoachCanonicalDayState.isNutritionLog(meal))
        XCTAssertFalse(CoachCanonicalDayState.isCoachRelevantSnapshot(meal))
        XCTAssertFalse(CoachCanonicalDayState.isSessionFocusCandidate(meal))
        XCTAssertEqual(CoachActivityClassifier.type(for: meal), .none)
        XCTAssertEqual(CoachActivityContextResolver.kind(for: meal), .meal)
    }

    func testUnknownOtherTypeIsNotSessionFocusCandidate() {
        let mystery = snapshot(
            type: "habit",
            title: "Beef Buckwheat",
            hour: 19,
            duration: 15
        )
        XCTAssertFalse(CoachCanonicalDayState.isSessionFocusCandidate(mystery))
        XCTAssertEqual(CoachActivityClassifier.type(for: mystery), .none)
        XCTAssertEqual(CoachActivityContextResolver.kind(for: mystery), .other)
    }

    func testWorkoutIsSessionFocusCandidate() {
        let ride = snapshot(
            type: "workout",
            title: "Evening Ride",
            hour: 19,
            duration: 90
        )
        // Title-driven classification should find cycling.
        XCTAssertEqual(CoachActivityClassifier.type(for: ride), .cycling)
        XCTAssertTrue(CoachCanonicalDayState.isSessionFocusCandidate(ride))
    }

    func testFocusIgnoresDinnerHoursAwayAtMorning() {
        let now = date(hour: 9, minute: 20)
        let meal = snapshot(type: "meal", title: "Beef Buckwheat", hour: 19, duration: 15, on: now)
        let input = makeInput(now: now, activities: [meal])

        let focus = CoachFocusResolver.resolve(input: input)
        XCTAssertEqual(focus.source, .idle)
        XCTAssertEqual(focus.phase, .idle)
        XCTAssertNil(focus.activity)

        let facts = CoachMorningBriefFactsBuilder.build(
            input: input,
            context: CoachEngine.evaluate(input: input).context
        )
        XCTAssertNil(facts.nextActivity)
        XCTAssertFalse(facts.nextActivityIsImminent)

        let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)
        let teaser = CoachMorningBriefCopyPolicy.teaser(for: facts, scenario: .morningReadiness)
        let joined = [
            pack.assessment.english,
            pack.recommendation.english,
            pack.avoid.english,
            pack.nextAction.english,
            teaser.coachHeadline.english,
            teaser.todayMessage.english
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(joined.contains("beef buckwheat"))
        XCTAssertFalse(joined.contains("before session"))
        XCTAssertFalse(joined.contains("prep gear"))
        XCTAssertFalse(joined.contains("arrive 10"))
        XCTAssertFalse(joined.contains("first block:"))
        XCTAssertFalse(joined.contains("min on the plan"))
        XCTAssertFalse(joined.contains("legs still hold"))
        XCTAssertEqual(teaser.coachHeadline.english, "Morning plan")
    }

    func testMealBeforeUpcomingWorkoutStillSelectsWorkoutInPrepWindow() {
        let now = date(hour: 17, minute: 30)
        let meal = snapshot(type: "meal", title: "Beef Buckwheat", hour: 18, duration: 15, on: now)
        let ride = snapshot(type: "workout", title: "Evening Ride", hour: 19, duration: 90, on: now)
        let input = makeInput(now: now, activities: [meal, ride])

        let focus = CoachFocusResolver.resolve(input: input)
        XCTAssertEqual(focus.source, .upcoming)
        XCTAssertEqual(focus.phase, .pre)
        XCTAssertEqual(focus.activity?.title, "Evening Ride")

        let facts = CoachMorningBriefFactsBuilder.build(
            input: input,
            context: CoachEngine.evaluate(input: input).context
        )
        XCTAssertEqual(facts.nextActivity?.title, "Evening Ride")
        XCTAssertTrue(facts.nextActivityIsImminent)
        XCTAssertFalse(facts.nextActivity?.title.lowercased().contains("buckwheat") == true)
    }

    func testWorkoutSeveralHoursAwayDoesNotEnterBeforeSessionFocus() {
        let now = date(hour: 9, minute: 20)
        let ride = snapshot(type: "workout", title: "Evening Ride", hour: 19, duration: 90, on: now)
        let input = makeInput(now: now, activities: [ride])

        let focus = CoachFocusResolver.resolve(input: input)
        XCTAssertEqual(focus.source, .idle)
        XCTAssertEqual(focus.phase, .idle)

        let facts = CoachMorningBriefFactsBuilder.build(
            input: input,
            context: CoachEngine.evaluate(input: input).context
        )
        XCTAssertEqual(facts.nextActivity?.title, "Evening Ride")
        XCTAssertFalse(facts.nextActivityIsImminent)

        let teaser = CoachMorningBriefCopyPolicy.teaser(for: facts, scenario: .morningReadiness)
        XCTAssertEqual(teaser.coachHeadline.english, "Morning plan")
        XCTAssertFalse(teaser.todayMessage.english.lowercased().contains("prep from"))
    }

    func testCompletedWorkoutPlusLaterMealDoesNotTreatMealAsWorkout() {
        let now = date(hour: 14, minute: 0)
        var ride = snapshot(type: "workout", title: "Morning Ride", hour: 8, duration: 60, on: now)
        ride = CoachPlannedActivitySnapshot(
            id: ride.id,
            date: ride.date,
            type: ride.type,
            title: ride.title,
            durationMinutes: ride.durationMinutes,
            isCompleted: true,
            actualDurationMinutes: 60
        )
        let meal = snapshot(type: "meal", title: "Beef Buckwheat", hour: 19, duration: 15, on: now)
        let input = makeInput(now: now, activities: [ride, meal])

        let focus = CoachFocusResolver.resolve(input: input)
        XCTAssertNotEqual(focus.activity?.title, "Beef Buckwheat")

        let facts = CoachMorningBriefFactsBuilder.build(
            input: input,
            context: CoachEngine.evaluate(input: input).context
        )
        XCTAssertNil(facts.nextActivity)
    }

    func testBeforeSessionWindowUsesConfigurableThreshold() {
        let ride = snapshot(type: "workout", title: "Tempo Run", hour: 12, duration: 45)
        XCTAssertTrue(
            CoachActivityWindowPolicy.isWithinBeforeSessionWindow(activity: ride, minutesUntilStart: 60)
        )
        XCTAssertFalse(
            CoachActivityWindowPolicy.isWithinBeforeSessionWindow(activity: ride, minutesUntilStart: 200)
        )
        XCTAssertEqual(CoachActivityWindowPolicy.beforeSessionCopyWindowMinutes, 90)
    }

    // MARK: - Helpers

    private func snapshot(
        type: String,
        title: String,
        hour: Int,
        duration: Int,
        on day: Date? = nil
    ) -> CoachPlannedActivitySnapshot {
        let base = day ?? date(hour: 12, minute: 0)
        let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        return CoachPlannedActivitySnapshot(
            date: start,
            type: type,
            title: title,
            durationMinutes: duration
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 19
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private func makeInput(now: Date, activities: [CoachPlannedActivitySnapshot]) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = calendar.component(.hour, from: now)

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 120,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 500,
                activityProgress: 0.24
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 94, sleepHours: 7.5),
            nutritionContext: nil,
            source: "CoachSessionFocusEligibilityTests"
        )
    }
}
