import XCTest
@testable import WeekFit

final class ProteinTrainingDayRecoveryBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenHigherProteinTrainingDaysImproveNextDayRecovery() {
        let observations = ProteinTrainingDayRecoveryFixtures.observationsWithRecoveryDelta()

        let evaluation = ProteinTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDelta ?? 0, 8)

        let result = ProteinTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .proteinTrainingDayRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenPatternRemainsStable() {
        let emerging = ProteinTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: ProteinTrainingDayRecoveryFixtures.observationsWithRecoveryDelta(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = ProteinTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: ProteinTrainingDayRecoveryFixtures.observationsWithStableDelta(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testTinyProteinSpreadRemainsWatching() {
        let result = ProteinTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: ProteinTrainingDayRecoveryFixtures.observationsWithTinyProteinSpread(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testInsufficientAnchorsRemainWatching() {
        let result = ProteinTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: ProteinTrainingDayRecoveryFixtures.observationsWithRecoveryDelta(trainingDayCount: 4),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum ProteinTrainingDayRecoveryFixtures {

    /// Alternating high/mid/low protein training days; next-day recovery tracks protein.
    static func observationsWithRecoveryDelta(trainingDayCount: Int = 9) -> [CoachDailyObservation] {
        let cycles: [(CoachWorkoutIntensityBand, Int, Int)] = [
            (.hard, 160, 86),
            (.moderate, 110, 78),
            (.hard, 70, 68),
        ]

        let training = Array(repeating: cycles, count: (trainingDayCount + 2) / 3)
            .flatMap { $0 }
            .prefix(trainingDayCount)
            .map { ($0.0, $0.1, $0.2) }
        return buildPairedSequence(trainingConfigs: Array(training))
    }

    static func observationsWithStableDelta() -> [CoachDailyObservation] {
        let cycles: [(CoachWorkoutIntensityBand, Int, Int)] = [
            (.hard, 165, 87),
            (.moderate, 115, 79),
            (.hard, 65, 69),
        ]
        let training = Array(repeating: cycles, count: 6).flatMap { $0 }
        return buildPairedSequence(trainingConfigs: training)
    }

    static func observationsWithTinyProteinSpread() -> [CoachDailyObservation] {
        let cycles: [(CoachWorkoutIntensityBand, Int, Int)] = [
            (.hard, 120, 84),
            (.moderate, 115, 82),
            (.hard, 110, 80),
        ]
        let training = Array(repeating: cycles, count: 4).flatMap { $0 }
        return buildPairedSequence(trainingConfigs: training)
    }

    /// Each training day is followed by a rest day whose recovery encodes the next-day effect.
    private static func buildPairedSequence(
        trainingConfigs: [(CoachWorkoutIntensityBand, Int, Int)]
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []
        var dayOffset = trainingConfigs.count * 2 + 1

        // Opening rest day
        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
            observations.append(nutritionTrainingDay(
                date: date,
                band: .rest,
                protein: 100,
                recovery: 80
            ))
        }
        dayOffset -= 1

        for config in trainingConfigs {
            if let trainDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(nutritionTrainingDay(
                    date: trainDate,
                    band: config.0,
                    protein: config.1,
                    recovery: 75
                ))
            }
            dayOffset -= 1

            if let restDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(nutritionTrainingDay(
                    date: restDate,
                    band: .rest,
                    protein: 100,
                    recovery: config.2
                ))
            }
            dayOffset -= 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    static func nutritionTrainingDay(
        date: Date,
        band: CoachWorkoutIntensityBand,
        protein: Int,
        recovery: Int
    ) -> CoachDailyObservation {
        let isTraining = band == .hard || band == .moderate
        return CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recovery,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: isTraining ? 70 : 20,
            activeCalories: isTraining ? 600 : 180,
            workoutCount: 1,
            workoutTypes: isTraining ? ["strength"] : ["walking"],
            hardWorkoutCount: band == .hard ? 1 : 0,
            workoutIntensityBand: band,
            hadHardTraining: band == .hard,
            hadRecoveryActivity: !isTraining,
            hadRestDay: band == .rest,
            trainingLoadScore: isTraining ? 80 : 25,
            proteinGrams: protein,
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
