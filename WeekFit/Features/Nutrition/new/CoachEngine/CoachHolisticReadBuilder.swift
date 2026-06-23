import Foundation

/// Builds My Read (assessment) from day context — recovery, sleep, completed load, upcoming plan.
enum CoachHolisticReadBuilder {

    struct Context {
        let owner: CoachFinalStoryOwner
        let isPreSession: Bool
        let isDuringSession: Bool
        let isPostSession: Bool
        let recoveryPercent: Int
        let caloriesBurned: Double
        let completedSeriousTrainingToday: Bool
        let sleepLimited: Bool
        let recoveryLimited: Bool
        let hydrationLimited: Bool
        let fuelLimited: Bool
        let nextActivityTitle: String?
        let hoursUntilNextActivity: Double?
        let hasUpcomingSessionToday: Bool
        let shouldProtectTomorrow: Bool
        let shouldProtectUpcomingSession: Bool
        let tomorrowRecoveryPlanSummary: CoachTomorrowPlanReadBuilder.RecoveryPlanSummary?
        let timePhase: CoachFinalDecisionTimeOfDay
        let heroNamesUpcomingPlan: Bool
        let isCalmOverviewDay: Bool
        let isPostHeatRecovery: Bool
        let todayPlanSummary: CoachDayPlanReadBuilder.DayPlanSummary?
    }

    struct Copy {
        let english: String
        let russian: String

        init(_ english: String, _ russian: String) {
            self.english = english
            self.russian = russian
        }

        init(english: String, russian: String) {
            self.english = english
            self.russian = russian
        }
    }

    static func compose(context: Context, tactical: Copy?) -> Copy {
        let clauses = rankedClauses(for: context)
        let selected = Array(clauses.prefix(maxClauses(for: context)))
        guard let tactical, !tactical.english.isEmpty else {
            return join(selected) ?? defaultCopy(for: context)
        }
        if selected.isEmpty {
            return tactical
        }
        if shouldAppendTactical(tactical, context: context, selected: selected) == false {
            return join(selected) ?? tactical
        }
        if let joined = join(selected) {
            return Copy(
                english: "\(joined.english) \(tactical.english)",
                russian: "\(joined.russian) \(tactical.russian)"
            )
        }
        return tactical
    }

    // MARK: - Clause ranking

    private static func rankedClauses(for context: Context) -> [Copy] {
        var clauses: [Copy] = []
        switch context.owner {
        case .postActivityRecovery, .recovery:
            if context.tomorrowRecoveryPlanSummary != nil, !context.shouldProtectTomorrow {
                appendIfPresent(&clauses, forwardClause(context))
                appendIfPresent(&clauses, dayLoadClause(context))
            } else {
                appendIfPresent(&clauses, todayPlanClause(context))
                appendIfPresent(&clauses, dayLoadClause(context))
                if context.tomorrowRecoveryPlanSummary != nil {
                    appendIfPresent(&clauses, forwardClause(context))
                }
            }
            appendIfPresent(&clauses, stateClause(context))
            appendIfPresent(&clauses, timePhaseClause(context))
            if context.tomorrowRecoveryPlanSummary == nil {
                appendIfPresent(&clauses, forwardClause(context))
            }
        case .activityPreparation:
            appendIfPresent(&clauses, stateClause(context))
            appendIfPresent(&clauses, timePhaseClause(context))
            appendIfPresent(&clauses, dayLoadClause(context))
            appendIfPresent(&clauses, forwardClause(context))
        case .tomorrowProtection:
            appendIfPresent(&clauses, timePhaseClause(context))
            appendIfPresent(&clauses, forwardClause(context))
            appendIfPresent(&clauses, dayLoadClause(context))
            appendIfPresent(&clauses, stateClause(context))
        case .pacingExecution, .sustainableExecution, .fuelingDuringActivity, .hydrationExecution, .activeActivity:
            appendIfPresent(&clauses, stateClause(context))
            appendIfPresent(&clauses, timePhaseClause(context))
            appendIfPresent(&clauses, dayLoadClause(context))
            appendIfPresent(&clauses, forwardClause(context))
        default:
            if context.isCalmOverviewDay {
                appendIfPresent(&clauses, stateClause(context))
            } else {
                appendIfPresent(&clauses, timePhaseClause(context))
                appendIfPresent(&clauses, stateClause(context))
                appendIfPresent(&clauses, dayLoadClause(context))
                if !context.heroNamesUpcomingPlan {
                    appendIfPresent(&clauses, forwardClause(context))
                }
            }
        }
        return clauses
    }

