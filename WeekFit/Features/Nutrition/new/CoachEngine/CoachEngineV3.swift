import Foundation
import SwiftUI

// MARK: - Coach Engine V3
// Philosophy:
// "Only speak when support meaningfully improves outcome."
//
// V3 is not a tracker.
// It is preparation + recovery guidance around meaningful activity moments.

enum CoachEngineV3 {

    static func decide(
        from brain: HumanBrain.State,
        plannedActivities: [PlannedActivity]? = nil,
        selectedDate: Date = Date(),
        dayContext: CoachDayContext? = nil,
        recoveryContext: CoachRecoveryContext? = nil,
        nutritionContext: CoachNutritionContext? = nil
    ) -> CoachGuidanceV3 {

        let activities = plannedActivities ?? brain.activities

        let resolvedDayContext = dayContext ?? CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: brain.now
        )

        let resolvedRecoveryContext = recoveryContext ?? CoachRecoveryContext(
            recoveryPercent: 0,
            sleepHours: 0
        )

        let phase = CoachActivityContextResolverV3.resolve(
            brain: brain,
            activities: activities,
            selectedDate: selectedDate
        )

        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: phase
        )

        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        let shouldSurface = CoachInterventionGateV3.shouldSurface(
            opportunity: opportunity,
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        return CoachGuidanceFactoryV3.make(
            phase: phase,
            readiness: readiness,
            opportunity: opportunity,
            shouldSurface: shouldSurface,
            brain: brain,
            dayContext: resolvedDayContext,
            recoveryContext: resolvedRecoveryContext
        )
    }
}

// MARK: - Main Output

struct CoachGuidanceV3 {
    let phase: CoachActivityPhaseV3
    let opportunity: CoachSupportOpportunityV3

    let shouldSurface: Bool

    let stateLabel: String

    // COACH SCREEN
    let title: String
    let message: String

    // TODAY / HIGH-LEVEL INSIGHT
    let insightTitle: String
    let insightSubtitle: String?

    let supportActions: [CoachSupportActionV3]
    let avoidNotes: [String]

    let icon: String
    let color: Color
    let importance: CoachGuidanceImportanceV3
    let tone: CoachToneV3
}

// MARK: - Coach Phase

enum CoachActivityPhaseV3 {
    case preparing(activity: PlannedActivity, kind: CoachActivityKindV3, minutesUntil: Int)
    case active(activity: PlannedActivity, kind: CoachActivityKindV3)
    case recovering(activity: PlannedActivity, kind: CoachActivityKindV3, minutesSinceEnd: Int)
    case stable
}

enum CoachActivityKindV3 {
    case endurance
    case workout
    case heat
    case recovery
    case meal
    case other
}

enum CoachActivityLoadV3 {
    case low
    case moderate
    case high
    case extreme
}

// MARK: - Readiness

struct CoachReadinessStateV3 {
    let fuelSupportUseful: Bool
    let hydrationSupportUseful: Bool
    let mineralSupportUseful: Bool
    let recoveryProtectionUseful: Bool
    let proteinSupportUseful: Bool
    let lightEveningUseful: Bool
    let hasLowConfidence: Bool
    let primarySignals: [CoachSignalV3]
}

struct CoachSignalV3: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let color: Color
}

// MARK: - Opportunity

enum CoachSupportOpportunityTypeV3 {
    case prepareForEndurance
    case prepareForWorkout
    case prepareForHeat
    case activeEnduranceSupport
    case activeWorkoutSupport
    case activeHeatSupport
    case recoverAfterWorkout
    case recoverAfterHeat
    case protectRecoveryBeforeActivity
    case stable
}

struct CoachSupportOpportunityV3 {
    let type: CoachSupportOpportunityTypeV3
    let importance: CoachGuidanceImportanceV3
    let reason: String
}

enum CoachGuidanceImportanceV3: Int {
    case quiet = 0
    case useful = 1
    case important = 2
    case high = 3
}

enum CoachToneV3 {
    case calm
    case supportive
    case preparation
    case recovery
}

// MARK: - Support Actions

enum CoachSupportActionTypeV3 {
    // Pre-workout
    case lightFueling
    case hydrateBeforeSession
    case breathingReset
    case mobilityPrep
    case keepDigestionLight

    // In-workout
    case steadyHydration
    case sustainEnergy
    case controlIntensity

    // Post-workout
    case cooldown
    case rehydrateGradually
    case lightRecoveryMovement
    case downshiftNervousSystem
    case startRecoveryNutrition

    case stayConsistent
    
    case recoveryMeal
    case electrolyteRecovery
    case sleepPriority
}

struct CoachSupportActionV3: Identifiable {
    let id = UUID()
    let type: CoachSupportActionTypeV3
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

// MARK: - Phase Resolver

// MARK: - Phase Resolver

enum CoachActivityContextResolverV3 {

    static func resolve(
        brain: HumanBrain.State,
        activities: [PlannedActivity],
        selectedDate: Date
    ) -> CoachActivityPhaseV3 {

        let calendar = Calendar.current
        let now = brain.now

        let todayActivities = activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }

        let immediateUpcomingActivity = todayActivities
            .filter { activity in
                guard !activity.isCompleted,
                      !activity.isSkipped else {
                    return false
                }

                let minutesUntil = Int(activity.date.timeIntervalSince(now) / 60)

                guard minutesUntil >= 0,
                      minutesUntil <= 15 else {
                    return false
                }

                let kind = kind(for: activity)

                return kind == .workout ||
                       kind == .endurance ||
                       kind == .heat
            }
            .sorted { $0.date < $1.date }
            .first

        let upcomingPriorityActivity = todayActivities
            .filter { activity in
                guard !activity.isCompleted,
                      !activity.isSkipped else {
                    return false
                }

                let minutesUntil = Int(activity.date.timeIntervalSince(now) / 60)

                guard minutesUntil > 0,
                      minutesUntil <= 60 else {
                    return false
                }

                let kind = kind(for: activity)
                let load = load(for: activity)

                return kind == .heat ||
                       kind == .workout ||
                       (kind == .endurance && load != .low)
            }
            .sorted { $0.date < $1.date }
            .first

