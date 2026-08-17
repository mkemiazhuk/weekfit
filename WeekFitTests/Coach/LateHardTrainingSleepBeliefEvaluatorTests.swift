import XCTest
@testable import WeekFit

final class LateHardTrainingSleepBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenLateHardSessionsShortenNextNightSleep() {
        let observations = LateHardTrainingSleepFixtures.observationsWithSleepDrop()

        let evaluation = LateHardTrainingSleepBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.sleepDropMinutes ?? 0, 35)

        let result = LateHardTrainingSleepBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .lateHardTrainingSleep)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testInsufficientLateAnchorsRemainWatching() {
        let result = LateHardTrainingSleepBeliefEvaluator.evaluate(
            observations: LateHardTrainingSleepFixtures.observationsWithoutLateHardSessions(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum LateHardTrainingSleepFixtures {

    static func observationsWithSleepDrop() -> [CoachDailyObservation] {
        // Alternating earlier hard (17:00) → long next sleep, late hard (21:00) → short next sleep.
        var configs: [(band: CoachWorkoutIntensityBand, end: Int?, sleep: Int)] = []
        for _ in 0..<5 {
            configs.append((.hard, 17 * 60, 420))
            configs.append((.rest, nil, 480)) // next-night sleep after earlier hard
            configs.append((.hard, 21 * 60, 420))
            configs.append((.rest, nil, 400)) // shorter next-night sleep after late hard
        }
        return build(configs: configs)
    }

    static func observationsWithoutLateHardSessions() -> [CoachDailyObservation] {
        var configs: [(band: CoachWorkoutIntensityBand, end: Int?, sleep: Int)] = []
        for _ in 0..<8 {
            configs.append((.hard, 17 * 60, 420))
            configs.append((.rest, nil, 470))
        }
        return build(configs: configs)
    }

    private static func build(
        configs: [(band: CoachWorkoutIntensityBand, end: Int?, sleep: Int)]
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        return configs.enumerated().compactMap { index, config in
            guard let date = calendar.date(byAdding: .day, value: -(configs.count - index), to: anchor) else {
                return nil
            }
            let isHard = config.band == .hard
            return CoachDailyObservation(
                dayKey: CoachDailyObservation.dayKey(for: date),
                sleepMinutes: config.sleep,
                recoveryPercent: 75,
                bedStartNormalizedMinutes: 1_380,
                exerciseMinutes: isHard ? 70 : 20,
                activeCalories: isHard ? 600 : 180,
                workoutCount: 1,
                workoutTypes: isHard ? ["strength"] : ["walking"],
                hardWorkoutCount: isHard ? 1 : 0,
                workoutIntensityBand: config.band,
                hadHardTraining: isHard,
                hadRecoveryActivity: !isHard,
                hadRestDay: config.band == .rest,
                trainingLoadScore: isHard ? 80 : 25,
                hardestWorkoutEndMinutes: config.end,
                proteinGrams: 120,
                carbsGrams: 200,
                fatGrams: 60,
                caloriesEaten: 2_200,
                calorieDeficit: 100,
                hydrationLiters: 2.2,
                mealsLoggedCount: 3,
                hasPopulatedNutritionFields: true,
                nutritionCompleteness: .complete,
                nutritionSource: .plannedMeals
            )
        }
    }
}
