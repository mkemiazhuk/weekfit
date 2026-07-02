import Foundation
internal import Combine

@MainActor
final class CoachInputProvider: ObservableObject {
    @Published private(set) var lastInput: CoachInputSnapshot?
    @Published private(set) var lastRefreshReason: String = "notLoaded"

    private let lifecycleToken = "CoachInputProvider"
    private var inFlightRefreshTask: Task<Void, Never>?
    private var lastCompletedRefreshKey: String?
    private var refreshGeneration = 0

    init() {
        WeekFitLifecycleTracker.attach(lifecycleToken)
    }

    deinit {
        inFlightRefreshTask?.cancel()
        WeekFitLifecycleTracker.detach(lifecycleToken)
    }

    func refresh(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        source: String,
        refreshHealth: Bool = false
    ) async {
        refreshGeneration += 1
        let generation = refreshGeneration

        let refreshKey = Self.refreshKey(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            source: source,
            refreshHealth: refreshHealth
        )

        if !refreshHealth, refreshKey == lastCompletedRefreshKey {
            return
        }

        if let inFlightRefreshTask {
            await inFlightRefreshTask.value
            if !refreshHealth, refreshKey == lastCompletedRefreshKey {
                return
            }
        }

        let task = Task { @MainActor in
            let dayActivities = DailyStateSnapshotBuilder.activities(on: selectedDate, from: plannedActivities)

            if refreshHealth {
                await healthManager.loadHealthData(
                    for: selectedDate,
                    plannedActivities: dayActivities
                )
            }

            await CoachUnderstandingService.refresh(
                healthManager: healthManager,
                through: selectedDate
            )

            let previousRefreshReason = lastRefreshReason
            refreshFromCurrentState(
                selectedDate: selectedDate,
                dayActivities: dayActivities,
                allPlannedActivities: plannedActivities,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                source: source
            )

            guard generation == self.refreshGeneration else {
                lastRefreshReason = previousRefreshReason
                #if DEBUG
                HealthRefreshGuardLog.logStaleCoachRefreshDropped(
                    generation: generation,
                    currentGeneration: self.refreshGeneration,
                    source: source
                )
                #endif
                return
            }

            lastCompletedRefreshKey = refreshKey
        }

        inFlightRefreshTask = task
        await task.value
        inFlightRefreshTask = nil
    }

    func invalidateCompletedRefreshCache() {
        lastCompletedRefreshKey = nil
    }

    private static func refreshKey(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        source: String,
        refreshHealth: Bool
    ) -> String {
        let day = Int(Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970 / 86_400)
        return [
            source,
            refreshHealth ? "health" : "cached",
            "\(day)",
            PlannedActivityRefreshSignature.make(from: plannedActivities)
        ].joined(separator: "#")
    }

    func refreshFromCurrentState(
        selectedDate: Date,
        dayActivities: [PlannedActivity],
        allPlannedActivities: [PlannedActivity]? = nil,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        source: String
    ) {
        let coachActivities = allPlannedActivities ?? dayActivities
        let dailySnapshot = DailyStateSnapshotBuilder.build(
            selectedDate: selectedDate,
            dayActivities: dayActivities,
            allPlannedActivities: coachActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            source: source
        )
        Self.logTomorrowPipeline(
            selectedDate: dailySnapshot.selectedDate,
            allActivities: dailySnapshot.allPlannedActivities,
            source: source
        )

        Self.logInputSeed(
            source: source,
            selectedDate: dailySnapshot.selectedDate,
            dayActivities: dailySnapshot.dayActivities,
            coachActivities: dailySnapshot.allPlannedActivities,
            metrics: dailySnapshot.nutritionMetrics,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )

        CoachObservationStore.recordToday(
            from: healthManager,
            date: selectedDate
        )
        CoachUnderstandingService.evaluateBeliefs()

        nutritionViewModel.updateNutrition(
            metrics: dailySnapshot.nutritionMetrics,
            profile: dailySnapshot.profile,
            plannedActivities: dailySnapshot.dayActivities,
            recoveryContext: dailySnapshot.recoveryContext,
            referenceDate: selectedDate,
            debugSource: "CoachInputProvider.\(source)"
        )

        guard let snapshot = nutritionViewModel.coachMetricsSnapshot else {
            coachCoordinator.updateInput(nil)
            _ = coachCoordinator.recomputeIfNeeded(reason: source)
            lastInput = nil
            lastRefreshReason = source
            return
        }

        let input = dailySnapshot.makeCoachInput(
            from: snapshot,
            source: "CoachInputProvider.\(source)"
        )

        coachCoordinator.updateInput(input)
        let nextState = coachCoordinator.recomputeIfNeeded(reason: source)
        Self.logDecisionRefresh(
            source: source,
            input: input,
            state: nextState
        )
        lastInput = input
        lastRefreshReason = source
    }

    static func activities(on date: Date, from activities: [PlannedActivity]) -> [PlannedActivity] {
        DailyStateSnapshotBuilder.activities(on: date, from: activities)
    }

