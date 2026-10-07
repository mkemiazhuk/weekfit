import Foundation
import WeekFitPlanner

/// Domain analysis for Coach Assistant — separate from conversational wording.
enum CoachAssistantScenarioAnalyzer {

    struct Context {
        var feeling: CoachFeelingKind?
        var clarification: CoachFeelingClarification?
        var checkInAt: Date
        var observations: [CoachDailyObservation]
        var plannedActivities: [PlannedActivity]
        var recentActivityCount: Int
        var recentActivityDayKeys: [String]
        var nutrition: CoachNutritionContext?
        /// HealthKit sharing authorization when known. Nil = unknown; never infer denial from empty samples.
        var healthAccessGranted: Bool?
    }

    // MARK: - Feeling reflection

    static func reflect(_ context: Context) -> (
        outcome: CoachFeelingComparisonKind,
        evidence: CoachFeelingEvidenceSnapshot,
        text: CoachBilingualText,
        facts: [CoachBilingualText],
        details: [CoachBilingualText]
    ) {
        guard let feeling = context.feeling else {
            return (
                .insufficient,
                .empty,
                CoachAssistantCopy.bi(
                    "Let’s start with how you feel.",
                    "Начнём с того, как вы себя чувствуете."
                ),
                [],
                []
            )
        }

        let result = CoachFeelingComparator.compare(
            .init(
                feeling: feeling,
                clarification: context.clarification,
                checkInAt: context.checkInAt,
                observations: context.observations,
                recentActivityDayKeys: context.recentActivityDayKeys,
                recentActivityCount: context.recentActivityCount
            )
        )
        let copy = CoachAssistantCopy.reflection(
            feeling: feeling,
            clarification: context.clarification,
            outcome: result.outcome,
            evidence: result.evidence
        )
        return (result.outcome, result.evidence, copy.text, copy.facts, copy.details)
    }

    // MARK: - Today activity flags

