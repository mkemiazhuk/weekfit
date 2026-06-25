import XCTest
@testable import WeekFit

final class CoachDayContextBuilderTests: XCTestCase {

    private let now = CoachTestClock.reference
    private let selectedDate = CoachTestClock.reference

    func testBuildExposesOnlyConsumedFieldsForCompletedTrainingDay() {
        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: CoachTestClock.offset(hours: -4, from: now),
            durationMinutes: 120,
            completed: true
        )
        let upcomingRun = PlannedActivityBuilder.workout(
            title: "Evening Run",
            at: CoachTestClock.offset(hours: 4, from: now),
            durationMinutes: 45
        )

        let context = CoachDayContextBuilder.build(
            activities: [completedRide, upcomingRun],
            selectedDate: selectedDate,
            now: now
        )

        XCTAssertEqual(context.date, selectedDate)
        XCTAssertEqual(context.now, now)
        XCTAssertEqual(context.allActivities.count, 2)
        XCTAssertEqual(context.lastCompletedActivity?.id, completedRide.id)
        XCTAssertEqual(context.upcomingActivities.map(\.id), [upcomingRun.id])
        XCTAssertGreaterThan(context.completedActivityVolumeMinutes, 0)
        XCTAssertEqual(context.upcomingTrainingActivities.map(\.id), [upcomingRun.id])
        XCTAssertEqual(context.upcomingTrainingMinutes, 45)
        XCTAssertGreaterThan(context.upcomingTrainingStressScore, 0)
        XCTAssertTrue(context.hasMeaningfulLoadCompleted)
    }

    func testHydrationLogsAreExcludedFromCoachRelevantActivities() {
        let water = PlannedActivityBuilder.hydrationLog(at: CoachTestClock.offset(minutes: -5, from: now))

        let context = CoachDayContextBuilder.build(
            activities: [water],
            selectedDate: selectedDate,
            now: now
        )

        XCTAssertTrue(context.allActivities.isEmpty)
        XCTAssertNil(context.lastCompletedActivity)
        XCTAssertFalse(context.hasMeaningfulLoadCompleted)
        XCTAssertEqual(context.completedActivityVolumeMinutes, 0)
    }

    func testPartialTrainingCompletionCountsAsMeaningfulLoad() {
        var partial = PlannedActivityBuilder.workout(
            title: "Strength",
            at: CoachTestClock.offset(minutes: -30, from: now),
            durationMinutes: 60,
            completed: true
        )
        partial.actualDurationMinutes = 20

        let context = CoachDayContextBuilder.build(
            activities: [partial],
            selectedDate: selectedDate,
            now: now
        )

        XCTAssertTrue(context.hasMeaningfulLoadCompleted)
        XCTAssertGreaterThan(context.completedActivityVolumeMinutes, 0)
    }
}
