import Foundation
import WeekFitPlanner

/// CoachV6 entry point: input facts → context → scenario key.
enum CoachV6Engine {

    struct Result: Equatable, Sendable {
        let context: CoachV6Context
        let resolution: CoachV6ScenarioResolution
        let todayInsight: CoachV6TodayInsight
        let copyPack: CoachV6CopyPack?

        var scenario: CoachV6ScenarioKey { resolution.scenario }
        var modifiers: CoachV6ScenarioModifiers { resolution.modifiers }
    }

    static func evaluate(
        input: CoachInputSnapshot,
        focusActivity: PlannedActivity? = nil
    ) -> Result {
        let context = buildContext(input: input, focusActivity: focusActivity)
        let resolution = CoachV6ScenarioResolver.resolve(context)
        let todayInsight = CoachV6PresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        let copyPack = CoachV6CopyRegistry.resolve(
            CoachV6CopyBuildInput.from(
                context: context,
                resolution: resolution,
                todayInsight: todayInsight
            )
        )
        return Result(
            context: context,
            resolution: resolution,
            todayInsight: todayInsight,
            copyPack: copyPack
        )
    }

    // MARK: - Context builder

    private static func buildContext(
        input: CoachInputSnapshot,
        focusActivity: PlannedActivity?
    ) -> CoachV6Context {
        let now = input.now
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let timeOfDay = CoachV6TimeOfDay.from(hour: hour)
        let tomorrowDemand = mapTomorrowDemand(input.dayPriorityModel.tomorrowDemand)

        let tomorrowWorkout = resolveTomorrowWorkout(from: input)
        let focus = CoachV6FocusResolver.resolve(
            input: input,
            explicitFocus: focusActivity
        )

        let completedSerious = completedSeriousActivities(from: input)
        let dayLoadBand = resolveDayLoadBand(
            input: input,
            focusActivity: focus.activity,
            completedSerious: completedSerious
        )

        let fuelState = resolveFuelState(
            input.nutritionContext,
            hour: hour,
            durationBand: .short,
            activityFamily: .none,
            activityState: .none
        )
        let hydrationState = resolveHydrationState(
            input.nutritionContext,
            hour: hour,
            activityFamily: .none,
            durationBand: .short,
            activityState: .none
        )
        let dayReadiness = CoachV6DayReadinessResolver.resolve(from: input)

        if let activity = focus.activity,
           shouldPreferTomorrowProtectionOverCompletedFocus(
            input: input,
            focus: activity,
            dayLoadBand: dayLoadBand,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay
           ) {
            return makeTomorrowProtectionContext(
                dayLoadBand: dayLoadBand,
                completedSerious: completedSerious,
                fuelState: fuelState,
                hydrationState: hydrationState,
                tomorrowDemand: tomorrowDemand,
                timeOfDay: timeOfDay,
                tomorrowWorkout: tomorrowWorkout,
                dayReadiness: dayReadiness
            )
        }

        guard let activity = focus.activity else {
            let sessionPhase = resolveIdleSessionPhase(
                timeOfDay: timeOfDay,
                tomorrowDemand: tomorrowDemand,
                dayLoadBand: dayLoadBand
            )
            return CoachV6Context(
                activityFamily: .none,
                activityType: .none,
                activityState: .none,
                sessionPhase: sessionPhase,
                durationBand: .short,
                dayLoadBand: dayLoadBand,
                completedSeriousActivities: completedSerious,
                fuelState: fuelState,
                hydrationState: hydrationState,
                tomorrowDemand: tomorrowDemand,
                timeOfDay: timeOfDay,
                tomorrowWorkout: tomorrowWorkout,
                focusActivityID: nil,
                focusSource: .idle,
                minutesUntilStart: nil,
                minutesSinceEnd: nil,
                dayReadiness: dayReadiness
            )
        }

        let resolvedFuelState = resolveFuelState(
            input.nutritionContext,
            hour: hour,
            durationBand: CoachV6DurationBand.from(minutes: activity.effectiveDurationMinutes),
            activityFamily: focus.family,
            activityState: focus.state
        )
        let resolvedHydrationState = resolveHydrationState(
            input.nutritionContext,
            hour: hour,
            activityFamily: focus.family,
            durationBand: CoachV6DurationBand.from(minutes: activity.effectiveDurationMinutes),
            activityState: focus.state
        )

        return CoachV6Context(
            activityFamily: focus.family,
            activityType: focus.type,
            activityState: focus.state,
            sessionPhase: focus.phase,
            durationBand: CoachV6DurationBand.from(minutes: activity.effectiveDurationMinutes),
            dayLoadBand: dayLoadBand,
            completedSeriousActivities: completedSerious,
            fuelState: resolvedFuelState,
            hydrationState: resolvedHydrationState,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay,
            tomorrowWorkout: tomorrowWorkout,
            focusActivityID: activity.id,
            focusSource: focus.source,
            minutesUntilStart: focus.minutesUntilStart,
            minutesSinceEnd: focus.minutesSinceEnd,
            dayReadiness: dayReadiness
        )
    }