    private static func maxClauses(for context: Context) -> Int {
        if context.isCalmOverviewDay {
            return 1
        }
        if context.isPostSession || context.isPostHeatRecovery {
            return 2
        }
        if context.owner == .activityPreparation && context.isPreSession {
            return 0
        }
        switch context.owner {
        case .pacingExecution, .sustainableExecution, .fuelingDuringActivity, .hydrationExecution:
            return 1
        case .postActivityRecovery, .recovery:
            return 2
        default:
            return 2
        }
    }

    private static func stateClause(_ context: Context) -> Copy? {
        if context.isCalmOverviewDay,
           context.owner == .stableOverview || context.owner == .readiness,
           !context.hasUpcomingSessionToday,
           !context.completedSeriousTrainingToday {
            if context.sleepLimited {
                if context.recoveryPercent >= 60 && context.recoveryPercent < 75 {
                    return calmOverviewRecoveryInterpretation(context)
                }
                return Copy(
                    "Last night was shorter than ideal.",
                    "Прошлой ночью вы недоспали."
                )
            }
            if isLateEveningPhase(context.timePhase), context.recoveryPercent >= 75 {
                return Copy(
                    "Recovery looked good today — leave something for tomorrow.",
                    "Сегодня восстановление выглядело нормально — завтра понадобятся силы."
                )
            }
            return calmOverviewRecoveryInterpretation(context)
        }

        if context.sleepLimited {
            return Copy(
                "You didn't sleep enough last night.",
                "Прошлой ночью вы недоспали."
            )
        }
        if context.hydrationLimited && (context.isPreSession || context.isDuringSession) {
            return Copy(
                "You're a bit low on water for today.",
                "Сегодня не хватает воды."
            )
        }
        if context.hydrationLimited && context.isCalmOverviewDay {
            return Copy(
                "You haven't logged water yet today.",
                "Сегодня вода пока не отмечена."
            )
        }
        if context.fuelLimited && (context.isPreSession || context.isDuringSession) {
            return Copy(
                "Eat something light before the session.",
                "Перед тренировкой лучше поесть."
            )
        }
        if context.fuelLimited && context.isCalmOverviewDay {
            if context.timePhase == .morning {
                return Copy(
                    "Nothing is logged for food yet this morning.",
                    "Утром пока ничего не отмечено из еды."
                )
            }
            return Copy(
                "Food is a little behind today.",
                "С едой сегодня немного отстаёте."
            )
        }
        if context.recoveryLimited || context.recoveryPercent < 70 {
            if shouldSkipSoftRecoveryClause(context) {
                return nil
            }
            if context.isPostHeatRecovery && context.recoveryPercent >= 75 {
                return Copy(
                    "Sauna took something out of you — drink water and take it easy next.",
                    "Сауна что-то забрала — пейте воду и не торопитесь дальше."
                )
            }
            if context.recoveryPercent >= 80 && !context.isDuringSession && !context.isPreSession {
                return nil
            }
            return Copy(
                "Recovery is at \(context.recoveryPercent)% today.",
                "Самочувствие сегодня — \(context.recoveryPercent)%."
            )
        }
        if context.recoveryPercent < 80 && (context.completedSeriousTrainingToday || context.isDuringSession) {
            return Copy(
                "Recovery is only at \(context.recoveryPercent)% so far.",
                "Силы пока на \(context.recoveryPercent)%."
            )
        }
        return nil
    }

    private static func calmOverviewRecoveryInterpretation(_ context: Context) -> Copy? {
        let recovery = context.recoveryPercent
        guard recovery > 0 else { return nil }

        let morningLead = context.timePhase == .morning
        switch recovery {
        case 75...:
            return morningLead
                ? Copy("Recovery looks solid this morning.", "С утра восстановление выглядит хорошим.")
                : Copy("Recovery looks solid today.", "Сегодня восстановление выглядит хорошим.")
        case 60..<75:
            return morningLead
                ? Copy("Recovery looks reasonable this morning.", "С утра самочувствие выглядит нормальным.")
                : Copy("Recovery looks reasonable today.", "Сегодня самочувствие выглядит нормальным.")
        case 45..<60:
            return Copy(
                "Recovery isn't fully restored yet, but nothing is seriously limiting the day.",
                "Восстановление ещё не полное, но день серьёзно не ограничен."
            )
        default:
            return Copy(
                "Recovery is still catching up today.",
                "Сегодня организм ещё восстанавливается."
            )
        }
    }

