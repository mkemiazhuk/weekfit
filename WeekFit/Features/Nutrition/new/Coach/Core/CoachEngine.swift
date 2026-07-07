import Foundation
import WeekFitPlanner

/// Coach entry point: input facts → context → scenario key.
///
/// Context assembly order:
/// 1. `CoachFocusResolver` — focus activity + session phase
/// 2. `CoachDayReadinessResolver` — idle/pre-session readiness bands
/// 3. Engine overrides — tomorrow protection session phase, day load, nutrition signals
/// 4. `CoachConversationPhaseResolver` — presentation frame only (no scenario routing)
enum CoachEngine {

    struct Result: Equatable, Sendable {
        let context: CoachContext
        let resolution: CoachScenarioResolution
        let todayInsight: CoachTodayInsight
        let copyPack: CoachCopyPack?
        let morningBriefFacts: CoachMorningBriefFacts?

        var scenario: CoachScenarioKey { resolution.scenario }
        var modifiers: CoachScenarioModifiers { resolution.modifiers }
    }

    static func evaluate(
        input: CoachInputSnapshot,
        focusActivity: PlannedActivity?
    ) -> Result {
        evaluate(
            input: input,
            focusActivity: focusActivity.map(CoachPlannedActivitySnapshot.init)
        )
    }

    static func evaluate(
        input: CoachInputSnapshot,
        focusActivity: CoachPlannedActivitySnapshot? = nil
    ) -> Result {
        let context = buildContext(input: input, focusActivity: focusActivity)
        let resolution = CoachScenarioResolver.resolve(context)
        let todayInsight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        let morningBriefFacts = CoachMorningBriefFactsBuilder.build(input: input, context: context)
        let copyPack = CoachCopyRegistry.resolve(
            CoachCopyBuildInput.from(
                context: context,
                resolution: resolution,
                todayInsight: todayInsight,
                morningBriefFacts: morningBriefFacts
            )
        )
        return Result(
            context: context,
            resolution: resolution,
            todayInsight: todayInsight,
            copyPack: copyPack,
            morningBriefFacts: morningBriefFacts
        )
    }

    // MARK: - Context builder

    private static func buildContext(
        input: CoachInputSnapshot,
        focusActivity: CoachPlannedActivitySnapshot?
    ) -> CoachContext {
        let now = input.now
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let timeOfDay = CoachTimeOfDay.from(hour: hour)
        let tomorrowDemand = input.dayPriorityModel.tomorrowDemand

        let tomorrowWorkout = resolveTomorrowWorkout(from: input)
        let focus = CoachFocusResolver.resolve(
            input: input,
            explicitFocus: focusActivity
        )

        let completedSerious = completedSeriousActivities(from: input)
        let lastCompletedSeriousType = lastCompletedSeriousActivityType(from: input)
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
        let dayReadiness = CoachDayReadinessResolver.resolve(from: input)

        let completedWalkToday = CoachActivityClassifier.hasCompletedWalkToday(
            in: input.plannedActivities,
            on: input.selectedDate,
            calendar: calendar
        )

        if let activity = focus.activity,
           shouldPreferTomorrowProtectionOverCompletedFocus(
            input: input,
            focus: activity,
            dayLoadBand: dayLoadBand,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay
           ) {
            return finalizeContext(
                makeTomorrowProtectionContext(
                    dayLoadBand: dayLoadBand,
                    completedSerious: completedSerious,
                    lastCompletedSeriousType: lastCompletedSeriousType,
                    fuelState: fuelState,
                    hydrationState: hydrationState,
                    tomorrowDemand: tomorrowDemand,
                    timeOfDay: timeOfDay,
                    tomorrowWorkout: tomorrowWorkout,
                    dayReadiness: dayReadiness,
                    completedWalkToday: completedWalkToday
                ),
                input: input
            )
        }

        guard let activity = focus.activity else {
            let sessionPhase = resolveIdleSessionPhase(
                input: input,
                timeOfDay: timeOfDay,
                tomorrowDemand: tomorrowDemand,
                dayLoadBand: dayLoadBand
            )
            return finalizeContext(
                CoachContext(
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
                    dayReadiness: dayReadiness,
                    lastCompletedSeriousActivityType: lastCompletedSeriousType,
                    completedWalkToday: completedWalkToday
                ),
                input: input
            )
        }

        let resolvedFuelState = resolveFuelState(
            input.nutritionContext,
            hour: hour,
            durationBand: CoachDurationBand.from(minutes: activity.effectiveDurationMinutes),
            activityFamily: focus.family,
            activityState: focus.state
        )
        let resolvedHydrationState = resolveHydrationState(
            input.nutritionContext,
            hour: hour,
            activityFamily: focus.family,
            durationBand: CoachDurationBand.from(minutes: activity.effectiveDurationMinutes),
            activityState: focus.state
        )

        return finalizeContext(
            CoachContext(
                activityFamily: focus.family,
                activityType: focus.type,
                activityState: focus.state,
                sessionPhase: focus.phase,
                durationBand: CoachDurationBand.from(minutes: activity.effectiveDurationMinutes),
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
                dayReadiness: dayReadiness,
                lastCompletedSeriousActivityType: lastCompletedSeriousType,
                completedWalkToday: completedWalkToday
            ),
            input: input
        )
    }

