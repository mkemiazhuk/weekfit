import Foundation
import SwiftUI

enum HumanBrain {
    
    struct State {
        let now: Date
        let currentHour: Int
        
        let metrics: DailyNutritionMetrics
        let profile: UserNutritionProfile
        let baseDayGoals: NutritionGoals
        let fullDayGoals: NutritionGoals
        let smoothedGoals: NutritionGoals
        let activities: [PlannedActivity]
        
        let past: PastContext
        let current: CurrentContext
        let future: FutureContext
        
        let sleep: SleepState
        let hydration: HydrationState
        let fuel: FuelState
        let protein: ProteinState
        let strain: StrainState
        let recovery: RecoveryState
        let readiness: ReadinessState
        
        let hasAnyFoodLogged: Bool
    }
    
    struct PastContext {
        let completedWorkouts: [PlannedActivity]
        let lastCompletedWorkout: PlannedActivity?
        let missedItemsCount: Int
        let completedWorkoutsCount: Int
        let hasHighActivityLoad: Bool
    }
    
    struct CurrentContext {
        let isMorning: Bool
        let isAfternoon: Bool
        let isEvening: Bool
        let isLateNight: Bool
        
        let hasFoodLogged: Bool
        let activeCalories: Double
        
        let caloriesProgress: Double
        let proteinProgress: Double
        let carbsProgress: Double
        let fatsProgress: Double
        let waterProgress: Double
        
        let expectedWaterProgress: Double
        let waterDeltaFromExpected: Double
        
        let expectedNutritionProgress: Double
        let expectedCaloriesByNow: Double
        let energyCoverage: Double
        let energyDeficit: Double
    }
    
    struct FutureContext {
        let upcomingWorkouts: [PlannedActivity]
        let nextWorkout: PlannedActivity?
        let hoursToNextWorkout: Double?
        let hasUpcomingWorkout: Bool
        let hasWorkoutSoon: Bool
    }
    
    enum SleepState {
        case unknown
        case strong
        case okay
        case short
        case veryShort
    }
    
    enum HydrationState {
        case depleted
        case behind
        case optimal
        case completed
        case excessive
    }
    
    enum FuelState {
        case good
        case light
        case underfueled
        case overfueled
    }
    
    enum ProteinState {
        case good
        case behind
        case low
    }
    
    enum StrainState {
        case low
        case normal
        case high
        case veryHigh
    }
    
    enum RecoveryState {
        case strong
        case stable
        case vulnerable
        case compromised
    }
    
    enum ReadinessState {
        case excellent
        case good
        case moderate
        case low
        case compromised
    }
    
    static func build(
        metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile,
        baseDayGoals: NutritionGoals? = nil,
        fullDayGoals: NutritionGoals,
        smoothedGoals: NutritionGoals,
        activities: [PlannedActivity]
    ) -> State {
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let hasFood = metrics.protein > 0 || metrics.carbs > 0 || metrics.calories > 0
        
        let past = buildPastContext(
            now: now,
            calendar: calendar,
            metrics: metrics,
            activities: activities
        )
        
        let current = buildCurrentContext(
            currentHour: currentHour,
            metrics: metrics,
            smoothedGoals: smoothedGoals,
            hasFood: hasFood
        )
        
        let future = buildFutureContext(
            now: now,
            activities: activities
        )
        
        let sleep = evaluateSleep(metrics: metrics)
        let hydration = evaluateHydration(current: current)
        let protein = evaluateProtein(current: current)
        let strain = evaluateStrain(metrics: metrics, past: past)
        
        let fuel = evaluateFuel(
            current: current,
            future: future,
            strain: strain,
            sleep: sleep,
            currentHour: currentHour
        )
        
        let recovery = evaluateRecovery(
            sleep: sleep,
            hydration: hydration,
            fuel: fuel,
            strain: strain,
            past: past
        )
        
        let readiness = evaluateReadiness(
            sleep: sleep,
            hydration: hydration,
            fuel: fuel,
            protein: protein,
            strain: strain,
            recovery: recovery,
            future: future
        )
        
        return State(
            now: now,
            currentHour: currentHour,
            metrics: metrics,
            profile: profile,
            baseDayGoals: baseDayGoals ?? fullDayGoals,
            fullDayGoals: fullDayGoals,
            smoothedGoals: smoothedGoals,
            activities: activities,
            past: past,
            current: current,
            future: future,
            sleep: sleep,
            hydration: hydration,
            fuel: fuel,
            protein: protein,
            strain: strain,
            recovery: recovery,
            readiness: readiness,
            hasAnyFoodLogged: hasFood
        )
    }
}