    static func todayActivityFlags(
        plannedActivities: [PlannedActivity],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (hasPlannedWorkout: Bool, hasCompletedActivity: Bool) {
        let today = plannedActivities.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let hasPlanned = today.contains {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassification.isSignificantWorkout(
                CoachPlannedActivitySnapshot(from: $0)
            )
        }
        let hasCompleted = today.contains {
            $0.isCompleted && !$0.isSkipped
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: $0)
                )
        }
        return (hasPlanned, hasCompleted)
    }

    // MARK: - Activity scenarios

    static func activityToday(feeling: CoachFeelingKind?, context: Context) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText],
        offerPlanEase: Bool
    ) {
        _ = feeling
        let calendar = Calendar.current
        let today = context.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: context.checkInAt)
        }
        let planned = today.filter {
            !$0.isCompleted && !$0.isSkipped
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: $0)
                )
        }
        let completed = today.filter {
            $0.isCompleted && !$0.isSkipped
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: $0)
                )
        }

        if !completed.isEmpty {
            return activityTodayTrend(
                completed: completed.map(CoachPlannedActivitySnapshot.init),
                plannedRemaining: planned,
                observations: context.observations,
                checkInAt: context.checkInAt
            )
        }

        if let session = planned.first {
            let name = session.type.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = name.isEmpty ? "session" : name
            let labelRU = name.isEmpty ? "сессия" : name
            return (
                CoachAssistantCopy.bi(
                    "You’ve got \(label) on today’s plan, and nothing logged yet.",
                    "В плане на сегодня есть \(labelRU), а записей пока нет."
                ),
                [],
                false
            )
        }

        return (
            CoachAssistantCopy.bi(
                "Nothing logged for today yet — that just means we don’t have movement on record.",
                "За сегодня пока ничего не записано — просто нет данных о движении."
            ),
            [],
            false
        )
    }

    /// Past-focused brief: what was logged today + light comparison to recent days when available.
    static func activityTodayTrend(
        completed: [CoachPlannedActivitySnapshot],
        plannedRemaining: [PlannedActivity],
        observations: [CoachDailyObservation],
        checkInAt: Date,
        calendar: Calendar = .current
    ) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText],
        offerPlanEase: Bool
    ) {
        let totalMinutes = completed.reduce(0) { $0 + max(1, $1.effectiveDurationMinutes) }
        let kinds = CoachAssistantCopy.activitySessionKindSummary(completed)

        var linesEN: [String] = []
        var linesRU: [String] = []
        if completed.count == 1, let only = completed.first {
            let phrase = CoachAssistantCopy.activitySessionPhrase(only)
            linesEN.append("Today you’ve got \(phrase.en) on the log.")
            linesRU.append("Сегодня в записях: \(phrase.ru).")
        } else if let kinds {
            linesEN.append(
                "Today you’ve logged \(kinds.en) — about \(totalMinutes) min."
            )
            linesRU.append(
                "Сегодня записано: \(kinds.ru) — около \(totalMinutes) мин."
            )
        } else {
            linesEN.append(
                "Today you’ve logged \(completed.count) sessions — about \(totalMinutes) min."
            )
            linesRU.append(
                "Сегодня записано \(completed.count) сессии — около \(totalMinutes) мин."
            )
        }

        if !plannedRemaining.isEmpty {
            let n = plannedRemaining.count
            linesEN.append(n == 1 ? "One more session is still on the plan." : "\(n) more sessions are still on the plan.")
            linesRU.append(n == 1 ? "В плане ещё одна сессия." : "В плане ещё \(n) сессии.")
        }

        let todayKey = CoachDailyObservation.dayKey(for: checkInAt, calendar: calendar)
        let todayObs = observations.first { $0.dayKey == todayKey }
        let yesterdayKey: String? = {
            guard let y = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: checkInAt))
            else { return nil }
            return CoachDailyObservation.dayKey(for: y, calendar: calendar)
        }()
        let yesterdayObs = yesterdayKey.flatMap { key in observations.first { $0.dayKey == key } }

        // Already stated today’s session minutes above — only add a trend vs yesterday,
        // and never restate the same duration from device exercise time.
        if let yesterdayMinutes = yesterdayObs?.exerciseMinutes, yesterdayMinutes > 0 {
            let todayMinutes = todayObs?.exerciseMinutes ?? totalMinutes
            if todayMinutes > yesterdayMinutes + 15 {
                linesEN.append("A bit more than yesterday (\(yesterdayMinutes) min).")
                linesRU.append("Чуть больше, чем вчера (\(yesterdayMinutes) мин).")
            } else if todayMinutes + 15 < yesterdayMinutes {
                linesEN.append("A bit less than yesterday (\(yesterdayMinutes) min).")
                linesRU.append("Чуть меньше, чем вчера (\(yesterdayMinutes) мин).")
            } else if abs(todayMinutes - yesterdayMinutes) <= 5
                        || abs(totalMinutes - yesterdayMinutes) <= 5 {
                // Same figure already said — don’t repeat “144 … yesterday’s 144”.
                linesEN.append("About the same as yesterday.")
                linesRU.append("Примерно как вчера.")
            } else {
                linesEN.append("About in line with yesterday (\(yesterdayMinutes) min).")
                linesRU.append("Примерно как вчера (\(yesterdayMinutes) мин).")
            }
        } else if let todayMinutes = todayObs?.exerciseMinutes,
                  todayMinutes > 0,
                  abs(todayMinutes - totalMinutes) > 15 {
            // Only cite device time when it differs meaningfully from the logged sessions.
            linesEN.append("Your device shows about \(todayMinutes) min of exercise so far.")
            linesRU.append("По устройству около \(todayMinutes) мин активности.")
        }

        return (
            CoachAssistantCopy.bi(linesEN.joined(separator: " "), linesRU.joined(separator: " ")),
            [],
            false
        )
    }

    static func activityRecentSummary(bundle: AskCoachPeriodBundle) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let sessions = bundle.currentDays.reduce(0) { $0 + $1.completedSessionCount }
        let allSessions = bundle.currentDays.flatMap(\.completedSessions)
        let minutes = allSessions.reduce(0) { $0 + $1.durationMinutes }
        let label = AskCoachCopy.activityCountLabel(count: sessions, sessions: allSessions)
        let duration = AskCoachCopy.durationHoursMinutes(totalMinutes: minutes)
        if sessions == 0 {
            return (
                CoachAssistantCopy.bi(
                    "Over the last 7 days there isn’t much completed movement on the log yet.",
                    "За последние 7 дней в записях пока мало завершённого движения."
                ),
                []
            )
        }
        return (
            CoachAssistantCopy.bi(
                "Over the last 7 days you’ve logged \(label.english) — about \(duration.english) in total.",
                "За последние 7 дней записано: \(label.russian) — примерно \(duration.russian) суммарно."
            ),
            []
        )
    }

    /// Local fallback when period bundle isn’t available — uses planner logs only.
    static func activityRecentSummaryFromPlanner(
        plannedActivities: [PlannedActivity],
        checkInAt: Date,
        calendar: Calendar = .current
    ) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let end = calendar.startOfDay(for: checkInAt)
        guard let start = calendar.date(byAdding: .day, value: -6, to: end) else {
            return (
                CoachAssistantCopy.bi(
                    "Over the last 7 days there isn’t enough logged activity to summarize yet.",
                    "За последние 7 дней пока мало записей активности для сводки."
                ),
                []
            )
        }
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let completed = plannedActivities.filter { activity in
            activity.isCompleted
                && !activity.isSkipped
                && activity.date >= start
                && activity.date < windowEnd
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: activity)
                )
        }
        let sessions = completed.count
        let totalMinutes = completed.reduce(0) { partial, activity in
            partial + max(1, CoachPlannedActivitySnapshot(from: activity).effectiveDurationMinutes)
        }
        if sessions == 0 {
            return (
                CoachAssistantCopy.bi(
                    "Over the last 7 days there aren’t completed training or movement logs in the planner yet.",
                    "За последние 7 дней в плане пока нет завершённых тренировок или движения."
                ),
                []
            )
        }
        let duration = AskCoachCopy.durationHoursMinutes(totalMinutes: totalMinutes)
        return (
            CoachAssistantCopy.bi(
                "Over the last 7 days you’ve logged \(sessions) sessions — about \(duration.english) in total.",
                "За последние 7 дней записано \(sessions) сессий — примерно \(duration.russian) суммарно."
            ),
            []
        )
    }

    static func activityConsistencySummary(bundle: AskCoachPeriodBundle) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let planned = bundle.currentDays.reduce(0) { $0 + $1.plannedPlannerSessionCount }
        let completed = bundle.currentDays.reduce(0) { $0 + $1.completedPlannerSessionCount }
        if planned == 0 && completed == 0 {
            return (
                CoachAssistantCopy.bi(
                    "There isn’t enough planned vs completed activity in the last 7 days to talk about consistency yet.",
                    "За последние 7 дней мало данных о плане и выполнении, чтобы говорить о последовательности."
                ),
                []
            )
        }
        return (
            CoachAssistantCopy.bi(
                "In the last 7 days you finished \(completed) of \(max(planned, completed)) planned sessions.",
                "За последние 7 дней выполнено \(completed) из \(max(planned, completed)) запланированных сессий."
            ),
            []
        )
    }

    static func activityConsistencySummaryFromPlanner(
        plannedActivities: [PlannedActivity],
        checkInAt: Date,
        calendar: Calendar = .current
    ) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let end = calendar.startOfDay(for: checkInAt)
        guard let start = calendar.date(byAdding: .day, value: -6, to: end) else {
            return (
                CoachAssistantCopy.bi(
                    "There isn’t enough planned vs completed activity in the last 7 days to talk about consistency yet.",
                    "За последние 7 дней мало данных о плане и выполнении, чтобы говорить о последовательности."
                ),
                []
            )
        }
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let inWindow = plannedActivities.filter { activity in
            activity.date >= start
                && activity.date < windowEnd
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: activity)
                )
        }
        let plannedCount = inWindow.filter { !$0.isSkipped }.count
        let completedCount = inWindow.filter { $0.isCompleted && !$0.isSkipped }.count
        if plannedCount == 0 && completedCount == 0 {
            return (
                CoachAssistantCopy.bi(
                    "There isn’t enough planned vs completed activity in the last 7 days to talk about consistency yet.",
                    "За последние 7 дней мало данных о плане и выполнении, чтобы говорить о последовательности."
                ),
                []
            )
        }
        return (
            CoachAssistantCopy.bi(
                "In the last 7 days you finished \(completedCount) of \(max(plannedCount, completedCount)) planned sessions.",
                "За последние 7 дней выполнено \(completedCount) из \(max(plannedCount, completedCount)) запланированных сессий."
            ),
            []
        )
    }

    // MARK: - Nutrition

    static func nutritionRemaining(nutrition: CoachNutritionContext?) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText],
        needsGoals: Bool
    ) {
        guard let nutrition else {
            return (
                CoachAssistantCopy.bi(
                    "There’s no nutrition log available yet for today. You can add meals anytime, or open Meal Builder when you’re ready.",
                    "Пока нет записей питания за сегодня. Можно добавить приёмы пищи или открыть конструктор блюд."
                ),
                [],
                false
            )
        }

        let hasCalorieGoal = nutrition.caloriesGoal > 0
        let hasProteinGoal = nutrition.proteinGoal > 0
        if !hasCalorieGoal && !hasProteinGoal {
            return (
                CoachAssistantCopy.bi(
                    "You’ve logged \(Int(nutrition.caloriesCurrent.rounded())) kcal and \(Int(nutrition.proteinCurrent.rounded())) g protein so far. Set a goal to see what’s left.",
                    "Пока записано \(Int(nutrition.caloriesCurrent.rounded())) ккал и \(Int(nutrition.proteinCurrent.rounded())) г белка. Задайте цель, чтобы увидеть остаток."
                ),
                [],
                true
            )
        }

        var facts: [CoachBilingualText] = []
        let calLogged = Int(nutrition.caloriesCurrent.rounded())
        let proLogged = Int(nutrition.proteinCurrent.rounded())
        let calGoal = Int(nutrition.caloriesGoal.rounded())
        let proGoal = Int(nutrition.proteinGoal.rounded())
        let meals = nutrition.mealsCount ?? 0

        if hasProteinGoal {
            let delta = nutrition.proteinGoal - nutrition.proteinCurrent
            if abs(delta) <= max(8, nutrition.proteinGoal * 0.08) {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Protein is \(proLogged) g of \(proGoal) g — close to your target.",
                        "Белок: \(proLogged) г из \(proGoal) г — близко к ориентиру."
                    )
                )
            } else if delta >= 0 {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Protein is \(proLogged) g of \(proGoal) g — about \(nutrition.proteinRemaining) g left.",
                        "Белок: \(proLogged) г из \(proGoal) г — остаётся около \(nutrition.proteinRemaining) г."
                    )
                )
            } else {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Protein is about \(Int((-delta).rounded())) g over today’s \(proGoal) g goal.",
                        "Белок примерно на \(Int((-delta).rounded())) г выше сегодняшней цели \(proGoal) г."
                    )
                )
            }
        }
        if hasCalorieGoal {
            let delta = nutrition.caloriesGoal - nutrition.caloriesCurrent
            if abs(delta) <= max(80, nutrition.caloriesGoal * 0.05) {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Calories are \(calLogged) of \(calGoal) kcal — close to your target.",
                        "Калории: \(calLogged) из \(calGoal) ккал — близко к ориентиру."
                    )
                )
            } else if delta >= 0 {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Calories are \(calLogged) of \(calGoal) kcal — about \(nutrition.caloriesRemaining) kcal left.",
                        "Калории: \(calLogged) из \(calGoal) ккал — остаётся около \(nutrition.caloriesRemaining) ккал."
                    )
                )
            } else {
                facts.append(
                    CoachAssistantCopy.bi(
                        "Calories are about \(Int((-delta).rounded())) kcal over today’s \(calGoal) kcal goal.",
                        "Калории примерно на \(Int((-delta).rounded())) ккал выше сегодняшней цели \(calGoal) ккал."
                    )
                )
            }
        }

        let bothNearGoal = hasCalorieGoal && hasProteinGoal
            && abs(nutrition.caloriesGoal - nutrition.caloriesCurrent) <= max(80, nutrition.caloriesGoal * 0.05)
            && abs(nutrition.proteinGoal - nutrition.proteinCurrent) <= max(8, nutrition.proteinGoal * 0.08)

        let summary: CoachBilingualText = {
            if bothNearGoal {
                return CoachAssistantCopy.bi(
                    "Calories and protein are close to your targets\(meals > 0 ? " (\(meals) meals logged)" : "").",
                    "По калориям и белку вы близко к ориентирам\(meals > 0 ? " (\(meals) приёмов)" : "")."
                )
            }
            if hasCalorieGoal && hasProteinGoal {
                let calLeft = max(0, nutrition.caloriesRemaining)
                let proLeft = max(0, nutrition.proteinRemaining)
                if calLeft > 0 || proLeft > 0 {
                    return CoachAssistantCopy.bi(
                        "So far: \(calLogged) of \(calGoal) kcal, and \(proLogged) of \(proGoal) g protein. Still about \(calLeft) kcal and \(proLeft) g protein left today.",
                        "Пока: \(calLogged) из \(calGoal) ккал и \(proLogged) из \(proGoal) г белка. Остаётся около \(calLeft) ккал и \(proLeft) г белка."
                    )
                }
                return CoachAssistantCopy.bi(
                    "So far: \(calLogged) of \(calGoal) kcal, and \(proLogged) of \(proGoal) g protein.",
                    "Пока: \(calLogged) из \(calGoal) ккал и \(proLogged) из \(proGoal) г белка."
                )
            }
            if hasCalorieGoal || hasProteinGoal {
                return CoachAssistantCopy.bi(
                    "So far you’ve logged \(calLogged) kcal and \(proLogged) g protein.",
                    "Пока записано \(calLogged) ккал и \(proLogged) г белка."
                )
            }
            return CoachAssistantCopy.bi(
                "Here’s what’s logged for food today.",
                "Вот что записано по еде на сегодня."
            )
        }()

        return (
            summary,
            Array(facts.prefix(2)),
            false
        )
    }

    static func nutritionHabits(observations: [CoachDailyObservation], checkInAt: Date) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: checkInAt)
        let keys: [String] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return CoachDailyObservation.dayKey(for: day, calendar: calendar)
        }
        let loggedDays = observations.filter { keys.contains($0.dayKey) && $0.hasTrustworthyNutritionForBeliefs }
        if loggedDays.isEmpty {
            return (
                CoachAssistantCopy.bi(
                    "Over the last 7 days there isn’t enough logged nutrition to describe a pattern. Unlogged days aren’t treated as zero intake.",
                    "За последние 7 дней мало записей питания, чтобы описать паттерн. Дни без записей не считаются нулевым рационом."
                ),
                []
            )
        }
        let avgProtein = loggedDays.compactMap(\.proteinGrams).reduce(0, +) / max(1, loggedDays.count)
        return (
            CoachAssistantCopy.bi(
                "Looking at \(loggedDays.count) logged days in the last week (not every day). Average protein on those days was about \(avgProtein) g.",
                "По \(loggedDays.count) дням с записями за неделю (не по всем дням). Средний белок в эти дни — около \(avgProtein) г."
            ),
            [
                CoachAssistantCopy.bi(
                    "This doesn’t judge whether intake was adequate overall.",
                    "Это не оценка достаточности рациона в целом."
                )
            ]
        )
    }

    // MARK: - Recovery

    static func recoveryToday(
        evidence: CoachFeelingEvidenceSnapshot,
        vitals: CoachAssistantRecoveryVitals? = nil,
        preferSleep: Bool = true
    ) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        _ = preferSleep
        var partsEN: [String] = []
        var partsRU: [String] = []

        let sleepMinutes = vitals?.sleepMinutes ?? evidence.sleepMinutes
        let sleepBaseline = evidence.sleepBaselineMinutes

        if let sleep = sleepMinutes, sleep > 0 {
            let sleepText = AskCoachCopy.sleepHours(from: sleep)
            if let baseline = sleepBaseline,
               baseline > 0 {
                let usual = AskCoachCopy.sleepHours(from: baseline)
                let shorter = sleep < baseline - CoachFeelingEvidenceRules.sleepNearBaselineMinutes
                let longer = sleep > baseline + CoachFeelingEvidenceRules.sleepNearBaselineMinutes
                if shorter {
                    partsEN.append(
                        "Last night you slept \(sleepText.english) — a bit shorter than your usual ~\(usual.english)."
                    )
                    partsRU.append(
                        "Прошлой ночью \(sleepText.russian) — чуть меньше обычных ~\(usual.russian)."
                    )
                } else if longer {
                    partsEN.append(
                        "Last night you slept \(sleepText.english) — a bit longer than your usual ~\(usual.english)."
                    )
                    partsRU.append(
                        "Прошлой ночью \(sleepText.russian) — чуть больше обычных ~\(usual.russian)."
                    )
                } else {
                    partsEN.append(
                        "Last night you slept \(sleepText.english) — about your usual ~\(usual.english)."
                    )
                    partsRU.append(
                        "Прошлой ночью \(sleepText.russian) — примерно как обычно (~\(usual.russian))."
                    )
                }
            } else {
                partsEN.append("Last night you slept \(sleepText.english).")
                partsRU.append("Прошлой ночью \(sleepText.russian).")
            }
        }

        // Sleep stages — absolute facts only (no invented baselines).
        var stageBitsEN: [String] = []
        var stageBitsRU: [String] = []
        if let deep = vitals?.deepSleepMinutes, deep > 0 {
            let t = AskCoachCopy.sleepHours(from: deep)
            stageBitsEN.append("deep \(t.english)")
            stageBitsRU.append("глубокий \(t.russian)")
        }
        if let rem = vitals?.remSleepMinutes, rem > 0 {
            let t = AskCoachCopy.sleepHours(from: rem)
            stageBitsEN.append("REM \(t.english)")
            stageBitsRU.append("REM \(t.russian)")
        }
        if let core = vitals?.coreSleepMinutes, core > 0 {
            let t = AskCoachCopy.sleepHours(from: core)
            stageBitsEN.append("core \(t.english)")
            stageBitsRU.append("core \(t.russian)")
        }
        if !stageBitsEN.isEmpty {
            if stageBitsEN.count == 1 {
                partsEN.append("That included \(stageBitsEN[0]).")
                partsRU.append("Из них \(stageBitsRU[0]).")
            } else {
                let enJoined = stageBitsEN.dropLast().joined(separator: ", ") + ", and \(stageBitsEN.last!)"
                let ruJoined = stageBitsRU.dropLast().joined(separator: ", ") + " и \(stageBitsRU.last!)"
                partsEN.append("That included \(enJoined).")
                partsRU.append("Из них \(ruJoined).")
            }
        }

        if let hrv = vitals?.hrvSDNN, hrv > 0 {
            let value = Int(hrv.rounded())
            if let baseline = vitals?.hrvBaselineSDNN, baseline > 0 {
                let base = Int(baseline.rounded())
                let delta = hrv - baseline
                if delta <= -8 {
                    partsEN.append("HRV was \(value) ms — below your usual ~\(base).")
                    partsRU.append("HRV \(value) мс — ниже обычных ~\(base).")
                } else if delta >= 8 {
                    partsEN.append("HRV was \(value) ms — above your usual ~\(base).")
                    partsRU.append("HRV \(value) мс — выше обычных ~\(base).")
                } else {
                    partsEN.append("HRV was \(value) ms — close to your usual ~\(base).")
                    partsRU.append("HRV \(value) мс — близко к обычным ~\(base).")
                }
            } else {
                partsEN.append("HRV was \(value) ms.")
                partsRU.append("HRV \(value) мс.")
            }
        }

        if let rhr = vitals?.restingHeartRate, rhr > 0 {
            let value = Int(rhr.rounded())
            if let baseline = vitals?.restingHeartRateBaseline, baseline > 0 {
                let base = Int(baseline.rounded())
                let delta = rhr - baseline
                if delta >= 4 {
                    partsEN.append("Resting heart rate was \(value) bpm — a bit above your usual ~\(base).")
                    partsRU.append("Пульс покоя \(value) уд/мин — чуть выше обычных ~\(base).")
                } else if delta <= -4 {
                    partsEN.append("Resting heart rate was \(value) bpm — a bit below your usual ~\(base).")
                    partsRU.append("Пульс покоя \(value) уд/мин — чуть ниже обычных ~\(base).")
                } else {
                    partsEN.append("Resting heart rate was \(value) bpm — close to your usual ~\(base).")
                    partsRU.append("Пульс покоя \(value) уд/мин — близко к обычным ~\(base).")
                }
            } else {
                partsEN.append("Resting heart rate was \(value) bpm.")
                partsRU.append("Пульс покоя \(value) уд/мин.")
            }
        }

        // Derived recovery score is secondary — only if we have little else.
        if partsEN.isEmpty, let recovery = evidence.recoveryPercent {
            if let baseline = evidence.recoveryBaselinePercent {
                partsEN.append(
                    "Recovery reading is \(recovery)% (usual ~\(baseline)%). Sleep and HRV details aren’t in yet."
                )
                partsRU.append(
                    "Показатель восстановления \(recovery)% (обычно ~\(baseline)%). Деталей сна и HRV пока нет."
                )
            } else {
                partsEN.append(
                    "Recovery reading is \(recovery)%. Sleep and HRV details aren’t in yet."
                )
                partsRU.append(
                    "Показатель восстановления \(recovery)%. Деталей сна и HRV пока нет."
                )
            }
        }

        guard !partsEN.isEmpty else {
            return (
                CoachAssistantCopy.bi(
                    "There isn’t enough recent sleep, HRV, or resting heart rate data to describe recovery yet.",
                    "Пока мало свежих данных о сне, HRV или пульсе покоя, чтобы описать восстановление."
                ),
                []
            )
        }

        return (
            CoachAssistantCopy.bi(partsEN.joined(separator: " "), partsRU.joined(separator: " ")),
            []
        )
    }

    static func recoveryNightsSummary(bundle: AskCoachPeriodBundle) -> (
        text: CoachBilingualText,
        facts: [CoachBilingualText]
    ) {
        let days = bundle.currentDays
        let sleepValues = days.compactMap(\.sleepMinutes).filter { $0 > 0 }
        let hrvValues = days.compactMap(\.hrvSDNN).filter { $0 > 0 }
        let rhrValues = days.compactMap(\.restingHeartRate).filter { $0 > 0 }

        var partsEN: [String] = []
        var partsRU: [String] = []

        if !sleepValues.isEmpty {
            let avg = sleepValues.reduce(0, +) / sleepValues.count
            let sleepText = AskCoachCopy.sleepHours(from: avg)
            partsEN.append(
                "Over the last \(sleepValues.count) nights, you averaged about \(sleepText.english) of sleep."
            )
            partsRU.append(
                "За последние \(sleepValues.count) ночей в среднем около \(sleepText.russian) сна."
            )
        }
        if hrvValues.count >= 3 {
            let avg = Int((hrvValues.reduce(0, +) / Double(hrvValues.count)).rounded())
            partsEN.append("Average HRV: about \(avg) ms.")
            partsRU.append("Средний HRV: около \(avg) мс.")
        } else if !hrvValues.isEmpty {
            partsEN.append("HRV showed up on \(hrvValues.count) of the last 7 days — still a thin sample.")
            partsRU.append("HRV есть за \(hrvValues.count) из 7 дней — пока мало для среднего.")
        }
        if rhrValues.count >= 3 {
            let avg = Int((rhrValues.reduce(0, +) / Double(rhrValues.count)).rounded())
            partsEN.append("Average resting heart rate: about \(avg) bpm.")
            partsRU.append("Средний пульс покоя: около \(avg) уд/мин.")
        }

        if partsEN.isEmpty {
            return (
                CoachAssistantCopy.bi(
                    "There isn’t enough sleep or HRV across the last 7 days to summarize yet.",
                    "За последние 7 дней пока мало записей сна или HRV для сводки."
                ),
                []
            )
        }

        return (
            CoachAssistantCopy.bi(partsEN.joined(separator: " "), partsRU.joined(separator: " ")),
            []
        )
    }
}
