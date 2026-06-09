import Foundation
import SwiftUI

enum CoachTimePhase: Hashable {
    case morning
    case midday
    case afternoon
    case evening
    case lateEvening

    static func resolve(hour: Int) -> CoachTimePhase {
        switch hour {
        case 5..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        default:
            return .lateEvening
        }
    }
}

struct CoachV5Contract {
    let dailyObjective: CoachObjective
    let currentReality: String
    let primaryLimiter: CoachLimiter
    let bestNextDecision: String
    let why: String
    let what: String
    let how: String
    let shouldSurface: Bool
    let priority: CoachDayPriorityResult
    let sourceSignals: [CoachSignal]
    let timePhase: CoachTimePhase
    let narrativePlan: CoachNarrativePlan?
}

enum CoachNarrativeLimiter: Hashable {
    case hydration
    case fuel
    case recovery
    case sleep
    case timing
    case heat
    case futureLoad
    case formQuality
    case intensityControl
    case none
}

enum CoachNarrativeBadgeIntent: Hashable {
    case startDay
    case prepare
    case manageEffort
    case keepControlled
    case hydrate
    case fuel
    case recover
    case protectSleep
    case startEasy
    case keepItEasy
    case adjustTrainingReadiness
    case reducePlan
    case goodToGo
    case protectTomorrow
    case protectMorning
    case windDown

    var label: String {
        switch self {
        case .startDay:
            return "START THE DAY"
        case .prepare:
            return "PREPARE"
        case .manageEffort:
            return "MANAGE EFFORT"
        case .keepControlled:
            return "KEEP IT CONTROLLED"
        case .hydrate:
            return "HYDRATION FIRST"
        case .fuel:
            return "FUEL"
        case .recover:
            return "RECOVER"
        case .protectSleep:
            return "PROTECT SLEEP"
        case .startEasy:
            return "START EASY"
        case .keepItEasy:
            return "KEEP IT EASY"
        case .adjustTrainingReadiness:
            return "ADJUST TRAINING READINESS"
        case .reducePlan:
            return "REDUCE THE PLAN"
        case .goodToGo:
            return "GOOD TO GO"
        case .protectTomorrow:
            return "PROTECT TOMORROW"
        case .protectMorning:
            return "PROTECT THE MORNING"
        case .windDown:
            return "WIND DOWN"
        }
    }
}

private struct CoachTimeLanguage {
    let isAfterMidnightBeforeMorning: Bool

    var nightPeriod: String {
        isAfterMidnightBeforeMorning ? "night" : "evening"
    }

    var calmNightTitle: String {
        isAfterMidnightBeforeMorning ? "Keep the night quiet" : "Keep the evening steady"
    }

    var calmNightRecommendation: String {
        isAfterMidnightBeforeMorning
            ? "Keep the night quiet and let sleep carry you into the morning."
            : "Keep the evening light and let the normal routine carry you toward sleep."
    }

    var activeSaunaTitle: String {
        isAfterMidnightBeforeMorning ? "Keep the sauna easy before sleep" : "Keep the sauna easy tonight"
    }

    var activeSaunaRead: String {
        isAfterMidnightBeforeMorning
            ? "You started a recovery sauna session overnight."
            : "You started a recovery sauna session late in the evening."
    }

    var activeSaunaRecommendation: String {
        isAfterMidnightBeforeMorning
            ? "Use it to relax, then cool down and let sleep take over."
            : "Use it to relax, not to extend the day."
    }

    var activeSaunaWhy: String {
        isAfterMidnightBeforeMorning
            ? "The benefit now comes from downshifting, not staying longer."
            : "The benefit tonight comes from downshifting, not staying longer."
    }
}

enum CoachActionIntent: Hashable {
    case objectiveAction(type: CoachSupportActionTypeV3, title: String, subtitle: String)
    case drink(amountRange: String?, timing: String?)
    case eat(macros: String?, timing: String?)
    case keepIntensity(effort: String)
    case startControlled(duration: String?)
    case bringBottle
    case sipBeforeLeaving
    case finishWithReserve
    case protectSleep
    case shortenSession
    case stopIfSymptoms
    case downshift
    case keepRecoveryEasy
    case prepareForSleep
    case keepEveningCalm
    case skipExtraTraining
    case leaveTomorrowForTomorrow
    case windDownNow
    case startHydration
    case eatNextMeal
    case keepPlanUnchanged
    case keepDayFlexible
}

private enum HeatPreparationHydrationState {
    case notStarted
    case stillLow
    case improving
    case sufficient
}

private enum CoachRecoveryDayCopyPhase {
    case morning
    case midday
    case evening
}

private extension CoachActionIntent {
    var isHydrationSupportIntent: Bool {
        switch self {
        case .drink, .bringBottle, .sipBeforeLeaving, .startHydration:
            return true
        default:
            return false
        }
    }
}

private extension CoachSupportActionTypeV3 {
    var isHydrationSupportIntent: Bool {
        switch self {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return true
        default:
            return false
        }
    }
}

struct CoachNarrativeSectionIntents {
    let myRead: String
    let recommendation: String
    let activityContext: String?
    let why: String?
    let planAdjustment: String?
}

struct CoachNarrativePlan {
    let priority: CoachDayPriority
    let objective: CoachObjective
    let urgency: CoachUrgency
    let primaryLimiter: CoachNarrativeLimiter
    let secondaryLimiters: [CoachNarrativeLimiter]
    let sessionContext: CoachActivityKindV3?
    let activityContext: String?
    let remainingDayLoad: String?
    let sectionIntents: CoachNarrativeSectionIntents
    let actionIntents: [CoachActionIntent]
    let riskIntent: String
    let badgeIntent: CoachNarrativeBadgeIntent
    let tone: CoachToneV3
    let confidence: Double
}

struct HumanCoachDecision {
    let status: CoachStatus
    let title: String
    let myRead: String
    let myRecommendation: String
    let beCarefulWith: String
    let why: String?
    let planChallenge: String?
    let supportingActions: [CoachSupportingAction]
    let priority: CoachDecisionPriority
    let sourceSignals: [CoachSignal]
    let v5Contract: CoachV5Contract?
    let narrativePlan: CoachNarrativePlan?
}

struct CoachScreenStory {
    let stateLabel: String
    let title: String
    let myRead: String
    let myRecommendation: String
    let beCarefulWith: String
    let shouldShowBeCarefulWith: Bool
    let primaryActions: [CoachSupportingAction]
    let supportActions: [CoachSupportingAction]
    let whyThisMatters: String?
    let planAdjustment: String?
    let activityContext: String?
    let shouldShowPlanAdjustment: Bool
    let shouldShowWhy: Bool
    let shouldShowActivityContext: Bool
    let tone: CoachToneV3
    let icon: String
    let color: Color
    let v5Contract: CoachV5Contract?
    let narrativePlan: CoachNarrativePlan?

    init(
        decision: HumanCoachDecision,
        phase: CoachActivityPhaseV3,
        activityIdentityIsCertain: Bool = true,
        activeSessionPhase: CoachActiveSessionPhase? = nil,
        titleOverride: String? = nil,
        icon: String,
        color: Color,
        tone: CoachToneV3
    ) {
        let requiredTexts = [
            decision.title,
            decision.myRead,
            decision.myRecommendation
        ]
        var visibleTexts = requiredTexts

        let candidatePrimaryActions = CoachScreenStory.primaryActions(for: decision)
        let risk = CoachRenderingContract.optionalText(
            decision.beCarefulWith,
            purpose: .risk,
            visibleTexts: visibleTexts
        )
        if let risk {
            visibleTexts.append(risk)
        }

        let primaryActions: [CoachSupportingAction]
        if CoachScreenStory.isMissingSleepRecoveryDay(decision) {
            primaryActions = Array(candidatePrimaryActions.prefix(3))
            visibleTexts.append(contentsOf: primaryActions.flatMap { [$0.title, $0.subtitle] })
        } else if CoachScreenStory.isHeatPreparationDecision(decision) {
            primaryActions = Array(candidatePrimaryActions.prefix(3))
            visibleTexts.append(contentsOf: primaryActions.flatMap { [$0.title, $0.subtitle] })
        } else if decision.status == .prepareSession {
            primaryActions = CoachRenderingContract.visibleActions(
                candidatePrimaryActions,
                visibleTexts: &visibleTexts
            )
        } else if CoachScreenStory.hasSportSpecificLiveAction(candidatePrimaryActions) {
            primaryActions = Array(candidatePrimaryActions.prefix(3))
            visibleTexts.append(contentsOf: primaryActions.flatMap { [$0.title, $0.subtitle] })
        } else {
            primaryActions = candidatePrimaryActions
                .contractFiltered(visibleTexts: &visibleTexts)
        }

        let supportActions = CoachScreenStory.supportActions(for: decision)
            .deduped(against: requiredTexts + primaryActions.flatMap { [$0.title, $0.subtitle] })
            .prefix(3)

        let activity = CoachScreenStory.uniqueText(
            CoachScreenStory.activityContext(
                for: phase,
                decision: decision,
                activityIdentityIsCertain: activityIdentityIsCertain,
                activeSessionPhase: activeSessionPhase
            ),
            purpose: .activityContext,
            against: visibleTexts
        )
        if let activity {
            visibleTexts.append(activity)
        }

        let why = CoachScreenStory.uniqueText(
            decision.why,
            purpose: .why,
            against: visibleTexts
        )
        if let why {
            visibleTexts.append(why)
        }

        let plan = CoachScreenStory.uniqueText(
            decision.planChallenge,
            purpose: .planAdjustment,
            against: visibleTexts
        )

        self.stateLabel = decision.narrativePlan?.badgeIntent.label ?? decision.status.label
        self.title = titleOverride ?? decision.title
        self.myRead = decision.myRead
        self.myRecommendation = decision.myRecommendation
        self.beCarefulWith = decision.beCarefulWith
        self.shouldShowBeCarefulWith = risk != nil
        self.primaryActions = Array(primaryActions)
        self.supportActions = Array(supportActions)
        self.whyThisMatters = why
        self.planAdjustment = plan
        self.activityContext = activity
        self.shouldShowWhy = why != nil
        self.shouldShowPlanAdjustment = plan != nil
        self.shouldShowActivityContext = activity != nil
        self.tone = tone
        self.icon = icon
        self.color = color
        self.v5Contract = decision.v5Contract
        self.narrativePlan = decision.narrativePlan
    }
}

private extension CoachScreenStory {

    static func isMissingSleepRecoveryDay(_ decision: HumanCoachDecision) -> Bool {
        decision.title == "Recovery day" &&
            decision.myRead.localizedCaseInsensitiveContains("sleep data was not captured")
    }

    static func isHeatPreparationDecision(_ decision: HumanCoachDecision) -> Bool {
        decision.title.localizedCaseInsensitiveContains("sauna") &&
            decision.status == .hydrateBeforeHeat
    }

    static func primaryActions(for decision: HumanCoachDecision) -> [CoachSupportingAction] {
        if let plan = decision.narrativePlan {
            return plan.actionIntents.map(actionIntent)
        }

        switch decision.status.label {
        case CoachStatus.protectTomorrow.label:
            return [
                action(.sleepPriority, title: "Set a hard stop for the evening", subtitle: "Make sleep the anchor"),
                action(.keepDigestionLight, title: "Keep food light only if already fueled", subtitle: "Avoid making digestion the last stressor"),
                action(.stayConsistent, title: "Prepare tomorrow's basics now", subtitle: "Remove friction before morning")
            ]

        case CoachStatus.nothingNeedsFixing.label:
            return [
                action(.sleepPriority, title: "Keep bedtime normal", subtitle: "Stay with the routine"),
                action(.steadyHydration, title: "Hydrate only if thirsty", subtitle: "No catch-up target is needed"),
                action(.stayConsistent, title: "No extra training needed", subtitle: "Let the day stay balanced")
            ]

        case CoachStatus.prepareSession.label:
            return prepareSessionActions(for: decision)

        case CoachStatus.recoveryDay.label:
            return [
                action(.controlIntensity, title: "Keep recovery easy", subtitle: "Conversational effort all day"),
                action(.cooldown, title: "Stop before it becomes work", subtitle: "No chasing range or strain"),
                action(.hydrateBeforeSession, title: "Arrive hydrated for heat", subtitle: "Drink calmly before exposure")
            ]

        case CoachStatus.keepControlled.label where decision.title.localizedCaseInsensitiveContains("sauna"):
            return [
                action(.controlIntensity, title: "Keep the session comfortable", subtitle: "Stay below strain"),
                action(.cooldown, title: "Leave refreshed, not drained", subtitle: "Stop before heat becomes work"),
                action(.rehydrateGradually, title: "Rehydrate after", subtitle: "Use steady fluids")
            ]

        case CoachStatus.planChanged.label where decision.title.localizedCaseInsensitiveContains("sauna"):
            return [
                action(.controlIntensity, title: "Keep sauna short", subtitle: "Save capacity for the later session"),
                action(.rehydrateGradually, title: "Rehydrate after", subtitle: "Do not start later work dry"),
                action(.controlIntensity, title: "Lower the later ceiling", subtitle: "Let the warm-up decide")
            ]

        case CoachStatus.dayHasChanged.label,
             CoachStatus.reducePlan.label,
             CoachStatus.manageEffort.label,
             CoachStatus.keepControlled.label:
            return activeSessionActions(for: decision)

        case CoachStatus.trainingGoalAchieved.label:
            return [
                action(.startRecoveryNutrition, title: "Eat normally", subtitle: "Support the work already done"),
                action(.rehydrateGradually, title: "Keep fluids steady", subtitle: "Avoid rushing catch-up"),
                action(.sleepPriority, title: "Protect tonight", subtitle: "Let the work absorb")
            ]

        default:
            return decision.supportingActions
        }
    }