        if let active = todayActivities.first(where: { activity in
            guard !activity.isCompleted,
                  !activity.isSkipped else {
                return false
            }

            let kind = kind(for: activity)

            guard kind == .endurance ||
                  kind == .workout ||
                  kind == .heat ||
                  kind == .recovery else {
                return false
            }

            let end = calendar.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date

            let isActiveNow = now >= activity.date && now <= end

            guard isActiveNow else {
                return false
            }

            if let immediateUpcomingActivity,
               immediateUpcomingActivity.id != activity.id {

                let activeLoad = load(for: activity)

                let activeIsLowPriority =
                    kind == .recovery ||
                    (kind == .endurance && activeLoad == .low)

                if activeIsLowPriority {
                    return false
                }
            }

            if let upcomingPriorityActivity,
               upcomingPriorityActivity.id != activity.id {

                let activeLoad = load(for: activity)

                let activeIsLowPriority =
                    kind == .recovery ||
                    (kind == .endurance && activeLoad == .low)

                if activeIsLowPriority {
                    return false
                }
            }

            return true
        }) {
            return .active(
                activity: active,
                kind: kind(for: active)
            )
        }

        if let immediateUpcomingActivity {
            let minutes = max(
                0,
                Int(immediateUpcomingActivity.date.timeIntervalSince(now) / 60)
            )

            return .preparing(
                activity: immediateUpcomingActivity,
                kind: kind(for: immediateUpcomingActivity),
                minutesUntil: minutes
            )
        }

        if let upcomingPriorityActivity {
            let minutes = max(
                0,
                Int(upcomingPriorityActivity.date.timeIntervalSince(now) / 60)
            )

            return .preparing(
                activity: upcomingPriorityActivity,
                kind: kind(for: upcomingPriorityActivity),
                minutesUntil: minutes
            )
        }

        if immediateUpcomingActivity == nil,
           let upcoming = todayActivities
            .filter({ activity in
                guard !activity.isCompleted,
                      !activity.isSkipped else {
                    return false
                }

                let minutes = Int(activity.date.timeIntervalSince(now) / 60)

                return minutes > 0 &&
                       minutes <= 360
            })
            .sorted(by: { $0.date < $1.date })
            .first(where: { activity in
                let kind = kind(for: activity)

                return kind == .endurance ||
                       kind == .workout ||
                       kind == .heat ||
                       kind == .recovery
            }) {

            let minutes = max(
                0,
                Int(upcoming.date.timeIntervalSince(now) / 60)
            )

            return .preparing(
                activity: upcoming,
                kind: kind(for: upcoming),
                minutesUntil: minutes
            )
        }

        if let recent = todayActivities
            .filter({ activity in
                guard activity.isCompleted else {
                    return false
                }

                let kind = kind(for: activity)

                guard kind == .endurance ||
                      kind == .workout ||
                      kind == .heat ||
                      kind == .recovery else {
                    return false
                }

                let end = calendar.date(
                    byAdding: .minute,
                    value: activity.durationMinutes,
                    to: activity.date
                ) ?? activity.date

                let minutesSinceEnd = Int(now.timeIntervalSince(end) / 60)

                guard minutesSinceEnd >= 0 else {
                    return false
                }

                if kind == .recovery {
                    if brain.hasAnyFoodLogged && minutesSinceEnd > 30 {
                        return false
                    }

                    return minutesSinceEnd <= 90
                }

                if kind == .heat {
                    return minutesSinceEnd <= 180
                }

                return minutesSinceEnd <= 240
            })
            .sorted(by: { $0.date > $1.date })
            .first {

            let end = calendar.date(
                byAdding: .minute,
                value: recent.durationMinutes,
                to: recent.date
            ) ?? recent.date

            let minutesSinceEnd = max(
                0,
                Int(now.timeIntervalSince(end) / 60)
            )

            return .recovering(
                activity: recent,
                kind: kind(for: recent),
                minutesSinceEnd: minutesSinceEnd
            )
        }

        return .stable
    }

