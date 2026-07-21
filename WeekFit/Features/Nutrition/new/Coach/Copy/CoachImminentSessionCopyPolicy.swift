import Foundation

/// Concrete pre-session copy when the next activity starts within ~90 minutes.
enum CoachImminentSessionCopyPolicy {

    private static let imminentWindowMinutes = 90

    struct BasePack {
        let assessment: CoachCopySection
        let recommendation: CoachCopySection
        let avoid: CoachCopySection
        let nextAction: CoachCopySection
    }

    struct Teaser {
        let todayMessage: CoachBilingualText
        let coachHeadline: CoachBilingualText
    }

    static func isImminent(_ input: CoachCopyBuildInput) -> Bool {
        guard input.sessionPhase == .pre, input.focusSource == .upcoming else { return false }
        guard let minutes = input.minutesUntilStart, minutes >= 0, minutes <= imminentWindowMinutes else {
            return false
        }
        return input.focusActivity != nil
    }

    static func basePack(for input: CoachCopyBuildInput, protective: Bool) -> BasePack? {
        guard isImminent(input), let activity = input.focusActivity else { return nil }

        return BasePack(
            assessment: .single(assessment(for: activity, input: input, protective: protective)),
            recommendation: .single(recommendation(for: activity, input: input, protective: protective)),
            avoid: .single(avoid(for: activity, protective: protective)),
            nextAction: .single(nextAction(for: activity, input: input, protective: protective))
        )
    }

    static func teaser(for input: CoachCopyBuildInput, protective: Bool) -> Teaser? {
        guard isImminent(input), let activity = input.focusActivity else { return nil }

        let titleEN = displayTitle(activity, russian: false)
        let titleRU = displayTitle(activity, russian: true)
        let minutes = input.minutesUntilStart ?? 0
        let minutesEN = formatMinutesUntil(minutes, russian: false)
        let minutesRU = formatMinutesUntil(minutes, russian: true)

        let todayMessage: CoachBilingualText
        if protective {
            todayMessage = .en(
                "\(titleEN) \(minutesEN) — start easier than planned.",
                "\(titleRU.capitalized) \(minutesRU) — начните легче плана."
            )
        } else {
            todayMessage = .en(
                "\(titleEN) \(minutesEN) — \(activity.formattedStartTime) on the clock.",
                "\(titleRU.capitalized) \(minutesRU) — старт в \(activity.formattedStartTime)."
            )
        }

        return Teaser(
            todayMessage: todayMessage,
            coachHeadline: coachHeadline(for: activity.activityType)
        )
    }

    // MARK: - Sections

    private static func assessment(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let titleEN = displayTitle(activity, russian: false)
        let titleRU = displayTitle(activity, russian: true)
        let minutesEN = formatMinutesUntil(input.minutesUntilStart ?? 0, russian: false)
        let minutesRU = formatMinutesUntil(input.minutesUntilStart ?? 0, russian: true)
        let durationClauseEN = durationClause(minutes: activity.durationMinutes, russian: false)
        let durationClauseRU = durationClause(minutes: activity.durationMinutes, russian: true)

        if protective {
            if input.dayReadiness.sleepIsLow {
                return .en(
                    "\(titleEN) \(minutesEN) (\(durationClauseEN)) — short sleep, recovery not full yet.",
                    "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — короткий сон, восстановление пока не полное."
                )
            }
            if input.dayReadiness.isLowRecovery {
                return .en(
                    "\(titleEN) \(minutesEN) (\(durationClauseEN)) — recovery is still lagging.",
                    "\\(titleRU.capitalized) \\(minutesRU) (\\(durationClauseRU)) — тело ещё не восстановилось."
                )
            }
            return .en(
                "\(titleEN) \(minutesEN) (\(durationClauseEN)) — not fully topped up yet.",
                "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — запас ещё не полный."
            )
        }

        return .en(
            "\(titleEN) \(minutesEN) (\(durationClauseEN)) — time to settle pace and legs.",
            "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — пора настроить темп и ноги."
        )
    }

    private static func recommendation(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let longSession = isLongSession(activity)

        if protective {
            if longSession {
                return .en(
                    "Keep the first hour easy; shorten the route if legs stay heavy.",
                    "Первый час держите легко; сократите маршрут, если ноги тяжёлые."
                )
            }
            return .en(
                "Start lighter than planned and leave room to finish strong.",
                "Начните легче плана — так сил хватит на сильный финиш."
            )
        }

        if longSession {
            return .en(
                "First hour easy — let breathing and rhythm settle before pushing.",
                "Первый час легко — дайте дыханию и ритму настроиться до усилия."
            )
        }
        return .en(
            "Start easy — let breathing and rhythm find their place.",
            "Начните легко — пусть дыхание и ритм настроятся сами."
        )
    }

