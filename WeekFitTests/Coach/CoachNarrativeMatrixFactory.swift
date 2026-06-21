import Foundation
@testable import WeekFit

enum CoachNarrativeMatrixFactory {

    static func allScenarios() -> [CoachNarrativeMatrixScenario] {
        var scenarios: [CoachNarrativeMatrixScenario] = []
        var id = 1
        scenarios += calmOverviewScenarios(startID: &id)
        scenarios += recoveryNeededScenarios(startID: &id)
        scenarios += workoutPrepScenarios(startID: &id)
        scenarios += activeSessionScenarios(startID: &id)
        scenarios += postWorkoutScenarios(startID: &id)
        scenarios += restAfterLoadScenarios(startID: &id)
        scenarios += eveningWindDownScenarios(startID: &id)
        scenarios += tomorrowProtectionScenarios(startID: &id)
        scenarios += nutritionLedScenarios(startID: &id)
        scenarios += hydrationLedScenarios(startID: &id)
        scenarios += saunaHeatScenarios(startID: &id)
        scenarios += syncEdgeCaseScenarios(startID: &id)
        scenarios += missingStaleDataScenarios(startID: &id)
        return scenarios
    }

    static func scenarios(for batch: CoachNarrativeMatrixRunBatch) -> [CoachNarrativeMatrixScenario] {
        allScenarios().filter { $0.runBatch == batch }
    }

    // MARK: - Builders

    private static func scenario(
        id: inout Int,
        group: CoachNarrativeMatrixGroup,
        name: String,
        inputSummary: String,
        intent: String,
        context: CoachNarrativeMatrixContext,
        activeCalories: Double = 240,
        completedWorkoutsCount: Int? = nil,
        exerciseMinutes: Int? = nil
    ) -> CoachNarrativeMatrixScenario {
        let decisionDate = CoachNarrativeMatrixStateBuilder.date(for: context.time)
        let activities = CoachNarrativeMatrixStateBuilder.activities(for: context, at: decisionDate)
        let current = CoachNarrativeMatrixScenario(
            id: id,
            group: group,
            name: name,
            inputSummary: inputSummary,
            intent: intent,
            context: context,
            makeState: {
                CoachNarrativeMatrixStateBuilder.makeState(
                    context: context,
                    activities: activities,
                    currentDate: decisionDate,
                    activeCalories: activeCalories,
                    completedWorkoutsCount: completedWorkoutsCount,
                    exerciseMinutes: exerciseMinutes
                )
            }
        )
        id += 1
        return current
    }

    private static func baseContext(
        time: CoachNarrativeTimeSlot = .normalMorning,
        recovery: CoachNarrativeRecoveryBand = .good,
        driver: CoachNarrativeRecoveryDriver = .balanced,
        activity: CoachNarrativeActivityShape = .none,
        timing: CoachNarrativeActivityTiming? = nil,
        nutrition: CoachNarrativeNutritionShape = .normal,
        hydration: CoachNarrativeHydrationShape = .normal,
        planner: CoachNarrativePlannerShape = .empty,
        tomorrowHard: Bool = false
    ) -> CoachNarrativeMatrixContext {
        CoachNarrativeMatrixContext(
            time: time,
            recoveryBand: recovery,
            recoveryDriver: driver,
            activity: activity,
            activityTiming: timing,
            nutrition: nutrition,
            hydration: hydration,
            planner: planner,
            tomorrowHardSession: tomorrowHard
        )
    }

    // MARK: - A. Calm overview (18)

