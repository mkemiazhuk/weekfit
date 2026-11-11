import XCTest
@testable import WeekFit

final class ReturnReminderPlannerTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    func testDay7RepeatsWalkWhenAWalkWasCompleted() {
        let offer = ReturnReminderPlanner.day7(
            completions: [
                completion(.breathing, at: anchor),
                completion(.walk, at: anchor.addingTimeInterval(60))
            ],
            goal: .unavailable
        )
        XCTAssertEqual(offer.actionID, ReturnReminderPlanner.walkID)
        XCTAssertEqual(offer.kind, .repeatAction)
        XCTAssertEqual(offer.horizon, .day7)
    }

    func testDay7RepeatsLastDirectActionWhenThereWasNoWalk() {
        let offer = ReturnReminderPlanner.day7(
            completions: [
                completion(.stretching, at: anchor, opensDirectly: false),
                completion(.breathing, at: anchor.addingTimeInterval(120))
            ],
            goal: .fatLoss
        )
        XCTAssertEqual(offer.actionID, ReturnReminderPlanner.breathingID)
        XCTAssertEqual(offer.kind, .repeatAction)
    }

    func testDay7UsesRecoveryGoalWhenNothingWasCompleted() {
        let offer = ReturnReminderPlanner.day7(completions: [], goal: .recovery)
        XCTAssertEqual(offer.actionID, ReturnReminderPlanner.breathingID)
        XCTAssertEqual(offer.kind, .firstAction)
    }

    func testDay7OffersAMealForNutritionGoalsWhenTheFormCanOpen() {
        for goal in [ReturnReminderGoal.fatLoss, .maintenance, .muscleGain] {
            let offer = ReturnReminderPlanner.day7(
                completions: [],
                goal: goal,
                foodLogAvailable: true
            )
            XCTAssertEqual(offer.actionID, ReturnReminderPlanner.mealID)
            XCTAssertEqual(offer.kind, .firstAction)
        }
    }

    func testDay7FallsBackToWalkWhenTheFoodFormCannotOpen() {
        let blocked = ReturnReminderPlanner.day7(
            completions: [],
            goal: .fatLoss,
            foodLogAvailable: false
        )
        XCTAssertEqual(blocked.actionID, ReturnReminderPlanner.walkID)
        XCTAssertEqual(blocked.kind, .firstAction)

        let missing = ReturnReminderPlanner.day7(
            completions: [],
            goal: .unavailable,
            foodLogAvailable: true
        )
        XCTAssertEqual(missing.actionID, ReturnReminderPlanner.walkID)
        XCTAssertFalse(
            ReturnReminderFoodLog.canOpenDirectly(
                onboardingComplete: false,
                blockingCoverVisible: false
            )
        )
        XCTAssertFalse(
            ReturnReminderFoodLog.canOpenDirectly(
                onboardingComplete: true,
                blockingCoverVisible: true
            )
        )
    }

    func testDay14ExcludesTheMealEvenWhenItWasNeverLogged() {
        let plan = ReturnReminderPlanner.plan(
            now: anchor,
            anchor: anchor,
            isNewReturn: true,
            existing: nil,
            completions: [],
            awards: sampleAwards(),
            goal: .maintenance,
            foodLogAvailable: true,
            enabled: true,
            notificationsAuthorized: true,
            calendar: calendar
        )
        XCTAssertEqual(plan.series.day7.actionID, ReturnReminderPlanner.mealID)
        XCTAssertNotEqual(plan.series.day14?.actionID, ReturnReminderPlanner.mealID)
        XCTAssertEqual(plan.series.day14?.actionID, ReturnReminderPlanner.walkID)
        XCTAssertEqual(plan.series.day14?.kind, .newActivityAward)
    }

    func testWinterSkipsCyclingButKeepsAWalk() {
        let winter = ReturnReminderWeather(isWinter: true)
        let offer = ReturnReminderPlanner.day14(
            completions: [completion(.walk, at: anchor), completion(.breathing, at: anchor)],
            awards: [
                award(ReturnReminderPlanner.cyclingID, opensDirectly: false, unlocked: []),
                award(ReturnReminderPlanner.stretchingID, opensDirectly: false, unlocked: [])
            ],
            excluding: ReturnReminderPlanner.walkID,
            weather: winter
        )
        XCTAssertEqual(offer?.actionID, ReturnReminderPlanner.stretchingID)
        XCTAssertFalse(winter.blocksExposedOutdoor)

        var winterParts = DateComponents(year: 2026, month: 1, day: 15)
        let january = calendar.date(from: winterParts)!
        let dryWinter = ReturnReminderWeatherResolver.make(
            summary: weather(temp: 4, feels: 2, condition: .clear, precip: 0),
            now: january,
            calendar: calendar
        )
        XCTAssertTrue(dryWinter.isWinter)
        XCTAssertTrue(dryWinter.blocksCycling)
        XCTAssertFalse(dryWinter.blocksExposedOutdoor)

        let summer = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 15))!
        let mild = ReturnReminderWeatherResolver.make(
            summary: weather(temp: 18, feels: 18, condition: .clear, precip: 0),
            now: summer,
            calendar: calendar
        )
        XCTAssertFalse(mild.blocksCycling)
        let ride = ReturnReminderPlanner.day14(
            completions: [completion(.walk, at: anchor), completion(.breathing, at: anchor)],
            awards: [award(ReturnReminderPlanner.cyclingID, opensDirectly: false, unlocked: [])],
            excluding: ReturnReminderPlanner.walkID,
            weather: mild
        )
        XCTAssertEqual(ride?.actionID, ReturnReminderPlanner.cyclingID)
    }

    func testNovemberEveningAtFourDegreesSkipsCyclingButKeepsAWalk() {
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 19))!
        let weather = ReturnReminderWeatherResolver.make(
            summary: weather(temp: 4, feels: 2, condition: .clear, precip: 0),
            now: evening,
            calendar: calendar
        )
        XCTAssertTrue(weather.isColdSeason)
        XCTAssertTrue(weather.isChilly)
        XCTAssertTrue(weather.isEvening)
        XCTAssertTrue(weather.blocksCycling)
        XCTAssertFalse(weather.blocksExposedOutdoor)

        let day7 = ReturnReminderPlanner.day7(
            completions: [completion(.walk, at: anchor)],
            goal: .unavailable,
            weather: weather
        )
        XCTAssertEqual(day7.actionID, ReturnReminderPlanner.walkID)

        let day14 = ReturnReminderPlanner.day14(
            completions: [completion(.walk, at: anchor), completion(.breathing, at: anchor)],
            awards: [
                award(ReturnReminderPlanner.cyclingID, opensDirectly: false, unlocked: []),
                award(ReturnReminderPlanner.stretchingID, opensDirectly: false, unlocked: [])
            ],
            excluding: day7.actionID,
            weather: weather
        )
        XCTAssertEqual(day14?.actionID, ReturnReminderPlanner.stretchingID)
        XCTAssertNotEqual(day14?.actionID, ReturnReminderPlanner.cyclingID)
    }

    func testFreezingRainInvitesBreathingInsteadOfAWalkOrRide() {
        let weather = ReturnReminderWeather(isVeryCold: true, isRaining: true)
        let day7 = ReturnReminderPlanner.day7(
            completions: [completion(.walk, at: anchor)],
            goal: .unavailable,
            weather: weather
        )
        XCTAssertEqual(day7.actionID, ReturnReminderPlanner.breathingID)
        XCTAssertEqual(day7.kind, .firstAction)

        let day14 = ReturnReminderPlanner.day14(
            completions: [],
            awards: [
                award(ReturnReminderPlanner.cyclingID, opensDirectly: false, unlocked: []),
                award(ReturnReminderPlanner.walkID, opensDirectly: true, unlocked: []),
                award("activity.upper-body", opensDirectly: false, unlocked: [])
            ],
            excluding: ReturnReminderPlanner.breathingID,
            weather: weather
        )
        XCTAssertEqual(day14?.actionID, "activity.upper-body")
    }

    func testOpenAppDoesNotRegisterReturnReminders() {
        XCTAssertFalse(ReturnReminderRegistration.shouldRegister(isForeground: true))
        XCTAssertTrue(ReturnReminderRegistration.shouldRegister(isForeground: false))
    }

    func testShortIntervalsStayOffUntilTheDebugAppEnablesThem() {
        XCTAssertFalse(ReturnReminderTiming.usesShortIntervals)
        ReturnReminderTiming.usesShortIntervals = true
        defer { ReturnReminderTiming.usesShortIntervals = false }
        let plan = self.plan(now: anchor, isNewReturn: true, existing: nil, completions: [])
        XCTAssertEqual(
            plan.notifications.map(\.fireAt),
            [
                calendar.date(byAdding: .minute, value: 1, to: anchor),
                calendar.date(byAdding: .minute, value: 3, to: anchor)
            ]
        )
    }

    func testDay14ChoosesADifferentUnopenedActivityAndSkipsWhenNoneRemain() {
        let excludingWalk = ReturnReminderPlanner.day14(
            completions: [],
            awards: sampleAwards(),
            excluding: ReturnReminderPlanner.walkID
        )
        XCTAssertEqual(excludingWalk?.actionID, ReturnReminderPlanner.breathingID)
        XCTAssertEqual(excludingWalk?.kind, .newActivityAward)
        XCTAssertNotEqual(excludingWalk?.actionID, ReturnReminderPlanner.walkID)

        let excludingBreathing = ReturnReminderPlanner.day14(
            completions: [completion(.breathing, at: anchor)],
            awards: sampleAwards(unlocked: [ReturnReminderPlanner.breathingID]),
            excluding: ReturnReminderPlanner.breathingID
        )
        XCTAssertEqual(excludingBreathing?.actionID, ReturnReminderPlanner.walkID)

        let none = ReturnReminderPlanner.day14(
            completions: [],
            awards: sampleAwards(unlocked: [
                ReturnReminderPlanner.walkID,
                ReturnReminderPlanner.breathingID,
                ReturnReminderPlanner.stretchingID
            ]),
            excluding: ReturnReminderPlanner.walkID
        )
        XCTAssertNil(none)
    }

    func testReturnCancelsThePreviousSeriesAndFrozenChoiceDoesNotChange() {
        ReturnReminderTiming.usesShortIntervals = false
        let first = plan(now: anchor, isNewReturn: true, existing: nil, completions: [])
        XCTAssertEqual(first.cancelIdentifiers, ReturnReminderPlanner.identifiers)
        XCTAssertEqual(first.notifications.map(\.identifier), [
            ReturnReminderHorizon.day7.notificationIdentifier,
            ReturnReminderHorizon.day14.notificationIdentifier
        ])
        XCTAssertEqual(
            first.notifications.map(\.fireAt),
            [
                calendar.date(byAdding: .day, value: 7, to: anchor),
                calendar.date(byAdding: .day, value: 14, to: anchor)
            ]
        )
        XCTAssertEqual(first.series.day7.actionID, ReturnReminderPlanner.walkID)
        XCTAssertEqual(first.series.day14?.actionID, ReturnReminderPlanner.breathingID)

        var frozen = first.series
        frozen.frozen = true
        let unchanged = plan(
            now: anchor.addingTimeInterval(3_600),
            isNewReturn: false,
            existing: frozen,
            completions: [completion(.breathing, at: anchor)]
        )
        XCTAssertEqual(unchanged.series.day7, frozen.day7)
        XCTAssertEqual(unchanged.series.day14, frozen.day14)

        let returned = plan(
            now: calendar.date(byAdding: .day, value: 8, to: anchor)!,
            isNewReturn: true,
            existing: frozen,
            completions: []
        )
        XCTAssertEqual(returned.series.anchor, calendar.date(byAdding: .day, value: 8, to: anchor))
        XCTAssertEqual(returned.cancelIdentifiers, ReturnReminderPlanner.identifiers)
        XCTAssertNotEqual(returned.series.day14?.actionID, returned.series.day7.actionID)
    }

    func testDisabledRemindersScheduleNothing() {
        let plan = ReturnReminderPlanner.plan(
            now: anchor,
            anchor: anchor,
            isNewReturn: true,
            existing: nil,
            completions: [],
            awards: sampleAwards(),
            goal: .unavailable,
            enabled: false,
            notificationsAuthorized: true,
            calendar: calendar
        )
        XCTAssertTrue(plan.notifications.isEmpty)
        XCTAssertEqual(plan.cancelIdentifiers, ReturnReminderPlanner.identifiers)
    }

    private func plan(
        now: Date,
        isNewReturn: Bool,
        existing: ReturnReminderSeries?,
        completions: [ReturnReminderCompletion]
    ) -> ReturnReminderPlan {
        ReturnReminderPlanner.plan(
            now: now,
            anchor: isNewReturn ? now : anchor,
            isNewReturn: isNewReturn,
            existing: existing,
            completions: completions,
            awards: sampleAwards(),
            goal: .unavailable,
            enabled: true,
            notificationsAuthorized: true,
            calendar: calendar
        )
    }

    private enum Sample {
        case walk, breathing, stretching
    }

    private func completion(
        _ sample: Sample,
        at date: Date,
        opensDirectly: Bool? = nil
    ) -> ReturnReminderCompletion {
        switch sample {
        case .walk:
            return ReturnReminderCompletion(
                actionID: ReturnReminderPlanner.walkID,
                completedAt: date,
                opensDirectly: opensDirectly ?? true
            )
        case .breathing:
            return ReturnReminderCompletion(
                actionID: ReturnReminderPlanner.breathingID,
                completedAt: date,
                opensDirectly: opensDirectly ?? true
            )
        case .stretching:
            return ReturnReminderCompletion(
                actionID: ReturnReminderPlanner.stretchingID,
                completedAt: date,
                opensDirectly: opensDirectly ?? false
            )
        }
    }

    private func sampleAwards(unlocked: Set<String> = []) -> [ReturnReminderAward] {
        [
            award(ReturnReminderPlanner.walkID, opensDirectly: true, unlocked: unlocked),
            award(ReturnReminderPlanner.breathingID, opensDirectly: true, unlocked: unlocked),
            award(ReturnReminderPlanner.stretchingID, opensDirectly: false, unlocked: unlocked)
        ]
    }

    private func award(_ id: String, opensDirectly: Bool, unlocked: Set<String>) -> ReturnReminderAward {
        ReturnReminderAward(
            actionID: id,
            opensDirectly: opensDirectly,
            hasPrepScreen: true,
            unlocked: unlocked.contains(id)
        )
    }
}

private extension ReturnReminderPlanner {
    static let stretchingID = "recovery.stretching"
}

private func weather(
    temp: Double,
    feels: Double,
    condition: WeekFitWeatherCondition,
    precip: Int
) -> WeekFitWeatherSummary {
    WeekFitWeatherSummary(
        temperature: Measurement(value: temp, unit: .celsius),
        feelsLike: Measurement(value: feels, unit: .celsius),
        highTemperature: nil,
        lowTemperature: nil,
        symbolName: "cloud",
        condition: condition,
        isDaylight: true,
        humidityPercent: 50,
        windSpeed: Measurement(value: 10, unit: .kilometersPerHour),
        uvIndex: 1,
        precipitationChance: precip,
        visibilityKilometers: 10,
        sunrise: nil,
        sunset: nil,
        placeName: nil
    )
}
