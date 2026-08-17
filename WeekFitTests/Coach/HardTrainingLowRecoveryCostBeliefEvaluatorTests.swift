import XCTest
@testable import WeekFit

final class HardTrainingLowRecoveryCostBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenHardTrainingWhileDepletedCostsNextDayRecovery() {
        let observations = HardTrainingLowRecoveryCostFixtures.observationsWithRecoveryCost()

        let evaluation = HardTrainingLowRecoveryCostBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryCost ?? 0, 8)

        let result = HardTrainingLowRecoveryCostBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .hardTrainingLowRecoveryCost)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenPatternRemainsStable() {
        let emerging = HardTrainingLowRecoveryCostBeliefEvaluator.evaluate(
            observations: HardTrainingLowRecoveryCostFixtures.observationsWithRecoveryCost(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = HardTrainingLowRecoveryCostBeliefEvaluator.evaluate(
            observations: HardTrainingLowRecoveryCostFixtures.observationsWithStableCost(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientDataRemainWatching() {
        let result = HardTrainingLowRecoveryCostBeliefEvaluator.evaluate(
            observations: HardTrainingLowRecoveryCostFixtures.observationsWithRecoveryCost(dayCount: 8),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testTooFewLowRecoveryHardDaysRemainWatching() {
        let result = HardTrainingLowRecoveryCostBeliefEvaluator.evaluate(
            observations: HardTrainingLowRecoveryCostFixtures.observationsWithoutLowRecoveryHardDays(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum HardTrainingLowRecoveryCostFixtures {

    /// Pattern: hard day while well recovered (≥70) → strong next day;
    /// hard day while poorly recovered (<60) → weak next day.
    static func observationsWithRecoveryCost(dayCount: Int = 15) -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 80, false),
            (.hard, 78, true),   // good recovery hard
            (.rest, 86, false),  // strong next day
            (.hard, 52, true),   // depleted hard
            (.rest, 70, false),  // weaker next day
            (.light, 82, false),
            (.hard, 76, true),
            (.rest, 85, false),
            (.hard, 48, true),
            (.rest, 68, false),
            (.light, 81, false),
            (.hard, 74, true),
            (.rest, 84, false),
            (.hard, 55, true),
            (.rest, 69, false),
            (.light, 80, false),
        ]
        return buildObservations(configs: Array(configs.prefix(dayCount)))
    }

    static func observationsWithStableCost() -> [CoachDailyObservation] {
        var configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 82, false),
            (.light, 83, false),
        ]

        let cycles: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.hard, 76, true),
            (.rest, 85, false),
            (.hard, 50, true),
            (.rest, 69, false),
            (.light, 82, false),
        ]

        for _ in 0..<5 {
            configs.append(contentsOf: cycles)
        }

        return buildObservations(configs: configs)
    }

    static func observationsWithoutLowRecoveryHardDays() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 80, false),
            (.hard, 78, true),
            (.rest, 84, false),
            (.hard, 76, true),
            (.rest, 83, false),
            (.light, 82, false),
            (.hard, 74, true),
            (.rest, 85, false),
            (.hard, 77, true),
            (.rest, 84, false),
            (.light, 81, false),
            (.hard, 75, true),
            (.rest, 83, false),
            (.light, 82, false),
        ]
        return buildObservations(configs: configs)
    }

    private static func buildObservations(
        configs: [(CoachWorkoutIntensityBand, Int, Bool)]
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []

        for (index, config) in configs.enumerated() {
            let offset = configs.count - index
            guard let date = calendar.date(byAdding: .day, value: -offset, to: anchor) else { continue }

            let isHard = config.2
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: config.1,
                    bedStartNormalizedMinutes: 1_380,
                    exerciseMinutes: isHard ? 95 : 35,
                    activeCalories: isHard ? 800 : 220,
                    workoutCount: 1,
                    workoutTypes: isHard ? ["cycling"] : ["walking"],
                    hardWorkoutCount: isHard ? 1 : 0,
                    workoutIntensityBand: config.0,
                    hadHardTraining: isHard,
                    hadRecoveryActivity: !isHard,
                    hadRestDay: config.0 == .rest,
                    trainingLoadScore: isHard ? 90 : 35
                )
            )
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