    private static func dayLoadClause(_ context: Context) -> Copy? {
        if let summary = context.todayPlanSummary,
           !context.completedSeriousTrainingToday,
           let completed = CoachDayPlanReadBuilder.completedDayClause(summary),
           summary.hasMultipleCompleted || summary.completedMinutes >= 75 {
            return Copy(completed.english, completed.russian)
        }
        if context.completedSeriousTrainingToday {
            if context.caloriesBurned >= 700 {
                return Copy(
                    "Today already put serious training into your legs.",
                    "Ноги уже получили достаточно работы сегодня."
                )
            }
            return Copy(
                "You already did the main workout today.",
                "Главная тренировка на сегодня уже сделана."
            )
        }
        if context.caloriesBurned >= 900 {
            return Copy(
                "Today already had more load than usual.",
                "Сегодня нагрузка уже выше обычной."
            )
        }
        if context.isDuringSession && context.caloriesBurned >= 400 {
            return Copy(
                "Energy spend is already adding up today.",
                "Расход энергии за день уже накапливается."
            )
        }
        return nil
    }

    private static func timePhaseClause(_ context: Context) -> Copy? {
        if context.tomorrowRecoveryPlanSummary != nil,
           context.isPostSession,
           isEveningPhase(context.timePhase) {
            return nil
        }
        return CoachTimeOfDayFraming.myReadTimeClause(
            timePhase: context.timePhase,
            owner: context.owner,
            completedSeriousTrainingToday: context.completedSeriousTrainingToday,
            hasUpcomingSessionToday: context.hasUpcomingSessionToday,
            isPostSession: context.isPostSession
        ).map { Copy($0.english, $0.russian) }
    }

    private static func todayPlanClause(_ context: Context) -> Copy? {
        guard let summary = context.todayPlanSummary else { return nil }
        if context.isPostSession || context.isPostHeatRecovery,
           let balance = CoachDayPlanReadBuilder.postSessionBalanceClause(
               summary: summary,
               isPostHeat: context.isPostHeatRecovery
           ) {
            return Copy(balance.english, balance.russian)
        }
        if let remaining = CoachDayPlanReadBuilder.remainingDayClause(summary) {
            return Copy(remaining.english, remaining.russian)
        }
        return nil
    }

