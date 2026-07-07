import XCTest
@testable import WeekFit

final class RecoveryAfterRestDayBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenRestDayFollowsHeavierWorkWithRecoveryRebound() {
        let observations = RecoveryAfterRestDayFixtures.observationsWithRecoveryRebound()

        let evaluation = RecoveryAfterRestDayBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThanOrEqual(evaluation?.recoveryRebound ?? 0, 8)

        let result = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .recoveryAfterRestDay)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenReboundPatternRemainsStable() {
        let emerging = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithRecoveryRebound(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithStableRecoveryRebound(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientDataRemainWatching() {
        let result = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithRecoveryRebound(dayCount: 10),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testTooFewHeavyToRestSequencesRemainWatching() {
        let result = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithoutRestFollowUpSequences(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testMissingTrainingFieldsAreExcluded() {
        let observations = RecoveryAfterRestDayFixtures.observationsWithRecoveryRebound()
            + [
                CoachDailyObservation(
                    dayKey: "2099-01-01",
                    sleepMinutes: 450,
                    recoveryPercent: 90,
                    bedStartNormalizedMinutes: 1_380,
                    workoutIntensityBand: nil
                )
            ]

        let evaluation = RecoveryAfterRestDayBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.eligibleDayCount, 16)
    }

    func testAlreadyHighRecoveryAfterHeavyDayProducesNoEvent() {
        let result = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithAlreadyHighRecovery(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testWeakReboundProducesNoEvent() {
        let result = RecoveryAfterRestDayBeliefEvaluator.evaluate(
            observations: RecoveryAfterRestDayFixtures.observationsWithWeakRebound(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum RecoveryAfterRestDayFixtures {

    static func observationsWithRecoveryRebound(dayCount: Int = 16) -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool, Bool)] = [
            (.moderate, 78, false, false),
            (.rest, 68, false, true),
            (.light, 77, false, true),
            (.light, 84, false, true),
            (.moderate, 77, false, false),
            (.rest, 67, false, true),
            (.light, 76, false, true),
            (.light, 84, false, true),
            (.hard, 76, true, false),
            (.light, 69, false, true),
            (.rest, 77, false, true),
            (.light, 85, false, true),
            (.moderate, 78, false, false),
            (.rest, 66, false, true),
            (.light, 75, false, true),
            (.light, 84, false, true),
        ]

        return buildObservations(configs: Array(configs.prefix(dayCount)))
    }

    static func observationsWithStableRecoveryRebound() -> [CoachDailyObservation] {
        var configs: [(CoachWorkoutIntensityBand, Int, Bool, Bool)] = [
            (.light, 84, false, true),
            (.light, 85, false, true),
        ]

        let sequence: [(CoachWorkoutIntensityBand, Int, Bool, Bool)] = [
            (.moderate, 78, false, false),
            (.rest, 68, false, true),
            (.light, 76, false, true),
            (.light, 84, false, true),
        ]

        for _ in 0..<5 {
            configs.append(contentsOf: sequence)
        }

        return buildObservations(configs: configs)
    }

    static func observationsWithoutRestFollowUpSequences() -> [CoachDailyObservation] {
        let configs = Array(
            repeating: (CoachWorkoutIntensityBand.moderate, 78, false, false),
            count: 14
        ) + Array(
            repeating: (CoachWorkoutIntensityBand.moderate, 79, false, false),
            count: 2
        )
        return buildObservations(configs: configs)
    }

    static func observationsWithAlreadyHighRecovery() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool, Bool)] = [
            (.moderate, 88, false, false),
            (.rest, 86, false, true),
            (.light, 87, false, true),
            (.light, 88, false, true),
            (.hard, 89, true, false),
            (.rest, 87, false, true),
            (.light, 88, false, true),
            (.light, 89, false, true),
            (.moderate, 88, false, false),
            (.rest, 86, false, true),
            (.light, 87, false, true),
            (.light, 88, false, true),
            (.moderate, 89, false, false),
            (.rest, 87, false, true),
            (.light, 88, false, true),
            (.light, 89, false, true),
        ]
        return buildObservations(configs: configs)
    }

    static func observationsWithWeakRebound() -> [CoachDailyObservation] {
        let configs: [(CoachWorkoutIntensityBand, Int, Bool, Bool)] = [
            (.moderate, 78, false, false),
            (.rest, 76, false, true),
            (.light, 78, false, true),
            (.light, 84, false, true),
            (.hard, 77, true, false),
            (.light, 75, false, true),
            (.rest, 77, false, true),
            (.light, 84, false, true),
            (.moderate, 78, false, false),
            (.rest, 76, false, true),
            (.light, 78, false, true),
            (.light, 84, false, true),
            (.moderate, 77, false, false),
            (.rest, 75, false, true),
            (.light, 77, false, true),
            (.light, 84, false, true),
        ]
        return buildObservations(configs: configs)
    }

    private static func buildObservations(
        configs: [(CoachWorkoutIntensityBand, Int, Bool, Bool)]
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
                    hadHardTraining: config.2,
                    hadRecoveryActivity: config.3
                )
            )
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    private static func trainingObservation(
        date: Date,
        recoveryPercent: Int,
        intensityBand: CoachWorkoutIntensityBand,
        hadHardTraining: Bool,
        hadRecoveryActivity: Bool
    ) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: hadHardTraining ? 95 : (intensityBand == .moderate ? 60 : 25),
            activeCalories: hadHardTraining ? 800 : (intensityBand == .moderate ? 500 : 150),
            workoutCount: intensityBand == .rest ? 0 : 1,
            workoutTypes: hadHardTraining ? ["cycling"] : ["walking"],
            hardWorkoutCount: hadHardTraining ? 1 : 0,
            workoutIntensityBand: intensityBand,
            hadHardTraining: hadHardTraining,
            hadRecoveryActivity: hadRecoveryActivity,
            hadRestDay: intensityBand == .rest,
            trainingLoadScore: hadHardTraining ? 90 : (intensityBand == .moderate ? 60 : 20)
        )
    }
}
