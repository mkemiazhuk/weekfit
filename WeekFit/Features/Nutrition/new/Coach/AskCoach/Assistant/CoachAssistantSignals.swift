import Foundation
import WeekFitPlanner

/// Freshness-aware snapshot of signals Assistant may cite.
/// Missing values stay nil — never coerced to zero.
struct CoachAssistantSignalSnapshot: Equatable, Sendable {
    var checkInAt: Date
    var sleepMinutes: Int?
    var sleepBaselineMinutes: Int?
    var sleepIsFresh: Bool
    var recoveryPercent: Int?
    var recoveryBaselinePercent: Int?
    var recoveryIsFresh: Bool
    /// Derived recovery score — not HRV or RHR.
    var recoveryIsDerivedScore: Bool
    var nutritionCaloriesCurrent: Double?
    var nutritionCaloriesGoal: Double?
    var nutritionProteinCurrent: Double?
    var nutritionProteinGoal: Double?
    var nutritionMealsLogged: Int
    var nutritionKnown: Bool
    var yesterdayHardMinutes: Int?
    var yesterdayHadHardTraining: Bool
    var todayPlannedSignificant: Bool
    var todayCompletedSignificant: Bool
    var todayPlannedLabel: String?
    var recentCompletedCount48h: Int
    /// True when HealthKit sharing authorization is granted (not the same as “has data”).
    var healthKitAuthorized: Bool?

    static func build(
        checkInAt: Date,
        observations: [CoachDailyObservation],
        plannedActivities: [PlannedActivity],
        nutrition: CoachNutritionContext?,
        recentActivityCount: Int,
        healthKitAuthorized: Bool?,
        calendar: Calendar = .current
    ) -> CoachAssistantSignalSnapshot {
        var calendar = calendar
        calendar.timeZone = TimeZone.current

        let feelingEvidence = CoachFeelingComparator.gatherEvidence(
            input: .init(
                feeling: .okay,
                clarification: nil,
                checkInAt: checkInAt,
                observations: observations,
                recentActivityDayKeys: [],
                recentActivityCount: recentActivityCount
            ),
            calendar: calendar
        )

        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: checkInAt))
        let yesterdayKey = yesterday.map { CoachDailyObservation.dayKey(for: $0, calendar: calendar) }
        let yesterdayObs = observations.first { $0.dayKey == yesterdayKey }

        let todayFlags = CoachAssistantScenarioAnalyzer.todayActivityFlags(
            plannedActivities: plannedActivities,
            now: checkInAt,
            calendar: calendar
        )
        let todayPlanned = plannedActivities.first {
            calendar.isDate($0.date, inSameDayAs: checkInAt)
                && !$0.isCompleted && !$0.isSkipped
                && CoachActivityClassification.isSignificantWorkout(CoachPlannedActivitySnapshot(from: $0))
        }

        let nutritionKnown = nutrition != nil
        return CoachAssistantSignalSnapshot(
            checkInAt: checkInAt,
            sleepMinutes: feelingEvidence.sleepIsStale ? nil : feelingEvidence.sleepMinutes,
            sleepBaselineMinutes: feelingEvidence.sleepBaselineMinutes,
            sleepIsFresh: feelingEvidence.sleepMinutes != nil && !feelingEvidence.sleepIsStale,
            recoveryPercent: feelingEvidence.recoveryIsStale ? nil : feelingEvidence.recoveryPercent,
            recoveryBaselinePercent: feelingEvidence.recoveryBaselinePercent,
            recoveryIsFresh: feelingEvidence.recoveryPercent != nil && !feelingEvidence.recoveryIsStale,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nutrition?.caloriesCurrent,
            nutritionCaloriesGoal: nutrition.flatMap { $0.caloriesGoal > 0 ? $0.caloriesGoal : nil },
            nutritionProteinCurrent: nutrition?.proteinCurrent,
            nutritionProteinGoal: nutrition.flatMap { $0.proteinGoal > 0 ? $0.proteinGoal : nil },
            nutritionMealsLogged: nutrition?.mealsCount ?? 0,
            nutritionKnown: nutritionKnown,
            yesterdayHardMinutes: yesterdayObs?.exerciseMinutes,
            yesterdayHadHardTraining: yesterdayObs?.isHardTrainingDay == true,
            todayPlannedSignificant: todayFlags.hasPlannedWorkout,
            todayCompletedSignificant: todayFlags.hasCompletedActivity,
            todayPlannedLabel: todayPlanned.map { label in
                let name = label.type.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? "session" : name
            },
            recentCompletedCount48h: recentActivityCount,
            healthKitAuthorized: healthKitAuthorized
        )
    }

    var hour: Int {
        Calendar.current.component(.hour, from: checkInAt)
    }

    var isEarlyDayNutrition: Bool { hour < 14 }

    var sleepShortVsUsual: Bool {
        guard let sleep = sleepMinutes, let baseline = sleepBaselineMinutes, sleepIsFresh else { return false }
        return sleep <= baseline - CoachFeelingEvidenceRules.tiredSleepShortfallMinutes
    }

    var recoveryLowVsUsual: Bool {
        guard let recovery = recoveryPercent, let baseline = recoveryBaselinePercent, recoveryIsFresh else {
            return false
        }
        return recovery <= baseline - CoachFeelingEvidenceRules.tiredRecoveryShortfallPoints
    }

    var proteinBelowGoal: Bool {
        guard let current = nutritionProteinCurrent, let goal = nutritionProteinGoal, goal > 0 else {
            return false
        }
        return current < goal
    }

    var hasMeaningfulSignalChange: Bool {
        sleepShortVsUsual || recoveryLowVsUsual || yesterdayHadHardTraining
            || todayPlannedSignificant || (nutritionKnown && proteinBelowGoal && !isEarlyDayNutrition)
    }
}