    private static func forwardClause(_ context: Context) -> Copy? {
        if let summary = context.tomorrowRecoveryPlanSummary, !context.shouldProtectTomorrow {
            let clause = CoachTomorrowPlanReadBuilder.forwardClause(summary: summary)
            return Copy(clause.english, clause.russian)
        }
        if context.shouldProtectTomorrow {
            return Copy(
                "Tomorrow has a hard session waiting.",
                "Завтра ждёт серьёзная тренировка."
            )
        }
        if let summary = context.todayPlanSummary,
           let remaining = CoachDayPlanReadBuilder.remainingDayClause(summary),
           context.isPostSession || context.isPostHeatRecovery || context.shouldProtectUpcomingSession {
            return Copy(remaining.english, remaining.russian)
        }
        guard let title = context.nextActivityTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }
        if context.isPostSession && !context.shouldProtectUpcomingSession && !context.isPreSession {
            if context.todayPlanSummary?.hasRemainingToday != true {
                return nil
            }
        }
        if let hours = context.hoursUntilNextActivity {
            if hours < 0.25 {
                return Copy(
                    "\(title) starts very soon — keep the rest of today simple.",
                    "\(title) скоро начнётся — остаток дня держите простым."
                )
            }
            if hours < 1 {
                return Copy(
                    "\(title) is less than an hour away — don't burn yourself out before it.",
                    "\(title) меньше чем через час — не выгорите до неё."
                )
            }
            if hours < 4 {
                let rounded = max(1, Int(hours.rounded()))
                return Copy(
                    "\(title) is in about \(rounded) hour\(rounded == 1 ? "" : "s") — save your energy for it.",
                    "\(title) примерно через \(rounded) \(russianHourWord(rounded)) — берегите силы."
                )
            }
            if context.isPreSession {
                return Copy(
                    "\(title) is the main thing left today.",
                    "\(title) — главное, что ещё осталось сегодня."
                )
            }
        } else if context.isPreSession {
            return Copy(
                "\(title) is the main thing left today.",
                "\(title) — главное, что ещё осталось сегодня."
            )
        }
        return nil
    }

    private static func defaultCopy(for context: Context) -> Copy {
        if context.owner == .stableOverview || context.owner == .readiness {
            let stable = CoachTimeOfDayFraming.stableDayRead(timePhase: context.timePhase)
            return Copy(stable.english, stable.russian)
        }
        return Copy(
            "Look at the whole day, not just the last thing you did.",
            "Смотрите на весь день, а не только на последнюю активность."
        )
    }

    // MARK: - Helpers

    private static func appendIfPresent(_ clauses: inout [Copy], _ clause: Copy?) {
        guard let clause else { return }
        guard !clauses.contains(where: { overlaps($0, clause) }) else { return }
        clauses.append(clause)
    }

    private static func join(_ copies: [Copy]) -> Copy? {
        guard !copies.isEmpty else { return nil }
        return Copy(
            english: copies.map(\.english).joined(separator: " "),
            russian: copies.map(\.russian).joined(separator: " ")
        )
    }

    private static func tacticalIsRedundant(_ tactical: Copy, given clauses: [Copy]) -> Bool {
        clauses.contains { overlaps($0, tactical) }
    }

    private static func shouldAppendTactical(
        _ tactical: Copy,
        context: Context,
        selected: [Copy]
    ) -> Bool {
        if tacticalIsRedundant(tactical, given: selected) {
            return false
        }
        if context.tomorrowRecoveryPlanSummary != nil,
           context.isPostSession,
           selected.contains(where: containsTomorrowRecoveryForwardClause) {
            return !tacticalRepeatsEveningRecoveryAdvice(tactical)
        }
        return true
    }

    private static func shouldSkipSoftRecoveryClause(_ context: Context) -> Bool {
        context.isPostSession &&
            context.tomorrowRecoveryPlanSummary != nil &&
            !context.shouldProtectTomorrow &&
            context.recoveryPercent >= 75
    }

    private static func containsTomorrowRecoveryForwardClause(_ clause: Copy) -> Bool {
        let english = normalized(clause.english)
        let russian = normalized(clause.russian)
        return english.contains("tomorrow has") || russian.contains("завтра в плане")
    }

    private static func tacticalRepeatsEveningRecoveryAdvice(_ tactical: Copy) -> Bool {
        let english = normalized(tactical.english)
        let russian = normalized(tactical.russian)
        return eveningRecoveryThemeScore(english) >= 2 || eveningRecoveryThemeScore(russian) >= 2
    }

    private static func eveningRecoveryThemeScore(_ text: String) -> Int {
        let themes = [
            "sleep", "calm", "evening", "protect", "сон", "спокой", "вечер", "берег"
        ]
        return themes.filter { text.contains($0) }.count
    }

    private static func isEveningPhase(_ phase: CoachFinalDecisionTimeOfDay) -> Bool {
        switch phase {
        case .evening, .lateEvening, .night:
            return true
        default:
            return false
        }
    }

    private static func isLateEveningPhase(_ phase: CoachFinalDecisionTimeOfDay) -> Bool {
        phase == .lateEvening || phase == .night
    }

    private static func overlaps(_ lhs: Copy, _ rhs: Copy) -> Bool {
        let a = normalized(lhs.english)
        let b = normalized(rhs.english)
        if a.isEmpty || b.isEmpty { return false }
        return a.contains(b) || b.contains(a) || wordOverlapRatio(a, b) >= 0.55
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\w\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func wordOverlapRatio(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(lhs.split(separator: " ").map(String.init).filter { $0.count > 3 })
        let right = Set(rhs.split(separator: " ").map(String.init).filter { $0.count > 3 })
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(min(left.count, right.count))
    }

    private static func russianHourWord(_ hours: Int) -> String {
        let mod10 = hours % 10
        let mod100 = hours % 100
        if mod10 == 1 && mod100 != 11 { return "час" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "часа" }
        return "часов"
    }
}
