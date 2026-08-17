import XCTest
@testable import WeekFit

final class CoachDiscoveryCopyPersonalizationTests: XCTestCase {

    func testSleepDurationCopyUsesLearnedThresholdHours() {
        let observations = sleepDurationSampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 84,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 68,
            sufficientCount: 5,
            insufficientCount: 3
        )

        let evaluation = SleepDurationBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.sufficientSleepThresholdMinutes, 450)

        let content = CoachDiscoveryCopy.content(
            for: .sleepDurationRecovery,
            observations: observations
        )
        XCTAssertTrue(content.body.contains("7.5–8 hours") || content.body.contains("7,5–8"))
        XCTAssertFalse(content.body.contains("7–7.5"))
    }

    func testProteinCopyUsesLearnedGramRange() {
        let observations = ProteinTrainingDayRecoveryFixtures.observationsWithStableDelta()
        let evaluation = ProteinTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)

        let content = CoachDiscoveryCopy.content(
            for: .proteinTrainingDayRecovery,
            observations: observations
        )
        XCTAssertTrue(content.body.contains("g protein") || content.body.contains("г белка"))
        if let evaluation {
            let low = evaluation.lowProteinMedianGrams + 10
            XCTAssertTrue(content.body.contains("\(low)"))
        }
    }

    private func sleepDurationSampleObservations(
        sufficientSleepMinutes: Int,
        sufficientRecovery: Int,
        insufficientSleepMinutes: Int,
        insufficientRecovery: Int,
        sufficientCount: Int,
        insufficientCount: Int
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []
        var offset = 0

        for _ in 0..<sufficientCount {
            let date = calendar.date(byAdding: .day, value: -offset, to: anchor)!
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: sufficientSleepMinutes,
                    recoveryPercent: sufficientRecovery,
                    bedStartNormalizedMinutes: 1_380,
                    exerciseMinutes: 30,
                    activeCalories: 250,
                    workoutCount: 1,
                    workoutTypes: ["walking"],
                    hardWorkoutCount: 0,
                    workoutIntensityBand: .light,
                    hadHardTraining: false,
                    hadRecoveryActivity: true,
                    hadRestDay: false,
                    trainingLoadScore: 25
                )
            )
            offset += 1
        }

        for _ in 0..<insufficientCount {
            let date = calendar.date(byAdding: .day, value: -offset, to: anchor)!
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: insufficientSleepMinutes,
                    recoveryPercent: insufficientRecovery,
                    bedStartNormalizedMinutes: 1_380,
                    exerciseMinutes: 30,
                    activeCalories: 250,
                    workoutCount: 1,
                    workoutTypes: ["walking"],
                    hardWorkoutCount: 0,
                    workoutIntensityBand: .light,
                    hadHardTraining: false,
                    hadRecoveryActivity: true,
                    hadRestDay: false,
                    trainingLoadScore: 25
                )
            )
            offset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
