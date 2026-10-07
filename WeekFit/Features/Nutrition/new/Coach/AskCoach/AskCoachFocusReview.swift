import Foundation

enum AskCoachFocusReview {

    /// Observable changes only — does not claim the user followed the habit.
    static func makeAnswer(
        focus: AskCoachWeeklyFocus,
        bundle: AskCoachPeriodBundle
    ) -> AskCoachAnswer {
        let sessions = bundle.currentDays.reduce(0) { $0 + $1.completedSessionCount }
        let allSessions = bundle.currentDays.flatMap(\.completedSessions)
        let sleepDays = bundle.currentDays.compactMap(\.sleepMinutes)
        let sleepCoverage = AskCoachMetricCoverage(
            metricKey: "sleep",
            observedDays: sleepDays.count,
            totalDays: bundle.currentDays.count
        )
        let activeDays = bundle.currentDays.filter(\.isActiveTrainingDay).count
        let countLabel = AskCoachCopy.activityCountLabel(count: sessions, sessions: allSessions)

        var facts: [CoachBilingualText] = [
            AskCoachCopy.bi(
                "\(countLabel.english) in the last 7 days",
                "\(countLabel.russian) за последние 7 дней"
            ),
            AskCoachCopy.bi(
                "Logged on \(activeDays) of \(bundle.currentDays.count) days",
                "Записи в \(activeDays) из \(bundle.currentDays.count) дней"
            )
        ]
        if let avg = sleepDays.isEmpty
            ? nil
            : Int((sleepDays.map(Double.init).reduce(0, +) / Double(sleepDays.count)).rounded()) {
            let sleep = AskCoachCopy.sleepHours(from: avg)
            facts.append(
                AskCoachCopy.bi(
                    "Average sleep \(sleep.english)",
                    "Средний сон \(sleep.russian)"
                )
            )
        }

        let title = AskCoachCopy.focusTitle(focus.kind)
        return AskCoachAnswer(
            question: .weeklyOverview,
            period: .last7Days,
            range: bundle.range,
            previousRange: bundle.previousRange,
            headline: AskCoachCopy.bi(
                "A quick look back at \(title.english.lowercased()).",
                "Короткий взгляд назад: \(title.russian.lowercased())."
            ),
            explanation: AskCoachCopy.bi(
                "Here are measurable changes since your focus window. WeekFit can’t confirm whether you followed the habit itself.",
                "Вот измеримые изменения после окна фокуса. WeekFit не может подтвердить, следовали ли вы самой привычке."
            ),
            supportingFacts: Array(facts.prefix(2)),
            detailFacts: AskCoachCopy.detailFacts(from: [sleepCoverage]),
            inlineLimitation: nil,
            coverage: [sleepCoverage],
            evidence: [],
            followUps: [],
            suggestedFocus: nil,
            loadState: sessions == 0 && sleepDays.isEmpty ? .partialData : .ready,
            isCompactFollowUp: true
        )
    }
}