extension HumanBrain.State {
    func refreshedForCurrentLocalTime(activities currentActivities: [PlannedActivity]? = nil) -> HumanBrain.State {
        HumanBrain.build(
            metrics: metrics,
            profile: profile,
            baseDayGoals: baseDayGoals,
            fullDayGoals: fullDayGoals,
            smoothedGoals: smoothedGoals,
            activities: currentActivities ?? activities
        )
        .replacingBrainStates(
            sleep: sleep,
            recovery: recovery,
            readiness: readiness
        )
    }

    func replacingBrainStates(
        sleep: HumanBrain.SleepState? = nil,
        recovery: HumanBrain.RecoveryState? = nil,
        readiness: HumanBrain.ReadinessState? = nil
    ) -> HumanBrain.State {
        HumanBrain.State(
            now: now,
            currentHour: currentHour,
            metrics: metrics,
            profile: profile,
            baseDayGoals: baseDayGoals,
            fullDayGoals: fullDayGoals,
            smoothedGoals: smoothedGoals,
            activities: activities,
            past: past,
            current: current,
            future: future,
            sleep: sleep ?? self.sleep,
            hydration: hydration,
            fuel: fuel,
            protein: protein,
            strain: strain,
            recovery: recovery ?? self.recovery,
            readiness: readiness ?? self.readiness,
            hasAnyFoodLogged: hasAnyFoodLogged
        )
    }
}

// MARK: - Builders

private extension HumanBrain {
    
    static func buildPastContext(
        now: Date,
        calendar: Calendar,
        metrics: DailyNutritionMetrics,
        activities: [PlannedActivity]
    ) -> PastContext {
        
        let todayWorkouts = activities.filter {
            $0.type.lowercased() == "workout"
        }
        
        let completedWorkouts = todayWorkouts.filter {
            $0.isCompleted
        }
        
        let lastCompletedWorkout = completedWorkouts
            .sorted { $0.date > $1.date }
            .first
        
        let missedItemsCount = activities.filter { activity in
            let eventEndDate = calendar.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date
            
            return !activity.isCompleted &&
            !activity.isSkipped &&
            now > eventEndDate
        }.count
        
        return PastContext(
            completedWorkouts: completedWorkouts,
            lastCompletedWorkout: lastCompletedWorkout,
            missedItemsCount: missedItemsCount,
            completedWorkoutsCount: completedWorkouts.count,
            hasHighActivityLoad: metrics.activeCalories > 750.0 || completedWorkouts.count >= 2
        )
    }
    
    static func buildCurrentContext(
        currentHour: Int,
        metrics: DailyNutritionMetrics,
        smoothedGoals: NutritionGoals,
        hasFood: Bool
    ) -> CurrentContext {
        
        let waterProgress = safeRatio(
            metrics.waterLiters,
            smoothedGoals.waterLiters
        )
        
        let expectedWater = expectedHydrationProgress(
            for: currentHour
        )
        
        let expectedNutrition = expectedNutritionProgress(
            for: currentHour
        )
        
        let expectedCaloriesByNow = max(
            smoothedGoals.calories * expectedNutrition,
            1.0
        )
        
        let energyCoverage = safeRatio(
            metrics.calories,
            expectedCaloriesByNow
        )
        
        let energyDeficit = max(
            expectedCaloriesByNow - metrics.calories,
            0.0
        )
        
        return CurrentContext(
            isMorning: currentHour >= 5 && currentHour < 12,
            isAfternoon: currentHour >= 12 && currentHour < 18,
            isEvening: currentHour >= 18 && currentHour < 22,
            isLateNight: currentHour >= 22 || currentHour < 4,
            hasFoodLogged: hasFood,
            activeCalories: metrics.activeCalories,
            caloriesProgress: safeRatio(metrics.calories, smoothedGoals.calories),
            proteinProgress: safeRatio(metrics.protein, smoothedGoals.protein),
            carbsProgress: safeRatio(metrics.carbs, smoothedGoals.carbs),
            fatsProgress: safeRatio(metrics.fats, smoothedGoals.fats),
            waterProgress: waterProgress,
            expectedWaterProgress: expectedWater,
            waterDeltaFromExpected: waterProgress - expectedWater,
            expectedNutritionProgress: expectedNutrition,
            expectedCaloriesByNow: expectedCaloriesByNow,
            energyCoverage: energyCoverage,
            energyDeficit: energyDeficit
        )
    }
    