/// Deterministic multi-signal insight used for short personalized replies.
enum CoachAssistantInsightBuilder {

    struct Result: Equatable, Sendable {
        var text: CoachBilingualText
        var insightID: String
        var recommendationID: String?
        var followUp: CoachAssistantFollowUpKind?
        var preferArea: CoachAssistantArea?
        var offerPlanEase: Bool
        /// When set, replace default topic chips.
        var choices: [CoachAssistantChoice]? = nil
        /// Jump straight into meal suggestion / plan review without an extra gate.
        var directDestination: CoachAssistantNodeID? = nil
    }

    static func openingInsight(
        signals: CoachAssistantSignalSnapshot,
        memory: CoachAssistantMemoryState,
        todayKey: String,
        recentQuestionIDs: [String]
    ) -> (mode: OpeningMode, insight: Result?) {
        // Fresh daily check-ins stay short. Insights come after feeling — never in the greeting.
        if let prior = CoachAssistantMemoryStore.priorUnresolved(memory, todayKey: todayKey) {
            switch prior.kind {
            case .easierSession:
                if signals.todayCompletedSignificant {
                    return (
                        .acknowledgeFollowUp,
                        Result(
                            text: CoachAssistantCopy.bi(
                                "You already logged activity today. How demanding did that session feel?",
                                "Сегодня уже есть записанная активность. Насколько напряжённой ощущалась эта сессия?"
                            ),
                            insightID: "open.followup.ease.done",
                            recommendationID: nil,
                            followUp: nil,
                            preferArea: .activity,
                            offerPlanEase: false,
                            choices: [
                                .init(
                                    id: "followup.ease.feltGood",
                                    title: CoachAssistantCopy.bi("Fine", "Нормально"),
                                    destination: .mindAsk
                                ),
                                .init(
                                    id: "followup.ease.feltHard",
                                    title: CoachAssistantCopy.bi("Hard", "Тяжело"),
                                    destination: .recoveryToday
                                ),
                                .init(
                                    id: "end.another",
                                    title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                                    destination: .mindAsk
                                )
                            ]
                        )
                    )
                }
                if !recentQuestionIDs.contains("open.followup.ease.ask") {
                    return (
                        .askFollowUp,
                        Result(
                            text: CoachAssistantCopy.bi(
                                "Yesterday we discussed a lighter session. Did you get a chance to do it?",
                                "Вчера обсуждали более лёгкую сессию. Получилось её сделать?"
                            ),
                            insightID: "open.followup.ease.ask",
                            recommendationID: nil,
                            followUp: .easierSession,
                            preferArea: .activity,
                            offerPlanEase: false,
                            choices: [
                                .init(
                                    id: "followup.ease.wentWell",
                                    title: CoachAssistantCopy.bi("Yes", "Да"),
                                    destination: .activityToday
                                ),
                                .init(
                                    id: "followup.ease.skipped",
                                    title: CoachAssistantCopy.bi("No", "Нет"),
                                    destination: .mindAsk
                                ),
                                .init(
                                    id: "followup.ease.stillDeciding",
                                    title: CoachAssistantCopy.bi("Changed plans", "Планы изменились"),
                                    destination: .activityGate
                                )
                            ]
                        )
                    )
                }
            case .nutritionProtein:
                if !recentQuestionIDs.contains("open.followup.nutrition") {
                    return (
                        .askFollowUp,
                        Result(
                            text: CoachAssistantCopy.bi(
                                "Last time we looked at protein. Want a meal idea for today?",
                                "В прошлый раз смотрели на белок. Нужна идея для еды сегодня?"
                            ),
                            insightID: "open.followup.nutrition",
                            recommendationID: nil,
                            followUp: .nutritionProtein,
                            preferArea: .nutrition,
                            offerPlanEase: false,
                            choices: [
                                .init(
                                    id: "followup.nutrition.yes",
                                    title: CoachAssistantCopy.bi("Yes", "Да"),
                                    destination: .nutritionChooseMeal
                                ),
                                .init(
                                    id: "followup.nutrition.no",
                                    title: CoachAssistantCopy.bi("No", "Нет"),
                                    destination: .mindAsk
                                )
                            ]
                        )
                    )
                }
            case .recoveryFocus:
                // Retired — clear silently; never reopen a weekly-focus check-in.
                break
            }
        }

        // Returning user, quiet data — still a short feeling check-in (no invented insight).
        if !signals.hasMeaningfulSignalChange,
           memory.days.contains(where: { $0.dayKey != todayKey }) {
            return (.standardFeeling, nil)
        }

        return (.standardFeeling, nil)
    }

