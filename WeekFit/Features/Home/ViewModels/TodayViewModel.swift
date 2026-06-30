import Foundation
import OSLog
internal import Combine

@MainActor
final class TodayViewModel: ObservableObject {

    @Published var healthRefreshID = UUID()
    @Published var now = Date()
    @Published private(set) var trackedDisplayDayStart: Date?

    private static let logger = Logger(subsystem: "WeekFit", category: "TodayViewModel")
    private let lifecycleToken = "TodayViewModel"

    init() {
        WeekFitLifecycleTracker.attach(lifecycleToken)
    }

    deinit {
        WeekFitLifecycleTracker.detach(lifecycleToken)
    }

    func triggerHealthRefresh() {
        healthRefreshID = UUID()
    }

    /// Returns `true` when the calendar day rolled over and HealthKit should reload.
    @discardableResult
    func reconcileDayBoundary(
        selectedDate: inout Date,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        calendar: Calendar = .current
    ) -> Bool {
        let currentNow = Date()
        now = currentNow

        let output = TodayDayBoundaryPolicy.reconcile(
            TodayDayBoundaryPolicy.Input(
                now: currentNow,
                selectedDate: selectedDate,
                trackedDayStart: trackedDisplayDayStart,
                calendar: calendar
            )
        )

        trackedDisplayDayStart = output.trackedDayStart
        selectedDate = output.selectedDate

        if output.didCrossBoundary {
            healthManager.prepareForDisplayDay(output.trackedDayStart)
            nutritionViewModel.prepareForDay(output.selectedDate)
            return output.shouldRefreshHealth
        }

        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        if calendar.isDate(selectedDate, inSameDayAs: currentNow),
           let nutritionDay = nutritionViewModel.trackedNutritionDayStart,
           !calendar.isDate(nutritionDay, inSameDayAs: selectedDayStart) {
            healthManager.prepareForDisplayDay(selectedDayStart)
            nutritionViewModel.prepareForDay(selectedDate)
            return true
        }

        return output.shouldRefreshHealth
    }

    func nextDayBoundary(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        TodayDayBoundaryPolicy.nextBoundary(after: date, calendar: calendar)
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