    static func activityContext(
        for phase: CoachActivityPhaseV3,
        decision: HumanCoachDecision,
        activityIdentityIsCertain: Bool,
        activeSessionPhase: CoachActiveSessionPhase?
    ) -> String? {
        switch phase {
        case .active(let activity, let kind):
            if !activityIdentityIsCertain {
                return uncertainActiveSessionContext(activeSessionPhase)
            }

            let name = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return activeSessionPhaseContext(activeSessionPhase)
            }

            let activityName = name
            switch kind {
            case .heat:
                if decision.title.localizedCaseInsensitiveContains("tonight") ||
                    decision.myRead.localizedCaseInsensitiveContains("late in the evening") {
                return "This is a bridge into sleep, so the next win is cooling down cleanly."
                }
                return "The benefit comes from relaxation now, not from stretching the heat block longer."
            case .recovery:
                return "\(activityName) is recovery support today, not fitness. Keep it easy."
            case .endurance, .workout:
                return activeSessionPhaseContext(activeSessionPhase)
            case .meal, .other:
                return nil
            }

        case .recovering(let activity, let kind, _):
            let name = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let activityName = activityIdentityIsCertain && !name.isEmpty ? name : "That session"
            switch kind {
            case .endurance, .workout:
                return "\(activityName) already sent the training signal. Recovery is the priority now."
            case .heat:
                return "The heat block is already done. Let it support recovery instead of adding more stress afterwards."
            case .recovery:
                return "\(activityName) already served recovery. Keep the next step easy."
            case .meal, .other:
                return nil
            }

        case .preparing, .stable:
            return nil
        }
    }

    static func uniqueText(
        _ text: String?,
        purpose: CoachRenderingContract.OptionalPurpose,
        against higherPriorityTexts: [String]
    ) -> String? {
        CoachRenderingContract.optionalText(
            text,
            purpose: purpose,
            visibleTexts: higherPriorityTexts
        )
    }

    static func activeSessionPhaseContext(_ phase: CoachActiveSessionPhase?) -> String {
        switch phase {
        case .started, .none:
            return "The first 10 minutes matter more than targets. Let breathing, pacing, and body feedback set the ceiling."
        case .middle:
            return "Keep effort repeatable here. Execution matters more than chasing a number."
        case .finishing:
            return "Finish with enough reserve that recovery starts as soon as the session ends."
        case .postSession:
            return "The training signal is done. Recovery is now the priority."
        }
    }

    static func hasSportSpecificLiveAction(_ actions: [CoachSupportingAction]) -> Bool {
        let titles = Set(actions.map { $0.title.lowercased() })
        return titles.contains("stay aerobic") ||
            titles.contains("stay conversational") ||
            titles.contains("reduce load") ||
            titles.contains("stay efficient") ||
            titles.contains("control intensity")
    }

    static func uncertainActiveSessionContext(_ phase: CoachActiveSessionPhase?) -> String {
        switch phase {
        case .started, .none:
            return "Because the active session is unclear, keep the first minutes neutral and avoid locking into targets."
        case .middle:
            return "Because the active session is unclear, keep the effort repeatable instead of chasing a specific plan."
        case .finishing:
            return "Because the active session is unclear, finish with reserve instead of proving the original plan."
        case .postSession:
            return "Because the active session is unclear, treat recovery as the next priority."
        }
    }

    static func action(
        _ type: CoachSupportActionTypeV3,
        title: String,
        subtitle: String
    ) -> CoachSupportingAction {
        let base = HumanCoachDecisionEngine.supportAction(for: type)
        return CoachSupportingAction(
            type: type,
            icon: base.icon,
            title: title,
            subtitle: subtitle,
            color: base.color
        )
    }

    static func actionIntent(_ intent: CoachActionIntent) -> CoachSupportingAction {
        switch intent {
        case .objectiveAction(let type, let title, let subtitle):
            return action(type, title: title, subtitle: subtitle)
        case .drink(let amountRange, let timing):
            let title = amountRange.map { "Drink \($0) water" } ?? "Sip calmly"
            return action(
                .hydrateBeforeSession,
                title: title,
                subtitle: timing ?? "Use fluids as support, not a target chase"
            )
        case .eat(let macros, let timing):
            let title = macros.map { "Eat \($0)" } ?? "Eat normally"
            return action(
                .lightFueling,
                title: title,
                subtitle: timing ?? "Keep it simple and digestible"
            )
        case .keepIntensity(let effort):
            return action(
                .controlIntensity,
                title: "Keep effort easy",
                subtitle: effort
            )
        case .startControlled(let duration):
            return action(
                .controlIntensity,
                title: duration.map { "Keep the first \($0) easy" } ?? "Start easy",
                subtitle: duration.map { "Keep the first \($0) easy" } ?? "Let the warm-up settle the effort"
            )
        case .bringBottle:
            return action(
                .steadyHydration,
                title: "Bring a bottle",
                subtitle: "Make the session easier to manage"
            )
        case .sipBeforeLeaving:
            return action(
                .steadyHydration,
                title: "Sip more before leaving",
                subtitle: "Keep fluids moving without rushing"
            )
        case .finishWithReserve:
            return action(
                .cooldown,
                title: "Finish with reserve",
                subtitle: "Make recovery easier to start"
            )
        case .protectSleep:
            return action(
                .sleepPriority,
                title: "Protect sleep",
                subtitle: "Keep rest as the priority"
            )
        case .shortenSession:
            return action(
                .controlIntensity,
                title: "Shorten if needed",
                subtitle: "Make the plan fit today's capacity"
            )
        case .stopIfSymptoms:
            return action(
                .controlIntensity,
                title: "Stop if symptoms show up",
                subtitle: "Safety beats completing the session"
            )
        case .downshift:
            return action(
                .cooldown,
                title: "Downshift",
                subtitle: "Make the next block easier to recover from"
            )
        case .keepRecoveryEasy:
            return action(
                .controlIntensity,
                title: "Keep recovery easy",
                subtitle: "Finish feeling better than when you started"
            )
        case .prepareForSleep:
            return action(
                .sleepPriority,
                title: "Prepare for sleep",
                subtitle: "Let the day close cleanly"
            )
        case .keepEveningCalm:
            return action(
                .downshiftNervousSystem,
                title: "Keep the evening calm",
                subtitle: "Lower the cost of the next hour"
            )
        case .skipExtraTraining:
            return action(
                .stayConsistent,
                title: "Skip extra training",
                subtitle: "The day does not need another load"
            )
        case .leaveTomorrowForTomorrow:
            return action(
                .mobilityPrep,
                title: "Leave tomorrow for tomorrow",
                subtitle: "Do not solve tomorrow tonight"
            )
        case .windDownNow:
            return action(
                .cooldown,
                title: "Wind down now",
                subtitle: "Shift out of doing mode"
            )
        case .startHydration:
            return action(
                .steadyHydration,
                title: "Start with 300-500 ml",
                subtitle: "Bring fluids online early"
            )
        case .eatNextMeal:
            return action(
                .lightFueling,
                title: "Eat normally at next meal",
                subtitle: "Bring the day online calmly"
            )
        case .keepPlanUnchanged:
            return action(
                .stayConsistent,
                title: "Keep the plan unchanged",
                subtitle: "Recovery supports the plan"
            )
        case .keepDayFlexible:
            return action(
                .stayConsistent,
                title: "Keep the day flexible",
                subtitle: "No demanding plan needs solving now"
            )
        }
    }

    static func supportActions(for decision: HumanCoachDecision) -> [CoachSupportingAction] {
        let bullets = decision.v5Contract?.priority.supportBullets ?? []
        let priority = decision.v5Contract?.priority
        let plan = decision.narrativePlan
        let activity = priority?.activity
        let activityKind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let isRecoveryIntent = priority?.focus == .postActivityRecovery ||
            priority?.objective == .recoverFromActivity ||
            plan?.objective == .recoverFromActivity
        let hasActivitySpecificContext = activity != nil &&
            priority?.focus != .dailyOverview &&
            priority?.focus != .eveningWindDown
        let hydrationCanLead = plan?.primaryLimiter == .hydration &&
            priority?.strength == .critical
        var actions: [CoachSupportingAction] = []

        func append(_ action: CoachSupportingAction) {
            guard !actions.contains(where: { $0.title.caseInsensitiveCompare(action.title) == .orderedSame }) else {
                return
            }
            actions.append(action)
        }

        for bullet in bullets {
            let normalized = bullet.lowercased()
            if normalized.contains("hydration") ||
                normalized.contains("water") ||
                normalized.contains("fluid") ||
                normalized.contains("sip") ||
                normalized.contains("bottle") {
                if !hasActivitySpecificContext && !hydrationCanLead {
                    append(action(.steadyHydration, title: "Consider a glass of water", subtitle: "Fluids can support the day"))
                } else if normalized.contains("bottle"), hasActivitySpecificContext {
                    append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Keep fluids available as support"))
                } else if (normalized.contains("300") || normalized.contains("500")) &&
                    (hydrationCanLead || hasActivitySpecificContext) {
                    append(action(.hydrateBeforeSession, title: "Drink 300-500 ml water", subtitle: "Over the next hour"))
                } else if hydrationCanLead {
                    append(action(.steadyHydration, title: "Sip fluids steadily", subtitle: "Keep the main guidance supported"))
                } else {
                    append(action(.steadyHydration, title: "Consider a glass of water", subtitle: "Fluids can support the day"))
                }
            }

            if normalized.contains("fuel") ||
                normalized.contains("carb") ||
                normalized.contains("meal") ||
                normalized.contains("nutrition") {
                if isRecoveryIntent {
                    append(action(.recoveryMeal, title: "Eat a normal meal with carbs and protein", subtitle: "Support the work already done"))
                } else if hasActivitySpecificContext {
                    let title: String
                    let subtitle: String
                    switch activityKind {
                    case .some(.endurance):
                        let activityText = [
                            activity?.title ?? "",
                            activity?.type ?? ""
                        ].joined(separator: " ").lowercased()
                        if activityText.contains("cycl") || activityText.contains("bike") || activityText.contains("ride") {
                            title = "Eat 20-40g carbs before the ride"
                            subtitle = "Banana, sports drink, toast, or fruit"
                        } else {
                            title = "Eat 20-40g carbs before starting"
                            subtitle = "Keep it easy to digest"
                        }
                    case .some(.workout):
                        title = "Eat a quick carb snack before starting"
                        subtitle = "Fruit, toast, yogurt, or sports drink"
                    default:
                        title = "Eat a simple snack before starting"
                        subtitle = "Keep it quick and digestible"
                    }
                    append(action(.lightFueling, title: title, subtitle: subtitle))
                } else {
                    append(action(.lightFueling, title: "Eat normally at next meal", subtitle: "Build the day gradually"))
                }
            }

            if normalized.contains("sleep") {
                append(action(.sleepPriority, title: "Protect sleep", subtitle: "Keep recovery moving"))
            }
        }

        return actions
    }

    static func prepareSessionActions(for decision: HumanCoachDecision) -> [CoachSupportingAction] {
        let bullets = decision.v5Contract?.priority.supportBullets ?? []
        let joined = (bullets + [
            decision.myRead,
            decision.myRecommendation,
            decision.beCarefulWith
        ]).joined(separator: " ").lowercased()
        var actions: [CoachSupportingAction] = []

        func append(_ action: CoachSupportingAction) {
            guard !actions.contains(where: { $0.title.caseInsensitiveCompare(action.title) == .orderedSame }) else {
                return
            }
            actions.append(action)
        }

        let mealIsIn = joined.contains("meal is in") ||
            joined.contains("food is in") ||
            joined.contains("give it time to settle") ||
            joined.contains("give the meal time to settle")
        let hydrationImproving = joined.contains("hydration is improving") ||
            joined.contains("hydration has started") ||
            joined.contains("hydration is on the way") ||
            joined.contains("keep adding fluids")
        let fuelMissing = joined.contains("fuel is still missing") ||
            joined.contains("30-60") ||
            joined.contains("carb")

        if mealIsIn && hydrationImproving {
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Sip more before leaving"))
            append(action(.controlIntensity, title: "Start easy", subtitle: "Let the warm-up settle the effort"))
            append(action(.controlIntensity, title: "Keep the first 10 minutes easy", subtitle: "Let the meal settle before building"))
            return actions
        }

        if mealIsIn && (joined.contains("drink 300-500") || joined.contains("hydration is still missing")) {
            append(action(.hydrateBeforeSession, title: "Drink 300-500 ml water", subtitle: "Do it now, then sip calmly"))
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Sip more before leaving"))
            append(action(.controlIntensity, title: "Start easy", subtitle: "Let the meal settle before building"))
            return actions
        }

        if hydrationImproving && fuelMissing {
            append(action(.lightFueling, title: "Eat 30-60g carbs", subtitle: "Banana, toast, fruit, or yogurt"))
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Sip more before leaving"))
            append(action(.controlIntensity, title: "Start easy", subtitle: "Let the warm-up settle the effort"))
            return actions
        }

        if mealIsIn {
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Sip more before leaving"))
            append(action(.steadyHydration, title: "Sip more before leaving", subtitle: "No large bolus needed"))
            append(action(.controlIntensity, title: "Start easy", subtitle: "Let the warm-up settle the effort"))
            return actions
        }

        if hydrationImproving {
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Sip more before leaving"))
        } else if joined.contains("300") || joined.contains("500") || joined.contains("water") || joined.contains("hydration") {
            append(action(.hydrateBeforeSession, title: "Drink 300-500 ml water", subtitle: "Do it now, then sip calmly"))
        }

        if fuelMissing {
            append(action(.lightFueling, title: "Eat 30-60g carbs", subtitle: "Banana, toast, fruit, or yogurt"))
        }

        if joined.contains("bring a bottle") || (!joined.contains("bring a bottle") && !joined.contains("hydration is improving")) {
            append(action(.steadyHydration, title: "Bring a bottle", subtitle: "Make the session easier to manage"))
        }

        if actions.isEmpty {
            actions = [
                action(.steadyHydration, title: "Bring a bottle", subtitle: "Make the session easier to manage"),
                action(.controlIntensity, title: "Start easy", subtitle: "Let the warm-up settle the effort")
            ]
        }

        return Array(actions.prefix(3))
    }

    static func activeSessionActions(for decision: HumanCoachDecision) -> [CoachSupportingAction] {
        let text = ([
            decision.myRead,
            decision.myRecommendation,
            decision.beCarefulWith
        ] + (decision.v5Contract?.priority.supportBullets ?? []))
            .joined(separator: " ")
            .lowercased()

        var actions: [CoachSupportingAction] = []

        func append(_ action: CoachSupportingAction) {
            guard !actions.contains(where: { $0.type == action.type || normalizedActionTitle($0.title) == normalizedActionTitle(action.title) }) else {
                return
            }
            actions.append(action)
        }

        if let sportActions = sportSpecificActiveSessionActions(for: text) {
            return sportActions
        }

        append(action(.controlIntensity, title: "Use body feedback now", subtitle: "Let this session set the ceiling"))

        if text.contains("fuel") || text.contains("food") || text.contains("carb") {
            append(action(.sustainEnergy, title: "Keep intensity easy until fueled", subtitle: "Do not spend energy you have not put in"))
        }

        if text.contains("hydration") || text.contains("fluid") || text.contains("water") || text.contains("heat") {
            append(action(.steadyHydration, title: "Sip calmly if available", subtitle: "No chasing the full target mid-session"))
        }

        if text.contains("tomorrow") || text.contains("recovery") || text.contains("reserve") || text.contains("later") || text.contains("changed the day") {
            append(action(.cooldown, title: "Finish with reserve", subtitle: "Make the next block easier to absorb"))
        }

        if actions.count < 3 {
            append(action(.steadyHydration, title: "Drink to comfort during this block", subtitle: "No chasing a number mid-session"))
        }

        if actions.count < 3 {
            append(action(.cooldown, title: "Finish with reserve", subtitle: "Make recovery easier to start"))
        }

        return Array(actions.prefix(3))
    }

    static func sportSpecificActiveSessionActions(for text: String) -> [CoachSupportingAction]? {
        if text.contains("squash") {
            return [
                action(.controlIntensity, title: "Control intensity", subtitle: "Keep match effort below today's ceiling"),
                action(.breathingReset, title: "Take longer recovery", subtitle: "Give rallies more space"),
                action(.cooldown, title: "Protect movement quality", subtitle: "Stop before technique drops")
            ]
        }

        if text.contains("tennis") {
            return [
                action(.controlIntensity, title: "Stay efficient", subtitle: "Use positioning over intensity"),
                action(.breathingReset, title: "Protect movement quality", subtitle: "Avoid chasing every ball"),
                action(.cooldown, title: "Finish with reserve", subtitle: "Leave court before fatigue drives errors")
            ]
        }

        if text.contains("upper body") ||
            text.contains("strength") ||
            text.contains("gym") ||
            text.contains("working weight") ||
            text.contains("reps in reserve") {
            return [
                action(.controlIntensity, title: "Reduce load", subtitle: "Keep working weight below normal"),
                action(.breathingReset, title: "Leave reps in reserve", subtitle: "No grinding sets today"),
                action(.cooldown, title: "Avoid failure", subtitle: "Stop before form breaks down")
            ]
        }

        if text.contains("run") ||
            text.contains("running") ||
            text.contains("conversational") ||
            text.contains("pace expectations") {
            return [
                action(.controlIntensity, title: "Keep effort easy", subtitle: "Stay below today's ceiling"),
                action(.breathingReset, title: "Stay conversational", subtitle: "Let breathing control pace"),
                action(.cooldown, title: "Shorten if needed", subtitle: "Finish fresh")
            ]
        }

        if text.contains("ride") ||
            text.contains("cycling") ||
            text.contains("power controlled") ||
            text.contains("stay aerobic") {
            return [
                action(.controlIntensity, title: "Keep effort easy", subtitle: "Stay below today's ceiling"),
                action(.breathingReset, title: "Stay aerobic", subtitle: "Skip threshold or interval work"),
                action(.cooldown, title: "Finish with reserve", subtitle: "Make recovery easier to start")
            ]
        }

        return nil
    }

    static func normalizedActionTitle(_ title: String) -> String {
        title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension Array where Element == CoachSupportingAction {
    func deduped(against higherPriorityTexts: [String]) -> [CoachSupportingAction] {
        var visibleTexts = higherPriorityTexts
        var result: [CoachSupportingAction] = []

        for action in self {
            let actionTexts = [action.title, action.subtitle]
            guard !visibleTexts.containsDuplicateIdea(ofAny: actionTexts),
                  !result.flatMap({ [$0.title, $0.subtitle] }).containsDuplicateIdea(ofAny: actionTexts) else {
                continue
            }

            result.append(action)
            visibleTexts.append(contentsOf: actionTexts)
        }

        return result
    }

    func contractFiltered(visibleTexts: inout [String]) -> [CoachSupportingAction] {
        CoachRenderingContract.visibleActions(self, visibleTexts: &visibleTexts)
    }
}

private enum CoachRenderingContract {
    enum OptionalPurpose {
        case risk
        case actions
        case why
        case planAdjustment
        case activityContext
    }

    static func optionalText(
        _ text: String?,
        purpose: OptionalPurpose,
        visibleTexts: [String]
    ) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              !CoachTextDedupe.isFiller(text),
              fitsPurpose(text, purpose: purpose),
              hasInformationGain(text, purpose: purpose, visibleTexts: visibleTexts),
              !introducesCompetingNarrative(text, purpose: purpose, visibleTexts: visibleTexts) else {
            return nil
        }

        return text
    }

    static func visibleActions(
        _ actions: [CoachSupportingAction],
        visibleTexts: inout [String]
    ) -> [CoachSupportingAction] {
        var result: [CoachSupportingAction] = []

        for action in actions {
            guard result.count < 3 else { break }
            let combined = "\(action.title). \(action.subtitle)"
            guard optionalText(combined, purpose: .actions, visibleTexts: visibleTexts) != nil else {
                continue
            }

            result.append(action)
            visibleTexts.append(action.title)
            visibleTexts.append(action.subtitle)
        }

        return result
    }

    private static func hasInformationGain(
        _ text: String,
        purpose: OptionalPurpose,
        visibleTexts: [String]
    ) -> Bool {
        guard !visibleTexts.containsObviousRepeat(of: text) else { return false }

        if visibleTexts.containsDuplicateIdea(of: text) {
            return purpose == .actions && addsConcreteHow(text, beyond: visibleTexts)
        }

        return true
    }

    private static func fitsPurpose(
        _ text: String,
        purpose: OptionalPurpose
    ) -> Bool {
        let lowercased = text.lowercased()

        switch purpose {
        case .risk:
            return containsAny(
                lowercased,
                [
                    "avoid", "do not", "don't", "careful", "risk", "mistake",
                    "turning", "forcing", "chasing", "rushing", "adding",
                    "stretching", "overdoing", "too much", "spending",
                    "treating", "pushing", "ignoring", "arriving",
                    "starting", "leaving", "intervals", "threshold",
                    "prove fitness", "hard work", "hard part", "sloppy reps"
                ]
            )

        case .actions:
            return containsAny(
                lowercased,
                [
                    "drink", "sip", "eat", "bring", "start", "keep", "finish",
                    "protect", "skip", "shorten", "set", "leave", "stop",
                    "prepare", "downshift", "rehydrate"
                ]
            )

        case .why:
            return !looksLikePrimaryAction(lowercased)

        case .planAdjustment:
            return containsAny(
                lowercased,
                [
                    "plan", "adjust", "change", "reduce", "shorten", "move",
                    "skip", "swap", "lower", "keep", "if", "instead"
                ]
            )

        case .activityContext:
            return containsAny(
                lowercased,
                [
                    "activity", "session", "workout", "ride", "run", "walk",
                    "swim", "sauna", "heat", "block", "training", "this",
                    "that"
                ]
            ) && !looksLikePrimaryAction(lowercased)
        }
    }

    private static func introducesCompetingNarrative(
        _ text: String,
        purpose: OptionalPurpose,
        visibleTexts: [String]
    ) -> Bool {
        guard purpose != .actions else { return false }

        let lowercased = text.lowercased()
        let hasNewRecommendation = containsAny(
            lowercased,
            ["you should", "you need to", "the next move is", "do this", "priority is"]
        )

        return hasNewRecommendation
    }

    private static func addsConcreteHow(
        _ text: String,
        beyond visibleTexts: [String]
    ) -> Bool {
        let lowercased = text.lowercased()
        let visible = visibleTexts.joined(separator: " ").lowercased()

        if lowercased.rangeOfCharacter(from: .decimalDigits) != nil,
           visible.rangeOfCharacter(from: .decimalDigits) == nil {
            return true
        }

        return containsAny(
            lowercased,
            [
                "before", "after", "first", "now", "gradually", "bottle",
                "hard stop", "reserve", "30", "45", "60", "300", "500"
            ]
        )
    }

    private static func looksLikePrimaryAction(_ lowercased: String) -> Bool {
        let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "drink", "sip", "eat", "bring", "start", "keep", "finish",
            "protect", "skip", "shorten", "set", "leave", "stop",
            "prepare", "downshift", "rehydrate"
        ].contains { trimmed.hasPrefix($0) }
    }

    private static func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }
}

private extension Array where Element == String {
    func containsDuplicateIdea(ofAny candidates: [String]) -> Bool {
        candidates.contains { containsDuplicateIdea(of: $0) }
    }

    func containsDuplicateIdea(of candidate: String) -> Bool {
        let candidateIdea = CoachTextDedupe.ideaKey(candidate)
        let candidateConcepts = CoachTextDedupe.semanticConcepts(candidate)
        guard !candidateIdea.isEmpty else { return false }

        return contains { text in
            let existingIdea = CoachTextDedupe.ideaKey(text)
            let existingConcepts = CoachTextDedupe.semanticConcepts(text)
            guard !existingIdea.isEmpty else { return false }
            return existingIdea == candidateIdea ||
                existingIdea.contains(candidateIdea) ||
                candidateIdea.contains(existingIdea) ||
                !existingConcepts.isDisjoint(with: candidateConcepts)
        }
    }

    func containsObviousRepeat(of candidate: String) -> Bool {
        let candidateWords = CoachTextDedupe.meaningfulWords(candidate)
        guard candidateWords.count >= 4 else { return false }

        let existingWords = Set(flatMap { CoachTextDedupe.meaningfulWords($0) })
        let overlap = candidateWords.filter { existingWords.contains($0) }
        return Double(overlap.count) / Double(candidateWords.count) >= 0.7
    }
}

private enum CoachTextDedupe {
    nonisolated static func ideaKey(_ text: String) -> String {
        let normalized = meaningfulWords(text)
            .map(canonical)

        if normalized.contains("sleep") || normalized.contains("bedtime") {
            return "sleep"
        }

        return normalized.prefix(6).joined(separator: " ")
    }

    nonisolated static func meaningfulWords(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined(separator: " ")
            .split(separator: " ")
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    nonisolated static func semanticConcepts(_ text: String) -> Set<String> {
        let words = Set(meaningfulWords(text).map(canonical))
        var concepts: Set<String> = []

        if words.contains("relax") && (words.contains("extend") || words.contains("duration") || words.contains("longer")) {
            concepts.insert("relax-not-duration")
        }

        if words.contains("recovery") && (words.contains("priority") || words.contains("absorb") || words.contains("absorbing")) {
            concepts.insert("recovery-priority")
        }

        if words.contains("hydrate") && (words.contains("comfort") || words.contains("goal") || words.contains("small")) {
            concepts.insert("contextual-hydration")
        }

        if words.contains("targets") && (words.contains("breathing") || words.contains("pacing") || words.contains("feedback")) {
            concepts.insert("settle-before-targets")
        }

        if words.contains("repeatable") || (words.contains("chasing") && words.contains("numbers")) {
            concepts.insert("repeatable-effort")
        }

        if words.contains("reserve") && words.contains("recovery") {
            concepts.insert("finish-with-reserve")
        }

        return concepts
    }

    nonisolated static func isFiller(_ text: String) -> Bool {
        let key = ideaKey(text)
        let lowercased = text.lowercased()
        return fillerIdeaKeys.contains(key) ||
            fillerFragments.contains { lowercased.contains($0) }
    }

    nonisolated private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "to", "of", "for", "with", "is", "are",
        "you", "your", "this", "that", "now", "tonight", "today", "tomorrow",
        "more", "than", "it", "its", "in", "on", "if", "only", "already",
        "use", "using", "comes", "from", "benefit", "block", "session"
    ]

    nonisolated private static let fillerIdeaKeys: Set<String> = [
        "plan changed because reality changed",
        "useful coaching often deciding no intervention",
        "good execution coaching too keep session"
    ]

    nonisolated private static let fillerFragments: [String] = [
        "the plan changed because reality changed",
        "useful coaching is often deciding that no intervention is needed",
        "good execution is coaching too"
    ]

    nonisolated private static func canonical(_ word: String) -> String {
        switch word {
        case "prioritize", "protect", "bed", "bedtime", "freshness":
            return "sleep"
        case "drink", "drinking", "fluids", "fluid", "water", "rehydrate":
            return "hydrate"
        case "sauna", "heat", "heated":
            return "sauna"
        case "eat", "eating", "meals", "fueling", "fueled":
            return "food"
        case "relaxing", "relaxation", "downshift", "downshifting", "calmer", "comfortable", "refreshed":
            return "relax"
        case "extend", "extending", "stretching", "staying", "stay", "long":
            return "extend"
        case "longer", "duration", "exposure":
            return "duration"
        case "recover", "recovering", "absorbed":
            return "recovery"
        case "absorbing":
            return "absorb"
        case "target":
            return "targets"
        case "pace":
            return "pacing"
        case "feedback":
            return "feedback"
        case "number":
            return "numbers"
        default:
            return word
        }
    }
}

enum CoachUrgency: Equatable {
    case execution
    case onTrack
    case caution
    case safety
    case planning

    var semanticColor: CoachStatus.SemanticColor {
        switch self {
        case .execution:
            return .blue
        case .onTrack:
            return .green
        case .caution:
            return .yellow
        case .safety:
            return .red
        case .planning:
            return .purple
        }
    }
}

struct CoachStatus: Equatable {
    enum SemanticColor: Equatable {
        case green
        case yellow
        case red
        case purple
        case blue
    }

    let label: String
    let urgency: CoachUrgency

    init(label: String, urgency: CoachUrgency) {
        self.label = label
        self.urgency = urgency
    }

    init(label: String, semanticColor: SemanticColor) {
        self.label = label
        switch semanticColor {
        case .green:
            self.urgency = .onTrack
        case .yellow:
            self.urgency = .caution
        case .red:
            self.urgency = .safety
        case .purple:
            self.urgency = .planning
        case .blue:
            self.urgency = .execution
        }
    }

    var semanticColor: SemanticColor {
        urgency.semanticColor
    }

    var color: Color {
        switch semanticColor {
        case .green:
            return WeekFitTheme.meal
        case .yellow:
            return Color.orange
        case .red:
            return Color.red
        case .purple:
            return WeekFitTheme.purple
        case .blue:
            return Color.blue
        }
    }

    static let goodToGo = CoachStatus(label: "GOOD TO GO", semanticColor: .green)
    static let trainingGoalAchieved = CoachStatus(label: "TRAINING GOAL ACHIEVED", semanticColor: .green)
    static let nothingNeedsFixing = CoachStatus(label: "NOTHING NEEDS FIXING", semanticColor: .green)
    static let opportunityDay = CoachStatus(label: "OPPORTUNITY DAY", semanticColor: .green)
    static let recoveryDay = CoachStatus(label: "RECOVERY DAY", semanticColor: .green)

    static let prepareSession = CoachStatus(label: "PREPARE", semanticColor: .blue)
    static let adjustPlan = CoachStatus(label: "ADJUST THE PLAN", semanticColor: .yellow)
    static let dayHasChanged = CoachStatus(label: "DAY HAS CHANGED", semanticColor: .yellow)
    static let keepControlled = CoachStatus(label: "KEEP IT CONTROLLED", semanticColor: .yellow)
    static let manageEffort = CoachStatus(label: "MANAGE EFFORT", urgency: .caution)
    static let keepItEasy = CoachStatus(label: "KEEP IT EASY", semanticColor: .blue)
    static let reducePlan = CoachStatus(label: "REDUCE THE PLAN", semanticColor: .red)
    static let recoveryFirst = CoachStatus(label: "RECOVERY FIRST", semanticColor: .red)

    static let planChanged = CoachStatus(label: "PLAN CHANGED", semanticColor: .purple)
    static let protectTomorrow = CoachStatus(label: "PROTECT TOMORROW", urgency: .caution)

    static let supportSession = CoachStatus(label: "SUPPORT THE SESSION", semanticColor: .blue)
    static let hydrateBeforeHeat = CoachStatus(label: "HYDRATE BEFORE HEAT", semanticColor: .blue)
}

enum CoachDecisionPriority: Int, Comparable {
    case supporting = 0
    case planOptimization = 1
    case trainingQuality = 2
    case safety = 3

    static func < (lhs: CoachDecisionPriority, rhs: CoachDecisionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var importance: CoachGuidanceImportanceV3 {
        switch self {
        case .supporting:
            return .quiet
        case .planOptimization:
            return .useful
        case .trainingQuality:
            return .important
        case .safety:
            return .high
        }
    }
}

struct CoachSupportingAction {
    let type: CoachSupportActionTypeV3
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

struct CoachSignal {
    enum Layer: Hashable {
        case past
        case present
        case future
    }

    enum Kind: Hashable {
        case sleep
        case recovery
        case readiness
        case yesterdayLoad
        case completedTraining
        case activeActivity
        case activeQuickAction
        case plannedTraining
        case tomorrowTraining
        case hydration
        case nutrition
        case time
    }

    let layer: Layer
    let kind: Kind
    let title: String
    let interpretation: String
    let priority: CoachDecisionPriority
}

private enum CoachPreparationStage {
    case missingFuelAndHydration
    case missingFuel
    case missingHydration
    case improvingHydration
    case mealLogged
    case readyToStart
}

private struct ActiveSessionCoachingContext {
    private enum SportProfile {
        case cycling
        case running
        case upperBody
        case tennis
        case squash
        case generic

        init(text: String) {
            let normalized = text.lowercased()
            if normalized.contains("squash") {
                self = .squash
            } else if normalized.contains("tennis") {
                self = .tennis
            } else if normalized.contains("upper body") ||
                        normalized.contains("strength") ||
                        normalized.contains("gym") ||
                        normalized.contains("weights") ||
                        normalized.contains("lifting") {
                self = .upperBody
            } else if normalized.contains("run") ||
                        normalized.contains("jog") {
                self = .running
            } else if normalized.contains("ride") ||
                        normalized.contains("cycling") ||
                        normalized.contains("cycl") ||
                        normalized.contains("bike") {
                self = .cycling
            } else {
                self = .generic
            }
        }

