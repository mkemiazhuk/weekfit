import Foundation

@MainActor
final class AppReviewDemoHealthDataProvider {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    private(set) var dataset: AppReviewDemoDataset

    init(scenario: AppReviewDemoScenario, referenceDate: Date = Date()) {
        dataset = AppReviewDemoDatasetGenerator.generate(
            scenario: scenario,
            referenceDate: referenceDate
        )
    }

    func regenerate(scenario: AppReviewDemoScenario, referenceDate: Date = Date()) {
        dataset = AppReviewDemoDatasetGenerator.generate(
            scenario: scenario,
            referenceDate: referenceDate
        )
    }

    func activityMetrics(for date: Date) -> ActivityMetricsSnapshot {
        dataset.activityMetrics(for: date)
    }

    func sleepSnapshot(for date: Date) -> RecoverySleepSnapshot {
        dataset.sleepSnapshot(for: date)
    }

    func nutritionSnapshot(for date: Date) -> NutritionMetricsSnapshot? {
        dataset.nutrition(for: date)
    }

    func hourlyActiveCalories(for date: Date) -> [Double] {
        dataset.hourlyActiveCalories(for: date)
    }

    func recoveryScoreContext(for date: Date) -> RecoveryScoreContext {
        AppReviewDemoDatasetGenerator.recoveryScoreContext(for: date, dataset: dataset)
    }

    func overnightVitals(for date: Date) -> (hrv: Double?, restingHeartRate: Double?) {
        let metrics = activityMetrics(for: date)
        return (
            hrv: metrics.hrvSDNN > 0 ? metrics.hrvSDNN : nil,
            restingHeartRate: metrics.restingHeartRate > 0 ? metrics.restingHeartRate : nil
        )
    }

    var userProfile: AppReviewDemoUserProfile {
        dataset.userProfile
    }
}