    enum OpeningMode: Equatable, Sendable {
        case standardFeeling
        case quietReturn
        case signalLed
        case askFollowUp
        case acknowledgeFollowUp
    }

    /// After feeling: 1–3 short sentences, one question/action, chips that match.
    static func afterFeeling(
        feeling: CoachFeelingKind,
        signals: CoachAssistantSignalSnapshot,
        memory: CoachAssistantMemoryState,
        todayKey: String
    ) -> Result {
        let shownToday = Set(CoachAssistantMemoryStore.day(todayKey, in: memory)?.questionIDs ?? [])
        let recentRecs = Set(
            CoachAssistantMemoryStore.recentRecommendationIDs(memory, excludingDayKey: todayKey)
        )
        let excludedInsights = shownToday
        let excludedRecs = recentRecs.union(
            Set(CoachAssistantMemoryStore.day(todayKey, in: memory)?.recommendationIDs ?? [])
        )

        if let path = primaryPath(
            feeling: feeling,
            signals: signals,
            excludedInsightIDs: excludedInsights,
            excludedRecommendationIDs: excludedRecs
        ) {
            return path
        }

        // Scenario A / J — no manufactured concern.
        let ack: CoachBilingualText = {
            switch feeling {
            case .okay:
                return CoachAssistantCopy.bi("Got it.", "Понял.")
            case .energized:
                return CoachAssistantCopy.bi("Good to hear.", "Хорошо слышать.")
            case .tired:
                return CoachAssistantCopy.bi("Got it — feeling tired.", "Понял — чувствуешь усталость.")
            case .low:
                return CoachAssistantCopy.bi("Got it — not great today.", "Понял — сегодня не очень.")
            }
        }()
        return Result(
            text: CoachAssistantCopy.bi(
                "\(ack.english) What shall we start with?",
                "\(ack.russian) С чего начнём?"
            ),
            insightID: "feel.topicPick.\(feeling.rawValue)",
            recommendationID: nil,
            followUp: nil,
            preferArea: preferArea(feeling: feeling, signals: signals),
            offerPlanEase: false,
            choices: CoachAssistantCopy.areaStarterChoices(
                order: orderedAreas(
                    feeling: feeling,
                    signals: signals,
                    prefer: preferArea(feeling: feeling, signals: signals)
                )
            )
        )
    }