        var title: String {
            switch self {
            case .cycling:
                return "Control today's ride"
            case .running:
                return "Control today's run"
            case .upperBody:
                return "Control today's upper body session"
            case .tennis:
                return "Control today's tennis session"
            case .squash:
                return "Control today's squash session"
            case .generic:
                return ""
            }
        }

        var fallbackRead: String {
            switch self {
            case .cycling:
                return "Today's ride is live. Keep the effort controlled and finish with reserve."
            case .running:
                return "Today's run is live. Keep the effort easy enough to finish fresh."
            case .upperBody:
                return "Today's upper body session is live. Prioritize quality over load."
            case .tennis:
                return "Tennis is live. Play within today's limits and protect movement quality."
            case .squash:
                return "Squash is live. Keep match intensity below today's normal ceiling."
            case .generic:
                return ""
            }
        }

        var limiterRead: String {
            switch self {
            case .cycling:
                return "Today's ride should stay controlled."
            case .running:
                return "Recovery does not support productive hard running today."
            case .upperBody:
                return "Today's session should prioritize quality over load."
            case .tennis:
                return "Recovery does not support long high-intensity rallies today."
            case .squash:
                return "Squash places high demands on movement and recovery. Today's ceiling is lower than normal."
            case .generic:
                return ""
            }
        }

        var limitedRecommendation: String {
            switch self {
            case .cycling:
                return "Stay aerobic, skip hard intervals, keep power controlled, and finish with reserve."
            case .running:
                return "Stay conversational, skip hard intervals or tempo work, reduce pace expectations, and shorten if needed."
            case .upperBody:
                return "Reduce working weight, skip top-end efforts, leave reps in reserve, and avoid failure training."
            case .tennis:
                return "Use positioning over intensity, avoid extended grinding points, protect movement quality, and keep serving effort controlled."
            case .squash:
                return "Reduce match intensity, take longer recovery between rallies, avoid repeated maximal efforts, and finish before technique drops."
            case .generic:
                return "Stay below your normal ceiling, avoid hard work, and shorten the session if effort feels flat."
            }
        }

        func phaseRecommendation(for phase: CoachActiveSessionPhase?) -> String {
            switch phase {
            case .started, .none:
                switch self {
                case .cycling:
                    return "Keep the first 10-15 minutes easy, stay aerobic, and let the ride settle before building."
                case .running:
                    return "Start conversational, ignore early pace targets, and let breathing set the ceiling."
                case .upperBody:
                    return "Use warm-up sets to lower the ceiling, then keep load below normal and leave reps in reserve."
                case .tennis:
                    return "Start efficient, use positioning over intensity, and avoid chasing every ball early."
                case .squash:
                    return "Open below match intensity, take longer recovery between rallies, and keep movement quality clean."
                case .generic:
                    return "Keep the first minutes easy. Finish with reserve."
                }
            case .middle:
                switch self {
                case .cycling:
                    return "Stay aerobic, keep power below your normal ceiling, and avoid threshold efforts."
                case .running:
                    return "Stay conversational, keep pace expectations reduced, and skip tempo or interval work."
                case .upperBody:
                    return "Reduce working weight, avoid grinding sets, and leave reps in reserve."
                case .tennis:
                    return "Protect movement quality, keep serving effort controlled, and choose positioning over intensity."
                case .squash:
                    return "Control match intensity, extend recovery between rallies, and avoid repeated maximal efforts."
                case .generic:
                    return "Stay repeatable. Finish with reserve."
                }
            case .finishing:
                switch self {
                case .cycling:
                    return "Finish controlled and leave recovery room instead of chasing the final minutes."
                case .running:
                    return "Finish fresh, keep it conversational, and shorten rather than forcing pace."
                case .upperBody:
                    return "Stop before failure work, leave reps in reserve, and finish with clean technique."
                case .tennis:
                    return "Finish with reserve, protect movement quality, and avoid extended grinding points."
                case .squash:
                    return "Finish before fatigue drives technique down and avoid another maximal rally block."
                case .generic:
                    return "Finish controlled. Leave recovery room."
                }
            case .postSession:
                return "Stop adding work. Start recovery now."
            }
        }

        var risk: String {
            switch self {
            case .cycling:
                return "Threshold efforts, hard intervals, or chasing power when recovery is limited."
            case .running:
                return "Tempo work, hard intervals, or forcing pace when the run should stay conversational."
            case .upperBody:
                return "Grinding sets, top-end load, or failure training when quality should lead."
            case .tennis:
                return "Extended grinding points, chasing every ball, or serving harder than today's recovery supports."
            case .squash:
                return "Repeated maximal rallies or pushing past the point where technique starts dropping."
            case .generic:
                return ""
            }
        }
    }

    enum Constraint: Hashable {
        case hydration
        case fuel
        case futureHeat
        case tomorrowLoad
        case recovery
        case sleep
        case manualStart
        case remainingLoad

        var readText: String {
            switch self {
            case .hydration:
                return "hydration is not yet supporting the day"
            case .fuel:
                return "fuel is still light for training"
            case .futureHeat:
                return "heat still has to fit into the day"
            case .tomorrowLoad:
                return "tomorrow still needs freshness"
            case .recovery:
                return "readiness sets a lower ceiling"
            case .sleep:
                return "shorter sleep lowers the margin"
            case .manualStart:
                return "this activity was added to the plan"
            case .remainingLoad:
                return "there is still load left after this"
            }
        }

        var decisionText: String {
            switch self {
            case .hydration:
                return "keep fluids calm and available"
            case .fuel:
                return "do not turn this into a hard effort before food is in"
            case .futureHeat:
                return "leave room for the later heat block"
            case .tomorrowLoad:
                return "protect tomorrow's starting point"
            case .recovery:
                return "let recovery set the ceiling"
            case .sleep:
                return "avoid adding stress that follows you into the next block"
            case .manualStart:
                return "treat this as a change to the day, not a free extra"
            case .remainingLoad:
                return "keep enough in reserve for what remains"
            }
        }
    }

    let activeName: String
    private let sportProfile: SportProfile
    let objective: CoachObjective
    let constraints: [Constraint]
    let primaryConstraint: Constraint?
    let phaseContext: String
    let activePhase: CoachActiveSessionPhase?
    let futureHeatName: String

    init(priority: CoachDayPriorityResult, interpretation i: HumanCoachInterpretation) {
        self.activeName = i.activeTrainingName
        self.sportProfile = SportProfile(text: [
            i.activeTrainingName,
            priority.activity?.title ?? "",
            priority.activity?.type ?? "",
            i.context.activityContext.activeActivity?.title ?? "",
            i.context.activityContext.activeActivity?.type ?? ""
        ].joined(separator: " "))
        self.objective = Self.objective(priority: priority, interpretation: i)
        self.phaseContext = i.activeTrainingPhaseContext
        self.activePhase = i.context.activityContext.activeSessionPhase
        self.futureHeatName = i.heatPlanDescription.isEmpty ? "heat" : i.heatPlanDescription
        self.constraints = Self.constraints(priority: priority, interpretation: i)
        self.primaryConstraint = self.constraints.first
    }

    var status: CoachStatus {
        return constraints.isEmpty ? .keepItEasy : .manageEffort
    }

    var title: String {
        if !sportProfile.title.isEmpty {
            return sportProfile.title
        }

        return "Control today's \(sessionTitleName)"
    }

    var myRead: String {
        guard let primaryConstraint else {
            if !sportProfile.fallbackRead.isEmpty {
                return sportProfile.fallbackRead
            }
            return "\(activeName.capitalizedFirst) is live. Keep the effort controlled and finish with reserve."
        }

        if !sportProfile.limiterRead.isEmpty,
           primaryConstraint == .sleep || primaryConstraint == .recovery {
            return "\(readSentence(for: primaryConstraint)) \(sportProfile.limiterRead)"
        }

        return "\(activeLabel.capitalizedFirst) should stay controlled. \(readSentence(for: primaryConstraint))"
    }

    func recommendation(phaseRecommendation: String) -> String {
        if constraints.contains(.sleep) || constraints.contains(.recovery) {
            return sportProfile.limitedRecommendation
        }

        return sportProfile.phaseRecommendation(for: activePhase)
    }

    var beCarefulWith: String {
        guard let primaryConstraint else {
            if !sportProfile.risk.isEmpty {
                return sportProfile.risk
            }

            switch activePhase {
            case .started, .none:
                return "Locking into the planned effort before the warm-up confirms it."
            case .middle:
                return "Chasing numbers if the repeatable effort is already clear."
            case .finishing:
                return "Turning the finish into a final test when the training signal is already there."
            case .postSession:
                return "Adding more work after the useful signal is already complete."
            }
        }

        return riskSentence(for: primaryConstraint)
    }

    var why: String? {
        nil
    }

    var planChallenge: String? {
        nil
    }

    private var isRide: Bool {
        sportProfile == .cycling
    }

    private var activeLabel: String {
        isRide ? "today's ride" : activeName
    }

    private var sessionTitleName: String {
        activeName == "this session" ? "session" : activeName
    }

    var actions: [CoachSupportActionTypeV3] {
        var result: [CoachSupportActionTypeV3] = [.controlIntensity]

        if constraints.contains(.hydration) || constraints.contains(.futureHeat) {
            result.append(.steadyHydration)
        }

        if primaryConstraint == .fuel {
            result.append(.sustainEnergy)
        }

        if constraints.contains(.tomorrowLoad) || constraints.contains(.recovery) || constraints.contains(.sleep) || constraints.contains(.manualStart) || constraints.contains(.remainingLoad) {
            result.append(.cooldown)
        }

        if result.count < 3 {
            result.append(.steadyHydration)
        }

        if result.count < 3 {
            result.append(.cooldown)
        }

        return Array(Self.uniqueActions(result).prefix(3))
    }

    private func readSentence(for constraint: Constraint) -> String {
        switch constraint {
        case .hydration:
            if constraints.contains(.fuel), constraints.contains(.futureHeat) {
                return "Hydration is still behind, with fuel light before \(futureHeatName)."
            }
            if constraints.contains(.fuel) {
                return "Hydration is still behind, and fuel is light."
            }
            if constraints.contains(.futureHeat) {
                return "Hydration is still behind before \(futureHeatName)."
            }
            return "Hydration is still behind."
        case .fuel:
            if constraints.contains(.hydration) {
                return "Fuel is light, with hydration still behind."
            }
            return "Fuel is still light for this effort."
        case .futureHeat:
            return "\(futureHeatName.capitalizedFirst) later sets the ceiling."
        case .tomorrowLoad:
            return "Tomorrow's training is the limiter."
        case .recovery:
            return "Recovery does not support productive hard efforts today."
        case .sleep:
            return "Short sleep lowers today's ceiling."
        case .manualStart:
            return "This adds load to the day."
        case .remainingLoad:
            return "There is still load left today."
        }
    }

    private func decisionSentence(for constraint: Constraint) -> String {
        switch constraint {
        case .hydration:
            return "Keep this easy and sip calmly if water is available."
        case .fuel:
            if activeName.localizedCaseInsensitiveContains("strength") ||
                activeName.localizedCaseInsensitiveContains("gym") ||
                activeName.localizedCaseInsensitiveContains("workout") {
                return "Keep form clean and leave reps in reserve until food is covered."
            }
            return "Keep this easy until food is covered."
        case .futureHeat:
            return "Keep this easy and leave room for \(futureHeatName)."
        case .tomorrowLoad:
            return "Keep this restorative and protect tomorrow."
        case .recovery:
            return "Keep effort below what recovery can support."
        case .sleep:
            return "Keep the session easy and avoid extra stress."
        case .manualStart:
            return "Treat this as added load, not a free extra."
        case .remainingLoad:
            return "Keep enough in reserve for what remains."
        }
    }

    private func secondaryDecisionSentence(for constraint: Constraint) -> String {
        switch constraint {
        case .hydration:
            if constraints.contains(.fuel) {
                return "Do not push intensity before food and fluids are handled."
            }
            return "Do not chase intensity while fluids are behind."
        case .fuel:
            if constraints.contains(.hydration) {
                return "Do not push intensity before food and fluids are handled."
            }
            return "Save intensity for a better-fueled block."
        case .futureHeat:
            return "Do not spend the heat budget early."
        case .tomorrowLoad:
            return "Finish fresher than you started."
        case .recovery:
            return "Let body feedback set the ceiling."
        case .sleep:
            return "Finish with reserve."
        case .manualStart:
            return "Keep the rest of the plan adjustable."
        case .remainingLoad:
            return "Finish with reserve."
        }
    }

    private func riskSentence(for constraint: Constraint) -> String {
        switch constraint {
        case .hydration:
            if constraints.contains(.fuel) {
                return "Turning this into hard work before fuel and hydration are handled."
            }
            return "Forcing intensity while fluids are behind."
        case .fuel:
            if activeName.localizedCaseInsensitiveContains("strength") ||
                activeName.localizedCaseInsensitiveContains("gym") ||
                activeName.localizedCaseInsensitiveContains("workout") {
                return "Chasing load or sloppy reps before fuel is handled."
            }
            return "Forcing intensity before fuel is handled."
        case .futureHeat:
            return "Spending the effort you still need for \(futureHeatName)."
        case .tomorrowLoad:
            return "Letting today's session steal from tomorrow."
        case .recovery:
            return "Working above what recovery can absorb."
        case .sleep:
            return "Adding stress that carries into the next block."
        case .manualStart:
            return "Treating an added session like it was already in the plan."
        case .remainingLoad:
            return "Emptying the tank before the day is done."
        }
    }

    private static func objective(
        priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachObjective {
        if priority.objective != .executeActivity {
            return priority.objective
        }

        if i.context.tomorrowContext?.hasHardTraining == true {
            return .protectTomorrow
        }

        if i.hasHeatAheadToday, i.hydrationIsEmptyOrBehind {
            return .prepareActivity
        }

        if i.trainingReadinessIsLimited || i.fuelingIsEmptyOrBehind || i.hydrationIsEmptyOrBehind {
            return .buildReadiness
        }

        return .executeActivity
    }

    private static func constraints(
        priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> [Constraint] {
        let support = priority.supportBullets.joined(separator: " ").lowercased()
        var result: [Constraint] = []

        if i.isLateEvening {
            result.append(.sleep)
        }

        if priority.limiter == .hydration ||
            support.contains("hydration is significantly behind") ||
            support.contains("hydration before") ||
            support.contains("add 300") ||
            support.contains("add 400") {
            result.append(.hydration)
        }

        if i.fuelingIsEmptyOrBehind ||
            support.contains("fuel is still missing") ||
            support.contains("pre-workout carbs") {
            result.append(.fuel)
        }

        if i.hasHeatAheadToday {
            result.append(.futureHeat)
        }

        if i.context.tomorrowContext?.hasHardTraining == true {
            result.append(.tomorrowLoad)
        }

        if i.trainingReadinessIsLimited {
            result.append(.recovery)
        }

        if i.sleepHours.map({ $0 < 6.5 }) == true {
            result.append(.sleep)
        }

        if i.isRealityStartedByUser {
            result.append(.manualStart)
        }

        if i.context.activityContext.nextUpcomingActivity != nil ||
            i.context.activityContext.laterTodayActivity != nil {
            result.append(.remainingLoad)
        }

        return uniqueConstraints(result)
    }

    private static func phaseDecision(from phaseRecommendation: String) -> String {
        let firstSentence = phaseRecommendation
            .split(whereSeparator: { ".!?".contains($0) })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstSentence, !firstSentence.isEmpty else {
            return "Use the session to confirm what effort is repeatable."
        }

        return firstSentence.hasSuffix(".") ? firstSentence : "\(firstSentence)."
    }

    private static func uniqueActions(_ values: [CoachSupportActionTypeV3]) -> [CoachSupportActionTypeV3] {
        var result: [CoachSupportActionTypeV3] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }

    private static func uniqueConstraints(_ values: [Constraint]) -> [Constraint] {
        var result: [Constraint] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }

    private static func list(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }
}

enum HumanCoachDecisionEngine {

    static func resolve(
        context: CoachDecisionContext,
        priority legacyPriority: CoachDayPriorityResult
    ) -> HumanCoachDecision {
        let interpretation = HumanCoachInterpretation(context: context)
        return CoachSituationStory.assess(
            interpretation,
            legacyPriority: legacyPriority
        )
        .decision(
            sourceSignals: interpretation.signals,
            legacyPriority: legacyPriority,
            interpretation: interpretation
        )
    }

    static func adapt(
        _ decision: HumanCoachDecision,
        phase: CoachActivityPhaseV3,
        opportunity: CoachSupportOpportunityV3,
        legacyPriority: CoachDayPriorityResult,
        activityIdentityIsCertain: Bool = true,
        activeSessionPhase: CoachActiveSessionPhase? = nil
    ) -> CoachGuidanceV3 {
        let displayStatus = decision.narrativePlan.map {
            CoachStatus(label: $0.badgeIntent.label, urgency: $0.urgency)
        } ?? decision.status
        let icon = icon(for: displayStatus)
        let tone = decision.narrativePlan?.tone ?? tone(for: decision)
        let color = displayStatus.color
        let storyPriority = decision.v5Contract?.priority ?? storyPriority(
            for: decision,
            legacyPriority: legacyPriority
        )
        let preservesTomorrowPlanRisk = storyPriority.focus == .tomorrowPlanRisk
        let screenStory = CoachScreenStory(
            decision: decision,
            phase: phase,
            activityIdentityIsCertain: activityIdentityIsCertain,
            activeSessionPhase: activeSessionPhase,
            titleOverride: preservesTomorrowPlanRisk ? storyPriority.todayTitle : nil,
            icon: icon,
            color: color,
            tone: tone
        )
        let renderedTitle = decision.title
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachTitlePipeline]",
            "candidateTitle=\"\(legacyPriority.detailTitle)\" decisionTitle=\"\(decision.title)\" guidanceTitle=\"\(decision.title)\" screenStoryTitle=\"\(screenStory.title)\" renderedTitle=\"\(renderedTitle)\" fallbackUsed=\(!CoachSituationStory.isValidPrimaryTitle(decision.title))"
        )
        #endif

        let visibleSupportActions = screenStory.primaryActions.map {
            CoachSupportActionV3(
                type: $0.type,
                icon: $0.icon,
                title: $0.title,
                subtitle: $0.subtitle,
                color: $0.color
            )
        }

        let tomorrowPlanGuidanceMessage = "Tomorrow includes a meaningful session. Protect tomorrow by rebuilding basics today."

        return CoachGuidanceV3(
            phase: phase,
            opportunity: opportunity,
            priority: storyPriority,
            shouldSurface: decision.v5Contract?.shouldSurface ?? true,
            stateLabel: displayStatus.label,
            title: preservesTomorrowPlanRisk ? storyPriority.todayTitle : decision.title,
            message: preservesTomorrowPlanRisk ? tomorrowPlanGuidanceMessage : visibleMessage(for: decision),
            insightTitle: preservesTomorrowPlanRisk ? storyPriority.todayTitle : decision.title,
            insightSubtitle: preservesTomorrowPlanRisk ? "Protect tomorrow by rebuilding basics today." : decision.myRecommendation,
            supportActions: visibleSupportActions,
            avoidNotes: screenStory.shouldShowBeCarefulWith ? [decision.beCarefulWith] : [],
            icon: icon,
            color: color,
            importance: decision.narrativePlan.map { importance(for: $0.urgency) } ?? decision.priority.importance,
            tone: tone,
            screenStory: screenStory,
            v5Contract: decision.v5Contract,
            narrativePlan: decision.narrativePlan
        )
    }
}

private extension HumanCoachDecisionEngine {

    static func visibleMessage(for decision: HumanCoachDecision) -> String {
        visibleMessage(
            title: decision.title,
            myRead: decision.myRead,
            myRecommendation: decision.myRecommendation,
            beCarefulWith: decision.beCarefulWith,
            why: decision.why
        )
    }

    static func visibleMessage(
        title: String,
        myRead: String,
        myRecommendation: String,
        beCarefulWith: String,
        why: String?
    ) -> String {
        var sections = [
            "My Read\n\(myRead)",
            "My Recommendation\n\(myRecommendation)",
            "Be Careful With\n\(beCarefulWith)"
        ]

        if let why = why?.trimmingCharacters(in: .whitespacesAndNewlines), !why.isEmpty {
            sections.append("Why\n\(why)")
        }

        return sections.joined(separator: "\n\n")
    }

    static func storyPriority(
        for decision: HumanCoachDecision,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachDayPriorityResult {
        if let plan = decision.narrativePlan {
            return CoachDayPriorityResult(
                focus: legacyPriority.focus,
                level: importance(for: plan.urgency).dayPriorityLevel,
                reason: plan.sectionIntents.myRead,
                activity: legacyPriority.activity,
                overridesTimingFocus: legacyPriority.overridesTimingFocus,
                priority: plan.priority,
                strength: legacyPriority.strength,
                confidence: plan.confidence,
                mode: legacyPriority.mode,
                limiter: coachLimiter(for: plan.primaryLimiter, fallback: legacyPriority.limiter),
                messageFamily: legacyPriority.messageFamily,
                priorityScore: legacyPriority.priorityScore,
                insightScore: legacyPriority.insightScore,
                uniquenessScore: legacyPriority.uniquenessScore,
                decisionScore: legacyPriority.decisionScore,
                todayTitle: decision.title,
                todayMessage: decision.myRecommendation,
                detailTitle: decision.title,
                detailMessage: visibleMessage(for: decision),
                supportBullets: decision.supportingActions.map(\.title),
                whyThisMatters: decision.why,
                reasons: legacyPriority.reasons,
                planChallenge: decision.planChallenge,
                horizon: legacyPriority.horizon,
                objective: legacyPriority.objective == .protectTomorrow ? .protectTomorrow : plan.objective,
                opportunity: legacyPriority.opportunity,
                interventionValue: legacyPriority.interventionValue,
                interventionCostNote: legacyPriority.interventionCostNote,
                completionState: legacyPriority.completionState,
                tomorrowProtection: legacyPriority.tomorrowProtection
            )
        }

        let mappedPriority: CoachDayPriority
        let focus: CoachDayFocus
        let limiter: CoachLimiter
        let mode: CoachingMode

        switch decision.status.semanticColor {
        case .red:
            mappedPriority = .planChallenge
            focus = .trainingReadinessWarning
            limiter = .trainingReadiness
            mode = .warning
        case .purple:
            mappedPriority = .planChallenge
            focus = decision.status.label == CoachStatus.protectTomorrow.label ? .tomorrowPlanRisk : .dailyOverview
            limiter = .upcomingTraining
            mode = .adjustment
        case .yellow:
            mappedPriority = .performance
            focus = .trainingReadinessWarning
            limiter = .timing
            mode = .adjustment
        case .blue:
            mappedPriority = .activeSession
            focus = .activeActivity
            limiter = .timing
            mode = .execution
        case .green:
            mappedPriority = .stable
            focus = .dailyOverview
            limiter = .none
            mode = decision.status.label == CoachStatus.opportunityDay.label ? .opportunity : .reinforcement
        }

        return CoachDayPriorityResult(
            focus: focus,
            level: decision.priority == .supporting ? .quiet : decision.priority.importance.dayPriorityLevel,
            reason: decision.myRead,
            activity: legacyPriority.activity,
            overridesTimingFocus: true,
            priority: mappedPriority,
            mode: mode,
            limiter: limiter,
            todayTitle: decision.title,
            todayMessage: decision.myRecommendation,
            detailTitle: decision.title,
            detailMessage: visibleMessage(for: decision),
            supportBullets: decision.supportingActions.map(\.title),
            whyThisMatters: decision.why,
            reasons: legacyPriority.reasons,
            planChallenge: decision.planChallenge,
            horizon: legacyPriority.horizon,
            objective: legacyPriority.objective,
            opportunity: legacyPriority.opportunity,
            interventionValue: legacyPriority.interventionValue,
            interventionCostNote: legacyPriority.interventionCostNote,
            completionState: legacyPriority.completionState,
            tomorrowProtection: legacyPriority.tomorrowProtection
        )
    }

    static func coachLimiter(
        for limiter: CoachNarrativeLimiter,
        fallback: CoachLimiter
    ) -> CoachLimiter {
        switch limiter {
        case .hydration:
            return .hydration
        case .fuel:
            return .fueling
        case .recovery:
            return .recovery
        case .sleep:
            return .sleep
        case .futureLoad:
            return .upcomingTraining
        case .timing:
            return .timing
        case .heat, .formQuality, .intensityControl, .none:
            return fallback
        }
    }

    static func importance(for urgency: CoachUrgency) -> CoachGuidanceImportanceV3 {
        switch urgency {
        case .safety:
            return .high
        case .caution, .planning:
            return .important
        case .execution:
            return .useful
        case .onTrack:
            return .quiet
        }
    }

    static func hardTrainingOnLimitedReadiness(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .adjustPlan,
            title: "Keep the \(i.nextTrainingName), reduce the intensity",
            myRead: "Your recovery is lower than today's training asks for. The limiter is recovery, not fitness.",
            myRecommendation: "Keep the session if you want, but remove the hard parts. Start easy and let the warm-up decide whether effort belongs today.",
            beCarefulWith: "Forcing intensity because it is on the calendar.",
            why: i.recoverySummary,
            priority: .trainingQuality,
            actions: [.controlIntensity, .hydrateBeforeSession]
        )
    }

