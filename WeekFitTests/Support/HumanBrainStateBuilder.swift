import Foundation
@testable import WeekFit

/// Deterministic `HumanBrain.State` for unit tests (bypasses wall-clock `HumanBrain.build`).
enum HumanBrainStateBuilder {

    struct Configuration {
        var currentHour: Int = 10
        var hasAnyFoodLogged: Bool = true
        var energyCoverage: Double = 0.75
        var carbsProgress: Double = 0.6
        var caloriesProgress: Double = 0.55
        var fatsProgress: Double = 0.55
        var waterProgress: Double = 0.7
        var hasWorkoutSoon: Bool = false
        var nextWorkout: PlannedActivity? = nil
        var hoursToNextWorkout: Double? = nil
        var missedItemsCount: Int = 0
        var completedWorkoutsCount: Int? = nil
        var sleep: HumanBrain.SleepState = .okay
        var hydration: HumanBrain.HydrationState = .optimal
        var fuel: HumanBrain.FuelState = .good
        var protein: HumanBrain.ProteinState = .good
        var strain: HumanBrain.StrainState = .normal
        var recovery: HumanBrain.RecoveryState = .stable
        var readiness: HumanBrain.ReadinessState = .good
        var isLateNight: Bool? = nil
        var metrics: DailyNutritionMetrics = CoachMetricsBuilder.metrics()
        var profile: UserNutritionProfile = CoachMetricsBuilder.standardProfile()
        var goals: NutritionGoals = CoachMetricsBuilder.standardGoals
    }

    static func make(_ config: Configuration = Configuration()) -> HumanBrain.State {
        let c = config
        let lateNight = c.isLateNight ?? (c.currentHour >= 22 || c.currentHour < 4)
        let workoutSoon = c.hoursToNextWorkout.map { $0 <= 2.5 } ?? c.hasWorkoutSoon

        let current = HumanBrain.CurrentContext(
            isMorning: c.currentHour >= 5 && c.currentHour < 12,
            isAfternoon: c.currentHour >= 12 && c.currentHour < 18,
            isEvening: c.currentHour >= 18 && c.currentHour < 22,
            isLateNight: lateNight,
            hasFoodLogged: c.hasAnyFoodLogged,
            activeCalories: c.metrics.activeCalories,
            caloriesProgress: c.caloriesProgress,
            proteinProgress: proteinProgress(for: c.protein),
            carbsProgress: c.carbsProgress,
            fatsProgress: c.fatsProgress,
            waterProgress: c.waterProgress,
            expectedWaterProgress: 0.5,
            waterDeltaFromExpected: c.waterProgress - 0.5,
            expectedNutritionProgress: 0.5,
            expectedCaloriesByNow: 1200,
            energyCoverage: c.energyCoverage,
            energyDeficit: max(1200 - c.metrics.calories, 0)
        )

        let nextSnapshot = c.nextWorkout.map(CoachPlannedActivitySnapshot.init)
        let upcoming = nextSnapshot.map { [$0] } ?? []
        let future = HumanBrain.FutureContext(
            upcomingWorkouts: upcoming,
            nextWorkout: nextSnapshot,
            hoursToNextWorkout: c.hoursToNextWorkout,
            hasUpcomingWorkout: nextSnapshot != nil,
            hasWorkoutSoon: workoutSoon
        )

        let completedCount = c.completedWorkoutsCount ?? defaultCompletedCount(for: c.strain)
        let past = HumanBrain.PastContext(
            completedWorkouts: [],
            lastCompletedWorkout: nil,
            missedItemsCount: c.missedItemsCount,
            completedWorkoutsCount: completedCount,
            hasHighActivityLoad: c.metrics.activeCalories > 750 || completedCount >= 2
        )

        return HumanBrain.State(
            now: CoachTestClock.reference,
            currentHour: c.currentHour,
            metrics: c.metrics,
            profile: c.profile,
            baseDayGoals: c.goals,
            fullDayGoals: c.goals,
            smoothedGoals: c.goals,
            activities: upcoming,
            past: past,
            current: current,
            future: future,
            sleep: c.sleep,
            hydration: c.hydration,
            fuel: c.fuel,
            protein: c.protein,
            strain: c.strain,
            recovery: c.recovery,
            readiness: c.readiness,
            hasAnyFoodLogged: c.hasAnyFoodLogged
        )
    }

    static func make(
        currentHour: Int = 10,
        hasAnyFoodLogged: Bool = true,
        energyCoverage: Double = 0.75,
        carbsProgress: Double = 0.6,
        caloriesProgress: Double = 0.55,
        fatsProgress: Double = 0.55,
        waterProgress: Double = 0.7,
        hasWorkoutSoon: Bool = false,
        nextWorkout: PlannedActivity? = nil,
        hoursToNextWorkout: Double? = nil,
        missedItemsCount: Int = 0,
        sleep: HumanBrain.SleepState = .okay,
        hydration: HumanBrain.HydrationState = .optimal,
        fuel: HumanBrain.FuelState = .good,
        protein: HumanBrain.ProteinState = .good,
        strain: HumanBrain.StrainState = .normal,
        recovery: HumanBrain.RecoveryState = .stable,
        readiness: HumanBrain.ReadinessState = .good,
        isLateNight: Bool? = nil,
        metrics: DailyNutritionMetrics = CoachMetricsBuilder.metrics(),
        profile: UserNutritionProfile = CoachMetricsBuilder.standardProfile()
    ) -> HumanBrain.State {
        var config = Configuration()
        config.currentHour = currentHour
        config.hasAnyFoodLogged = hasAnyFoodLogged
        config.energyCoverage = energyCoverage
        config.carbsProgress = carbsProgress
        config.caloriesProgress = caloriesProgress
        config.fatsProgress = fatsProgress
        config.waterProgress = waterProgress
        config.hasWorkoutSoon = hasWorkoutSoon
        config.nextWorkout = nextWorkout
        config.hoursToNextWorkout = hoursToNextWorkout
        config.missedItemsCount = missedItemsCount
        config.sleep = sleep
        config.hydration = hydration
        config.fuel = fuel
        config.protein = protein
        config.strain = strain
        config.recovery = recovery
        config.readiness = readiness
        config.isLateNight = isLateNight
        config.metrics = metrics
        config.profile = profile
        return make(config)
    }

    private static func proteinProgress(for protein: HumanBrain.ProteinState) -> Double {
        switch protein {
        case .good: return 0.9
        case .behind: return 0.7
        case .low: return 0.4
        }
    }

    private static func defaultCompletedCount(for strain: HumanBrain.StrainState) -> Int {
        switch strain {
        case .veryHigh: return 2
        case .high: return 1
        default: return 0
        }
    }
}

enum HumanBrainIntegrationBuilder {

    static func build(
        metrics: DailyNutritionMetrics = CoachMetricsBuilder.metrics(),
        activities: [PlannedActivity] = [],
        profile: UserNutritionProfile = CoachMetricsBuilder.standardProfile(),
        goals: NutritionGoals = CoachMetricsBuilder.standardGoals
    ) -> HumanBrain.State {
        HumanBrain.build(
            metrics: metrics,
            profile: profile,
            fullDayGoals: goals,
            smoothedGoals: goals,
            activities: activities.coachSnapshots()
        )
    }
}

extension HumanBrain.State {
    var testDecision: CoachDecision {
        CoachDecisionEngine.makeDecision(from: self)
    }

    var testInsights: [DynamicInsight] {
        CoachInsightFactory.generateInsights(brain: self, decision: testDecision)
    }
}