    static func kind(for activity: PlannedActivity) -> CoachActivityKindV3 {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        if title.contains("sauna") ||
            type.contains("sauna") ||
            title.contains("hot yoga") ||
            type.contains("hot yoga") ||
            title.contains("heat") ||
            type.contains("heat") {
            return .heat
        }

        if type == "meal" ||
            title.contains("meal") ||
            title.contains("lunch") ||
            title.contains("dinner") {
            return .meal
        }

        let isExplicitRecovery =
            type.contains("recovery") ||
            title.contains("recovery block") ||
            title.contains("recovery")

        if isExplicitRecovery {
            return .recovery
        }

        let isRun =
            title.contains("run") ||
            type.contains("run")

        let isRide =
            title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("biking") ||
            title.contains("ride") ||
            title.contains("cardio") ||
            type.contains("cycling") ||
            type.contains("cycle") ||
            type.contains("bike") ||
            type.contains("biking") ||
            type.contains("ride") ||
            type.contains("cardio")

        let isWalkOrHike =
            title.contains("walk") ||
            title.contains("hike") ||
            type.contains("walk") ||
            type.contains("hike")

        if isRun || isRide || (isWalkOrHike && activity.durationMinutes >= 60) {
            return .endurance
        }

        if title.contains("gym") ||
            title.contains("strength") ||
            title.contains("hiit") ||
            title.contains("training") ||
            title.contains("workout") ||
            type.contains("gym") ||
            type.contains("strength") ||
            type.contains("hiit") ||
            type.contains("training") ||
            type.contains("workout") {
            return .workout
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("stretch") ||
            type.contains("mobility") {
            return .recovery
        }

        return .other
    }

    static func load(for activity: PlannedActivity) -> CoachActivityLoadV3 {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        let duration = activity.durationMinutes
        let calories = activityCalories(activity)

        if duration >= 180 || calories >= 1800 {
            return .extreme
        }

        if duration >= 120 || calories >= 1000 {
            return .high
        }

        if title.contains("walk") || type.contains("walk") {
            return duration >= 90 || calories >= 500 ? .moderate : .low
        }

        if title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("ride") ||
            title.contains("run") ||
            type.contains("cycling") ||
            type.contains("run") {

            if duration >= 120 || calories >= 1000 { return .high }
            if duration >= 60 || calories >= 400 { return .moderate }
            return .low
        }

        if title.contains("strength") ||
            title.contains("gym") ||
            title.contains("hiit") ||
            title.contains("workout") ||
            type.contains("strength") ||
            type.contains("gym") ||
            type.contains("hiit") ||
            type.contains("workout") {

            if duration >= 90 || calories >= 700 { return .high }
            return .moderate
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            title.contains("recovery") {
            return .low
        }

        return .moderate
    }

    static func activityCalories(_ activity: PlannedActivity) -> Int {
        let mirror = Mirror(reflecting: activity)

        let possibleNames = [
            "activeCalories",
            "calories",
            "caloriesBurned",
            "burnedCalories",
            "energyBurned",
            "activeEnergy"
        ]

        for child in mirror.children {
            guard let label = child.label,
                  possibleNames.contains(label) else {
                continue
            }

            if let value = child.value as? Int {
                return value
            }

            if let value = child.value as? Double {
                return Int(value)
            }

            if let value = child.value as? CGFloat {
                return Int(value)
            }

            if let value = child.value as? Optional<Double>,
               let unwrapped = value {
                return Int(unwrapped)
            }

            if let value = child.value as? Optional<Int>,
               let unwrapped = value {
                return unwrapped
            }
        }

        return 0
    }
}

// MARK: - Readiness Analyzer

enum CoachReadinessAnalyzerV3 {

    static func analyze(
        brain: HumanBrain.State,
        phase: CoachActivityPhaseV3
    ) -> CoachReadinessStateV3 {

        var signals: [CoachSignalV3] = []

        let fuelSupportUseful =
            brain.fuel == .underfueled ||
            brain.fuel == .light ||
            brain.current.energyCoverage < 0.55 ||
            brain.current.carbsProgress < 0.35

        let hydrationSupportUseful =
            brain.hydration == .depleted ||
            brain.hydration == .behind ||
            brain.current.waterProgress < 0.65

        let mineralSupportUseful =
            brain.hydration == .excessive ||
            brain.current.waterProgress >= 1.10 ||
            isHeatPhase(phase)

        let recoveryProtectionUseful =
            brain.recovery == .compromised ||
            brain.recovery == .vulnerable ||
            brain.sleep == .veryShort ||
            brain.sleep == .short ||
            brain.strain == .veryHigh

        let proteinSupportUseful =
            brain.protein == .low ||
            brain.protein == .behind

        let lightEveningUseful =
            brain.current.isEvening ||
            brain.current.isLateNight ||
            brain.strain == .high ||
            brain.strain == .veryHigh

        let hasLowConfidence =
            !brain.hasAnyFoodLogged &&
            brain.currentHour >= 12

        if fuelSupportUseful {
            signals.append(
                .init(
                    icon: "bolt.fill",
                    title: "Energy support",
                    text: "A small snack may make this feel easier.",
                    color: .orange
                )
            )
        }

        if hydrationSupportUseful {
            signals.append(
                .init(
                    icon: "drop.fill",
                    title: "Hydration support",
                    text: "A little water now can help later.",
                    color: .blue
                )
            )
        }

        if mineralSupportUseful {
            signals.append(
                .init(
                    icon: "drop.triangle.fill",
                    title: "Mineral support",
                    text: "Electrolytes may help more than plain water here.",
                    color: .blue
                )
            )
        }

        if recoveryProtectionUseful {
            signals.append(
                .init(
                    icon: "heart.text.square.fill",
                    title: "Recovery protection",
                    text: "Go easier today and you’ll probably feel better later.",
                    color: WeekFitTheme.purple
                )
            )
        }

        if proteinSupportUseful {
            signals.append(
                .init(
                    icon: "bolt.shield.fill",
                    title: "Recovery support",
                    text: "Some protein after training may help recovery.",
                    color: WeekFitTheme.purple
                )
            )
        }

        return CoachReadinessStateV3(
            fuelSupportUseful: fuelSupportUseful,
            hydrationSupportUseful: hydrationSupportUseful,
            mineralSupportUseful: mineralSupportUseful,
            recoveryProtectionUseful: recoveryProtectionUseful,
            proteinSupportUseful: proteinSupportUseful,
            lightEveningUseful: lightEveningUseful,
            hasLowConfidence: hasLowConfidence,
            primarySignals: Array(signals.prefix(3))
        )
    }

    private static func isHeatPhase(_ phase: CoachActivityPhaseV3) -> Bool {
        switch phase {
        case .preparing(_, let kind, _),
             .active(_, let kind),
             .recovering(_, let kind, _):
            return kind == .heat

        case .stable:
            return false
        }
    }
}

// MARK: - Opportunity Resolver

enum CoachSupportOpportunityResolverV3 {

    static func resolve(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachSupportOpportunityV3 {

        switch phase {

        case .preparing(let activity, let kind, let minutesUntil):

            if shouldProtectAfterEarlierHighLoad(
                before: activity,
                kind: kind,
                brain: brain
            ) {
                return .init(
                    type: .protectRecoveryBeforeActivity,
                    importance: kind == .recovery ? .useful : .important,
                    reason: "You’ve already done a lot today."
                )
            }

            switch kind {

            case .endurance:
                let load = CoachActivityContextResolverV3.load(for: activity)

                return .init(
                    type: .prepareForEndurance,
                    importance: load == .low
                        ? .useful
                        : (readiness.recoveryProtectionUseful
                            ? .high
                            : (minutesUntil <= 180 ? .high : .important)),
                    reason: load == .low
                        ? "For light movement, keep it simple."
                        : (readiness.recoveryProtectionUseful
                            ? "You have endurance work coming up, but your body may need an easier approach."
                            : "For longer efforts, eating and drinking a bit earlier usually helps.")
                )

            case .workout:
                let load = CoachActivityContextResolverV3.load(for: activity)

                return .init(
                    type: .prepareForWorkout,
                    importance: load == .low
                        ? .useful
                        : (readiness.recoveryProtectionUseful
                            ? .high
                            : (minutesUntil <= 120 ? .important : .useful)),
                    reason: load == .low
                        ? "For a lighter session, keep prep simple."
                        : (readiness.recoveryProtectionUseful
                            ? "You have a workout coming up, but your body may need an easier approach."
                            : "A little prep now can make the session feel smoother.")
                )

            case .heat:
                return .init(
                    type: .prepareForHeat,
                    importance: .high,
                    reason: "Heat can drain fluids faster than expected."
                )

            case .recovery:
                return .init(
                    type: .prepareForWorkout,
                    importance: .useful,
                    reason: "Start recovery or mobility work gently."
                )

            case .meal, .other:
                return stableOpportunity
            }

        case .active(_, let kind):
            switch kind {

            case .heat:
                return .init(
                    type: .activeHeatSupport,
                    importance: .high,
                    reason: "Heat is active now, so fluids and minerals matter more."
                )

            case .endurance:
                return .init(
                    type: .activeEnduranceSupport,
                    importance: .high,
                    reason: "You’re in the session now. Keep things steady."
                )

            case .workout:
                return .init(
                    type: .activeWorkoutSupport,
                    importance: .important,
                    reason: "You’re in the session now. Keep it steady."
                )

            case .recovery:
                return .init(
                    type: .activeWorkoutSupport,
                    importance: .useful,
                    reason: "Keep this gentle and sip a little water."
                )

            case .meal, .other:
                return stableOpportunity
            }

        case .recovering(_, let kind, _):
            switch kind {

            case .heat:
                return .init(
                    type: .recoverAfterHeat,
                    importance: .important,
                    reason: "After heat, rehydrate slowly and give yourself time."
                )

            case .endurance, .workout, .recovery:
                return .init(
                    type: .recoverAfterWorkout,
                    importance: .important,
                    reason: "Right after training is a good time to recover well."
                )

            case .meal, .other:
                return stableOpportunity
            }
            
        case .stable:
            return stableOpportunity
        }
    }

    private static var stableOpportunity: CoachSupportOpportunityV3 {
        .init(
            type: .stable,
            importance: .quiet,
            reason: "No training or recovery moment needs attention right now."
        )
    }
    
    private static func shouldProtectAfterEarlierHighLoad(
        before upcoming: PlannedActivity,
        kind upcomingKind: CoachActivityKindV3,
        brain: HumanBrain.State
    ) -> Bool {

        // Recovery sessions should still stay encouraged.
        // Low-load endurance-like activities, such as a normal walk, should not be treated as a second workout.
        let upcomingLoad = CoachActivityContextResolverV3.load(for: upcoming)

        guard upcomingKind == .workout || (upcomingKind == .endurance && upcomingLoad != .low) else {
            return false
        }

        guard brain.strain == .high || brain.strain == .veryHigh else {
            return false
        }

        let calendar = Calendar.current

        return brain.activities.contains { activity in
            guard activity.isCompleted else { return false }
            guard calendar.isDate(activity.date, inSameDayAs: upcoming.date) else {
                return false
            }

            guard activity.date < upcoming.date else {
                return false
            }

            let kind = CoachActivityContextResolverV3.kind(for: activity)
            let load = CoachActivityContextResolverV3.load(for: activity)

            return kind == .workout ||
                   kind == .heat ||
                   (kind == .endurance && load != .low)
        }
    }
}

// MARK: - Intervention Gate

enum CoachInterventionGateV3 {

    static func shouldSurface(
        opportunity: CoachSupportOpportunityV3,
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> Bool {

        switch opportunity.type {

        case .stable:
            return false

        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            return true

        case .protectRecoveryBeforeActivity:
            return true

        case .activeEnduranceSupport, .activeWorkoutSupport:
            return readiness.fuelSupportUseful ||
                   readiness.hydrationSupportUseful ||
                   readiness.mineralSupportUseful

        case .prepareForEndurance:
            guard case .preparing(_, _, let minutesUntil) = phase else {
                return false
            }

            return minutesUntil <= 240

        case .prepareForWorkout:
            guard case .preparing(_, _, let minutesUntil) = phase else {
                return false
            }

            return minutesUntil <= 180

        case .recoverAfterWorkout:
            guard case .recovering(_, _, let minutesSinceEnd) = phase else {
                return false
            }

            return minutesSinceEnd <= 120
//            return minutesSinceEnd <= 180 &&
//                   (
//                    readiness.proteinSupportUseful ||
//                    readiness.fuelSupportUseful ||
//                    readiness.hydrationSupportUseful ||
//                    brain.strain == .high ||
//                    brain.strain == .veryHigh
//                   )
        }
    }
}

// MARK: - Guidance Factory old version

enum CoachGuidanceFactoryV3 {

//    static func make(
//        phase: CoachActivityPhaseV3,
//        readiness: CoachReadinessStateV3,
//        opportunity: CoachSupportOpportunityV3,
//        shouldSurface: Bool,
//        brain: HumanBrain.State
//    ) -> CoachGuidanceV3 {
//
//        if !shouldSurface {
//            return stableGuidance(phase: phase, opportunity: opportunity)
//        }
//
//        switch opportunity.type {
//
//        case .prepareForEndurance:
//            return prepareForEndurance(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .prepareForWorkout:
//            return prepareForWorkout(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .prepareForHeat:
//            return prepareForHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .protectRecoveryBeforeActivity:
//            return protectRecoveryBeforeActivity(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeEnduranceSupport:
//            return activeEndurance(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeWorkoutSupport:
//            return activeWorkout(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeHeatSupport:
//            return activeHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .recoverAfterWorkout:
//            return recoverAfterWorkout(
//                   phase: phase,
//                   readiness: readiness,
//                   opportunity: opportunity,
//                   brain: brain
//               )
//
//        case .recoverAfterHeat:
//            return recoverAfterHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .stable:
//            return stableGuidance(phase: phase, opportunity: opportunity)
//        }
//    }
    
    //------------------------ new -----------------------------------
    static func make(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        shouldSurface: Bool,
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext
    ) -> CoachGuidanceV3 {

        if !shouldSurface {
            return stableGuidance(phase: phase, opportunity: opportunity)
        }

        let scenario = CoachActivityScenarioResolver.resolve(
            phase: phase,
            brain: brain
        )

        let rule = CoachScenarioRuleEngine.resolve(
            scenario: scenario,
            dayContext: dayContext,
            recoveryContext: recoveryContext,
            readiness: readiness,
            brain: brain
        )

        return guidanceFromRule(
            phase: phase,
            readiness: readiness,
            opportunity: opportunity,
            rule: rule,
            scenario: scenario
        )
    }
    
    private static func guidanceFromRule(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        rule: CoachScenarioRule,
        scenario: CoachActivityScenario
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return CoachGuidanceV3(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: rule.stateLabel,
            title: rule.title,
            message: rule.message,
            insightTitle: scenario.stage == .stable
                ? rule.title
                : "\(activityTitle) \(insightStageText(scenario.stage))",
            insightSubtitle: rule.supportFocus.first,
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: rule.supportActions
            ),
            avoidNotes: rule.avoidNotes,
            icon: icon(for: scenario),
            color: color(for: scenario),
            importance: opportunity.importance,
            tone: tone(for: scenario.stage)
        )
    }
    
    private static func insightStageText(_ stage: CoachActivityStage) -> String {
        switch stage {
        case .before: return "coming up"
        case .during: return "in progress"
        case .after: return "completed"
        case .stable: return ""
        }
    }

    private static func icon(for scenario: CoachActivityScenario) -> String {
        switch scenario.kind {
        case .recovery: return "figure.walk"
        case .endurance: return "figure.run"
        case .workout: return "figure.strengthtraining.traditional"
        case .heat: return "drop.triangle.fill"
        case .meal: return "fork.knife"
        case .other: return "sparkles"
        }
    }

    private static func color(for scenario: CoachActivityScenario) -> Color {
        switch scenario.kind {
        case .recovery: return WeekFitTheme.meal
        case .endurance: return .orange
        case .workout: return WeekFitTheme.meal
        case .heat: return .blue
        case .meal: return WeekFitTheme.meal
        case .other: return .white.opacity(0.7)
        }
    }

    private static func tone(for stage: CoachActivityStage) -> CoachToneV3 {
        switch stage {
        case .before: return .preparation
        case .during: return .supportive
        case .after: return .recovery
        case .stable: return .calm
        }
    }
    
    //------------------------ new -----------------------------------

    private static func prepareForEndurance(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: load == .low ? "EASY PREP" : "PREPARE",

            title: "\(activityTitle) \(timeText)",
            message: load == .low
                ? "A lighter session is coming up. Keep it simple and comfortable."
                : "A little preparation now usually makes the session feel better later.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: timeText,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.hydrateBeforeSession, .mobilityPrep, .breathingReset]
                    : [.lightFueling, .hydrateBeforeSession, .keepDigestionLight]
            ),
            avoidNotes: load == .low ? [] : ["Keep it light enough to avoid heavy digestion."],
            icon: load == .low ? "figure.walk" : "bolt.fill",
            color: load == .low ? WeekFitTheme.meal : .orange,
            importance: load == .low ? .useful : opportunity.importance,
            tone: .preparation
        )
    }

    private static func prepareForWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: load == .low ? "EASY PREP" : "GET READY",

            title: "\(activityTitle) \(timeText)",
            message: load == .low
                ? "A lighter session is coming up. Keep it simple and comfortable."
                : "You’re about to ask more from your body.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: timeText,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.hydrateBeforeSession, .mobilityPrep, .breathingReset]
                    : [.lightFueling, .hydrateBeforeSession, .mobilityPrep]
            ),
            avoidNotes: load == .low
                ? []
                : (readiness.recoveryProtectionUseful ? ["Keep intensity flexible if your body feels heavy."] : []),
            icon: load == .low ? "figure.walk" : "figure.strengthtraining.traditional",
            color: WeekFitTheme.meal,
            importance: load == .low ? .useful : opportunity.importance,
            tone: .preparation
        )
    }

    private static func prepareForHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "HEAT PREP",

            title: "\(activityTitle) \(timeText)",
            message: "Heat changes what your body needs.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: "Heat prep",

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.hydrateBeforeSession, .keepDigestionLight, .breathingReset]
            ),
            avoidNotes: ["Keep food light before heat."],
            icon: "drop.triangle.fill",
            color: .blue,
            importance: opportunity.importance,
            tone: .preparation
        )
    }

    private static func protectRecoveryBeforeActivity(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "CAUTION",

            title: "You’ve already done a lot today",
            message: "If you still train later, keep it flexible and don’t chase intensity.",

            insightTitle: "Keep it light today",
            insightSubtitle: "\(activityTitle) \(timeText)",
            
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.controlIntensity, .hydrateBeforeSession, .downshiftNervousSystem]
            ),
            avoidNotes: ["Keep intensity flexible today."],
            icon: "heart.text.square.fill",
            color: WeekFitTheme.purple,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeEndurance(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let activityName = activityTitle.lowercased()

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "SUPPORT NOW",

            title: "Keep your \(activityName) steady",
            message: "It gets harder to catch up once energy starts dropping.",

            insightTitle: "\(activityTitle) in progress",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.steadyHydration, .sustainEnergy, .controlIntensity]
            ),
            avoidNotes: [],
            icon: "bolt.fill",
            color: .orange,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "SUPPORT NOW",

            title: load == .low
                ? "Keep it gentle"
                : "Keep the session steady",

            message: load == .low
                ? "Stay comfortable. Don’t turn recovery into another workout."
                : "This is usually where it helps to stay steady.",

            insightTitle: "\(activityTitle) in progress",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.steadyHydration, .controlIntensity, .breathingReset]
                    : [.steadyHydration, .controlIntensity, .sustainEnergy]
            ),
            avoidNotes: [],
            icon: load == .low
                ? "figure.walk"
                : "figure.strengthtraining.traditional",
            color: WeekFitTheme.meal,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "HEAT SUPPORT",

            title: "Hydrate calmly",
            message: "Heat can drain fluids faster than expected.",

            insightTitle: "\(activityTitle) active",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.hydrateBeforeSession, .keepDigestionLight, .breathingReset]
            ),
            avoidNotes: ["Avoid heavy food until you feel settled."],
            icon: "drop.triangle.fill",
            color: .blue,
            importance: opportunity.importance,
            tone: .supportive
        )
    }
    
    private static func recoverAfterWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        brain: HumanBrain.State
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let load = activityLoad(from: phase)
        let narrative = recoveryNarrative(
            activityTitle: activityTitle,
            load: load,
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        let stateLabel: String
        let actions: [CoachSupportActionTypeV3]

        switch load {
        case .extreme:
            stateLabel = "RECOVERY PRIORITY"
            actions = [
                .recoveryMeal,
                .electrolyteRecovery,
                .sleepPriority
            ]

        case .high:
            stateLabel = "RECOVERY FOCUS"
            actions = [
                .recoveryMeal,
                .rehydrateGradually,
                .lightRecoveryMovement
            ]

        case .moderate:
            stateLabel = "RECOVER"
            actions = [
                .startRecoveryNutrition,
                .rehydrateGradually,
                .lightRecoveryMovement
            ]

        case .low:
            stateLabel = "EASY RECOVERY"
            actions = [
                .rehydrateGradually,
                .downshiftNervousSystem,
                .lightRecoveryMovement
            ]
        }

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: stateLabel,
            title: narrative.title,
            message: narrative.message,
            insightTitle: narrative.title,
            insightSubtitle: activityStatsText(from: phase),
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: actions
            ),
            avoidNotes: load == .extreme || load == .high
                ? ["Avoid adding more intensity today."]
                : [],
            icon: load == .extreme ? "flame.fill" : "heart.fill",
            color: load == .extreme ? .orange : WeekFitTheme.purple,
            importance: load == .extreme ? .high : opportunity.importance,
            tone: .recovery
        )
    }

    private static func recoveryNarrative(
        activityTitle: String,
        load: CoachActivityLoadV3,
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachNarrative {

        let stats = activityStatsText(from: phase)
        let hasStats = !stats.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch load {
        case .extreme:
            return CoachNarrative(
                title: "Recovery is the priority",
                message: hasStats
                    ? "\(stats) This was a big load. Start with fluids, a real meal and keep the rest of the day easy."
                    : "This was a big load. Start with fluids, a real meal and keep the rest of the day easy."
            )

        case .high:
            return CoachNarrative(
                title: "Recover after \(activityTitle)",
                message: hasStats
                    ? "\(stats) Rehydrate, eat properly and avoid adding more intensity today."
                    : "Rehydrate, eat properly and avoid adding more intensity today."
            )

        case .moderate:
            if readiness.proteinSupportUseful || readiness.fuelSupportUseful {
                return CoachNarrative(
                    title: "\(activityTitle) complete",
                    message: hasStats
                        ? "\(stats) Replace fluids and get some protein when you can."
                        : "Replace fluids and get some protein when you can."
                )
            }

            return CoachNarrative(
                title: "\(activityTitle) complete",
                message: hasStats
                    ? "\(stats) Let your body settle and keep the next block controlled."
                    : "Let your body settle and keep the next block controlled."
            )

        case .low:
            return CoachNarrative(
                title: "\(activityTitle) complete",
                message: "Light activity is done. Stay hydrated and return to your normal routine."
            )
        }
    }

    private static func activityStatsText(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .recovering(let activity, _, _),
             .active(let activity, _),
             .preparing(let activity, _, _):

            let duration = activity.durationMinutes
            let hours = duration / 60
            let minutes = duration % 60
            let durationText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"

            let calories = CoachActivityContextResolverV3.activityCalories(activity)

            if calories > 0 {
                return "\(durationText) completed • about \(calories) kcal burned."
            }

            return "\(durationText) completed."

        case .stable:
            return ""
        }
    }

    private static func recoverAfterHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "REHYDRATE",

            title: "Recover slowly after heat",
            message: "The next few hours matter more after heat.",

            insightTitle: "\(activityTitle) completed",
            insightSubtitle: "After heat",

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.rehydrateGradually, .downshiftNervousSystem, .lightRecoveryMovement]
            ),
            avoidNotes: ["Give your body a calmer few hours."],
            icon: "drop.triangle.fill",
            color: .blue,
            importance: opportunity.importance,
            tone: .recovery
        )
    }

    private static func stableGuidance(
        phase: CoachActivityPhaseV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: false,
            stateLabel: "OVERVIEW",

            title: "No active focus",
            message: "Nothing needs immediate attention right now.",

            insightTitle: "No active focus",
            insightSubtitle: nil,

            supportActions: [
                .init(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: "Keep your rhythm",
                    subtitle: "Stay consistent with food, water and movement",
                    color: WeekFitTheme.meal
                )
            ],
            avoidNotes: [],
            icon: "waveform.path.ecg.rectangle.fill",
            color: WeekFitTheme.meal,
            importance: .quiet,
            tone: .calm
        )
    }

    private static func supportActions(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        preferred: [CoachSupportActionTypeV3]
    ) -> [CoachSupportActionV3] {

        var result: [CoachSupportActionV3] = []
        let kind = activityKind(from: phase)
        let load = activityLoad(from: phase)
        let isLightMovement = load == .low
        
        func add(_ type: CoachSupportActionTypeV3) {
            guard !result.contains(where: { $0.type == type }) else { return }

            switch type {

            // MARK: - Pre-workout

            case .lightFueling:
                guard readiness.fuelSupportUseful else { return }
                result.append(.init(
                    type: .lightFueling,
                    icon: "bolt.fill",
                    title: "Eat something light",
                    subtitle: preFuelSubtitle(for: kind),
                    color: .orange
                ))

            case .hydrateBeforeSession:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .hydrateBeforeSession,
                    icon: "drop.fill",
                    title: "Drink some water",
                    subtitle: "Starting hydrated usually feels better",
                    color: .blue
                ))

            case .breathingReset:
                result.append(.init(
                    type: .breathingReset,
                    icon: "wind",
                    title: "Take a quiet minute",
                    subtitle: breathingSubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .mobilityPrep:
                result.append(.init(
                    type: .mobilityPrep,
                    icon: "figure.cooldown",
                    title: mobilityTitle(for: kind),
                    subtitle: mobilitySubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .keepDigestionLight:
                result.append(.init(
                    type: .keepDigestionLight,
                    icon: "leaf.fill",
                    title: "Keep food light",
                    subtitle: kind == .heat
                        ? "Keep digestion light before heat"
                        : "Avoid anything heavy before moving",
                    color: WeekFitTheme.meal
                ))

            // MARK: - In-workout

            case .steadyHydration:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .steadyHydration,
                    icon: "drop.fill",
                    title: "Sip some water",
                    subtitle: "Small sips are enough",
                    color: .blue
                ))

            case .sustainEnergy:
                guard readiness.fuelSupportUseful else { return }
                result.append(.init(
                    type: .sustainEnergy,
                    icon: "bolt.fill",
                    title: "Don’t wait too long",
                    subtitle: "A small snack now is easier than catching up later",
                    color: .orange
                ))

            case .controlIntensity:
                result.append(.init(
                    type: .controlIntensity,
                    icon: "speedometer",
                    title: intensityTitle(for: kind),
                    subtitle: intensitySubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            // MARK: - Post-workout

            case .cooldown:
                result.append(.init(
                    type: .cooldown,
                    icon: "figure.cooldown",
                    title: cooldownTitle(for: kind),
                    subtitle: cooldownSubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .rehydrateGradually:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .rehydrateGradually,
                    icon: "drop.fill",
                    title: isLightMovement ? "Hydrate lightly" : "Rehydrate gradually",
                    subtitle: isLightMovement ? "No need to overdo it after a light walk" : "Sip over the next hour",
                    color: .blue
                ))

            case .lightRecoveryMovement:
                result.append(.init(
                    type: .lightRecoveryMovement,
                    icon: "figure.walk",
                    title: isLightMovement ? "Stay loose" : "Move lightly",
                    subtitle: isLightMovement ? "Let your body settle naturally" : recoveryMovementSubtitle(for: kind),
                    color: WeekFitTheme.meal
                ))

            case .downshiftNervousSystem:
                guard readiness.lightEveningUseful || readiness.recoveryProtectionUseful else { return }
                result.append(.init(
                    type: .downshiftNervousSystem,
                    icon: "moon.fill",
                    title: "Start winding down",
                    subtitle: "Keep the rest of the day easy",
                    color: WeekFitTheme.purple
                ))

            case .startRecoveryNutrition:
                guard readiness.proteinSupportUseful || readiness.recoveryProtectionUseful else { return }
                result.append(.init(
                    type: .startRecoveryNutrition,
                    icon: "bolt.shield.fill",
                    title: "Get some protein",
                    subtitle: "Help your body repair after training",
                    color: WeekFitTheme.purple
                ))

            case .stayConsistent:
                result.append(.init(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: "Keep your rhythm",
                    subtitle: "Keep your normal rhythm",
                    color: WeekFitTheme.meal
                ))
                
            case .recoveryMeal:

                result.append(
                    .init(
                        type: .recoveryMeal,
                        icon: "fork.knife",
                        title: "Eat a recovery meal",
                        subtitle: "Replace energy and support recovery",
                        color: WeekFitTheme.meal
                    )
                )

            case .electrolyteRecovery:

                result.append(
                    .init(
                        type: .electrolyteRecovery,
                        icon: "drop.fill",
                        title: "Replace fluids",
                        subtitle: "Water and electrolytes over the next few hours",
                        color: .blue
                    )
                )

            case .sleepPriority:

                result.append(
                    .init(
                        type: .sleepPriority,
                        icon: "moon.fill",
                        title: "Protect tonight's sleep",
                        subtitle: "Recovery continues while you sleep",
                        color: WeekFitTheme.purple
                    )
                )
            }
        }

        preferred.forEach { add($0) }

        if result.isEmpty {
            result.append(.init(
                type: .stayConsistent,
                icon: "waveform.path.ecg",
                title: "Keep your rhythm",
                subtitle: "Nothing special needed",
                color: WeekFitTheme.meal
            ))
        }

        return Array(result.prefix(3))
    }

    private static func activityKind(from phase: CoachActivityPhaseV3) -> CoachActivityKindV3 {
        switch phase {
        case .preparing(_, let kind, _),
             .active(_, let kind),
             .recovering(_, let kind, _):
            return kind

        case .stable:
            return .other
        }
    }

    private static func activityLoad(from phase: CoachActivityPhaseV3) -> CoachActivityLoadV3 {
        switch phase {
        case .preparing(let activity, _, _),
             .active(let activity, _),
             .recovering(let activity, _, _):
            return CoachActivityContextResolverV3.load(for: activity)

        case .stable:
            return .low
        }
    }

    private static func preFuelSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "A small carb snack may help before the session"
        case .workout:
            return "A small snack may help before training"
        case .heat:
            return "Keep food simple before heat"
        case .recovery:
            return "Keep it light and comfortable"
        case .meal, .other:
            return "Keep it light before activity"
        }
    }

    private static func breathingSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .recovery:
            return "Take a quiet minute before mobility"
        case .heat:
            return "Start calm before heat"
        default:
            return "Take a quiet minute before you start"
        }
    }

    private static func mobilityTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .recovery:
            return "Ease into it"
        default:
            return "Warm up gently"
        }
    }

    private static func mobilitySubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .workout:
            return "Warm up before loading"
        case .recovery:
            return "Start gently before going deeper"
        default:
            return "Get your body moving first"
        }
    }

    private static func intensityTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .heat:
            return "Keep it moderate"
        case .recovery:
            return "Keep it gentle"
    
        case .endurance:
            return "Keep the pace comfortable"
        default:
            return "Keep effort controlled"
        }
    }

    private static func intensitySubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .heat:
                return "15–30 minutes is usually enough"
        case .endurance:
            return "Stay comfortable instead of chasing effort"
        case .recovery:
            return "Don’t turn recovery into a workout"
        default:
            return "Keep it at a pace you can hold"
        }
    }

    private static func cooldownTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "Cool down easy"
        case .workout:
            return "Cool down easy"
        case .heat:
            return "Cool down slowly"
        case .recovery:
            return "Finish gently"
        case .meal, .other:
            return "Cool down easy"
        }
    }

    private static func cooldownSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "Spin or walk easy for 5–10 minutes"
        case .workout:
            return "Keep the last 5–10 minutes easy"
        case .heat:
            return "Let your body cool down gradually"
        case .recovery:
            return "Finish with calm breathing or easy movement"
        case .meal, .other:
            return "Keep 5–10 min easy before stopping"
        }
    }

    private static func recoveryMovementSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "A short walk can help your legs feel less heavy"
        case .workout:
            return "Gentle walking can help with stiffness"
        case .heat:
            return "Keep movement easy while you rehydrate"
        case .recovery:
            return "Stay loose without adding more load"
        case .meal, .other:
            return "Gentle movement can help recovery"
        }
    }

    private static func activityTitle(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .preparing(let activity, _, _),
             .active(let activity, _),
             .recovering(let activity, _, _):

            let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "Activity" : title

        case .stable:
            return "Today"
        }
    }

    private static func timeText(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .preparing(_, _, let minutesUntil):
            if minutesUntil < 60 {
                return "in \(minutesUntil) min"
            }

            let hours = minutesUntil / 60
            let minutes = minutesUntil % 60

            if minutes == 0 {
                return "in \(hours)h"
            }

            return "in \(hours)h \(minutes)m"

        case .active:
            return "is active"

        case .recovering(_, _, let minutesSinceEnd):
            if minutesSinceEnd < 60 {
                return "finished \(minutesSinceEnd) min ago"
            }

            let hours = minutesSinceEnd / 60
            return "finished \(hours)h ago"

        case .stable:
            return ""
        }
    }
}