    // MARK: - Idle session phase

    private static func resolveIdleSessionPhase(
        timeOfDay: CoachV6TimeOfDay,
        tomorrowDemand: CoachV6TomorrowDemand,
        dayLoadBand: CoachV6DayLoadBand
    ) -> CoachV6SessionPhase {
        if shouldProtectTomorrow(
            timeOfDay: timeOfDay,
            tomorrowDemand: tomorrowDemand,
            dayLoadBand: dayLoadBand
        ) {
            return .tomorrowProtection
        }
        return .idle
    }

    private static func shouldProtectTomorrow(
        timeOfDay: CoachV6TimeOfDay,
        tomorrowDemand: CoachV6TomorrowDemand,
        dayLoadBand: CoachV6DayLoadBand
    ) -> Bool {
        guard tomorrowDemand == .moderate || tomorrowDemand == .hard else { return false }
        guard dayLoadBand == .heavy || dayLoadBand == .extreme else { return false }
        switch timeOfDay {
        case .afternoon, .evening, .lateEvening:
            return true
        default:
            return false
        }
    }

    private static func shouldPreferTomorrowProtectionOverCompletedFocus(
        input: CoachInputSnapshot,
        focus: PlannedActivity,
        dayLoadBand: CoachV6DayLoadBand,
        tomorrowDemand: CoachV6TomorrowDemand,
        timeOfDay: CoachV6TimeOfDay
    ) -> Bool {
        guard focus.isCompleted || focus.isPartialCompletion else { return false }
        guard shouldProtectTomorrow(
            timeOfDay: timeOfDay,
            tomorrowDemand: tomorrowDemand,
            dayLoadBand: dayLoadBand
        ) else { return false }
        return !hasUpcomingTrainingToday(input)
    }

