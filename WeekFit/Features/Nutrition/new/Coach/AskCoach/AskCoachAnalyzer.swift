import Foundation

enum AskCoachAnalyzer {

    // MARK: Minimum sample requirements

    enum Minimums {
        static let sleepAverage = 3
        static let sleepConsistency = 5
        static let recoveryTrend = 4
        static let hrvTrend = 5
        static let rhrTrend = 5
        static let previousComparisonSessions = 1
        static let previousComparisonSleep = 3
    }

    struct Input: Equatable, Sendable {
        let question: AskCoachQuestion
        let period: AskCoachPeriodLength
        let currentDays: [AskCoachDayMetrics]
        let previousDays: [AskCoachDayMetrics]
        let range: AskCoachDateRange
        let previousRange: AskCoachDateRange
        let healthAccessGranted: Bool
        let followUp: AskCoachFollowUp?
    }

    
    private static func makeAnswer(
        input: Input,
        headline: CoachBilingualText,
        explanation: CoachBilingualText,
        supportingFacts: [CoachBilingualText],
       detailFacts: [CoachBilingualText] = [],
        inlineLimitation: CoachBilingualText? = nil,
        coverage: [AskCoachMetricCoverage],
        evidence: [AskCoachEvidenceItem],
        followUps: [AskCoachFollowUp],
        suggestedFocus: AskCoachSuggestedFocus?,
        loadState: AskCoachLoadState,
        isCompactFollowUp: Bool = false
    ) -> AskCoachAnswer {
        AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: headline,
            explanation: explanation,
            supportingFacts: Array(supportingFacts.prefix(2)),
            detailFacts: detailFacts,
            inlineLimitation: inlineLimitation,
            coverage: coverage,
            evidence: evidence,
            followUps: Array(uniqueFollowUps(followUps).prefix(2)),
            suggestedFocus: suggestedFocus,
            loadState: loadState,
            isCompactFollowUp: isCompactFollowUp
        )
    }

    static func analyze(_ input: Input) -> AskCoachAnswer {
        if !input.healthAccessGranted {
            return permissionAnswer(input)
        }

        switch input.followUp {
        case .myRecovery:
            return recoveryAnswer(input, compact: true)
        case .shorterSleepDays:
            return shorterSleepDaysAnswer(input)
        case .workoutDistribution:
            return workoutDistributionAnswer(input)
        case .comparePrevious:
            return comparePreviousAnswer(input)
        case .nextWeekFocus:
            return focusAnswer(input)
        case .backToQuestions, .none:
            break
        }

        switch input.question {
        case .weeklyOverview:
            return weeklyOverviewAnswer(input)
        case .recovery:
            return recoveryAnswer(input)
        case .consistency:
            return consistencyAnswer(input)
        }
    }

    // MARK: - Weekly overview

    private static func weeklyOverviewAnswer(_ input: Input) -> AskCoachAnswer {
        let current = input.currentDays
        let previous = input.previousDays
        let allSessions = current.flatMap(\.completedSessions)
        let sessions = allSessions.count
        let duration = totalDuration(current)
        let previousSessions = totalSessions(previous)
        let sleepCoverage = coverage(for: current, metric: \.sleepMinutes, key: "sleep")
        let recoveryCoverage = coverage(for: current, metric: \.recoveryPercent, key: "recovery")
        let sessionCoverage = AskCoachMetricCoverage(
            metricKey: "workouts",
            observedDays: current.filter(\.isActiveTrainingDay).count,
            totalDays: current.count
        )
        let countLabel = AskCoachCopy.activityCountLabel(count: sessions, sessions: allSessions)
        let durationText = AskCoachCopy.durationHoursMinutes(totalMinutes: duration)
        let previousPhrase = AskCoachCopy.previousPeriodPhrase(input.period)

        let hasAnySignal = sessions > 0 || sleepCoverage.observedDays > 0 || !recoveryScoreValues(current).isEmpty
        if !hasAnySignal {
            return noDataAnswer(input, coverage: [sessionCoverage, sleepCoverage])
        }

        var facts: [CoachBilingualText] = []
        var detailFacts: [CoachBilingualText] = []
        var inlineLimitation: CoachBilingualText?
        // Weekly overview: recovery + next focus. Avoid repeating visible counts.
        var followUps: [AskCoachFollowUp] = [.myRecovery, .nextWeekFocus]

        let headline: CoachBilingualText
        let explanation: CoachBilingualText

        if sessions > 0 {
            if previousHasSessionSignal(previous), previousSessions >= Minimums.previousComparisonSessions {
                let delta = sessions - previousSessions
                headline = weeklyFindingHeadline(delta: delta, period: input.period)
                if delta == 0 {
                    explanation = AskCoachCopy.bi(
                        "Activity volume looked similar to \(previousPhrase.english).",
                        "Объём активности похож на то, что было \(previousPhrase.russian)."
                    )
                } else if delta > 0 {
                    explanation = AskCoachCopy.bi(
                        "You logged a bit more activity than \(previousPhrase.english).",
                        "Активности чуть больше, чем \(previousPhrase.russian)."
                    )
                } else {
                    explanation = AskCoachCopy.bi(
                        "You logged a bit less activity than \(previousPhrase.english).",
                        "Активности чуть меньше, чем \(previousPhrase.russian)."
                    )
                }
            } else {
                headline = AskCoachCopy.bi(
                    "Here’s a clear read on your recent activity.",
                    "Краткий разбор вашей недавней активности."
                )
                explanation = AskCoachCopy.bi(
                    "These are logged sessions only — not a judgement of training load.",
                    "Это только записанные сессии, а не оценка тренировочной нагрузки."
                )
                if !previousHasSessionSignal(previous) {
                    inlineLimitation = AskCoachCopy.insufficientComparison(input.period)
                }
            }

            facts.append(
                AskCoachCopy.bi(
                    "\(countLabel.english) · \(durationText.english) total",
                    "\(countLabel.russian) · \(durationText.russian) всего"
                )
            )
            facts.append(
                AskCoachCopy.bi(
                    "Logged on \(sessionCoverage.observedDays) of \(sessionCoverage.totalDays) days",
                    "Записи в \(sessionCoverage.observedDays) из \(sessionCoverage.totalDays) дней"
                )
            )
        } else {
            headline = AskCoachCopy.bi(
                "No completed activities were logged in this period.",
                "За этот период нет записанных завершённых активностей."
            )
            explanation = AskCoachCopy.bi(
                "Sleep and recovery can still tell a useful story when available.",
                "Сон и восстановление всё ещё могут дать полезную картину, если есть данные."
            )
        }

        if let avgSleep = averageSleepMinutes(current), sleepCoverage.observedDays >= Minimums.sleepAverage {
            let sleepText = AskCoachCopy.sleepHours(from: avgSleep)
            if let previousAvg = averageSleepMinutes(previous),
               sleepCoverageCount(previous) >= Minimums.previousComparisonSleep {
                let delta = avgSleep - previousAvg
                let sleepFact = sleepComparisonExplanation(sleepText: sleepText, deltaMinutes: delta)
                if facts.count < 2 {
                    facts.append(sleepFact)
                } else {
                    detailFacts.append(sleepFact)
                }
            } else if facts.count < 2 {
                facts.append(
                    AskCoachCopy.bi(
                        "Average sleep \(sleepText.english)",
                        "Средний сон \(sleepText.russian)"
                    )
                )
            }
        } else if sleepCoverage.observedDays > 0, sleepCoverage.observedDays < Minimums.sleepAverage {
            inlineLimitation = AskCoachCopy.bi(
                "Sleep was recorded on only \(sleepCoverage.observedDays) of \(sleepCoverage.totalDays) nights, so averages stay provisional.",
                "Сон записан только за \(sleepCoverage.observedDays) из \(sleepCoverage.totalDays) ночей — средние пока ориентировочные."
            )
        }

        if let recoveryDelta = recoveryTrendDelta(current: current, previous: previous) {
            detailFacts.append(recoveryTrendFact(delta: recoveryDelta, period: input.period))
        }

        detailFacts.append(contentsOf: AskCoachCopy.detailFacts(from: [
            sessionCoverage, sleepCoverage, recoveryCoverage
        ]))

        let recoveryShare = allSessions.isEmpty
            ? 0
            : allSessions.filter(\.isRecoveryActivity).count
        if recoveryShare > 0, recoveryShare < sessions {
            detailFacts.insert(
                AskCoachCopy.bi(
                    "Includes \(recoveryShare) recovery sessions among logged activities.",
                    "Среди записанных активностей — \(recoveryShare) восстановительных сессий."
                ),
                at: 0
            )
        }

        let evidence = sessionEvidence(current)
        let suggested = suggestFocus(current: current, previous: previous)
        let loadState: AskCoachLoadState = (sleepCoverage.observedDays < current.count || sessions == 0)
            ? .partialData
            : .ready

        return makeAnswer(
            input: input,
            headline: headline,
            explanation: explanation,
            supportingFacts: facts,
           detailFacts: detailFacts,
            inlineLimitation: inlineLimitation,
            coverage: [sessionCoverage, sleepCoverage, recoveryCoverage],
            evidence: evidence,
            followUps: followUps,
            suggestedFocus: suggested,
            loadState: loadState
        )
    }

    private static func weeklyFindingHeadline(
        delta: Int,
        period: AskCoachPeriodLength
    ) -> CoachBilingualText {
        if abs(delta) <= 1 {
            return AskCoachCopy.bi(
                "Your activity level stayed fairly steady.",
                "Уровень активности остался довольно стабильным."
            )
        }
        if delta > 1 {
            return AskCoachCopy.bi(
                "You were a bit more active recently.",
                "В последнее время вы были немного активнее."
            )
        }
        return AskCoachCopy.bi(
            "You were a bit less active recently.",
            "В последнее время вы были немного менее активны."
        )
    }

    // MARK: - Recovery

    private static func recoveryAnswer(_ input: Input, compact: Bool = false) -> AskCoachAnswer {
        let current = input.currentDays
        let previous = input.previousDays
        let sleepCoverage = coverage(for: current, metric: \.sleepMinutes, key: "sleep")
        let recoveryCoverage = coverage(for: current, metric: \.recoveryPercent, key: "recovery")
        let hrvCoverage = coverage(for: current, metric: \.hrvSDNN, key: "hrv")
        let rhrCoverage = coverage(for: current, metric: \.restingHeartRate, key: "rhr")

        let sleepValues = sleepMinutesValues(current)
        let currentRecovery = recoveryScoreValues(current)
        let previousRecovery = recoveryScoreValues(previous)
        let hrvValues = current.compactMap(\.hrvSDNN)
        let rhrValues = current.compactMap(\.restingHeartRate)

        if sleepValues.isEmpty && currentRecovery.isEmpty && hrvValues.isEmpty && rhrValues.isEmpty {
            return noDataAnswer(
                input,
                coverage: [sleepCoverage, recoveryCoverage, hrvCoverage, rhrCoverage]
            )
        }

        var facts: [CoachBilingualText] = []
        var detailFacts: [CoachBilingualText] = []
        var inlineLimitation: CoachBilingualText?
        var followUps: [AskCoachFollowUp] = compact ? [.nextWeekFocus] : [.nextWeekFocus, .shorterSleepDays]
        let previousNoun = AskCoachCopy.previousPeriodNoun(input.period)

        let headline: CoachBilingualText
        var explanation: CoachBilingualText

        if currentRecovery.count >= Minimums.recoveryTrend, let avg = average(currentRecovery.map(Double.init)) {
            let rounded = Int(avg.rounded())
            if let previousAvg = average(previousRecovery.map(Double.init)),
               previousRecovery.count >= Minimums.recoveryTrend {
                let delta = Int((avg - previousAvg).rounded())
                if abs(delta) < 3 {
                    headline = AskCoachCopy.bi(
                        "Recovery looks steady.",
                        "Восстановление выглядит стабильным."
                    )
                } else if delta > 0 {
                    headline = AskCoachCopy.bi(
                        "Recovery is trending a little better.",
                        "Восстановление немного улучшается."
                    )
                } else {
                    headline = AskCoachCopy.bi(
                        "Recovery looks a little softer lately.",
                        "Восстановление в последнее время чуть мягче."
                    )
                }
                explanation = AskCoachCopy.bi(
                    "Compared with \(previousNoun.english), your average score moved by \(delta) points on recorded days.",
                    "По сравнению с \(previousNoun.russian) средний показатель изменился на \(delta) пунктов в дни с данными."
                )
                facts.append(
                    AskCoachCopy.bi(
                        "Average recovery \(rounded)%",
                        "Среднее восстановление \(rounded)%"
                    )
                )
            } else {
                headline = AskCoachCopy.bi(
                    "Here’s what recovery looks like lately.",
                    "Вот как выглядит восстановление в последнее время."
                )
                explanation = AskCoachCopy.bi(
                    "Average recovery score \(rounded)% on days with data.",
                    "Средний показатель восстановления \(rounded)% в дни с данными."
                )
            }
        } else if sleepValues.count >= Minimums.sleepAverage, let avgSleep = averageSleepMinutes(current) {
            let sleepText = AskCoachCopy.sleepHours(from: avgSleep)
            headline = AskCoachCopy.bi(
                "Sleep is the clearest recovery signal right now.",
                "Сон сейчас — самый ясный сигнал восстановления."
            )
            explanation = AskCoachCopy.bi(
                "Average recorded sleep was \(sleepText.english).",
                "Средний записанный сон — \(sleepText.russian)."
            )
        } else {
            headline = AskCoachCopy.bi(
                "Recovery signals are still limited.",
                "Сигналов восстановления пока мало."
            )
            explanation = AskCoachCopy.bi(
                "Missing days aren’t treated as zeros — only recorded nights and scores count.",
                "Пропуски не считаются нулями — учитываются только записанные ночи и показатели."
            )
        }

        if sleepValues.count >= Minimums.sleepAverage, let avgSleep = averageSleepMinutes(current) {
            let sleepText = AskCoachCopy.sleepHours(from: avgSleep)
            if facts.count < 2 {
                facts.append(
                    AskCoachCopy.bi(
                        "Average sleep \(sleepText.english)",
                        "Средний сон \(sleepText.russian)"
                    )
                )
            }
            if sleepValues.count >= Minimums.sleepConsistency {
                let consistencyMinutes = Int(standardDeviation(sleepValues.map(Double.init)).rounded())
                detailFacts.append(
                    AskCoachCopy.bi(
                        "Sleep duration varied by about \(consistencyMinutes) minutes.",
                        "Продолжительность сна варьировалась примерно на \(consistencyMinutes) мин."
                    )
                )
                if !compact {
                    followUps = [.shorterSleepDays, .nextWeekFocus]
                }
            }
        } else if sleepCoverage.observedDays > 0, sleepCoverage.observedDays < Minimums.sleepAverage {
            inlineLimitation = AskCoachCopy.bi(
                "Sleep coverage is thin (\(sleepCoverage.observedDays) of \(sleepCoverage.totalDays) nights), so keep conclusions light.",
                "Записей сна мало (\(sleepCoverage.observedDays) из \(sleepCoverage.totalDays) ночей) — выводы пока осторожные."
            )
        }

        if hrvValues.count >= Minimums.hrvTrend, let avgHRV = average(hrvValues) {
            detailFacts.append(
                AskCoachCopy.bi(
                    "Average overnight HRV \(Int(avgHRV.rounded())) ms",
                    "Средний ночной HRV \(Int(avgHRV.rounded())) мс"
                )
            )
        } else if hrvCoverage.observedDays > 0 {
            detailFacts.append(
                AskCoachCopy.bi(
                    "HRV on \(hrvCoverage.observedDays) days — not enough for a trend",
                    "HRV за \(hrvCoverage.observedDays) дн. — мало для тренда"
                )
            )
        }

        if rhrValues.count >= Minimums.rhrTrend, let avgRHR = average(rhrValues) {
            detailFacts.append(
                AskCoachCopy.bi(
                    "Average overnight resting HR \(Int(avgRHR.rounded())) bpm",
                    "Средний ночной пульс покоя \(Int(avgRHR.rounded())) уд/мин"
                )
            )
        }

        detailFacts.append(contentsOf: AskCoachCopy.detailFacts(from: [
            sleepCoverage, recoveryCoverage, hrvCoverage, rhrCoverage
        ]))

        let evidence = sleepEvidence(current)
        let suggested = suggestFocus(current: current, previous: previous)
        let loadState: AskCoachLoadState =
            (sleepCoverage.observedDays < Minimums.sleepAverage && recoveryCoverage.observedDays < Minimums.recoveryTrend)
            ? .partialData
            : .ready

        return makeAnswer(
            input: input,
            headline: headline,
            explanation: explanation,
            supportingFacts: facts,
            detailFacts: detailFacts,
            inlineLimitation: inlineLimitation,
            coverage: [sleepCoverage, recoveryCoverage, hrvCoverage, rhrCoverage],
            evidence: evidence,
            followUps: followUps,
            suggestedFocus: compact ? nil : suggested,
            loadState: loadState,
            isCompactFollowUp: compact
        )
    }

    // MARK: - Consistency

    private static func consistencyAnswer(_ input: Input) -> AskCoachAnswer {
        let current = input.currentDays
        let previous = input.previousDays
        let sessions = totalSessions(current)
        let activeDays = current.filter(\.isActiveTrainingDay).count
        let plannedTotal = current.reduce(0) { $0 + $1.plannedPlannerSessionCount }
        let plannedCompleted = current.reduce(0) { $0 + $1.completedPlannerSessionCount }
        let sessionCoverage = AskCoachMetricCoverage(
            metricKey: "activeDays",
            observedDays: activeDays,
            totalDays: current.count
        )

        if sessions == 0 && plannedTotal == 0 {
            return noDataAnswer(input, coverage: [sessionCoverage])
        }

        var facts: [CoachBilingualText] = []
        var followUps: [AskCoachFollowUp] = [.myRecovery, .nextWeekFocus]
        let allSessions = current.flatMap(\.completedSessions)
        let countLabel = AskCoachCopy.activityCountLabel(count: sessions, sessions: allSessions)
        let durationText = AskCoachCopy.durationHoursMinutes(totalMinutes: totalDuration(current))
        let previousNoun = AskCoachCopy.previousPeriodNoun(input.period)

        let headline = AskCoachCopy.bi(
            "Your activity was spread across \(activeDays) days.",
            "Активность распределилась на \(activeDays) дней."
        )

        let explanation = AskCoachCopy.bi(
            "Days without a logged session aren’t labeled as inactivity — only completed sessions count.",
            "Дни без записанной сессии не считаются бездействием — учитываются только завершённые сессии."
        )

        facts.append(
            AskCoachCopy.bi(
                "\(countLabel.english) · \(durationText.english)",
                "\(countLabel.russian) · \(durationText.russian)"
            )
        )

        if previousHasSessionSignal(previous) {
            let previousActive = previous.filter(\.isActiveTrainingDay).count
            facts.append(
                AskCoachCopy.bi(
                    "\(previousNoun.english.capitalized): \(previousActive) active days",
                    "\(AskCoachCopy.previousPeriodNoun(input.period).russian): \(previousActive) активных дней"
                )
            )
        }

        // Planned vs completed only when planner slots exist in-range.
        if plannedTotal > 0 {
            facts.append(
                AskCoachCopy.bi(
                    "Planner sessions completed: \(plannedCompleted) of \(plannedTotal).",
                    "Запланированные сессии выполнены: \(plannedCompleted) из \(plannedTotal)."
                )
            )
        }

        let suggested = suggestFocus(current: current, previous: previous)
        return AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: headline,
            explanation: explanation,
            supportingFacts: Array(facts.prefix(3)),
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [sessionCoverage],
            evidence: sessionEvidence(current),
            followUps: uniqueFollowUps(followUps),
            suggestedFocus: suggested,
            loadState: sessions > 0 ? .ready : .partialData,
            isCompactFollowUp: false
        )
    }

    // MARK: - Follow-ups

    private static func shorterSleepDaysAnswer(_ input: Input) -> AskCoachAnswer {
        let current = input.currentDays
        let withSleep = current.compactMap { day -> (AskCoachDayMetrics, Int)? in
            guard let sleep = day.sleepMinutes else { return nil }
            return (day, sleep)
        }
        guard withSleep.count >= Minimums.sleepAverage, let avg = averageSleepMinutes(current) else {
            return AskCoachAnswer(
                question: input.question,
                period: input.period,
                range: input.range,
                previousRange: input.previousRange,
                headline: AskCoachCopy.bi(
                    "Not enough sleep nights to highlight shorter days.",
                    "Недостаточно ночей со сном, чтобы выделить более короткие дни."
                ),
                explanation: AskCoachCopy.bi(
                    "Need at least \(Minimums.sleepAverage) recorded nights.",
                    "Нужно минимум \(Minimums.sleepAverage) ночей с записью сна."
                ),
                supportingFacts: [],
                detailFacts: [],
                inlineLimitation: nil,
            coverage: [coverage(for: current, metric: \.sleepMinutes, key: "sleep")],
                evidence: [],
                followUps: [.backToQuestions],
                suggestedFocus: nil,
                loadState: .partialData,
                isCompactFollowUp: false
            )
        }

        let shorter = withSleep
            .filter { $0.1 < avg }
            .sorted { $0.1 < $1.1 }
            .prefix(5)

        let facts = shorter.map { day, minutes in
            let label = WeekFitShortWeekdayMonthDay(day.dayStart)
            let sleep = AskCoachCopy.sleepHours(from: minutes)
            return AskCoachCopy.bi(
                "\(label): \(sleep.english)",
                "\(label): \(sleep.russian)"
            )
        }

        return AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.bi(
                "Nights shorter than your period average (\(AskCoachCopy.sleepHours(from: avg).english)).",
                "Ночи короче среднего за период (\(AskCoachCopy.sleepHours(from: avg).russian))."
            ),
            explanation: AskCoachCopy.bi(
                "Listed nights had recorded sleep below the average for this period.",
                "Перечислены ночи с записанным сном ниже среднего за этот период."
            ),
            supportingFacts: Array(facts.prefix(3)),
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [coverage(for: current, metric: \.sleepMinutes, key: "sleep")],
            evidence: shorter.map { day, minutes in
                AskCoachEvidenceItem(
                    id: day.dayKey,
                    title: AskCoachCopy.bi(
                        WeekFitShortWeekdayMonthDay(day.dayStart),
                        WeekFitShortWeekdayMonthDay(day.dayStart)
                    ),
                    detail: AskCoachCopy.sleepHours(from: minutes)
                )
            },
            followUps: [.comparePrevious, .nextWeekFocus, .backToQuestions],
            suggestedFocus: suggestFocus(current: current, previous: input.previousDays),
            loadState: .ready,
            isCompactFollowUp: false
        )
    }

    private static func workoutDistributionAnswer(_ input: Input) -> AskCoachAnswer {
        let current = input.currentDays
        let active = current.filter(\.isActiveTrainingDay)
        let facts = active.prefix(3).map { day in
            let label = WeekFitShortWeekdayMonthDay(day.dayStart)
            let count = day.completedSessionCount
            let duration = AskCoachCopy.durationHoursMinutes(totalMinutes: day.completedDurationMinutes)
            return AskCoachCopy.bi(
                "\(label): \(count) · \(duration.english)",
                "\(label): \(count) · \(duration.russian)"
            )
        }

        return AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.bi(
                "Workout distribution across \(active.count) active days.",
                "Распределение тренировок по \(active.count) активным дням."
            ),
            explanation: AskCoachCopy.bi(
                "Only days with at least one completed session are shown.",
                "Показаны только дни хотя бы с одной завершённой сессией."
            ),
            supportingFacts: Array(facts),
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [
                AskCoachMetricCoverage(
                    metricKey: "activeDays",
                    observedDays: active.count,
                    totalDays: current.count
                )
            ],
            evidence: active.map { day in
                AskCoachEvidenceItem(
                    id: day.dayKey,
                    title: AskCoachCopy.bi(
                        WeekFitShortWeekdayMonthDay(day.dayStart),
                        WeekFitShortWeekdayMonthDay(day.dayStart)
                    ),
                    detail: AskCoachCopy.bi(
                        "\(day.completedSessionCount) · \(AskCoachCopy.durationHoursMinutes(totalMinutes: day.completedDurationMinutes).english)",
                        "\(day.completedSessionCount) · \(AskCoachCopy.durationHoursMinutes(totalMinutes: day.completedDurationMinutes).russian)"
                    )
                )
            },
            followUps: [.comparePrevious, .nextWeekFocus, .backToQuestions],
            suggestedFocus: suggestFocus(current: current, previous: input.previousDays),
            loadState: active.isEmpty ? .noData : .ready,
            isCompactFollowUp: true
        )
    }

    private static func comparePreviousAnswer(_ input: Input) -> AskCoachAnswer {
        let current = input.currentDays
        let previous = input.previousDays
        var facts: [CoachBilingualText] = []

        if previousHasSessionSignal(previous) {
            facts.append(
                AskCoachCopy.bi(
                    "Workouts: \(totalSessions(current)) now vs \(totalSessions(previous)) before.",
                    "Тренировки: \(totalSessions(current)) сейчас vs \(totalSessions(previous)) раньше."
                )
            )
        } else {
            facts.append(AskCoachCopy.insufficientComparison(input.period))
        }

        if let curSleep = averageSleepMinutes(current),
           let prevSleep = averageSleepMinutes(previous),
           sleepCoverageCount(current) >= Minimums.sleepAverage,
           sleepCoverageCount(previous) >= Minimums.previousComparisonSleep {
            let curText = AskCoachCopy.sleepHours(from: curSleep)
            let prevText = AskCoachCopy.sleepHours(from: prevSleep)
            facts.append(
                AskCoachCopy.bi(
                    "Average sleep: \(curText.english) vs \(prevText.english).",
                    "Средний сон: \(curText.russian) vs \(prevText.russian)."
                )
            )
        }

        if let delta = recoveryTrendDelta(current: current, previous: previous) {
            facts.append(recoveryTrendFact(delta: delta))
        }

        return AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.bi(
                "Comparison with the previous \(input.period.dayCount) days.",
                "Сравнение с предыдущими \(input.period.dayCount) днями."
            ),
            explanation: AskCoachCopy.bi(
                "Only metrics with enough samples in both periods are compared.",
                "Сравниваются только метрики с достаточным числом наблюдений в обоих периодах."
            ),
            supportingFacts: Array(facts.prefix(3)),
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [
                coverage(for: current, metric: \.sleepMinutes, key: "sleep"),
                coverage(for: previous, metric: \.sleepMinutes, key: "sleepPrevious"),
                AskCoachMetricCoverage(
                    metricKey: "workouts",
                    observedDays: current.filter(\.isActiveTrainingDay).count,
                    totalDays: current.count
                )
            ],
            evidence: [],
            followUps: [.workoutDistribution, .nextWeekFocus, .backToQuestions],
            suggestedFocus: suggestFocus(current: current, previous: previous),
            loadState: .ready,
            isCompactFollowUp: false
        )
    }

    private static func focusAnswer(_ input: Input) -> AskCoachAnswer {
        let suggested = suggestFocus(current: input.currentDays, previous: input.previousDays)
        if let suggested {
            let title = AskCoachCopy.focusTitle(suggested.kind)
            return AskCoachAnswer(
                question: input.question,
                period: input.period,
                range: input.range,
                previousRange: input.previousRange,
                headline: AskCoachCopy.bi(
                    "Suggested focus: \(title.english)",
                    "Предлагаемый фокус: \(title.russian)"
                ),
                explanation: suggested.rationale,
                supportingFacts: [],
                detailFacts: [],
                inlineLimitation: nil,
            coverage: [
                    coverage(for: input.currentDays, metric: \.sleepMinutes, key: "sleep"),
                    AskCoachMetricCoverage(
                        metricKey: "workouts",
                        observedDays: input.currentDays.filter(\.isActiveTrainingDay).count,
                        totalDays: input.currentDays.count
                    )
                ],
                evidence: [],
                followUps: [.backToQuestions],
                suggestedFocus: suggested,
                loadState: .ready,
                isCompactFollowUp: false
            )
        }

        return AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.noSuggestion(),
            explanation: AskCoachCopy.bi(
                "Keep logging sleep and completed sessions — a focus needs clearer patterns.",
                "Продолжайте записывать сон и завершённые сессии — для фокуса нужны более ясные паттерны."
            ),
            supportingFacts: [],
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [
                coverage(for: input.currentDays, metric: \.sleepMinutes, key: "sleep")
            ],
            evidence: [],
            followUps: [.backToQuestions],
            suggestedFocus: nil,
            loadState: .partialData,
            isCompactFollowUp: false
        )
    }

    // MARK: - Focus suggestion

    static func suggestFocus(
        current: [AskCoachDayMetrics],
        previous: [AskCoachDayMetrics]
    ) -> AskCoachSuggestedFocus? {
        if let curSleep = averageSleepMinutes(current),
           let prevSleep = averageSleepMinutes(previous),
           sleepCoverageCount(current) >= Minimums.sleepAverage,
           sleepCoverageCount(previous) >= Minimums.previousComparisonSleep,
           curSleep <= prevSleep - 30 {
            return AskCoachSuggestedFocus(
                kind: .steadySleepDuration,
                rationale: AskCoachCopy.bi(
                    "Recorded sleep averaged at least 30 minutes shorter than before.",
                    "Записанный сон в среднем короче прошлого периода минимум на 30 минут."
                )
            )
        }

        if sleepCoverageCount(current) >= Minimums.sleepConsistency {
            let values = sleepMinutesValues(current).map(Double.init)
            if standardDeviation(values) >= 45 {
                return AskCoachSuggestedFocus(
                    kind: .consistentBedtime,
                    rationale: AskCoachCopy.bi(
                        "Sleep duration varied substantially across recorded nights.",
                        "Продолжительность сна сильно варьировалась между записанными ночами."
                    )
                )
            }
        }

        if let delta = recoveryTrendDelta(current: current, previous: previous), delta <= -8 {
            return AskCoachSuggestedFocus(
                kind: .protectRecovery,
                rationale: AskCoachCopy.bi(
                    "Average recovery score was lower than before where data exists.",
                    "Средний показатель восстановления ниже, чем раньше (где есть данные)."
                )
            )
        }

        let activeDays = current.filter(\.isActiveTrainingDay).count
        let dayCount = max(current.count, 1)
        if totalSessions(current) > 0, Double(activeDays) / Double(dayCount) < 0.25, dayCount >= 7 {
            return AskCoachSuggestedFocus(
                kind: .keepTrainingDays,
                rationale: AskCoachCopy.bi(
                    "Completed sessions clustered on relatively few days this period.",
                    "Завершённые сессии в этом периоде сосредоточены на относительно немногих днях."
                )
            )
        }

        return nil
    }

    // MARK: - Shared helpers

    private static func permissionAnswer(_ input: Input) -> AskCoachAnswer {
        AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.bi(
                "Health access is needed for Ask Coach.",
                "Для «Спросить тренера» нужен доступ к данным Здоровья."
            ),
            explanation: AskCoachCopy.bi(
                "Connect Apple Health to analyze workouts, sleep, and recovery from your data.",
                "Подключите Apple Health, чтобы анализировать тренировки, сон и восстановление по вашим данным."
            ),
            supportingFacts: [],
            detailFacts: [],
            inlineLimitation: nil,
            coverage: [],
            evidence: [],
            followUps: [.backToQuestions],
            suggestedFocus: nil,
            loadState: .permissionUnavailable,
            isCompactFollowUp: false
        )
    }

    private static func noDataAnswer(
        _ input: Input,
        coverage: [AskCoachMetricCoverage]
    ) -> AskCoachAnswer {
        AskCoachAnswer(
            question: input.question,
            period: input.period,
            range: input.range,
            previousRange: input.previousRange,
            headline: AskCoachCopy.bi(
                "Not enough recorded data for this question yet.",
                "Пока недостаточно записанных данных для этого вопроса."
            ),
            explanation: AskCoachCopy.bi(
                "Ask Coach only uses completed sessions and measured recovery signals — nothing is invented.",
                "«Спросить тренера» использует только завершённые сессии и измеренные сигналы восстановления — ничего не выдумывается."
            ),
            supportingFacts: [],
            detailFacts: [],
            inlineLimitation: nil,
            coverage: coverage,
            evidence: [],
            followUps: [.backToQuestions],
            suggestedFocus: nil,
            loadState: .noData,
            isCompactFollowUp: false
        )
    }

    private static func totalSessions(_ days: [AskCoachDayMetrics]) -> Int {
        days.reduce(0) { $0 + $1.completedSessionCount }
    }

    private static func totalDuration(_ days: [AskCoachDayMetrics]) -> Int {
        days.reduce(0) { $0 + $1.completedDurationMinutes }
    }

    private static func sleepMinutesValues(_ days: [AskCoachDayMetrics]) -> [Int] {
        days.compactMap(\.sleepMinutes)
    }

    private static func sleepCoverageCount(_ days: [AskCoachDayMetrics]) -> Int {
        days.compactMap(\.sleepMinutes).count
    }

    private static func averageSleepMinutes(_ days: [AskCoachDayMetrics]) -> Int? {
        let values = sleepMinutesValues(days)
        guard !values.isEmpty, let avg = average(values.map(Double.init)) else { return nil }
        return Int(avg.rounded())
    }

    private static func recoveryScoreValues(_ days: [AskCoachDayMetrics]) -> [Int] {
        days.compactMap(\.recoveryPercent)
    }

    private static func previousHasSessionSignal(_ days: [AskCoachDayMetrics]) -> Bool {
        totalSessions(days) > 0 || days.contains(where: \.hasTrainingSignal)
    }

    private static func recoveryTrendDelta(
        current: [AskCoachDayMetrics],
        previous: [AskCoachDayMetrics]
    ) -> Int? {
        let cur = recoveryScoreValues(current)
        let prev = recoveryScoreValues(previous)
        guard cur.count >= Minimums.recoveryTrend,
              prev.count >= Minimums.recoveryTrend,
              let curAvg = average(cur.map(Double.init)),
              let prevAvg = average(prev.map(Double.init)) else {
            return nil
        }
        return Int((curAvg - prevAvg).rounded())
    }

    private static func coverage(
        for days: [AskCoachDayMetrics],
        metric: KeyPath<AskCoachDayMetrics, Int?>,
        key: String
    ) -> AskCoachMetricCoverage {
        AskCoachMetricCoverage(
            metricKey: key,
            observedDays: days.compactMap { $0[keyPath: metric] }.count,
            totalDays: days.count
        )
    }

    private static func coverage(
        for days: [AskCoachDayMetrics],
        metric: KeyPath<AskCoachDayMetrics, Double?>,
        key: String
    ) -> AskCoachMetricCoverage {
        AskCoachMetricCoverage(
            metricKey: key,
            observedDays: days.compactMap { $0[keyPath: metric] }.count,
            totalDays: days.count
        )
    }

    private static func sessionEvidence(_ days: [AskCoachDayMetrics]) -> [AskCoachEvidenceItem] {
        days.filter(\.isActiveTrainingDay).map { day in
            AskCoachEvidenceItem(
                id: day.dayKey,
                title: AskCoachCopy.bi(
                    WeekFitShortWeekdayMonthDay(day.dayStart),
                    WeekFitShortWeekdayMonthDay(day.dayStart)
                ),
                detail: AskCoachCopy.bi(
                    "\(day.completedSessionCount) · \(AskCoachCopy.durationHoursMinutes(totalMinutes: day.completedDurationMinutes).english)",
                    "\(day.completedSessionCount) · \(AskCoachCopy.durationHoursMinutes(totalMinutes: day.completedDurationMinutes).russian)"
                )
            )
        }
    }

    private static func sleepEvidence(_ days: [AskCoachDayMetrics]) -> [AskCoachEvidenceItem] {
        days.compactMap { day in
            guard let sleep = day.sleepMinutes else { return nil }
            return AskCoachEvidenceItem(
                id: day.dayKey,
                title: AskCoachCopy.bi(
                    WeekFitShortWeekdayMonthDay(day.dayStart),
                    WeekFitShortWeekdayMonthDay(day.dayStart)
                ),
                detail: AskCoachCopy.sleepHours(from: sleep)
            )
        }
    }

    private static func workoutComparisonHeadline(
        countText: CoachBilingualText,
        durationText: CoachBilingualText,
        delta: Int
    ) -> CoachBilingualText {
        if delta == 0 {
            return AskCoachCopy.bi(
                "You completed \(countText.english), the same as before (\(durationText.english)).",
                "Вы завершили \(countText.russian) — столько же, сколько в прошлом периоде (\(durationText.russian))."
            )
        }
        if delta > 0 {
            return AskCoachCopy.bi(
                "You completed \(countText.english) (\(durationText.english)) — \(delta) more than before.",
                "Вы завершили \(countText.russian) (\(durationText.russian)) — на \(delta) больше, чем раньше."
            )
        }
        let absDelta = abs(delta)
        return AskCoachCopy.bi(
            "You completed \(countText.english) (\(durationText.english)) — \(absDelta) fewer than before.",
            "Вы завершили \(countText.russian) (\(durationText.russian)) — на \(absDelta) меньше, чем раньше."
        )
    }

    private static func sleepComparisonExplanation(
        sleepText: CoachBilingualText,
        deltaMinutes: Int
    ) -> CoachBilingualText {
        if abs(deltaMinutes) < 15 {
            return AskCoachCopy.bi(
                "Your average recorded sleep was \(sleepText.english), similar to before.",
                "Средняя записанная продолжительность сна — \(sleepText.russian), похоже на то, что было раньше."
            )
        }
        if deltaMinutes > 0 {
            return AskCoachCopy.bi(
                "Your average recorded sleep was \(sleepText.english) — about \(deltaMinutes) minutes longer than before.",
                "Средняя записанная продолжительность сна — \(sleepText.russian): примерно на \(deltaMinutes) минут дольше, чем раньше."
            )
        }
        let shorter = abs(deltaMinutes)
        return AskCoachCopy.bi(
            "Your average recorded sleep was \(sleepText.english) — about \(shorter) minutes shorter than before.",
            "Средняя записанная продолжительность сна — \(sleepText.russian): примерно на \(shorter) минут короче, чем раньше."
        )
    }

    private static func recoveryScoreHeadline(average: Int, delta: Int) -> CoachBilingualText {
        if abs(delta) < 3 {
            return AskCoachCopy.bi(
                "Average recovery score \(average)% — similar to before.",
                "Средний показатель восстановления \(average)% — похоже на то, что было раньше."
            )
        }
        if delta > 0 {
            return AskCoachCopy.bi(
                "Average recovery score \(average)% — about \(delta) points higher than before.",
                "Средний показатель восстановления \(average)% — примерно на \(delta) пунктов выше, чем раньше."
            )
        }
        return AskCoachCopy.bi(
            "Average recovery score \(average)% — about \(abs(delta)) points lower than before.",
            "Средний показатель восстановления \(average)% — примерно на \(abs(delta)) пунктов ниже, чем раньше."
        )
    }

    private static func recoveryTrendFact(delta: Int, period: AskCoachPeriodLength = .last7Days) -> CoachBilingualText {
        let previous = AskCoachCopy.previousPeriodNoun(period)
        if delta == 0 {
            return AskCoachCopy.bi(
                "Recovery score matched \(previous.english) where both had enough samples.",
                "Показатель восстановления совпал с \(previous.russian) (где хватало данных)."
            )
        }
        if delta > 0 {
            return AskCoachCopy.bi(
                "Recovery score averaged \(delta) points higher than \(previous.english) (recorded days only).",
                "Показатель восстановления на \(delta) пунктов выше \(previous.russian) (только дни с данными)."
            )
        }
        let drop = abs(delta)
        return AskCoachCopy.bi(
            "Recovery score averaged \(drop) points lower than \(previous.english) (recorded days only).",
            "Показатель восстановления на \(drop) пунктов ниже \(previous.russian) (только дни с данными)."
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2, let mean = average(values) else { return 0 }
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private static func uniqueFollowUps(_ items: [AskCoachFollowUp]) -> [AskCoachFollowUp] {
        var seen = Set<AskCoachFollowUp>()
        return items.filter { seen.insert($0).inserted }
    }
}