// MARK: - Adapters

extension CoachGuidanceV3 {

    var dynamicInsight: DynamicInsight {
        DynamicInsight(
            icon: icon,
            title: insightTitle,
            text: insightSubtitle ?? "",
            color: color,
            actionLabel: "Coach Insight",
            tags: coachTags
        )
    }

    var coachDecision: CoachDecision {
        CoachDecision(
            primaryStrategy: primaryStrategy,
            secondaryPriorities: secondaryPriorities,
            suppressedActions: suppressedActions,
            hydrationAlreadySolved: false,
            needsElectrolytesInsteadOfWater: isHeatSupport
        )
    }



    private var isHeatSupport: Bool {
        switch opportunity.type {
        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            return true
        default:
            return false
        }
    }
    
    private var coachTags: Set<CoachTag> {
        var tags = Set<CoachTag>()

        supportActions.forEach { action in
            switch action.type {

            case .lightFueling,
                 .sustainEnergy:
                tags.insert(.carbs)

            case .hydrateBeforeSession,
                 .steadyHydration,
                 .rehydrateGradually:
                tags.insert(.hydration)

            case .startRecoveryNutrition,
                 .recoveryMeal:
                tags.insert(.protein)
                tags.insert(.recovery)

            case .electrolyteRecovery:
                tags.insert(.hydration)
                tags.insert(.minerals)
                tags.insert(.recovery)

            case .sleepPriority:
                tags.insert(.recovery)

            case .breathingReset,
                 .mobilityPrep,
                 .keepDigestionLight,
                 .controlIntensity,
                 .cooldown,
                 .lightRecoveryMovement,
                 .downshiftNervousSystem:
                tags.insert(.recovery)

            case .stayConsistent:
                tags.insert(.consistency)
            }
        }

        if isHeatSupport {
            tags.insert(.minerals)
        }

        if tags.isEmpty {
            tags.insert(.consistency)
        }

        return tags
    }

