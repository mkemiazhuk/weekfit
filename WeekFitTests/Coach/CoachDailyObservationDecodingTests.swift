import XCTest
@testable import WeekFit

final class CoachDailyObservationDecodingTests: XCTestCase {

    func testLegacyObservationJSONDecodesWithoutTrainingFields() throws {
        let json = """
        {
            "dayKey": "2026-01-15",
            "sleepMinutes": 420,
            "recoveryPercent": 78,
            "bedStartNormalizedMinutes": 1380
        }
        """.data(using: .utf8)!

        let observation = try JSONDecoder().decode(CoachDailyObservation.self, from: json)

        XCTAssertEqual(observation.dayKey, "2026-01-15")
        XCTAssertEqual(observation.sleepMinutes, 420)
        XCTAssertEqual(observation.recoveryPercent, 78)
        XCTAssertEqual(observation.bedStartNormalizedMinutes, 1380)
        XCTAssertNil(observation.exerciseMinutes)
        XCTAssertNil(observation.activeCalories)
        XCTAssertNil(observation.workoutCount)
        XCTAssertNil(observation.workoutTypes)
        XCTAssertNil(observation.hardWorkoutCount)
        XCTAssertNil(observation.workoutIntensityBand)
        XCTAssertNil(observation.hadHardTraining)
        XCTAssertNil(observation.hadRecoveryActivity)
        XCTAssertNil(observation.hadRestDay)
        XCTAssertNil(observation.trainingLoadScore)
        XCTAssertFalse(observation.hasPopulatedTrainingFields)
        XCTAssertNil(observation.proteinGrams)
        XCTAssertNil(observation.carbsGrams)
        XCTAssertNil(observation.fatGrams)
        XCTAssertNil(observation.caloriesEaten)
        XCTAssertNil(observation.calorieDeficit)
        XCTAssertNil(observation.hydrationLiters)
        XCTAssertNil(observation.mealsLoggedCount)
        XCTAssertNil(observation.hasPopulatedNutritionFields)
        XCTAssertFalse(observation.hasPopulatedNutritionFieldsResolved)
    }

    func testStoredObservationDictionaryDecodesLegacyRows() throws {
        let json = """
        {
            "2026-01-15": {
                "dayKey": "2026-01-15",
                "sleepMinutes": 450,
                "recoveryPercent": 82,
                "bedStartNormalizedMinutes": null
            }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: CoachDailyObservation].self, from: json)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded["2026-01-15"]?.workoutIntensityBand)
    }

    func testObservationRoundTripEncodesTrainingFields() throws {
        let observation = CoachDailyObservation(
            dayKey: "2026-02-01",
            sleepMinutes: 430,
            recoveryPercent: 80,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: 95,
            activeCalories: 720,
            workoutCount: 1,
            workoutTypes: ["cycling"],
            hardWorkoutCount: 1,
            workoutIntensityBand: .hard,
            hadHardTraining: true,
            hadRecoveryActivity: false,
            hadRestDay: false,
            trainingLoadScore: 90
        )

        let data = try JSONEncoder().encode(observation)
        let decoded = try JSONDecoder().decode(CoachDailyObservation.self, from: data)

        XCTAssertEqual(decoded, observation)
        XCTAssertTrue(decoded.hasPopulatedTrainingFields)
    }

    func testObservationRoundTripEncodesNutritionFields() throws {
        let observation = CoachDailyObservation(
            dayKey: "2026-02-02",
            sleepMinutes: 430,
            recoveryPercent: 80,
            bedStartNormalizedMinutes: 1_380,
            proteinGrams: 140,
            carbsGrams: 220,
            fatGrams: 55,
            caloriesEaten: 2_100,
            calorieDeficit: 150,
            hydrationLiters: 2.4,
            mealsLoggedCount: 3,
            hasPopulatedNutritionFields: true
        )

        let data = try JSONEncoder().encode(observation)
        let decoded = try JSONDecoder().decode(CoachDailyObservation.self, from: data)

        XCTAssertEqual(decoded, observation)
        XCTAssertTrue(decoded.hasPopulatedNutritionFieldsResolved)
    }
}
