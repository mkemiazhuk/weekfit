import Foundation
internal import Combine

@MainActor
final class HighlightsViewModel: ObservableObject {

    @Published private(set) var story: HighlightStory = WeekFitDataSynthesizer.generateMonthlyHighlight(from: [])
    @Published private(set) var dailyMetrics: [DailyMetrics] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private let provider: WeekFitHighlightsDataProvider
    private var refreshToken = UUID()

    init(provider: WeekFitHighlightsDataProvider = WeekFitHighlightsDataProvider()) {
        self.provider = provider
    }

    func refresh(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        plannedActivities: [PlannedActivity]
    ) async {
        let token = UUID()
        refreshToken = token
        isLoading = true

        let metrics = await provider.loadMonthlyMetrics(
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            plannedActivities: plannedActivities
        )

        guard refreshToken == token else {
            isLoading = false
            return
        }

        dailyMetrics = metrics
        story = WeekFitDataSynthesizer.generateMonthlyHighlight(from: metrics)
        lastUpdated = Date()
        isLoading = false
    }
}