    /// One grounded path for the feeling turn — never stacks multiple questions.
    static func primaryPath(
        feeling: CoachFeelingKind,
        signals: CoachAssistantSignalSnapshot,
        excludedInsightIDs: Set<String>,
        excludedRecommendationIDs: Set<String>
    ) -> Result? {
        // B: tired/low + short sleep + demanding completed activity (+ planned today).
        if feeling.suggestsFatigueFollowUp,
           signals.sleepShortVsUsual,
           signals.yesterdayHadHardTraining,
           !excludedInsightIDs.contains("insight.sleepHard.ease") {
            let text: CoachBilingualText = {
                if signals.todayPlannedSignificant, !signals.todayCompletedSignificant {
                    return CoachAssistantCopy.bi(
                        "You slept less than usual after yesterday’s demanding session. A lighter workout may feel more manageable today. Want to review today’s plan?",
                        "Вы спали меньше обычного после вчерашней нагрузочной сессии. Сегодня более лёгкая тренировка может ощущаться проще. Посмотреть план на сегодня?"
                    )
                }
                return CoachAssistantCopy.bi(
                    "You slept less than usual after yesterday’s demanding session. Want a few recovery tips?",
                    "Вы спали меньше обычного после вчерашней нагрузочной сессии. Нужны короткие советы по восстановлению?"
                )
            }()
            return Result(
                text: text,
                insightID: "insight.sleepHard.ease",
                recommendationID: excludedRecommendationIDs.contains("rec.easePlan") ? nil : "rec.easePlan",
                followUp: .easierSession,
                preferArea: .activity,
                offerPlanEase: signals.todayPlannedSignificant && !signals.todayCompletedSignificant,
                choices: [
                    .init(
                        id: "activity.proposeEase",
                        title: CoachAssistantCopy.bi("Review plan", "Смотреть план"),
                        destination: .activityPlanConfirm,
                        action: nil
                    ),
                    .init(
                        id: "mind.recovery",
                        title: CoachAssistantCopy.bi("Recovery tips", "Восстановление"),
                        destination: .recoveryToday
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                        destination: .mindAsk
                    )
                ]
            )
        }

        // C: completed training today + protein remaining (not early-day shortfall).
        if signals.todayCompletedSignificant,
           signals.proteinBelowGoal,
           !signals.isEarlyDayNutrition,
           signals.nutritionKnown,
           !excludedInsightIDs.contains("insight.protein.afterTraining") {
            return Result(
                text: CoachAssistantCopy.bi(
                    "You logged a workout today. Based on your food entries, there’s still protein left toward your daily goal. Want an idea for your next meal?",
                    "Сегодня есть записанная тренировка. По записям еды белка до дневной цели ещё остаётся. Нужна идея для следующего приёма пищи?"
                ),
                insightID: "insight.protein.afterTraining",
                recommendationID: "rec.protein",
                followUp: .nutritionProtein,
                preferArea: .nutrition,
                offerPlanEase: false,
                choices: [
                    .init(
                        id: "nutrition.mealIdea",
                        title: CoachAssistantCopy.bi("Meal idea", "Идея еды"),
                        destination: .nutritionChooseMeal
                    ),
                    .init(
                        id: "nutrition.remaining",
                        title: CoachAssistantCopy.bi("Check food log", "Дневник еды"),
                        destination: .nutritionRemaining
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                        destination: .mindAsk
                    )
                ]
            )
        }

        // G: okay/energized but recovery lower than usual — ask about energy; don’t upgrade “Okay” to “good”.
        if (feeling == .okay || feeling == .energized),
           signals.recoveryLowVsUsual,
           !excludedInsightIDs.contains("insight.recovery.conflict") {
            let observation: CoachBilingualText = {
                switch feeling {
                case .energized:
                    return CoachAssistantCopy.bi(
                        "Your recovery is below your usual range today, even though you’re feeling good.",
                        "Восстановление сегодня ниже обычного диапазона, хотя вы чувствуете себя хорошо."
                    )
                case .okay:
                    return CoachAssistantCopy.bi(
                        "Your recovery is below your usual range today.",
                        "Восстановление сегодня ниже обычного диапазона."
                    )
                case .tired, .low:
                    return CoachAssistantCopy.bi(
                        "Your recovery is below your usual range today.",
                        "Восстановление сегодня ниже обычного диапазона."
                    )
                }
            }()
            let question = CoachAssistantCopy.bi(
                "How does your energy feel during activity today?",
                "Как ощущается энергия во время активности сегодня?"
            )
            return Result(
                text: CoachAssistantMessageFormatter.compose(observation, question),
                insightID: "insight.recovery.conflict",
                recommendationID: "data.recovery.belowBaseline",
                followUp: nil,
                preferArea: .activity,
                offerPlanEase: false,
                choices: [
                    .init(
                        id: "recovery.energy.normal",
                        title: CoachAssistantCopy.bi("Normal", "Обычная"),
                        destination: .activityToday
                    ),
                    .init(
                        id: "recovery.energy.lower",
                        title: CoachAssistantCopy.bi("Lower than usual", "Ниже обычной"),
                        destination: .recoveryToday
                    ),
                    .init(
                        id: "recovery.energy.notStarted",
                        title: CoachAssistantCopy.bi("Haven’t started", "Ещё не начинал(а)"),
                        destination: .mindAsk
                    )
                ]
            )
        }

        // F: energized + sleep near usual + planned activity.
        if feeling == .energized,
           signals.sleepIsFresh,
           let sleep = signals.sleepMinutes,
           let baseline = signals.sleepBaselineMinutes,
           sleep >= baseline - CoachFeelingEvidenceRules.sleepNearBaselineMinutes,
           signals.todayPlannedSignificant,
           !signals.todayCompletedSignificant,
           !excludedInsightIDs.contains("insight.energized.plan") {
            return Result(
                text: CoachAssistantCopy.bi(
                    "Glad you’re feeling energized — sleep looks closer to your usual. Want to review today’s planned session?",
                    "Хорошо, что есть энергия — сон ближе к обычному. Посмотреть запланированную сессию на сегодня?"
                ),
                insightID: "insight.energized.plan",
                recommendationID: nil,
                followUp: nil,
                preferArea: .activity,
                offerPlanEase: false,
                choices: [
                    .init(
                        id: "activity.decideTrain",
                        title: CoachAssistantCopy.bi("Review session", "Смотреть сессию"),
                        destination: .activityToday
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                        destination: .mindAsk
                    ),
                    .init(
                        id: "end.done",
                        title: CoachAssistantCopy.bi("Done", "Готово"),
                        destination: .end
                    )
                ]
            )
        }

        // Tired/low + short sleep only (no hard-day combo).
        if feeling.suggestsFatigueFollowUp,
           signals.sleepShortVsUsual,
           !excludedInsightIDs.contains("insight.sleep.short") {
            return Result(
                text: CoachAssistantCopy.bi(
                    "You slept less than usual last night. Want recovery tips, or to check today’s plan?",
                    "Прошлой ночью вы спали меньше обычного. Нужны советы по восстановлению или смотрим план на сегодня?"
                ),
                insightID: "insight.sleep.short",
                recommendationID: nil,
                followUp: nil,
                preferArea: .recovery,
                offerPlanEase: signals.todayPlannedSignificant,
                choices: [
                    .init(
                        id: "mind.recovery",
                        title: CoachAssistantCopy.bi("Recovery tips", "Восстановление"),
                        destination: .recoveryToday
                    ),
                    .init(
                        id: "activity.proposeEase",
                        title: CoachAssistantCopy.bi("Review plan", "Смотреть план"),
                        destination: .activityPlanConfirm
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                        destination: .mindAsk
                    )
                ]
            )
        }

        return nil
    }

