import XCTest
@testable import WeekFit

final class CoachDayActivityContextXCTests: XCTestCase {

    private let now = CoachTestClock.reference
    private let selectedDate = CoachTestClock.reference

    /// a) Heat work now uses the V4 preparation window.
    func testUpcomingHeatIn15Minutes_insidePreparationWindow_isPreparing() {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 15, from: now),
            durationMinutes: 30
        )
        activity.type = "recovery"

        let context = resolve([activity])

        guard case .preparing(let focus, _, let minutes) = context.phase else {
            return XCTFail("Expected preparing phase")
        }

        XCTAssertEqual(focus.id, activity.id)
        XCTAssertEqual(minutes, 15)
        XCTAssertTrue(context.isInsidePreparationWindow)
        XCTAssertTrue(context.showsImmediateCoachFocusOnToday)
    }

    /// b) Starts inside prep window.
    func testUpcomingIn8Minutes_insidePreparationWindow_isPreparing() {
        let activity = PlannedActivityBuilder.workout(
            title: "Sauna",
            at: CoachTestClock.offset(minutes: 8, from: now),
            durationMinutes: 30
        )
        activity.type = "recovery"

        let context = resolve([activity])

        guard case .preparing(let focus, _, let minutes) = context.phase else {
            return XCTFail("Expected preparing phase")
        }

        XCTAssertEqual(focus.id, activity.id)
        XCTAssertEqual(minutes, 8)
        XCTAssertTrue(context.isInsidePreparationWindow)
        XCTAssertTrue(context.showsImmediateCoachFocusOnToday)
    }

    /// c) Active session with a later activity — Up Next must not duplicate active.
    func testActiveWithNextActivity_upNextSkipsActive() {
        let active = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -10, from: now),
            durationMinutes: 60
        )

        let next = PlannedActivityBuilder.workout(
            title: "Evening Run",
            at: CoachTestClock.offset(minutes: 90, from: now),
            durationMinutes: 45
        )

        let context = resolve([active, next])

        guard case .active(let focus, _) = context.phase else {
            return XCTFail("Expected active phase")
        }

        XCTAssertEqual(focus.id, active.id)
        XCTAssertEqual(context.nextUpcomingActivity?.id, next.id)
        XCTAssertTrue(context.activeActivityIdentityIsCertain)
        XCTAssertEqual(context.activeSessionPhase, .middle)
    }

    func testQuickActionActiveWinsOverOverlappingPlannedActivity() {
        let planned = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -15, from: now),
            durationMinutes: 60
        )

        let quickStarted = PlannedActivityBuilder.workout(
            title: "Recovery Ride",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 30
        )
        quickStarted.source = "today"

        let context = resolve([planned, quickStarted])

        XCTAssertEqual(context.activeActivity?.id, quickStarted.id)
        XCTAssertTrue(context.activeActivityIdentityIsCertain)
    }

    func testOverlappingPlannedActiveActivitiesMarkIdentityUncertain() {
        let strength = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -15, from: now),
            durationMinutes: 60
        )

        let ride = PlannedActivityBuilder.workout(
            title: "Endurance Ride",
            at: CoachTestClock.offset(minutes: -5, from: now),
            durationMinutes: 60
        )

        let context = resolve([strength, ride])

        XCTAssertNotNil(context.activeActivity)
        XCTAssertFalse(context.activeActivityIdentityIsCertain)
    }

    /// d) Recently completed inside post-completion window.
    func testRecentlyCompleted_insidePostWindow_isRecovering() {
        let completed = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: CoachTestClock.offset(minutes: -55, from: now),
            durationMinutes: 45,
            completed: true
        )

        let context = resolve([completed])

        guard case .recovering(let focus, _, _) = context.phase else {
            return XCTFail("Expected recovering phase")
        }

        XCTAssertEqual(focus.id, completed.id)
    }

    /// e) Recently completed outside post-completion window.
    func testRecentlyCompleted_outsidePostWindow_isStable() {
        let completed = PlannedActivityBuilder.workout(
            title: "Easy Walk",
            at: CoachTestClock.offset(minutes: -90, from: now),
            durationMinutes: 30,
            completed: true
        )

        let context = resolve([completed])

        XCTAssertTrue(context.phase.isStable)
    }

    /// f) No activities today.
    func testNoActivitiesToday_isStableWithOverviewCopy() {
        let context = resolve([])

        XCTAssertTrue(context.phase.isStable)
        XCTAssertNil(context.nextUpcomingActivity)

        let copy = CoachActivityContextResolverV3.stablePresentation(from: context)
        XCTAssertTrue(copy.message.contains("open") || copy.title.contains("overview"))
    }

    func testHydrationLogsAreNotCoachActivities() {
        let completedWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: -10, from: now)
        )
        let futureWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: 30, from: now)
        )
        futureWater.isCompleted = false

        let context = resolve([completedWater, futureWater])

        XCTAssertTrue(context.phase.isStable)
        XCTAssertNil(context.activeActivity)
        XCTAssertNil(context.preparingActivity)
        XCTAssertNil(context.recentlyCompletedActivity)
        XCTAssertNil(context.nextUpcomingActivity)
        XCTAssertNil(context.laterTodayActivity)
    }

    func testNutritionLogsAreNotCoachActivities() {
        let plannedMeal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: CoachTestClock.offset(minutes: 30, from: now),
            completed: false
        )
        let coffee = PlannedActivityBuilder.meal(
            title: "Coffee",
            at: CoachTestClock.offset(minutes: -10, from: now),
            calories: 5,
            protein: 0,
            carbs: 0,
            fats: 0,
            completed: true
        )
        let futureWater = PlannedActivityBuilder.hydrationLog(
            at: CoachTestClock.offset(minutes: 10, from: now)
        )
        futureWater.isCompleted = false

        let context = resolve([coffee, futureWater, plannedMeal])

        XCTAssertTrue(context.phase.isStable)
        XCTAssertNil(context.activeActivity)
        XCTAssertNil(context.preparingActivity)
        XCTAssertNil(context.recentlyCompletedActivity)
        XCTAssertNil(context.nextUpcomingActivity)
        XCTAssertNil(context.laterTodayActivity)
        XCTAssertTrue(CoachCanonicalDayState.coachRelevantActivities(from: [coffee, futureWater, plannedMeal]).isEmpty)
    }

    /// g) Later activity today but not immediate coach focus.
    func testLaterActivityToday_stableAvoidsScheduleDuplication() {
        let later = PlannedActivityBuilder.workout(
            title: "Evening Strength",
            at: CoachTestClock.offset(minutes: 180, from: now),
            durationMinutes: 60
        )

        let context = resolve([later])

        XCTAssertTrue(context.phase.isStable)
        XCTAssertFalse(context.showsImmediateCoachFocusOnToday)
        XCTAssertNotNil(context.laterTodayActivity)

        let copy = CoachActivityContextResolverV3.stablePresentation(from: context)
        XCTAssertFalse(copy.title.contains("Evening Strength"))
        XCTAssertFalse(copy.message.contains("Evening Strength"))
        XCTAssertFalse(copy.title.localizedCaseInsensitiveContains("next up"))
        XCTAssertTrue(copy.message.localizedCaseInsensitiveContains("preparation") || copy.message.localizedCaseInsensitiveContains("steady"))
    }

    func testSubtitle_avoidsRecoveryBlockDuplication() {
        let stretch = PlannedActivityBuilder.workout(
            title: "Recovery stretch",
            at: now,
            durationMinutes: 20
        )
        stretch.type = "recovery"

        XCTAssertEqual(CoachActivitySubtitle.displaySubtitle(for: stretch), "Mobility reset")
    }

    private func resolve(_ activities: [PlannedActivity]) -> CoachDayActivityContext {
        CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
    }
}

private extension CoachActivityPhaseV3 {
    var isStable: Bool {
        if case .stable = self {
            return true
        }
        return false
    }
}