    private static func avoid(
        for activity: CoachPlannedActivitySummary,
        protective: Bool
    ) -> CoachBilingualText {
        switch activity.activityType {
        case .cycling, .running:
            if protective {
                let durationEN = durationClause(minutes: activity.durationMinutes, russian: false)
                let durationRU = durationClause(minutes: activity.durationMinutes, russian: true)
                return .en(
                    "Don't force the full \(durationEN) effort from the first minutes.",
                    "Не форсируйте полный объём (\(durationRU)) с первых минут."
                )
            }
            return .en(
                "Don't open with a sprint or heavy gear.",
                "Не стартуйте рывком или тяжёлой передачей."
            )
        case .tennis, .squash:
            return .en(
                "Don't spend energy before the first point matters.",
                "Не тратьте силы до первого важного розыгрыша."
            )
        default:
            return .en(
                "Don't race the clock from the first set.",
                "Не гонитесь с первых же подходов."
            )
        }
    }

    private static func nextAction(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let titleEN = displayTitle(activity, russian: false)
        let titleRU = displayTitle(activity, russian: true)
        let time = activity.formattedStartTime

        if isLongSession(activity) {
            return .en(
                "Water and a snack, 10-minute warmup — \(titleEN) at \(time).",
                "Вода и перекус, 10 минут разминки — \(titleRU) в \(time)."
            )
        }

        switch activity.activityType {
        case .cycling, .running:
            return .en(
                "10-minute warmup — \(titleEN) at \(time).",
                "10 минут разминки — \(titleRU) в \(time)."
            )
        case .tennis, .squash:
            return .en(
                "15-minute warmup — \(titleEN) at \(time).",
                "15 минут разминки — \(titleRU) в \(time)."
            )
        default:
            return .en(
                "Light first sets — \(titleEN) at \(time).",
                "Первые подходы легко — \(titleRU) в \(time)."
            )
        }
    }

    // MARK: - Formatting

    private static func displayTitle(_ activity: CoachPlannedActivitySummary, russian: Bool) -> String {
        let trimmed = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return activityTypeLabel(activity.activityType, russian: russian)
        }
        return CoachWorkoutTitleLocalization.displayTitle(trimmed, russian: russian)
    }

    private static func activityTypeLabel(_ type: CoachActivityType, russian: Bool) -> String {
        switch type {
        case .cycling:
            return russian ? "велосессия" : "ride"
        case .running:
            return russian ? "пробежка" : "run"
        case .tennis:
            return russian ? "теннис" : "tennis"
        case .squash:
            return russian ? "сквош" : "squash"
        case .walk:
            return russian ? "прогулка" : "walk"
        default:
            return russian ? "тренировка" : "session"
        }
    }

    private static func coachHeadline(for type: CoachActivityType) -> CoachBilingualText {
        switch type {
        case .cycling:
            return .en("Before the ride", "Перед заездом")
        case .running:
            return .en("Before the run", "Перед пробежкой")
        case .tennis, .squash:
            return .en("Before the match", "Перед игрой")
        default:
            return .en("Before the session", "Перед тренировкой")
        }
    }

    private static func formatMinutesUntil(_ minutes: Int, russian: Bool) -> String {
        if russian {
            return "через \(minutes) мин"
        }
        return "in \(minutes) min"
    }

    private static func durationClause(minutes: Int, russian: Bool) -> String {
        if russian {
            return "~\(durationHoursLabel(minutes, russian: true))"
        }
        return "~\(durationHoursLabel(minutes, russian: false))"
    }

    private static func durationHoursLabel(_ minutes: Int, russian: Bool) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if russian {
            if remainder == 0 { return "\(hours) ч" }
            if remainder == 30 { return "\(hours),5 ч" }
            return "\(hours) ч \(remainder) мин"
        }
        if remainder == 0 { return "\(hours) h" }
        if remainder == 30 { return "\(hours).5 h" }
        return "\(hours) h \(remainder) min"
    }

    private static func formatDuration(_ minutes: Int, russian: Bool) -> String {
        durationHoursLabel(minutes, russian: russian)
    }

    private static func isLongSession(_ activity: CoachPlannedActivitySummary) -> Bool {
        activity.durationMinutes >= 90
    }
}
