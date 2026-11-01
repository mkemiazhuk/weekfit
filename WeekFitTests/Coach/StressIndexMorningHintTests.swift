import XCTest
@testable import WeekFit

final class StressIndexMorningHintTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let walk = RecoveryPriorDayLoad(exerciseMinutes: 35, activeCalories: 300, workoutCount: 2)
    private let workout = RecoveryPriorDayLoad(exerciseMinutes: 70, activeCalories: 650, workoutCount: 1)

    private func stress(
        hrv: Double = 34,
        rhr: Double = 62,
        sleepMinutes: Int = 360,
        load: RecoveryPriorDayLoad? = .empty
    ) -> StressIndexResult {
        let baseline = RecoveryPhysiologyBaseline(
            hrvMedian: 50,
            hrvSampleCount: 21,
            restingHeartRateMedian: 52,
            restingHeartRateSampleCount: 21,
            windowDays: RecoveryPhysiologyBaseline.preferredWindowDays
        )
        return StressIndexEngine.calculate(
            RecoveryScoreInput(
                sleepMinutes: sleepMinutes,
                timeInBedMinutes: sleepMinutes + 20,
                awakeMinutes: 20,
                awakeningsCount: 1,
                deepSleepMinutes: 60,
                remSleepMinutes: 80,
                hrvSDNN: hrv,
                restingHeartRate: rhr,
                bedtimeDeviationMinutes: 0,
                baseline: baseline,
                priorDayLoad: load
            ),
            at: fixedDate
        )
    }

    func testBeerAfterAQuietDayIsNamed() {
        let result = stress(load: walk)
        XCTAssertEqual(result.level, .high)
        XCTAssertEqual(
            StressIndexMorningHint.resolve(result: result, priorDayLoad: walk, alcohol: .beer),
            .alcohol(.beer)
        )
    }

    func testBeerAfterAWorkoutMentionsBoth() {
        let result = stress(load: workout)
        XCTAssertEqual(
            StressIndexMorningHint.resolve(result: result, priorDayLoad: workout, alcohol: .beer),
            .alcoholAfterLoad(.beer)
        )
    }

    func testNothingLoggedAfterAQuietDayStaysVague() {
        let result = stress(load: walk)
        XCTAssertEqual(
            StressIndexMorningHint.resolve(result: result, priorDayLoad: walk, alcohol: nil),
            .unlogged
        )
    }

    func testWorkoutWithoutDrinksKeepsTheUsualText() {
        let result = stress(load: workout)
        XCTAssertNil(StressIndexMorningHint.resolve(result: result, priorDayLoad: workout, alcohol: nil))
    }

    func testMildVitalsShiftDoesNotGuess() {
        let result = stress(hrv: 44, rhr: 55, sleepMinutes: 240, load: walk)
        XCTAssertNil(StressIndexMorningHint.resolve(result: result, priorDayLoad: walk, alcohol: .beer))
    }

    func testOnlyOneVitalShiftedDoesNotGuess() {
        let result = stress(hrv: 50, rhr: 66, sleepMinutes: 240, load: walk)
        XCTAssertNil(StressIndexMorningHint.resolve(result: result, priorDayLoad: walk, alcohol: .beer))
    }

    func testBelowHighDoesNotGuess() {
        let result = stress(hrv: 41, rhr: 56, sleepMinutes: 540, load: walk)
        XCTAssertNotEqual(result.level, .high)
        XCTAssertNil(StressIndexMorningHint.resolve(result: result, priorDayLoad: walk, alcohol: .beer))
    }

    func testAlcoholClassification() {
        XCTAssertEqual(StressIndexAlcohol.classify(title: "Beer", imageName: "ingredient-beer"), .beer)
        XCTAssertEqual(StressIndexAlcohol.classify(title: "Red Wine", imageName: "ingredient-red-wine"), .wine)
        XCTAssertEqual(StressIndexAlcohol.classify(title: "Светлое пиво", imageName: ""), .beer)
        XCTAssertEqual(StressIndexAlcohol.classify(title: "Weißwein", imageName: ""), .wine)
        XCTAssertNil(StressIndexAlcohol.classify(title: "Безалкогольное пиво", imageName: ""))
        XCTAssertNil(StressIndexAlcohol.classify(title: "Ginger ale", imageName: ""))
        XCTAssertNil(StressIndexAlcohol.classify(title: "Water", imageName: "hydration"))
        XCTAssertNil(StressIndexAlcohol.classify(title: "Coffee", imageName: ""))
        XCTAssertNil(StressIndexAlcohol.classify(title: "Grape juice", imageName: ""))
        XCTAssertEqual(StressIndexAlcohol.combine([.beer, .beer]), .beer)
        XCTAssertEqual(StressIndexAlcohol.combine([.beer, .wine]), .mixed)
        XCTAssertNil(StressIndexAlcohol.combine([]))
    }

    func testEveryHintHasRussianCopy() {
        let hints: [StressIndexMorningHint] = [
            .alcohol(.beer), .alcohol(.wine), .alcohol(.mixed),
            .alcoholAfterLoad(.beer), .alcoholAfterLoad(.wine), .alcoholAfterLoad(.mixed), .unlogged
        ]
        for hint in hints {
            XCTAssertFalse(hint.text.hasPrefix("recovery.stressIndex.morning."), "\(hint)")
        }
    }
}