    static func preferArea(
        feeling: CoachFeelingKind?,
        signals: CoachAssistantSignalSnapshot
    ) -> CoachAssistantArea? {
        if signals.recoveryLowVsUsual || signals.sleepShortVsUsual { return .recovery }
        if feeling?.suggestsFatigueFollowUp == true, signals.todayPlannedSignificant { return .activity }
        if signals.proteinBelowGoal, !signals.isEarlyDayNutrition { return .nutrition }
        if signals.todayPlannedSignificant || signals.yesterdayHadHardTraining { return .activity }
        return nil
    }

    /// Order Nutrition / Recovery / Activity by relevance; always keep all three.
    static func orderedAreas(
        feeling: CoachFeelingKind?,
        signals: CoachAssistantSignalSnapshot,
        prefer: CoachAssistantArea?
    ) -> [CoachAssistantArea] {
        var scores: [CoachAssistantArea: Int] = [
            .nutrition: 0,
            .recovery: 0,
            .activity: 0
        ]
        if let prefer { scores[prefer, default: 0] += 5 }
        if signals.recoveryLowVsUsual || signals.sleepShortVsUsual { scores[.recovery, default: 0] += 3 }
        if feeling?.suggestsFatigueFollowUp == true { scores[.recovery, default: 0] += 2; scores[.activity, default: 0] += 1 }
        if feeling == .energized { scores[.activity, default: 0] += 2 }
        if signals.todayPlannedSignificant { scores[.activity, default: 0] += 2 }
        if signals.proteinBelowGoal, !signals.isEarlyDayNutrition { scores[.nutrition, default: 0] += 3 }
        if signals.nutritionKnown, signals.isEarlyDayNutrition { scores[.nutrition, default: 0] += 1 }

        let base: [CoachAssistantArea] = [.nutrition, .recovery, .activity]
        return base.sorted { (scores[$0] ?? 0) > (scores[$1] ?? 0) }
    }
}
