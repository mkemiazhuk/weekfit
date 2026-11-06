import Foundation

enum ActivityAwardCopy {
    static func name(
        kind: ActivityAwardKind,
        goal: Int?,
        unit: ActivityAwardUnit,
        activity: String,
        language: String = WeekFitCurrentLanguageCode()
    ) -> String {
        switch kind {
        case .first:
            return activity
        case .accumulation:
            return times(goal ?? 0, language)
        case .streak:
            return pack(language).streak
        case .personalRecord:
            return unit == .milliliters ? pack(language).water : pack(language).longest
        }
    }

    static func caption(
        kind: ActivityAwardKind,
        goal: Int?,
        unit: ActivityAwardUnit,
        activity: String,
        language: String = WeekFitCurrentLanguageCode()
    ) -> String {
        let title = name(kind: kind, goal: goal, unit: unit, activity: activity, language: language)
        return "\(title) · \(activity)"
    }

    static func condition(
        kind: ActivityAwardKind,
        goal: Int?,
        unit: ActivityAwardUnit,
        activity: String,
        language: String = WeekFitCurrentLanguageCode()
    ) -> String {
        let text = pack(language)
        switch kind {
        case .first:
            return activity
        case .accumulation:
            if unit == .days {
                return String(format: text.waterDays, days(goal ?? 0, language))
            }
            return String(format: text.countCondition, activity, times(goal ?? 0, language))
        case .streak:
            return String(format: text.streakCondition, activity)
        case .personalRecord:
            if unit == .milliliters { return text.waterCondition }
            return String(format: text.longestCondition, activity)
        }
    }

    static func result(_ badge: ActivityBadgeDisplay, language: String = WeekFitCurrentLanguageCode()) -> String {
        if badge.isUnlocked {
            switch badge.award.kind {
            case .first:
                if badge.award.unit == .minutes, let minutes = badge.award.best {
                    return minutesText(minutes, language)
                }
                return pack(language).completed
            case .accumulation:
                return times(badge.award.goal ?? badge.award.current, language)
            case .streak:
                return days(badge.award.best ?? badge.award.current, language)
            case .personalRecord:
                if badge.award.unit == .milliliters {
                    return volume(badge.award.current, language)
                }
                return minutesText(badge.award.current, language)
            }
        }
        return progress(badge.award.current, badge.award.goal ?? 1, language)
    }

    static func dateLine(_ badge: ActivityBadgeDisplay, language: String = WeekFitCurrentLanguageCode()) -> String? {
        guard badge.isUnlocked else { return nil }
        if badge.award.kind == .streak {
            return span(badge.award.rangeStart, badge.award.rangeEnd, language)
        }
        let date = badge.unlockedAt ?? badge.award.rangeEnd
        return date.map { medium($0, language) }
    }

    static func supporting(_ badge: ActivityBadgeDisplay, language: String = WeekFitCurrentLanguageCode()) -> String? {
        guard badge.award.kind == .streak, badge.isUnlocked else { return nil }
        return String(format: pack(language).currentStreak, days(badge.award.current, language))
    }

    static func progressFraction(_ badge: ActivityBadgeDisplay) -> Double? {
        guard !badge.isUnlocked, let goal = badge.award.goal, goal > 0 else { return nil }
        return min(1, max(0, Double(badge.award.current) / Double(goal)))
    }

    static func accessibilityLabel(for badge: ActivityBadgeDisplay, language: String = WeekFitCurrentLanguageCode()) -> String {
        var parts = [badge.name, badge.activityName]
        if badge.isUnlocked {
            parts.append(result(badge, language: language))
            if let date = dateLine(badge, language: language) { parts.append(date) }
            if let extra = supporting(badge, language: language) { parts.append(extra) }
        } else {
            parts.append(badge.condition)
            parts.append(result(badge, language: language))
        }
        return parts.joined(separator: ". ")
    }

    static func progress(_ current: Int, _ goal: Int, _ language: String = WeekFitCurrentLanguageCode()) -> String {
        String(format: pack(language).of, current, goal)
    }