    private static func logInputSeed(
        source: String,
        selectedDate: Date,
        dayActivities: [PlannedActivity],
        coachActivities: [PlannedActivity],
        metrics: DailyNutritionMetrics,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel
    ) {
        #if DEBUG
        let current = nutritionViewModel.currentMetrics
        let coach = nutritionViewModel.coachMetricsSnapshot?.nutritionContext
        CoachLogger.trace(
            "[CoachInputTrace]",
            """
            source=\(source) selectedDate=\(selectedDate) dayActivities=\(dayActivities.count) coachActivities=\(coachActivities.count) seedCalories=\(String(format: "%.0f", metrics.calories)) seedProtein=\(String(format: "%.0f", metrics.protein)) seedCarbs=\(String(format: "%.0f", metrics.carbs)) seedWater=\(String(format: "%.2f", metrics.waterLiters)) healthCalories=\(String(format: "%.0f", healthManager.calories)) healthWater=\(String(format: "%.2f", healthManager.waterLiters)) currentCalories=\(String(format: "%.0f", current?.calories ?? -1.0)) currentWater=\(String(format: "%.2f", current?.waterLiters ?? -1.0)) coachCalories=\(String(format: "%.0f", coach?.caloriesCurrent ?? -1.0)) coachWater=\(String(format: "%.2f", coach?.waterCurrent ?? -1.0))
            """
        )
        #endif
    }

    private static func logDecisionRefresh(
        source: String,
        input: CoachInputSnapshot,
        state: CoachState
    ) {
        #if DEBUG
        let nutrition = input.nutritionContext
        let model = input.dayPriorityModel
        CoachLogger.trace(
            "[CoachDecisionTrace]",
            """
            source=\(source) stateID=\(state.id) selectedDate=\(input.selectedDate) now=\(input.now) scenario=\(state.coachIntegrationDebug?.scenario.rawValue ?? "nil") usingCoach=\(state.coachUIPresentation != nil) dayGoal=\(model.dayGoal.rawValue) tomorrowDemand=\(model.tomorrowDemand.rawValue) activeCalories=\(String(format: "%.0f", input.actualLoad.activeCalories)) nutritionCalories=\(String(format: "%.0f", nutrition?.caloriesCurrent ?? -1.0)) nutritionWater=\(String(format: "%.2f", nutrition?.waterCurrent ?? -1.0)) activities=\(input.plannedActivities.count) sourceSnapshot=\(input.metricsSnapshotID?.uuidString ?? "nil")
            """
        )
        #endif
    }

    private static func logTomorrowPipeline(
        selectedDate: Date,
        allActivities: [PlannedActivity],
        source: String
    ) {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else {
            return
        }

        let rawTomorrowActivities = activities(on: tomorrow, from: allActivities)
        let plannedActivitiesTomorrow = rawTomorrowActivities.filter { !$0.isCompleted && !$0.isSkipped }
        let filteredTomorrowActivities = plannedActivitiesTomorrow.filter {
            isMeaningfulTrainingActivity($0)
        }
        let tomorrowContext = CoachDayContextBuilder.build(
            activities: allActivities,
            selectedDate: tomorrow,
            now: Date()
        )
        let tomorrowPlanContext = tomorrowContext.allActivities.isEmpty
            ? nil
            : CoachTomorrowPlanContext(dayContext: tomorrowContext)
        let tomorrowDemand = CoachTomorrowDemandResolver.resolve(tomorrowContext: tomorrowPlanContext)

        CoachLogger.trace(
            "[CoachTomorrowPipelineDebug]",
            """
            source=\(source) rawTomorrowActivities=\(debugActivities(rawTomorrowActivities)) plannedActivitiesTomorrow=\(debugActivities(plannedActivitiesTomorrow)) filteredTomorrowActivities=\(debugActivities(filteredTomorrowActivities)) tomorrowDemand=\(tomorrowDemand.level.rawValue) upcomingTrainingStress=\(tomorrowContext.upcomingTrainingStressScore) selectedTomorrowProtectionTarget=\(tomorrowDemand.primaryTrainingActivity.map(debugActivity) ?? "nil")
            """
        )
    }

    private static func debugActivities(_ activities: [PlannedActivity]) -> String {
        "[" + activities.map(debugActivity).joined(separator: " | ") + "]"
    }

    private static func debugActivity(_ activity: PlannedActivity) -> String {
        "\(activity.title){type=\(activity.type),duration=\(activity.effectiveDurationMinutes),completed=\(activity.isCompleted),skipped=\(activity.isSkipped)}"
    }

    private static func isMeaningfulTrainingActivity(_ activity: PlannedActivity) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let imageName = activity.imageName.lowercased()
        if type == "meal" || type == "drink" || imageName == "hydration" {
            return false
        }
        if type == "workout" || type == "recovery" {
            return true
        }
        return activity.effectiveDurationMinutes >= 20 ||
            title.contains("run") ||
            title.contains("cycling") ||
            title.contains("ride") ||
            title.contains("bike") ||
            title.contains("вел")
    }
}
