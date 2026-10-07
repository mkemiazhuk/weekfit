import Foundation

enum AskCoachCopy {

    static func bi(_ english: String, _ russian: String, chinese: String? = nil) -> CoachBilingualText {
        let resolvedChinese = chinese
            ?? CoachChineseOverrides.resolved(english: english)
            ?? english
        return .en(english, russian, chinese: resolvedChinese)
    }

    static func resolve(_ text: CoachBilingualText) -> String {
        text.resolved()
    }

    /// Prefer “activities” when the set mixes recovery and training records.
    static func activityCountLabel(
        count: Int,
        sessions: [AskCoachCompletedSession]
    ) -> CoachBilingualText {
        guard count > 0 else {
            return bi("no logged activities", "нет записанной активности")
        }
        let recoveryCount = sessions.filter(\.isRecoveryActivity).count
        let usesActivities = recoveryCount > 0 && recoveryCount < count
        let allRecovery = recoveryCount == count

        if allRecovery {
            if count == 1 {
                return bi("1 recovery session", "1 восстановительная сессия")
            }
            return bi("\(count) recovery sessions", "\(count) восстановительных сессий")
        }
        if usesActivities {
            if count == 1 {
                return bi("1 activity", "1 активность")
            }
            return bi("\(count) activities", "\(count) активностей")
        }
        if count == 1 {
            return bi("1 workout", "1 тренировка")
        }
        return bi("\(count) workouts", "\(count) тренировок")
    }

    static func durationHoursMinutes(totalMinutes: Int) -> CoachBilingualText {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return bi("\(minutes)m", "\(minutes)м")
        }
        if minutes == 0 {
            return bi("\(hours)h", "\(hours)ч")
        }
        return bi("\(hours)h \(minutes)m", "\(hours)ч \(minutes)м")
    }

    /// Sleep as “7h 30m”, not “7.5 h”.
    static func sleepHours(from minutes: Int) -> CoachBilingualText {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return bi("\(mins)m", "\(mins)м")
        }
        if mins == 0 {
            return bi("\(hours)h", "\(hours)ч")
        }
        return bi("\(hours)h \(mins)m", "\(hours)ч \(mins)м")
    }

    /// Used in phrases like “similar to …” / “чем …”.
    static func previousPeriodPhrase(_ period: AskCoachPeriodLength) -> CoachBilingualText {
        switch period {
        case .last7Days:
            return bi("last week", "на прошлой неделе")
        case .last28Days:
            return bi("the previous 28 days", "за предыдущие 28 дней")
        }
    }

    /// Used in phrases like “higher than …”.
    static func previousPeriodNoun(_ period: AskCoachPeriodLength) -> CoachBilingualText {
        switch period {
        case .last7Days:
            return bi("last week", "прошлой недели")
        case .last28Days:
            return bi("the previous 28 days", "предыдущих 28 дней")
        }
    }

    static func coverageLine(metricEnglish: String, metricRussian: String, observed: Int, total: Int) -> CoachBilingualText {
        bi(
            "\(metricEnglish) recorded for \(observed) of \(total) days",
            "\(metricRussian): данные за \(observed) из \(total) дней"
        )
    }

    static func insufficientComparison(_ period: AskCoachPeriodLength) -> CoachBilingualText {
        let noun = previousPeriodNoun(period)
        return bi(
            "Not enough data from \(noun.english) to compare.",
            "Недостаточно данных за \(noun.russian) для сравнения."
        )
    }

    static func noSuggestion() -> CoachBilingualText {
        bi(
            "There isn’t enough consistent evidence for a weekly focus yet.",
            "Пока недостаточно устойчивых данных, чтобы предложить фокус на неделю."
        )
    }

    static func focusTitle(_ kind: AskCoachFocusKind) -> CoachBilingualText {
        switch kind {
        case .consistentBedtime:
            return bi("More consistent sleep timing", "Более стабильный режим сна")
        case .protectRecovery:
            return bi("Protect recovery this week", "Беречь восстановление на этой неделе")
        case .keepTrainingDays:
            return bi("Spread training across more days", "Распределить тренировки по большему числу дней")
        case .steadySleepDuration:
            return bi("Steady sleep duration", "Стабильная продолжительность сна")
        }
    }

    static func focusDetail(_ kind: AskCoachFocusKind) -> CoachBilingualText {
        switch kind {
        case .consistentBedtime:
            return bi(
                "Aim for similar bed and wake times on the nights you can measure.",
                "Стремитесь к похожему времени отхода ко сну и подъёма в ночи, которые можете отслеживать."
            )
        case .protectRecovery:
            return bi(
                "Keep at least one easier day and watch sleep coverage before adding load.",
                "Оставьте хотя бы один более лёгкий день и следите за записью сна, прежде чем добавлять нагрузку."
            )
        case .keepTrainingDays:
            return bi(
                "If you train, try completing sessions on three separate days you can log.",
                "Если тренируетесь, попробуйте завершить сессии в три разных дня, которые можно записать."
            )
        case .steadySleepDuration:
            return bi(
                "Prioritize nights closer to your recent average sleep duration.",
                "Приоритизируйте ночи ближе к вашей недавней средней продолжительности сна."
            )
        }
    }

    static func coverageDisplay(_ coverage: AskCoachMetricCoverage) -> CoachBilingualText {
        switch coverage.metricKey {
        case "sleep", "sleepPrevious":
            return coverageLine(
                metricEnglish: "Sleep",
                metricRussian: "Сон",
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        case "recovery":
            return coverageLine(
                metricEnglish: "Recovery score",
                metricRussian: "Показатель восстановления",
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        case "hrv":
            return coverageLine(
                metricEnglish: "HRV",
                metricRussian: "HRV",
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        case "rhr":
            return coverageLine(
                metricEnglish: "Resting heart rate",
                metricRussian: "Пульс покоя",
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        case "workouts", "activeDays":
            return coverageLine(
                metricEnglish: "Days with logged activity",
                metricRussian: "Дни с записанной активностью",
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        default:
            return coverageLine(
                metricEnglish: coverage.metricKey,
                metricRussian: coverage.metricKey,
                observed: coverage.observedDays,
                total: coverage.totalDays
            )
        }
    }

    static func detailFacts(from coverage: [AskCoachMetricCoverage]) -> [CoachBilingualText] {
        coverage.map(coverageDisplay)
    }
}