    static func saunaBeforeTraining(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .planChanged,
            title: "Sauna changes the rest of today",
            myRead: "The day just changed. Sauna can support recovery, but it still adds heat stress before \(i.nextTrainingName).",
            myRecommendation: "Keep sauna short and comfortable. I would reduce training intensity afterwards.",
            beCarefulWith: "Treating heat and training as two separate hard efforts.",
            why: i.hydrationSafetyNote,
            priority: .planOptimization,
            actions: [.rehydrateGradually, .controlIntensity]
        )
    }

    static func trainingGoalAchieved(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .trainingGoalAchieved,
            title: "The useful work is already done",
            myRead: "Today's primary training load is already covered. Additional work has little upside now.",
            myRecommendation: "Focus on recovery, normal food, hydration, and the next important session.",
            beCarefulWith: "Adding another workout because you still feel good.",
            why: i.tomorrowSummary,
            priority: .planOptimization,
            actions: [.rehydrateGradually, .startRecoveryNutrition, .sleepPriority]
        )
    }

    static func unexpectedTrainingStarted(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .dayHasChanged,
            title: "This is no longer a recovery day",
            myRead: "The \(i.activeTrainingName) became today's primary training load.",
            myRecommendation: "Keep the effort easy and treat recovery as the next priority afterwards.",
            beCarefulWith: "Adding more activity later tonight.",
            why: nil,
            priority: .trainingQuality,
            actions: [.controlIntensity, .rehydrateGradually]
        )
    }

    static func nothingNeedsFixing(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .nothingNeedsFixing,
            title: "The day is in a good place",
            myRead: "Training, recovery, and preparation are balanced.",
            myRecommendation: "Enjoy the evening and keep a normal routine.",
            beCarefulWith: "Trying to optimize things that are already working.",
            why: nil,
            priority: .supporting,
            actions: [.stayConsistent]
        )
    }

    static func protectTomorrow(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        let isAfterMidnight = i.isAfterMidnightBeforeMorning
        return make(
            i,
            status: .protectTomorrow,
            title: isAfterMidnight ? "Protect the morning" : "Tomorrow matters more now",
            myRead: isAfterMidnight
                ? "The next important event is later today. The useful move now is sleep, not catching up."
                : "Tomorrow's \(i.tomorrowTrainingName) is now more important than anything left today.",
            myRecommendation: isAfterMidnight ? "Keep the night quiet and let sleep do the work." : "Prioritize sleep and arrive fresh.",
            beCarefulWith: "Late activity, late meals, or anything that delays recovery.",
            why: nil,
            priority: .planOptimization,
            actions: [.sleepPriority]
        )
    }

    static func activeTrainingWithUnsafeReadiness(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .reducePlan,
            title: "Do not force intensity today",
            myRead: "Today's limiter is recovery. The body is not ready for productive intensity.",
            myRecommendation: "Convert the \(i.activeTrainingName) into an easy recovery effort or stop early if the legs feel flat.",
            beCarefulWith: "Intervals, threshold work, or trying to prove fitness today.",
            why: i.recoverySummary,
            priority: .safety,
            actions: [.controlIntensity, .cooldown]
        )
    }

    static func opportunityDay(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .opportunityDay,
            title: "Today can absorb training",
            myRead: "This is one of the stronger readiness profiles recently. The body is ready to absorb useful training.",
            myRecommendation: "If you were considering a meaningful session this week, today is a good candidate.",
            beCarefulWith: "Wasting a high-readiness day on random activity that creates fatigue without purpose.",
            why: i.recoverySummary,
            priority: .planOptimization,
            actions: [.stayConsistent]
        )
    }

    static func saunaAfterHardTraining(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .keepControlled,
            title: "Use sauna carefully",
            myRead: "The hard work is already done. Sauna can be relaxing, but after hard training it can also add stress.",
            myRecommendation: "Keep sauna short. Rehydrate afterwards and make recovery the next priority.",
            beCarefulWith: "Long heat exposure or adding more activity tonight.",
            why: i.hydrationSafetyNote,
            priority: .trainingQuality,
            actions: [.rehydrateGradually, .sleepPriority]
        )
    }

    static func activeRecovery(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .supportSession,
            title: "Use this as recovery",
            myRead: "\(i.activeRecoveryName.capitalizedFirst) can support the day if it stays easy.",
            myRecommendation: "Keep it easy so it helps recovery and does not steal energy from the next session.",
            beCarefulWith: "Letting an easy action turn into another training load.",
            why: nil,
            priority: .supporting,
            actions: [.controlIntensity]
        )
    }

    static func goodOpenDay(_ i: HumanCoachInterpretation) -> HumanCoachDecision {
        make(
            i,
            status: .goodToGo,
            title: "Today is available",
            myRead: "You recovered well, slept enough, and recent load is light. Nothing important is limiting today.",
            myRecommendation: "If you want to train, today supports one purposeful block that fits the week.",
            beCarefulWith: "Adding intensity just because recovery is high. Today does not require a hard session.",
            why: nil,
            priority: .supporting,
            actions: [.stayConsistent]
        )
    }

    static func stableDay(
        _ i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> HumanCoachDecision {
        make(
            i,
            status: .goodToGo,
            title: legacyPriority.detailTitle == "Day overview" ? "Nothing needs chasing" : legacyPriority.detailTitle,
            myRead: "The day does not show a safety or training-quality problem right now.",
            myRecommendation: legacyPriority.detailMessage,
            beCarefulWith: "Turning normal support signals into the main goal.",
            why: nil,
            priority: .supporting,
            actions: [.stayConsistent]
        )
    }

    static func make(
        _ i: HumanCoachInterpretation,
        status: CoachStatus,
        title: String,
        myRead: String,
        myRecommendation: String,
        beCarefulWith: String,
        why: String?,
        planChallenge: String? = nil,
        priority: CoachDecisionPriority,
        actions: [CoachSupportActionTypeV3]
    ) -> HumanCoachDecision {
        return HumanCoachDecision(
            status: status,
            title: title,
            myRead: myRead,
            myRecommendation: myRecommendation,
            beCarefulWith: beCarefulWith,
            why: why,
            planChallenge: planChallenge,
            supportingActions: actions.map { supportAction(for: $0) },
            priority: priority,
            sourceSignals: i.signals,
            v5Contract: nil,
            narrativePlan: nil
        )
    }

    static func supportAction(for type: CoachSupportActionTypeV3) -> CoachSupportingAction {
        switch type {
        case .controlIntensity:
            return CoachSupportingAction(type: type, icon: "speedometer", title: "Keep effort easy", subtitle: "Let readiness set the ceiling", color: Color.orange)
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually:
            return CoachSupportingAction(type: type, icon: "drop.fill", title: "Sip to comfort", subtitle: "Use fluids as support, not the main goal", color: Color.blue)
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy:
            return CoachSupportingAction(type: type, icon: "fork.knife", title: "Eat normally", subtitle: "Support recovery and training quality", color: WeekFitTheme.meal)
        case .sleepPriority:
            return CoachSupportingAction(type: type, icon: "moon.fill", title: "Protect sleep", subtitle: "Tonight sets up the next session", color: WeekFitTheme.purple)
        case .cooldown, .mobilityPrep, .lightRecoveryMovement:
            return CoachSupportingAction(type: type, icon: "figure.cooldown", title: "Downshift", subtitle: "Make the next block easier to recover from", color: WeekFitTheme.purple)
        case .stayConsistent:
            return CoachSupportingAction(type: type, icon: "checkmark.circle.fill", title: "Keep the routine", subtitle: "No extra fix is needed", color: WeekFitTheme.meal)
        case .breathingReset, .downshiftNervousSystem:
            return CoachSupportingAction(type: type, icon: "wind", title: "Settle down", subtitle: "Lower stress before the next demand", color: WeekFitTheme.purple)
        case .keepDigestionLight:
            return CoachSupportingAction(type: type, icon: "leaf.fill", title: "Keep food light", subtitle: "Avoid adding digestive stress", color: WeekFitTheme.meal)
        case .electrolyteRecovery:
            return CoachSupportingAction(type: type, icon: "sparkles", title: "Replace minerals", subtitle: "Useful after heat or heavy sweat", color: Color.blue)
        }
    }

    static func icon(for decision: HumanCoachDecision) -> String {
        icon(for: decision.status)
    }

    static func icon(for status: CoachStatus) -> String {
        switch status.semanticColor {
        case .green:
            return "checkmark.seal.fill"
        case .yellow:
            return "exclamationmark.triangle.fill"
        case .red:
            return "hand.raised.fill"
        case .purple:
            return "calendar.badge.clock"
        case .blue:
            return "drop.fill"
        }
    }

    static func tone(for decision: HumanCoachDecision) -> CoachToneV3 {
        switch decision.priority {
        case .safety:
            return .supportive
        case .trainingQuality:
            return .preparation
        case .planOptimization:
            return .calm
        case .supporting:
            return .calm
        }
    }
}

private struct CoachSituationStory {
    enum Kind {
        case protectTomorrow
        case recoveryDay
        case recoverFromLoad
        case fuelBeforeTraining
        case hydrateAroundHeat
        case manageActiveSauna
        case manageActiveTraining
        case keepRecoveryEasy
        case adjustPlannedTraining
        case prepareForTraining
        case normalEvening
        case opportunityDay
        case availableDay
        case steadyDay
        case morningSetup
    }

    let kind: Kind
    let status: CoachStatus
    let title: String
    let myRead: String
    let myRecommendation: String
    let beCarefulWith: String
    let why: String?
    let planChallenge: String?
    let priority: CoachDecisionPriority
    let actions: [CoachSupportActionTypeV3]

    static func assess(
        _ i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachSituationStory {
        let priorityActivity = legacyPriority.activity ?? i.context.activityContext.preparingActivity
        let priorityActivityIsHeat = priorityActivity.map { CoachActivityContextResolverV3.kind(for: $0) == .heat } == true

        if legacyPriority.focus == .tomorrowPlanRisk ||
            legacyPriority.tomorrowProtection.active {
            return priorityPreservedStory(legacyPriority, interpretation: i) ?? protectTomorrow(i)
        }

        if i.sleepDataIsMissing, i.shouldLeadWithRecoveryDay {
            return recoveryDay(i)
        }

        if legacyPriority.priority == .hydration,
           legacyPriority.limiter == .hydration {
            if priorityActivityIsHeat {
                return hydrateAroundHeat(i)
            }
        }

        if legacyPriority.focus == .prepareForActivity,
           priorityActivityIsHeat {
            return hydrateAroundHeat(i)
        }

        if let preserved = priorityPreservedStory(legacyPriority, interpretation: i) {
            return preserved
        }

        if legacyPriority.tomorrowProtection.active,
           i.context.activityContext.activeActivity == nil,
           i.context.activityContext.preparingActivity == nil {
            return protectTomorrow(i)
        }

        if legacyPriority.focus == .eveningWindDown {
            return normalEvening(i)
        }

        if i.shouldProtectSleepNow {
            return protectTomorrow(i)
        }

        if i.activeHeat != nil {
            return manageActiveSauna(i)
        }

        if i.activeTraining != nil {
            return manageActiveTraining(i, priority: legacyPriority)
        }

        if i.sleepDataIsMissing, i.shouldLeadWithRecoveryDay {
            return recoveryDay(i)
        }

        if legacyPriority.objective == .startDay || i.shouldUseMorningSetup(legacyPriority) {
            return morningSetup(i, legacyPriority: legacyPriority)
        }

        if i.shouldAdjustPlannedTraining {
            return adjustPlannedTraining(i)
        }

        if i.shouldPrepareForTrainingAhead {
            return prepareForTraining(i)
        }

        if i.trainingFuelNeedsAttention {
            return fuelBeforeTraining(i)
        }

        if i.shouldLeadWithRecoveryDay {
            return recoveryDay(i)
        }

        if i.heatHydrationNeedsAttention {
            return hydrateAroundHeat(i)
        }

        if i.shouldLeadWithHydrationSetup(legacyPriority) {
            return hydrationSetup(i, legacyPriority: legacyPriority)
        }

        if i.hasDaytimeCompletedTrainingToProtect {
            return recoverFromLoad(i)
        }

        if i.everythingImportantIsDone {
            return normalEvening(i)
        }

        if i.isHighReadinessOpportunity {
            return opportunityDay(i)
        }

        if i.activeRecovery != nil {
            return keepRecoveryEasy(i)
        }

        if i.isBalancedLateEvening {
            return normalEvening(i)
        }

        if i.isGoodOpenDay {
            return availableDay(i)
        }

        return steadyDay(i, legacyPriority: legacyPriority)
    }

    func decision(
        sourceSignals: [CoachSignal],
        legacyPriority: CoachDayPriorityResult,
        interpretation: HumanCoachInterpretation
    ) -> HumanCoachDecision {
        let decisionTitle = CoachSituationStory.primaryTitle(
            story: self,
            storyTitle: title,
            legacyPriority: legacyPriority
        )
        let narrativePlan = CoachNarrativePlan.make(
            story: self,
            legacyPriority: legacyPriority,
            interpretation: interpretation
        )
        let contract = v5Contract(
            sourceSignals: sourceSignals,
            legacyPriority: legacyPriority,
            interpretation: interpretation,
            narrativePlan: narrativePlan,
            decisionTitle: decisionTitle
        )

        return HumanCoachDecision(
            status: status,
            title: decisionTitle,
            myRead: CoachSituationStory.primaryRead(
                story: self,
                narrativeRead: narrativePlan.sectionIntents.myRead,
                legacyPriority: legacyPriority
            ),
            myRecommendation: narrativePlan.sectionIntents.recommendation,
            beCarefulWith: narrativePlan.riskIntent,
            why: narrativePlan.sectionIntents.why,
            planChallenge: narrativePlan.sectionIntents.planAdjustment,
            supportingActions: actions.map { HumanCoachDecisionEngine.supportAction(for: $0) },
            priority: priority,
            sourceSignals: sourceSignals,
            v5Contract: contract,
            narrativePlan: narrativePlan
        )
    }

    static func primaryTitle(
        story: CoachSituationStory,
        storyTitle: String,
        legacyPriority: CoachDayPriorityResult
    ) -> String {
        if legacyPriority.focus == .eveningWindDown,
           legacyPriority.limiter == .sleep {
            return legacyPriority.title
        }

        if story.usesStoryTitleAsPrimaryTitle(legacyPriority: legacyPriority) {
            return storyTitle
        }

        let priorityTitle = legacyPriority.detailTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidPrimaryTitle(priorityTitle) {
            return priorityTitle
        }

        return storyTitle
    }

    static func primaryRead(
        story: CoachSituationStory,
        narrativeRead: String,
        legacyPriority: CoachDayPriorityResult
    ) -> String {
        if story.kind == .prepareForTraining,
           legacyPriority.priority == .planChallenge,
           legacyPriority.activity != nil {
            return narrativeRead
        }

        let shouldIncludeDiagnosis = story.usesStoryTitleAsPrimaryTitle(legacyPriority: legacyPriority) ||
            legacyPriority.focus == .trainingReadinessWarning
        guard shouldIncludeDiagnosis,
              let diagnosis = story.diagnosisReadPrefix(legacyPriority: legacyPriority) else {
            return narrativeRead
        }

        let trimmedRead = narrativeRead.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRead.localizedCaseInsensitiveContains(diagnosis) else {
            return trimmedRead
        }

        return "\(diagnosis) \(trimmedRead)"
    }

    static func isValidPrimaryTitle(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return normalized != "day overview" && normalized != "overview"
    }

    func usesStoryTitleAsPrimaryTitle(legacyPriority: CoachDayPriorityResult) -> Bool {
        if kind == .manageActiveTraining || kind == .manageActiveSauna {
            return true
        }

        if kind == .recoverFromLoad {
            return true
        }

        if kind == .recoveryDay {
            return true
        }

        if kind == .prepareForTraining,
           legacyPriority.priority == .planChallenge,
           legacyPriority.activity != nil {
            return true
        }

        if status == .protectTomorrow || kind == .protectTomorrow {
            return true
        }

        if legacyPriority.tomorrowProtection.active {
            return true
        }

        return false
    }

    func diagnosisReadPrefix(legacyPriority: CoachDayPriorityResult) -> String? {
        switch legacyPriority.focus {
        case .trainingReadinessWarning:
            if legacyPriority.tomorrowProtection.active || kind == .protectTomorrow {
                return "Training readiness is below the next planned demand."
            }
            return "Readiness is lower than the planned work."
        case .tomorrowPlanRisk:
            return "Tomorrow's plan is carrying more risk than the current recovery picture supports."
        case .recoveryNeeded:
            return "Recovery is the main constraint behind this recommendation."
        default:
            return nil
        }
    }
}

private extension CoachSituationStory {

    func v5Contract(
        sourceSignals: [CoachSignal],
        legacyPriority: CoachDayPriorityResult,
        interpretation: HumanCoachInterpretation,
        narrativePlan: CoachNarrativePlan,
        decisionTitle: String
    ) -> CoachV5Contract {
        let supportTitles = legacyPriority.supportBullets.isEmpty
            ? actions.map { HumanCoachDecisionEngine.supportAction(for: $0).title }
            : legacyPriority.supportBullets
        let plannedRead = narrativePlan.sectionIntents.myRead
        let plannedRecommendation = narrativePlan.sectionIntents.recommendation
        let plannedWhy = narrativePlan.sectionIntents.why
        let plannedRisk = narrativePlan.riskIntent
        let plannedPlanAdjustment = narrativePlan.sectionIntents.planAdjustment
        let contractWhy = CoachSituationStory.conciseWhy(plannedWhy ?? plannedRead)
        let isNoIntervention = status.label == CoachStatus.nothingNeedsFixing.label ||
            (priority == .supporting && legacyPriority.priority == .stable && legacyPriority.limiter == .none)
        let contractWhat = isNoIntervention
            ? "Nothing needs fixing."
            : CoachSituationStory.conciseWhat(from: plannedRecommendation, fallback: title)
        let contractHow = isNoIntervention
            ? "Keep going."
            : CoachSituationStory.conciseHow(plannedRecommendation)
        let shouldSurface = !isNoIntervention && (priority != .supporting || legacyPriority.interventionValue != .none)

        let plannedLimiter = HumanCoachDecisionEngine.coachLimiter(
            for: narrativePlan.primaryLimiter,
            fallback: legacyPriority.limiter
        )
        let contractLimiter = legacyPriority.priority == .sleepPreparation &&
            legacyPriority.focus == .eveningWindDown
            ? legacyPriority.limiter
            : plannedLimiter

        let preservedPriority = CoachDayPriorityResult(
            focus: legacyPriority.focus,
            level: shouldSurface ? legacyPriority.level : .quiet,
            reason: contractWhy,
            activity: legacyPriority.activity,
            overridesTimingFocus: legacyPriority.overridesTimingFocus,
            priority: legacyPriority.priority,
            strength: shouldSurface ? legacyPriority.strength : .low,
            confidence: legacyPriority.confidence,
            mode: legacyPriority.mode,
            limiter: contractLimiter,
            messageFamily: legacyPriority.messageFamily,
            priorityScore: legacyPriority.priorityScore,
            insightScore: legacyPriority.insightScore,
            uniquenessScore: legacyPriority.uniquenessScore,
            decisionScore: legacyPriority.decisionScore,
            todayTitle: legacyPriority.focus == .tomorrowPlanRisk ? legacyPriority.todayTitle : decisionTitle,
            todayMessage: legacyPriority.focus == .tomorrowPlanRisk ? legacyPriority.todayMessage : contractWhat,
            detailTitle: legacyPriority.focus == .tomorrowPlanRisk ? legacyPriority.detailTitle : decisionTitle,
            detailMessage: legacyPriority.focus == .tomorrowPlanRisk ? legacyPriority.detailMessage : HumanCoachDecisionEngine.visibleMessage(
                title: decisionTitle,
                myRead: plannedRead,
                myRecommendation: plannedRecommendation,
                beCarefulWith: plannedRisk,
                why: plannedWhy
            ),
            supportBullets: supportTitles,
            whyThisMatters: shouldSurface ? contractWhy : nil,
            reasons: legacyPriority.reasons,
            planChallenge: plannedPlanAdjustment,
            horizon: legacyPriority.horizon,
            objective: legacyPriority.objective,
            opportunity: legacyPriority.opportunity,
            interventionValue: shouldSurface ? legacyPriority.interventionValue : .none,
            interventionCostNote: legacyPriority.interventionCostNote,
            completionState: shouldSurface ? legacyPriority.completionState : .complete,
            tomorrowProtection: legacyPriority.tomorrowProtection
        )

        return CoachV5Contract(
            dailyObjective: legacyPriority.objective,
            currentReality: plannedRead,
            primaryLimiter: contractLimiter,
            bestNextDecision: contractWhat,
            why: contractWhy,
            what: contractWhat,
            how: contractHow,
            shouldSurface: shouldSurface,
            priority: preservedPriority,
            sourceSignals: sourceSignals,
            timePhase: interpretation.timePhase,
            narrativePlan: narrativePlan
        )
    }

    static func conciseWhy(_ text: String) -> String {
        conciseSentence(text, maxWords: 15)
    }

    static func conciseWhat(from title: String, fallback: String) -> String {
        let sentence = conciseSentence(title, maxWords: 10)
        return sentence.isEmpty ? conciseSentence(fallback, maxWords: 10) : sentence
    }

    static func conciseHow(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Keep the next step simple." }

        let sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)

        let joined = sentences.joined(separator: ". ")
        return joined.hasSuffix(".") ? joined : "\(joined)."
    }

