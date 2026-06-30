import Foundation

enum CoachActualLoadSource: String, Hashable {
    case healthKitSamplesWithAppGoalEstimate
    case nutritionMetricsFallback
}

enum CoachPlanSource: String, Hashable {
    case swiftDataPlannedActivity
}

struct CoachActualLoadSnapshot: Hashable {
    let source: CoachActualLoadSource
    let activeCalories: Double
    let exerciseMinutes: Int?
    let standHours: Int?
    let activityGoalCalories: Double?
    let activityProgress: Double?

    static func fallback(from brain: HumanBrain.State) -> CoachActualLoadSnapshot {
        return CoachActualLoadSnapshot(
            source: .nutritionMetricsFallback,
            activeCalories: brain.metrics.activeCalories,
            exerciseMinutes: nil,
            standHours: nil,
            activityGoalCalories: nil,
            activityProgress: nil
        )
    }
}

struct CoachLoadSourceDebug: Hashable {
    let activityCircleActiveCalories: Double
    let activityCircleExerciseMinutes: Int?
    let activityCircleProgress: Double?
    let plannedCompletedActivities: Int
    let syncedAppleWorkouts: Int
    let manualCompletedActivities: Int
    let loadSourceUsed: CoachActualLoadSource
    let discrepancyDetected: Bool
    let discrepancyReason: String?

    var debugLines: [String] {
        [
            "CoachLoadSourceDebug.healthKitSampleActiveCalories=\(Int(activityCircleActiveCalories.rounded()))",
            "CoachLoadSourceDebug.healthKitSampleExerciseMinutes=\(exerciseMinutesText)",
            "CoachLoadSourceDebug.estimatedActivityProgress=\(activityCircleProgress.map { String(format: "%.2f", $0) } ?? "nil")",
            "CoachLoadSourceDebug.plannedCompletedActivities=\(plannedCompletedActivities)",
            "CoachLoadSourceDebug.syncedAppleWorkouts=\(syncedAppleWorkouts)",
            "CoachLoadSourceDebug.manualCompletedActivities=\(manualCompletedActivities)",
            "CoachLoadSourceDebug.loadSourceUsed=\(loadSourceUsed.rawValue)",
            "CoachLoadSourceDebug.discrepancyDetected=\(discrepancyDetected)",
            "CoachLoadSourceDebug.discrepancyReason=\(discrepancyReason ?? "none")"
        ]
    }

    private var exerciseMinutesText: String {
        activityCircleExerciseMinutes.map(String.init) ?? "nil"
    }
}

struct CoachInputSnapshot {
    let metricsSnapshotID: UUID?
    let selectedDate: Date
    let now: Date
    let brain: HumanBrain.State
    let plannedActivities: [PlannedActivity]
    let actualLoad: CoachActualLoadSnapshot
    let planSource: CoachPlanSource
    let dayContext: CoachDayContext
    let recoveryContext: CoachRecoveryContext
    let nutritionContext: CoachNutritionContext?
    let isHealthAccessGranted: Bool
    let source: String

    var dayPriorityModel: DayPriorityModel {
        DayPriorityModel.build(from: self)
    }

    init(
        metricsSnapshotID: UUID? = nil,
        selectedDate: Date,
        now: Date = Date(),
        brain: HumanBrain.State,
        plannedActivities: [PlannedActivity],
        actualLoad: CoachActualLoadSnapshot? = nil,
        planSource: CoachPlanSource = .swiftDataPlannedActivity,
        dayContext: CoachDayContext? = nil,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext?,
        isHealthAccessGranted: Bool = true,
        source: String
    ) {
        self.metricsSnapshotID = metricsSnapshotID
        self.selectedDate = selectedDate
        self.now = now
        self.brain = brain
        self.plannedActivities = plannedActivities
        self.actualLoad = actualLoad ?? CoachActualLoadSnapshot.fallback(from: brain)
        self.planSource = planSource
        let resolvedDayContext = dayContext ?? CoachDayContextBuilder.build(
            activities: plannedActivities,
            selectedDate: selectedDate,
            now: now
        )
        self.dayContext = resolvedDayContext
        self.recoveryContext = recoveryContext
        self.nutritionContext = nutritionContext
        self.isHealthAccessGranted = isHealthAccessGranted
        self.source = source
    }
}
