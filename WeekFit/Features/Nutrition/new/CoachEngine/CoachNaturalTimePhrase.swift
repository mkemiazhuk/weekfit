import Foundation

/// Natural-language time phrases for Coach narratives — never raw minute countdowns.
enum CoachNaturalTimePhrase {

    // MARK: - Time until start

    static func untilStart(minutes: Int) -> (english: String, russian: String) {
        let m = max(minutes, 1)
        switch m {
        case ..<15:
            return ("Start is almost here.", "Старт уже на носу.")
        case 15..<45:
            return ("Start is in less than an hour.", "До старта меньше часа.")
        case 45..<75:
            return ("Start is in about an hour.", "До старта примерно час.")
        case 75..<105:
            return ("Start is in about an hour and a half.", "До старта примерно полтора часа.")
        case 105..<150:
            return ("Start is in about 2 hours.", "До старта примерно 2 часа.")
        case 150..<210:
            return ("Start is in a couple of hours.", "До старта ещё пара часов.")
        case 210..<300:
            return ("Start is in a few hours.", "До старта ещё несколько часов.")
        case 300..<480:
            let hours = max(1, Int((Double(m) / 60.0).rounded()))
            return (
                "Start is in about \(hours) hours.",
                "До старта около \(hours) \(WeekFitCountPluralization.noun(count: hours, category: .hourNominative, locale: Locale(identifier: "ru")))."
            )
        default:
            return ("There is plenty of time before the start.", "До старта ещё достаточно времени.")
        }
    }

    static func preparationLead(minutes: Int) -> (english: String, russian: String) {
        let m = max(minutes, 1)
        switch m {
        case ..<15:
            return ("very soon", "скоро")
        case 15..<45:
            return ("in less than an hour", "меньше чем через час")
        case 45..<75:
            return ("in about an hour", "примерно через час")
        case 75..<105:
            return ("in about an hour and a half", "примерно через полтора часа")
        case 105..<150:
            return ("in about 2 hours", "примерно через 2 часа")
        case 150..<210:
            return ("in a couple of hours", "через пару часов")
        case 210..<300:
            return ("in a few hours", "через несколько часов")
        case 300..<480:
            let hours = max(1, Int((Double(m) / 60.0).rounded()))
            return ("in about \(hours) hours", "примерно через \(hours) \(WeekFitCountPluralization.noun(count: hours, category: .hourNominative, locale: Locale(identifier: "ru")))")
        default:
            return ("later today", "позже сегодня")
        }
    }

    // MARK: - Session duration

    static func sessionDuration(minutes: Int) -> (english: String, russian: String)? {
        guard minutes > 0 else { return nil }
        if minutes < 60 {
            return ("about \(minutes) minutes", "около \(minutes) \(WeekFitCountPluralization.noun(count: minutes, category: .minuteAccusative, locale: Locale(identifier: "ru")))")
        }
        let hours = Double(minutes) / 60.0
        if minutes % 60 == 0 {
            let h = minutes / 60
            return ("about \(h) hour\(h == 1 ? "" : "s")", "около \(h) \(WeekFitCountPluralization.noun(count: h, category: .hourNominative, locale: Locale(identifier: "ru")))")
        }
        let rounded = (hours * 2).rounded() / 2
        if rounded == floor(rounded) {
            let h = Int(rounded)
            return ("about \(h) hours", "около \(h) \(WeekFitCountPluralization.noun(count: h, category: .hourNominative, locale: Locale(identifier: "ru")))")
        }
        let whole = Int(floor(rounded))
        let half = rounded - Double(whole)
        if half > 0, whole > 0 {
            return (
                "about \(String(format: "%.1f", rounded)) hours",
                "около \(russianDecimalHours(rounded))"
            )
        }
        return ("about \(String(format: "%.1f", hours)) hours", "около \(russianDecimalHours(hours))")
    }

    // MARK: - Helpers

    private static func russianDecimalHours(_ hours: Double) -> String {
        let whole = Int(floor(hours))
        let fraction = hours - Double(whole)
        if abs(fraction - 0.5) < 0.01 {
            if whole == 0 { return "полтора часа" }
            return "\(whole),5 часа"
        }
        let rounded = Int(hours.rounded())
        return "\(rounded) \(WeekFitCountPluralization.noun(count: rounded, category: .hourNominative, locale: Locale(identifier: "ru")))"
    }
}