    static func conciseSentence(_ text: String, maxWords: Int) -> String {
        let sentence = text
            .split(whereSeparator: { ".!?".contains($0) })
            .first
            .map(String.init) ?? text
        let words = sentence
            .split(separator: " ")
            .map(String.init)
        let clipped = words.prefix(maxWords).joined(separator: " ")
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension CoachNarrativePlan {
    static func make(
        story: CoachSituationStory,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachNarrativePlan {
        let primaryLimiter = primaryLimiter(
            for: story,
            legacyPriority: legacyPriority,
            interpretation: i
        )
        let secondaryLimiters = secondaryLimiters(
            excluding: primaryLimiter,
            legacyPriority: legacyPriority,
            interpretation: i
        )
        let actionIntents = isNoIntervention(story: story, legacyPriority: legacyPriority) &&
            legacyPriority.focus != .eveningWindDown
            ? []
            : actionIntents(
                for: story,
                legacyPriority: legacyPriority,
                primaryLimiter: primaryLimiter,
                secondaryLimiters: secondaryLimiters,
                interpretation: i
            )
        let sections = sectionIntents(
            for: story,
            primaryLimiter: primaryLimiter,
            legacyPriority: legacyPriority,
            interpretation: i
        )
        let riskIntent = riskIntent(
            for: story,
            primaryLimiter: primaryLimiter
        )

        return CoachNarrativePlan(
            priority: legacyPriority.priority,
            objective: objective(
                for: story,
                primaryLimiter: primaryLimiter,
                legacyPriority: legacyPriority
            ),
            urgency: story.status.urgency,
            primaryLimiter: primaryLimiter,
            secondaryLimiters: secondaryLimiters,
            sessionContext: sessionContext(in: i),
            activityContext: activityContext(in: i),
            remainingDayLoad: remainingDayLoad(in: i),
            sectionIntents: sections,
            actionIntents: actionIntents,
            riskIntent: riskIntent,
            badgeIntent: badgeIntent(
                for: story,
                primaryLimiter: primaryLimiter,
                legacyPriority: legacyPriority,
                interpretation: i
            ),
            tone: tone(for: story),
            confidence: legacyPriority.confidence
        )
    }

    static func objective(
        for story: CoachSituationStory,
        primaryLimiter: CoachNarrativeLimiter,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachObjective {
        if primaryLimiter == .hydration || primaryLimiter == .fuel {
            return .buildReadiness
        }

        if story.kind == .morningSetup {
            return .startDay
        }

        return legacyPriority.objective
    }

    static func primaryLimiter(
        for story: CoachSituationStory,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachNarrativeLimiter {
        if legacyPriority.priority == .sleepPreparation,
           legacyPriority.focus == .eveningWindDown {
            return narrativeLimiter(from: legacyPriority.limiter)
        }

        if i.isVeryPoorState {
            if i.sleepHours.map({ $0 < 5.0 }) == true { return .sleep }
            return .recovery
        }

        return narrativeLimiter(from: legacyPriority.limiter)
    }

    static func narrativeLimiter(from limiter: CoachLimiter) -> CoachNarrativeLimiter {
        switch limiter {
        case .sleep:
            return .sleep
        case .recovery, .accumulatedFatigue, .trainingReadiness, .insufficientRecoveryTime:
            return .recovery
        case .hydration:
            return .hydration
        case .fueling:
            return .fuel
        case .upcomingTraining, .excessivePlannedLoad:
            return .futureLoad
        case .timing:
            return .timing
        case .none:
            return .none
        }
    }

    static func secondaryLimiters(
        excluding primary: CoachNarrativeLimiter,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> [CoachNarrativeLimiter] {
        var values: [CoachNarrativeLimiter] = []

        func append(_ limiter: CoachNarrativeLimiter) {
            guard limiter != primary, limiter != .none, !values.contains(limiter) else { return }
            values.append(limiter)
        }

        if i.hydrationIsEmptyOrBehind || legacyPriority.supportBullets.joined(separator: " ").localizedCaseInsensitiveContains("hydration") {
            append(.hydration)
        }
        if i.fuelingIsEmptyOrBehind || legacyPriority.supportBullets.joined(separator: " ").localizedCaseInsensitiveContains("fuel") {
            append(.fuel)
        }
        if i.trainingReadinessIsLimited {
            append(.recovery)
        }
        if i.sleepHours.map({ $0 < 6.5 }) == true {
            append(.sleep)
        }
        if i.hasHeatAheadToday {
            append(.heat)
        }
        if i.context.tomorrowContext?.hasHardTraining == true ||
            i.context.activityContext.nextUpcomingActivity != nil ||
            i.context.activityContext.laterTodayActivity != nil {
            append(.futureLoad)
        }

        return values
    }

    static func actionIntents(
        for story: CoachSituationStory,
        legacyPriority: CoachDayPriorityResult,
        primaryLimiter: CoachNarrativeLimiter,
        secondaryLimiters: [CoachNarrativeLimiter],
        interpretation i: HumanCoachInterpretation
    ) -> [CoachActionIntent] {
        var intents: [CoachActionIntent] = []

        func append(_ intent: CoachActionIntent) {
            guard !intents.contains(intent) else { return }
            intents.append(intent)
        }

        if legacyPriority.focus == .eveningWindDown {
            if story.kind == .protectTomorrow || legacyPriority.tomorrowProtection.active {
                append(.protectSleep)
                append(.skipExtraTraining)
                if primaryLimiter == .hydration {
                    append(.drink(amountRange: nil, timing: "Sip gradually tonight"))
                } else {
                    append(i.isAfterMidnightBeforeMorning ? .prepareForSleep : .leaveTomorrowForTomorrow)
                }
            } else {
                append(.prepareForSleep)
                append(i.isAfterMidnightBeforeMorning ? .windDownNow : .keepEveningCalm)
                append(.skipExtraTraining)
            }

            return Array(intents.prefix(3))
        }

        if story.kind == .protectTomorrow,
           legacyPriority.focus == .tomorrowPlanRisk {
            append(.objectiveAction(type: .rehydrateGradually, title: "Drink fluids steadily", subtitle: "Rebuild hydration without chasing"))
            append(.objectiveAction(type: .recoveryMeal, title: "Eat normally", subtitle: "Cover basics at the next meal"))
            append(.keepRecoveryEasy)
            return Array(intents.prefix(3))
        }

        switch story.kind {
        case .prepareForTraining:
            if primaryLimiter == .hydration && legacyPriority.strength == .critical {
                append(.drink(amountRange: "300-500 ml", timing: "Do it now, then sip calmly"))
                append(.bringBottle)
                append(.startControlled(duration: "10 minutes"))
            } else {
                for intent in objectivePrimaryActions(for: i, legacyPriority: legacyPriority) {
                    append(intent)
                }
            }

        case .manageActiveTraining:
            if let sportIntents = activeSportActionIntents(for: i, legacyPriority: legacyPriority) {
                sportIntents.forEach(append)
            } else {
                append(.keepIntensity(effort: activeEffortCue(for: i)))
            }
            if primaryLimiter == .sleep {
                append(.finishWithReserve)
                append(.shortenSession)
            } else if primaryLimiter == .recovery {
                append(.finishWithReserve)
                append(.shortenSession)
            }
            if primaryLimiter == .fuel {
                append(.eat(macros: nil, timing: "Keep intensity easy until fuel is covered"))
            }
            if primaryLimiter == .hydration {
                append(.drink(amountRange: nil, timing: "Sip calmly if available"))
            }
            append(.finishWithReserve)

        case .manageActiveSauna, .hydrateAroundHeat:
            for intent in heatPreparationActionIntents(for: i) {
                append(intent)
            }

        case .recoveryDay, .keepRecoveryEasy:
            if story.kind == .recoveryDay, i.heatHydrationSupportNeedsAttention {
                append(.drink(amountRange: "300-500 ml", timing: "Before sauna"))
                append(.objectiveAction(type: .steadyHydration, title: "Enter heat well hydrated", subtitle: "Do not start sauna dry"))
                append(.keepRecoveryEasy)
            } else if story.kind == .recoveryDay, i.sleepDataIsMissing {
                switch i.recoveryDayCopyPhase {
                case .morning:
                    append(.startHydration)
                    append(.objectiveAction(type: .lightFueling, title: "Eat normally at next meal", subtitle: "After water, keep food normal"))
                    append(.keepDayFlexible)
                case .midday:
                    append(.objectiveAction(type: .steadyHydration, title: "Bring fluids online", subtitle: "Sip steadily over the next hour"))
                    append(.objectiveAction(type: .lightFueling, title: "Eat normally at next meal", subtitle: "Keep recovery easy"))
                    append(.keepRecoveryEasy)
                case .evening:
                    append(.objectiveAction(type: .rehydrateGradually, title: "Drink fluids steadily", subtitle: "Protect recovery for tomorrow"))
                    append(.objectiveAction(type: .stayConsistent, title: "Maintain normal routines", subtitle: "Keep food and activity calm"))
                    append(.keepRecoveryEasy)
                }
            } else {
                append(.keepRecoveryEasy)
                append(.finishWithReserve)
                if primaryLimiter == .hydration {
                    append(.drink(amountRange: nil, timing: "Sip calmly"))
                }
            }

        case .morningSetup:
            append(.startHydration)
            append(.eatNextMeal)
            append(i.hasCurrentFutureTrainingToday && !i.sleepDataIsMissing ? .keepPlanUnchanged : .keepDayFlexible)

        case .protectTomorrow:
            append(.protectSleep)
            append(.skipExtraTraining)
            if primaryLimiter == .hydration {
                append(.drink(amountRange: nil, timing: "Sip gradually tonight"))
            } else {
                append(i.isAfterMidnightBeforeMorning ? .prepareForSleep : .leaveTomorrowForTomorrow)
            }

        case .adjustPlannedTraining:
            append(.keepIntensity(effort: "Let readiness set the ceiling"))
            append(.startControlled(duration: "10 minutes"))
            append(.shortenSession)

        case .recoverFromLoad:
            append(.objectiveAction(type: .recoveryMeal, title: "Eat a normal meal with carbs and protein", subtitle: "Make the ride easier to absorb"))
            append(.objectiveAction(type: .rehydrateGradually, title: "Drink 300-500 ml over the next hour", subtitle: "Then sip to comfort"))
            append(.skipExtraTraining)

        case .fuelBeforeTraining:
            append(.eat(macros: "30-60g carbs", timing: "Before training"))
            append(.startControlled(duration: "10 minutes"))
            append(.bringBottle)

        case .normalEvening:
            append(.prepareForSleep)
            append(i.isAfterMidnightBeforeMorning ? .windDownNow : .keepEveningCalm)
            append(.skipExtraTraining)

        case .opportunityDay, .availableDay, .steadyDay:
            let hasFutureActivity = legacyPriority.activity.map { activity in
                !(activity.isCompleted || activity.isSkipped)
            } == true ||
                i.context.activityContext.activeActivity != nil ||
                i.context.activityContext.preparingActivity != nil ||
                i.context.activityContext.nextUpcomingActivity != nil ||
                i.context.activityContext.laterTodayActivity != nil

            if hasFutureActivity {
                append(.keepIntensity(effort: "Keep the session purposeful"))
                append(.startControlled(duration: nil))
            } else {
                append(.keepDayFlexible)
                append(.keepRecoveryEasy)
                append(.eatNextMeal)
            }
        }

        for action in story.actions where primaryLimiter == .hydration || !action.isHydrationSupportIntent {
            append(intent(for: action))
        }

        return Array(intents.prefix(3))
    }

    static func heatPreparationActionIntents(for i: HumanCoachInterpretation) -> [CoachActionIntent] {
        let heatName = i.heatPlanDescription.isEmpty ? "heat" : i.heatPlanDescription
        let executionActions: [CoachActionIntent] = [
            .objectiveAction(type: .steadyHydration, title: "Enter heat well hydrated", subtitle: "Do not start \(heatName) dry"),
            .keepRecoveryEasy
        ]

        switch i.heatPreparationHydrationState {
        case .notStarted:
            return [
                .drink(amountRange: "300-500 ml", timing: "Before \(heatName)"),
                executionActions[0],
                executionActions[1]
            ]
        case .stillLow:
            return [
                .objectiveAction(type: .hydrateBeforeSession, title: "Drink another 300-500 ml before \(heatName)", subtitle: "You have started, but heat still needs more margin"),
                executionActions[0],
                executionActions[1]
            ]
        case .improving:
            return [
                .objectiveAction(type: .steadyHydration, title: "Keep sipping before \(heatName)", subtitle: "No need to chase a large bolus"),
                executionActions[0],
                executionActions[1]
            ]
        case .sufficient:
            return [
                executionActions[0],
                executionActions[1],
                .objectiveAction(type: .cooldown, title: "Avoid staying too long if you feel flat", subtitle: "Stop before heat becomes another stressor")
            ]
        }
    }

    static func activeSportActionIntents(
        for i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> [CoachActionIntent]? {
        let text = [
            i.activeTrainingName,
            legacyPriority.activity?.title ?? "",
            legacyPriority.activity?.type ?? "",
            i.context.activityContext.activeActivity?.title ?? "",
            i.context.activityContext.activeActivity?.type ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        if text.contains("squash") {
            return [
                .objectiveAction(type: .controlIntensity, title: "Control intensity", subtitle: "Keep match effort below today's ceiling"),
                .objectiveAction(type: .breathingReset, title: "Take longer recovery", subtitle: "Give rallies more space"),
                .objectiveAction(type: .cooldown, title: "Protect movement quality", subtitle: "Stop before technique drops")
            ]
        }

        if text.contains("tennis") {
            return [
                .objectiveAction(type: .controlIntensity, title: "Stay efficient", subtitle: "Use positioning over intensity"),
                .objectiveAction(type: .breathingReset, title: "Protect movement quality", subtitle: "Avoid chasing every ball"),
                .objectiveAction(type: .cooldown, title: "Finish with reserve", subtitle: "Leave court before fatigue drives errors")
            ]
        }

        if text.contains("upper body") ||
            text.contains("strength") ||
            text.contains("gym") ||
            text.contains("weights") ||
            text.contains("lifting") {
            return [
                .objectiveAction(type: .controlIntensity, title: "Reduce load", subtitle: "Keep working weight below normal"),
                .objectiveAction(type: .breathingReset, title: "Leave reps in reserve", subtitle: "No grinding sets today"),
                .objectiveAction(type: .cooldown, title: "Avoid failure", subtitle: "Stop before form breaks down")
            ]
        }

        if text.contains("run") ||
            text.contains("jog") {
            return [
                .objectiveAction(type: .controlIntensity, title: "Keep effort easy", subtitle: "Stay below today's ceiling"),
                .objectiveAction(type: .breathingReset, title: "Stay conversational", subtitle: "Let breathing control pace"),
                .objectiveAction(type: .cooldown, title: "Shorten if needed", subtitle: "Finish fresh")
            ]
        }

        if text.contains("ride") ||
            text.contains("cycling") ||
            text.contains("cycl") ||
            text.contains("bike") {
            return [
                .objectiveAction(type: .controlIntensity, title: "Keep effort easy", subtitle: "Stay below today's ceiling"),
                .objectiveAction(type: .breathingReset, title: "Stay aerobic", subtitle: "Skip threshold or interval work"),
                .objectiveAction(type: .cooldown, title: "Finish with reserve", subtitle: "Make recovery easier to start")
            ]
        }

        return nil
    }

    static func objectivePrimaryActions(
        for i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> [CoachActionIntent] {
        let activity = legacyPriority.activity ??
            i.context.activityContext.preparingActivity ??
            i.context.activityContext.nextUpcomingActivity ??
            i.context.activityContext.laterTodayActivity
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let name = i.nextTrainingName

        switch kind {
        case .some(.endurance):
            if name == "ride" || activity?.title.localizedCaseInsensitiveContains("cycl") == true || activity?.title.localizedCaseInsensitiveContains("bike") == true {
                if i.minutesUntilNextTraining.map({ $0 <= 60 }) == true {
                    return [
                        .objectiveAction(type: .lightFueling, title: "Eat 20-40g carbs before the ride", subtitle: "Banana, sports drink, toast, or fruit"),
                        .objectiveAction(type: .hydrateBeforeSession, title: "Drink 300-500 ml before starting", subtitle: "Then bring a bottle"),
                        .objectiveAction(type: .controlIntensity, title: "Keep the first 10-15 minutes easy", subtitle: "Shorten the ride if power feels flat")
                    ]
                }
                return [
                    .objectiveAction(type: .controlIntensity, title: "Keep morning activity easy", subtitle: "Save freshness for the ride"),
                    .objectiveAction(type: .lightFueling, title: "Bring carbs for the ride", subtitle: "Banana, bar, sports drink, or gels"),
                    .objectiveAction(type: .controlIntensity, title: "Keep the first 15-20 minutes easy", subtitle: "Save intensity for later")
                ]
            }
            return [
                .objectiveAction(type: .controlIntensity, title: "Keep the first 10 minutes easy", subtitle: "Let breathing settle first"),
                .objectiveAction(type: .lightFueling, title: "Eat 20-40g carbs before starting", subtitle: "Keep it easy to digest"),
                .objectiveAction(type: .controlIntensity, title: "Build pace gradually", subtitle: "Avoid pushing early")
            ]

        case .some(.workout):
            let title = activity?.title.lowercased() ?? ""
            if title.contains("strength") || title.contains("gym") {
                return [
                    .objectiveAction(type: .controlIntensity, title: "Keep the first sets submaximal", subtitle: "Build into the session"),
                    .objectiveAction(type: .controlIntensity, title: "Leave a rep or two in reserve", subtitle: "Protect quality"),
                    .objectiveAction(type: .controlIntensity, title: "Build into the session", subtitle: "Do not spend everything early")
                ]
            }
            return [
                .objectiveAction(type: .controlIntensity, title: "Keep the opening block easy", subtitle: "Let the session come to you"),
                .objectiveAction(type: .lightFueling, title: "Eat a quick carb snack before starting", subtitle: "Fruit, toast, yogurt, or sports drink"),
                .objectiveAction(type: .controlIntensity, title: "Save intensity for later", subtitle: "Avoid pushing early")
            ]

        case .some(.recovery):
            return [
                .objectiveAction(type: .lightRecoveryMovement, title: "Keep the walk restorative", subtitle: "Stay relaxed"),
                .objectiveAction(type: .controlIntensity, title: "Keep intensity low", subtitle: "Finish fresher than you started"),
                .objectiveAction(type: .controlIntensity, title: "Stay relaxed", subtitle: "Let recovery lead")
            ]

        case .some(.heat):
            return [
                .objectiveAction(type: .controlIntensity, title: "Keep heat exposure conservative", subtitle: "Do not turn heat into effort"),
                .objectiveAction(type: .controlIntensity, title: "Exit before fatigue accumulates", subtitle: "Leave refreshed"),
                .objectiveAction(type: .breathingReset, title: "Downshift after heat", subtitle: "Let recovery start")
            ]

        case .some(.meal), .some(.other), .none:
            return [
                .objectiveAction(type: .stayConsistent, title: "Keep the day simple", subtitle: "No workout plan needs solving now"),
                .objectiveAction(type: .lightFueling, title: "Eat normally at next meal", subtitle: "Build the day gradually"),
                .objectiveAction(type: .stayConsistent, title: "Stay flexible today", subtitle: "Let the next real context decide")
            ]
        }
    }

    static func isNoIntervention(
        story: CoachSituationStory,
        legacyPriority: CoachDayPriorityResult
    ) -> Bool {
        let supportText = legacyPriority.supportBullets.joined(separator: " ").lowercased()
        let hasRelevantSupport = supportText.contains("hydration") ||
            supportText.contains("water") ||
            supportText.contains("sip") ||
            supportText.contains("fluid") ||
            supportText.contains("fuel") ||
            supportText.contains("carb") ||
            supportText.contains("meal") ||
            supportText.contains("sleep") ||
            supportText.contains("recovery")

        if hasRelevantSupport {
            return false
        }

        return story.status == .nothingNeedsFixing ||
            (story.priority == .supporting && legacyPriority.priority == .stable && legacyPriority.limiter == .none)
    }

    static func sectionIntents(
        for story: CoachSituationStory,
        primaryLimiter: CoachNarrativeLimiter,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachNarrativeSectionIntents {
        if story.kind == .prepareForTraining {
            return preparationSectionIntents(
                for: story,
                primaryLimiter: primaryLimiter,
                legacyPriority: legacyPriority,
                interpretation: i
            )
        }

        if story.kind == .manageActiveTraining || story.kind == .recoverFromLoad {
            return CoachNarrativeSectionIntents(
                myRead: story.myRead,
                recommendation: story.myRecommendation,
                activityContext: nil,
                why: story.why,
                planAdjustment: story.planChallenge
            )
        }

        if primaryLimiter == .sleep,
           story.status != .reducePlan,
           story.kind != .normalEvening {
            return CoachNarrativeSectionIntents(
                myRead: "Short sleep is the main recovery constraint today.",
                recommendation: "Keep recovery work easy and make tonight's sleep the main win.",
                activityContext: nil,
                why: "The useful move is absorbing training stress, not adding to it.",
                planAdjustment: story.planChallenge
            )
        }

        return CoachNarrativeSectionIntents(
            myRead: story.myRead,
            recommendation: story.myRecommendation,
            activityContext: nil,
            why: story.why,
            planAdjustment: story.planChallenge
        )
    }

    static func preparationSectionIntents(
        for story: CoachSituationStory,
        primaryLimiter: CoachNarrativeLimiter,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachNarrativeSectionIntents {
        if legacyPriority.priority == .planChallenge {
            return CoachNarrativeSectionIntents(
                myRead: story.myRead,
                recommendation: story.myRecommendation,
                activityContext: nil,
                why: story.why,
                planAdjustment: story.planChallenge
            )
        }

        let stage = CoachSituationStory.preparationStage(legacyPriority, interpretation: i)
        let preparationRead = CoachSituationStory.preparationRead(stage, interpretation: i)
        let preparationRecommendation = CoachSituationStory.preparationRecommendation(stage, interpretation: i)
        let readModifier: String
        let recommendationModifier: String
        let why: String

        switch primaryLimiter {
        case .sleep:
            readModifier = "Short sleep lowers today's ceiling."
            recommendationModifier = "keep the first block easier than planned"
            why = "Sleep changes how hard the session should start; it does not change the next job, which is arriving prepared."
        case .recovery:
            readModifier = "Readiness sets a lower ceiling than the plan assumes."
            recommendationModifier = "let readiness cap the early effort"
            why = "Recovery should shape how the workout is executed, not turn pre-workout guidance into a recovery-day story."
        case .hydration:
            readModifier = "Hydration is still part of the preparation job."
            recommendationModifier = "bring fluids and sip before the start"
            why = "Fluids matter because there is a workout soon, not because hydration owns the whole day."
        case .fuel:
            readModifier = "Fuel is still part of the preparation job."
            recommendationModifier = "cover simple fuel before the start"
            why = "Food matters now because it changes how the workout starts."
        case .heat:
            readModifier = "Heat later adds another load to manage."
            recommendationModifier = "save margin for the rest of the day"
            why = "The workout should leave room for the next stressor."
        case .futureLoad:
            readModifier = "The rest of the plan still needs some margin."
            recommendationModifier = "avoid spending the whole day in the opening block"
            why = "Preparation should protect the whole plan, not only the next start line."
        case .formQuality, .intensityControl:
            readModifier = "Movement quality matters more than forcing pace today."
            recommendationModifier = "use the warm-up to find clean, repeatable effort"
            why = "Preparation should protect execution quality before the workout starts."
        case .timing, .none:
            readModifier = "The useful decision is arriving ready."
            recommendationModifier = "start controlled and adjust by feel"
            why = story.why ?? "The next useful decision is before the workout, not after it."
        }

        return CoachNarrativeSectionIntents(
            myRead: "\(preparationRead) \(readModifier)",
            recommendation: "\(preparationRecommendation) Also \(recommendationModifier).",
            activityContext: nil,
            why: why,
            planAdjustment: story.planChallenge
        )
    }

    static func riskIntent(
        for story: CoachSituationStory,
        primaryLimiter: CoachNarrativeLimiter
    ) -> String {
        if story.kind == .manageActiveTraining || story.kind == .recoverFromLoad {
            return story.beCarefulWith
        }

        if story.kind == .prepareForTraining,
           primaryLimiter == .sleep || primaryLimiter == .recovery {
            return "Treating the planned workout like a normal-ceiling day."
        }

        if primaryLimiter == .sleep,
           story.status != .reducePlan,
           story.kind != .normalEvening {
            return "Turning a low-sleep recovery day into more load."
        }

        return story.beCarefulWith
    }

    static func intent(for action: CoachSupportActionTypeV3) -> CoachActionIntent {
        switch action {
        case .lightFueling, .sustainEnergy:
            return .eat(macros: nil, timing: "Keep it simple and digestible")
        case .hydrateBeforeSession:
            return .drink(amountRange: "300-500 ml", timing: "Before the session")
        case .steadyHydration, .rehydrateGradually:
            return .drink(amountRange: nil, timing: "Sip calmly")
        case .controlIntensity:
            return .keepIntensity(effort: "Let readiness set the ceiling")
        case .cooldown, .mobilityPrep, .lightRecoveryMovement:
            return .finishWithReserve
        case .sleepPriority:
            return .protectSleep
        case .breathingReset, .downshiftNervousSystem:
            return .downshift
        case .stayConsistent:
            return .startControlled(duration: nil)
        case .recoveryMeal, .startRecoveryNutrition:
            return .eat(macros: nil, timing: "Support recovery")
        case .electrolyteRecovery:
            return .drink(amountRange: nil, timing: "Replace fluids steadily")
        case .keepDigestionLight:
            return .eat(macros: nil, timing: "Keep food light")
        }
    }

    static func badgeIntent(
        for story: CoachSituationStory,
        primaryLimiter: CoachNarrativeLimiter,
        legacyPriority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachNarrativeBadgeIntent {
        if story.kind == .manageActiveTraining {
            return story.status == .keepItEasy ? .keepItEasy : .manageEffort
        }

        if story.kind == .recoverFromLoad {
            return .recover
        }

        if legacyPriority.focus == .trainingReadinessWarning {
            return .adjustTrainingReadiness
        }

        if story.status == .reducePlan { return .reducePlan }
        if legacyPriority.priority == .sleepPreparation,
           legacyPriority.focus == .eveningWindDown,
           primaryLimiter == .sleep {
            return .protectSleep
        }
        if story.status == .protectTomorrow {
            return i.isAfterMidnightBeforeMorning ? .protectMorning : .protectTomorrow
        }
        if story.kind == .keepRecoveryEasy || story.kind == .recoveryDay || story.kind == .recoverFromLoad { return .recover }
        if primaryLimiter == .hydration && legacyPriority.strength == .critical { return .hydrate }
        if primaryLimiter == .sleep { return .protectSleep }
        if story.kind == .morningSetup { return .startDay }
        if legacyPriority.focus == .eveningWindDown || story.kind == .normalEvening { return .windDown }
        if story.status == .nothingNeedsFixing || story.status == .goodToGo || story.status == .opportunityDay { return .goodToGo }
        if story.kind == .prepareForTraining { return .prepare }
        if story.kind == .manageActiveTraining && primaryLimiter == .none { return .keepItEasy }
        if primaryLimiter == .hydration && legacyPriority.priority == .hydration && legacyPriority.strength == .critical { return .hydrate }
        if primaryLimiter == .fuel && legacyPriority.priority == .fueling { return .fuel }
        if story.kind == .manageActiveTraining { return .manageEffort }
        if story.kind == .manageActiveSauna { return .keepControlled }
        return story.status.urgency == .execution ? .startEasy : .manageEffort
    }

    static func tone(for story: CoachSituationStory) -> CoachToneV3 {
        switch story.priority {
        case .safety:
            return .supportive
        case .trainingQuality:
            return .preparation
        case .planOptimization, .supporting:
            return .calm
        }
    }

    static func sessionContext(in i: HumanCoachInterpretation) -> CoachActivityKindV3? {
        [
            i.context.activityContext.activeActivity,
            i.context.activityContext.preparingActivity,
            i.context.activityContext.recentlyCompletedActivity,
            i.context.activityContext.nextUpcomingActivity,
            i.context.activityContext.laterTodayActivity
        ]
        .compactMap { $0 }
        .first
        .map { CoachActivityContextResolverV3.kind(for: $0) }
    }

    static func activityContext(in i: HumanCoachInterpretation) -> String? {
        if let active = i.context.activityContext.activeActivity {
            return active.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let preparing = i.context.activityContext.preparingActivity {
            return preparing.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return i.context.activityContext.nextUpcomingActivity?.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func remainingDayLoad(in i: HumanCoachInterpretation) -> String? {
        if i.context.tomorrowContext?.hasHardTraining == true {
            return "tomorrow hard training"
        }
        if let next = i.context.activityContext.nextUpcomingActivity {
            return next.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let later = i.context.activityContext.laterTodayActivity {
            return later.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func activeEffortCue(for i: HumanCoachInterpretation) -> String {
        if let active = i.activeTraining {
            let kind = CoachActivityContextResolverV3.kind(for: active)
            if kind == .workout {
                return "Keep form clean and leave reps in reserve"
            }
        }

        switch i.context.activityContext.activeSessionPhase {
        case .started, .none:
            return "Let the first block settle before building"
        case .middle:
            return "Hold effort you can repeat"
        case .finishing:
            return "Finish with reserve"
        case .postSession:
            return "Start recovery now"
        }
    }
}

private extension CoachSituationStory {

    static func protectTomorrow(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let isAfterMidnight = i.isAfterMidnightBeforeMorning
        return CoachSituationStory(
            kind: .protectTomorrow,
            status: .protectTomorrow,
            title: isAfterMidnight ? "Protect the morning" : "Protect tomorrow",
            myRead: isAfterMidnight
                ? "The next important event is later today. The goal is arriving rested rather than catching up overnight."
                : "Tomorrow's \(i.tomorrowTrainingName) is now the next important event. The goal is arriving fresh rather than adding more work.",
            myRecommendation: isAfterMidnight ? "Protect sleep and keep the night quiet." : "Protect sleep and keep recovery easy tonight.",
            beCarefulWith: "Turning recovery time into more training or activity.",
            why: isAfterMidnight
                ? "The morning depends more on reducing overnight cost than on adding another useful action."
                : "Freshness tomorrow depends more on reducing evening cost than on adding another useful action.",
            planChallenge: nil,
            priority: .planOptimization,
            actions: [.sleepPriority, .downshiftNervousSystem, .keepDigestionLight]
        )
    }

    static func priorityPreservedStory(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachSituationStory? {
        guard priority.activity != nil else { return nil }
        let stage = preparationStage(priority, interpretation: i)

        switch priority.focus {
        case .tomorrowPlanRisk:
            return CoachSituationStory(
                kind: .protectTomorrow,
                status: .protectTomorrow,
                title: priority.detailTitle,
                myRead: tomorrowPlanRiskRead(priority, interpretation: i),
                myRecommendation: tomorrowPlanRiskRecommendation(priority, interpretation: i),
                beCarefulWith: priority.interventionCostNote ??
                    priority.planChallenge ??
                    "Treating tomorrow's plan like it is already safe to absorb.",
                why: priority.whyThisMatters,
                planChallenge: priority.planChallenge,
                priority: .planOptimization,
                actions: [.rehydrateGradually, .recoveryMeal, .controlIntensity]
            )

        case .trainingReadinessWarning:
            guard i.context.activityContext.preparingActivity != nil else { return nil }
            return CoachSituationStory(
                kind: .prepareForTraining,
                status: .adjustPlan,
                title: preparationPlanChallengeTitle(priority, interpretation: i),
                myRead: preparationPlanChallengeRead(priority, interpretation: i),
                myRecommendation: preparationPlanChallengeRecommendation(priority, interpretation: i),
                beCarefulWith: priority.interventionCostNote ??
                    priority.planChallenge ??
                    coachingFirstPreparationCarefulWith(priority, interpretation: i),
                why: "The workout is still the next decision; sleep and readiness should change how you execute it.",
                planChallenge: priority.planChallenge,
                priority: .trainingQuality,
                actions: [.controlIntensity, .hydrateBeforeSession, .lightFueling]
            )

        case .prepareForActivity:
            let hydrationCanLead = hydrationCanLeadNarrative(priority)
            return CoachSituationStory(
                kind: .prepareForTraining,
                status: .prepareSession,
                title: priority.detailTitle,
                myRead: hydrationCanLead ? preparationRead(stage, interpretation: i) : coachingFirstPreparationRead(priority, interpretation: i),
                myRecommendation: hydrationCanLead ? preparationRecommendation(stage, interpretation: i) : coachingFirstPreparationRecommendation(priority, interpretation: i),
                beCarefulWith: priority.interventionCostNote ??
                    priority.planChallenge ??
                    coachingFirstPreparationCarefulWith(priority, interpretation: i),
                why: hydrationCanLead ? preparationWhy(stage, interpretation: i) : coachingFirstPreparationWhy(priority, interpretation: i),
                planChallenge: priority.planChallenge,
                priority: .supporting,
                actions: [.hydrateBeforeSession, .lightFueling, .mobilityPrep]
            )

        case .performanceReadiness:
            guard i.recoveryIsStrong else { return nil }
            let hydrationCanLead = hydrationCanLeadNarrative(priority)
            return CoachSituationStory(
                kind: .prepareForTraining,
                status: .prepareSession,
                title: hydrationCanLead ? priority.detailTitle : coachingFirstPreparationTitle(priority, interpretation: i),
                myRead: hydrationCanLead ? preparationRead(stage, interpretation: i) : coachingFirstPreparationRead(priority, interpretation: i),
                myRecommendation: hydrationCanLead ? preparationRecommendation(stage, interpretation: i) : coachingFirstPreparationRecommendation(priority, interpretation: i),
                beCarefulWith: priority.interventionCostNote ??
                    priority.planChallenge ??
                    coachingFirstPreparationCarefulWith(priority, interpretation: i),
                why: hydrationCanLead ? preparationWhy(stage, interpretation: i) : coachingFirstPreparationWhy(priority, interpretation: i),
                planChallenge: priority.planChallenge,
                priority: .supporting,
                actions: [.hydrateBeforeSession, .lightFueling, .mobilityPrep]
            )

        case .nextActivityLater:
            guard priority.priority == .stable,
                  i.context.activityContext.activeActivity == nil,
                  i.context.activityContext.preparingActivity == nil else {
                return nil
            }
            let hydrationCanLead = hydrationCanLeadNarrative(priority)
            return CoachSituationStory(
                kind: .prepareForTraining,
                status: .prepareSession,
                title: priority.detailTitle,
                myRead: hydrationCanLead ? preparationRead(stage, interpretation: i) : coachingFirstPreparationRead(priority, interpretation: i),
                myRecommendation: hydrationCanLead ? preparationRecommendation(stage, interpretation: i) : coachingFirstPreparationRecommendation(priority, interpretation: i),
                beCarefulWith: priority.interventionCostNote ??
                    priority.planChallenge ??
                    coachingFirstPreparationCarefulWith(priority, interpretation: i),
                why: hydrationCanLead ? preparationWhy(stage, interpretation: i) : coachingFirstPreparationWhy(priority, interpretation: i),
                planChallenge: priority.planChallenge,
                priority: .supporting,
                actions: [.hydrateBeforeSession, .lightFueling, .mobilityPrep]
            )

        default:
            return nil
        }
    }

    static func tomorrowPlanRiskRead(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        let activityName = priority.activity.map { i.activityShortName($0) } ?? i.tomorrowTrainingName
        let trainingName = activityName.isEmpty ? "training" : activityName.lowercased()
        let limiterText = tomorrowPlanLimiterText(priority, interpretation: i)
        return "Tomorrow includes a meaningful \(trainingName) session. \(limiterText.capitalizedFirst) are not yet where they should be."
    }

    static func tomorrowPlanRiskRecommendation(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        "Protect tomorrow by rebuilding basics today."
    }

    static func tomorrowPlanLimiterText(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        var limiters: [String] = []

        if priority.limiter == .recovery ||
            priority.limiter == .accumulatedFatigue ||
            priority.limiter == .trainingReadiness ||
            i.recoveryPercent.map({ $0 < 70 }) == true ||
            i.context.brain.recovery == .vulnerable ||
            i.context.brain.readiness == .low {
            limiters.append("recovery")
        }

        if priority.limiter == .hydration || i.hydrationIsEmptyOrBehind {
            limiters.append("hydration")
        }

        if priority.limiter == .fueling || i.fuelingIsEmptyOrBehind {
            limiters.append("fuel")
        }

        if limiters.isEmpty {
            limiters = ["recovery", "hydration", "fuel"]
        } else {
            for fallback in ["hydration", "fuel"] where !limiters.contains(fallback) {
                limiters.append(fallback)
            }
        }

        return i.list(limiters)
    }

    static func hydrationCanLeadNarrative(_ priority: CoachDayPriorityResult) -> Bool {
        priority.limiter == .hydration && priority.strength == .critical
    }

    static func preparationPlanChallengeTitle(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        let name = activityName(priority, interpretation: i)
        if isRideLike(priority, interpretation: i) {
            return "Reduce ride intensity"
        }
        return "Reduce \(name) intensity"
    }

    static func preparationPlanChallengeRead(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        let name = activityName(priority, interpretation: i).capitalizedFirst
        let timing = i.minutesUntilNextTraining.map { i.preparationTimingText($0) } ?? "soon"
        let limiter = priority.limiter == .sleep || i.sleepHours.map { $0 < 6.0 } == true
            ? "short sleep lowers today's ceiling"
            : "readiness lowers today's ceiling"
        return "\(name) starts in \(timing), but \(limiter)."
    }

    static func preparationPlanChallengeRecommendation(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        if isRideLike(priority, interpretation: i) {
            return "Ride easier than planned, keep the first 10-15 minutes controlled, drink 300-500 ml, take a banana or sports drink before starting, and shorten if you feel flat."
        }
        let name = activityName(priority, interpretation: i)
        return "Take \(name) easier than planned, keep the first 10-15 minutes controlled, drink 300-500 ml, eat a quick carb snack before starting, and shorten if you feel flat."
    }

    static func activityName(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        let explicit = priority.activity?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicit, !explicit.isEmpty {
            return explicit.lowercased()
        }
        return i.nextTrainingName
    }

    static func isRideLike(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> Bool {
        let text = [
            priority.activity?.title ?? "",
            priority.activity?.type ?? "",
            i.nextTrainingName
        ].joined(separator: " ").lowercased()
        return text.contains("cycl") || text.contains("bike") || text.contains("ride")
    }

    static func coachingFirstPreparationRead(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        let timing = i.minutesUntilNextTraining.map { i.preparationTimingText($0) } ?? "later today"
        let activity = i.nextTrainingName
        let selectedActivityText = [
            priority.activity?.title ?? "",
            priority.activity?.type ?? ""
        ].joined(separator: " ").lowercased()
        let isCycling = activity == "ride" ||
            selectedActivityText.contains("cycl") ||
            selectedActivityText.contains("bike") ||
            selectedActivityText.contains("ride")

        switch priority.focus {
        case .nextActivityLater:
            if i.hydrationHasStarted || i.mealLoggedForPreparation {
                return "\(activity.capitalizedFirst) starts in \(timing). Fueling has started and readiness looks good."
            }
            return "You have \(timing) before today's \(activity). There is plenty of time to prepare well."
        case .performanceReadiness:
            return "Readiness supports the \(activity). The useful move is arriving settled, not changing the plan early."
        default:
            if isCycling, i.mealLoggedForPreparation {
                return "The ride starts in \(timing). Breakfast is in, so now the goal is arriving fresh."
            }
            return "The \(activity) is the next meaningful event. The goal is arriving fresh and ready."
        }
    }

    static func coachingFirstPreparationTitle(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        guard priority.focus == .nextActivityLater else { return priority.detailTitle }
        let name = i.nextTrainingName
        let article = ["ride", "run", "walk"].contains(name) ? "the " : ""
        return "Prepare for \(article)\(name)"
    }

    static func coachingFirstPreparationRecommendation(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        switch priority.focus {
        case .nextActivityLater:
            return "Arrive fresh and avoid unnecessary fatigue."
        case .performanceReadiness:
            return "Keep the plan intact, stay calm, and let the start confirm the ceiling."
        default:
            let selectedActivityText = [
                priority.activity?.title ?? "",
                priority.activity?.type ?? ""
            ].joined(separator: " ").lowercased()
            if i.nextTrainingName == "ride" ||
                selectedActivityText.contains("cycl") ||
                selectedActivityText.contains("bike") ||
                selectedActivityText.contains("ride") {
                return "Arrive fueled and fresh."
            }
            return "Build readiness gradually and keep the opening minutes easy."
        }
    }

    static func coachingFirstPreparationCarefulWith(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        switch priority.focus {
        case .nextActivityLater:
            return "Letting the gap before the \(i.nextTrainingName) create extra fatigue."
        default:
            let selectedActivityText = [
                priority.activity?.title ?? "",
                priority.activity?.type ?? ""
            ].joined(separator: " ").lowercased()
            if i.nextTrainingName == "ride" ||
                selectedActivityText.contains("cycl") ||
                selectedActivityText.contains("bike") ||
                selectedActivityText.contains("ride") {
                return "Turning preparation into extra training before the ride."
            }
            return "Turning preparation into urgency before the start."
        }
    }

    static func coachingFirstPreparationWhy(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> String {
        "The useful coaching decision is arriving fresher, not making one support signal the whole story."
    }

    static func preparationStage(
        _ priority: CoachDayPriorityResult,
        interpretation i: HumanCoachInterpretation
    ) -> CoachPreparationStage {
        let support = priority.supportBullets.joined(separator: " ").lowercased()
        let supportSaysMealIsIn = support.contains("meal is in") ||
            support.contains("food is covered") ||
            support.contains("fuel is covered") ||
            support.contains("give it time to settle")
        let supportSaysHydrationStarted = support.contains("hydration is improving") ||
            support.contains("hydration is on the way") ||
            support.contains("hydration has started")
        let supportSaysFuelMissing = support.contains("fuel is still missing") ||
            support.contains("30-60") ||
            support.contains("carb")
        let supportSaysHydrationMissing = support.contains("hydration is significantly behind") ||
            support.contains("add 300-500") ||
            support.contains("drink 300-500")

        let mealLogged = supportSaysMealIsIn || i.mealLoggedForPreparation
        let hydrationStarted = supportSaysHydrationStarted || i.hydrationHasStarted
        let fuelMissing = !mealLogged && (supportSaysFuelMissing || i.fuelingIsEmptyOrBehind)
        let hydrationMissing = !hydrationStarted && (supportSaysHydrationMissing || i.hydrationIsEmptyOrBehind)

        switch (hydrationMissing, fuelMissing) {
        case (true, true):
            return .missingFuelAndHydration
        case (false, true):
            return hydrationStarted ? .improvingHydration : .missingFuel
        case (true, false):
            return .missingHydration
        case (false, false):
            if hydrationStarted && mealLogged {
                return .readyToStart
            }
            if mealLogged {
                return .mealLogged
            }
            return .readyToStart
        }
    }

    static func preparationRead(_ stage: CoachPreparationStage, interpretation i: HumanCoachInterpretation) -> String {
        let timing = i.minutesUntilNextTraining.map { i.preparationTimingText($0) } ?? "later today"
        switch stage {
        case .readyToStart:
            return "The main prep is done. Food is in and hydration has started."
        case .improvingHydration:
            return "Hydration is improving. Fuel is still the missing piece before the \(i.nextTrainingName)."
        case .mealLogged:
            return "Your meal is in. Now give it time to settle and keep fluids moving."
        case .missingFuelAndHydration:
            return "\(i.nextTrainingName.capitalizedFirst) starts in \(timing), and the two things that matter now are fluid and quick fuel."
        case .missingHydration:
            if i.mealLoggedForPreparation {
                return "Your meal is in. Hydration is still missing before the \(i.nextTrainingName)."
            }
            return "\(i.nextTrainingName.capitalizedFirst) starts in \(timing). Hydration is the useful lever before the session starts."
        case .missingFuel:
            return "\(i.nextTrainingName.capitalizedFirst) starts in \(timing). Fuel is the useful lever before the session starts."
        }
    }

    static func preparationRecommendation(_ stage: CoachPreparationStage, interpretation i: HumanCoachInterpretation) -> String {
        switch stage {
        case .readyToStart:
            return "Give the meal time to settle. Bring a bottle and start easy."
        case .improvingHydration:
            return "Bring a bottle and add a small carb source before leaving."
        case .mealLogged:
            return "Sip before leaving and bring a bottle for the \(i.nextTrainingName)."
        case .missingFuelAndHydration:
            return "Drink 300-500 ml now. Add 30-60 g carbs before leaving."
        case .missingHydration:
            return "Drink 300-500 ml now. Give the meal time to settle and bring a bottle."
        case .missingFuel:
            return "Add 30-60 g carbs before leaving and start easy."
        }
    }

    static func preparationCarefulWith(_ stage: CoachPreparationStage, interpretation i: HumanCoachInterpretation) -> String {
        switch stage {
        case .readyToStart:
            return "Starting too hard before the meal settles."
        case .improvingHydration:
            return "Treating water as enough when the \(i.nextTrainingName) still needs quick fuel."
        case .mealLogged:
            return "Adding more food right before the start or forgetting fluids if training is actually next."
        case .missingFuelAndHydration:
            return "Starting the \(i.nextTrainingName) dehydrated and waiting until the session to eat."
        case .missingHydration:
            return "Starting the \(i.nextTrainingName) dry even though food is already handled."
        case .missingFuel:
            return "Waiting until the session starts to eat."
        }
    }

    static func preparationWhy(_ stage: CoachPreparationStage, interpretation i: HumanCoachInterpretation) -> String {
        switch stage {
        case .readyToStart:
            return "The useful work now is arriving settled, not adding more prep."
        case .mealLogged:
            return "Letting food settle protects the start without adding digestive stress."
        case .improvingHydration:
            return "Keeping fluids available matters more now than forcing another large drink."
        case .missingFuelAndHydration, .missingFuel, .missingHydration:
            return "A little food and fluid now makes the \(i.nextTrainingName) easier to absorb."
        }
    }

    static func recoveryDay(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        if i.sleepDataIsMissing {
            let heatPlan = i.heatPlanDescription
            let heatHydrationSupport = i.heatHydrationSupportNeedsAttention && !heatPlan.isEmpty
            let read = heatHydrationSupport
                ? "No hard training is planned today, sleep data was not captured, and \(heatPlan) later will increase fluid demands."
                : "No hard training is planned today, and sleep data was not captured."
            let recommendation: String = {
                switch i.recoveryDayCopyPhase {
                case .morning:
                    return heatHydrationSupport
                        ? "Keep the morning easy, bring fluids online before \(heatPlan), and eat normally at the next meal."
                        : "Keep the morning easy, start with water, and eat normally at the next meal."
                case .midday:
                    return heatHydrationSupport
                        ? "Keep recovery easy, bring fluids online before \(heatPlan), and eat normally at the next meal."
                        : "Keep recovery easy, bring fluids online, and eat normally at the next meal."
                case .evening:
                    return heatHydrationSupport
                        ? "Maintain normal routines, drink fluids steadily before \(heatPlan), and protect recovery for tomorrow."
                        : "Maintain normal routines, drink fluids steadily, and protect recovery for tomorrow."
                }
            }()

            return CoachSituationStory(
                kind: .recoveryDay,
                status: .prepareSession,
                title: "Recovery day",
                myRead: read,
                myRecommendation: recommendation,
                beCarefulWith: "Treating missing sleep data like strong recovery.",
                why: "Missing data is not positive data, so the useful move is a cautious, simple start.",
                planChallenge: nil,
                priority: .planOptimization,
                actions: [.hydrateBeforeSession, .lightFueling, .stayConsistent]
            )
        }

        let recoveryPlan = i.recoveryPlanDescription
        let heatPlan = i.heatPlanDescription
        let heatHydrationSupport = i.heatHydrationSupportNeedsAttention && !heatPlan.isEmpty
        let read = heatHydrationSupport
            ? "Today is built to absorb training stress, not create a new one. \(heatPlan.capitalizedFirst) later will increase fluid demands."
            : "Today is built to absorb training stress, not create a new one."
        let heatClause = heatHydrationSupport
            ? " Bring fluids online before \(heatPlan), and keep the heat block restorative."
            : (!heatPlan.isEmpty
                ? " Let \(heatPlan) stay restorative instead of turning recovery into another challenge."
                : "")
        let actions: [CoachSupportActionTypeV3] = heatHydrationSupport
            ? [.hydrateBeforeSession, .controlIntensity, .cooldown]
            : (i.hasHeatAheadToday
                ? [.controlIntensity, .cooldown, .hydrateBeforeSession]
                : [.controlIntensity, .cooldown])

        return CoachSituationStory(
            kind: .recoveryDay,
            status: .recoveryDay,
            title: "Keep recovery easy",
            myRead: read,
            myRecommendation: "Keep \(recoveryPlan) easy.\(heatClause)",
            beCarefulWith: "Adding unnecessary intensity.",
            why: "The win today is finishing the morning feeling fresher than when it started.",
            planChallenge: nil,
            priority: .planOptimization,
            actions: actions
        )
    }

    static func manageActiveSauna(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let afterHardTraining = i.hasHardTrainingCompleted
        let beforeTraining = i.hasTrainingAheadToday
        let late = i.isLateEvening
        let time = i.timeLanguage

        let status: CoachStatus = beforeTraining ? .planChanged : (afterHardTraining || late ? .keepControlled : .supportSession)
        let title = beforeTraining ? "Sauna changes the rest of today" : (late ? time.activeSaunaTitle : "Use sauna as recovery")
        let read: String
        let recommendation: String
        let careful: String
        let why: String?
        let planChallenge: String?

        if late {
            read = time.activeSaunaRead
            recommendation = time.activeSaunaRecommendation
            careful = "Long exposure, dehydration, or turning heat into another effort."
            why = time.activeSaunaWhy
            planChallenge = nil
        } else if beforeTraining {
            read = "Sauna is now part of the day before \(i.nextTrainingName), so heat stress and training are connected."
            recommendation = "Keep sauna short and make the later session easier than originally planned."
            careful = "Treating sauna and training as separate efforts when they both draw from the same recovery budget."
            why = i.hydrationSafetyNote ?? "The useful move is protecting the quality of the later session."
            planChallenge = "If the later warm-up feels flat, remove intensity instead of forcing the original plan."
        } else if afterHardTraining {
            read = "The hard work is already done, and sauna is now extra stress on top of that load."
            recommendation = "Use sauna briefly, then shift into food, fluids, and a quieter evening."
            careful = "Long heat exposure or adding more activity after the session."
            why = "Today's adaptation comes from absorbing the work you already did."
            planChallenge = nil
        } else {
            read = "Sauna is active, and there is no stronger training demand competing with it right now."
            recommendation = "Use it as an easy recovery block and stop while it still feels comfortable."
            careful = "Turning a recovery tool into something you have to recover from."
            why = "The benefit comes from leaving the body calmer than when you started."
            planChallenge = nil
        }

        return CoachSituationStory(
            kind: .manageActiveSauna,
            status: status,
            title: title,
            myRead: read,
            myRecommendation: recommendation,
            beCarefulWith: careful,
            why: why,
            planChallenge: planChallenge,
            priority: beforeTraining || afterHardTraining ? .trainingQuality : .supporting,
            actions: late ? [.cooldown, .sleepPriority] : [.rehydrateGradually, .controlIntensity]
        )
    }

    static func manageActiveTraining(
        _ i: HumanCoachInterpretation,
        priority: CoachDayPriorityResult
    ) -> CoachSituationStory {
        let phaseRecommendation = i.activeTrainingPhaseRecommendation
        let activeContext = ActiveSessionCoachingContext(priority: priority, interpretation: i)

        if i.isVeryPoorState {
            return CoachSituationStory(
                kind: .manageActiveTraining,
                status: .manageEffort,
                title: activeContext.title,
                myRead: activeContext.myRead,
                myRecommendation: activeContext.recommendation(phaseRecommendation: phaseRecommendation),
                beCarefulWith: activeContext.beCarefulWith,
                why: nil,
                planChallenge: nil,
                priority: .safety,
                actions: activeContext.actions
            )
        }

        return CoachSituationStory(
            kind: .manageActiveTraining,
            status: activeContext.status,
            title: activeSessionTitle(priority: priority, activeContext: activeContext),
            myRead: activeContext.myRead,
            myRecommendation: activeContext.recommendation(phaseRecommendation: phaseRecommendation),
            beCarefulWith: activeContext.beCarefulWith,
            why: activeContext.why,
            planChallenge: activeContext.planChallenge,
            priority: .trainingQuality,
            actions: activeContext.actions
        )
    }

    static func activeSessionTitle(
        priority: CoachDayPriorityResult,
        activeContext: ActiveSessionCoachingContext
    ) -> String {
        if activeContext.status == .manageEffort || activeContext.status == .keepItEasy {
            return activeContext.title
        }

        let resolverTitle = priority.detailTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolverTitle.isEmpty else {
            return activeContext.title
        }

        let fallbackTitle = activeContext.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolverTitle != fallbackTitle else {
            return activeContext.title
        }

        if let activityTitle = priority.activity?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           !activityTitle.isEmpty,
           !isGenericActiveSessionTitle(resolverTitle) {
            return resolverTitle
        }

        let normalizedResolverTitle = resolverTitle.lowercased()
        let normalizedActiveName = activeContext.activeName.lowercased()
        if !normalizedActiveName.isEmpty,
           normalizedResolverTitle.contains(normalizedActiveName) {
            return resolverTitle
        }

        return activeContext.title
    }

    static func isGenericActiveSessionTitle(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "keep session easy" ||
            normalized == "keep this session easy" ||
            normalized == "let the session prove itself"
    }

    static func adjustPlannedTraining(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let read = i.recoveryOverrideExplanation ??
            "Today's planned \(i.nextTrainingName) asks for more quality than your current sleep and recovery profile is likely to give."

        return CoachSituationStory(
            kind: .adjustPlannedTraining,
            status: .adjustPlan,
            title: "Keep the \(i.nextTrainingName), lower the ceiling",
            myRead: read,
            myRecommendation: "Keep the session if you want it, but make the warm-up decide how much effort belongs today.",
            beCarefulWith: "Forcing the hard part just because it is on the calendar.",
            why: "The goal is a useful session, not proving you can complete the plan unchanged.",
            planChallenge: "If the warm-up feels flat, remove intensity and keep the work easy.",
            priority: .trainingQuality,
            actions: [.controlIntensity, .mobilityPrep]
        )
    }

    static func prepareForTraining(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        return CoachSituationStory(
            kind: .prepareForTraining,
            status: .prepareSession,
            title: "Fuel the \(i.nextTrainingName)",
            myRead: "Recovery is sufficient for today's \(i.nextTrainingName). The biggest determinant of performance now is preparation, not readiness.",
            myRecommendation: "Continue hydration and complete your planned meal before the session.",
            beCarefulWith: "Starting the session under-fueled.",
            why: "The decision that matters now is arriving ready, not changing the workout early.",
            planChallenge: nil,
            priority: .supporting,
            actions: [.hydrateBeforeSession, .lightFueling]
        )
    }

    static func fuelBeforeTraining(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        CoachSituationStory(
            kind: .fuelBeforeTraining,
            status: .supportSession,
            title: "Make the next session easier to start",
            myRead: "\(i.nextTrainingName.capitalizedFirst) is still ahead, and recent food looks light for the work you are asking from the body.",
            myRecommendation: "Add simple food before training so the session starts easy instead of rushed.",
            beCarefulWith: "Waiting until the session starts and then trying to catch up.",
            why: "Fuel matters here because there is actual work ahead, not because a target is unfinished.",
            planChallenge: nil,
            priority: .trainingQuality,
            actions: [.lightFueling, .keepDigestionLight]
        )
    }

    static func hydrateAroundHeat(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let heatPlan = i.heatPlanDescription.isEmpty ? "the heat block" : i.heatPlanDescription
        let recommendation: String = {
            switch i.heatPreparationHydrationState {
            case .notStarted:
                return "Bring fluids up gradually before \(heatPlan) and keep the heat block conservative."
            case .stillLow:
                return "You have started bringing fluids online. Drink another 300-500 ml before \(heatPlan), then keep the heat block easy."
            case .improving:
                return "Hydration is moving in the right direction. Keep sipping before \(heatPlan) and keep the heat block conservative."
            case .sufficient:
                return "You have started bringing fluids online. Keep \(heatPlan) easy and avoid adding extra stress."
            }
        }()

        return CoachSituationStory(
            kind: .hydrateAroundHeat,
            status: .hydrateBeforeHeat,
            title: "Arrive ready for heat",
            myRead: "\(heatPlan.capitalizedFirst) is still ahead today, so hydration matters because it changes how stressful that heat block feels.",
            myRecommendation: recommendation,
            beCarefulWith: "Treating hydration like a number to chase at the last minute.",
            why: "Arriving steady makes heat safer and easier to recover from.",
            planChallenge: nil,
            priority: .trainingQuality,
            actions: [.hydrateBeforeSession, .electrolyteRecovery]
        )
    }

    static func recoverFromLoad(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let completed = i.completedTrainingName
        let minutesSinceEnd = i.completedTrainingMinutesSinceEnd
        let laterRecovery = minutesSinceEnd.map { $0 >= 120 } == true
        let sleepClause = i.sleepHours.map { $0 < 6.5 } == true
            ? " Short sleep makes this recovery window more important."
            : ""
        return CoachSituationStory(
            kind: .recoverFromLoad,
            status: .trainingGoalAchieved,
            title: laterRecovery ? "The work is done" : "Protect the work you just did",
            myRead: laterRecovery
                ? "A meaningful \(completed) is already banked. Recovery quality will determine what you keep from it.\(sleepClause)"
                : "A meaningful \(completed) is now complete. Recovery quality will determine what you keep from it.\(sleepClause)",
            myRecommendation: "Shift from training to absorbing the work: refuel calmly, hydrate steadily, and keep the rest of today low stress.",
            beCarefulWith: "Adding more stress because you still feel good right now.",
            why: i.tomorrowSummary ?? "Fitness improves when today's work is absorbed instead of constantly extended.",
            planChallenge: nil,
            priority: .planOptimization,
            actions: [.rehydrateGradually, .startRecoveryNutrition, .stayConsistent]
        )
    }

    static func morningSetup(
        _ i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachSituationStory {
        let hasFutureTraining = i.hasCurrentFutureTrainingToday
        let missingSleep = i.sleepDataIsMissing
        return CoachSituationStory(
            kind: .morningSetup,
            status: .prepareSession,
            title: "Bring the basics online",
            myRead: missingSleep
                ? (hasFutureTraining
                    ? "\(i.nextTrainingName.capitalizedFirst) is still later today, but sleep data is missing."
                    : "The day is open, but sleep data is missing.")
                : (hasFutureTraining
                ? "Recovery is strong, and the \(i.nextTrainingName) is still later today."
                : "The day is open and recovery is strong."),
            myRecommendation: hasFutureTraining
                ? "Start hydration early and eat normally through the morning."
                : "Use the morning to bring food and fluids online.",
            beCarefulWith: hasFutureTraining
                ? "Waiting until the training window to catch up."
                : "Waiting until later to catch up all at once.",
            why: missingSleep
                ? "Missing sleep data keeps recovery unknown, so the useful move now is a calm setup."
                : (hasFutureTraining
                ? "Strong recovery gives the plan room; the useful move now is a calm setup, not reducing training."
                : "Strong recovery gives you options; the useful move now is a calm start, not inventing urgency."),
            planChallenge: nil,
            priority: .supporting,
            actions: [.stayConsistent]
        )
    }

    static func hydrationSetup(
        _ i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachSituationStory {
        let current = i.context.nutritionContext?.waterCurrent ?? 0
        let hasFutureTraining = i.hasCurrentFutureTrainingToday
        let read: String

        if current <= 0.05 {
            read = "Hydration has not started yet, so the useful setup move is simple water before anything bigger."
        } else {
            read = "Hydration is still behind where the day needs it, even though the rest of the plan does not need changing."
        }

        return CoachSituationStory(
            kind: .morningSetup,
            status: .supportSession,
            title: "Hydration first",
            myRead: read,
            myRecommendation: hasFutureTraining
                ? "Drink 300-500 ml now, then keep fluids steady before the \(i.nextTrainingName)."
                : "Drink 300-500 ml now, then keep sipping calmly through the morning.",
            beCarefulWith: "Calling the day good to go before hydration has even started.",
            why: "Starting fluids early fixes the limiter without turning the whole day into a target chase.",
            planChallenge: nil,
            priority: .supporting,
            actions: [.hydrateBeforeSession, .stayConsistent]
        )
    }

    static func normalEvening(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        let time = i.timeLanguage
        return CoachSituationStory(
            kind: .normalEvening,
            status: .nothingNeedsFixing,
            title: time.calmNightTitle,
            myRead: "The useful work now is closing the day calmly.",
            myRecommendation: time.calmNightRecommendation,
            beCarefulWith: i.isAfterMidnightBeforeMorning ? "Adding intensity or extra structure overnight." : "Adding intensity or extra structure late.",
            why: nil,
            planChallenge: nil,
            priority: .supporting,
            actions: [.stayConsistent, .downshiftNervousSystem]
        )
    }

    static func opportunityDay(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        CoachSituationStory(
            kind: .opportunityDay,
            status: .opportunityDay,
            title: "Today can absorb training",
            myRead: "Sleep, recovery, and recent load line up well, and there is no planned session competing for energy.",
            myRecommendation: "Use today deliberately if there is a meaningful session you wanted to place this week.",
            beCarefulWith: "Spending a strong day on random activity that creates fatigue without purpose.",
            why: "High readiness is useful when it is attached to a training reason.",
            planChallenge: nil,
            priority: .planOptimization,
            actions: [.stayConsistent, .controlIntensity]
        )
    }

    static func keepRecoveryEasy(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        CoachSituationStory(
            kind: .keepRecoveryEasy,
            status: .supportSession,
            title: "Keep this easy",
            myRead: "\(i.activeRecoveryName.capitalizedFirst) is active, and its value today comes from supporting recovery rather than creating fitness.",
            myRecommendation: "Stay below effort and finish feeling better than when you started.",
            beCarefulWith: "Letting an easy recovery action become another training load.",
            why: "Recovery work only works when it stays easy enough to recover from.",
            planChallenge: nil,
            priority: .supporting,
            actions: [.controlIntensity, .cooldown]
        )
    }

    static func availableDay(_ i: HumanCoachInterpretation) -> CoachSituationStory {
        CoachSituationStory(
            kind: .availableDay,
            status: .goodToGo,
            title: "Today is available",
            myRead: "You slept well, recovered well, and there is no important load already shaping the day.",
            myRecommendation: "If you want to train, choose a purposeful session and keep it appropriate for the week.",
            beCarefulWith: "Adding intensity only because the numbers look good.",
            why: "A good day gives you options; it does not require a hard session.",
            planChallenge: nil,
            priority: .supporting,
            actions: [.stayConsistent, .controlIntensity]
        )
    }

    static func steadyDay(
        _ i: HumanCoachInterpretation,
        legacyPriority: CoachDayPriorityResult
    ) -> CoachSituationStory {
        CoachSituationStory(
            kind: .steadyDay,
            status: .goodToGo,
            title: legacyPriority.detailTitle == "Day overview" ? "Nothing needs chasing" : legacyPriority.detailTitle,
            myRead: "The day is open enough to stay simple.",
            myRecommendation: "Keep the next step flexible and maintain normal basics.",
            beCarefulWith: "Adding structure the day does not need.",
            why: "Useful coaching is often deciding that no intervention is needed yet.",
            planChallenge: nil,
            priority: .supporting,
            actions: [.stayConsistent]
        )
    }
}

private struct HumanCoachInterpretation {
    let context: CoachDecisionContext
    let signals: [CoachSignal]

    init(context: CoachDecisionContext) {
        self.context = context
        self.signals = HumanCoachSignalResolver.resolve(context)
    }

    var timePhase: CoachTimePhase {
        CoachTimePhase.resolve(hour: context.brain.currentHour)
    }

    var recoveryDayCopyPhase: CoachRecoveryDayCopyPhase {
        switch context.brain.currentHour {
        case 6..<11:
            return .morning
        case 11..<16:
            return .midday
        default:
            return .evening
        }
    }

    var recoveryPercent: Int? {
        if let value = context.recoveryContext?.recoveryPercent, value > 0 { return value }
        return nil
    }

    var sleepHours: Double? {
        if context.brain.metrics.sleepHours > 0 { return context.brain.metrics.sleepHours }
        if let value = context.recoveryContext?.sleepHours, value > 0 { return value }
        return nil
    }

    var sleepDataIsMissing: Bool {
        if context.brain.sleep == .unknown { return true }
        if context.brain.metrics.sleepHours <= 0 { return true }
        if let recovery = context.recoveryContext, recovery.sleepHours <= 0 { return true }
        return sleepHours == nil
    }

    var activeHeat: PlannedActivity? {
        guard let active = context.activityContext.activeActivity,
              CoachActivityContextResolverV3.kind(for: active) == .heat else {
            return nil
        }
        return active
    }

    var activeTraining: PlannedActivity? {
        guard let active = context.activityContext.activeActivity else { return nil }
        let kind = CoachActivityContextResolverV3.kind(for: active)
        return kind == .endurance || kind == .workout ? active : nil
    }

    var activeRecovery: PlannedActivity? {
        guard let active = context.activityContext.activeActivity,
              CoachActivityContextResolverV3.kind(for: active) == .recovery else {
            return nil
        }
        return active
    }

    var hasTrainingAheadToday: Bool {
        context.dayContext.upcomingTrainingActivities.contains { activity in
            guard let active = context.activityContext.activeActivity else { return true }
            return activity.id != active.id
        }
    }

    var hasHardTrainingAheadToday: Bool {
        context.dayContext.upcomingTrainingActivities.contains { activity in
            guard context.activityContext.activeActivity?.id != activity.id else { return false }
            return isHardTraining(activity)
        }
    }

    var hasHardTrainingCompleted: Bool {
        context.dayContext.completedTrainingActivities.contains(where: isHardTraining)
    }

    var hasLongTrainingCompleted: Bool {
        context.dayContext.completedTrainingMinutes >= 120 ||
            context.dayContext.completedTrainingActivities.contains {
                $0.effectiveDurationMinutes >= 120 || CoachActivityContextResolverV3.load(for: $0) == .high || CoachActivityContextResolverV3.load(for: $0) == .extreme
            }
    }

    var hasDaytimeCompletedTrainingToProtect: Bool {
        guard !isLateEvening else { return false }
        return context.activityContext.recentlyCompletedActivity != nil && hasLongTrainingCompleted ||
            context.dayContext.completedTrainingActivities.contains { activity in
                let load = CoachActivityContextResolverV3.load(for: activity)
                let meaningful = activity.effectiveDurationMinutes >= 120 || load == .high || load == .extreme
                guard meaningful else { return false }
                let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, activity.durationMinutes) * 60))
                let minutesSinceEnd = Int(context.dayContext.now.timeIntervalSince(end) / 60)
                return minutesSinceEnd >= 0 && minutesSinceEnd <= 360
            }
    }

    var trainingReadinessIsLimited: Bool {
        if isVeryPoorState { return true }
        if recoveryPercent.map({ $0 < 60 }) == true { return true }
        if sleepHours.map({ $0 < 6.0 }) == true { return true }
        return context.brain.readiness == .low || context.brain.recovery == .vulnerable
    }

    var shouldAdjustPlannedTraining: Bool {
        guard hasHardTrainingAheadToday, trainingReadinessIsLimited else { return false }

        if recoveryIsStrong {
            guard recoveryOverrideExplanation != nil else { return false }
            return minutesUntilNextTraining.map { $0 <= 60 } == true
        }

        if severeTrainingLimiter { return true }

        guard let minutes = minutesUntilNextTraining else { return false }
        return minutes <= 60
    }

    func shouldUseMorningSetup(_ priority: CoachDayPriorityResult) -> Bool {
        guard timePhase == .morning else { return false }
        guard priority.priority == .stable else { return false }
        guard priority.focus == .dailyOverview || priority.focus == .nextActivityLater else { return false }
        guard activeTraining == nil, activeHeat == nil, context.activityContext.preparingActivity == nil else { return false }
        if hasTrainingAheadToday {
            guard minutesUntilNextTraining.map({ $0 > 240 }) == true else { return false }
        }
        guard recoveryPercent.map({ $0 >= 90 }) == true || recoveryIsStrong else { return false }
        guard !severeTrainingLimiter else { return false }

        let noFoodOrWaterYet = (context.nutritionContext?.mealsCount ?? 0) == 0 &&
            (context.nutritionContext?.waterCurrent ?? 0) <= 0.05
        return noFoodOrWaterYet || hydrationIsEmptyOrBehind || fuelingIsEmptyOrBehind
    }

    func shouldLeadWithHydrationSetup(_ priority: CoachDayPriorityResult) -> Bool {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil else {
            return false
        }

        return priority.limiter == .hydration && priority.strength == .critical
    }

    var shouldPrepareForTrainingAhead: Bool {
        guard hasHardTrainingAheadToday else { return false }
        guard activeTraining == nil, activeHeat == nil else { return false }
        guard !isLateEvening else { return false }
        guard let minutes = minutesUntilNextTraining,
              minutes > 60,
              minutes <= 240 || context.activityContext.preparingActivity != nil else { return false }
        return !severeTrainingLimiter || recoveryIsStrong
    }

    var recoveryIsStrong: Bool {
        recoveryPercent.map { $0 >= 85 } == true &&
            context.brain.recovery != .vulnerable
    }

    var severeTrainingLimiter: Bool {
        if isVeryPoorState { return true }
        if recoveryPercent.map({ $0 < 60 }) == true { return true }
        if sleepHours.map({ $0 < 5.0 }) == true { return true }
        return context.brain.readiness == .low && context.brain.recovery == .vulnerable
    }

    var recoveryOverrideExplanation: String? {
        guard recoveryIsStrong else { return nil }
        guard let sleepHours, sleepHours < 6.5 else { return nil }
        guard nextTrainingDurationMinutes >= 180 else { return nil }

        return "Recovery metrics are positive, however sleep duration was shorter than ideal for a \(nextTrainingDurationText) \(nextTrainingName)."
    }

    var isVeryPoorState: Bool {
        if recoveryPercent.map({ $0 < 45 }) == true { return true }
        if sleepHours.map({ $0 < 5.0 }) == true { return true }
        if recoveryPercent.map({ $0 >= 75 }) == true { return false }
        return context.brain.readiness == .low && context.brain.recovery == .vulnerable
    }

    var isRealityStartedByUser: Bool {
        guard let active = context.activityContext.activeActivity else { return false }
        return active.source.lowercased() == "today"
    }

    var shouldManageActiveTrainingEffort: Bool {
        guard activeTraining != nil else { return false }
        guard !isRealityStartedByUser else { return false }
        guard !isVeryPoorState else { return false }

        let recoveryReadyEnough = recoveryPercent.map { $0 >= 75 } ?? true
        let sleepNotIdeal = sleepHours.map { $0 < 6.5 } ?? false
        let hydrationNotCovered = hydrationRatio.map { $0 < 0.85 } ?? false
        let staleReadinessCaution = recoveryReadyEnough &&
            context.brain.readiness == .low &&
            context.brain.recovery == .vulnerable

        return sleepNotIdeal || hydrationNotCovered || staleReadinessCaution
    }

    var isLateEvening: Bool {
        timePhase == .lateEvening
    }

    var isAfterMidnightBeforeMorning: Bool {
        (0..<5).contains(context.brain.currentHour)
    }

    var timeLanguage: CoachTimeLanguage {
        CoachTimeLanguage(isAfterMidnightBeforeMorning: isAfterMidnightBeforeMorning)
    }

    var shouldProtectSleepNow: Bool {
        isLateEvening &&
            context.tomorrowContext?.hasHardTraining == true &&
            context.activityContext.activeActivity == nil
    }

    var shouldProtectTomorrow: Bool {
        guard context.brain.currentHour >= 21 else { return false }
        return context.tomorrowContext?.hasHardTraining == true
    }

    var trainingFuelNeedsAttention: Bool {
        guard hasHardTrainingAheadToday else { return false }
        guard let nutrition = context.nutritionContext else { return false }
        guard nutrition.caloriesGoal > 0 || nutrition.carbsGoal > 0 else { return false }

        let calorieRatio = nutrition.caloriesGoal > 0
            ? nutrition.caloriesCurrent / nutrition.caloriesGoal
            : 1
        let carbRatio = nutrition.carbsGoal > 0
            ? nutrition.carbsCurrent / nutrition.carbsGoal
            : 1

        return context.activityContext.minutesUntilStart.map { $0 <= 240 } == true &&
            (calorieRatio < 0.45 || carbRatio < 0.35) &&
            !isLateEvening
    }

    var heatHydrationNeedsAttention: Bool {
        guard hasHeatAheadToday else { return false }
        guard hydrationRatio.map({ $0 < 0.55 }) == true else { return false }
        return !isLateEvening
    }

    var heatHydrationSupportNeedsAttention: Bool {
        guard hydrationRatio.map({ $0 < 0.55 }) == true else { return false }
        guard !isLateEvening else { return false }

        return futureCoachActivities.contains { activity in
            guard CoachActivityContextResolverV3.kind(for: activity) == .heat else { return false }
            let minutes = Int(activity.date.timeIntervalSince(context.dayContext.now) / 60)
            guard minutes >= 0 else { return false }
            return minutes <= CoachDayActivityContextResolver.preparationLeadMinutes(for: activity)
        }
    }

    var hasHeatAheadToday: Bool {
        futureCoachActivities.contains { activity in
            CoachActivityContextResolverV3.kind(for: activity) == .heat
        }
    }

    var shouldLeadWithRecoveryDay: Bool {
        guard context.dayContext.dayType == .recovery else { return false }
        guard !context.dayContext.hasTrainingToday else { return false }
        guard activeTraining == nil, activeHeat == nil else { return false }
        guard context.dayContext.upcomingActivities.contains(where: { activity in
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .recovery || kind == .heat
        }) else { return false }
        guard recoveryPercent.map({ $0 >= 70 }) != false else { return false }
        guard sleepHours.map({ $0 >= 6.0 }) != false else { return false }
        return true
    }

    var everythingImportantIsDone: Bool {
        context.brain.currentHour >= 18 &&
            context.dayContext.hasMeaningfulLoadCompleted &&
            !context.dayContext.hasMoreLoadAhead &&
            context.tomorrowContext?.hasHardTraining != true &&
            hydrationRatio.map { $0 >= 0.65 } != false &&
            context.nutritionContext?.mealsCount.map { $0 > 0 } != false
    }

    var isBalancedLateEvening: Bool {
        isLateEvening &&
            activeTraining == nil &&
            activeRecovery == nil &&
            activeHeat == nil &&
            context.dayContext.hasMoreLoadAhead == false &&
            context.tomorrowContext?.hasHardTraining != true &&
            recoveryPercent.map { $0 >= 70 } != false &&
            sleepHours.map { $0 >= 6.5 } != false &&
            hydrationRatio.map { $0 >= 0.60 } != false &&
            context.nutritionContext?.mealsCount.map { $0 > 0 } != false
    }

    var isHighReadinessOpportunity: Bool {
        !context.dayContext.hasTrainingToday &&
            !context.dayContext.hasRecoveryToday &&
            activeTraining == nil &&
            recoveryPercent.map { $0 >= 93 } == true &&
            sleepHours.map { $0 >= 8.5 } == true &&
            !context.brain.past.hasHighActivityLoad
    }

    var isGoodOpenDay: Bool {
        !context.dayContext.hasTrainingToday &&
            !context.dayContext.hasRecoveryToday &&
            activeTraining == nil &&
            recoveryPercent.map { $0 >= 85 } == true &&
            sleepHours.map { $0 >= 7.5 } == true &&
            !context.brain.past.hasHighActivityLoad
    }

    var hydrationRatio: Double? {
        guard let nutrition = context.nutritionContext, nutrition.waterGoal > 0 else { return nil }
        return nutrition.waterCurrent / nutrition.waterGoal
    }

    var hydrationIsEmptyOrBehind: Bool {
        guard let nutrition = context.nutritionContext else { return false }
        return nutrition.waterCurrent <= 0.05 || hydrationRatio.map { $0 < 0.45 } == true
    }

    var hydrationHasStarted: Bool {
        (context.nutritionContext?.waterCurrent ?? 0) >= 0.50
    }

    var heatPreparationHydrationState: HeatPreparationHydrationState {
        let current = context.nutritionContext?.waterCurrent ?? 0
        guard let ratio = hydrationRatio else {
            return current <= 0.05 ? .notStarted : .improving
        }

        if ratio >= 0.75 {
            return .sufficient
        }

        if current <= 0.05 || ratio < 0.20 {
            return .notStarted
        }

        if ratio < 0.45 {
            return .stillLow
        }

        return .improving
    }

    var fuelingIsEmptyOrBehind: Bool {
        guard let nutrition = context.nutritionContext else { return false }
        let carbsBehind = nutrition.carbsGoal > 0 && nutrition.carbsCurrent / nutrition.carbsGoal < 0.25
        let caloriesBehind = nutrition.caloriesGoal > 0 && nutrition.caloriesCurrent / nutrition.caloriesGoal < 0.35
        return !mealLoggedForPreparation && (nutrition.mealsCount ?? 0 == 0 || carbsBehind || caloriesBehind)
    }

    var eveningFuelCovered: Bool {
        guard let nutrition = context.nutritionContext else { return false }
        let caloriesCovered = nutrition.caloriesGoal > 0 && nutrition.caloriesCurrent / nutrition.caloriesGoal >= 1.0
        let carbsCovered = nutrition.carbsGoal > 0 && nutrition.carbsCurrent / nutrition.carbsGoal >= 1.0
        return caloriesCovered && carbsCovered && mealRecentlyLogged
    }

    var mealRecentlyLogged: Bool {
        guard let lastMealTime = context.nutritionContext?.lastMealTime else { return false }
        let minutes = Calendar.current.dateComponents([.minute], from: lastMealTime, to: context.dayContext.now).minute ?? Int.max
        return minutes >= 0 && minutes <= 120
    }

    var mealLoggedForPreparation: Bool {
        guard let nutrition = context.nutritionContext else { return false }
        let mealsLogged = (nutrition.mealsCount ?? 0) > 0
        let carbsCovered = nutrition.carbsGoal > 0 && nutrition.carbsCurrent / nutrition.carbsGoal >= 0.25
        let caloriesCovered = nutrition.caloriesGoal > 0 && nutrition.caloriesCurrent / nutrition.caloriesGoal >= 0.25
        return mealRecentlyLogged || (mealsLogged && (carbsCovered || caloriesCovered))
    }

    var preparationStage: CoachPreparationStage {
        if hydrationHasStarted && mealLoggedForPreparation {
            return .readyToStart
        }

        if mealLoggedForPreparation {
            return .mealLogged
        }

        if hydrationHasStarted && fuelingIsEmptyOrBehind {
            return .improvingHydration
        }

        switch (hydrationIsEmptyOrBehind, fuelingIsEmptyOrBehind) {
        case (true, true):
            return .missingFuelAndHydration
        case (false, true):
            return .missingFuel
        case (true, false):
            return .missingHydration
        case (false, false):
            return .readyToStart
        }
    }

    var preparationRead: String {
        let timing = minutesUntilNextTraining.map(preparationTimingText) ?? "later today"

        switch preparationStage {
        case .readyToStart:
            return "The main prep is done. Food is in and hydration has started."
        case .improvingHydration:
            return "Hydration is improving. Fuel is still the missing piece before the \(nextTrainingName)."
        case .mealLogged:
            return "Your meal is in. Now give it time to settle and keep fluids moving."
        case .missingFuelAndHydration:
            return "You have \(nextTrainingName) \(timing), and the two things that matter now are fluid and quick fuel."
        case .missingHydration:
            return "You have \(nextTrainingName) \(timing). Hydration is the useful lever before the session starts."
        case .missingFuel:
            return "You have \(nextTrainingName) \(timing). Fuel is the useful lever before the session starts."
        }
    }

    var preparationRecommendation: String {
        switch preparationStage {
        case .readyToStart:
            return "Give the meal time to settle, bring a bottle, and start easy."
        case .improvingHydration:
            return "Bring a bottle and add a small carb source before leaving."
        case .mealLogged:
            return "Sip before leaving and bring a bottle for the \(nextTrainingName)."
        case .missingFuelAndHydration:
            return "Drink 300-500 ml now. Add 30-60 g carbs before leaving."
        case .missingHydration:
            return "Drink 300-500 ml now and bring a bottle for the \(nextTrainingName)."
        case .missingFuel:
            return "Add 30-60 g carbs before leaving and start easy."
        }
    }

    var preparationCarefulWith: String {
        switch preparationStage {
        case .readyToStart:
            return "Starting too hard before the meal settles."
        case .improvingHydration:
            return "Treating water as enough when the \(nextTrainingName) still needs quick fuel."
        case .mealLogged:
            return "Adding more food right before the start or forgetting fluids if training is actually next."
        case .missingFuelAndHydration:
            return "Starting the \(nextTrainingName) dehydrated and waiting until the session to eat."
        case .missingHydration:
            return "Starting the \(nextTrainingName) dry and trying to catch up during the session."
        case .missingFuel:
            return "Waiting until the session starts to eat."
        }
    }

    var preparationWhy: String {
        switch preparationStage {
        case .readyToStart:
            return "The useful work now is arriving settled, not adding more prep."
        case .mealLogged:
            return "Letting food settle protects the start without adding digestive stress."
        case .improvingHydration:
            return "Keeping fluids available matters more now than forcing another large drink."
        case .missingFuelAndHydration, .missingFuel, .missingHydration:
            return "A little food and fluid now makes the \(nextTrainingName) easier to absorb."
        }
    }

    var nextTrainingName: String {
        activityShortName(context.dayContext.upcomingTrainingActivities.first)
    }

    var hasCurrentFutureTrainingToday: Bool {
        context.dayContext.upcomingTrainingActivities.contains { activity in
            activity.date > context.dayContext.now &&
                !activity.isCompleted &&
                !activity.isSkipped
        }
    }

    var nextTrainingDurationMinutes: Int {
        context.dayContext.upcomingTrainingActivities.first?.effectiveDurationMinutes ?? 0
    }

    var nextTrainingDurationText: String {
        let minutes = nextTrainingDurationMinutes
        guard minutes >= 60 else { return "\(minutes)-minute" }
        let hours = Double(minutes) / 60.0
        if minutes % 60 == 0 {
            return "\(Int(hours))-hour"
        }
        return "\(String(format: "%.1f", hours))-hour"
    }

    var minutesUntilNextTraining: Int? {
        context.activityContext.minutesUntilStart
    }

    func preparationTimingText(_ minutes: Int) -> String {
        switch minutes {
        case ..<45:
            return "about \(max(minutes, 1)) minutes"
        case 45..<90:
            return "about an hour"
        case 90..<150:
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 {
                return "about \(hours)h"
            }
            return "about \(hours)h \(remainder)m"
        default:
            return "later today"
        }
    }

    var activeTrainingName: String {
        activeActivityIdentityIsCertain ? activityShortName(activeTraining) : "this session"
    }

    var activeRecoveryName: String {
        activeActivityIdentityIsCertain ? activityShortName(activeRecovery) : "this recovery block"
    }

    var completedTrainingName: String {
        activityShortName(context.activityContext.recentlyCompletedActivity ?? context.dayContext.completedTrainingActivities.last)
    }

    var completedTrainingMinutesSinceEnd: Int? {
        let activity = context.activityContext.recentlyCompletedActivity ?? context.dayContext.completedTrainingActivities.last
        guard let activity else { return nil }
        let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, activity.durationMinutes) * 60))
        let minutes = Int(context.dayContext.now.timeIntervalSince(end) / 60)
        return minutes >= 0 ? minutes : nil
    }

    var tomorrowTrainingName: String {
        activityShortName(context.tomorrowContext?.primaryTrainingActivity)
    }

    var tomorrowTrainingDescription: String {
        guard let activity = context.tomorrowContext?.primaryTrainingActivity else {
            return "\(tomorrowTrainingName) session"
        }

        let name = activityShortName(activity)
        if activity.effectiveDurationMinutes >= 120 {
            return "long \(name) session"
        }
        if activity.effectiveDurationMinutes >= 75 {
            return "hard \(name) session"
        }
        return "\(name) session"
    }

    var recoveryPlanDescription: String {
        let recoveryActivities = futureCoachActivities
            .filter { activity in
                let kind = CoachActivityContextResolverV3.kind(for: activity)
                return kind == .recovery || kind == .heat
            }
            .map(activityShortName)
            .uniquedPreservingOrder()

        guard !recoveryActivities.isEmpty else { return "the recovery work" }
        return list(recoveryActivities)
    }

    var heatPlanDescription: String {
        let heatActivities = futureCoachActivities
            .filter { CoachActivityContextResolverV3.kind(for: $0) == .heat }
            .map(activityShortName)
            .uniquedPreservingOrder()

        return list(heatActivities)
    }

    var futureCoachActivities: [PlannedActivity] {
        let candidates = context.dayContext.upcomingActivities +
            [
                context.activityContext.preparingActivity,
                context.activityContext.nextUpcomingActivity,
                context.activityContext.laterTodayActivity
            ].compactMap { $0 }
        var seenIDs = Set<String>()

        return candidates.compactMap { activity in
            guard activity.date >= context.dayContext.now,
                  !activity.isCompleted,
                  !activity.isSkipped,
                  !seenIDs.contains(activity.id) else {
                return nil
            }
            seenIDs.insert(activity.id)
            return activity
        }
    }

    var activeActivityIdentityIsCertain: Bool {
        context.activityContext.activeActivityIdentityIsCertain
    }

    var activeTrainingPhaseContext: String {
        switch context.activityContext.activeSessionPhase {
        case .started, .none:
            return "\(activeTrainingName.capitalizedFirst) is live, and the opening minutes are for settling in."
        case .middle:
            return "\(activeTrainingName.capitalizedFirst) is in its main block now."
        case .finishing:
            return "\(activeTrainingName.capitalizedFirst) is near the finish."
        case .postSession:
            return "\(activeTrainingName.capitalizedFirst) is done."
        }
    }

    var activeTrainingPhaseRecommendation: String {
        switch context.activityContext.activeSessionPhase {
        case .started, .none:
            return "Keep the first minutes easy and let breathing, pacing, and body feedback set the ceiling."
        case .middle:
            return "Stay with the effort you can repeat rather than chasing numbers."
        case .finishing:
            return "Leave enough in reserve that recovery starts immediately."
        case .postSession:
            return "The training signal is done. Recovery is now the priority."
        }
    }

    var recoverySummary: String? {
        var parts: [String] = []
        if let sleepHours {
            parts.append(sleepHours >= 7.5 ? "sleep is supportive" : "sleep is limiting")
        }
        if let recoveryPercent {
            parts.append(recoveryPercent >= 80 ? "recovery is supportive" : "recovery is limiting")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ").capitalizedFirst + "."
    }

    var hydrationSafetyNote: String? {
        guard let hydrationRatio else { return nil }
        if hydrationRatio < 0.4 {
            return "Hydration is a safety signal because heat is involved."
        }
        if hydrationRatio < 0.7 {
            return "Hydration is useful support because heat adds stress."
        }
        return nil
    }

    var tomorrowSummary: String? {
        context.tomorrowContext?.hasHardTraining == true ? "Tomorrow still needs freshness." : nil
    }

    func isHardTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        guard kind == .endurance || kind == .workout else { return false }
        let load = CoachActivityContextResolverV3.load(for: activity)
        return load == .high || load == .extreme || activity.effectiveDurationMinutes >= 75 || activity.title.localizedCaseInsensitiveContains("interval")
    }

    func activityShortName(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "training" }
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if title.contains("sauna") { return "sauna" }
        if title.contains("walk") { return "walk" }
        if title.contains("yoga") { return "yoga" }
        if title.contains("ride") || title.contains("cycling") || title.contains("bike") { return "ride" }
        if title.contains("run") { return "run" }
        if title.contains("tennis") { return "tennis" }
        if title.contains("squash") { return "squash" }
        if title.contains("strength") { return "strength session" }
        if title.contains("gym") { return "gym session" }

        switch CoachActivityContextResolverV3.kind(for: activity) {
        case .endurance:
            return "session"
        case .workout:
            return "session"
        case .heat:
            return "sauna"
        case .recovery:
            return "recovery work"
        case .meal, .other:
            return "training"
        }
    }

    func list(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in self {
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}

private enum HumanCoachSignalResolver {

    static func resolve(_ context: CoachDecisionContext) -> [CoachSignal] {
        var signals: [CoachSignal] = []

        if let sleep = context.recoveryContext?.sleepHours, sleep > 0 {
            signals.append(CoachSignal(
                layer: .past,
                kind: .sleep,
                title: "Sleep",
                interpretation: sleep < 6 ? "Sleep is limiting readiness." : "Sleep supports readiness.",
                priority: sleep < 5 ? .safety : (sleep < 6 ? .trainingQuality : .supporting)
            ))
        }

        if let recovery = context.recoveryContext?.recoveryPercent, recovery > 0 {
            signals.append(CoachSignal(
                layer: .present,
                kind: .recovery,
                title: "Recovery",
                interpretation: recovery < 60 ? "Recovery asks for a lower ceiling." : "Recovery can support the current plan.",
                priority: recovery < 45 ? .safety : (recovery < 60 ? .trainingQuality : .supporting)
            ))
        }

        if context.brain.past.hasHighActivityLoad {
            signals.append(CoachSignal(
                layer: .past,
                kind: .yesterdayLoad,
                title: "Recent load",
                interpretation: "Recent load increases the cost of adding more intensity.",
                priority: .trainingQuality
            ))
        }

        if let active = context.activityContext.activeActivity {
            signals.append(CoachSignal(
                layer: .present,
                kind: active.source.lowercased() == "today" ? .activeQuickAction : .activeActivity,
                title: "Current activity",
                interpretation: "\(active.title) is a reality change, not the recommendation itself.",
                priority: .planOptimization
            ))
        }

        if context.dayContext.hasMeaningfulLoadCompleted {
            signals.append(CoachSignal(
                layer: .past,
                kind: .completedTraining,
                title: "Completed training",
                interpretation: "Completed work changes what is useful from here.",
                priority: .planOptimization
            ))
        }

        if context.dayContext.hasMoreLoadAhead {
            signals.append(CoachSignal(
                layer: .future,
                kind: .plannedTraining,
                title: "Remaining training",
                interpretation: "Training ahead needs the current state to be respected.",
                priority: .trainingQuality
            ))
        }

        if context.tomorrowContext?.hasHardTraining == true {
            signals.append(CoachSignal(
                layer: .future,
                kind: .tomorrowTraining,
                title: "Tomorrow",
                interpretation: "Tomorrow's load makes recovery tonight more valuable.",
                priority: .planOptimization
            ))
        }

        if let nutrition = context.nutritionContext {
            if nutrition.waterGoal > 0 {
                let ratio = nutrition.waterCurrent / nutrition.waterGoal
                signals.append(CoachSignal(
                    layer: .present,
                    kind: .hydration,
                    title: "Hydration",
                    interpretation: ratio < 0.5 ? "Hydration may affect safety or training quality." : "Hydration is a supporting signal.",
                    priority: ratio < 0.35 ? .trainingQuality : .supporting
                ))
            }

            if nutrition.mealsCount != nil || nutrition.caloriesGoal > 0 {
                signals.append(CoachSignal(
                    layer: .past,
                    kind: .nutrition,
                    title: "Nutrition",
                    interpretation: "Food is support for the recommendation, not the headline.",
                    priority: .supporting
                ))
            }
        }

        signals.append(CoachSignal(
            layer: .present,
            kind: .time,
            title: "Time of day",
            interpretation: context.brain.currentHour >= 21 ? "Evening shifts the decision toward tomorrow." : "There is still room to adjust the day.",
            priority: context.brain.currentHour >= 21 ? .planOptimization : .supporting
        ))

        return signals
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

private extension CoachGuidanceImportanceV3 {
    var dayPriorityLevel: CoachDayPriorityLevel {
        switch self {
        case .quiet:
            return .quiet
        case .useful:
            return .useful
        case .important:
            return .important
        case .high:
            return .high
        }
    }
}

private extension CoachDayContext {
    func hasTrainingTodayExcludingActive(_ active: PlannedActivity?) -> Bool {
        guard let active else {
            return hasTrainingToday
        }

        return (completedTrainingActivities + upcomingTrainingActivities)
            .contains { $0.id != active.id }
    }
}
