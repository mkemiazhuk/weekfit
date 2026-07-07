import XCTest
@testable import WeekFit

@MainActor
final class CoachInputProviderStaleTaskTests: XCTestCase {

    func testLatestConcurrentRefreshWins() async {
        let provider = CoachInputProvider()
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()

        async let first: Void = provider.refresh(
            selectedDate: Date(),
            plannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            source: "slowRefresh",
            refreshHealth: false
        )

        try? await Task.sleep(nanoseconds: 1_000_000)
        await provider.refresh(
            selectedDate: Date(),
            plannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            source: "fastRefresh",
            refreshHealth: false
        )

        await first
        XCTAssertEqual(provider.lastRefreshReason, "fastRefresh")
    }
}
