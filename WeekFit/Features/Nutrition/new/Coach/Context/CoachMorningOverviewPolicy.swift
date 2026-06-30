import Foundation
import WeekFitPlanner

/// Morning Overview — first conversational phase after waking.
/// Body state, sleep, recovery, and the nearest event only; nutrition/hydration come later.
enum CoachMorningOverviewPolicy {

    // MARK: - Window

    static func isMorningWindow(now: Date, timeOfDay: CoachTimeOfDay) -> Bool {
        if timeOfDay == .morning {
            return true
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return hour == 9 && minute <= 30
    }

    // MARK: - Phase eligibility

    static func isActive(
        input: CoachInputSnapshot,
        context: CoachContext,
        isFirstOpenToday: Bool
    ) -> Bool {
        guard isFirstOpenToday else { return false }
        guard isMorningWindow(now: input.now, timeOfDay: context.timeOfDay) else {
            return false
        }
        guard !hasEnded(input: input, context: context) else {
            return false
        }
        return true
    }

    /// Nutrition/hydration must not surface as owners, next actions, or Why rows.
    static func shouldSuppressNutrition(context: CoachContext) -> Bool {
        guard context.conversationPhase == .morningOverview else { return false }

        switch context.sessionPhase {
        case .during, .immediatePost:
            return false
        default:
            break
        }

        if context.focusSource == .active || context.activityState == .active {
            return false
        }

        return true
    }

    // MARK: - Exit conditions

    static func hasEnded(input: CoachInputSnapshot, context: CoachContext) -> Bool {
        if hasCompletedActivityToday(input: input) {
            return true
        }
        if hasLoggedDrink(input: input) {
            return true
        }
        if hasLoggedMeal(input: input) {
            return true
        }
        return false
    }

    static func hasCompletedActivityToday(input: CoachInputSnapshot) -> Bool {
        let calendar = Calendar.current
        return input.plannedActivities.contains {
            calendar.isDate($0.date, inSameDayAs: input.now) &&
                ($0.isCompleted || $0.isPartialCompletion) &&
                !$0.isSkipped
        }
    }

    static func hasLoggedDrink(input: CoachInputSnapshot) -> Bool {
        guard let nutrition = input.nutritionContext else { return false }
        return nutrition.waterCurrent > 0
    }

    static func hasLoggedMeal(input: CoachInputSnapshot) -> Bool {
        guard let nutrition = input.nutritionContext else { return false }
        if nutrition.caloriesCurrent > 0 { return true }
        if let mealsCount = nutrition.mealsCount, mealsCount > 0 { return true }
        return false
    }

    // MARK: - Why copy (upcoming activity focus)

    static func upcomingActivityWhySignal(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard input.conversationPhase == .morningOverview else { return nil }
        guard input.focusSource == .upcoming, input.activityType != .none else { return nil }
        guard input.dayReadiness.recoveryDataAvailable else {
            if input.dayReadiness.hadHeavyYesterday {
                return .en(
                    "Yesterday still counts — today's plan stays measured.",
                    "Вчера ещё в теле — сегодня по плану, без спешки."
                )
            }
            return nil
        }

        if input.dayReadiness.sleepIsLow {
            return .en(
                "Sleep was short — ease into what's next.",
                "Сон был коротким — начинайте день мягко."
            )
        }

        if input.dayReadiness.isLowRecovery {
            return .en(
                "Recovery is lagging — keep the next block lighter.",
                "Восстановление отстаёт — следующий блок легче."
            )
        }

        if input.dayReadiness.hadHeavyYesterday {
            return .en(
                "Yesterday still counts — today's plan stays measured.",
                "Вчера ещё в теле — сегодня по плану, без спешки."
            )
        }

        switch input.activityType {
        case .walk:
            return .en(
                "A walk is next — let the morning settle first.",
                "Впереди прогулка — дайте утру спокойно начаться."
            )
        case .cycling, .running:
            return .en(
                "Training is on the plan — start from how you feel now.",
                "Тренировка в календаре — начните с того, как вы себя чувствуете."
            )
        case .tennis, .squash:
            return .en(
                "Match day is coming — protect energy until it's time.",
                "Игра впереди — берегите силы до старта."
            )
        default:
            return .en(
                "The day starts here — follow the plan at your pace.",
                "День начинается — двигайтесь по плану в своём темпе."
            )
        }
    }
}
