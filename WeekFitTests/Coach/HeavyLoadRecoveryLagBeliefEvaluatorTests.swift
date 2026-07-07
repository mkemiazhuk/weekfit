import XCTest
@testable import WeekFit

final class HeavyLoadRecoveryLagBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenHardDaysAreFollowedByLowerRecovery() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithRecoveryLag()

        let evaluation = HeavyLoadRecoveryLagBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryLag ?? 0, 8)

        let result = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .heavyLoadRecoveryLag)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenLagPatternRemainsStable() {
        let emergingObservations = HeavyLoadRecoveryLagFixtures.observationsWithRecoveryLag()

        let emerging = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: emergingObservations,
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let establishedObservations = HeavyLoadRecoveryLagFixtures.observationsWithStableRecoveryLag()

        let established = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: establishedObservations,
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientDataRemainWatching() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithRecoveryLag(dayCount: 8)

        let result = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testNoHardDaysRemainWatching() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithoutHardDays()

        let result = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testMissingTrainingFieldsAreExcluded() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithRecoveryLag()
            + [
                CoachDailyObservation(
                    dayKey: "2099-01-01",
                    sleepMinutes: 450,
                    recoveryPercent: 40,
                    bedStartNormalizedMinutes: 1_380,
                    workoutIntensityBand: nil
                )
            ]

        let evaluation = HeavyLoadRecoveryLagBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.eligibleDayCount, 14)
    }

    func testUniformlyLowRecoveryProducesNoEvent() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithUniformLowRecovery()

        let result = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testWeakRecoveryDifferenceProducesNoEvent() {
        let observations = HeavyLoadRecoveryLagFixtures.observationsWithWeakLag()

        let result = HeavyLoadRecoveryLagBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    // MARK: - Helpers
}

enum HeavyLoadRecoveryLagFixtures {

    static func observationsWithRecoveryLag(dayCount: Int = 14) -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 83, false),
            (.light, 84, false),
            (.rest, 84, false),
            (.hard, 82, true),
            (.rest, 71, false),
            (.rest, 72, false),
            (.light, 84, false),
            (.hard, 81, true),
            (.rest, 70, false),
            (.rest, 71, false),
            (.light, 84, false),
            (.hard, 80, true),
            (.rest, 69, false),
            (.rest, 70, false),
        ]

        return buildObservations(configs: Array(configs.prefix(dayCount)))
    }

    static func observationsWithStableRecoveryLag() -> [CoachDailyObservation] {
        var configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 84, false),
            (.light, 85, false),
            (.rest, 84, false),
            (.light, 85, false),
        ]

        let hardCycles: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.hard, 82, true),
            (.rest, 73, false),
            (.rest, 74, false),
        ]

        for _ in 0..<5 {
            configs.append(contentsOf: hardCycles)
            configs.append((.light, 85, false))
        }

        return buildObservations(configs: configs)
    }

    static func observationsWithoutHardDays() -> [CoachDailyObservation] {
        let configs = Array(
            repeating: (CoachWorkoutIntensityBand.light, 84, false),
            count: 14
        )
        return buildObservations(configs: configs)
    }

    static func observationsWithUniformLowRecovery() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 52, false),
            (.light, 53, false),
            (.rest, 52, false),
            (.hard, 51, true),
            (.rest, 50, false),
            (.rest, 51, false),
            (.light, 52, false),
            (.hard, 50, true),
            (.rest, 49, false),
            (.rest, 50, false),
            (.light, 52, false),
            (.hard, 51, true),
            (.rest, 50, false),
            (.rest, 49, false),
        ]
        return buildObservations(configs: configs)
    }

    static func observationsWithWeakLag() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.rest, 82, false),
            (.light, 83, false),
            (.rest, 82, false),
            (.hard, 81, true),
            (.rest, 79, false),
            (.rest, 80, false),
            (.light, 83, false),
            (.hard, 81, true),
            (.rest, 78, false),
            (.rest, 79, false),
            (.light, 83, false),
            (.hard, 80, true),
            (.rest, 78, false),
            (.rest, 79, false),
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

            observations.append(
                trainingObservation(
                    date: date,
                    recoveryPercent: config.1,
                    intensityBand: config.0,
                    hadHardTraining: config.2
                )
            )
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    static func trainingObservation(
        date: Date,
        recoveryPercent: Int,
        intensityBand: CoachWorkoutIntensityBand,
        hadHardTraining: Bool
    ) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: hadHardTraining ? 95 : 35,
            activeCalories: hadHardTraining ? 800 : 220,
            workoutCount: 1,
            workoutTypes: hadHardTraining ? ["cycling"] : ["walking"],
            hardWorkoutCount: hadHardTraining ? 1 : 0,
            workoutIntensityBand: intensityBand,
            hadHardTraining: hadHardTraining,
            hadRecoveryActivity: !hadHardTraining,
            hadRestDay: intensityBand == .rest,
            trainingLoadScore: hadHardTraining ? 90 : 35
        )
    }
}
