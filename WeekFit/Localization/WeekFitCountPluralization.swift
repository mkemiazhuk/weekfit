import Foundation

enum WeekFitRussianPluralForm: Equatable {
    case one
    case few
    case many
}

struct WeekFitCountNounForms {
    let englishOne: String
    let englishOther: String
    let russianOne: String
    let russianFew: String
    let russianMany: String

    static func standard(
        englishOne: String,
        englishOther: String,
        russianOne: String,
        russianFew: String,
        russianMany: String
    ) -> WeekFitCountNounForms {
        WeekFitCountNounForms(
            englishOne: englishOne,
            englishOther: englishOther,
            russianOne: russianOne,
            russianFew: russianFew,
            russianMany: russianMany
        )
    }
}

enum WeekFitCountPluralization {

    enum Category {
        case workout
        case meal
        case habit
        case recovery
        case plannedItem
        case session
        case portion
        case plannedPoint
        case day
        case night
        case minuteAccusative
        case hourNominative
        case ingredientAdded
    }

    static func russianForm(for count: Int) -> WeekFitRussianPluralForm {
        let mod100 = count % 100
        let mod10 = count % 10

        if (11...14).contains(mod100) {
            return .many
        }

        switch mod10 {
        case 1:
            return .one
        case 2...4:
            return .few
        default:
            return .many
        }
    }

    static func isRussian(locale: Locale = WeekFitCurrentLocale()) -> Bool {
        locale.identifier.hasPrefix("ru")
    }

    static func noun(
        count: Int,
        category: Category,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        let forms = forms(for: category)
        return noun(count: count, forms: forms, locale: locale)
    }

    static func noun(
        count: Int,
        forms: WeekFitCountNounForms,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            switch russianForm(for: count) {
            case .one:
                return forms.russianOne
            case .few:
                return forms.russianFew
            case .many:
                return forms.russianMany
            }
        }