    private static func finalizeContext(
        _ context: CoachContext,
        input: CoachInputSnapshot
    ) -> CoachContext {
        let isFirstOpenToday = CoachSessionTracker.isFirstOpenToday(now: input.now)
        let resolution = CoachConversationPhaseResolver.resolve(
            input: input,
            context: context,
            isFirstOpenToday: isFirstOpenToday
        )
        CoachLogger.trace(
            "[CoachConversationPhase]",
            "phase=\(resolution.phase.rawValue) reason=\(resolution.reason)"
        )
        CoachSessionTracker.markCoachInteraction(now: input.now)
        return context.withConversationPhase(resolution)
    }

    // MARK: - Idle session phase

    private static func resolveIdleSessionPhase(
        input: CoachInputSnapshot,
        timeOfDay: CoachTimeOfDay,
        tomorrowDemand: CoachTomorrowDemand,
        dayLoadBand: CoachDayLoadBand
    ) -> CoachSessionPhase {
        if shouldProtectTomorrow(
            timeOfDay: timeOfDay,
            tomorrowDemand: tomorrowDemand,
            dayLoadBand: dayLoadBand
        ),
           timeOfDay == .afternoon || timeOfDay == .evening,
           !CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday(input) {
            return .tomorrowProtection
        }
        return .idle
    }

    private static func shouldProtectTomorrow(
        timeOfDay: CoachTimeOfDay,
        tomorrowDemand: CoachTomorrowDemand,
        dayLoadBand: CoachDayLoadBand
    ) -> Bool {
        CoachTomorrowProtectionPolicy.shouldProtect(
            timeOfDay: timeOfDay,
            tomorrowDemand: tomorrowDemand,
            dayLoadBand: dayLoadBand
        )
    }

    private static func shouldPreferTomorrowProtectionOverCompletedFocus(
        input: CoachInputSnapshot,
        focus: CoachPlannedActivitySnapshot,
        dayLoadBand: CoachDayLoadBand,
        tomorrowDemand: CoachTomorrowDemand,
        timeOfDay: CoachTimeOfDay
    ) -> Bool {
        guard focus.isCompleted || focus.isPartialCompletion else { return false }
        guard shouldProtectTomorrow(
            timeOfDay: timeOfDay,
            tomorrowDemand: tomorrowDemand,
            dayLoadBand: dayLoadBand
        ) else { return false }
        return !CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday(input)
    }

