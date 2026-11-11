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
            if unit == .kilometers {
                return kilometers(goal ?? 0, language)
            }
            return times(goal ?? 0, language)
        case .streak:
            return pack(language).streak
        case .personalRecord:
            if unit == .kilocalories {
                return "\(goal ?? 0) \(language == "ru" ? "ккал" : "kcal")"
            }
            if unit == .kilometers {
                return longestDistanceName(catalogTitle: activity, language: language)
            }
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
        if unit == .kilocalories {
            if language == "ru" {
                return "\(groupedThousands(goal ?? 0)) ккал"
            }
            return title
        }
        if unit == .milliliters {
            return title
        }
        if kind == .personalRecord, unit == .kilometers {
            return title
        }
        if language == "ru", unit == .kilometers, activity == "Прогулка" {
            return "\(title) пешком"
        }
        return "\(title) · \(activity)"
    }

    static func sessionMetric(
        _ source: ActivityAwardSource,
        preferring unit: ActivityAwardUnit? = nil,
        language: String = WeekFitCurrentLanguageCode()
    ) -> String? {
        if unit == .kilometers, let distance = distanceMetric(source, language) {
            return distance
        }
        if let kcal = source.kilocalories, kcal > 0 {
            let number = language == "ru" ? groupedThousands(kcal) : "\(kcal)"
            return "\(number) \(WeekFitLocalizedString("common.unit.kcal"))"
        }
        if let meters = source.distanceMeters, meters >= 100, let distance = distanceMetric(source, language) {
            return distance
        }
        if source.waterMilliliters > 0 {
            return String(format: WeekFitLocalizedString("common.unit.millilitersFormat"), source.waterMilliliters)
        }
        if source.durationMinutes > 0 {
            return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), source.durationMinutes)
        }
        return nil
    }

    private static func distanceMetric(_ source: ActivityAwardSource, _ language: String) -> String? {
        guard let meters = source.distanceMeters, meters >= 100 else { return nil }
        let kilometers = Double(meters) / 1000
        let number = kilometers >= 10
            ? "\(Int(kilometers.rounded()))"
            : String(format: "%g", (kilometers * 10).rounded() / 10)
        return "\(number) \(WeekFitLocalizedString("common.unit.kilometer"))"
    }

    static func sessionWhen(
        _ date: Date,
        language: String = WeekFitCurrentLanguageCode(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return ActivityBadgeCopy.sessionToday
        }
        return medium(date, language)
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
            if unit == .kilometers {
                return kilometers(goal ?? 0, language)
            }
            if unit == .days {
                return String(format: text.waterDays, days(goal ?? 0, language))
            }
            return String(format: text.countCondition, activity, times(goal ?? 0, language))
        case .streak:
            return String(format: text.streakCondition, activity)
        case .personalRecord:
            if unit == .kilocalories {
                let amount = goal ?? 0
                return language == "ru" ? "Одна сессия от \(amount) ккал" : "One session of \(amount) kcal"
            }
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
                if badge.award.unit == .kilometers {
                    return kilometers(badge.award.goal ?? badge.award.current, language)
                }
                return times(badge.award.goal ?? badge.award.current, language)
            case .streak:
                return days(badge.award.best ?? badge.award.current, language)
            case .personalRecord:
                if badge.award.unit == .kilocalories {
                    return "\(badge.award.current) \(language == "ru" ? "ккал" : "kcal")"
                }
                if badge.award.unit == .kilometers {
                    return distanceText(meters: badge.award.current, language: language)
                }
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

    static func story(_ badge: ActivityBadgeDisplay, language: String = WeekFitCurrentLanguageCode()) -> String {
        let activity = badge.activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = activity.isEmpty ? badge.name : activity
        let lead: String
        if badge.id == "recovery.walk", badge.award.kind == .first, !badge.isUnlocked {
            lead = sentence("walk", language)
        } else if badge.id == "recovery.breathing", badge.award.kind == .first, !badge.isUnlocked {
            lead = sentence("breath", language)
        } else if badge.id == "habit.drink-water", badge.award.kind == .first, !badge.isUnlocked {
            lead = sentence("waterGoal", language)
        } else {
            switch badge.award.kind {
            case .first:
                lead = fill(sentence(badge.isUnlocked ? "earnedFirst" : "earnFirst", language), named)
            case .accumulation:
                if badge.award.unit == .kilometers {
                    let distance = kilometers(badge.award.goal ?? badge.award.current, language)
                    lead = fill(sentence(badge.isUnlocked ? "earnedDistance" : "earnDistance", language), distance, named)
                } else {
                    let count = times(badge.award.goal ?? badge.award.current, language)
                    lead = fill(sentence(badge.isUnlocked ? "earnedCount" : "earnCount", language), named, count)
                }
            case .streak:
                lead = fill(sentence(badge.isUnlocked ? "earnedStreak" : "earnStreak", language), named)
            case .personalRecord:
                if badge.award.unit == .kilocalories {
                    let amount = "\(badge.award.goal ?? badge.award.current) \(language == "ru" ? "ккал" : "kcal")"
                    lead = fill(sentence(badge.isUnlocked ? "earnedKcal" : "earnKcal", language), amount)
                } else if badge.award.unit == .milliliters {
                    lead = badge.isUnlocked
                        ? fill(sentence("earnedWater", language), volume(badge.award.current, language))
                        : sentence("earnWater", language)
                } else if badge.award.unit == .kilometers {
                    lead = badge.isUnlocked
                        ? fill(sentence("earnedLongest", language), named, distanceText(meters: badge.award.current, language: language))
                        : fill(sentence("earnLongest", language), named)
                } else {
                    lead = badge.isUnlocked
                        ? fill(sentence("earnedLongest", language), named, minutesText(badge.award.current, language))
                        : fill(sentence("earnLongest", language), named)
                }
            }
        }
        guard badge.isUnlocked, let date = dateLine(badge, language: language) else { return lead }
        return lead + "\n" + fill(sentence("earnedOn", language), date)
    }

    static func longestDistanceName(catalogTitle: String, language: String = WeekFitCurrentLanguageCode()) -> String {
        let titles: [String: [String: String]] = [
            "walk": [
                "en": "Longest walk", "ru": "Рекорд пешком", "de": "Längster Spaziergang",
                "es": "Caminata más larga", "fr": "Plus longue marche", "it": "Camminata più lunga",
                "pl": "Najdłuższy spacer", "ja": "最長の散歩", "ko": "가장 긴 걷기", "zh-Hans": "最长步行"
            ],
            "running": [
                "en": "Longest run", "ru": "Рекорд бега", "de": "Längster Lauf",
                "es": "Carrera más larga", "fr": "Plus longue course", "it": "Corsa più lunga",
                "pl": "Najdłuższy bieg", "ja": "最長のラン", "ko": "가장 긴 달리기", "zh-Hans": "最长跑步"
            ],
            "cycling": [
                "en": "Longest cycling", "ru": "Рекорд вело", "de": "Längste Radtour",
                "es": "Ruta en bici más larga", "fr": "Plus longue sortie vélo", "it": "Uscita in bici più lunga",
                "pl": "Najdłuższa jazda", "ja": "最長のライド", "ko": "가장 긴 라이딩", "zh-Hans": "最长骑行"
            ]
        ]
        let key = ActivityBadgeCatalog.normalize(catalogTitle)
        let pack = titles[key] ?? titles["walk"]
        return pack?[language] ?? pack?["en"] ?? "Longest walk"
    }

    static func earnedOnLine(_ date: String, language: String = WeekFitCurrentLanguageCode()) -> String {
        fill(sentence("earnedOn", language), date)
    }

    private static func fill(_ template: String, _ values: String...) -> String {
        var rest = template
        for value in values {
            guard let range = rest.range(of: "%@") else { return rest }
            rest.replaceSubrange(range, with: value)
        }
        return rest
    }

    private static func sentence(_ key: String, _ language: String) -> String {
        let pack = storyPacks[language] ?? storyPacks["en"] ?? [:]
        return pack[key] ?? storyPacks["en"]?[key] ?? ""
    }

    private static let storyPacks: [String: [String: String]] = [
        "en": [
            "earnedFirst": "You earned this award for your first %@.",
            "earnFirst": "Complete one %@ to earn this award.",
            "walk": "Finish a walk with a measured route. Steps alone do not count.",
            "breath": "Breathe for a full minute to earn this award.",
            "waterGoal": "Reach your daily water goal once to earn this award.",
            "earnedDistance": "You earned this award for a %@ %@.",
            "earnDistance": "Finish a %@ %@ to earn this award.",
            "earnedCount": "You earned this award for completing %@ %@.",
            "earnCount": "Complete %@ %@ to earn this award.",
            "earnedStreak": "You earned this award for %@ on consecutive days.",
            "earnStreak": "Do %@ on consecutive days to earn this award.",
            "earnedKcal": "You earned this award for one session of %@.",
            "earnKcal": "Burn %@ in a single session to earn this award.",
            "earnedWater": "You earned this award for your daily water goal.",
            "earnWater": "Reach your daily water goal to earn this award.",
            "earnedLongest": "You earned this award for your longest %@: %@.",
            "earnLongest": "Set your longest measured %@ to earn this award.",
            "earnedOn": "Earned on %@."
        ],
        "ru": [
            "earnedFirst": "Награда за первую «%@».",
            "earnFirst": "Заверши одну «%@», чтобы получить награду.",
            "walk": "Заверши прогулку с измеренным маршрутом. Шаги сами по себе не считаются.",
            "breath": "Подыши целую минуту, чтобы получить награду.",
            "waterGoal": "Один раз закрой дневную цель по воде, чтобы получить награду.",
            "earnedDistance": "Награда за %@ · %@.",
            "earnDistance": "Заверши %@ · %@, чтобы получить награду.",
            "earnedCount": "Награда за «%@» %@.",
            "earnCount": "Сделай «%@» %@, чтобы получить награду.",
            "earnedStreak": "Награда за «%@» несколько дней подряд.",
            "earnStreak": "Делай «%@» несколько дней подряд, чтобы получить награду.",
            "earnedKcal": "Награда за одну сессию от %@.",
            "earnKcal": "Сожги %@ за одну сессию, чтобы получить награду.",
            "earnedWater": "Награда за дневную цель по воде.",
            "earnWater": "Закрой дневную цель по воде, чтобы получить награду.",
            "earnedLongest": "Награда за самую длинную «%@»: %@.",
            "earnLongest": "Поставь самую длинную «%@», чтобы получить награду.",
            "earnedOn": "Получена %@."
        ],
        "de": [
            "earnedFirst": "Du hast diese Auszeichnung für dein erstes %@ erhalten.",
            "earnFirst": "Schließe ein %@ ab, um diese Auszeichnung zu erhalten.",
            "walk": "Beende einen Spaziergang mit gemessener Strecke. Schritte allein zählen nicht.",
            "breath": "Atme eine volle Minute, um diese Auszeichnung zu erhalten.",
            "waterGoal": "Erreiche einmal dein tägliches Wasserziel, um diese Auszeichnung zu erhalten.",
            "earnedDistance": "Du hast diese Auszeichnung für %@ %@ erhalten.",
            "earnDistance": "Beende %@ %@, um diese Auszeichnung zu erhalten.",
            "earnedCount": "Du hast diese Auszeichnung für %@ %@ erhalten.",
            "earnCount": "Schließe %@ %@ ab, um diese Auszeichnung zu erhalten.",
            "earnedStreak": "Du hast diese Auszeichnung für %@ an aufeinanderfolgenden Tagen erhalten.",
            "earnStreak": "Mach %@ an aufeinanderfolgenden Tagen, um diese Auszeichnung zu erhalten.",
            "earnedKcal": "Du hast diese Auszeichnung für eine Einheit von %@ erhalten.",
            "earnKcal": "Verbrenne %@ in einer Einheit, um diese Auszeichnung zu erhalten.",
            "earnedWater": "Du hast diese Auszeichnung für dein tägliches Wasserziel erhalten.",
            "earnWater": "Erreiche dein tägliches Wasserziel, um diese Auszeichnung zu erhalten.",
            "earnedLongest": "Du hast diese Auszeichnung für deine längste %@ erhalten: %@.",
            "earnLongest": "Stell deine längste gemessene %@ auf, um diese Auszeichnung zu erhalten.",
            "earnedOn": "Erhalten am %@."
        ],
        "es": [
            "earnedFirst": "Ganaste este premio por tu primer %@.",
            "earnFirst": "Completa un %@ para ganar este premio.",
            "walk": "Termina un paseo con una ruta medida. Los pasos por sí solos no cuentan.",
            "breath": "Respira un minuto entero para ganar este premio.",
            "waterGoal": "Alcanza tu meta diaria de agua una vez para ganar este premio.",
            "earnedDistance": "Ganaste este premio por %@ de %@.",
            "earnDistance": "Termina %@ de %@ para ganar este premio.",
            "earnedCount": "Ganaste este premio por completar %@ %@.",
            "earnCount": "Completa %@ %@ para ganar este premio.",
            "earnedStreak": "Ganaste este premio por %@ en días seguidos.",
            "earnStreak": "Haz %@ en días seguidos para ganar este premio.",
            "earnedKcal": "Ganaste este premio por una sesión de %@.",
            "earnKcal": "Quema %@ en una sola sesión para ganar este premio.",
            "earnedWater": "Ganaste este premio por tu meta diaria de agua.",
            "earnWater": "Alcanza tu meta diaria de agua para ganar este premio.",
            "earnedLongest": "Ganaste este premio por tu %@ más larga: %@.",
            "earnLongest": "Marca tu %@ más larga para ganar este premio.",
            "earnedOn": "Conseguido el %@."
        ],
        "fr": [
            "earnedFirst": "Tu as obtenu cette récompense pour ton premier %@.",
            "earnFirst": "Termine un %@ pour obtenir cette récompense.",
            "walk": "Termine une marche avec un parcours mesuré. Les pas seuls ne comptent pas.",
            "breath": "Respire une minute entière pour obtenir cette récompense.",
            "waterGoal": "Atteins une fois ton objectif d’eau du jour pour obtenir cette récompense.",
            "earnedDistance": "Tu as obtenu cette récompense pour %@ · %@.",
            "earnDistance": "Termine %@ · %@ pour obtenir cette récompense.",
            "earnedCount": "Tu as obtenu cette récompense pour %@ %@.",
            "earnCount": "Termine %@ %@ pour obtenir cette récompense.",
            "earnedStreak": "Tu as obtenu cette récompense pour %@ plusieurs jours de suite.",
            "earnStreak": "Fais %@ plusieurs jours de suite pour obtenir cette récompense.",
            "earnedKcal": "Tu as obtenu cette récompense pour une séance de %@.",
            "earnKcal": "Dépense %@ en une seule séance pour obtenir cette récompense.",
            "earnedWater": "Tu as obtenu cette récompense pour ton objectif d’eau du jour.",
            "earnWater": "Atteins ton objectif d’eau du jour pour obtenir cette récompense.",
            "earnedLongest": "Tu as obtenu cette récompense pour ta plus longue %@ : %@.",
            "earnLongest": "Établis ta plus longue %@ pour obtenir cette récompense.",
            "earnedOn": "Obtenue le %@."
        ],
        "it": [
            "earnedFirst": "Hai ottenuto questo premio per il primo %@.",
            "earnFirst": "Completa un %@ per ottenere questo premio.",
            "walk": "Concludi una camminata con un percorso misurato. I passi da soli non contano.",
            "breath": "Respira per un minuto intero per ottenere questo premio.",
            "waterGoal": "Raggiungi una volta il tuo obiettivo d’acqua del giorno per ottenere questo premio.",
            "earnedDistance": "Hai ottenuto questo premio per %@ · %@.",
            "earnDistance": "Concludi %@ · %@ per ottenere questo premio.",
            "earnedCount": "Hai ottenuto questo premio per %@ %@.",
            "earnCount": "Completa %@ %@ per ottenere questo premio.",
            "earnedStreak": "Hai ottenuto questo premio per %@ in giorni di fila.",
            "earnStreak": "Fai %@ in giorni di fila per ottenere questo premio.",
            "earnedKcal": "Hai ottenuto questo premio per una sessione da %@.",
            "earnKcal": "Brucia %@ in una sola sessione per ottenere questo premio.",
            "earnedWater": "Hai ottenuto questo premio per il tuo obiettivo d’acqua del giorno.",
            "earnWater": "Raggiungi il tuo obiettivo d’acqua del giorno per ottenere questo premio.",
            "earnedLongest": "Hai ottenuto questo premio per la tua %@ più lunga: %@.",
            "earnLongest": "Imposta la tua %@ più lunga per ottenere questo premio.",
            "earnedOn": "Ottenuto il %@."
        ],
        "pl": [
            "earnedFirst": "Ta nagroda jest za pierwsze „%@”.",
            "earnFirst": "Ukończ jedno „%@”, żeby zdobyć nagrodę.",
            "walk": "Ukończ spacer ze zmierzoną trasą. Same kroki się nie liczą.",
            "breath": "Oddychaj przez pełną minutę, żeby zdobyć nagrodę.",
            "waterGoal": "Raz zamknij dzienny cel wody, żeby zdobyć nagrodę.",
            "earnedDistance": "Nagroda za %@ · %@.",
            "earnDistance": "Ukończ %@ · %@, żeby zdobyć nagrodę.",
            "earnedCount": "Nagroda za „%@” %@.",
            "earnCount": "Ukończ „%@” %@, żeby zdobyć nagrodę.",
            "earnedStreak": "Nagroda za „%@” przez kolejne dni.",
            "earnStreak": "Rób „%@” przez kolejne dni, żeby zdobyć nagrodę.",
            "earnedKcal": "Nagroda za jedną sesję od %@.",
            "earnKcal": "Spal %@ w jednej sesji, żeby zdobyć nagrodę.",
            "earnedWater": "Nagroda za dzienny cel wody.",
            "earnWater": "Zamknij dzienny cel wody, żeby zdobyć nagrodę.",
            "earnedLongest": "Nagroda za najdłuższą „%@”: %@.",
            "earnLongest": "Ustaw najdłuższą „%@”, żeby zdobyć nagrodę.",
            "earnedOn": "Zdobyta %@."
        ],
        "ja": [
            "earnedFirst": "初めての%@でこの表彰を獲得しました。",
            "earnFirst": "%@を1回完了すると獲得できます。",
            "walk": "計測されたルートの散歩を完了します。歩数だけでは数えません。",
            "breath": "1分呼吸すると獲得できます。",
            "waterGoal": "1日の水分目標を1回達成すると獲得できます。",
            "earnedDistance": "%@の%@でこの表彰を獲得しました。",
            "earnDistance": "%@の%@を完了すると獲得できます。",
            "earnedCount": "%@を%@完了して獲得しました。",
            "earnCount": "%@を%@完了すると獲得できます。",
            "earnedStreak": "%@を連続した日に行い、獲得しました。",
            "earnStreak": "%@を連続した日に行うと獲得できます。",
            "earnedKcal": "1回のセッションで%@に達して獲得しました。",
            "earnKcal": "1回のセッションで%@消費すると獲得できます。",
            "earnedWater": "1日の水分目標を達成して獲得しました。",
            "earnWater": "1日の水分目標を達成すると獲得できます。",
            "earnedLongest": "いちばん長い%@の記録です：%@。",
            "earnLongest": "計測した%@の最長を出すと獲得できます。",
            "earnedOn": "%@に獲得。"
        ],
        "ko": [
            "earnedFirst": "첫 %@로 이 수상을 받았어요.",
            "earnFirst": "%@를 한 번 완료하면 받을 수 있어요.",
            "walk": "측정된 경로의 산책을 완료하세요. 걸음 수만으로는 인정되지 않아요.",
            "breath": "1분 동안 호흡하면 받을 수 있어요.",
            "waterGoal": "하루 물 목표를 한 번 달성하면 받을 수 있어요.",
            "earnedDistance": "%@ %@로 이 수상을 받았어요.",
            "earnDistance": "%@ %@를 완료하면 받을 수 있어요.",
            "earnedCount": "%@ %@를 완료해서 받았어요.",
            "earnCount": "%@ %@를 완료하면 받을 수 있어요.",
            "earnedStreak": "%@를 연속으로 해서 받았어요.",
            "earnStreak": "%@를 연속한 날에 하면 받을 수 있어요.",
            "earnedKcal": "한 세션 %@로 이 수상을 받았어요.",
            "earnKcal": "한 세션에 %@를 소모하면 받을 수 있어요.",
            "earnedWater": "하루 물 목표를 달성해서 받았어요.",
            "earnWater": "하루 물 목표를 달성하면 받을 수 있어요.",
            "earnedLongest": "가장 긴 %@ 기록이에요: %@.",
            "earnLongest": "측정된 가장 긴 %@를 세우면 받을 수 있어요.",
            "earnedOn": "%@에 획득."
        ],
        "zh-Hans": [
            "earnedFirst": "你因第一次%@获得了这项奖项。",
            "earnFirst": "完成一次%@即可获得。",
            "walk": "完成一次有测量路线的步行。只计步数不算。",
            "breath": "呼吸满一分钟即可获得。",
            "waterGoal": "达成一次每日饮水目标即可获得。",
            "earnedDistance": "你因%@%@获得了这项奖项。",
            "earnDistance": "完成%@%@即可获得。",
            "earnedCount": "你因完成%@ %@获得了这项奖项。",
            "earnCount": "完成%@ %@即可获得。",
            "earnedStreak": "你因连续几天%@获得了这项奖项。",
            "earnStreak": "连续几天%@即可获得。",
            "earnedKcal": "你因一次训练达到%@获得了这项奖项。",
            "earnKcal": "在一次训练中消耗%@即可获得。",
            "earnedWater": "你因达成每日饮水目标获得了这项奖项。",
            "earnWater": "达成每日饮水目标即可获得。",
            "earnedLongest": "这是最长的%@：%@。",
            "earnLongest": "创造有测量时长的最长%@即可获得。",
            "earnedOn": "于%@获得。"
        ]
    ]

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

    private static func groupedThousands(_ value: Int) -> String {
        let digits = String(value)
        guard value >= 1000 else { return digits }
        var parts: [String] = []
        var rest = digits
        while rest.count > 3 {
            let split = rest.index(rest.endIndex, offsetBy: -3)
            parts.append(String(rest[split...]))
            rest = String(rest[..<split])
        }
        parts.append(rest)
        return parts.reversed().joined(separator: "\u{00A0}")
    }

    private static func kilometers(_ value: Int, _ language: String) -> String {
        let unit = language == "ru" ? "км" : "km"
        return "\(value) \(unit)"
    }

    private static func distanceText(meters: Int, language: String) -> String {
        let kilometers = Double(meters) / 1000
        let number = kilometers >= 10
            ? "\(Int(kilometers.rounded()))"
            : String(format: "%g", (kilometers * 10).rounded() / 10)
        let unit = language == "ru" ? "км" : "km"
        return "\(number) \(unit)"
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
                of: "%d из %d", completed: "Завершено", streak: "Серия", longest: "Самая длинная", water: "Дневная цель",
                countCondition: "Выполнить «%@» %@", waterDays: "Закрыть цель по воде %@",
                streakCondition: "«%@» несколько дней подряд",
                longestCondition: "Самая длинная «%@» с измеренной длительностью",
                waterCondition: "Закройте дневную цель по воде",
                currentStreak: "Сейчас: %@", minute: "мин", milliliter: "мл", liter: "л",
                timeOne: "раз", timeFew: "раза", timeMany: "раз",
                dayOne: "день", dayFew: "дня", dayMany: "дней"
            )
        case "de":
            return Pack(
                of: "%d von %d", completed: "Geschafft", streak: "Serie", longest: "Längste Einheit", water: "Tagesziel",
                countCondition: "%@ %@", waterDays: "Wasserziel an %@",
                streakCondition: "%@ an aufeinanderfolgenden Tagen",
                longestCondition: "Längste gemessene %@",
                waterCondition: "Erreiche dein tägliches Wasserziel",
                currentStreak: "Aktuelle Serie: %@", minute: "Min.", milliliter: "ml", liter: "l",
                timeOne: "Mal", timeFew: "Mal", timeMany: "Mal",
                dayOne: "Tag", dayFew: "Tage", dayMany: "Tage"
            )
        case "es":
            return Pack(
                of: "%d de %d", completed: "Completado", streak: "Racha", longest: "Sesión más larga", water: "Meta del día",
                countCondition: "Completar %@ %@", waterDays: "Llegar a la meta de agua %@",
                streakCondition: "%@ en días seguidos",
                longestCondition: "%@ más larga medida",
                waterCondition: "Alcanza tu meta diaria de agua",
                currentStreak: "Racha actual: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "vez", timeFew: "veces", timeMany: "veces",
                dayOne: "día", dayFew: "días", dayMany: "días"
            )
        case "fr":
            return Pack(
                of: "%d sur %d", completed: "Terminé", streak: "Série", longest: "Plus longue séance", water: "Objectif du jour",
                countCondition: "Terminer %@ %@", waterDays: "Atteindre l’objectif d’eau %@",
                streakCondition: "%@ plusieurs jours de suite",
                longestCondition: "Plus longue %@ mesurée",
                waterCondition: "Atteins ton objectif d’eau du jour",
                currentStreak: "Série en cours : %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "fois", timeFew: "fois", timeMany: "fois",
                dayOne: "jour", dayFew: "jours", dayMany: "jours"
            )
        case "it":
            return Pack(
                of: "%d di %d", completed: "Completato", streak: "Serie", longest: "Sessione più lunga", water: "Obiettivo del giorno",
                countCondition: "Completare %@ %@", waterDays: "Raggiungere l’obiettivo d’acqua %@",
                streakCondition: "%@ in giorni di fila",
                longestCondition: "%@ più lunga misurata",
                waterCondition: "Raggiungi l’obiettivo d’acqua del giorno",
                currentStreak: "Serie attuale: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "volta", timeFew: "volte", timeMany: "volte",
                dayOne: "giorno", dayFew: "giorni", dayMany: "giorni"
            )
        case "pl":
            return Pack(
                of: "%d z %d", completed: "Ukończone", streak: "Seria", longest: "Najdłuższa", water: "Cel dnia",
                countCondition: "Ukończ „%@” %@", waterDays: "Zamknąć cel wody %@",
                streakCondition: "„%@” przez kolejne dni",
                longestCondition: "Najdłuższa zmierzona „%@”",
                waterCondition: "Zamknij dzienny cel wody",
                currentStreak: "Teraz: %@", minute: "min", milliliter: "ml", liter: "l",
                timeOne: "raz", timeFew: "razy", timeMany: "razy",
                dayOne: "dzień", dayFew: "dni", dayMany: "dni"
            )
        case "ja":
            return Pack(
                of: "%d / %d", completed: "達成", streak: "連続日数", longest: "最長セッション", water: "1日の目標",
                countCondition: "%@を%@", waterDays: "水分目標を%@",
                streakCondition: "%@を連続した日に",
                longestCondition: "計測した%@の最長",
                waterCondition: "1日の水分目標を達成",
                currentStreak: "いまの連続: %@", minute: "分", milliliter: "ml", liter: "L",
                timeOne: "回", timeFew: "回", timeMany: "回",
                dayOne: "日", dayFew: "日", dayMany: "日"
            )
        case "ko":
            return Pack(
                of: "%d / %d", completed: "완료", streak: "연속", longest: "가장 긴 세션", water: "하루 목표",
                countCondition: "%@ %@ 완료", waterDays: "물 목표 %@",
                streakCondition: "%@를 연속한 날에",
                longestCondition: "측정된 가장 긴 %@",
                waterCondition: "하루 물 목표를 달성",
                currentStreak: "현재 연속: %@", minute: "분", milliliter: "ml", liter: "L",
                timeOne: "회", timeFew: "회", timeMany: "회",
                dayOne: "일", dayFew: "일", dayMany: "일"
            )
        case "zh-Hans":
            return Pack(
                of: "%d / %d", completed: "已完成", streak: "连续天数", longest: "最长一次", water: "每日目标",
                countCondition: "完成%@ %@", waterDays: "达成饮水目标 %@",
                streakCondition: "连续几天完成%@",
                longestCondition: "有测量时长的最长%@",
                waterCondition: "达成每日饮水目标",
                currentStreak: "当前连续：%@", minute: "分钟", milliliter: "毫升", liter: "升",
                timeOne: "次", timeFew: "次", timeMany: "次",
                dayOne: "天", dayFew: "天", dayMany: "天"
            )
        default:
            return Pack(
                of: "%d of %d", completed: "Completed", streak: "Day streak", longest: "Longest session", water: "Daily goal",
                countCondition: "Complete %@ %@", waterDays: "Reach the water goal on %@",
                streakCondition: "%@ on consecutive days",
                longestCondition: "Longest measured %@",
                waterCondition: "Reach your daily water goal",
                currentStreak: "Current streak: %@", minute: "min", milliliter: "ml", liter: "L",
                timeOne: "time", timeFew: "times", timeMany: "times",
                dayOne: "day", dayFew: "days", dayMany: "days"
            )
        }
    }
}