    private static func calmOverviewScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        let times: [CoachNarrativeTimeSlot] = [.earlyMorning, .normalMorning, .lateMorning, .afternoon, .evening, .lateNight]
        let recoveries: [CoachNarrativeRecoveryBand] = [.excellent, .good, .moderate]
        var items: [CoachNarrativeMatrixScenario] = []
        for time in times {
            for recovery in recoveries {
                items.append(scenario(
                    id: &startID,
                    group: .calmOverview,
                    name: "Calm \(time.rawValue) recovery \(recovery.percent)%",
                    inputSummary: "\(time.rawValue), recovery \(recovery.percent)%, no activities",
                    intent: "Stable daily overview without alarmist copy",
                    context: baseContext(time: time, recovery: recovery, planner: .empty)
                ))
            }
        }
        return items
    }

    // MARK: - B. Recovery needed (12)

    private static func recoveryNeededScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        let drivers: [(CoachNarrativeRecoveryDriver, CoachNarrativeRecoveryBand, String)] = [
            (.fragmentedSleep, .low, "Fragmented sleep, recovery 48%"),
            (.fragmentedSleep, .veryLow, "Fragmented sleep, recovery 22%"),
            (.goodSleepLowReadiness, .low, "Good sleep but low readiness"),
            (.shortSleepBalancedSignals, .moderate, "Short sleep, moderate recovery"),
            (.highRestingHeartRate, .moderate, "Elevated RHR pattern"),
            (.highRestingHeartRate, .low, "Elevated RHR with low recovery"),
            (.balanced, .low, "Low recovery score only"),
            (.balanced, .veryLow, "Very low recovery score"),
            (.fragmentedSleep, .moderate, "Fragmented sleep, moderate recovery"),
            (.goodSleepLowReadiness, .moderate, "Low readiness without sleep deficit"),
            (.shortSleepBalancedSignals, .low, "Short sleep with low recovery"),
            (.balanced, .moderate, "Moderate recovery with caution")
        ]
        return drivers.map { driver, band, label in
            scenario(
                id: &startID,
                group: .recoveryNeeded,
                name: label,
                inputSummary: "Morning 09:00, \(label)",
                intent: "Recovery-first coaching matched to evidence",
                context: baseContext(recovery: band, driver: driver)
            )
        }
    }

    // MARK: - C. Workout prep (16)

    private static func workoutPrepScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        var items: [CoachNarrativeMatrixScenario] = []
        let prepCases: [(CoachNarrativeActivityShape, CoachNarrativeActivityTiming, CoachNarrativeRecoveryBand, String)] = [
            (.runPlanned, .startsIn15Min, .good, "Run in 15 min"),
            (.runPlanned, .startsIn45Min, .good, "Run in 45 min"),
            (.runPlanned, .startsIn2Hours, .excellent, "Run in 2h excellent recovery"),
            (.runPlanned, .startsIn2Hours, .low, "Run in 2h low recovery"),
            (.longRidePlanned, .startsIn2Hours, .good, "Long ride in 2h"),
            (.longRidePlanned, .startsIn45Min, .moderate, "Long ride in 45 min"),
            (.strengthPlanned, .startsIn2Hours, .good, "Strength in 2h"),
            (.strengthPlanned, .startsIn45Min, .moderate, "Strength in 45 min"),
            (.easyWalkPlanned, .startsIn2Hours, .good, "Walk in 2h"),
            (.saunaPlanned, .startsIn45Min, .good, "Sauna in 45 min"),
            (.runPlanned, .startsIn6Hours, .good, "Run in 6h"),
            (.longRidePlanned, .startsIn6Hours, .moderate, "Long ride in 6h")
        ]
        for (activity, timing, recovery, label) in prepCases {
            items.append(scenario(
                id: &startID,
                group: .workoutPrep,
                name: label,
                inputSummary: "09:00, \(label), recovery \(recovery.percent)%",
                intent: "Prep story acknowledges upcoming activity",
                context: baseContext(recovery: recovery, activity: activity, timing: timing)
            ))
        }
        items.append(scenario(
            id: &startID,
            group: .workoutPrep,
            name: "Under-fueled before long ride",
            inputSummary: "Long ride in 2h with low calories",
            intent: "Fuel guidance before endurance without calm-day copy",
            context: baseContext(
                recovery: .good,
                activity: .longRidePlanned,
                timing: .startsIn2Hours,
                nutrition: .underFueledBeforeWorkout
            )
        ))
        items.append(scenario(
            id: &startID,
            group: .workoutPrep,
            name: "Low hydration before run",
            inputSummary: "Run in 45 min with low water",
            intent: "Hydration support before workout",
            context: baseContext(
                recovery: .good,
                activity: .runPlanned,
                timing: .startsIn45Min,
                hydration: .lowBeforeEndurance
            )
        ))
        items.append(scenario(
            id: &startID,
            group: .workoutPrep,
            name: "Low hydration before sauna",
            inputSummary: "Sauna in 45 min with low water",
            intent: "Hydration can lead before heat",
            context: baseContext(
                recovery: .good,
                activity: .saunaPlanned,
                timing: .startsIn45Min,
                hydration: .lowBeforeSauna
            )
        ))
        items.append(scenario(
            id: &startID,
            group: .workoutPrep,
            name: "Full structured day morning prep",
            inputSummary: "Walk, strength, sauna planned later",
            intent: "Structured day planning without generic calm copy",
            context: baseContext(recovery: .good, planner: .fullStructured)
        ))
        return items
    }

    // MARK: - D. Active session (14)

    private static func activeSessionScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        let activeCases: [(CoachNarrativeActivityShape, CoachNarrativeRecoveryBand, Double, String)] = [
            (.activeWalk, .good, 80, "Easy walk active"),
            (.activeRun, .good, 420, "Run active"),
            (.activeLongRide, .good, 820, "Long ride active"),
            (.activeStrength, .good, 220, "Strength active"),
            (.activeSauna, .good, 60, "Sauna active"),
            (.activeWalk, .excellent, 70, "Walk active excellent recovery"),
            (.activeRun, .moderate, 360, "Run active moderate recovery"),
            (.activeLongRide, .moderate, 900, "Long ride active moderate recovery"),
            (.activeStrength, .low, 180, "Strength active low recovery")
        ]
        var items = activeCases.map { activity, recovery, calories, label in
            scenario(
                id: &startID,
                group: .activeSession,
                name: label,
                inputSummary: "Active session, recovery \(recovery.percent)%",
                intent: "Live session coaching with correct owner",
                context: baseContext(
                    time: .normalMorning,
                    recovery: recovery,
                    activity: activity,
                    timing: .activeNow,
                    hydration: activity == .activeLongRide ? .lowBeforeEndurance : .normal
                ),
                activeCalories: calories
            )
        }
        items.append(scenario(
            id: &startID,
            group: .activeSession,
            name: "Active walk afternoon",
            inputSummary: "Walk active at 15:00",
            intent: "Active contract holds outside morning",
            context: baseContext(time: .afternoon, recovery: .good, activity: .activeWalk, timing: .activeNow),
            activeCalories: 75
        ))
        items.append(scenario(
            id: &startID,
            group: .activeSession,
            name: "Active run with under-fuel",
            inputSummary: "Run active with low calories",
            intent: "In-session fuel guidance when appropriate",
            context: baseContext(
                recovery: .good,
                activity: .activeRun,
                timing: .activeNow,
                nutrition: .underFueledBeforeWorkout
            ),
            activeCalories: 350
        ))
        items.append(scenario(
            id: &startID,
            group: .activeSession,
            name: "Active walk with run planned later",
            inputSummary: "Walk active, run in 2h",
            intent: "Active story wins over upcoming prep",
            context: baseContext(
                recovery: .good,
                activity: .activeWalk,
                timing: .activeNow,
                planner: .hardSingle
            ),
            activeCalories: 60
        ))
        items.append(scenario(
            id: &startID,
            group: .activeSession,
            name: "Active long ride evening",
            inputSummary: "Long ride active at 20:30",
            intent: "Evening active endurance coaching",
            context: baseContext(
                time: .evening,
                recovery: .moderate,
                activity: .activeLongRide,
                timing: .activeNow,
                hydration: .lowBeforeEndurance
            ),
            activeCalories: 1_100
        ))
        return items
    }

    // MARK: - E. Post-workout (10)

    private static func postWorkoutScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        let cases: [(CoachNarrativeActivityShape, CoachNarrativeActivityTiming, CoachNarrativeNutritionShape, Double, Int?, String)] = [
            (.easyWalkCompleted, .completed30MinAgo, .normal, 260, 1, "Easy walk completed 30m ago"),
            (.hardRunCompleted, .completed30MinAgo, .normal, 1_100, 1, "Hard run completed 30m ago"),
            (.longRideCompleted, .completed30MinAgo, .normal, 1_850, 1, "Long ride completed 30m ago"),
            (.strengthCompleted, .completed30MinAgo, .normal, 650, 1, "Strength completed 30m ago"),
            (.hardRunCompleted, .completed3HoursAgo, .normal, 1_050, 1, "Hard run completed 3h ago"),
            (.longRideCompleted, .completed3HoursAgo, .normal, 1_700, 1, "Long ride completed 3h ago"),
            (.strengthCompleted, .completed30MinAgo, .underFueledAfterWorkout, 650, 1, "Strength completed under-fueled"),
            (.strengthCompleted, .completed30MinAgo, .strongAdherence, 800, 1, "Strength completed well fueled"),
            (.hardRunCompleted, .completed30MinAgo, .underFueledAfterWorkout, 1_050, 1, "Hard run under-fueled"),
            (.longRideCompleted, .completed30MinAgo, .strongAdherence, 1_900, 1, "Long ride well fueled")
        ]
        return cases.map { activity, timing, nutrition, calories, count, label in
            scenario(
                id: &startID,
                group: .postWorkout,
                name: label,
                inputSummary: label,
                intent: "Post-workout recovery story acknowledges completed load",
                context: baseContext(
                    time: .afternoon,
                    recovery: .moderate,
                    activity: activity,
                    timing: timing,
                    nutrition: nutrition
                ),
                activeCalories: calories,
                completedWorkoutsCount: count,
                exerciseMinutes: activity == .longRideCompleted ? 150 : (activity == .hardRunCompleted ? 90 : 60)
            )
        }
    }

    // MARK: - F. Rest after load (6)

    private static func restAfterLoadScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Day after long ride",
                inputSummary: "Morning after heavy endurance, recovery 68%",
                intent: "Rest day without post-workout alarm",
                context: baseContext(recovery: .moderate, driver: .fragmentedSleep),
                activeCalories: 120
            ),
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Day after hard strength",
                inputSummary: "Morning after strength, recovery 72%",
                intent: "Calm day after strength without duplicate post copy",
                context: baseContext(recovery: .good, driver: .shortSleepBalancedSignals),
                activeCalories: 180
            ),
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Day after poor sleep",
                inputSummary: "Morning after short sleep, recovery 58%",
                intent: "Recovery-first without overstating load",
                context: baseContext(recovery: .low, driver: .fragmentedSleep),
                activeCalories: 90
            ),
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Rest day with light plan",
                inputSummary: "Recovery 74%, yoga planned later",
                intent: "Light plan on rest day",
                context: baseContext(recovery: .moderate, planner: .recoveryOnly),
                activeCalories: 60
            ),
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Rest day excellent recovery",
                inputSummary: "Recovery 92%, no load yesterday",
                intent: "True rest without warning tone",
                context: baseContext(recovery: .excellent, driver: .balanced),
                activeCalories: 40
            ),
            scenario(
                id: &startID, group: .restAfterLoad,
                name: "Rest day with completed easy walk",
                inputSummary: "Easy walk done, recovery 84%",
                intent: "Acknowledge light movement without post-workout push",
                context: baseContext(
                    recovery: .good,
                    activity: .easyWalkCompleted,
                    timing: .completed30MinAgo
                ),
                activeCalories: 220,
                completedWorkoutsCount: 1
            )
        ]
    }

    // MARK: - G. Evening wind-down (6)

    private static func eveningWindDownScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Evening no activities left",
                inputSummary: "20:30, no remaining load",
                intent: "Evening calm without workout prep",
                context: baseContext(time: .evening, recovery: .good, planner: .empty),
                activeCalories: 420
            ),
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Evening after long ride",
                inputSummary: "20:30, ride completed earlier",
                intent: "Evening recovery after hard day",
                context: baseContext(
                    time: .evening,
                    recovery: .moderate,
                    activity: .longRideCompleted,
                    timing: .completed3HoursAgo
                ),
                activeCalories: 1_700,
                completedWorkoutsCount: 1,
                exerciseMinutes: 150
            ),
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Late night calm",
                inputSummary: "23:30, quiet day",
                intent: "Late evening without training push",
                context: baseContext(time: .lateNight, recovery: .good),
                activeCalories: 300
            ),
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Evening low recovery",
                inputSummary: "20:30, recovery 46%",
                intent: "Wind-down with recovery evidence",
                context: baseContext(time: .evening, recovery: .low, driver: .fragmentedSleep),
                activeCalories: 500
            ),
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Evening after strength",
                inputSummary: "20:30, strength done 3h ago",
                intent: "Protect evening after strength",
                context: baseContext(
                    time: .evening,
                    recovery: .moderate,
                    activity: .strengthCompleted,
                    timing: .completed3HoursAgo,
                    nutrition: .strongAdherence
                ),
                activeCalories: 700,
                completedWorkoutsCount: 1
            ),
            scenario(
                id: &startID, group: .eveningWindDown,
                name: "Evening with skipped run",
                inputSummary: "20:30, planned run skipped",
                intent: "Skipped activity does not trigger active prep",
                context: baseContext(time: .evening, recovery: .good, activity: .skippedActivity),
                activeCalories: 180
            )
        ]
    }

    // MARK: - H. Tomorrow protection (6)

    private static func tomorrowProtectionScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow long ride after today load",
                inputSummary: "Evening, tomorrow long ride, ride done today",
                intent: "Protect tomorrow's session",
                context: baseContext(
                    time: .evening,
                    recovery: .moderate,
                    activity: .longRideCompleted,
                    timing: .completed3HoursAgo,
                    tomorrowHard: true
                ),
                activeCalories: 1_650,
                completedWorkoutsCount: 1,
                exerciseMinutes: 150
            ),
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow hard session calm today",
                inputSummary: "Morning, tomorrow hard ride, quiet today",
                intent: "Tomorrow awareness without over-restriction today",
                context: baseContext(recovery: .good, tomorrowHard: true),
                activeCalories: 200
            ),
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow hard session low recovery evening",
                inputSummary: "Evening low recovery, hard session tomorrow",
                intent: "Strong tomorrow protection",
                context: baseContext(time: .evening, recovery: .low, driver: .fragmentedSleep, tomorrowHard: true),
                activeCalories: 650
            ),
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow run after afternoon strength",
                inputSummary: "Evening after strength, run tomorrow",
                intent: "Balance today completion with tomorrow demand",
                context: baseContext(
                    time: .evening,
                    recovery: .moderate,
                    activity: .strengthCompleted,
                    timing: .completed3HoursAgo,
                    tomorrowHard: true
                ),
                activeCalories: 720,
                completedWorkoutsCount: 1
            ),
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow hard with full plan today",
                inputSummary: "Structured today, hard tomorrow",
                intent: "Planner + tomorrow protection interplay",
                context: baseContext(recovery: .good, planner: .fullStructured, tomorrowHard: true),
                activeCalories: 350
            ),
            scenario(
                id: &startID, group: .tomorrowProtection,
                name: "Tomorrow hard late night",
                inputSummary: "23:30 before hard session",
                intent: "Sleep protection before hard day",
                context: baseContext(time: .lateNight, recovery: .good, tomorrowHard: true),
                activeCalories: 480
            )
        ]
    }

    // MARK: - I. Nutrition-led (10)

    private static func nutritionLedScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Empty nutrition early morning",
                inputSummary: "06:30 zero calories",
                intent: "Gentle fuel mention only when appropriate",
                context: baseContext(time: .earlyMorning, recovery: .excellent, nutrition: .emptyEarlyMorning)
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Empty nutrition normal morning",
                inputSummary: "09:00 zero calories",
                intent: "Morning fuel gap can surface gently",
                context: baseContext(recovery: .good, nutrition: .emptyEarlyMorning)
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Empty nutrition afternoon",
                inputSummary: "15:00 zero calories",
                intent: "Afternoon empty nutrition can lead",
                context: baseContext(time: .afternoon, recovery: .good, nutrition: .emptyAfternoon)
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Under-fueled before ride",
                inputSummary: "Long ride in 2h, low calories",
                intent: "Pre-endurance fuel support",
                context: baseContext(
                    recovery: .good,
                    activity: .longRidePlanned,
                    timing: .startsIn2Hours,
                    nutrition: .underFueledBeforeWorkout
                )
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Under-fueled after strength",
                inputSummary: "Strength done, 850 kcal logged",
                intent: "Post-strength refuel guidance",
                context: baseContext(
                    time: .afternoon,
                    recovery: .moderate,
                    activity: .strengthCompleted,
                    timing: .completed30MinAgo,
                    nutrition: .underFueledAfterWorkout
                ),
                activeCalories: 620,
                completedWorkoutsCount: 1
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Strong nutrition adherence",
                inputSummary: "Strength done, nutrition on target",
                intent: "No false fuel alarm after good adherence",
                context: baseContext(
                    time: .afternoon,
                    recovery: .good,
                    activity: .strengthCompleted,
                    timing: .completed30MinAgo,
                    nutrition: .strongAdherence
                ),
                activeCalories: 780,
                completedWorkoutsCount: 1
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "High calories low protein",
                inputSummary: "Calories high, protein low",
                intent: "Protein gap without generic calm copy",
                context: baseContext(recovery: .good, nutrition: .highCaloriesLowProtein),
                activeCalories: 500
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Missing nutrition data morning",
                inputSummary: "No nutrition data logged",
                intent: "Missing data should not invent severe fuel warning",
                context: baseContext(recovery: .good, nutrition: .missingData)
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Empty morning with run in 45m",
                inputSummary: "Zero calories, run in 45 min",
                intent: "Fuel can lead when workout soon",
                context: baseContext(
                    recovery: .good,
                    activity: .runPlanned,
                    timing: .startsIn45Min,
                    nutrition: .emptyEarlyMorning
                )
            ),
            scenario(
                id: &startID, group: .nutritionLed,
                name: "Empty morning with walk planned later",
                inputSummary: "Zero calories, walk in 2h",
                intent: "Empty morning without hard workout should stay gentle",
                context: baseContext(
                    recovery: .good,
                    activity: .easyWalkPlanned,
                    timing: .startsIn2Hours,
                    nutrition: .emptyEarlyMorning
                )
            )
        ]
    }

    // MARK: - J. Hydration-led (10)

    private static func hydrationLedScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .hydrationLed,
                name: "No water early morning",
                inputSummary: "06:30 zero water",
                intent: "Hydration should not dominate early morning by default",
                context: baseContext(time: .earlyMorning, recovery: .excellent, hydration: .noWaterEarlyMorning)
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "No water normal morning",
                inputSummary: "09:00 zero water",
                intent: "Morning hydration gap can surface gently",
                context: baseContext(recovery: .good, hydration: .noWaterEarlyMorning)
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "No water afternoon",
                inputSummary: "15:00 zero water",
                intent: "Afternoon hydration gap can lead",
                context: baseContext(time: .afternoon, recovery: .good, hydration: .noWaterAfternoon)
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "Low hydration before endurance",
                inputSummary: "Long ride in 45 min, low water",
                intent: "Hydration before endurance",
                context: baseContext(
                    recovery: .good,
                    activity: .longRidePlanned,
                    timing: .startsIn45Min,
                    hydration: .lowBeforeEndurance
                )
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "Low hydration before sauna",
                inputSummary: "Sauna in 45 min, low water",
                intent: "Hydration before heat",
                context: baseContext(
                    recovery: .good,
                    activity: .saunaPlanned,
                    timing: .startsIn45Min,
                    hydration: .lowBeforeSauna
                )
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "Normal hydration calm day",
                inputSummary: "Hydration on target",
                intent: "No hydration problem language",
                context: baseContext(recovery: .good, hydration: .normal)
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "Heat day low water",
                inputSummary: "Hot day with severe water gap",
                intent: "Heat + hydration can lead",
                context: baseContext(time: .afternoon, recovery: .moderate, hydration: .heatDayLowWater),
                activeCalories: 600
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "Low water active long ride",
                inputSummary: "Long ride active, low water",
                intent: "In-session hydration execution",
                context: baseContext(
                    recovery: .good,
                    activity: .activeLongRide,
                    timing: .activeNow,
                    hydration: .lowBeforeEndurance
                ),
                activeCalories: 780
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "No water with run in 15m",
                inputSummary: "Zero water, run in 15 min",
                intent: "Hydration can lead when workout imminent",
                context: baseContext(
                    recovery: .good,
                    activity: .runPlanned,
                    timing: .startsIn15Min,
                    hydration: .noWaterAfternoon
                )
            ),
            scenario(
                id: &startID, group: .hydrationLed,
                name: "No water evening calm",
                inputSummary: "20:30 zero water, no workout",
                intent: "Evening hydration gap without workout prep language",
                context: baseContext(time: .evening, recovery: .good, hydration: .noWaterAfternoon),
                activeCalories: 350
            )
        ]
    }

    // MARK: - K. Sauna / heat (6)

    private static func saunaHeatScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Sauna prep low hydration",
                inputSummary: "Sauna in 45 min, low water",
                intent: "Heat prep with hydration support",
                context: baseContext(recovery: .good, activity: .saunaPlanned, timing: .startsIn45Min, hydration: .lowBeforeSauna)
            ),
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Sauna active",
                inputSummary: "Sauna in session",
                intent: "Active heat session coaching",
                context: baseContext(recovery: .good, activity: .activeSauna, timing: .activeNow),
                activeCalories: 55
            ),
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Sauna completed recent",
                inputSummary: "Sauna finished 30m ago",
                intent: "Post-heat rehydration without over-warning",
                context: baseContext(
                    time: .afternoon,
                    recovery: .good,
                    activity: .saunaPlanned,
                    timing: .completed30MinAgo,
                    hydration: .lowBeforeSauna
                ),
                activeCalories: 120,
                completedWorkoutsCount: 1
            ),
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Sauna planned with hard day",
                inputSummary: "Sauna later on structured day",
                intent: "Heat on mixed day",
                context: baseContext(recovery: .moderate, activity: .saunaPlanned, timing: .startsIn2Hours, planner: .fullStructured)
            ),
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Heat day low water afternoon",
                inputSummary: "Hot afternoon, low water, no sauna",
                intent: "Heat context without sauna activity",
                context: baseContext(time: .afternoon, recovery: .moderate, hydration: .heatDayLowWater),
                activeCalories: 700
            ),
            scenario(
                id: &startID, group: .saunaHeat,
                name: "Sauna with tomorrow hard session",
                inputSummary: "Sauna today, hard ride tomorrow",
                intent: "Heat + tomorrow protection",
                context: baseContext(
                    time: .evening,
                    recovery: .moderate,
                    activity: .saunaPlanned,
                    timing: .completed30MinAgo,
                    tomorrowHard: true
                ),
                activeCalories: 500,
                completedWorkoutsCount: 1
            )
        ]
    }

    // MARK: - L. Sync edge cases (6)

    private static func syncEdgeCaseScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk no plan match",
                inputSummary: "Apple Watch walk completed, no matching plan",
                intent: "Acknowledge easy movement without recovery warning",
                context: baseContext(time: .afternoon, recovery: .good, activity: .syncedWalkNoPlanMatch),
                activeCalories: 420,
                completedWorkoutsCount: 1,
                exerciseMinutes: 35
            ),
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk future coffee candidate",
                inputSummary: "Synced walk done, future Coffee log exists",
                intent: "Coffee must not become fitness activity or prep focus",
                context: baseContext(time: .afternoon, recovery: .good, activity: .syncedWalkFutureCoffeeCandidate),
                activeCalories: 360,
                completedWorkoutsCount: 1,
                exerciseMinutes: 30
            ),
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk future planned walk",
                inputSummary: "Synced walk done, planned walk later",
                intent: "Completed sync acknowledged, future walk not treated as active",
                context: baseContext(time: .afternoon, recovery: .good, activity: .syncedWalkFuturePlannedWalk),
                activeCalories: 380,
                completedWorkoutsCount: 1,
                exerciseMinutes: 32
            ),
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk low recovery afternoon",
                inputSummary: "Synced walk, recovery 48%",
                intent: "Light sync should not force recoveryNeeded alone",
                context: baseContext(
                    time: .afternoon,
                    recovery: .low,
                    driver: .fragmentedSleep,
                    activity: .syncedWalkNoPlanMatch
                ),
                activeCalories: 300,
                completedWorkoutsCount: 1,
                exerciseMinutes: 30
            ),
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk with sauna planned",
                inputSummary: "Synced walk done, sauna later",
                intent: "No false post-heat copy from synced walk",
                context: baseContext(
                    time: .afternoon,
                    recovery: .good,
                    activity: .syncedWalkNoPlanMatch,
                    planner: .light
                ),
                activeCalories: 340,
                completedWorkoutsCount: 1,
                exerciseMinutes: 33
            ),
            scenario(
                id: &startID, group: .syncEdgeCases,
                name: "Synced walk evening no prep",
                inputSummary: "Synced walk at 20:30",
                intent: "Evening sync stays calm overview",
                context: baseContext(time: .evening, recovery: .good, activity: .syncedWalkNoPlanMatch),
                activeCalories: 280,
                completedWorkoutsCount: 1,
                exerciseMinutes: 28
            )
        ]
    }

    // MARK: - M. Missing / stale data (6)

    private static func missingStaleDataScenarios(startID: inout Int) -> [CoachNarrativeMatrixScenario] {
        return [
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Missing sleep data morning",
                inputSummary: "No sleep hours available",
                intent: "Do not claim poor sleep without evidence",
                context: baseContext(recovery: .good, driver: .missingSleepData)
            ),
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Missing recovery score",
                inputSummary: "Recovery percent unavailable",
                intent: "Avoid raw metric claims when score missing",
                context: baseContext(recovery: .good, driver: .missingRecoveryScore)
            ),
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Missing nutrition data afternoon",
                inputSummary: "Nutrition context missing",
                intent: "Missing nutrition should not invent severe fuel warning",
                context: baseContext(time: .afternoon, recovery: .good, nutrition: .missingData)
            ),
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Stale recovery snapshot moderate",
                inputSummary: "Stale recovery context, moderate score",
                intent: "Moderate recovery without contradictory evidence claims",
                context: baseContext(recovery: .moderate, driver: .staleRecoverySnapshot)
            ),
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Missing sleep with low recovery",
                inputSummary: "Low recovery, sleep data missing",
                intent: "Low recovery without inventing sleep deficit",
                context: baseContext(recovery: .low, driver: .missingSleepData)
            ),
            scenario(
                id: &startID, group: .missingStaleData,
                name: "Missing recovery with active walk",
                inputSummary: "Active walk, recovery score missing",
                intent: "Active contract still holds with missing recovery score",
                context: baseContext(
                    recovery: .good,
                    driver: .missingRecoveryScore,
                    activity: .activeWalk,
                    timing: .activeNow
                ),
                activeCalories: 70
            )
        ]
    }
}