    static func buildFutureContext(
        now: Date,
        activities: [PlannedActivity]
    ) -> FutureContext {
        
        let upcoming = activities
            .filter {
                $0.type.lowercased() == "workout" &&
                !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date >= now
            }
            .sorted {
                $0.date < $1.date
            }
        
        let nextWorkout = upcoming.first
        
        let hours = nextWorkout.map {
            $0.date.timeIntervalSince(now) / 3600.0
        }
        
        let soon = hours.map {
            $0 <= 2.5
        } ?? false
        
        return FutureContext(
            upcomingWorkouts: upcoming,
            nextWorkout: nextWorkout,
            hoursToNextWorkout: hours,
            hasUpcomingWorkout: nextWorkout != nil,
            hasWorkoutSoon: soon
        )
    }
}

// MARK: - Evaluators

private extension HumanBrain {
    
    static func evaluateSleep(
        metrics: DailyNutritionMetrics
    ) -> SleepState {
        
        guard metrics.sleepHours > 0 else {
            return .unknown
        }
        
        if metrics.sleepHours < 5.5 {
            return .veryShort
        }
        
        if metrics.sleepHours < 6.4 {
            return .short
        }
        
        if metrics.sleepHours < 7.2 {
            return .okay
        }
        
        return .strong
    }
    
    static func evaluateHydration(
        current: CurrentContext
    ) -> HydrationState {
        
        if current.waterProgress >= 1.30 {
            return .excessive
        }
        
        if current.waterProgress >= 1.00 {
            return .completed
        }
        
        if current.waterProgress >= 0.85 || current.waterDeltaFromExpected >= -0.08 {
            return .optimal
        }
        
        let trajectoryAdjustedProgress = current.expectedWaterProgress > 0
            ? current.waterProgress / current.expectedWaterProgress
            : current.waterProgress

        if trajectoryAdjustedProgress < 0.20 || current.waterDeltaFromExpected < -0.25 {
            return .depleted
        }
        
        return .behind
    }
    
    static func evaluateProtein(
        current: CurrentContext
    ) -> ProteinState {
        
        if current.proteinProgress < 0.55 {
            return .low
        }
        
        if current.proteinProgress < 0.82 {
            return .behind
        }
        
        return .good
    }
    
    static func evaluateStrain(
        metrics: DailyNutritionMetrics,
        past: PastContext
    ) -> StrainState {
        
        if metrics.activeCalories > 900.0 || past.completedWorkoutsCount >= 2 {
            return .veryHigh
        }
        
        if metrics.activeCalories > 550.0 || past.completedWorkoutsCount == 1 {
            return .high
        }
        
        if metrics.activeCalories < 120.0 {
            return .low
        }
        
        return .normal
    }
    
    static func evaluateRecovery(
        sleep: SleepState,
        hydration: HydrationState,
        fuel: FuelState,
        strain: StrainState,
        past: PastContext
    ) -> RecoveryState {
        
        if sleep == .veryShort && (strain == .high || strain == .veryHigh) {
            return .compromised
        }
        
        if hydration == .depleted && strain == .veryHigh {
            return .compromised
        }
        
        if fuel == .underfueled && strain == .veryHigh {
            return .compromised
        }
        
        if sleep == .short ||
            hydration == .depleted ||
            fuel == .underfueled ||
            strain == .veryHigh ||
            past.hasHighActivityLoad {
            return .vulnerable
        }
        
        if sleep == .strong &&
            (hydration == .optimal || hydration == .completed) &&
            fuel == .good {
            return .strong
        }
        
        return .stable
    }
    
    static func evaluateReadiness(
        sleep: SleepState,
        hydration: HydrationState,
        fuel: FuelState,
        protein: ProteinState,
        strain: StrainState,
        recovery: RecoveryState,
        future: FutureContext
    ) -> ReadinessState {
        
        if recovery == .compromised {
            return .compromised
        }
        
        if recovery == .vulnerable &&
            future.hasWorkoutSoon &&
            (fuel == .underfueled || hydration == .depleted) {
            return .low
        }
        
        if sleep == .veryShort ||
            hydration == .depleted ||
            fuel == .underfueled {
            return .low
        }
        
        if sleep == .short ||
            hydration == .behind ||
            protein == .behind ||
            strain == .high {
            return .moderate
        }
        
        if sleep == .strong &&
            (hydration == .optimal || hydration == .completed) &&
            fuel == .good &&
            protein == .good &&
            strain != .veryHigh {
            return .excellent
        }
        
        return .good
    }
}

// MARK: - Thresholds