    private static func times(_ count: Int, _ language: String) -> String {
        let text = pack(language)
        if language == "ru" || language == "pl" {
            return slavic(count, text.timeOne, text.timeFew, text.timeMany)
        }
        if count == 1 { return "1 \(text.timeOne)" }
        return "\(count) \(text.timeMany)"
    }

    private static func days(_ count: Int, _ language: String) -> String {
        let text = pack(language)
        if language == "ru" || language == "pl" {
            return slavic(count, text.dayOne, text.dayFew, text.dayMany)
        }
        if count == 1 { return "1 \(text.dayOne)" }
        return "\(count) \(text.dayMany)"
    }

    private static func minutesText(_ minutes: Int, _ language: String) -> String {
        "\(minutes) \(pack(language).minute)"
    }

    private static func volume(_ milliliters: Int, _ language: String) -> String {
        let text = pack(language)
        guard milliliters >= 1000 else { return "\(milliliters) \(text.milliliter)" }
        let liters = Double(milliliters) / 1000
        let number = String(format: liters >= 10 ? "%.0f" : "%.1f", liters)
        return "\(number) \(text.liter)"
    }

    private static func medium(_ date: Date, _ language: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func span(_ start: Date?, _ end: Date?, _ language: String) -> String? {
        guard let end else { return nil }
        guard let start, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return medium(end, language)
        }
        return "\(medium(start, language)) – \(medium(end, language))"
    }

    private static func slavic(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let value = abs(count)
        let mod10 = value % 10
        let mod100 = value % 100
        if mod10 == 1, mod100 != 11 { return "\(count) \(one)" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "\(count) \(few)" }
        return "\(count) \(many)"
    }

    private struct Pack {
        var of: String
        var completed: String
        var streak: String
        var longest: String
        var water: String
        var countCondition: String
        var waterDays: String
        var streakCondition: String
        var longestCondition: String
        var waterCondition: String
        var currentStreak: String
        var minute: String
        var milliliter: String
        var liter: String
        var timeOne: String
        var timeFew: String
        var timeMany: String
        var dayOne: String
        var dayFew: String
        var dayMany: String
    }

