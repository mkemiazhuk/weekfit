import XCTest
@testable import WeekFit

final class CoachDayReadinessHeavyYesterdayTests: XCTestCase {

    func testSixHourHikeYesterdayIsHeavy() {
        let today = date(2026, 8, 15, 8, 0)
        let hike = CoachPlannedActivitySnapshot(
            id: "hike",
            date: date(2026, 8, 14, 9, 0),
            type: "walk",
            title: "Hiking",
            durationMinutes: 360,
            icon: "figure.hiking",
            imageName: "",
            isCompleted: true,
            isSkipped: false,
            source: "plan"
        )
        XCTAssertTrue(
            CoachDayReadinessResolver.yesterdayPlanWasHeavy(
                activities: [hike],
                relativeTo: today
            )
        )
    }

    func testShortEasyWalkYesterdayIsNotHeavy() {
        let today = date(2026, 8, 15, 8, 0)
        let walk = CoachPlannedActivitySnapshot(
            id: "walk",
            date: date(2026, 8, 14, 18, 0),
            type: "walk",
            title: "Walk",
            durationMinutes: 25,
            icon: "figure.walk",
            imageName: "",
            isCompleted: true,
            isSkipped: false,
            source: "plan"
        )
        XCTAssertFalse(
            CoachDayReadinessResolver.yesterdayPlanWasHeavy(
                activities: [walk],
                relativeTo: today
            )
        )
    }

    func testPriorDayLoadHeavyFromExerciseMinutes() {
        let load = RecoveryPriorDayLoad(exerciseMinutes: 360, activeCalories: 500, workoutCount: 1)
        XCTAssertTrue(CoachDayReadinessResolver.isHeavyPriorDayLoad(load))
    }

    func testWalkPolicyOffersOptionalWalkAfterHeavyGoodRecovery() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .good,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: true,
            confidence: .medium,
            stronglyRejectsWalk: false
        )
        XCTAssertEqual(decision, .unselected)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return Calendar.current.date(from: comps) ?? Date()
    }
}