    private static func hasUpcomingTrainingToday(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.upcomingTrainingActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                activity.date >= input.now
        }
    }

    private static func makeTomorrowProtectionContext(
        dayLoadBand: CoachV6DayLoadBand,
        completedSerious: CoachV6CompletedSeriousActivities,
        fuelState: CoachV6FuelState,
        hydrationState: CoachV6HydrationState,
        tomorrowDemand: CoachV6TomorrowDemand,
        timeOfDay: CoachV6TimeOfDay,
        tomorrowWorkout: CoachV6TomorrowWorkout?,
        dayReadiness: CoachV6DayReadiness
    ) -> CoachV6Context {
        CoachV6Context(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .tomorrowProtection,
            durationBand: .short,
            dayLoadBand: dayLoadBand,
            completedSeriousActivities: completedSerious,
            fuelState: fuelState,
            hydrationState: hydrationState,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay,
            tomorrowWorkout: tomorrowWorkout,
            focusActivityID: nil,
            focusSource: .idle,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: dayReadiness
        )
    }

    private static func resolveTomorrowWorkout(from input: CoachInputSnapshot) -> CoachV6TomorrowWorkout? {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.selectedDate) else {
            return nil
        }

        let tomorrowActivities = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: tomorrow) && !$0.isSkipped
        }
        guard let primary = CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).primaryTrainingActivity else {
            return nil
        }

        let components = calendar.dateComponents([.hour, .minute], from: primary.date)
        return CoachV6TomorrowWorkout(
            title: primary.title,
            startHour: components.hour ?? 0,
            startMinute: components.minute ?? 0,
            durationMinutes: primary.effectiveDurationMinutes
        )
    }

    private static func isEveningPhase(_ timeOfDay: CoachV6TimeOfDay) -> Bool {
        timeOfDay == .evening || timeOfDay == .lateEvening
    }

    // MARK: - Day load

    private static func resolveDayLoadBand(
        input: CoachInputSnapshot,
        focusActivity: PlannedActivity?,
        completedSerious: CoachV6CompletedSeriousActivities
    ) -> CoachV6DayLoadBand {
        let bands: [CoachV6DayLoadBand] = [
            bandFromSeriousWork(
                completedSerious: completedSerious,
                focusActivity: focusActivity,
                input: input
            ),
            bandFromCalories(input.actualLoad.activeCalories),
            bandFromProgress(input.actualLoad.activityProgress),
            bandFromVolume(input.dayContext.completedActivityVolumeMinutes)
        ]
        return bands.max { rank($0) < rank($1) } ?? .fresh
    }

    private static func bandFromSeriousWork(
        completedSerious: CoachV6CompletedSeriousActivities,
        focusActivity: PlannedActivity?,
        input: CoachInputSnapshot
    ) -> CoachV6DayLoadBand {
        let activeSerious = focusActivity.flatMap {
            CoachV6ActivityClassifier.isSeriousTraining($0) && !$0.isCompleted ? $0 : nil
        }

        if completedSerious == .twoOrMore {
            return activeSerious != nil ? .extreme : .heavy
        }
        if completedSerious == .one {
            if activeSerious != nil {
                return .heavy
            }
            return .moderate
        }
        return .fresh
    }

    private static func bandFromCalories(_ calories: Double) -> CoachV6DayLoadBand {
        switch calories {
        case 1_200...:
            return .extreme
        case 700..<1_200:
            return .heavy
        case 400..<700:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func bandFromProgress(_ progress: Double?) -> CoachV6DayLoadBand {
        guard let progress else { return .fresh }
        switch progress {
        case 1.9...:
            return .extreme
        case 1.5..<1.9:
            return .heavy
        case 1.0..<1.5:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func bandFromVolume(_ minutes: Int) -> CoachV6DayLoadBand {
        switch minutes {
        case 240...:
            return .extreme
        case 90..<240:
            return .heavy
        case 60..<90:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func rank(_ band: CoachV6DayLoadBand) -> Int {
        switch band {
        case .fresh: return 0
        case .moderate: return 1
        case .heavy: return 2
        case .extreme: return 3
        }
    }

    private static func completedSeriousActivities(
        from input: CoachInputSnapshot
    ) -> CoachV6CompletedSeriousActivities {
        let count = input.plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: input.now) &&
                $0.isCompleted &&
                !$0.isSkipped &&
                CoachV6ActivityClassifier.isSeriousTraining($0)
        }.count

        switch count {
        case 0:
            return .none
        case 1:
            return .one
        default:
            return .twoOrMore
        }
    }

    // MARK: - Nutrition signals

    private static func resolveFuelState(
        _ nutrition: CoachNutritionContext?,
        hour: Int,
        durationBand: CoachV6DurationBand,
        activityFamily: CoachV6ActivityFamily,
        activityState: CoachV6ActivityState
    ) -> CoachV6FuelState {
        _ = activityState
        return CoachV6NutritionPace.fuelState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand
        )
    }

    private static func resolveHydrationState(
        _ nutrition: CoachNutritionContext?,
        hour: Int,
        activityFamily: CoachV6ActivityFamily,
        durationBand: CoachV6DurationBand,
        activityState: CoachV6ActivityState
    ) -> CoachV6HydrationState {
        CoachV6NutritionPace.hydrationState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand,
            activityState: activityState
        )
    }

    private static func mapTomorrowDemand(_ demand: CoachTomorrowDemand) -> CoachV6TomorrowDemand {
        switch demand {
        case .none:
            return .none
        case .easy:
            return .easy
        case .moderate:
            return .moderate
        case .hard:
            return .hard
        }
    }
}