    private static func pack(_ language: String) -> Pack {
        switch language {
        case "ru":
            return Pack(
                of: "%d из %d", completed: "Завершено", streak: "Серия", longest: "Самая длинная", water: "Больше всего воды",
                countCondition: "Выполнить «%@» %@", waterDays: "Закрыть цель по воде %@",
                streakCondition: "«%@» несколько дней подряд",
                longestCondition: "Самая длинная «%@» с измеренной длительностью",
                waterCondition: "Больше всего воды за один день",
                currentStreak: "Сейчас: %@", minute: "мин", milliliter: "мл", liter: "л",
                timeOne: "раз", timeFew: "раза", timeMany: "раз",
                dayOne: "день", dayFew: "дня", dayMany: "дней"
            )
        case "de":
            return Pack(
                of: "%d von %d", completed: "Geschafft", streak: "Serie", longest: "Längste Einheit", water: "Meistes Wasser",
                countCondition: "%@ %@", waterDays: "Wasserziel an %@",
                streakCondition: "%@ an aufeinanderfolgenden Tagen",
                longestCondition: "Längste gemessene %@",
                waterCondition: "Meistes Wasser an einem Tag",
                currentStreak: "Aktuelle Serie: %@", minute: "Min.", milliliter: "ml", liter: "l",
                timeOne: "Mal", timeFew: "Mal", timeMany: "Mal",
                dayOne: "Tag", dayFew: "Tage", dayMany: "Tage"
            )
        case "es":
            return Pack(
                of: "%d de %d", completed: "Completado", streak: "Racha", longest: "Sesión más larga", water: "Más agua",
                countCondition: "Completar %@ %@", waterDays: "Llegar a la meta de agua %@",
                streakCondition: "%@ en días seguidos",
                longestCondition: "%@ más larga medida",
                waterCondition: "Más agua en un día",
                currentStreak: "Racha actual: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "vez", timeFew: "veces", timeMany: "veces",
                dayOne: "día", dayFew: "días", dayMany: "días"
            )
        case "fr":
            return Pack(
                of: "%d sur %d", completed: "Terminé", streak: "Série", longest: "Plus longue séance", water: "Plus d’eau",
                countCondition: "Terminer %@ %@", waterDays: "Atteindre l’objectif d’eau %@",
                streakCondition: "%@ plusieurs jours de suite",
                longestCondition: "Plus longue %@ mesurée",
                waterCondition: "Plus d’eau en un jour",
                currentStreak: "Série en cours : %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "fois", timeFew: "fois", timeMany: "fois",
                dayOne: "jour", dayFew: "jours", dayMany: "jours"
            )
        case "it":
            return Pack(
                of: "%d di %d", completed: "Completato", streak: "Serie", longest: "Sessione più lunga", water: "Più acqua",
                countCondition: "Completare %@ %@", waterDays: "Raggiungere l’obiettivo d’acqua %@",
                streakCondition: "%@ in giorni di fila",
                longestCondition: "%@ più lunga misurata",
                waterCondition: "Più acqua in un giorno",
                currentStreak: "Serie attuale: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "volta", timeFew: "volte", timeMany: "volte",
                dayOne: "giorno", dayFew: "giorni", dayMany: "giorni"
            )
        case "pl":
            return Pack(
                of: "%d z %d", completed: "Ukończone", streak: "Seria", longest: "Najdłuższa", water: "Najwięcej wody",
                countCondition: "Ukończ „%@” %@", waterDays: "Zamknąć cel wody %@",
                streakCondition: "„%@” przez kolejne dni",
                longestCondition: "Najdłuższa zmierzona „%@”",
                waterCondition: "Najwięcej wody w jeden dzień",
                currentStreak: "Teraz: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "raz", timeFew: "razy", timeMany: "razy",
                dayOne: "dzień", dayFew: "dni", dayMany: "dni"
            )
        case "ja":
            return Pack(
                of: "%d / %d", completed: "達成", streak: "連続日数", longest: "最長セッション", water: "いちばん多い水",
                countCondition: "%@を%@", waterDays: "水分目標を%@",
                streakCondition: "%@を連続した日に",
                longestCondition: "計測した%@の最長",
                waterCondition: "1日でいちばん多い水",
                currentStreak: "いまの連続: %@", minute: "分", milliliter: "ml", liter: "L",
                timeOne: "回", timeFew: "回", timeMany: "回",
                dayOne: "日", dayFew: "日", dayMany: "日"
            )
        case "ko":
            return Pack(
                of: "%d / %d", completed: "완료", streak: "연속", longest: "가장 긴 세션", water: "가장 많은 물",
                countCondition: "%@ %@ 완료", waterDays: "물 목표 %@",
                streakCondition: "%@를 연속한 날에",
                longestCondition: "측정된 가장 긴 %@",
                waterCondition: "하루에 가장 많은 물",
                currentStreak: "현재 연속: %@", minute: "분", milliliter: "ml", liter: "L",
                timeOne: "회", timeFew: "회", timeMany: "회",
                dayOne: "일", dayFew: "일", dayMany: "일"
            )
        case "zh-Hans":
            return Pack(
                of: "%d / %d", completed: "已完成", streak: "连续天数", longest: "最长一次", water: "最多饮水",
                countCondition: "完成%@ %@", waterDays: "达成饮水目标 %@",
                streakCondition: "连续几天完成%@",
                longestCondition: "有测量时长的最长%@",
                waterCondition: "一天中最多的饮水",
                currentStreak: "当前连续：%@", minute: "分钟", milliliter: "毫升", liter: "升",
                timeOne: "次", timeFew: "次", timeMany: "次",
                dayOne: "天", dayFew: "天", dayMany: "天"
            )
        default:
            return Pack(
                of: "%d of %d", completed: "Completed", streak: "Day streak", longest: "Longest session", water: "Most water",
                countCondition: "Complete %@ %@", waterDays: "Reach the water goal on %@",
                streakCondition: "%@ on consecutive days",
                longestCondition: "Longest measured %@",
                waterCondition: "Most water in one day",
                currentStreak: "Current streak: %@", minute: "min", milliliter: "ml", liter: "L",
                timeOne: "time", timeFew: "times", timeMany: "times",
                dayOne: "day", dayFew: "days", dayMany: "days"
            )
        }
    }
}
