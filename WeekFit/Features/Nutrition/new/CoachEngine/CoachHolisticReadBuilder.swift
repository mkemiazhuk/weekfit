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
            appendIfPresent(&clauses, dayLoadClause(context))
            if context.tomorrowRecoveryPlanSummary != nil {
                appendIfPresent(&clauses, forwardClause(context))
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
            appendIfPresent(&clauses, timePhaseClause(context))
            appendIfPresent(&clauses, stateClause(context))
            appendIfPresent(&clauses, dayLoadClause(context))
            appendIfPresent(&clauses, forwardClause(context))
        }
        return clauses
    }

    private static func maxClauses(for context: Context) -> Int {
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
        if context.sleepLimited {
            return Copy(
                "Sleep is limiting readiness today.",
                "Сон сегодня ограничивает готовность."
            )
        }
        if context.hydrationLimited && (context.isPreSession || context.isDuringSession) {
            return Copy(
                "Hydration is behind what today requires.",
                "Гидратация отстаёт от того, что требует день."
            )
        }
        if context.fuelLimited && (context.isPreSession || context.isDuringSession) {
            return Copy(
                "Fuel is behind what today requires.",
                "Питание отстаёт от того, что требует день."
            )
        }
        if context.recoveryLimited || context.recoveryPercent < 70 {
            if shouldSkipSoftRecoveryClause(context) {
                return nil
            }
            return Copy(
                "Recovery is limited at \(context.recoveryPercent)%.",
                "Восстановление ограничено — \(context.recoveryPercent)%."
            )
        }
        if context.recoveryPercent < 80 && (context.completedSeriousTrainingToday || context.isDuringSession) {
            return Copy(
                "Recovery is still moderate at \(context.recoveryPercent)%.",
                "Восстановление пока умеренное — \(context.recoveryPercent)%."
            )
        }
        return nil
    }

    private static func dayLoadClause(_ context: Context) -> Copy? {
        if context.completedSeriousTrainingToday {
            if context.caloriesBurned >= 700 {
                return Copy(
                    "Today already has serious training in the legs.",
                    "Сегодня уже серьёзная тренировочная нагрузка."
                )
            }
            return Copy(
                "The main training work for today is already done.",
                "Главная тренировка на сегодня уже сделана."
            )
        }
        if context.caloriesBurned >= 900 {
            return Copy(
                "The day has already cost a lot of energy.",
                "День уже стоил много энергии."
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

    private static func forwardClause(_ context: Context) -> Copy? {
        if let summary = context.tomorrowRecoveryPlanSummary, !context.shouldProtectTomorrow {
            let clause = CoachTomorrowPlanReadBuilder.forwardClause(summary: summary)
            return Copy(clause.english, clause.russian)
        }
        if context.shouldProtectTomorrow {
            return Copy(
                "Tomorrow still has real training demand.",
                "Завтра ещё есть серьёзная нагрузка."
            )
        }
        guard let title = context.nextActivityTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }
        if context.isPostSession && !context.shouldProtectUpcomingSession && !context.isPreSession {
            return nil
        }
        if let hours = context.hoursUntilNextActivity {
            if hours < 0.25 {
                return Copy(
                    "\(title) starts very soon — the rest of the day should support it.",
                    "\(title) скоро начнётся — остаток дня лучше выстроить вокруг этого."
                )
            }
            if hours < 1 {
                return Copy(
                    "\(title) is within the hour — keep the rest of the day aligned with that.",
                    "\(title) в течение часа — остаток дня лучше выстроить вокруг этого."
                )
            }
            if hours < 4 {
                let rounded = max(1, Int(hours.rounded()))
                return Copy(
                    "\(title) is in about \(rounded) hour\(rounded == 1 ? "" : "s") — protect energy for it.",
                    "\(title) примерно через \(rounded) \(russianHourWord(rounded)) — берегите энергию."
                )
            }
            if context.isPreSession {
                return Copy(
                    "\(title) is the main training demand left today.",
                    "\(title) — главная тренировочная задача, которая ещё впереди сегодня."
                )
            }
        } else if context.isPreSession {
            return Copy(
                "\(title) is the main training demand left today.",
                "\(title) — главная тренировочная задача, которая ещё впереди сегодня."
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
            "Use the day context, not just the last activity.",
            "Смотрите на день целиком, а не только на последнюю активность."
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