    private var primaryStrategy: PrimaryStrategy {
        switch opportunity.type {
        case .prepareForEndurance,
             .prepareForWorkout,
             .activeEnduranceSupport,
             .activeWorkoutSupport:
            return .prepareWorkout

        case .prepareForHeat,
             .activeHeatSupport,
             .recoverAfterHeat:
            return .rehydrate

        case .recoverAfterWorkout:
            return .addProtein

        case .protectRecoveryBeforeActivity:
            return .protectRecovery

        case .stable:
            return .maintain
        }
    }

    private var secondaryPriorities: [CoachPriority] {
        var priorities: [CoachPriority] = []

        func add(_ priority: CoachPriority) {
            guard !priorities.contains(priority) else { return }
            priorities.append(priority)
        }

        supportActions.forEach { action in
            switch action.type {

            case .lightFueling,
                 .sustainEnergy:
                add(.carbs)

            case .hydrateBeforeSession,
                 .steadyHydration,
                 .rehydrateGradually:
                add(.hydration)

            case .startRecoveryNutrition:
                add(.protein)
                add(.recovery)

            case .recoveryMeal:
                add(.carbs)
                add(.protein)
                add(.recovery)

            case .electrolyteRecovery:
                add(.hydration)
                add(.minerals)
                add(.recovery)

            case .sleepPriority:
                add(.recovery)

            case .breathingReset,
                 .mobilityPrep,
                 .keepDigestionLight,
                 .controlIntensity,
                 .cooldown,
                 .lightRecoveryMovement,
                 .downshiftNervousSystem:
                add(.recovery)

            case .stayConsistent:
                break
            }
        }

        if isHeatSupport {
            add(.minerals)
        }

        let preferredOrder: [CoachPriority] = [
            .recovery,
            .hydration,
            .protein,
            .carbs,
            .minerals
        ]

        return priorities.sorted {
            (preferredOrder.firstIndex(of: $0) ?? 999)
                <
            (preferredOrder.firstIndex(of: $1) ?? 999)
        }
    }

    private var suppressedActions: Set<CoachSuppression> {
        var suppressed = Set<CoachSuppression>()

        switch opportunity.type {
        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            suppressed.insert(.heavyFood)
            suppressed.insert(.workoutPush)

        case .protectRecoveryBeforeActivity:
            suppressed.insert(.workoutPush)

        case .recoverAfterWorkout:
            suppressed.insert(.workoutPush)

        case .prepareForEndurance,
             .prepareForWorkout,
             .activeEnduranceSupport,
             .activeWorkoutSupport:
            suppressed.insert(.heavyFood)

        case .stable:
            break
        }

        return suppressed
    }
}
