import Foundation
import OSLog
internal import Combine

@MainActor
final class TodayViewModel: ObservableObject {

    @Published var healthRefreshID = UUID()
    @Published var now = Date()

    private static let logger = Logger(subsystem: "WeekFit", category: "TodayViewModel")

    func triggerHealthRefresh() {
        healthRefreshID = UUID()
    }

    func selectedDayActivities(
        on selectedDate: Date,
        from plannedActivities: [PlannedActivity]
    ) -> [PlannedActivity] {
        DailyStateSnapshotBuilder.activities(on: selectedDate, from: plannedActivities)
    }

    func updateNutrition(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        extraWater: Double = 0
    ) {
        let dayActivities = selectedDayActivities(on: selectedDate, from: plannedActivities)
        let dailySnapshot = DailyStateSnapshotBuilder.build(
            selectedDate: selectedDate,
            dayActivities: dayActivities,
            allPlannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: now,
            source: "TodayViewModel.updateNutrition"
        )
        var metrics = dailySnapshot.nutritionMetrics
        if extraWater > 0 {
            metrics.waterLiters = max(metrics.waterLiters, healthManager.waterLiters + extraWater)
        }

        nutritionViewModel.updateNutrition(
            metrics: metrics,
            profile: dailySnapshot.profile,
            plannedActivities: dailySnapshot.dayActivities,
            recoveryContext: dailySnapshot.recoveryContext,
            referenceDate: selectedDate,
            debugSource: "TodayViewModel.updateNutrition"
        )
    }

    func refreshCoachInsight(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        coachInputProvider: CoachInputProvider,
        source: String
    ) {
        let start = Self.debugStart("todayCoachInsight.update source=\(source)")
        let dayActivities = selectedDayActivities(on: selectedDate, from: plannedActivities)
        coachInputProvider.refreshFromCurrentState(
            selectedDate: selectedDate,
            dayActivities: dayActivities,
            allPlannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            source: "TodayView.\(source)"
        )
        Self.debugEnd("todayCoachInsight.update source=\(source)", start: start)
    }

    func refreshTodayLiveState(
        refreshHealth: Bool,
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel
    ) {
        now = Date()
        updateNutrition(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )

        if refreshHealth {
            triggerHealthRefresh()
        }
    }

    func refreshHealthAndNutrition(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        appSession: AppSessionState
    ) async {
        guard healthManager.isHealthAccessRequested else {
            updateNutrition(
                selectedDate: selectedDate,
                plannedActivities: plannedActivities,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel
            )
            return
        }

        let dayActivities = selectedDayActivities(on: selectedDate, from: plannedActivities)
        await healthManager.loadHealthData(for: selectedDate, plannedActivities: dayActivities)
        updateNutrition(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        appSession.triggerCoachRefresh(source: "TodayView.healthDataLoaded")
    }

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        guard CoachDebugSettings.todayDataAuditEnabled else { return 0 }

        let start = CFAbsoluteTimeGetCurrent()
        logger.debug("\(label, privacy: .public) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        guard CoachDebugSettings.todayDataAuditEnabled, start > 0 else { return }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("\(label, privacy: .public) end elapsedMs=\(elapsedMs, privacy: .public)")
        #endif
    }
}