        return count == 1 ? forms.englishOne : forms.englishOther
    }

    static func phrase(
        count: Int,
        category: Category,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        "\(count) \(noun(count: count, category: category, locale: locale))"
    }

    static func portionsPhrase(
        quantity: Double,
        formattedQuantity: String,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        let count = max(0, Int(quantity.rounded()))
        if isRussian(locale: locale) {
            return "\(formattedQuantity) \(noun(count: count, category: .portion, locale: locale))"
        }

        let suffix = count == 1 ? "portion" : "portions"
        return "\(formattedQuantity) \(suffix)"
    }

    static func toastPortionsPhrase(
        title: String,
        quantity: Double,
        formattedQuantity: String,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        "\(title) · \(portionsPhrase(quantity: quantity, formattedQuantity: formattedQuantity, locale: locale))"
    }

    static func ingredientsAddedPhrase(
        count: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        phrase(count: count, category: .ingredientAdded, locale: locale)
    }

    static func eveningPlannedCompletedPhrase(
        count: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        guard count > 0 else {
            return isRussian(locale: locale)
                ? "Вы всё равно выполнили запланированный пункт."
                : "You still completed a planned item."
        }

        if isRussian(locale: locale) {
            switch russianForm(for: count) {
            case .one:
                return "Вы всё равно выполнили 1 запланированный пункт."
            case .few:
                return "Вы всё равно выполнили \(count) запланированных пункта."
            case .many:
                return "Вы всё равно выполнили \(count) запланированных пунктов."
            }
        }

        return count == 1
            ? "You still completed 1 planned item."
            : "You still completed \(count) planned items."
    }

    static func insightsMoreDaysPhrase(
        count: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "\(count) \(noun(count: count, category: .day, locale: locale))"
        }

        return count == 1 ? "1 day" : "\(count) days"
    }

    static func insightsMoreNightsPhrase(
        count: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        phrase(count: count, category: .night, locale: locale)
    }

    static func insightsUnlockActivityDaysSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Нужно ещё \(phrase(count: needed, category: .day, locale: locale)) с активностью, чтобы открыть паттерны нагрузки."
        }
        return "\(needed) more activity \(needed == 1 ? "day" : "days") needed to unlock load patterns."
    }

    static func insightsUnlockMealDaysSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Нужно ещё \(phrase(count: needed, category: .day, locale: locale)) с приёмами пищи, чтобы открыть тренды питания."
        }
        return "\(needed) more meal \(needed == 1 ? "day" : "days") needed to unlock nutrition trends."
    }

    static func insightsUnlockRecoveryDaysSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Нужно ещё \(phrase(count: needed, category: .day, locale: locale)) с данными восстановления, чтобы понять паттерн."
        }
        return "\(needed) more recovery \(needed == 1 ? "day" : "days") needed to understand your recovery pattern."
    }

    static func insightsUnlockSleepNightsSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Нужно ещё \(phrase(count: needed, category: .night, locale: locale)) со сном, чтобы понять паттерн сна."
        }
        return "\(needed) more \(needed == 1 ? "night" : "nights") needed to understand your sleep pattern."
    }

    static func insightsLogMealsOnMoreDaysSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Записывайте еду ещё \(phrase(count: needed, category: .day, locale: locale)), чтобы сравнивать питание с восстановлением."
        }
        return "Log meals on \(needed) more \(needed == 1 ? "day" : "days") so food can be compared with recovery."
    }

    static func insightsLogDrinksOnMoreDaysSubtitle(
        needed: Int,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "Записывайте напитки ещё \(phrase(count: needed, category: .day, locale: locale)) за последние 7 дней, чтобы сравнить с восстановлением."
        }
        return "Log drinks on \(needed) more \(needed == 1 ? "day" : "days") in the last 7 days to compare with recovery."
    }

    static func insightsMoreDomainDaysReflection(
        needed: Int,
        domainName: String,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        if isRussian(locale: locale) {
            return "\(domainName.capitalized) сейчас самый ясный сигнал. Ещё \(phrase(count: needed, category: .day, locale: locale)) сделают следующий паттерн надёжнее."
        }
        return "\(domainName.capitalized) is currently the clearest signal. \(needed) more \(needed == 1 ? "day" : "days") will make the next coaching pattern more reliable."
    }

    private static func forms(for category: Category) -> WeekFitCountNounForms {
        switch category {
        case .workout:
            return .standard(
                englishOne: "workout",
                englishOther: "workouts",
                russianOne: "тренировка",
                russianFew: "тренировки",
                russianMany: "тренировок"
            )

        case .meal:
            return .standard(
                englishOne: "meal",
                englishOther: "meals",
                russianOne: "прием пищи",
                russianFew: "приема пищи",
                russianMany: "приемов пищи"
            )

        case .habit:
            return .standard(
                englishOne: "habit",
                englishOther: "habits",
                russianOne: "привычка",
                russianFew: "привычки",
                russianMany: "привычек"
            )

        case .recovery:
            return .standard(
                englishOne: "recovery activity",
                englishOther: "recovery activities",
                russianOne: "восстановление",
                russianFew: "восстановления",
                russianMany: "восстановлений"
            )

        case .plannedItem:
            return .standard(
                englishOne: "planned item",
                englishOther: "planned items",
                russianOne: "элемент плана",
                russianFew: "элемента плана",
                russianMany: "элементов плана"
            )

        case .session:
            return .standard(
                englishOne: "session",
                englishOther: "sessions",
                russianOne: "тренировка",
                russianFew: "тренировки",
                russianMany: "тренировок"
            )

        case .portion:
            return .standard(
                englishOne: "portion",
                englishOther: "portions",
                russianOne: "порция",
                russianFew: "порции",
                russianMany: "порций"
            )

        case .plannedPoint:
            return .standard(
                englishOne: "planned item",
                englishOther: "planned items",
                russianOne: "пункт",
                russianFew: "пункта",
                russianMany: "пунктов"
            )

        case .day:
            return .standard(
                englishOne: "day",
                englishOther: "days",
                russianOne: "день",
                russianFew: "дня",
                russianMany: "дней"
            )

        case .night:
            return .standard(
                englishOne: "night",
                englishOther: "nights",
                russianOne: "ночь",
                russianFew: "ночи",
                russianMany: "ночей"
            )

        case .minuteAccusative:
            return .standard(
                englishOne: "minute",
                englishOther: "minutes",
                russianOne: "минуту",
                russianFew: "минуты",
                russianMany: "минут"
            )

        case .hourNominative:
            return .standard(
                englishOne: "hour",
                englishOther: "hours",
                russianOne: "час",
                russianFew: "часа",
                russianMany: "часов"
            )

        case .ingredientAdded:
            return .standard(
                englishOne: "added",
                englishOther: "added",
                russianOne: "добавлен",
                russianFew: "добавлено",
                russianMany: "добавлено"
            )
        }
    }
}