    private static func makeTomorrowProtectionContext(
        dayLoadBand: CoachDayLoadBand,
        completedSerious: CoachCompletedSeriousActivities,
        lastCompletedSeriousType: CoachActivityType,
        fuelState: CoachFuelState,
        hydrationState: CoachHydrationState,
        tomorrowDemand: CoachTomorrowDemand,
        timeOfDay: CoachTimeOfDay,
        tomorrowWorkout: CoachTomorrowWorkout?,
        dayReadiness: CoachDayReadiness,
        completedWalkToday: Bool
    ) -> CoachContext {
        CoachContext(
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
            dayReadiness: dayReadiness,
            lastCompletedSeriousActivityType: lastCompletedSeriousType,
            completedWalkToday: completedWalkToday
        )
    }

    private static func resolveTomorrowWorkout(from input: CoachInputSnapshot) -> CoachTomorrowWorkout? {
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
        return CoachTomorrowWorkout(
            title: primary.title,
            startHour: components.hour ?? 0,
            startMinute: components.minute ?? 0,
            durationMinutes: primary.effectiveDurationMinutes
        )
    }

    // MARK: - Day load

    private static func resolveDayLoadBand(
        input: CoachInputSnapshot,
        focusActivity: CoachPlannedActivitySnapshot?,
        completedSerious: CoachCompletedSeriousActivities
    ) -> CoachDayLoadBand {
        let bands: [CoachDayLoadBand] = [
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
        completedSerious: CoachCompletedSeriousActivities,
        focusActivity: CoachPlannedActivitySnapshot?,
        input: CoachInputSnapshot
    ) -> CoachDayLoadBand {
        let activeSerious = focusActivity.flatMap {
            CoachActivityClassifier.isSeriousTraining($0) && !$0.isCompleted ? $0 : nil
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

    private static func bandFromCalories(_ calories: Double) -> CoachDayLoadBand {
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

    private static func bandFromProgress(_ progress: Double?) -> CoachDayLoadBand {
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

    private static func bandFromVolume(_ minutes: Int) -> CoachDayLoadBand {
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

    private static func rank(_ band: CoachDayLoadBand) -> Int {
        switch band {
        case .fresh: return 0
        case .moderate: return 1
        case .heavy: return 2
        case .extreme: return 3
        }
    }

    private static func completedSeriousActivities(
        from input: CoachInputSnapshot
    ) -> CoachCompletedSeriousActivities {
        let count = input.plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: input.now) &&
                $0.isCompleted &&
                !$0.isSkipped &&
                CoachActivityClassifier.isSeriousTraining($0)
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

    private static func lastCompletedSeriousActivityType(
        from input: CoachInputSnapshot
    ) -> CoachActivityType {
        let calendar = Calendar.current
        let completedSerious = input.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.now) &&
                $0.isCompleted &&
                !$0.isSkipped &&
                CoachActivityClassifier.isSeriousTraining($0)
        }

        guard let latest = completedSerious.max(by: { activityEndDate($0) < activityEndDate($1) }) else {
            return .none
        }

        return CoachActivityClassifier.type(for: latest)
    }

    private static func activityEndDate(_ activity: CoachPlannedActivitySnapshot) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
    }

    // MARK: - Nutrition signals

    private static func resolveFuelState(
        _ nutrition: CoachNutritionContext?,
        hour: Int,
        durationBand: CoachDurationBand,
        activityFamily: CoachActivityFamily,
        activityState: CoachActivityState
    ) -> CoachFuelState {
        _ = activityState
        return CoachNutritionPace.fuelState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand
        )
    }

    private static func resolveHydrationState(
        _ nutrition: CoachNutritionContext?,
        hour: Int,
        activityFamily: CoachActivityFamily,
        durationBand: CoachDurationBand,
        activityState: CoachActivityState
    ) -> CoachHydrationState {
        CoachNutritionPace.hydrationState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand,
            activityState: activityState
        )
    }
}
