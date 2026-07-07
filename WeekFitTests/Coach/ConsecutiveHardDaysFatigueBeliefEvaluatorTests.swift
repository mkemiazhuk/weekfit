import XCTest
@testable import WeekFit

final class ConsecutiveHardDaysFatigueBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenConsecutiveLoadLowersRecovery() {
        let observations = ConsecutiveHardDaysFatigueFixtures.observationsWithConsecutiveFatigue()

        let evaluation = ConsecutiveHardDaysFatigueBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThanOrEqual(evaluation?.recoveryFatigue ?? 0, 8)

        let result = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .consecutiveHardDaysFatigue)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenFatiguePatternRemainsStable() {
        let emerging = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithConsecutiveFatigue(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithStableConsecutiveFatigue(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientDataRemainWatching() {
        let result = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithConsecutiveFatigue(dayCount: 12),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testTooFewConsecutiveSequencesRemainWatching() {
        let result = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithoutConsecutiveSequences(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testMissingTrainingFieldsAreExcluded() {
        let observations = ConsecutiveHardDaysFatigueFixtures.observationsWithConsecutiveFatigue()
            + [
                CoachDailyObservation(
                    dayKey: "2099-01-01",
                    sleepMinutes: 450,
                    recoveryPercent: 40,
                    bedStartNormalizedMinutes: 1_380,
                    workoutIntensityBand: nil
                )
            ]

        let evaluation = ConsecutiveHardDaysFatigueBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.eligibleDayCount, 22)
    }

    func testUniformlyLowRecoveryProducesNoEvent() {
        let result = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithUniformLowRecovery(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testWeakFatigueEffectProducesNoEvent() {
        let result = ConsecutiveHardDaysFatigueBeliefEvaluator.evaluate(
            observations: ConsecutiveHardDaysFatigueFixtures.observationsWithWeakFatigue(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum ConsecutiveHardDaysFatigueFixtures {

    static func observationsWithConsecutiveFatigue(dayCount: Int = 22) -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.light, 84, false),
            (.moderate, 80, false),
            (.light, 84, false),
            (.light, 85, false),
            (.moderate, 78, false),
            (.moderate, 77, false),
            (.light, 71, false),
            (.moderate, 79, false),
            (.light, 83, false),
            (.light, 84, false),
            (.moderate, 79, false),
            (.light, 83, false),
            (.hard, 76, true),
            (.moderate, 75, false),
            (.light, 68, false),
            (.light, 84, false),
            (.moderate, 78, false),
            (.light, 82, false),
            (.light, 84, false),
            (.moderate, 77, false),
            (.hard, 76, true),
            (.light, 67, false),
        ]

        return buildObservations(configs: Array(configs.prefix(dayCount)))
    }

    static func observationsWithStableConsecutiveFatigue() -> [CoachDailyObservation] {
        var configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.light, 84, false),
            (.light, 85, false),
        ]

        let block: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.moderate, 80, false),
            (.light, 84, false),
            (.light, 85, false),
            (.moderate, 78, false),
            (.moderate, 77, false),
            (.light, 71, false),
            (.light, 84, false),
        ]

        for _ in 0..<5 {
            configs.append(contentsOf: block)
        }

        return buildObservations(configs: configs)
    }

    static func observationsWithoutConsecutiveSequences() -> [CoachDailyObservation] {
        var configs: [(CoachWorkoutIntensityBand, Int, Bool)] = []
        for index in 0..<18 {
            let band: CoachWorkoutIntensityBand = index % 3 == 1 ? .moderate : .light
            configs.append((band, 80, false))
        }
        return buildObservations(configs: configs)
    }

    static func observationsWithUniformLowRecovery() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.light, 52, false),
            (.moderate, 51, false),
            (.light, 52, false),
            (.light, 53, false),
            (.moderate, 51, false),
            (.moderate, 50, false),
            (.light, 49, false),
            (.moderate, 51, false),
            (.light, 52, false),
            (.light, 53, false),
            (.moderate, 50, false),
            (.light, 51, false),
            (.hard, 50, true),
            (.moderate, 49, false),
            (.light, 48, false),
            (.light, 52, false),
            (.moderate, 51, false),
            (.light, 52, false),
            (.light, 53, false),
            (.moderate, 50, false),
            (.hard, 49, true),
            (.light, 48, false),
        ]
        return buildObservations(configs: configs)
    }

    static func observationsWithWeakFatigue() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool)] = [
            (.light, 82, false),
            (.moderate, 80, false),
            (.light, 81, false),
            (.light, 82, false),
            (.moderate, 79, false),
            (.moderate, 78, false),
            (.light, 77, false),
            (.moderate, 80, false),
            (.light, 81, false),
            (.light, 82, false),
            (.moderate, 79, false),
            (.light, 80, false),
            (.hard, 78, true),
            (.moderate, 77, false),
            (.light, 76, false),
            (.light, 82, false),
            (.moderate, 80, false),
            (.light, 81, false),
            (.light, 82, false),
            (.moderate, 79, false),
            (.hard, 78, true),
            (.light, 77, false),
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

    private static func trainingObservation(
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
            exerciseMinutes: hadHardTraining ? 95 : (intensityBand == .moderate ? 60 : 25),
            activeCalories: hadHardTraining ? 800 : (intensityBand == .moderate ? 500 : 150),
            workoutCount: intensityBand == .light && !hadHardTraining ? 0 : 1,
            workoutTypes: hadHardTraining ? ["cycling"] : ["walking"],
            hardWorkoutCount: hadHardTraining ? 1 : 0,
            workoutIntensityBand: intensityBand,
            hadHardTraining: hadHardTraining,
            hadRecoveryActivity: intensityBand == .light,
            hadRestDay: false,
            trainingLoadScore: hadHardTraining ? 90 : (intensityBand == .moderate ? 60 : 25)
        )
    }
}
