import Foundation
@testable import WeekFit

enum CoachNarrativeMatrixStateBuilder {

    private static var referenceDay: Date { CoachTestClock.reference }

    static func date(for time: CoachNarrativeTimeSlot, on base: Date = CoachTestClock.reference) -> Date {
        Calendar.current.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: base
        ) ?? base
    }

    static func tomorrow(hour: Int, minute: Int = 0, from base: Date = CoachTestClock.reference) -> Date {
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrowDate) ?? tomorrowDate
    }

    static func makeState(
        context: CoachNarrativeMatrixContext,
        activities: [PlannedActivity],
        currentDate: Date,
        nutrition: CoachNutritionContext? = nil,
        activeCalories: Double = 240,
        completedWorkoutsCount: Int? = nil,
        exerciseMinutes: Int? = nil
    ) -> CoachState {
        let profile = recoveryProfile(for: context)
        let nutritionContext = nutrition ?? nutritionContext(for: context, at: currentDate)
        let resolvedRecoveryPercent = context.recoveryBand.percent
        let resolvedSleepHours: Double = {
            if context.recoveryDriver == .missingSleepData {
                // Readiness gate requires sleep hours; scenario context still marks sleep as missing for audit.
                return 7.2
            }
            return profile.sleepHours
        }()

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: currentDate)
        brainConfig.hasAnyFoodLogged = (nutritionContext.mealsCount ?? 0) > 0
        brainConfig.waterProgress = nutritionContext.waterGoal > 0
            ? nutritionContext.waterCurrent / nutritionContext.waterGoal
            : 1
        brainConfig.hasWorkoutSoon = activities.contains { !$0.isCompleted && !$0.isSkipped }
        brainConfig.nextWorkout = activities.first { !$0.isCompleted && !$0.isSkipped }
        brainConfig.hoursToNextWorkout = brainConfig.nextWorkout.map {
            max(0, $0.date.timeIntervalSince(currentDate) / 3600)
        }
        brainConfig.hydration = hydrationBrainState(for: context)
        brainConfig.fuel = fuelBrainState(for: context)
        brainConfig.sleep = profile.sleep
        brainConfig.recovery = profile.recovery
        brainConfig.readiness = profile.readiness
        brainConfig.completedWorkoutsCount = completedWorkoutsCount
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: nutritionContext.proteinCurrent,
            carbs: nutritionContext.carbsCurrent,
            calories: nutritionContext.caloriesCurrent,
            waterLiters: nutritionContext.waterCurrent,
            activeCalories: activeCalories,
            sleepHours: resolvedSleepHours
        )

        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: currentDate,
            now: currentDate
        )
        let input = CoachInputSnapshot(
            selectedDate: currentDate,
            now: currentDate,
            brain: brain,
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: activeCalories,
                exerciseMinutes: exerciseMinutes,
                standHours: nil,
                activityGoalCalories: nil,
                activityProgress: nil
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: resolvedRecoveryPercent,
                sleepHours: resolvedSleepHours
            ),
            nutritionContext: nutritionContext,
            source: "CoachNarrativeMatrix"
        )
        let guidance = CoachEngineV3.decide(
            from: brain.refreshedForCurrentLocalTime(activities: activities),
            plannedActivities: activities,
            selectedDate: referenceDay,
            dayContext: dayContext,
            recoveryContext: input.recoveryContext,
            nutritionContext: nutritionContext
        )

        return CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: currentDate
        )
    }

    static func activity(
        type: String,
        title: String,
        minutesFromNow: Int,
        duration: Int,
        icon: String,
        completed: Bool = false,
        skipped: Bool = false,
        baseDate: Date,
        source: String = "planner",
        healthKitUUID: String? = nil,
        actualDurationMinutes: Int? = nil
    ) -> PlannedActivity {
        let activity = PlannedActivity(
            date: CoachTestClock.offset(minutes: minutesFromNow, from: baseDate),
            type: type,
            title: title,
            durationMinutes: duration,
            icon: icon,
            imageName: icon,
            colorRed: 0.3,
            colorGreen: 0.6,
            colorBlue: 0.9,
            isCompleted: completed,
            source: source
        )
        activity.isSkipped = skipped
        activity.healthKitWorkoutUUID = healthKitUUID
        activity.actualDurationMinutes = actualDurationMinutes
        return activity
    }

    static func nutritionContext(for context: CoachNarrativeMatrixContext, at date: Date) -> CoachNutritionContext {
        switch context.nutrition {
        case .emptyEarlyMorning, .emptyAfternoon:
            return nutrition(
                water: context.hydration == .noWaterEarlyMorning ? 0 : 1.2,
                calories: 0,
                protein: 0,
                carbs: 0
            )
        case .underFueledBeforeWorkout, .underFueledAfterWorkout:
            return nutrition(water: 1.0, calories: 850, protein: 35, carbs: 70)
        case .strongAdherence:
            return nutrition(water: 2.4, calories: 2_700, protein: 210, carbs: 260)
        case .highCaloriesLowProtein:
            return nutrition(water: 1.8, calories: 2_400, protein: 45, carbs: 280)
        case .missingData:
            return CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 0,
                proteinCurrent: 0,
                proteinGoal: 0,
                carbsCurrent: 0,
                carbsGoal: 0,
                fatsCurrent: 0,
                fatsGoal: 0,
                waterCurrent: 0,
                waterGoal: 0,
                mealsCount: nil,
                lastMealTime: nil
            )
        case .normal:
            switch context.hydration {
            case .noWaterEarlyMorning, .noWaterAfternoon, .heatDayLowWater:
                return nutrition(
                    water: context.hydration == .heatDayLowWater ? 0.3 : 0,
                    calories: 1_200,
                    protein: 60,
                    carbs: 130
                )
            case .lowBeforeEndurance, .lowBeforeSauna:
                return nutrition(water: 0.4, calories: 1_400, protein: 70, carbs: 150)
            default:
                return nutrition()
            }
        }
    }

    static func nutrition(
        water: Double = 1.6,
        calories: Double = 1_400,
        protein: Double = 80,
        carbs: Double = 150
    ) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: CoachMetricsBuilder.standardGoals.calories,
            proteinCurrent: protein,
            proteinGoal: CoachMetricsBuilder.standardGoals.protein,
            carbsCurrent: carbs,
            carbsGoal: CoachMetricsBuilder.standardGoals.carbs,
            fatsCurrent: 40,
            fatsGoal: CoachMetricsBuilder.standardGoals.fats,
            waterCurrent: water,
            waterGoal: CoachMetricsBuilder.standardGoals.waterLiters,
            mealsCount: calories > 0 ? 1 : 0,
            lastMealTime: CoachTestClock.reference
        )
    }

    static func activities(for context: CoachNarrativeMatrixContext, at decisionDate: Date) -> [PlannedActivity] {
        var items: [PlannedActivity] = []

        func minutesUntilStart(_ timing: CoachNarrativeActivityTiming) -> Int {
            switch timing {
            case .activeNow: return -5
            case .startsIn15Min: return 15
            case .startsIn45Min: return 45
            case .startsIn2Hours: return 120
            case .startsIn6Hours: return 360
            case .completed30MinAgo: return -60
            case .completed3HoursAgo: return -240
            }
        }

        func appendPrimary(_ shape: CoachNarrativeActivityShape, timing: CoachNarrativeActivityTiming?) {
            let resolvedTiming = timing ?? .activeNow
            let offset = minutesUntilStart(resolvedTiming)
            let completed = resolvedTiming == .completed30MinAgo || resolvedTiming == .completed3HoursAgo ||
                [.easyWalkCompleted, .hardRunCompleted, .longRideCompleted, .strengthCompleted,
                 .syncedWalkNoPlanMatch, .syncedWalkFutureCoffeeCandidate, .syncedWalkFuturePlannedWalk].contains(shape)

            switch shape {
            case .none:
                break
            case .easyWalkPlanned, .easyWalkCompleted, .activeWalk:
                items.append(activity(
                    type: "walking", title: "Walk", minutesFromNow: offset, duration: 30,
                    icon: "figure.walk", completed: completed, baseDate: decisionDate,
                    source: shape == .activeWalk ? "today" : "planner"
                ))
            case .runPlanned, .hardRunCompleted, .activeRun:
                items.append(activity(
                    type: "running", title: shape == .hardRunCompleted ? "Hard run" : "Run",
                    minutesFromNow: offset, duration: shape == .hardRunCompleted ? 90 : 60,
                    icon: "figure.run", completed: completed, baseDate: decisionDate,
                    source: shape == .activeRun ? "today" : "planner"
                ))
            case .longRidePlanned, .longRideCompleted, .activeLongRide:
                items.append(activity(
                    type: "cycling", title: "Long ride", minutesFromNow: offset, duration: 150,
                    icon: "bicycle", completed: completed, baseDate: decisionDate,
                    source: shape == .activeLongRide ? "today" : "planner"
                ))
            case .strengthPlanned, .strengthCompleted, .activeStrength:
                items.append(activity(
                    type: "strength", title: "Strength", minutesFromNow: offset, duration: 70,
                    icon: "dumbbell.fill", completed: completed, baseDate: decisionDate,
                    source: shape == .activeStrength ? "today" : "planner"
                ))
            case .saunaPlanned, .activeSauna:
                items.append(activity(
                    type: "sauna", title: "Sauna", minutesFromNow: offset, duration: 30,
                    icon: "flame.fill", completed: completed, baseDate: decisionDate,
                    source: shape == .activeSauna ? "today" : "planner"
                ))
            case .syncedWalkNoPlanMatch:
                items.append(activity(
                    type: "workout", title: "Walk", minutesFromNow: -120, duration: 35,
                    icon: "figure.walk", completed: true, baseDate: decisionDate,
                    source: "appleWorkout", healthKitUUID: UUID().uuidString, actualDurationMinutes: 35
                ))
            case .syncedWalkFutureCoffeeCandidate:
                items.append(activity(
                    type: "workout", title: "Walk", minutesFromNow: -90, duration: 30,
                    icon: "figure.walk", completed: true, baseDate: decisionDate,
                    source: "appleWorkout", healthKitUUID: UUID().uuidString, actualDurationMinutes: 30
                ))
                items.append(activity(
                    type: "meal", title: "Coffee", minutesFromNow: 120, duration: 1,
                    icon: "cup.and.saucer.fill", completed: false, baseDate: decisionDate,
                    source: "nutritionLog"
                ))
            case .syncedWalkFuturePlannedWalk:
                items.append(activity(
                    type: "workout", title: "Walk", minutesFromNow: -100, duration: 32,
                    icon: "figure.walk", completed: true, baseDate: decisionDate,
                    source: "appleWorkout", healthKitUUID: UUID().uuidString, actualDurationMinutes: 32
                ))
                items.append(activity(
                    type: "walking", title: "Walk", minutesFromNow: 180, duration: 30,
                    icon: "figure.walk", completed: false, baseDate: decisionDate
                ))
            case .skippedActivity:
                items.append(activity(
                    type: "running", title: "Run", minutesFromNow: -30, duration: 60,
                    icon: "figure.run", skipped: true, baseDate: decisionDate
                ))
            }
        }

        appendPrimary(context.activity, timing: context.activityTiming)

        switch context.planner {
        case .empty:
            break
        case .light:
            if context.activity == .none {
                items.append(activity(type: "walking", title: "Morning walk", minutesFromNow: 120, duration: 30, icon: "figure.walk", baseDate: decisionDate))
            }
        case .hardSingle:
            if !items.contains(where: { $0.title.localizedCaseInsensitiveContains("run") || $0.type == "running" }) {
                items.append(activity(type: "running", title: "Run", minutesFromNow: 180, duration: 60, icon: "figure.run", baseDate: decisionDate))
            }
        case .fullStructured:
            if items.isEmpty {
                items.append(activity(type: "walking", title: "Morning walk", minutesFromNow: 60, duration: 30, icon: "figure.walk", baseDate: decisionDate))
                items.append(activity(type: "strength", title: "Strength", minutesFromNow: 300, duration: 60, icon: "dumbbell.fill", baseDate: decisionDate))
                items.append(activity(type: "sauna", title: "Sauna", minutesFromNow: 540, duration: 30, icon: "flame.fill", baseDate: decisionDate))
            }
        case .recoveryOnly:
            if items.isEmpty {
                items.append(activity(type: "walking", title: "Recovery walk", minutesFromNow: 90, duration: 30, icon: "figure.walk", baseDate: decisionDate))
                items.append(activity(type: "yoga", title: "Yoga", minutesFromNow: 240, duration: 30, icon: "figure.yoga", baseDate: decisionDate))
            }
        case .mixedTrainingRecovery:
            items.append(activity(type: "walking", title: "Recovery walk", minutesFromNow: 90, duration: 30, icon: "figure.walk", baseDate: decisionDate))
            items.append(activity(type: "strength", title: "Strength", minutesFromNow: 300, duration: 60, icon: "dumbbell.fill", baseDate: decisionDate))
        }

        if context.tomorrowHardSession {
            items.append(activity(
                type: "cycling",
                title: "Long ride",
                minutesFromNow: Int(tomorrow(hour: 8, from: decisionDate).timeIntervalSince(decisionDate) / 60),
                duration: 180,
                icon: "bicycle",
                baseDate: decisionDate
            ))
        }

        return items
    }

    private static func recoveryProfile(for context: CoachNarrativeMatrixContext) -> (
        sleep: HumanBrain.SleepState,
        recovery: HumanBrain.RecoveryState,
        readiness: HumanBrain.ReadinessState,
        sleepHours: Double
    ) {
        switch context.recoveryDriver {
        case .balanced:
            return (.strong, .strong, .good, 8.0)
        case .goodSleepLowReadiness:
            return (.strong, .compromised, .low, 7.8)
        case .shortSleepBalancedSignals:
            return (.short, .stable, .good, 5.8)
        case .fragmentedSleep:
            return (.short, .compromised, .compromised, 6.2)
        case .highRestingHeartRate:
            return (.okay, .stable, .compromised, 7.0)
        case .missingSleepData:
            return (.okay, .stable, .good, 0)
        case .missingRecoveryScore, .staleRecoverySnapshot:
            return (.okay, .stable, .good, 7.2)
        }
    }

    private static func hydrationBrainState(for context: CoachNarrativeMatrixContext) -> HumanBrain.HydrationState {
        switch context.hydration {
        case .normal: return .optimal
        case .noWaterEarlyMorning, .noWaterAfternoon, .heatDayLowWater, .lowBeforeEndurance, .lowBeforeSauna:
            return .depleted
        }
    }

    private static func fuelBrainState(for context: CoachNarrativeMatrixContext) -> HumanBrain.FuelState {
        switch context.nutrition {
        case .normal, .strongAdherence, .highCaloriesLowProtein:
            return .good
        default:
            return .underfueled
        }
    }
}
