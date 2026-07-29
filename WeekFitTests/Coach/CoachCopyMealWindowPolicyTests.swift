import XCTest
@testable import WeekFit

final class CoachCopyMealWindowPolicyTests: XCTestCase {

    func testLoggedMealOpensWindowEvenWhenFuelBehindInMorning() {
        let context = makeContext(
            timeOfDay: .morning,
            fuelState: .behind,
            hasLoggedMealToday: true
        )

        XCTAssertTrue(
            CoachCopyMealWindowPolicy.isOpen(context: context, fuelState: .behind)
        )
    }

    func testEmptyMorningWithFuelBehindKeepsWindowClosed() {
        let context = makeContext(
            timeOfDay: .midday,
            fuelState: .behind,
            hasLoggedMealToday: false
        )

        XCTAssertFalse(
            CoachCopyMealWindowPolicy.isOpen(context: context, fuelState: .behind)
        )
    }

    func testLoggedMealSuppressesFirstMealAheadWhyRow() throws {
        let closedWindowInput = fastingInput(mealWindowOpen: false)
        let openWindowInput = fastingInput(mealWindowOpen: true)

        let closedPack = try XCTUnwrap(CoachCopyRegistry.resolve(closedWindowInput))
        let openPack = try XCTUnwrap(CoachCopyRegistry.resolve(openWindowInput))

        XCTAssertTrue(
            closedPack.supportingSignals.lines.contains {
                $0.english.contains("First meal is still ahead")
            }
        )
        XCTAssertFalse(
            openPack.supportingSignals.lines.contains {
                $0.english.contains("First meal is still ahead")
            }
        )
    }

    // MARK: - Helpers

    private func makeContext(
        timeOfDay: CoachTimeOfDay,
        fuelState: CoachFuelState,
        hasLoggedMealToday: Bool
    ) -> CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .idle,
            durationBand: .short,
            dayLoadBand: .fresh,
            completedSeriousActivities: .none,
            fuelState: fuelState,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: timeOfDay,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: .idle,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 80,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            lastCompletedSeriousActivityType: .none,
            hasLoggedMealToday: hasLoggedMealToday
        )
    }

    private func fastingInput(mealWindowOpen: Bool) -> CoachCopyBuildInput {
        CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: true,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .none,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: .midday,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: .normal,
            fuelState: .behind,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: .elevated,
            tomorrowWorkout: nil,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 82,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            focusSource: .idle,
            sessionPhase: .idle,
            activityState: .none,
            minutesSinceEnd: nil,
            mealWindowOpen: mealWindowOpen
        )
    }
}
