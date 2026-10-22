import XCTest
@testable import WeekFit

final class PlanAddPreferenceTests: XCTestCase {

    func testTypeOrderStartsWithRecovery() {
        XCTAssertEqual(
            PlanAddPreference.typeOrder,
            [.recovery, .workout, .meal, .habit]
        )
    }

    func testNoHistoryPrefersRecovery() {
        XCTAssertEqual(PlanAddPreference.preferredType([]), .recovery)
    }

    func testMostUsedTypeWinsTiesBySheetOrder() {
        let samples = [
            sample(.meal, title: "Oats", minute: 8 * 60),
            sample(.meal, title: "Oats", minute: 8 * 60),
            sample(.workout, title: "Running", minute: 7 * 60),
            sample(.recovery, title: "Walk", minute: 18 * 60)
        ]
        XCTAssertEqual(PlanAddPreference.preferredType(samples), .meal)

        let tied = [
            sample(.habit, title: "Drink Water", minute: 9 * 60),
            sample(.recovery, title: "Walk", minute: 18 * 60)
        ]
        XCTAssertEqual(PlanAddPreference.preferredType(tied), .recovery)
    }

    func testMostUsedOptionLeadsTheCatalog() {
        let samples = [
            sample(.recovery, title: "Walk", imageName: "recovery-walk", minute: 18 * 60, duration: 25),
            sample(.recovery, title: "Walk", imageName: "recovery-walk", minute: 18 * 60 + 10, duration: 25),
            sample(.recovery, title: "Yoga", imageName: "recovery-yoga", minute: 7 * 60, duration: 20)
        ]
        let ranked = PlanAddPreference.rankedOptions(
            PlannerType.recovery.options,
            type: .recovery,
            samples: samples
        )
        XCTAssertEqual(ranked.first?.title, "Walk")
        XCTAssertEqual(ranked.last?.title, PlannerType.recovery.options.last?.title)
    }

    func testHabitUsesMedianClockRoundedToQuarterHourAndMedianDuration() {
        let samples = [
            sample(.recovery, title: "Walk", minute: 18 * 60, duration: 20),
            sample(.recovery, title: "Walk", minute: 18 * 60 + 10, duration: 25),
            sample(.recovery, title: "Walk", minute: 18 * 60 + 20, duration: 30)
        ]
        let habit = PlanAddPreference.habit(
            type: .recovery,
            title: "Walk",
            imageName: "recovery-walk",
            samples: samples
        )
        XCTAssertEqual(habit?.minuteOfDay, 18 * 60 + 15)
        XCTAssertEqual(habit?.durationMinutes, 25)
    }

    func testUnknownActivityHasNoHabit() {
        XCTAssertNil(
            PlanAddPreference.habit(
                type: .workout,
                title: "Tennis",
                imageName: "workout-tennis",
                samples: [sample(.workout, title: "Running", minute: 7 * 60)]
            )
        )
    }

    func testImageNameCountsEvenWhenTitleDiffers() {
        let samples = [
            sample(.recovery, title: "Evening walk", imageName: "recovery-walk", minute: 18 * 60),
            sample(.recovery, title: "Evening walk", imageName: "recovery-walk", minute: 18 * 60)
        ]
        let ranked = PlanAddPreference.rankedOptions(
            PlannerType.recovery.options,
            type: .recovery,
            samples: samples
        )
        XCTAssertEqual(ranked.first?.title, "Walk")
    }

    func testSamplesUseTheLastMonthNotOnlyToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        let today = activity(title: "Walk", imageName: "recovery-walk", on: now)
        let withinMonth = activity(
            title: "Running",
            imageName: "workout-running",
            on: calendar.date(byAdding: .day, value: -12, to: now)!
        )
        let older = activity(
            title: "Yoga",
            imageName: "recovery-yoga",
            on: calendar.date(byAdding: .day, value: -45, to: now)!
        )

        let samples = PlanAddPreference.samples(
            from: [today, withinMonth, older],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(Set(samples.map(\.title)), ["Walk", "Running"])
    }

    func testStoredWorkoutImageMapsToWorkout() {
        XCTAssertEqual(
            PlanAddPreference.plannerType(
                storedType: "training",
                title: "Morning run",
                imageName: "workout-running"
            ),
            .workout
        )
        XCTAssertEqual(
            PlanAddPreference.plannerType(storedType: "Meal", title: "Oats", imageName: ""),
            .meal
        )
    }

    private func activity(
        title: String,
        imageName: String,
        on date: Date
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "workout",
            title: title,
            durationMinutes: 30,
            icon: "figure.run",
            imageName: imageName,
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.8
        )
    }

    private func sample(
        _ type: PlannerType,
        title: String,
        imageName: String = "",
        minute: Int,
        duration: Int = 20
    ) -> PlanAddPreference.Sample {
        PlanAddPreference.Sample(
            type: type,
            title: title,
            imageName: imageName,
            minuteOfDay: minute,
            durationMinutes: duration
        )
    }
}