extension HumanBrain {
    
    struct EnergyThresholds {
        let critical: Double
        let low: Double
        let optimal: Double
        let excessive: Double
    }
    
    static func energyThresholds(
        strain: StrainState,
        sleep: SleepState,
        hasWorkoutSoon: Bool,
        hour: Int
    ) -> EnergyThresholds {
        
        let optimal = dynamicCoverageThreshold(
            strain: strain,
            sleep: sleep,
            hasWorkoutSoon: hasWorkoutSoon,
            hour: hour
        )
        
        let critical = max(optimal * 0.55, 0.28)
        let low = max(optimal * 0.82, critical + 0.08)
        
        // ИСПРАВЛЕНО: Порог избытка энергии теперь динамический.
        // Вечером (после 18:00) лимит жестче (1.15), так как метаболизм замедляется и зажоры ломают сон.
        let excessive = hour >= 18 ? 1.15 : 1.35
        
        return EnergyThresholds(
            critical: critical,
            low: low,
            optimal: optimal,
            excessive: excessive
        )
    }

    static func evaluateFuel(
        current: CurrentContext,
        future: FutureContext,
        strain: StrainState,
        sleep: SleepState,
        currentHour: Int
    ) -> FuelState {
        
        let thresholds = energyThresholds(
            strain: strain,
            sleep: sleep,
            hasWorkoutSoon: future.hasWorkoutSoon,
            hour: currentHour
        )
        
        // 🚀 ИСПРАВЛЕНО: Защита от внутридневных циркадных колебаний.
        // Экстренный статус .overfueled включаем ТОЛЬКО если реальный прогресс калорий
        // от ПОЛНОЙ дневной нормы превысил 115% (caloriesProgress >= 1.15)
        // ИЛИ если углеводы улетели в глубокий абсолютный профицит (carbsProgress >= 1.30).
        // Мы полностью убрали отсюда "current.energyCoverage", который ломал логику ночью!
        let isTotalCaloriesOverfueled = current.caloriesProgress >= 1.15
        let isCarbsOverfueled = current.carbsProgress >= 1.30
        
        if isTotalCaloriesOverfueled || isCarbsOverfueled {
            return .overfueled
        }
        
        // 2. Проверяем критический недобор
        if current.energyCoverage < thresholds.critical {
            return .underfueled
        }
        
        if future.hasWorkoutSoon &&
            current.carbsProgress < 0.45 &&
            current.energyCoverage < thresholds.low {
            return .underfueled
        }
        
        if current.energyCoverage < thresholds.low {
            return .light
        }
        
        return .good
    }
    
    static func dynamicCoverageThreshold(
        strain: StrainState,
        sleep: SleepState,
        hasWorkoutSoon: Bool,
        hour: Int
    ) -> Double {
        
        var threshold = 0.72
        
        if hour < 10 {
            threshold -= 0.18
        }
        
        if hour >= 15 {
            threshold += 0.04
        }
        
        if strain == .high {
            threshold += 0.08
        }
        
        if strain == .veryHigh {
            threshold += 0.15
        }
        
        if hasWorkoutSoon {
            threshold += 0.12
        }
        
        if sleep == .short {
            threshold += 0.05
        }
        
        if sleep == .veryShort {
            threshold += 0.10
        }
        
        return min(
            max(threshold, 0.35),
            0.95
        )
    }
    
    static func expectedNutritionProgress(
        for hour: Int
    ) -> Double {
        
        switch hour {
        case 5..<9:
            return 0.18
        case 9..<12:
            return 0.35
        case 12..<15:
            return 0.58
        case 15..<18:
            return 0.74
        case 18..<21:
            return 0.90
        default:
            return 1.0
        }
    }
    
    static func expectedHydrationProgress(
        for hour: Int
    ) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.08),
            (8, 0.18),
            (12, 0.45),
            (16, 0.68),
            (20, 0.90),
            (22, 1.00)
        ])
    }
    
    static func safeRatio(
        _ value: Double,
        _ target: Double
    ) -> Double {
        
        guard target > 0 else {
            return 0
        }
        
        return value / target
    }

    private static func interpolate(hour: Int, points: [(Int, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 1 }
        if hour <= first.0 { return first.1 }
        if hour >= last.0 { return last.1 }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let next = points[index]
            guard hour <= next.0 else { continue }
            let span = Double(next.0 - previous.0)
            let progress = span > 0 ? Double(hour - previous.0) / span : 1
            return previous.1 + ((next.1 - previous.1) * progress)
        }

        return last.1
    }
}
